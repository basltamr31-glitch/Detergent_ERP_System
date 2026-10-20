@echo off
setlocal
if not exist "%~dp0detergent_factory.exe" goto incomplete
if not exist "%~dp0flutter_windows.dll" goto incomplete
if not exist "%~dp0printing_plugin.dll" goto incomplete
if not exist "%~dp0pdfium.dll" goto incomplete
if not exist "%~dp0data\flutter_assets\AssetManifest.bin" goto incomplete
echo Starting the separate ERP test workspace...
echo Username: tester
echo Password: Tester@2026!Demo
echo Click Enter test app. No typing is needed.
start "" /D "%~dp0" "%~dp0detergent_factory.exe" --demo
exit /b 0
:incomplete
echo Extract the COMPLETE ERP ZIP first, then open START-TEST.cmd.
echo Keep detergent_factory.exe, all DLLs and the data folder together.
pause
exit /b 1
