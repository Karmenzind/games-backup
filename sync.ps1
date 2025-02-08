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

    Must-ValidString -str $game.source -fieldName "source"
    Must-ValidString -str $game.target -fieldName "target"

    Write-Host "Backing up game: $($game.name)"
    Backup-Game -gameName $game.name -source $game.source -target $game.target -ignore $game.ignore
}
