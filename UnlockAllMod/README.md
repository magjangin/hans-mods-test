# UnlockAllMod for HANS (UE4SS)

Steam 인디 플랫포머 게임 **HANS**에서 존재하는 **모든 45종 스킨**과 **모든 23종 업적(Steam 도전과제 연동 포함)**을 **키 입력 없이 게임 실행 시 100% 전자동으로 즉시 해금**하는 올인원 언락 모드입니다.  
UE4SS(Unreal Engine 4/5 Scripting System) Lua API와 바이너리 세이브 엔진을 기반으로 구동됩니다.

---

## ⚡ 전자동 해금 메커니즘 (Zero-Keypress)

본 모드는 **사용자가 어떠한 키도 누를 필요 없이**, 게임이 실행되는 즉시 다음 3단계 파이프라인을 통해 모든 스킨과 업적을 자동으로 완료합니다:

1. **디스크 세이브 선제적 자동 주입:** 모드 로드 시점에 즉시 `%LOCALAPPDATA%\Hans\Saved\SaveGames\`의 `skinslot.sav`와 `achslot.sav`를 바이트 단위로 패치하여, 메인 메뉴의 스킨 선택 화면에 진입하자마자 모든 스킨이 해금되어 있습니다.
2. **백그라운드 가디언 루프 (`LoopAsync 1000ms`):** 게임 레벨 또는 메인 메뉴가 로드되며 `BP_SkinManager_C` 및 `BP_AchievementManager_C` 액터가 메모리에 스폰되는 즉시 감지하여 45종 스킨 및 23종 업적 해금 함수를 1회 정밀 자동 호출합니다.
3. **Steam 도전과제 직접 연동 & 스팸 방지:** 스킨/업적 해금이 완료되면 가디언 루프가 자동으로 종료(`return true`)되어 **로그 스팸 및 불필요한 반복 호출을 100% 방지**하며, 네이티브 Steamworks 브릿지를 통해 **실제 Steam 도전과제 달성 알림(Popup)이 즉시 발동**됩니다.

---

## 🔬 기술 아키텍처 및 동작 원리

### 1. 언리얼 엔진 인게임 UFunction 자동 감지 & 호출
* **스킨 매니저 (`ABP_SkinManager_C`)**:
  * 멤버: `TMap<TEnumAsByte<E_Skins::Type>, bool> Skins`, `UBP_SaveSkins_C* SaveSkins`
  * 함수: `void UnlockASkin(TEnumAsByte<E_Skins::Type> UnlockedSkin);`
  * 총 45종 스킨 열거형: `E_Skins::Type::NewEnumerator0` (0) ~ `NewEnumerator44` (44)
  * 인게임 매니저 액터가 스폰되면 `sm:UnlockASkin(i)`를 0부터 44까지 순차 자동 호출하여 인게임 렌더링 메시 및 세이브 상태를 갱신합니다.

* **업적 매니저 (`ABP_AchievementManager_C`)**:
  * 멤버: `TMap<TEnumAsByte<EAchievements::Type>, bool> Achievements`, `UBP_SaveAchs_C* SaveAchs`
  * 함수: `void UnlockAchievement(TEnumAsByte<EAchievements::Type> Achievement);`
  * 총 23종 업적 열거형: `EAchievements::Type::NewEnumerator0` (0) ~ `NewEnumerator22` (22)
  * 언락 호출 시 게임 내 블루프린트가 `BP_Achievement_C` 액터를 스폰하며, 언리얼 엔진의 `UWriteAchievementProgressCallbackProxy` 노드를 통해 Steamworks API로 전달되어 **실제 Steam 도전과제 알림(Popup)이 즉시 발동**됩니다.

### 2. GVAS 바이너리 세이브 파일 직접 패치
* **스킨 세이브:** `%LOCALAPPDATA%\Hans\Saved\SaveGames\skinslot.sav`
  * `MapProperty` 형식의 `SavedSkins` 블록을 45개 열거형(`E_Skins::NewEnumerator0` ~ `44`)과 `true`(`0x01`) 플래그로 덮어씁니다.
* **업적 세이브:** `%LOCALAPPDATA%\Hans\Saved\SaveGames\achslot.sav`
  * `MapProperty` 형식의 `Achievements` 블록을 23개 열거형(`EAchievements::NewEnumerator0` ~ `22`)과 `true`(`0x01`) 플래그로 덮어씁니다.

---

## 🎮 비상 수동 단축키 (선택 사항)

기본적으로 전자동으로 해금되므로 키를 누를 필요가 없으나, 필요 시 수동으로 재호출할 수 있는 단축키도 제공됩니다:

| 단축키 | 넘패드 | 기능 | 설명 |
| :---: | :---: | :--- | :--- |
| **`F7`** | **`Num 7`** | **모든 스킨 수동 해금** | 45종 모든 수박 스킨을 즉시 수동 재해금 |
| **`F8`** | **`Num 8`** | **모든 업적 수동 해금** | 23종 모든 게임 업적 수동 재해금 및 Steam 도전과제 재전송 |
| **`F9`** | **`Num 9`** | **올인원 전체 수동 해금** | 스킨 45종 + 업적 23종 동시 전체 재해금 |

---

## 📂 파일 구성

```text
UnlockAllMod/
├── enabled.txt          # UE4SS 모드 활성화 플래그
├── README.md            # 본 모듈 설명서
└── scripts/
    └── main.lua         # Lua 런타임 언락 및 바이너리 패처 구현체
```
