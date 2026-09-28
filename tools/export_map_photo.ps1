param([string]$Source,[int]$Width=1024,[long]$Quality=90)
# Writes <map>.jpg next to a map photograph: the size and format imported into
# Studio's Asset Manager for the portal signs (Config.MapImages).
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$image=[System.Drawing.Image]::FromFile($Source)
try {
    $height=[int]([Math]::Round($image.Height*$Width/$image.Width))
    $bitmap=New-Object System.Drawing.Bitmap($Width,$height)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($image,0,0,$Width,$height)
    $graphics.Dispose()
    $codec=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|Where-Object{$_.MimeType -eq 'image/jpeg'}
    $parameters=New-Object System.Drawing.Imaging.EncoderParameters(1)
    $parameters.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,$Quality)
    $output=[System.IO.Path]::ChangeExtension($Source,'.jpg')
    $bitmap.Save($output,$codec,$parameters)
    $bitmap.Dispose()
    Write-Output $output
} finally { $image.Dispose() }
