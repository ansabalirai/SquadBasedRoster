@echo off
SET "SDKLocation=D:\SteamLibrary\steamapps\common\XCOM 2 War of the Chosen SDK"
SET "GameLocation=F:\SteamLibrary\steamapps\common\XCOM 2\XCom2-WarOfTheChosen"
SET "SRCLocation=D:\Github\SquadBasedRoster"
REM SET "LWOTCLocation=D:\Github\lwotc"
powershell.exe -NonInteractive -ExecutionPolicy Unrestricted  -file "D:\Github\SquadBasedRoster\.scripts\build.ps1" -srcDirectory "%SRCLocation%" -sdkPath "%SDKLocation%" -gamePath "%GameLocation%" -config "default"
