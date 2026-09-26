$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

Write-Banner "HANS UE4SS 모드 연결 해제"

foreach ($modName in $ModNames) {
    $targetLink = Join-Path $GameModsDir $modName

    if (Test-Path $targetLink) {
        # Remove junction without deleting original content
        (Get-Item $targetLink).Delete()
        Write-Host "[성공] $modName 링크가 게임 Mods 폴더에서 안전하게 제거되었습니다." -ForegroundColor Green
    } else {
        Write-Host "[확인] $modName 링크가 이미 없습니다." -ForegroundColor Yellow
    }
}
Write-Host "       (작업 폴더의 소스 코드는 그대로 보존됩니다)" -ForegroundColor Gray

if (Test-Path $ModsTxt) {
    $newContent = @(Get-Content $ModsTxt)
    foreach ($modName in $ModNames) {
        $pattern = Get-ModsTxtPattern $modName
        $newContent = @($newContent | Where-Object { $_ -notmatch $pattern })
    }
    Set-Content -Path $ModsTxt -Value $newContent
    Write-Host "[성공] mods.txt에서 모드 등록 해제 완료." -ForegroundColor Green
}

Write-Host "========================================================" -ForegroundColor Cyan
