param([string]$OutputPath = "test-results/studio.png", [long]$WindowHandle = 0,
  [ValidateRange(1,60)][int]$FrameCount = 1, [ValidateRange(0,1000)][int]$FrameIntervalMs = 33)
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class StudioWindow {
	[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
}
'@
if ($WindowHandle -ne 0) { $studioWindow = [IntPtr]$WindowHandle } else {
  $studioProcess = Get-Process RobloxStudioBeta -ErrorAction Stop | Where-Object { $_.MainWindowTitle -like '*Doomsday*' } | Select-Object -First 1
  if (-not $studioProcess) { throw 'Open the Doomsday place in Studio first.' }
  $studioWindow = $studioProcess.MainWindowHandle
}
[StudioWindow]::SetProcessDPIAware() | Out-Null
# With the display asleep Windows stops presenting Studio's 3D view and
# PrintWindow returns the last frame; resetting the display timer wakes it.
if ([StudioWindow]::SetThreadExecutionState(0x3) -ne 0) { Start-Sleep -Milliseconds 1500 }
$studioRect = New-Object StudioWindow+Rect
[StudioWindow]::GetWindowRect($studioWindow, [ref]$studioRect) | Out-Null
$captureWidth = $studioRect.Right - $studioRect.Left
$captureHeight = $studioRect.Bottom - $studioRect.Top
$captureBitmap = New-Object System.Drawing.Bitmap($captureWidth, $captureHeight)
$captureGraphics = [System.Drawing.Graphics]::FromImage($captureBitmap)
try {
  $capturePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
  [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($capturePath)) | Out-Null
  $clock = [System.Diagnostics.Stopwatch]::StartNew()
  for ($frame = 1; $frame -le $FrameCount; $frame++) {
  $captureContext = $captureGraphics.GetHdc()
  try {
    if (-not [StudioWindow]::PrintWindow($studioWindow, $captureContext, 2)) { throw 'Unable to capture Studio window.' }
  } finally { $captureGraphics.ReleaseHdc($captureContext) }
  $framePath = $capturePath
  if ($FrameCount -gt 1) {
    $framePath = Join-Path ([System.IO.Path]::GetDirectoryName($capturePath)) (([System.IO.Path]::GetFileNameWithoutExtension($capturePath)) + ('-{0:d2}' -f $frame) + '.png')
  }
  $captureBitmap.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
  if ($FrameCount -gt 1) { Write-Output ($framePath + ' elapsedMs=' + $clock.ElapsedMilliseconds) } else { Write-Output $framePath }
  if ($frame -lt $FrameCount) { Start-Sleep -Milliseconds $FrameIntervalMs }
  }
} finally {
  $captureGraphics.Dispose()
  $captureBitmap.Dispose()
}
