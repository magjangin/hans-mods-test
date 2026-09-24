# ==============================================================================
# HANS - All Skins & Achievements Unlocker (PowerShell)
# 45종 모든 스킨 및 23종 모든 업적을 세이브 파일에 100% 해금 주입합니다.
# ==============================================================================
$ErrorActionPreference = "Stop"

$saveDir = [System.Environment]::ExpandEnvironmentVariables("%LOCALAPPDATA%\Hans\Saved\SaveGames")
$skinPath = Join-Path $saveDir "skinslot.sav"
$achPath  = Join-Path $saveDir "achslot.sav"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  HANS - 모든 스킨 & 업적 해금 패처" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $saveDir)) {
    New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
}

function Patch-Skins {
    param ([string]$filePath)
    
    if (-not (Test-Path $filePath)) {
        Write-Host "[안내] $filePath 파일이 아직 없습니다. 게임을 먼저 1회 실행하거나 기본 세이브 생성이 필요합니다." -ForegroundColor Yellow
        return $false
    }
    
    # 백업 생성
    $bakPath = $filePath + ".bak"
    Copy-Item -Path $filePath -Destination $bakPath -Force
    Write-Host "[백업] 기존 스킨 세이브 백업 완료 -> $bakPath" -ForegroundColor DarkGray
    
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    
    # "SavedSkins`0" 위치 검색
    $searchPattern = [System.Text.Encoding]::ASCII.GetBytes("SavedSkins`0")
    $idx = -1
    for ($i = 0; $i -le ($bytes.Length - $searchPattern.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $searchPattern.Length; $j++) {
            if ($bytes[$i + $j] -ne $searchPattern[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            $idx = $i
            break
        }
    }
    
    if ($idx -eq -1) {
        Write-Host "[오류] SavedSkins 속성을 세이브 파일에서 찾을 수 없습니다." -ForegroundColor Red
        return $false
    }
    
    $prefix = New-Object byte[] $idx
    [System.Array]::Copy($bytes, 0, $prefix, 0, $idx)
    
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    
    # 45개 스킨 엔트리 생성
    $entryMs = New-Object System.IO.MemoryStream
    $entryBw = New-Object System.IO.BinaryWriter($entryMs)
    
    for ($k = 0; $k -lt 45; $k++) {
        $nameBytes = [System.Text.Encoding]::ASCII.GetBytes("E_Skins::NewEnumerator$k`0")
        $entryBw.Write([int32]$nameBytes.Length)
        $entryBw.Write($nameBytes)
        $entryBw.Write([byte]1) # bool true
    }
    
    $entriesData = $entryMs.ToArray()
    $entryBw.Close()
    $entryMs.Close()
    
    # Map Payload: NumKeysToRemove (0), NumEntries (45), Entries
    $payloadMs = New-Object System.IO.MemoryStream
    $payloadBw = New-Object System.IO.BinaryWriter($payloadMs)
    $payloadBw.Write([int32]0)
    $payloadBw.Write([int32]45)
    $payloadBw.Write($entriesData)
    $payloadData = $payloadMs.ToArray()
    $payloadBw.Close()
    $payloadMs.Close()
    
    # 속성 메타데이터 작성
    $bw.Write($prefix)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("SavedSkins`0"))
    $bw.Write([int32]12)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("MapProperty`0"))
    $bw.Write([int64]$payloadData.Length)
    $bw.Write([int32]13)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("ByteProperty`0"))
    $bw.Write([int32]13)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("BoolProperty`0"))
    $bw.Write([byte]0) # tag
    $bw.Write($payloadData)
    
    # Trailer
    $bw.Write([int32]5)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("None`0"))
    $bw.Write([int32]0)
    
    $finalBytes = $ms.ToArray()
    $bw.Close()
    $ms.Close()
    
    [System.IO.File]::WriteAllBytes($filePath, $finalBytes)
    Write-Host "[성공] 45개 모든 스킨(0~44) 해금 주입 완료! (크기: $($finalBytes.Length) bytes)" -ForegroundColor Green
    return $true
}

function Patch-Achievements {
    param ([string]$filePath)
    
    if (-not (Test-Path $filePath)) {
        Write-Host "[안내] $filePath 파일이 아직 없습니다. 게임을 먼저 1회 실행하거나 기본 세이브 생성이 필요합니다." -ForegroundColor Yellow
        return $false
    }
    
    # 백업 생성
    $bakPath = $filePath + ".bak"
    Copy-Item -Path $filePath -Destination $bakPath -Force
    Write-Host "[백업] 기존 업적 세이브 백업 완료 -> $bakPath" -ForegroundColor DarkGray
    
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    
    # "Achievements`0" 위치 검색
    $searchPattern = [System.Text.Encoding]::ASCII.GetBytes("Achievements`0")
    $idx = -1
    for ($i = 0; $i -le ($bytes.Length - $searchPattern.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $searchPattern.Length; $j++) {
            if ($bytes[$i + $j] -ne $searchPattern[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            $idx = $i
            break
        }
    }
    
    if ($idx -eq -1) {
        Write-Host "[오류] Achievements 속성을 세이브 파일에서 찾을 수 없습니다." -ForegroundColor Red
        return $false
    }
    
    $prefix = New-Object byte[] $idx
    [System.Array]::Copy($bytes, 0, $prefix, 0, $idx)
    
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    
    # 23개 업적 엔트리 생성
    $entryMs = New-Object System.IO.MemoryStream
    $entryBw = New-Object System.IO.BinaryWriter($entryMs)
    
    for ($k = 0; $k -lt 23; $k++) {
        $nameBytes = [System.Text.Encoding]::ASCII.GetBytes("EAchievements::NewEnumerator$k`0")
        $entryBw.Write([int32]$nameBytes.Length)
        $entryBw.Write($nameBytes)
        $entryBw.Write([byte]1) # bool true
    }
    
    $entriesData = $entryMs.ToArray()
    $entryBw.Close()
    $entryMs.Close()
    
    # Map Payload: NumKeysToRemove (0), NumEntries (23), Entries
    $payloadMs = New-Object System.IO.MemoryStream
    $payloadBw = New-Object System.IO.BinaryWriter($payloadMs)
    $payloadBw.Write([int32]0)
    $payloadBw.Write([int32]23)
    $payloadBw.Write($entriesData)
    $payloadData = $payloadMs.ToArray()
    $payloadBw.Close()
    $payloadMs.Close()
    
    # 속성 메타데이터 작성
    $bw.Write($prefix)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("Achievements`0"))
    $bw.Write([int32]12)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("MapProperty`0"))
    $bw.Write([int64]$payloadData.Length)
    $bw.Write([int32]13)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("ByteProperty`0"))
    $bw.Write([int32]13)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("BoolProperty`0"))
    $bw.Write([byte]0) # tag
    $bw.Write($payloadData)
    
    # Trailer
    $bw.Write([int32]5)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("None`0"))
    $bw.Write([int32]0)
    
    $finalBytes = $ms.ToArray()
    $bw.Close()
    $ms.Close()
    
    [System.IO.File]::WriteAllBytes($filePath, $finalBytes)
    Write-Host "[성공] 23개 모든 업적(0~22) 해금 주입 완료! (크기: $($finalBytes.Length) bytes)" -ForegroundColor Green
    return $true
}

Write-Host "[1/3] 스킨 세이브 파일 패치 진행 중..." -ForegroundColor White
Patch-Skins -filePath $skinPath | Out-Null

Write-Host ""
Write-Host "[2/3] 업적 세이브 파일 패치 진행 중..." -ForegroundColor White
Patch-Achievements -filePath $achPath | Out-Null

Write-Host ""
Write-Host "[3/3] Steam 도전과제(Achievements) 직접 연동 중..." -ForegroundColor White
$steamScript = Join-Path $PSScriptRoot "unlock_steam_achievements.py"
if (Test-Path $steamScript) {
    try {
        & python $steamScript
    } catch {
        Write-Host "[경고] Python 실행 중 예외 발생: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  해금 완료! 모든 스킨/업적/Steam 도전과제가 적용되었습니다." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
