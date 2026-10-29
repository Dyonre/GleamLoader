<#
 Gleam Loader installer. Everything it does is undone by Uninstall.bat.

   1. Copies version.dll (the loader) next to Absolver-Win64-Shipping.exe. It refuses to overwrite a version.dll that is not ours.
   2. Copies AbsolverModLauncher.exe into the game folder.
   3. Keeps the game's original Absolver.exe as Absolver.exe.eac and puts the launcher in its place, so Steam's Play button starts the game
      without EasyAntiCheat. Offline and private LAN play only.
   4. Creates the Mods folder.

 It never edits or removes EasyAntiCheat files, never moves your paks, and never touches saves.
 Steam's "Verify integrity of game files" restores the original Absolver.exe; run this installer again afterwards.
 A log of every step is written to install.log next to this script.

 Usage:  Install.bat   |   Uninstall.bat   |   Install.ps1 [-GameDir "<game folder>"] [-Uninstall] [-Quiet]
#>
param([string]$GameDir, [switch]$Uninstall, [switch]$Quiet)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $here 'install.log'
$launcherMarker = 'Absolver Mod Launcher'      # UTF-16 title string inside our launcher exe
$loaderMarker = 'LanNative M'                   # ASCII version string inside our version.dll

function Say([string]$m) {
    Write-Host $m
    try { Add-Content -LiteralPath $logFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) } catch {}
}

function Find-GameRoot {
    $roots = @()
    foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
        try { $p = Get-ItemProperty $k -ErrorAction Stop; foreach ($n in 'SteamPath', 'InstallPath') { if ($p.$n) { $roots += ($p.$n -replace '/', '\') } } } catch {}
    }
    $libs = @()
    foreach ($r in ($roots | Select-Object -Unique)) {
        $libs += $r
        $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') } }
    }
    foreach ($l in ($libs | Select-Object -Unique)) {
        $c = Join-Path $l 'steamapps\common\Absolver'
        if (Test-Path (Join-Path $c 'Absolver\Binaries\Win64\Absolver-Win64-Shipping.exe')) { return $c }
    }
    return $null
}

# Byte search, so a large file never has to be turned into a string.
function Has-Text([string]$path, [string]$text, [Text.Encoding]$encoding) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $b = [IO.File]::ReadAllBytes($path); $n = $encoding.GetBytes($text)
    for ($i = 0; $i -le $b.Length - $n.Length; $i++) {
        if ($b[$i] -ne $n[0]) { continue }
        $hit = $true; for ($j = 1; $j -lt $n.Length; $j++) { if ($b[$i + $j] -ne $n[$j]) { $hit = $false; break } }
        if ($hit) { return $true }
    }
    return $false
}
function Is-OurLauncher([string]$path) { Has-Text $path $launcherMarker ([Text.Encoding]::Unicode) }
function Is-OurLoader([string]$path)   { Has-Text $path $loaderMarker ([Text.Encoding]::ASCII) }

function Run {
    Say ('--- {0} ---' -f $(if ($Uninstall) { 'Uninstall' } else { 'Install' }))
    if (-not $GameDir) { $script:GameDir = Find-GameRoot }
    if (-not $GameDir) {
        if ($Quiet) { throw 'Could not find Absolver through Steam. Run again with -GameDir "<game folder>".' }
        $script:GameDir = Read-Host 'Could not find Absolver automatically. Paste the full path of the main game folder (the one that contains Absolver.exe)'
    }
    $root = $GameDir.Trim('"').TrimEnd('\')
    $win64 = Join-Path $root 'Absolver\Binaries\Win64'
    if (-not (Test-Path -LiteralPath (Join-Path $win64 'Absolver-Win64-Shipping.exe'))) { throw "Absolver-Win64-Shipping.exe not found under $root" }
    Say "Game folder: $root"
    if (Get-Process -Name 'Absolver-Win64-Shipping', 'AbsolverModLauncher' -ErrorAction SilentlyContinue) {
        throw 'Absolver (or the launcher) is running. Close it, then run this again.'
    }

    $dll = Join-Path $win64 'version.dll'
    $launcherCopy = Join-Path $root 'AbsolverModLauncher.exe'
    $exe = Join-Path $root 'Absolver.exe'
    $eacBackup = Join-Path $root 'Absolver.exe.eac'

    if ($Uninstall) {
        if ((Test-Path -LiteralPath $exe) -and (Is-OurLauncher $exe)) {
            if (Test-Path -LiteralPath $eacBackup) {
                Remove-Item -LiteralPath $exe -Force
                Move-Item -LiteralPath $eacBackup -Destination $exe
                Say 'Restored the original Absolver.exe.'
            } else {
                Say 'Absolver.exe is still the launcher but Absolver.exe.eac is missing. In Steam use Properties > Installed Files > Verify integrity to restore it.'
            }
        } else { Say 'Absolver.exe is not the launcher: left alone.' }
        if (Test-Path -LiteralPath $dll) {
            if (Is-OurLoader $dll) { Remove-Item -LiteralPath $dll -Force; Say 'Removed version.dll.' } else { Say 'version.dll here is not ours: left alone.' }
        }
        if (Test-Path -LiteralPath $launcherCopy) { Remove-Item -LiteralPath $launcherCopy -Force; Say 'Removed AbsolverModLauncher.exe.' }
        Say 'Your Mods folder was left in place.'
        return
    }

    foreach ($f in 'version.dll', 'AbsolverModLauncher.exe') {
        if (-not (Test-Path -LiteralPath (Join-Path $here $f))) { throw "$f is missing next to the installer." }
    }
    if ((Test-Path -LiteralPath $dll) -and -not (Is-OurLoader $dll)) {
        throw "$dll already exists and is not ours (another mod uses that file). Refusing to overwrite it."
    }

    Copy-Item -LiteralPath (Join-Path $here 'version.dll') -Destination $dll -Force
    Say 'Installed version.dll.'
    Copy-Item -LiteralPath (Join-Path $here 'AbsolverModLauncher.exe') -Destination $launcherCopy -Force
    Say 'Installed AbsolverModLauncher.exe.'

    if ((Test-Path -LiteralPath $exe) -and (Is-OurLauncher $exe)) {
        Copy-Item -LiteralPath (Join-Path $here 'AbsolverModLauncher.exe') -Destination $exe -Force
        Say 'Play button: already set up (launcher updated).'
    } else {
        if (Test-Path -LiteralPath $exe) {
            $dest = $eacBackup
            if (Test-Path -LiteralPath $dest) { $dest = Join-Path $root ('Absolver.exe.{0}.bak' -f (Get-Date -Format 'yyyyMMdd-HHmmss')) }   # never overwrite a backup
            Move-Item -LiteralPath $exe -Destination $dest
            Say ('Kept the original Absolver.exe as ' + (Split-Path $dest -Leaf) + '.')
        }
        Copy-Item -LiteralPath (Join-Path $here 'AbsolverModLauncher.exe') -Destination $exe -Force
        Say 'Play button: Steam''s Play now starts the modded game. Clear any Absolver launch option you set earlier.'
    }

    $mods = Join-Path $root 'Mods'
    if (-not (Test-Path -LiteralPath $mods)) { New-Item -ItemType Directory -Path $mods | Out-Null; Say "Created $mods" } else { Say "Mods folder: $mods" }

    $paks = Join-Path $root 'Absolver\Content\Paks'
    if (Test-Path -LiteralPath $paks) {
        $extra = @(Get-ChildItem -LiteralPath $paks -Recurse -File -Filter *.pak | Where-Object { $_.Name -notmatch '^pakchunk[0-2]-' })
        if ($extra.Count) {
            Say ('Note: {0} extra .pak file(s) in Content\Paks (not moved). Put each mod in its own folder under Mods instead:' -f $extra.Count)
            foreach ($p in $extra) { Say ('  ' + $p.FullName) }
        }
    }
    Say 'Done. Start the game from Steam as usual. Run Uninstall.bat to go back to the stock game.'
}

try { Run }
catch { Say ('ERROR: ' + $_.Exception.Message); Say "Nothing else was changed after this point. See $logFile"; if (-not $Quiet) { Read-Host 'Press Enter' }; exit 1 }
if (-not $Quiet) { Read-Host 'Press Enter' }
