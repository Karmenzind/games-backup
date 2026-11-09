param (
    [switch]$Debug,
    [switch]$fake, 
    [string]$name  
)

if ($Debug) {
    $DebugPreference = "Continue"
} else {
    $DebugPreference = "SilentlyContinue"
}

# Load the configuration
$configPath = ".\config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Function to ensure a string is not null or empty after trimming
function Must-ValidString {
    param (
        [string]$str,
        [string]$fieldName
    )
    if ([string]::IsNullOrWhiteSpace($str)) {
        Write-Error "The field '$fieldName' must not be null or empty"
        exit 1
    }
}

# Function to validate and ensure required fields are non-empty
function Validate-SourceAndTarget {
    param (
        [string]$source,
        [string]$target,
        [string]$gameName
    )
    Must-ValidString -str $source -fieldName "source"
    Must-ValidString -str $target -fieldName "target"
}

# Back up selected values from a Windows registry key to a deterministic JSON
# file. Unity stores PlayerPrefs in the registry for standalone Windows games.
function Backup-Registry {
    param (
        [string]$gameName,
        [string]$registry,
        [string]$target,
        [array]$include
    )

    if ($registry -notlike "HKEY_CURRENT_USER\*") {
        Write-Error "Only HKEY_CURRENT_USER registry sources are supported: $registry"
        exit 1
    }

    $registryPath = "Registry::$registry"
    if (-not (Test-Path -LiteralPath $registryPath)) {
        Write-Error "Registry source does not exist: $registry"
        exit 1
    }

    $key = Get-Item -LiteralPath $registryPath
    $values = @()
    foreach ($valueName in ($key.GetValueNames() | Sort-Object)) {
        $selected = $include.Count -eq 0
        foreach ($pattern in $include) {
            if ($valueName -like $pattern) {
                $selected = $true
                break
            }
        }
        if (-not $selected) {
            Write-Debug "Ignored registry value: $valueName"
            continue
        }

        $kind = $key.GetValueKind($valueName).ToString()
        $value = $key.GetValue(
            $valueName,
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        )
        $valueType = $value.GetType().Name
        if ($value -is [byte[]]) {
            $value = [Convert]::ToBase64String($value)
        } elseif ($value -is [int64]) {
            # Keep 64-bit Unity float payloads exact in JSON consumers that
            # cannot safely represent integers larger than 2^53.
            $value = $value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        $values += [ordered]@{
            name = $valueName
            kind = $kind
            valueType = $valueType
            value = $value
        }
    }

    if ($values.Count -eq 0) {
        Write-Error "No registry values matched the include list for: $registry"
        exit 1
    }

    $snapshot = [ordered]@{
        registry = $registry
        values = $values
    }
    $content = ($snapshot | ConvertTo-Json -Depth 5) + [Environment]::NewLine
    $targetDir = [System.IO.Path]::GetDirectoryName($target)
    Ensure-TargetDirectory $targetDir

    $addedFiles = 0
    $overwrittenFiles = 0
    $notChanged = 0
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Debug "Writing registry snapshot: $target"
        if (-not $fake) {
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::GetFullPath($target),
                $content,
                (New-Object System.Text.UTF8Encoding($false))
            )
        }
        $addedFiles++
    } elseif ((Get-Content -Raw -LiteralPath $target) -ceq $content) {
        $notChanged++
    } else {
        Write-Debug "Updating registry snapshot: $target"
        if (-not $fake) {
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::GetFullPath($target),
                $content,
                (New-Object System.Text.UTF8Encoding($false))
            )
        }
        $overwrittenFiles++
    }

    Write-Host "Backup Stats for '$gameName':"
    Write-Host "  Added files: $addedFiles"
    Write-Host "  Overwritten files: $overwrittenFiles"
    Write-Host "  Not changed: $notChanged"
    Write-Host "  Deleted files: 0"
}

# Function to handle file backup
function Backup-Game {
    param (
        [string]$gameName,
        [string]$source,
        [string]$target,
        [array]$ignore
    )

    # Expand user folder (e.g., ~ -> C:\Users\vales)
    $source = [System.Environment]::ExpandEnvironmentVariables($source)
    if ($source -like "~*") {
        $source = $source -replace "^~", $env:USERPROFILE
    }

    # Ensure the target directory exists
    Ensure-TargetDirectory $target
    $targetAbs = Resolve-Path $target

    # Tracking stats for this game
    $addedFiles = 0
    $overwrittenFiles = 0
    $deletedFiles = 0
    $notChanged = 0

    # Handle file deletions ONLY in the target directory
    $targetFiles = Get-ChildItem -Path $target -Recurse -File
    Write-Debug "Checking existed backup files under $($target)"
    foreach ($targetFile in $targetFiles) {
        Write-Debug "Checking $targetFile"
        # Check if the file is missing in the source (i.e., it's no longer needed)
        $relativeTargetPath = $targetFile.FullName.Substring($targetAbs.Path.Length).TrimStart('\')

        $sourceFilePath = Join-Path $source $relativeTargetPath
        if (-not (Test-Path -Path $sourceFilePath)) {
            Write-Debug "Deleting file: $($targetFile.FullName)"
            if (-not $fake) {
                Remove-Item -Path $targetFile.FullName -Force
            }
            $deletedFiles++
        } else {
            Write-Debug "Found mapping: $($targetFile.FullName)"
        }
    }

    # Get all files and directories in the source folder
    $files = Get-ChildItem -Path $source -Recurse -File
    #$directories = Get-ChildItem -Path $source -Recurse -Directory
    foreach ($file in $files) {

        # Construct the relative path and target file path correctly
        $relativePath = $file.FullName.Substring($source.Length).TrimStart('\')  # Remove any leading backslashes

        # Check if the file is in the ignore list
        $skipFile = $false
        foreach ($ignorePattern in $ignore) {
            if ($relativePath -like "$ignorePattern*") {
                $skipFile = $true
                break
            }
        }
        if ($skipFile) {
            Write-Debug "Ignored file: $($relativePath)"
            continue
        }

        $targetFile = Join-Path $target $relativePath  # Properly join the paths

        # Ensure the directory exists in the target path
        $targetDir = [System.IO.Path]::GetDirectoryName($targetFile)
        Ensure-TargetDirectory $targetDir

        # Check if the file needs to be copied (doesn't exist or is different)
        if (-not (Test-Path -Path $targetFile)) {
            Write-Debug "Copy file: $($file.FullName) -> $targetFile"
            if (-not $fake) {
                Copy-Item -Path $file.FullName -Destination $targetFile -Force
            }
            $addedFiles++
        } else {
            if ((Get-FileHash -Path $file.FullName).Hash -ne (Get-FileHash -Path $targetFile).Hash) {
                Write-Debug "Overwriting file: $($file.FullName) to $targetFile"
                if (-not $fake) {
                    Copy-Item -Path $file.FullName -Destination $targetFile -Force
                }
                $overwrittenFiles++
            } else {
                $notChanged++
                Write-Debug "Hash matched: $($targetFile)"
            }
        }
    }

    # Print the stats for this game
    Write-Host "Backup Stats for '$gameName':"
    Write-Host "  Added files: $addedFiles"
    Write-Host "  Overwritten files: $overwrittenFiles"
    Write-Host "  Not changed: $notChanged"
    Write-Host "  Deleted files: $deletedFiles"
}

# Ensure target directory exists
function Ensure-TargetDirectory {
    param (
        [string]$path
    )

    if (-not (Test-Path -Path $path)) {
        Write-Debug "Creating directory: $path"
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}


foreach ($game in $config) {
    if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne $game.name) {
        continue
    }

    if ($game.disabled -eq $true) {
        Write-Host "Skipping disabled game: $($game.name)"
        continue
    }

    Must-ValidString -str $game.target -fieldName "target"

    $hasSource = -not [string]::IsNullOrWhiteSpace($game.source)
    $hasRegistry = -not [string]::IsNullOrWhiteSpace($game.registry)
    if ($hasSource -eq $hasRegistry) {
        Write-Error "Game '$($game.name)' must define exactly one of 'source' or 'registry'"
        exit 1
    }

    Write-Host "Backing up game: $($game.name)"
    if ($hasRegistry) {
        Backup-Registry -gameName $game.name -registry $game.registry -target $game.target -include $game.include
    } else {
        Backup-Game -gameName $game.name -source $game.source -target $game.target -ignore $game.ignore
    }
}
