# ==============================================================================
# HANS - All Skins & Achievements Unlocker (PowerShell)
# 45종 모든 스킨 및 23종 모든 업적을 세이브 파일에 해금 주입합니다.
# ==============================================================================
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

# 바이트와 문자가 1:1로 대응하는 인코딩이라 바이너리 안의 문자열 검색에 쓴다
$Latin1 = [System.Text.Encoding]::GetEncoding(28591)

# GVAS FString: int32 길이(널 문자 포함) + ASCII 바이트 + 널 문자
function Write-FString([System.IO.BinaryWriter]$writer, [string]$text) {
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($text + "`0")
    $writer.Write([int32]$bytes.Length)
    $writer.Write($bytes)
}

function Skip-FString([System.IO.BinaryReader]$reader) {
    $length = $reader.ReadInt32()
    $reader.BaseStream.Position += $length
}

# TMap<Enum, bool> 속성의 값을 <EnumPrefix>0 ~ <EnumPrefix>(Count-1) 전부 true로 바꿔 쓴다.
# 맵 뒤에 오는 속성(예: skinslot.sav의 SelectedMesh)은 그대로 둔다.
function Unlock-BoolMapSave {
    param (
        [string]$FilePath,
        [string]$PropertyName,
        [string]$EnumPrefix,
        [int]$Count,
        [string]$Label
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "[안내] $FilePath 파일이 아직 없습니다. 게임을 먼저 1회 실행하거나 기본 세이브 생성이 필요합니다." -ForegroundColor Yellow
        return $false
    }

    $bakPath = $FilePath + ".bak"
    Copy-Item -Path $FilePath -Destination $bakPath -Force
    Write-Host "[백업] 기존 $Label 세이브 백업 완료 -> $bakPath" -ForegroundColor DarkGray

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    # 속성 이름 앞의 int32 길이는 그대로 두고, 이름 문자열부터 새로 쓴다
    $nameStart = $Latin1.GetString($bytes).IndexOf("$PropertyName`0", [System.StringComparison]::Ordinal)
    if ($nameStart -lt 0) {
        Write-Host "[오류] $PropertyName 속성을 세이브 파일에서 찾을 수 없습니다." -ForegroundColor Red
        return $false
    }

    # 기존 태그(타입, 크기, 배열 인덱스, 키 타입, 값 타입, GUID 플래그)를 건너뛰어 맵 값이 끝나는 위치를 구한다
    $reader = [System.IO.BinaryReader]::new([System.IO.MemoryStream]::new($bytes))
    $reader.BaseStream.Position = $nameStart + $PropertyName.Length + 1
    Skip-FString $reader                       # MapProperty
    $oldSize = $reader.ReadInt32()
    $reader.BaseStream.Position += 4           # ArrayIndex
    Skip-FString $reader                       # ByteProperty
    Skip-FString $reader                       # BoolProperty
    if ($reader.ReadByte() -ne 0) { $reader.BaseStream.Position += 16 }  # PropertyGuid
    $restStart = [int]($reader.BaseStream.Position + $oldSize)
    $reader.Close()

    # 맵 값: NumKeysToRemove, NumEntries, (Enum 이름, bool) 목록
    $value = [System.IO.MemoryStream]::new()
    $valueWriter = [System.IO.BinaryWriter]::new($value)
    $valueWriter.Write([int32]0)
    $valueWriter.Write([int32]$Count)
    for ($k = 0; $k -lt $Count; $k++) {
        Write-FString $valueWriter "$EnumPrefix$k"
        $valueWriter.Write([byte]1)
    }
    $valueWriter.Flush()
    $valueBytes = $value.ToArray()
    $valueWriter.Close()

    $out = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($out)
    $writer.Write($bytes, 0, $nameStart)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("$PropertyName`0"))
    Write-FString $writer "MapProperty"
    $writer.Write([int32]$valueBytes.Length)
    $writer.Write([int32]0)                    # ArrayIndex
    Write-FString $writer "ByteProperty"
    Write-FString $writer "BoolProperty"
    $writer.Write([byte]0)                     # PropertyGuid 없음
    $writer.Write($valueBytes)
    $writer.Write($bytes, $restStart, $bytes.Length - $restStart)
    $writer.Flush()
    $finalBytes = $out.ToArray()
    $writer.Close()

    [System.IO.File]::WriteAllBytes($FilePath, $finalBytes)
    Write-Host "[성공] ${Count}개 모든 ${Label}(0~$($Count - 1)) 해금 주입 완료! (크기: $($finalBytes.Length) bytes)" -ForegroundColor Green
    return $true
}

Write-Banner "HANS - 모든 스킨 & 업적 해금 패처"
Write-Host ""

Write-Host "[1/3] 스킨 세이브 파일 패치 진행 중..." -ForegroundColor White
Unlock-BoolMapSave -FilePath (Join-Path $SaveDir "skinslot.sav") -PropertyName "SavedSkins" `
    -EnumPrefix "E_Skins::NewEnumerator" -Count 45 -Label "스킨" | Out-Null

Write-Host ""
Write-Host "[2/3] 업적 세이브 파일 패치 진행 중..." -ForegroundColor White
Unlock-BoolMapSave -FilePath (Join-Path $SaveDir "achslot.sav") -PropertyName "Achievements" `
    -EnumPrefix "EAchievements::NewEnumerator" -Count 23 -Label "업적" | Out-Null

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
Write-Banner "해금 완료! 모든 스킨/업적/Steam 도전과제가 적용되었습니다."
