# Luleme app icon generator (ASCII-only for PS 5.1 compatibility)
# Generates 1024x1024 layered icon (background/foreground) + 144x144 startIcon.
# Run from project root:  powershell -ExecutionPolicy Bypass -File tools/make_icon.ps1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

# ---------- tunable params ----------
$CanvasSize = 1024
$GradFrom = [System.Drawing.Color]::FromArgb(255, 46, 46, 46)      # dark gray #2E2E2E
$GradTo   = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)         # black #000000
$DeerColor = [System.Drawing.Color]::White
$AccentColor = [System.Drawing.Color]::FromArgb(255, 26, 26, 26)   # near black #1A1A1A (eye/heart)
$ShadowColor = [System.Drawing.Color]::FromArgb(120, 0, 0, 0)      # soft black shadow
$StartIconSize = 144
# ----------------------------------

function New-BitmapCanvas([int]$size) {
    return New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Get-Graphics([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    return $g
}

function New-RoundPen([System.Drawing.Color]$color, [float]$width) {
    $pen = New-Object System.Drawing.Pen($color, $width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $pen
}

function Add-Heart([System.Drawing.Graphics]$g, [float]$cx, [float]$cy, [float]$s, [System.Drawing.Color]$color) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $r = $s * 0.5
    $g.FillEllipse($brush, $cx - $r, $cy - $r * 0.9, $r * 2, $r * 2)
    $g.FillEllipse($brush, $cx - $r * 0.35, $cy - $r * 0.9, $r * 2, $r * 2)
    $tri = [System.Drawing.Point[]]@(
        (New-Object System.Drawing.Point([int]($cx - $r * 1.15), [int]($cy - $r * 0.15))),
        (New-Object System.Drawing.Point([int]($cx + $r * 1.35), [int]($cy - $r * 0.15))),
        (New-Object System.Drawing.Point([int]($cx + $r * 0.1), [int]($cy + $r * 1.15)))
    )
    $g.FillPolygon($brush, $tri)
    $brush.Dispose()
}

# White deer silhouette, facing left, standing. Coordinates for 1024 canvas.
function Add-Deer([System.Drawing.Graphics]$g, [System.Drawing.Color]$deer, [System.Drawing.Color]$accent) {
    # hind legs
    $leg = New-RoundPen $deer 46
    $g.DrawLine($leg, 660, 700, 690, 830)
    $g.DrawLine($leg, 730, 690, 760, 830)
    # front legs
    $g.DrawLine($leg, 470, 705, 445, 835)
    $g.DrawLine($leg, 540, 710, 520, 840)
    $leg.Dispose()

    # tail
    $tail = New-Object System.Drawing.SolidBrush($deer)
    $g.FillEllipse($tail, 782, 545, 56, 56)
    $tail.Dispose()

    # body
    $body = New-Object System.Drawing.SolidBrush($deer)
    $g.FillEllipse($body, 400, 480, 400, 250)
    $body.Dispose()

    # neck
    $neck = New-RoundPen $deer 88
    $g.DrawLine($neck, 470, 560, 420, 460)
    $neck.Dispose()

    # antlers (behind head)
    $antler = New-RoundPen $deer 26
    $g.DrawLine($antler, 410, 400, 350, 250)
    $g.DrawLine($antler, 355, 300, 290, 255)
    $g.DrawLine($antler, 340, 265, 320, 205)
    $g.DrawLine($antler, 465, 405, 520, 265)
    $g.DrawLine($antler, 500, 310, 570, 270)
    $g.DrawLine($antler, 530, 275, 555, 215)
    $antler.Dispose()

    # ears
    $ear = New-Object System.Drawing.SolidBrush($deer)
    $g.FillEllipse($ear, 345, 315, 48, 92)
    $g.FillEllipse($ear, 452, 320, 48, 92)
    $ear.Dispose()

    # head + muzzle
    $head = New-Object System.Drawing.SolidBrush($deer)
    $g.FillEllipse($head, 330, 375, 200, 200)
    $g.FillEllipse($head, 268, 470, 130, 92)
    $head.Dispose()

    # eye
    $eye = New-Object System.Drawing.SolidBrush($accent)
    $g.FillEllipse($eye, 392, 448, 22, 22)
    $eye.Dispose()

    # heart on chest
    Add-Heart $g 500 610 46 $accent
}

# ---------- background ----------
$bg = New-BitmapCanvas $CanvasSize
$g = Get-Graphics $bg
$rect = New-Object System.Drawing.Rectangle(0, 0, $CanvasSize, $CanvasSize)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $GradFrom, $GradTo, 45.0)
$g.FillRectangle($grad, $rect)
$grad.Dispose()
$g.Dispose()
$bg.Save((Join-Path $PSScriptRoot '..\AppScope\resources\base\media\background.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bg.Dispose()
Write-Output 'background.png OK'

# ---------- foreground ----------
$fg = New-BitmapCanvas $CanvasSize
$g = Get-Graphics $fg
# center the deer (shift left 40) and add soft shadow pass
$g.TranslateTransform(-40, 18)
Add-Deer $g $ShadowColor $ShadowColor
$g.ResetTransform()
$g.TranslateTransform(-40, 0)
Add-Deer $g $DeerColor $AccentColor
$g.ResetTransform()
$g.Dispose()
$fg.Save((Join-Path $PSScriptRoot '..\AppScope\resources\base\media\foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$fg.Dispose()
Write-Output 'foreground.png OK'

# ---------- startIcon (composite, scaled) ----------
$full = New-BitmapCanvas $CanvasSize
$g = Get-Graphics $full
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $GradFrom, $GradTo, 45.0)
$g.FillRectangle($grad, $rect)
$grad.Dispose()
$g.TranslateTransform(-40, 18)
Add-Deer $g $ShadowColor $ShadowColor
$g.ResetTransform()
$g.TranslateTransform(-40, 0)
Add-Deer $g $DeerColor $AccentColor
$g.ResetTransform()
$g.Dispose()
$icon = New-BitmapCanvas $StartIconSize
$g = Get-Graphics $icon
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($full, 0, 0, $StartIconSize, $StartIconSize)
$g.Dispose()
$full.Dispose()
$icon.Save((Join-Path $PSScriptRoot '..\entry\src\main\resources\base\media\startIcon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$icon.Dispose()
Write-Output 'startIcon.png OK'

# ---------- sync entry module layered art ----------
Copy-Item (Join-Path $PSScriptRoot '..\AppScope\resources\base\media\background.png') (Join-Path $PSScriptRoot '..\entry\src\main\resources\base\media\background.png') -Force
Copy-Item (Join-Path $PSScriptRoot '..\AppScope\resources\base\media\foreground.png') (Join-Path $PSScriptRoot '..\entry\src\main\resources\base\media\foreground.png') -Force
Write-Output 'entry module icons synced'

Write-Output 'ALL DONE'
