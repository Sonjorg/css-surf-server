# Installs MetaMod:Source + SourceMod and enables map voting plugins.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Server = Join-Path $Root "css-server"
$Cstrike = Join-Path $Server "cstrike"
$Temp = Join-Path $env:TEMP "css-surf-setup"

New-Item -ItemType Directory -Force -Path $Temp | Out-Null

$mmZip = Join-Path $Temp "mmsource.zip"
$smZip = Join-Path $Temp "sourcemod.zip"

Write-Host "Downloading MetaMod:Source..."
Invoke-WebRequest -Uri "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1148-windows.zip" -OutFile $mmZip -UseBasicParsing

Write-Host "Downloading SourceMod..."
Invoke-WebRequest -Uri "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7220-windows.zip" -OutFile $smZip -UseBasicParsing

$mmDir = Join-Path $Temp "mmsource"
$smDir = Join-Path $Temp "sourcemod"
Remove-Item $mmDir,$smDir -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $mmZip -DestinationPath $mmDir -Force
Expand-Archive -Path $smZip -DestinationPath $smDir -Force

$addons = Join-Path $Cstrike "addons"
New-Item -ItemType Directory -Force -Path $addons | Out-Null

Write-Host "Installing MetaMod + SourceMod into css-server\cstrike\addons ..."
Copy-Item -Path (Join-Path $mmDir "addons\*") -Destination $addons -Recurse -Force
Copy-Item -Path (Join-Path $smDir "addons\*") -Destination $addons -Recurse -Force

$cfgDest = Join-Path $Server "cfg"
$gameCfgDest = Join-Path $Cstrike "cfg\sourcemod"
New-Item -ItemType Directory -Force -Path (Join-Path $cfgDest "sourcemod"), $gameCfgDest | Out-Null
Copy-Item -Path (Join-Path $smDir "cfg\sourcemod\*") -Destination (Join-Path $cfgDest "sourcemod") -Recurse -Force
$autopokerCfg = Join-Path $Root "css-server\cfg\sourcemod\autopoker.cfg"
if (Test-Path $autopokerCfg) {
    Copy-Item $autopokerCfg (Join-Path $gameCfgDest "autopoker.cfg") -Force
}
$smCfg = Join-Path $smDir "cfg\sourcemod\sourcemod.cfg"
if (Test-Path $smCfg) {
    Copy-Item $smCfg (Join-Path $gameCfgDest "sourcemod.cfg") -Force
}

$plugins = Join-Path $addons "sourcemod\plugins"
$disabled = Join-Path $plugins "disabled"
foreach ($plugin in @("mapchooser.smx","nominations.smx","rockthevote.smx","nextmap.smx")) {
    $src = Join-Path $disabled $plugin
    $dst = Join-Path $plugins $plugin
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "Enabled plugin: $plugin"
    }
}

Write-Host "Done. SourceMod + map voting plugins installed."
