param([long]$WindowHandle = 0, [int]$WaitSeconds = 120)
# Publishes the open Doomsday place through Studio's own menu (File > "Publicar na
# Roblox" / "Publish to Roblox") by UI Automation InvokePattern: no screen clicks,
# no focus theft. Then confirms through the Studio log, because GetProductInfo's
# Updated date stays cached for the session and Team Create saves move it too.
# Never touches experience settings, audience, prices, collaborators or terms.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
if ($WindowHandle -ne 0) { $studioHandle = [IntPtr]$WindowHandle } else {
  $studioProc = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*Doomsday*' -or $_.MainWindowTitle -like '*Tower Defense*' -or $_.MainWindowTitle -like '*Defesa de Torre*' } | Select-Object -First 1
  if (-not $studioProc) { throw 'Doomsday is not open in Studio.' }
  $studioHandle = $studioProc.MainWindowHandle
}
$studio = [System.Windows.Automation.AutomationElement]::FromHandle($studioHandle)
$all = $studio.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
$fileMenu = $all | Where-Object { $_.Current.Name -in @('Arquivo', 'File') -and $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::MenuItem } | Select-Object -First 1
if (-not $fileMenu) { throw 'Studio did not expose the File menu.' }
$fileMenu.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
Start-Sleep -Milliseconds 400
# Studio 0.743 renamed the item to a plain "Publicar"/"Publish" ("Publicar como" is the other one).
$names = @('Publicar na Roblox', 'Publish to Roblox', 'Publicar', 'Publish')
$target = $null
foreach ($name in $names) {
  $target = $studio.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)))
  if ($target) { break }
}
if (-not $target) {
  # The open menu may answer as its own popup window.
  $desktop = [System.Windows.Automation.AutomationElement]::RootElement
  foreach ($name in $names) {
    $target = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)))
    if ($target) { break }
  }
}
if (-not $target) { try { $fileMenu.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Collapse() } catch { }; throw 'Studio did not expose "Publicar na Roblox".' }
$logDir = Join-Path $env:LOCALAPPDATA 'Roblox\logs'
$log = Get-ChildItem $logDir -Filter '*_Studio_*_last.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$before = if ($log) { (Select-String -Path $log.FullName -Pattern 'Go to PublishSuccessful' -SimpleMatch | Measure-Object).Count } else { 0 }
$target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 400
try { $fileMenu.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Collapse() } catch { }
Write-Output 'Sent Studio action: publish'
$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 3
  $log = Get-ChildItem $logDir -Filter '*_Studio_*_last.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $count = (Select-String -Path $log.FullName -Pattern 'Go to PublishSuccessful' -SimpleMatch | Measure-Object).Count
  if ($count -gt $before) { Write-Output ('PublishSuccessful confirmed in ' + $log.Name); exit 0 }
  $failed = Select-String -Path $log.FullName -Pattern 'Go to PublishFailed|PublishError' | Select-Object -Last 1
  if ($failed -and $failed.LineNumber -gt 0) { }
}
Write-Output 'Publish not confirmed in the Studio log within the wait.'
exit 2
