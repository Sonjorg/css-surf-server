# Downloads combat surf maps from GameBanana into css-server\cstrike\maps
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$MapsDir = Join-Path $Root "css-server\cstrike\maps"
$Tmp = Join-Path $env:TEMP "css-surf-maps"
New-Item -ItemType Directory -Force -Path $MapsDir,$Tmp | Out-Null

$MapMods = @(
    @{ Id = 121787; Target = "surf_buck-wild" },
    @{ Id = 121522; Target = "surf_10x_final" },
    @{ Id = 137687; Target = "surf_japan_ptad" },
    @{ Id = 122347; Target = "surf_japan_reworked" },
    @{ Id = 135599; Target = "gg_lelouche_rooftops_v3" },
    @{ Id = 122185; Target = "surf_greatriver_fix5" },
    @{ Id = 121552; Target = "surf_4fun" },
    @{ Id = 122985; Target = "surf_skyworld" },
    @{ Id = 122646; Target = "surf_ny_exploder_prime" }
)

function Expand-ArchiveAny {
    param([string]$Path, [string]$Dest)
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    if ($Path -match '\.zip$') {
        Expand-Archive -Path $Path -DestinationPath $Dest -Force
        return
    }
    if ($Path -match '\.rar$') {
        $sevenZip = @(
            "${env:ProgramFiles}\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($sevenZip) {
            & $sevenZip x $Path "-o$Dest" -y | Out-Null
        } else {
            Write-Warning "Need 7-Zip to extract RAR: $Path"
        }
    }
}

$installed = New-Object System.Collections.Generic.List[string]

foreach ($entry in $MapMods) {
    $id = $entry.Id
    $target = $entry.Target
    Write-Host "Downloading $target (GameBanana mod $id)..."
    try {
        $page = Invoke-RestMethod -Uri "https://gamebanana.com/apiv11/Mod/$id/DownloadPage" -UseBasicParsing
        $file = $page._aFiles[0]
        $dlUrl = $file._sDownloadUrl
        $fileName = $file._sFile
        $localZip = Join-Path $Tmp "$id-$fileName"
        Invoke-WebRequest -Uri $dlUrl -OutFile $localZip -UseBasicParsing
        $extractDir = Join-Path $Tmp "extract-$id"
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        Expand-ArchiveAny -Path $localZip -Dest $extractDir
        $bsp = Get-ChildItem $extractDir -Recurse -Filter *.bsp | Select-Object -First 1
        if (-not $bsp) {
            Write-Warning "No .bsp found for $target"
            continue
        }
        $destBsp = Join-Path $MapsDir ($target + ".bsp")
        Copy-Item $bsp.FullName $destBsp -Force
        Write-Host "  -> $($bsp.Name) saved as $target.bsp"
        $installed.Add($target) | Out-Null
    } catch {
        Write-Warning "Failed $target : $_"
    }
}

if ($installed.Count -gt 0) {
    $cyclePath = Join-Path $Root "css-server\cstrike\cfg\mapcycle.txt"
    $installed | Set-Content -Path $cyclePath -Encoding ASCII
    Write-Host "Updated mapcycle.txt with $($installed.Count) installed maps."
} else {
    Write-Warning "No maps installed. Download manually from GameBanana."
}

Write-Host "Installed maps:"
$installed | ForEach-Object { Write-Host "  $_" }
