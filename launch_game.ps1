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
# [커스텀 BGM] hwa 폴더에 음악이 있으면 Settings.ini의 음악 볼륨을 0으로 선제 패치 (메뉴 화면 BGM 중복 원천 차단)
$hwaDir = "H:\steam\steamapps\common\HANS\hwa"
$settingsIni = Join-Path $env:LOCALAPPDATA "Hans\Saved\Config\Windows\Settings.ini"
if ((Test-Path $hwaDir) -and (Test-Path $settingsIni)) {
    $hasMusic = Get-ChildItem -Path $hwaDir -Include "*.ogg","*.mp3","*.wav","*.flac" -File -Recurse -ErrorAction SilentlyContinue
    if ($hasMusic) {
        $iniText = Get-Content $settingsIni -Raw
        if ($iniText -match "GameAudio\.MusicVolume\s*=\s*[0-9\.]+") {
            $iniText = $iniText -replace "GameAudio\.MusicVolume\s*=\s*[0-9\.]+", "GameAudio.MusicVolume=0"
            Set-Content -Path $settingsIni -Value $iniText -NoNewline
            Write-Host "[커스텀 BGM] Settings.ini 순정 음악 볼륨 -> 0 선제 음소거 완료 (메인 메뉴 겹침 방지)" -ForegroundColor Green
        }
    }
}
Write-Host ""

if (Test-Path $GameExe) {
    Write-Host "[진행] Hans.exe 실행 중..."
    Start-Process -FilePath $GameExe
} else {
    Write-Host "[진행] Steam을 통해 HANS 실행 중..."
    Start-Process "steam://rungameid/$SteamAppId"
}
