$ErrorActionPreference = "Stop"

$gameModsDir = "H:\steam\steamapps\common\HANS\Hans\Binaries\Win64\ue4ss\Mods"
$modNames = @("GravityMod", "WindowModeFix")
$modsTxt = Join-Path $gameModsDir "mods.txt"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  HANS UE4SS 모드 연결 해제" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

foreach ($modName in $modNames) {
    $targetLink = Join-Path $gameModsDir $modName

    if (Test-Path $targetLink) {
        # Remove junction without deleting original content
        (Get-Item $targetLink).Delete()
        Write-Host "[성공] $modName 링크가 게임 Mods 폴더에서 안전하게 제거되었습니다." -ForegroundColor Green
    } else {
        Write-Host "[확인] $modName 링크가 이미 없습니다." -ForegroundColor Yellow
    }
}
Write-Host "       (작업 폴더의 소스 코드는 그대로 보존됩니다)" -ForegroundColor Gray

if (Test-Path $modsTxt) {
    $newContent = @(Get-Content $modsTxt)
    foreach ($modName in $modNames) {
        $pattern = "^\s*" + [regex]::Escape($modName) + "\s*:"
        $newContent = @($newContent | Where-Object { $_ -notmatch $pattern })
    }
    Set-Content -Path $modsTxt -Value $newContent
    Write-Host "[성공] mods.txt에서 모드 등록 해제 완료." -ForegroundColor Green
}

Write-Host "========================================================" -ForegroundColor Cyan
