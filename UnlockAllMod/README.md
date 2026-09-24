# UnlockAllMod for HANS (UE4SS)

Steam 인디 플랫포머 게임 **HANS**에서 존재하는 **모든 45종 스킨**과 **모든 23종 업적(Steam 도전과제 연동 포함)**을 실시간 또는 원클릭으로 100% 해금하는 올인원 언락 모드입니다.  
UE4SS(Unreal Engine 4/5 Scripting System) Lua API와 바이너리 세이브 엔진을 기반으로 구동됩니다.

---

## 🔬 기술 아키텍처 및 동작 원리

### 1. 언리얼 엔진 인게임 UFunction 후킹 & 호출
HANS 게임 내부의 스킨 및 업적 관리는 두 개의 핵심 매니저 액터가 담당합니다:

* **스킨 매니저 (`ABP_SkinManager_C`)**:
  * 멤버: `TMap<TEnumAsByte<E_Skins::Type>, bool> Skins`, `UBP_SaveSkins_C* SaveSkins`
  * 함수: `void UnlockASkin(TEnumAsByte<E_Skins::Type> UnlockedSkin);`
  * 총 45종 스킨 열거형: `E_Skins::Type::NewEnumerator0` (0) ~ `NewEnumerator44` (44)
  * 모드가 실행되면 `sm:UnlockASkin(i)`를 0부터 44까지 순차 호출하여 인게임 렌더링 메시 및 세이브 상태를 갱신합니다.

* **업적 매니저 (`ABP_AchievementManager_C`)**:
  * 멤버: `TMap<TEnumAsByte<EAchievements::Type>, bool> Achievements`, `UBP_SaveAchs_C* SaveAchs`
  * 함수: `void UnlockAchievement(TEnumAsByte<EAchievements::Type> Achievement);`
  * 총 23종 업적 열거형: `EAchievements::Type::NewEnumerator0` (0) ~ `NewEnumerator22` (22)
  * 언락 호출 시 게임 내 블루프린트가 `BP_Achievement_C` 액터를 스폰하며, 언리얼 엔진의 `UWriteAchievementProgressCallbackProxy` 노드를 통해 Steamworks API로 전달되어 **실제 Steam 도전과제 알림(Popup)이 즉시 발동**됩니다.

### 2. GVAS 바이너리 세이브 파일 직접 패치 (이중 안전장치)
인게임 액터가 로드되지 않은 메인 메뉴 화면이나 오프라인 상태에서도 100% 즉시 적용될 수 있도록, 언리얼 엔진의 바이너리 세이브 포맷(GVAS)을 직접 해석하여 패치합니다:

* **스킨 세이브:** `%LOCALAPPDATA%\Hans\Saved\SaveGames\skinslot.sav`
  * `MapProperty` 형식의 `SavedSkins` 블록을 45개 열거형(`E_Skins::NewEnumerator0` ~ `44`)과 `true`(`0x01`) 플래그로 덮어씁니다.
* **업적 세이브:** `%LOCALAPPDATA%\Hans\Saved\SaveGames\achslot.sav`
  * `MapProperty` 형식의 `Achievements` 블록을 23개 열거형(`EAchievements::NewEnumerator0` ~ `22`)과 `true`(`0x01`) 플래그로 덮어씁니다.

---

## 🎮 단축키 안내

| 단축키 | 넘패드 | 기능 | 설명 |
| :---: | :---: | :--- | :--- |
| **`F7`** | **`Num 7`** | **모든 스킨 해금 (All Skins)** | 45종 모든 수박 스킨을 즉시 해금하고 세이브에 영구 저장 |
| **`F8`** | **`Num 8`** | **모든 업적 해금 (All Achievements)** | 23종 모든 게임 업적 해금 및 Steam 도전과제 즉시 달성 |
| **`F9`** | **`Num 9`** | **올인원 전체 해금 (Unlock Everything)** | 스킨 45종 + 업적 23종 동시 전체 해금 |

* 기본 설정(`AutoUnlockOnStart = true`)에 의해 게임 실행 후 2초 뒤 백그라운드에서 전자동으로 1회 자동 해금이 수행됩니다.

---

## 📂 파일 구성

```text
UnlockAllMod/
├── enabled.txt          # UE4SS 모드 활성화 플래그
├── README.md            # 본 모듈 설명서
└── scripts/
    └── main.lua         # Lua 런타임 언락 및 바이너리 패처 구현체
```
