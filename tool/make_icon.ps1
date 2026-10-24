Add-Type -AssemblyName System.Drawing

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Draw-Icon([string]$path, [bool]$foreground) {
    $size = 1024
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    if (-not $foreground) {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255, 16, 20, 30), [System.Drawing.Color]::FromArgb(255, 8, 10, 16), 45)
        $g.FillRectangle($bg, $rect)

        # warm aurora blobs
        foreach ($blob in @(
            @(140, 160, 620, 255, 77, 109),
            @(520, 620, 700, 123, 92, 255),
            @(700, 120, 420, 124, 231, 196)
        )) {
            $c = [System.Drawing.Color]::FromArgb(70, $blob[3], $blob[4], $blob[5])
            $br = New-Object System.Drawing.Drawing2D.GraphicsPath
            $br.AddEllipse($blob[0], $blob[1], $blob[2], $blob[2])
            $pbr = New-Object System.Drawing.Drawing2D.PathGradientBrush($br)
            $pbr.CenterColor = $c
            $pbr.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $blob[3], $blob[4], $blob[5]))
            $g.FillEllipse($pbr, $blob[0], $blob[1], $blob[2], $blob[2])
        }

        # vinyl rings
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(34, 255, 255, 255), 3)
        foreach ($rr in @(250, 310, 370, 430)) {
            $g.DrawEllipse($pen, 512 - $rr, 512 - $rr, $rr * 2, $rr * 2)
        }
        $pen.Dispose()
    }

    # sound wave bars behind text
    $accent = [System.Drawing.Color]::FromArgb(255, 255, 77, 109)
    $mint = [System.Drawing.Color]::FromArgb(255, 124, 231, 196)
    $bars = @(
        @(200, 430, 34, 164, $accent),
        @(262, 382, 34, 260, $accent),
        @(324, 460, 34, 104, $mint),
        @(700, 430, 34, 164, $mint),
        @(762, 382, 34, 260, $accent),
        @(824, 460, 34, 104, $accent)
    )
    foreach ($b in $bars) {
        $r = New-RoundedPath $b[0] $b[1] $b[2] $b[3] 17
        $br = New-Object System.Drawing.SolidBrush($b[4])
        $g.FillPath($br, $r)
        $br.Dispose(); $r.Dispose()
    }

    # main wordmark
    $family = New-Object System.Drawing.FontFamily("Microsoft YaHei")
    $font = New-Object System.Drawing.Font($family, 268, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rectF = New-Object System.Drawing.RectangleF(0, 300, 1024, 460)
    $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 0, 0, 0))
    $g.DrawString("爽听", $font, $shadow, (New-Object System.Drawing.RectangleF(6, 312, 1024, 460)), $fmt)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.DrawString("爽听", $font, $white, $rectF, $fmt)

    # subtitle
    $sub = New-Object System.Drawing.Font("Segoe UI", 46, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $subFmt = New-Object System.Drawing.StringFormat
    $subFmt.Alignment = [System.Drawing.StringAlignment]::Center
    $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 255, 255))
    $g.DrawString("S H U A N G T I N G", $sub, $subBrush, (New-Object System.Drawing.RectangleF(0, 720, 1024, 80)), $subFmt)

    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

Draw-Icon "C:\Users\leey1\Desktop\A\A2\assets\icon\app_icon.png" $false
Draw-Icon "C:\Users\leey1\Desktop\A\A2\assets\icon\app_icon_foreground.png" $true
Write-Output "icons written"
