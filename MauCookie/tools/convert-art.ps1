# Converts the original Cookie Clicker art (downloaded to cc-source\img and
# cc-download) into 32-bit TGA files for the addon's LOCAL Textures folder,
# padded or scaled to power-of-two sizes, and writes MauCookie\Art.lua with
# the real pixel sizes so the UI can set texcoords.  The images are
# copyrighted (Orteil / DashNet); the Textures folder is git-ignored and the
# build script never packs it.  Art.lua holds numbers only.
param(
    [string]$Src = "$PSScriptRoot\cc-source\img",
    [string]$Src2 = "$PSScriptRoot\cc-download",
    [string]$Out = "C:\Users\Gamer\Documents\MauAddons\MauCookie\Textures",
    [string]$ArtLua = "C:\Users\Gamer\Documents\MauAddons\MauCookie\Art.lua"
)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null

function Pow2([int]$n) { $p = 1; while ($p -lt $n) { $p *= 2 }; return [Math]::Max(2, $p) }

function Write-Tga([System.Drawing.Bitmap]$bmp, [string]$path) {
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $w -band 0xFF; $header[13] = ($w -shr 8) -band 0xFF
    $header[14] = $h -band 0xFF; $header[15] = ($h -shr 8) -band 0xFF
    $header[16] = 32
    $header[17] = 8
    $fs = [System.IO.File]::Create($path)
    $fs.Write($header, 0, 18)
    for ($y = $h - 1; $y -ge 0; $y--) { $fs.Write($bytes, $y * $stride, $w * 4) }
    $fs.Close()
}

function Load-Image([string]$name) {
    foreach ($dir in @($Src, $Src2)) {
        $p = Join-Path $dir $name
        if (Test-Path $p) {
            $bytes = [System.IO.File]::ReadAllBytes($p)
            $ms = New-Object System.IO.MemoryStream(,$bytes)
            return [System.Drawing.Image]::FromStream($ms)
        }
    }
    return $null
}

$art = @{}
$missing = @()

# key, source file, mode: pad (top-left, transparent fill) or scale (stretch to pow2) or exact
function Convert-One([string]$key, [string]$file, [string]$mode = "pad") {
    $img = Load-Image $file
    if ($null -eq $img) { $script:missing += $file; return }
    $w = $img.Width; $h = $img.Height
    $tw = Pow2 $w; $th = Pow2 $h
    $bmp = New-Object System.Drawing.Bitmap $tw, $th, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    if ($mode -eq "scale") {
        $g.DrawImage($img, 0, 0, $tw, $th)
        $script:art[$key] = @($tw, $th, $tw, $th)
    } elseif ($mode -eq "scale256") {
        $bmp.Dispose()
        $bmp = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g.Dispose()
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($img, 0, 0, 256, 256)
        $script:art[$key] = @(256, 256, 256, 256)
    } elseif ($mode -eq "square") {
        # Centered in a square so the texture can be rotated cleanly.
        $side = Pow2 ([Math]::Max($w, $h))
        $bmp.Dispose()
        $bmp = New-Object System.Drawing.Bitmap $side, $side, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g.Dispose()
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        $g.DrawImage($img, [int](($side - $w) / 2), [int](($side - $h) / 2), $w, $h)
        $script:art[$key] = @($side, $side, $side, $side, 1, 1, $w, $h)
    } else {
        $g.DrawImage($img, 0, 0, $w, $h)
        $script:art[$key] = @($w, $h, $tw, $th)
    }
    $g.Dispose()
    Write-Tga $bmp (Join-Path $Out "$key.tga")
    $bmp.Dispose(); $img.Dispose()
}

# A grid sheet re-laid into a square-ish grid: frames of fw x fh in a row -> cols x rows
function Convert-Strip([string]$key, [string]$file, [int]$fw, [int]$fh, [int]$cols) {
    $img = Load-Image $file
    if ($null -eq $img) { $script:missing += $file; return }
    $frames = [int]($img.Width / $fw)
    $rows = [int][Math]::Ceiling($frames / $cols)
    $tw = Pow2 ($cols * $fw); $th = Pow2 ($rows * $fh)
    $bmp = New-Object System.Drawing.Bitmap $tw, $th, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    for ($i = 0; $i -lt $frames; $i++) {
        $dx = ($i % $cols) * $fw; $dy = [int][Math]::Floor($i / $cols) * $fh
        $dest = New-Object System.Drawing.Rectangle $dx, $dy, $fw, $fh
        $srcR = New-Object System.Drawing.Rectangle ($i * $fw), 0, $fw, $fh
        $g.DrawImage($img, $dest, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $g.Dispose()
    Write-Tga $bmp (Join-Path $Out "$key.tga")
    $script:art[$key] = @($fw, $fh, $tw, $th, $cols, $frames)
    $bmp.Dispose(); $img.Dispose()
}

# icons.png: 48 px cells, cut into tiles of 21 x 21 cells (1008 px) padded to 1024.
function Convert-Icons() {
    $img = Load-Image "icons.png"
    if ($null -eq $img) { $script:missing += "icons.png"; return }
    $cell = 48; $per = 21
    $cols = [int][Math]::Ceiling($img.Width / $cell); $rows = [int][Math]::Ceiling($img.Height / $cell)
    $tilesX = [int][Math]::Ceiling($cols / $per); $tilesY = [int][Math]::Ceiling($rows / $per)
    for ($ty = 0; $ty -lt $tilesY; $ty++) {
        for ($tx = 0; $tx -lt $tilesX; $tx++) {
            $bmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            $sx = $tx * $per * $cell; $sy = $ty * $per * $cell
            $sw = [Math]::Min($per * $cell, $img.Width - $sx); $sh = [Math]::Min($per * $cell, $img.Height - $sy)
            $dest = New-Object System.Drawing.Rectangle 0, 0, $sw, $sh
            $srcR = New-Object System.Drawing.Rectangle $sx, $sy, $sw, $sh
            $g.DrawImage($img, $dest, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
            $g.Dispose()
            Write-Tga $bmp (Join-Path $Out "icons_${tx}_${ty}.tga")
            $bmp.Dispose()
        }
    }
    $script:art["icons"] = @($cols, $rows, $per, $cell, $tilesX, $tilesY)
    $img.Dispose()
}

Convert-Icons
Convert-One "buildings" "buildings.png"
Convert-One "cookie" "perfectCookie.png"
Convert-One "cookieShadow" "cookieShadow.png"
Convert-One "shine" "shine.png"
Convert-One "shineSpoke" "shineSpoke.png"
Convert-One "golden" "goldCookie.png"
Convert-One "wrath" "wrathCookie.png"
Convert-One "goldenWreath" "goldCookieWreath.png"
Convert-One "wrathWreath" "wrathCookieWreath.png"
Convert-One "spookyCookie" "spookyCookie.png"
Convert-One "hearts" "hearts.png"
Convert-One "bunnies" "bunnies.png"
Convert-One "familiars" "familiars.png"
Convert-One "spamCookies" "spamCookies.gif"
Convert-One "reindeer" "frostedReindeer.png"
Convert-One "wrinkler" "wrinkler.png" "square"
Convert-One "wrinklershiny" "shinyWrinkler.png" "square"
Convert-One "wrinklerwinter" "winterWrinkler.png" "square"
Convert-One "wrinklerShadow" "wrinklerShadow.png"
Convert-One "storeTile" "storeTile.jpg" "scale256"
Convert-One "darkNoise" "darkNoise.jpg"
Convert-One "darkNoiseTopBar" "darkNoiseTopBar.jpg"
Convert-One "panelHorizontal" "panelHorizontal.png"
Convert-One "panelVertical" "panelVertical.png"
Convert-One "panelBG" "panelBG.png"
Convert-One "panelMenu3" "panelMenu3.png"
Convert-One "shadedBorders" "shadedBorders.png"
Convert-One "shadedBordersGold" "shadedBordersGold.png"
Convert-One "shadedBordersRed" "shadedBordersRed.png"
Convert-One "shadedBordersSoft" "shadedBordersSoft.png"
Convert-One "upgradeFrame" "upgradeFrame.png"
Convert-One "upgradeHighlight" "upgradeHighlight.png"
Convert-One "upgradeSelector" "upgradeSelector.png"
Convert-One "pieFill" "pieFill.png"
Convert-One "levelUp" "levelUp.png"
Convert-One "sugarLump" "sugarLump.png"
Convert-One "money" "money.png"
Convert-One "heavenlyMoney" "heavenlyMoney.png"
Convert-One "heraldFlag" "heraldFlag.png"
Convert-One "starbg" "starbg.jpg"
Convert-One "heavenRing1" "heavenRing1.jpg"
Convert-One "heavenRing2" "heavenRing2.jpg"
Convert-One "ascendBox" "ascendBox.png"
Convert-One "ascendInfo" "ascendInfo.png"
Convert-One "ascendSlot" "ascendSlot.png"
Convert-One "mapBG" "mapBG.jpg"
Convert-One "shimmeringVeil" "shimmeringVeil.png"
Convert-One "smallCookies" "smallCookies.png"
Convert-One "cookieShower1" "cookieShower1.png"
Convert-One "cookieShower2" "cookieShower2.png"
Convert-One "cookieShower3" "cookieShower3.png"
Convert-One "glint" "glint.png"
Convert-One "flare" "flare.png"
Convert-One "flareGold" "flareGold.png"
Convert-One "spellBG" "spellBG.png"
Convert-One "BGgarden" "BGgarden.jpg"
Convert-One "BGmarket" "BGmarket.jpg"
Convert-One "BGpantheon" "BGpantheon.jpg"
Convert-One "BGgrimoire" "BGgrimoire.jpg"
Convert-One "gardenPlants" "gardenPlants.png"
Convert-One "gardenPlots" "gardenPlots.png"
Convert-One "gardenTip" "gardenTip.png"
Convert-One "roundedPanelBG" "roundedPanelBG.png"
Convert-One "frameBorder" "frameBorder.png"
Convert-One "infoBG" "infoBG.png"
Convert-One "messageBG" "messageBG.png"
Convert-One "prestigeBar" "prestigeBar.jpg"
Convert-One "prestigeBarCap" "prestigeBarCap.png"
Convert-One "featherLeft" "featherLeft.png"
Convert-One "featherRight" "featherRight.png"
Convert-One "snow2" "snow2.jpg"
Convert-One "nest" "nest.png"
Convert-One "parade" "parade.png"
Convert-One "dragonBG2" "dragonBG2.png"
Convert-One "heartStorm" "heartStorm.png"
Convert-One "selectTarget" "selectTarget.png"
Convert-One "linkPulse" "linkPulse.png"
Convert-One "turnInto" "turnInto.png"
Convert-One "imperfectCookie" "imperfectCookie.png"
Convert-Strip "santa" "santa.png" 96 96 4
Convert-Strip "dragon" "dragon.png" 96 96 3
Convert-Strip "brokenCookie" "brokenCookie.png" 256 256 4

# Building rows: background tiles and sprites.
$buildings = @("cursor","grandma","farm","mine","factory","bank","temple","wizardtower","shipment","alchemylab","portal","timemachine","antimattercondenser","prism","chancemaker","fractalEngine","javascriptconsole","idleverse","cortex","you")
foreach ($b in $buildings) {
    Convert-One $b "$b.png"
    Convert-One "${b}Background" "${b}Background.png"
}
Convert-One "youLight" "youLight.png"
$grandmas = @("farmerGrandma","workerGrandma","minerGrandma","cosmicGrandma","transmutedGrandma","alteredGrandma","grandmasGrandma","antiGrandma","rainbowGrandma","bankGrandma","templeGrandma","witchGrandma","luckyGrandma","metaGrandma","scriptGrandma","alternateGrandma","brainyGrandma","cloneGrandma","elfGrandma","bunnyGrandma")
foreach ($g in $grandmas) { Convert-One $g "$g.png" }

# Milks (240 -> 256 scaled so they tile) and backgrounds.
$milks = @("milkPlain","milkChocolate","milkRaspberry","milkOrange","milkCaramel","milkBanana","milkLime","milkBlueberry","milkStrawberry","milkVanilla","milkZebra","milkStars","milkFire","milkBlood","milkGold","milkBlack","milkGreenFire","milkBlueFire","milkHoney","milkCoffee","milkTea","milkCoconut","milkCherry","milkSoy","milkSpiced","milkMaple","milkMint","milkLicorice","milkRose","milkDragonfruit","milkMelon","milkBlackcurrant","milkPeach","milkHazelnut")
foreach ($m in $milks) { Convert-One $m "$m.png" "scale" }
$bgs = @("bgBlue","bgRed","bgWhite","bgBlack","bgGold","grandmas1","grandmas2","grandmas3","bgMoney","bgPurple","bgPink","bgMint","bgSilver","bgBW","bgSpectrum","bgCandy","bgYellowBlue","bgChoco","bgChocoDark","bgPaint","bgSnowy","bgSky","bgStars","bgFoil")
foreach ($bg in $bgs) { Convert-One $bg "$bg.jpg" "scale" }

# Art.lua: sizes only.
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- MauCookie: pixel sizes of the images in the local Textures folder, written")
[void]$sb.AppendLine("-- by scratchpad convert-art.ps1 so the window can set texcoords.  The images")
[void]$sb.AppendLine("-- themselves are not in the repository (see CLAUDE.md, section Art).")
[void]$sb.AppendLine("-- key = { width, height, textureWidth, textureHeight[, frameColumns, frames] }")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("local _, NS = ...")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("NS.ART = {")
foreach ($k in ($art.Keys | Sort-Object)) {
    $v = $art[$k]
    [void]$sb.AppendLine("`t[`"$k`"] = { $($v -join ', ') },")
}
[void]$sb.AppendLine("}")
[System.IO.File]::WriteAllText($ArtLua, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Output ("written " + $art.Count + " entries; " + (Get-ChildItem $Out -Filter *.tga).Count + " tga files; missing: " + ($missing -join ", "))
