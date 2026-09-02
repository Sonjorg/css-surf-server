#!/usr/bin/env bash
# Install / update CSS dedicated server + Linux MetaMod/SourceMod on the VM.
set -euo pipefail

ROOT="${CSS_SURF_ROOT:-/home/azureuser/css-surf}"
STEAMCMD="$ROOT/steamcmd/steamcmd.sh"
SERVER_DIR="$ROOT/css-server"

if ! command -v steamcmd >/dev/null 2>&1; then
  echo "Installing 32-bit libs for SteamCMD..."
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y lib32gcc-s1 lib32stdc++6 curl ca-certificates
fi

mkdir -p "$ROOT/steamcmd"
if [[ ! -x "$STEAMCMD" ]]; then
  echo "Installing SteamCMD..."
  cd "$ROOT/steamcmd"
  curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
fi

mkdir -p "$SERVER_DIR"

echo "Updating Counter-Strike: Source dedicated server (232330)..."
cd "$ROOT/steamcmd"
./steamcmd.sh \
  +@sSteamCmdForcePlatformType linux \
  +force_install_dir "$SERVER_DIR" \
  +login anonymous \
  +app_update 232330 validate \
  +quit

MM_ZIP="$ROOT/mmsource-linux.tar.gz"
SM_ZIP="$ROOT/sourcemod-linux.tar.gz"
if [[ ! -f "$MM_ZIP" ]]; then
  curl -fL "https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1148-linux.tar.gz" -o "$MM_ZIP"
fi
if [[ ! -f "$SM_ZIP" ]]; then
  curl -fL "https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7220-linux.tar.gz" -o "$SM_ZIP"
fi

echo "Installing MetaMod + SourceMod..."
tar -xzf "$MM_ZIP" -C "$SERVER_DIR/cstrike"
tar -xzf "$SM_ZIP" -C "$SERVER_DIR/cstrike"

for plugin in mapchooser nominations rockthevote; do
  src="$SERVER_DIR/cstrike/addons/sourcemod/plugins/disabled/${plugin}.smx"
  dst="$SERVER_DIR/cstrike/addons/sourcemod/plugins/${plugin}.smx"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst"
  fi
done

echo "CSS surf server install complete."
