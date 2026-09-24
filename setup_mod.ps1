$ErrorActionPreference = "Stop"

$gameModsDir = "H:\steam\steamapps\common\HANS\Hans\Binaries\Win64\ue4ss\Mods"
$modNames = @("GravityMod", "WindowModeFix", "UnlockAllMod")
$modsTxt = Join-Path $gameModsDir "mods.txt"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  HANS UE4SS 모드 연결 및 활성화" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

if (-not (Test-Path $gameModsDir)) {
    Write-Host "[오류] UE4SS Mods 폴더를 찾을 수 없습니다: $gameModsDir" -ForegroundColor Red
    return
}

# 1. 각 모드 폴더를 심볼릭 링크(Junction)로 연결
$linked = @()
foreach ($modName in $modNames) {
    $srcDir = Join-Path $PSScriptRoot $modName
    $targetLink = Join-Path $gameModsDir $modName

    if (-not (Test-Path $srcDir)) {
        Write-Host "[건너뜀] 소스 모드 폴더가 없습니다: $srcDir" -ForegroundColor Yellow
        continue
    }

    if (Test-Path $targetLink) {
        Write-Host "[확인] 이미 게임 폴더에 $modName 링크가 연결되어 있습니다." -ForegroundColor Green
    } else {
        New-Item -ItemType Junction -Path $targetLink -Target $srcDir | Out-Null
        Write-Host "[성공] $modName Junction 링크 생성 완료 -> $targetLink" -ForegroundColor Green
    }
    $linked += $modName
}

# 2. mods.txt 등록
if ((Test-Path $modsTxt) -and ($linked.Count -gt 0)) {
    $lines = @(Get-Content $modsTxt)
    $added = @()

    foreach ($modName in $linked) {
        $pattern = "^\s*" + [regex]::Escape($modName) + "\s*:"
        if ($lines -match $pattern) {
            Write-Host "[확인] mods.txt에 이미 $modName 항목이 등록되어 있습니다." -ForegroundColor Yellow
        } else {
            $added += "$modName : 1"
        }
    }

    if ($added.Count -gt 0) {
        # 'Built-in keybinds' 주석 아래 항목은 항상 맨 끝에 있어야 하므로 그 앞에 삽입한다
        $insertAt = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s*;\s*Built-in keybinds") {
                $insertAt = $i
                break
            }
        }

        if ($insertAt -gt 0) {
            $newLines = @($lines[0..($insertAt - 1)]) + $added + @($lines[$insertAt..($lines.Count - 1)])
        } elseif ($insertAt -eq 0) {
            $newLines = $added + $lines
        } else {
            $newLines = $lines + $added
        }

        Set-Content -Path $modsTxt -Value $newLines
        foreach ($entry in $added) {
            Write-Host "[성공] mods.txt에 '$entry' 추가 완료!" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  모드 준비 완료! 게임을 실행하세요." -ForegroundColor Green
Write-Host ""
Write-Host "  [GravityMod]" -ForegroundColor Cyan
Write-Host "  [F1] / [Num 1] : 원래 중력으로 복구 (1.0x)" -ForegroundColor White
Write-Host "  [F2] / [Num 2] : 저중력 (0.25x)" -ForegroundColor White
Write-Host "  [F3] / [Num 3] : 달 중력 (0.08x)" -ForegroundColor White
Write-Host "  [F4] / [Num 4] : 무중력 (0.0x)" -ForegroundColor White
Write-Host "  [F5] / [Num 5] : 공중 부유 (0.05x)" -ForegroundColor White
Write-Host "  [F6]           : 현재 실제 적용 중력 확인" -ForegroundColor White
Write-Host ""
Write-Host "  [WindowModeFix]" -ForegroundColor Cyan
Write-Host "  메인 메뉴 전체화면 강제 버그 자동 복원 (무간섭 동작)" -ForegroundColor White
Write-Host ""
Write-Host "  [UnlockAllMod]" -ForegroundColor Cyan
Write-Host "  [F7] / [Num 7] : 모든 45종 스킨 해금" -ForegroundColor White
Write-Host "  [F8] / [Num 8] : 모든 23종 업적 해금 & Steam 도전과제 달성" -ForegroundColor White
Write-Host "  [F9] / [Num 9] : 스킨 + 업적 올인원 전체 해금" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan
