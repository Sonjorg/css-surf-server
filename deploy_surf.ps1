# Deploy autopoker.net CSS combat surf server to the Azure VM (same host as pokerfl).
#
# Run from repo root:
#   powershell -ExecutionPolicy Bypass -File deploy_surf.ps1
#
# Switches:
#   -SkipPromo     skip uploading surf promo image to nginx web root
#   -SkipMaps      skip uploading .bsp map files
#   -SkipInstall   skip remote steamcmd / SourceMod install (configs only)
#   -Key <path>    SSH .pem key (or POKERFL_SSH_KEY / deploy_key.local.txt)

param(
    [switch]$SkipPromo,
    [switch]$SkipMaps,
    [switch]$SkipInstall,
    [string]$Key
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
Set-Location $Root

$KEY = $Key
if (-not $KEY -and $env:POKERFL_SSH_KEY) { $KEY = $env:POKERFL_SSH_KEY }
$keyPathFile = Join-Path $Root "deploy_key.local.txt"
if (-not $KEY -and (Test-Path $keyPathFile)) {
    $KEY = (Get-Content $keyPathFile -Raw).Trim()
}
$pokerflKeyFile = Join-Path (Split-Path $Root -Parent) "pokerfl\docker_setup\deploy_key.local.txt"
if (-not $KEY -and (Test-Path $pokerflKeyFile)) {
    $KEY = (Get-Content $pokerflKeyFile -Raw).Trim()
}
if (-not $KEY) {
    throw "No SSH key. Use -Key, POKERFL_SSH_KEY, deploy_key.local.txt, or pokerfl/docker_setup/deploy_key.local.txt"
}

$SERVER = "azureuser@20.251.169.134"
$REMOTE_ROOT = "/home/azureuser/css-surf"
$REMOTE_SERVER = "$REMOTE_ROOT/css-server"
$WEB_ROOT = "/home/azureuser/pokerfl/build/web_landing"
$PROMO_URL = "https://autopoker.net/surf-promo.png"

function Assert-Exit([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit $LASTEXITCODE)" }
}

$SshOpts = @(
    "-i", $KEY,
    "-o", "ConnectTimeout=20",
    "-o", "TCPKeepAlive=yes",
    "-o", "ServerAliveInterval=10",
    "-o", "ServerAliveCountMax=90"
)

function ConvertTo-BashLiteral([string]$Command) {
    $unix = ($Command -replace "`r`n", "`n") -replace "`r", "`n"
    return "'" + ($unix.Replace("'", "'\''")) + "'"
}

function Invoke-Ssh([string]$RemoteCommand) {
    $quoted = ConvertTo-BashLiteral $RemoteCommand
    ssh @SshOpts $SERVER "bash -lc $quoted"
    Assert-Exit "ssh: $RemoteCommand"
}

function Invoke-ScpFile([string]$LocalPath, [string]$RemotePath) {
    $normalized = $LocalPath -Replace '\\', '/'
    scp -i $KEY -o ConnectTimeout=20 $normalized "${SERVER}:${RemotePath}"
    Assert-Exit "scp $LocalPath -> $RemotePath"
}

function Invoke-ScpDir([string]$LocalDir, [string]$RemoteDir) {
    scp -i $KEY -o ConnectTimeout=20 -r "$LocalDir/." "${SERVER}:${RemoteDir}/"
    Assert-Exit "scp dir $LocalDir -> $RemoteDir"
}

function Sync-SurfConfigs {
    Write-Host "Uploading server configs and MOTD..."
    Invoke-ScpFile (Join-Path $Root "css-server\cstrike\cfg\server.cfg") "$REMOTE_SERVER/cstrike/cfg/server.cfg"
    Invoke-ScpFile (Join-Path $Root "css-server\cstrike\cfg\mapcycle.txt") "$REMOTE_SERVER/cstrike/cfg/mapcycle.txt"
    Invoke-ScpFile (Join-Path $Root "css-server\cstrike\cfg\sourcemod\autopoker.cfg") "$REMOTE_SERVER/cstrike/cfg/sourcemod/autopoker.cfg"
    Invoke-ScpFile (Join-Path $Root "css-server\cstrike\cfg\motd.txt") "$REMOTE_SERVER/cstrike/cfg/motd.txt"
    if (Test-Path (Join-Path $Root "css-server\cstrike\cfg\sourcemod\sourcemod.cfg")) {
        Invoke-ScpFile (Join-Path $Root "css-server\cstrike\cfg\sourcemod\sourcemod.cfg") "$REMOTE_SERVER/cstrike/cfg/sourcemod/sourcemod.cfg"
    }
}

function Sync-SurfMaps {
    if ($SkipMaps) { return }
    $mapsDir = Join-Path $Root "css-server\cstrike\maps"
    $surfMaps = Get-ChildItem $mapsDir -Filter "surf_*.bsp" -ErrorAction SilentlyContinue
    if (-not $surfMaps) { throw "No surf_*.bsp files in css-server\cstrike\maps - run install-maps.bat first" }
    Write-Host "Uploading $($surfMaps.Count) surf maps..."
    foreach ($map in $surfMaps) {
        Invoke-ScpFile $map.FullName "$REMOTE_SERVER/cstrike/maps/$($map.Name)"
    }
}

if (-not (Test-Path $KEY)) { throw "SSH key not found: $KEY" }
Write-Host "Preflight OK. Deploy target: $SERVER"

Invoke-Ssh "mkdir -p $REMOTE_ROOT $REMOTE_SERVER/cstrike/cfg/sourcemod $REMOTE_SERVER/cstrike/maps $REMOTE_ROOT/remote"

if (-not $SkipPromo) {
    $promoLocal = Join-Path $Root "assets\surf-promo.png"
    if (-not (Test-Path $promoLocal)) {
        $fallback = Join-Path $Root "surf promo.png"
        if (Test-Path $fallback) {
            New-Item -ItemType Directory -Force -Path (Join-Path $Root "assets") | Out-Null
            Copy-Item $fallback $promoLocal -Force
        }
    }
    if (-not (Test-Path $promoLocal)) { throw "Promo image missing: assets/surf-promo.png" }
    Write-Host "Uploading promo image -> $WEB_ROOT/surf-promo.png ($PROMO_URL)"
    Invoke-ScpFile $promoLocal "$WEB_ROOT/surf-promo.png"
    Invoke-Ssh "chmod 644 $WEB_ROOT/surf-promo.png"
}

Write-Host "Uploading remote install/start scripts..."
Invoke-ScpDir (Join-Path $Root "remote") "$REMOTE_ROOT/remote"
Invoke-Ssh "sed -i 's/\r$//' $REMOTE_ROOT/remote/*.sh"
Invoke-Ssh "chmod +x $REMOTE_ROOT/remote/*.sh && cp $REMOTE_ROOT/remote/start-surf.sh $REMOTE_ROOT/start-surf.sh && chmod +x $REMOTE_ROOT/start-surf.sh && sed -i 's/\r$//' $REMOTE_ROOT/start-surf.sh"

if (-not $SkipInstall) {
    Write-Host "Running remote SteamCMD + SourceMod install (first deploy may take several minutes)..."
    Invoke-Ssh "bash $REMOTE_ROOT/remote/install-surf-server.sh"
}

Sync-SurfConfigs
Sync-SurfMaps

Write-Host "Installing systemd service css-surf..."
$serviceCmd = @"
sudo cp $REMOTE_ROOT/remote/css-surf.service /etc/systemd/system/css-surf.service
sudo systemctl daemon-reload
sudo systemctl enable css-surf
sudo systemctl restart css-surf
sleep 8
sudo systemctl status css-surf --no-pager -l | head -n 25
"@
Invoke-Ssh $serviceCmd

Write-Host ""
Write-Host "Deploy complete."
Write-Host "  Promo / MOTD image: $PROMO_URL"
Write-Host "  Connect:            connect 20.251.169.134:27015"
Write-Host "  Service logs:       ssh ... 'sudo journalctl -u css-surf -f'"
Write-Host ""
Write-Host "If players cannot connect, add Azure NSG inbound rules for UDP and TCP port 27015."
