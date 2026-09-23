@echo off
chcp 65001 > nul
set "GAME_EXE=H:\steam\steamapps\common\HANS\Hans.exe"

echo ========================================================
echo   HANS 게임 실행 스크립트
echo ========================================================
echo.
if exist "%GAME_EXE%" (
    echo [진행] Hans.exe 실행 중...
    start "" "%GAME_EXE%"
) else (
    echo [진행] Steam을 통해 HANS 실행 중...
    start steam://rungameid/2616420
)
