@echo off
rem Portable wrapper to run repo-local arduino-cli (no PATH changes)
setlocal enabledelayedexpansion
set SCRIPT_DIR=%~dp0
set ARDUINO_CLI=%~dp0..\flash\arduino-cli\arduino-cli.exe

rem Ensure repo-local data directory and config file exist so arduino-cli won't use user home
pushd "%SCRIPT_DIR%.." >nul 2>&1
set REPO_ROOT=%CD%
popd >nul 2>&1
set ARDUINO_DATA=%REPO_ROOT%\flash\arduino-cli-data
if not exist "%ARDUINO_DATA%" (
  mkdir "%ARDUINO_DATA%" >nul 2>&1
)

set CONFIG_FILE=%SCRIPT_DIR%arduino-cli-config.yaml
if not exist "%CONFIG_FILE%" (
  echo directories: > "%CONFIG_FILE%"
  echo   data: "%ARDUINO_DATA%" >> "%CONFIG_FILE%"
)

if not exist "%ARDUINO_CLI%" (
  echo Arduino CLI not found at "%ARDUINO_CLI%"
  echo Run scripts\install-tools-windows.ps1 and select ArduinoCLI, or place arduino-cli.exe in flash\arduino-cli\
  exit /b 1
)

rem Always force repo-local config file so Arduino CLI uses repo data dirs
"%ARDUINO_CLI%" --config-file "%CONFIG_FILE%" %*
