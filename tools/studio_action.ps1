param([ValidateSet('play','stop','command')][string]$Action, [string]$ScriptPath, [long]$WindowHandle = 0)
# Operates only on the open Doomsday Studio window through UI Automation.
$ErrorActionPreference = 'Stop'
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
  # If a movement key lands before the command during focus handoff, it only
  # renames this harmless assignment instead of breaking the first Lua call.
  $code = "_ = nil`n" + $code
  $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($code)
  Start-Sleep -Milliseconds 150
  $run = Named $toolbar 'Correr'
  if (-not $run) { $run = Named $toolbar 'Run' }
  $run.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
} else {
  # The toolbar also contains a combobox named Teste. Select the actual menu.
  $menu = $studioElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition) | Where-Object { $_.Current.Name -in @('Teste', 'Test') -and $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::MenuItem } | Select-Object -First 1
  $menu.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
  Start-Sleep -Milliseconds 120
  if ($Action -eq 'play') {
    $sub = Named $studioElement 'Iniciar teste de sessão'
    if (-not $sub) { $sub = Named $studioElement ([string]::Concat('Iniciar teste de sess',[char]0x00e3,'o')) }
    $sub.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
    Start-Sleep -Milliseconds 120
    $items = $studioElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Teste')))
    $target = $items[$items.Count - 1]
  } else {
    $target = Named $studioElement 'Parar'
    if (-not $target) { $target = Named $studioElement ([string]::Concat('Finalizar a sess',[char]0x00e3,'o')) }
    if (-not $target) { $target = Named $studioElement 'End Session' }
    if (-not $target) { $target = Named $studioElement 'Stop' }
    if (-not $target) { throw 'Studio did not expose a Stop/End Session action.' }
  }
  $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
}
Write-Output ('Sent Studio action: ' + $Action)
