# games backup

ͨ��Powershell�ű�����Windowsƽ̨��Ϸ�浵��������֧�ֻ�ԭ���ܣ�

Ŀǰֻ��Win���������ܻ����NS

������

- final fantasy 7 remake
- stray
- resident evil 3
- alan wake 2
- �۹�ʵ¼
- slient hill

## �ű�����



### �����ļ�

ÿ����Ϸ���ö���Ϊ��

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

- name ��Ϸ����
- source ��Ϸ�����������ϵĴ洢λ�ã�~ �����û�����Ŀ¼
- ignore ���飬��Ҫ���ļ��л��ļ�
- target ��Ϸ��repo�еı���Ŀ¼
- disabled ������ǰ��Ϸ

### ���з���

���޸������ļ�config.json

clone֮����powershell�����У����ɽ��б��ݣ�

```powershell
.\sync.ps1
```

�ű�֧�ָ���������

- `-Debug` ��ӡ�ļ�ϸ��
- `-Fake` ֻԤ���б���ִ�б���
- `-Name` ָ����Ϸ���֣�Ĭ��Ϊȫ����Ϸ

������£�

```
 .\sync.ps1 -Debug -Name 'Stray'
Backing up game: Stray
DEBUG: Checking existed backup files under Win/Stray
DEBUG: Checking C:\Users\vales\Localworks\games-backup\Win\Stray\Config\CrashReportClient\UE4CC-Windows-2E8D38AA4AFB04A3B050BDB4980350D3\CrashReportClient.ini
DEBUG: Found mapping: C:\Users\vales\Localworks\games-backup\Win\Stray\Config\CrashReportClient\UE4CC-Windows-2E8D38AA4AFB04A3B050BDB4980350D3\CrashReportClient.ini
(...ʡ���ļ��б�)
DEBUG: Hash matched: Win\Stray\SaveGames\76561197960267366\Slots\Slot_3\Data.sav
Backup Stats for 'Stray':
  Added files: 0
  Overwritten files: 0
  Not changed: 25
  Deleted files: 0
```
