# 스크립트 공용 설정. 다른 .ps1 파일이 dot-source(. config.ps1)로 불러 쓴다.
# 게임이 다른 위치에 설치되어 있으면 $GameDir만 고치면 된다.
# (게임 안에서 실행되는 unlock_steam_achievements.py는 자체 GAME_DIR 상수를 쓴다)

$GameDir     = "H:\steam\steamapps\common\HANS"
$GameExe     = Join-Path $GameDir "Hans.exe"
$GameModsDir = Join-Path $GameDir "Hans\Binaries\Win64\ue4ss\Mods"
$ModsTxt     = Join-Path $GameModsDir "mods.txt"
$SteamAppId  = 2616420

$ModNames = @("GravityMod", "WindowModeFix", "UnlockAllMod")

$SaveDir = Join-Path $env:LOCALAPPDATA "Hans\Saved\SaveGames"

function Write-Banner([string]$title) {
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
}

# mods.txt에서 "<ModName> : 0|1" 줄을 찾는 정규식
function Get-ModsTxtPattern([string]$modName) {
    return "^\s*" + [regex]::Escape($modName) + "\s*:"
}
