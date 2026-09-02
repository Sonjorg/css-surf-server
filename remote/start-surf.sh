#!/usr/bin/env bash
set -eo pipefail

ROOT="${CSS_SURF_ROOT:-/home/azureuser/css-surf}"
SERVER_DIR="$ROOT/css-server"
cd "$SERVER_DIR"

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$SERVER_DIR/bin"

exec ./srcds_run -game cstrike -console -tickrate 66 -port 27015 +ip 0.0.0.0 +maxplayers 24 +exec server.cfg +map surf_buck-wild
