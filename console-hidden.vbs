' Launch the mihomo control console with no console window. WScript is a GUI
' process so no black cmd/powershell window appears; the PowerShell script runs
' hidden (window style 0). The WPF window itself is shown by the script.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
d = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File """ & d & "\console.ps1""", 0, False
