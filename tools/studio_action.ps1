param([ValidateSet('play','stop','command')][string]$Action, [string]$ScriptPath, [long]$WindowHandle = 0)
# Operates only on the open Doomsday Studio window through UI Automation.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
if ($WindowHandle -ne 0) { $studioHandle = [IntPtr]$WindowHandle } else {
  # The experience title is localized: a Portuguese Studio shows "Defesa de Torre ...".
  $studioProc = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*Doomsday*' -or $_.MainWindowTitle -like '*Tower Defense*' -or $_.MainWindowTitle -like '*Defesa de Torre*' } | Select-Object -First 1
  if (-not $studioProc) { throw 'Doomsday is not open in Studio.' }
  $studioHandle = $studioProc.MainWindowHandle
}
$studioElement = [System.Windows.Automation.AutomationElement]::FromHandle($studioHandle)
function Named($root, $name) {
  return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,$name)))
}
if ($Action -eq 'command') {
  # Portuguese or English Studio UI.
  $toolbar = Named $studioElement 'Comando'
  if (-not $toolbar) { $toolbar = Named $studioElement 'Command Bar' }
  if (-not $toolbar) { $toolbar = Named $studioElement 'Command' }
  $edit = $toolbar.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Edit)))
  $code = Get-Content -Raw -Encoding UTF8 -LiteralPath $ScriptPath
  $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($code)
  Start-Sleep -Milliseconds 150
  $run = Named $toolbar 'Correr'
  if (-not $run) { $run = Named $toolbar 'Run' }
  $run.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
} else {
  $menu = Named $studioElement 'Teste'
  $menu.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
  Start-Sleep -Milliseconds 120
  if ($Action -eq 'play') {
    $sub = Named $studioElement 'Iniciar teste de sessão'
    if (-not $sub) { $sub = Named $studioElement ([string]::Concat('Iniciar teste de sess',[char]0x00e3,'o')) }
    $sub.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
    Start-Sleep -Milliseconds 120
    $items = $studioElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Teste')))
    $target = $items[$items.Count - 1]
  } else { $target = Named $studioElement 'Parar' }
  $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
}
Write-Output ('Sent Studio action: ' + $Action)
