# GravityMod for HANS (UE4SS)

Steam 인디 플랫포머 게임 **HANS**를 위한 실시간 중력 및 캐릭터 물리 파라미터 조작 모드입니다.  
UE4SS(Unreal Engine 4/5 Scripting System) Lua API를 기반으로 구동됩니다.

---

## 🔬 기술 아키텍처 및 내부 원리

### 1. 언리얼 엔진 물리 파이프라인 분석
언리얼 엔진 캐릭터 무브먼트 컴포넌트(`UCharacterMovementComponent`)에서 캐릭터가 매 프레임 체감하는 실제 중력 가속도는 다음과 같이 계산됩니다:

$$\text{Effective Gravity Z} = \text{WorldSettings:GetGravityZ()} \times \text{CharacterMovement.GravityScale}$$

일반적으로 모드 개발 시 `WorldSettings.WorldGravityZ` 필드만 단독 수정하는 경우가 많으나, UE4의 `AWorldSettings::GetGravityZ()` 내부 로직상 `bGlobalGravitySet` 플래그가 비활성화되어 있으면 프로젝트 디폴트 중력값(`DefaultGravityZ`)으로 값을 재평가(Re-derive)하여 덮어쓰므로 변경 사항이 영구히 유지되지 않는 문제가 발생합니다.

본 모드는 이를 극복하기 위해 다음과 같은 방식으로 엔진 코어 파라미터를 조작합니다:
1. 게임 시작 시 `CaptureOriginalsOnce()`를 통해 순정 상태의 물리 파라미터(`OriginalWorldGravityZ`, `OriginalGlobalGravityZ`, `OriginalGravityScale`)를 메모리에 1회 완벽 백업합니다.
2. 중력 변경 시 `WorldSettings.GlobalGravityZ`를 목표값으로 설정하고, `WorldSettings.bGlobalGravitySet = true`를 활성화합니다.
3. 캐릭터 무브먼트의 개별 `GravityScale`은 게임 고유의 설계(점프/낙하 감쇠율 등)를 해치지 않도록 유지합니다.

### 2. 비동기 가디언 루프 (LoopAsync Guardian Loop)
게임 진행 도중 레벨이 전환(Level Streaming 또는 Seamless/Non-Seamless Travel)되거나 플레이어가 체크포인트에서 리스폰되면, 언리얼 엔진은 새로운 `WorldSettings` 액터를 생성하고 중력을 기본값(`-980.0`)으로 초기화합니다.

이를 방지하기 위해 `LoopAsync(250ms)` 비동기 백그라운드 태스크를 실행합니다:
- 250ms 주기로 `WorldSettings.bGlobalGravitySet` 및 `GlobalGravityZ`의 드리프트(Drift)를 감지합니다.
- 값이 엔진 기본값으로 초기화된 경우, `ExecuteInGameThread()`를 호출하여 메인 게임 스레드 안전성을 확보하면서 사용자가 설정한 중력으로 즉각 재적용합니다.

---

## 🎮 단축키 및 모드 프리셋 상세

| 단축키 | 넘패드 | 프리셋 이름 | 중력 배율 | 계산된 GravityZ | 동작 및 물리 특성 |
| :---: | :---: | :--- | :---: | :---: | :--- |
| **`F1`** | **`Num 1`** | **원래 상태 (Original)** | `1.0x` | `-980.0` | 백업해둔 순정 게임 기본 물리 및 글로벌 중력 상태로 완전 복원 |
| **`F2`** | **`Num 2`** | **저중력 (Low)** | `0.25x` | `-245.0` | 완만한 낙하 속도 및 긴 체공 시간 제공 |
| **`F3`** | **`Num 3`** | **달 중력 (Moon)** | `0.08x` | `-78.4` | 달 표면 수준의 초저중력으로 고난도 도약 구간 돌파에 용이 |
| **`F4`** | **`Num 4`** | **완전 무중력 (Zero)** | `0.0x` | `0.0` | 수직 낙하 속도를 `LaunchCharacter(Z=0)`로 즉시 상쇄하여 완전 공중 정지 |
| **`F5`** | **`Num 5`** | **공중 부유 (Floating)** | `0.05x` | `-49.0` | `LaunchCharacter(Z=750)` 상승 임펄스를 1회 부여한 뒤 천천히 하강 부유 |
| **`↑`** | - | **위쪽 추진 (Thrust)** | - | - | 무중력(0.0x) 또는 초저중력(0.1x 이하) 상태에서 위쪽으로 `400` 추진력 부여 |
| **`F6`** | - | **상태 진단 (Status)** | - | - | 콘솔창에 현재 중력, `GravityScale`, `Effective Gravity`, `JumpZVelocity` 출력 |

---

## 📂 파일 구성

```text
GravityMod/
├── enabled.txt          # UE4SS 모드 활성화 플래그 파일
├── README.md            # 본 모듈 설명서
└── scripts/
    └── main.lua         # Lua 소스 코드
```

---

## ⚙️ 커스터마이징 가이드

중력 배율이나 추진력을 변경하고 싶다면 `GravityMod/scripts/main.lua` 파일을 텍스트 에디터로 열어 아래 부분을 수정할 수 있습니다:

```lua
-- F2 배율 변경 예시 (기본 0.25 -> 0.15로 더 가볍게)
RegisterKeyBind(Key.F2, function() ApplyGravity(0.15, "커스텀 저중력 (Custom 0.15x)") end)

-- F5 상승 임펄스 세기 변경 (기본 Z=750 -> 1000)
player:LaunchCharacter({X = 0, Y = 0, Z = 1000}, false, true)
```
