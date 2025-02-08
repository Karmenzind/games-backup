# games backup

通过Powershell脚本备份Windows平台游戏存档（后续会支持还原功能）

目前只有Win，后续可能会加上NS

包含：

- final fantasy 7 remake
- stray
- resident evil 3
- alan wake 2
- 港诡实录
- slient hill

## 脚本介绍



### 配置文件

每个游戏配置对象为：

```json
{
    "name": "Layers of Fear 2023",
    "source": "~\\AppData\\LocalLow\\Bloober Team\\Layers of Fear",
    "ignore": [
      "tmp",
      "crash"
    ],
    "target": "Win/LayersOfFear2023",
    "disabled": false
}
```

- name 游戏名称
- source 游戏数据在主机上的存储位置，~ 代表用户的主目录
- ignore 数组，需要的文件夹或文件
- target 游戏在repo中的备份目录
- disabled 不处理当前游戏

### 运行方法

先修改配置文件config.json

clone之后，再powershell中运行，即可进行备份：

```powershell
.\sync.ps1
```

脚本支持辅助参数：

- `-Debug` 打印文件细节
- `-Fake` 只预览列表，不执行备份
- `-Name` 指定游戏名字，默认为全部游戏

输出如下：

```
 .\sync.ps1 -Debug -Name 'Stray'
Backing up game: Stray
DEBUG: Checking existed backup files under Win/Stray
DEBUG: Checking C:\Users\vales\Localworks\games-backup\Win\Stray\Config\CrashReportClient\UE4CC-Windows-2E8D38AA4AFB04A3B050BDB4980350D3\CrashReportClient.ini
DEBUG: Found mapping: C:\Users\vales\Localworks\games-backup\Win\Stray\Config\CrashReportClient\UE4CC-Windows-2E8D38AA4AFB04A3B050BDB4980350D3\CrashReportClient.ini
(...省略文件列表)
DEBUG: Hash matched: Win\Stray\SaveGames\76561197960267366\Slots\Slot_3\Data.sav
Backup Stats for 'Stray':
  Added files: 0
  Overwritten files: 0
  Not changed: 25
  Deleted files: 0
```
