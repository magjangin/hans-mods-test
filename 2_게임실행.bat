@echo off
chcp 65001 > nul
set "GAME_EXE=H:\steam\steamapps\common\HANS\Hans.exe"

echo ========================================================
echo   HANS 게임 실행 스크립트
echo ========================================================
echo.
echo [자동 해금] 게임 실행 전 45종 모든 스킨 및 23종 업적 세이브 자동 주입 중...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0unlock_all.ps1"
echo.
if exist "%GAME_EXE%" (
    echo [진행] Hans.exe 실행 중...
    start "" "%GAME_EXE%"
) else (
    echo [진행] Steam을 통해 HANS 실행 중...
    start steam://rungameid/2616420
)
