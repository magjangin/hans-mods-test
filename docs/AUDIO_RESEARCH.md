# 🎵 HANS 오디오 파이프라인 분석 & BGM 모딩 연구 기록 (Audio Research Notes)

> **연구자:** Lead Modder 화평  
> **대상 게임:** HANS (Steam AppID: 2616420 / Unreal Engine 5.1+ IoStore)

---

## 📌 핵심 발견 요약

인게임 오디오 옵션 메뉴의 하위 서브 채널(`음악`, `음향 효과`)을 런타임에서 100% 음소거하더라도, 특정 인게임 사운드 및 앰비언스가 하위 채널을 경유하지 않고 최상위 **`MASTER` 버스에 직접 직결(Direct Bypass Route)**되어 출력되는 순정 사운드 누수 현상이 확인되었습니다.

```mermaid
flowchart TD
    subgraph "HANS 오디오 라우팅 아키텍처"
        A[인게임 사운드 에셋 / MetaSound] --> B{사운드 클래스 라우팅}
        B -->|정상 서브 채널| C[음악 SoundClass]
        B -->|정상 서브 채널| D[음향 효과 SoundClass]
        B -->|누수 경로 (Bypass)| E[MASTER 최상위 버스 직결]
        
        C -->|모드로 뮤트 완료| F[차단됨 (Muted)]
        D -->|모드로 뮤트 완료| G[차단됨 (Muted)]
        E -->|필터링 우회| H[스피커로 소리 흘러나옴 (Sound Leak)]
    end
```

---

## 🔍 현상 분석 및 원인 규명

### 1. 인게임 설정 메뉴 슬라이더 계층 구조
HANS의 오디오 설정 UI(`AudioSettingsPage_C` / `AutoSettings`)는 다음 3개의 독립 슬라이더로 제어됩니다:
1. **MASTER** (최상위 마스터 사운드 클래스)
2. **음악 (Music)** (배경음악 전용 사운드 클래스)
3. **음향 효과 (SFX)** (효과음 전용 사운드 클래스)

### 2. 하위 2개 서브 채널 차단 검증
- 모드를 통해 `GI_Hans_C:MusicVolumeChanged(0.0)` 및 `GI_Hans_C:SFXVolumeChanged(0.0)`를 호출하고, 인게임의 `AudioComponent`를 직접 뮤트했을 때 **하위 2개 채널(`음악`, `음향 효과`)은 정상적으로 침묵 처리**됨을 확인했습니다.

### 3. MASTER 채널 직결 누수 (Root Cause)
- 특정 배경 음악, 환경 앰비언스, 또는 시스템 사운드 에셋이 `Music`이나 `SFX` 서브 사운드 클래스에 할당되지 않고 최상위 `MASTER` 사운드 클래스로 직접 라우팅되어 있습니다.
- 결과적으로 하위 채널을 아무리 완벽하게 꺼도 최상위 `MASTER` 채널을 타고 순정 소리가 스피커로 흘러나와 외부 커스텀 음원과 섞여 들리게 됩니다.

---

## 🛠️ 향후 BGM 교체 모딩을 위한 기술 로드맵

### 방안 A: 런타임 Master Bus 라우팅 가로채기
- 하위 서브 채널이 아닌 최상위 `MASTER` 사운드 클래스(`USoundClass`) 또는 기본 사운드 믹스(`DefaultBaseSoundMix`) 수준에서 라우팅 자체를 가로채거나 볼륨을 제어.
- 단점: 게임의 모든 사운드가 꺼질 수 있으므로 커스텀 사운드와의 섬세한 분리가 필요함.

### 방안 B: IoStore 에셋 레벨 교체 (가장 강력 권장)
- 런타임 메모리 후킹 대신, 언리얼 엔진 5의 IoStore 패키지(`Hans\Content\Paks\Hans-Windows.pak` / `.ucas`) 내부의 실제 BGM 에셋(`MetaSoundSource /Game/HANS/SFX/Music/Music.Music`)을 언리얼 모딩 툴(FModel, UnrealPak, Repak 등)로 분석.
- 해당 에셋 경로에 빈 무음 사운드 또는 교체할 음악 파일을 동일한 에셋 구조로 패키징하여 `Hans/Content/Paks/~mods` 폴더에 모드 PAK으로 주입.
- 장점: 엔진 코드나 볼륨 버스를 건드릴 필요 없이 순정 사운드 엔진이 커스텀 음원을 자체 순정 BGM으로 인식하여 100% 무결점 재생.
