param([long]$WindowHandle,[string]$OutputPath,[string]$MapId,[switch]$CropOnly)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName System.Drawing
if (-not $CropOnly) {
    $window=[System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$WindowHandle)
    $window.SetFocus()
    Start-Sleep -Milliseconds 1800
    & (Join-Path $PSScriptRoot 'capture_studio.ps1') -WindowHandle $WindowHandle -OutputPath $OutputPath
}
$picture=[System.Drawing.Bitmap]::FromFile($OutputPath)
try {
    # Crop only the rendered scene; UI never becomes part of a map asset.
    # Current shared Studio layout: Explorer at right, Toolbox at left.
    $left=[int]($picture.Width*0.145)
    # Leave the orientation cube above the photograph; frame buildings/roads.
    $top=[int]($picture.Height*0.265)
    $width=[int]($picture.Width*0.605)
    $height=[int]($width/2.3)
    $crop=$picture.Clone((New-Object System.Drawing.Rectangle($left,$top,$width,$height)),$picture.PixelFormat)
    try {
        $destination=Join-Path (Split-Path $PSScriptRoot -Parent) ('assets/map-photos/'+$MapId+'.png')
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($destination)) > $null
        $crop.Save($destination,[System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output $destination
        # The tracked copy for Studio's Asset Manager: 1024 wide, JPEG.
        & (Join-Path $PSScriptRoot 'export_map_photo.ps1') -Source $destination
    } finally { $crop.Dispose() }
} finally { $picture.Dispose() }
