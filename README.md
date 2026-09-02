# autopoker.net CSS surf server

Counter-Strike: Source combat surf server for **autopoker.net - surf**, with map voting, bhop physics, and Azure deployment.

## Quick start (Windows)

1. Install SteamCMD and the CSS dedicated server into `css-server/` (see `remote/install-surf-server.sh` for Linux equivalent).
2. Run `install-plugins.bat` — MetaMod + SourceMod + map vote plugins.
3. Run `install-maps.bat` — downloads surf maps from GameBanana.
4. Start locally with `start-server.bat`.

## Deploy to Azure

```powershell
powershell -ExecutionPolicy Bypass -File deploy_surf.ps1
```

Uses the same Azure VM as pokerfl. Place an SSH key in `deploy_key.local.txt` or `pokerfl/docker_setup/deploy_key.local.txt`, or pass `-Key`.

## Connect

```
connect 20.251.169.134:27015
```

Game files and maps are not in git — install them with SteamCMD and `install-maps.ps1`.
