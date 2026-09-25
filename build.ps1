# Builds a release zip for one addon in this repository.
#
#   .\build.ps1 MauGuildMap
#
# Reads <Addon>\<Addon>.toc, takes the version from "## Version:" and the file
# list from the TOC's file entries, copies exactly those files (plus the TOC)
# into a folder named after the addon and zips that folder as
# versions\<Addon>-<version>.zip.  Extracting the zip into Interface\AddOns
# gives a working addon; nothing else (README, CLAUDE.md, CURSEFORGE.md, ...)
# ends up inside.

param(
	[Parameter(Mandatory = $true)]
	[string]$Addon
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $root $Addon
$toc = Join-Path $source "$Addon.toc"
if (-not (Test-Path $toc)) {
	throw "No $Addon.toc found in $source"
}

$lines = Get-Content $toc
$version = $null
foreach ($line in $lines) {
	if ($line -match '^##\s*Version:\s*(.+?)\s*$') {
		$version = $Matches[1]
		break
	}
}
if (-not $version) {
	throw "No '## Version:' line in $toc"
}

# File entries: every non-empty line that is not a directive, without any
# trailing load condition such as "[AllowLoadGameType camelot]".
$files = @()
foreach ($line in $lines) {
	$entry = $line.Trim()
	if ($entry -eq '' -or $entry.StartsWith('#')) {
		continue
	}
	$entry = ($entry -replace '\s*\[.*\]\s*$', '').Trim()
	if ($entry -ne '') {
		$files += $entry
	}
}

$staging = Join-Path $env:TEMP ("mauaddons-build-" + [guid]::NewGuid().ToString())
$packageDir = Join-Path $staging $Addon
New-Item -ItemType Directory -Path $packageDir | Out-Null
try {
	Copy-Item $toc (Join-Path $packageDir "$Addon.toc")
	foreach ($file in $files) {
		$from = Join-Path $source $file
		if (-not (Test-Path $from)) {
			throw "Listed in the TOC but missing on disk: $file"
		}
		$to = Join-Path $packageDir $file
		$toDir = Split-Path -Parent $to
		if (-not (Test-Path $toDir)) {
			New-Item -ItemType Directory -Path $toDir | Out-Null
		}
		Copy-Item $from $to
	}

	$versionsDir = Join-Path $root 'versions'
	if (-not (Test-Path $versionsDir)) {
		New-Item -ItemType Directory -Path $versionsDir | Out-Null
	}
	$zip = Join-Path $versionsDir "$Addon-$version.zip"
	if (Test-Path $zip) {
		Remove-Item $zip
	}

	# tar.exe ships with Windows 10 and later and writes zips with forward
	# slashes, which every unzip tool and CurseForge accept.
	& tar.exe -a -c -f $zip -C $staging $Addon
	if ($LASTEXITCODE -ne 0) {
		throw "tar.exe failed with exit code $LASTEXITCODE"
	}

	Write-Output "Built $zip"
	& tar.exe -t -f $zip
}
finally {
	Remove-Item -Recurse -Force $staging
}
