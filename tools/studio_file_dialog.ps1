param([Parameter(Mandatory = $true)][string]$Path, [long]$WindowHandle = 0, [int]$TimeoutSeconds = 25, [switch]$Cancel)
# Answers the "Import File" dialog that StudioService:PromptImportFile opens in the
# Doomsday Studio window: types the path into the file-name box and presses Open,
# through window messages, so it neither moves the mouse nor takes the keyboard.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgWin {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
}
"@
if ($WindowHandle -eq 0) {
  $proc = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*Doomsday*' -or $_.MainWindowTitle -like '*Tower Defense*' } | Select-Object -First 1
  if (-not $proc) { throw 'Doomsday is not open in Studio.' }
  $WindowHandle = $proc.MainWindowHandle
}
$main = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$WindowHandle)
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, '#32770')
$dialog = $null
$end = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $end -and -not $dialog) {
  $dialog = $main.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
  if (-not $dialog) { Start-Sleep -Milliseconds 250 }
}
if (-not $dialog) { throw 'No file dialog appeared.' }
$title = $dialog.Current.Name
# Only ever answer the import prompt this tool is for.
if ($title -notlike '*Import*' -and $title -notlike '*Importar*') { throw "Unexpected dialog: $title" }
$hDialog = [IntPtr]$dialog.Current.NativeWindowHandle
if ($Cancel) {
  [void][DlgWin]::SendMessage($hDialog, 0x111, [IntPtr]2, [IntPtr]::Zero) # WM_COMMAND IDCANCEL
  Write-Output 'Dialog cancelled'
  exit 0
}
# The file-name box: a combo's edit (id 1148) or a plain edit (id 1152).
$edit = [DlgWin]::GetDlgItem($hDialog, 1148)
if ($edit -ne [IntPtr]::Zero) { $inner = [DlgWin]::FindWindowEx($edit, [IntPtr]::Zero, 'Edit', $null); if ($inner -ne [IntPtr]::Zero) { $edit = $inner } }
if ($edit -eq [IntPtr]::Zero) { $edit = [DlgWin]::GetDlgItem($hDialog, 1152) }
if ($edit -eq [IntPtr]::Zero) { throw 'The dialog has no file-name box.' }
[void][DlgWin]::SendMessage($edit, 0x000C, [IntPtr]::Zero, $Path) # WM_SETTEXT
Start-Sleep -Milliseconds 200
$open = [DlgWin]::GetDlgItem($hDialog, 1)
[void][DlgWin]::SendMessage($hDialog, 0x111, [IntPtr]1, $open)     # WM_COMMAND IDOK
Write-Output ("Dialog answered: " + $Path)
