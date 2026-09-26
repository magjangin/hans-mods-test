$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

Write-Banner "HANS 게임 실행 스크립트"
Write-Host ""
Write-Host "[자동 해금] 게임 실행 전 45종 모든 스킨 및 23종 업적 세이브 자동 주입 중..."
try {
    & (Join-Path $PSScriptRoot "unlock_all.ps1")
} catch {
    # 세이브 패치가 실패해도 게임은 실행한다
    Write-Host "[경고] 세이브 패치 실패: $_" -ForegroundColor Yellow
}
Write-Host ""

if (Test-Path $GameExe) {
    Write-Host "[진행] Hans.exe 실행 중..."
    Start-Process -FilePath $GameExe
} else {
    Write-Host "[진행] Steam을 통해 HANS 실행 중..."
    Start-Process "steam://rungameid/$SteamAppId"
}
