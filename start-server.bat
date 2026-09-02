@echo off
cd /d "%~dp0css-server"

echo Starting autopoker.net - surf ...
echo Map vote: !nominate / !rtv  ^|  Auto vote every 25 min
echo.

srcds.exe -console -game cstrike -tickrate 66 -port 27015 +maxplayers 24 +exec server.cfg +map surf_buck-wild

pause
