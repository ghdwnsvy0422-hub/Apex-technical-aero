# Apex — 작업 규약

온라인 경쟁 레이싱 게임. 기획은 `docs/PRD.md`, 제작 계획과 단계 분할은 `docs/PRODUCTION_PLAN.md`.

**이 프로젝트는 100% 바이브 코딩으로 만든다.** 사람은 GUI 에디터를 열지 않는다. 따라서 GUI에서만 가능한 작업에 의존하는 설계는 채택하지 않는다.

---

## 스택

| | |
|---|---|
| 엔진 | Godot 4.4 (Forward+) |
| 언어 | GDScript (정적 타입 필수) |
| 물리 | Jolt Physics, 120Hz 고정 틱 |
| 서버 | 동일 프로젝트의 헤드리스 빌드 (서버 권위) |
| 백엔드 | Go + PostgreSQL + Redis (`/backend`) |

---

## 실행

Godot 바이너리는 리포에 포함하지 않는다. `bin/`은 gitignore되어 있다.

```bash
# 최초 1회: 고정 버전(4.4-stable) 설치 → bin/godot
./tools/install_godot.sh

# 커밋 전 게이트: 임포트 + 환경 자가 검증 + 전체 테스트
./tools/check.sh
```

엔진 버전을 고정하는 이유는 업데이트가 물리 거동을 조용히 바꾸기 때문이다. 그러면 원인 불명의 랩타임 회귀로 나타난다.

개별 실행은 `tools/godot.sh`를 거친다(`$GODOT` → `bin/godot` → PATH 순으로 탐색).

```bash
./tools/godot.sh --path game                                    # 클라이언트
./tools/godot.sh --headless --path game -- --selfcheck          # 환경 검증
./tools/godot.sh --headless --path game -- --server --port=27015  # 전용 서버
./tools/godot.sh --headless --path game -- --sim                # 시뮬 하네스
```

---

## 디렉터리

```
game/core     결정론적 시뮬레이션 코어 (물리, 차량, 타이어, 손상)
game/net      복제, 클라 예측, 서버 재조정
game/track    스플라인 → 절차적 트랙 메시 생성
game/data     부품 / 트랙 / 티어 정의 (JSON)
game/ui       Control 노드 + 테마
game/server   헤드리스 진입점, 룸 관리
game/tests    GUT 테스트 + 시뮬 하네스
tools/        트랙 DSL 컴파일러, 밸런스 스윕, 캡처
backend/      Go 서비스
docs/         PRD, 제작 계획, 밸런스 노트
```

---

## 코드 규약

### 정적 타입은 필수다

```gdscript
var speed: float = 0.0
func apply_downforce(velocity: Vector3) -> Vector3:
```

타입 없는 선언은 경고로 잡힌다(`project.godot`의 `untyped_declaration=1`). 예외는 없다.

### 이름

| 대상 | 규칙 |
|---|---|
| 파일 / 디렉터리 | `snake_case.gd` |
| 클래스 (`class_name`) | `PascalCase` |
| 함수 / 변수 | `snake_case` |
| 내부 전용 | `_leading_underscore` |
| 상수 / enum 값 | `SCREAMING_SNAKE_CASE` |
| 시그널 | 과거형 (`lap_completed`, `car_retired`) |

식별자와 코드 주석은 영어로 쓴다. 문서(`docs/`)는 한국어로 쓴다.

### 주석

기본은 주석 없음. 코드가 무엇을 하는지는 이름으로 드러낸다. 주석은 **왜**가 자명하지 않을 때만 쓴다 — 숨은 제약, 비직관적 불변식, 특정 버그 우회.

`##` 독스트링은 파일 최상단 클래스 설명과 공개 API에만 붙인다.

---

## 아키텍처 규칙

### 1. `game/core`는 헤드리스에서 돌아야 한다

시뮬레이션 코어는 렌더링, 입력, UI, 씬 트리 구조에 의존하지 않는다. 그래야 전용 서버와 AI 드라이버 하네스가 같은 코드를 돌린다. 코어에서 `get_viewport()`, `Input.*`, 카메라 참조는 금지.

입력은 **값으로 주입**한다:

```gdscript
func simulate(input: DriverInput, delta: float) -> void:
```

`Input.get_axis()`를 코어 안에서 직접 부르지 않는다. 그렇게 하면 서버가 그 코드를 못 돌린다.

### 2. `VehicleBody3D`를 쓰지 않는다

Godot 내장 차량 노드는 아케이드용이라 타이어 마모(PRD §29), 다운포스 트레이드오프(§27), 부위별 손상(§31)을 넣을 수 없다. 차량은 `RigidBody3D` + 커스텀 레이캐스트 서스펜션 + 슬립 기반 타이어 모델로 직접 구현한다.

### 3. 물리는 `_physics_process`에서만

가변 프레임레이트(`_process`)에서 물리 상태를 건드리면 클라와 서버 결과가 갈린다. 시뮬레이션 상태 변경은 전부 고정 틱 안에서 한다.

### 4. 서버가 판정한다

순위, 랩, 충돌, 완주, ELO는 서버 결과가 진실이다(PRD §89). 클라이언트는 예측하고 서버가 정정한다. 클라이언트가 보낸 결과값을 신뢰하는 코드를 쓰지 않는다.

### 5. 콘텐츠는 코드가 아니라 데이터다

트랙, 부품, 리버리, 티어 구간은 `game/data`의 JSON이다. 콘텐츠를 추가하려고 `.gd` 파일을 새로 만들고 있다면 설계가 잘못된 것이다.

모든 데이터 파일은 `schema_version`을 갖고 `DataRegistry`가 부팅 시 검증한다. **새 데이터 종류를 추가하면 검증기도 같이 추가한다.** 검증 없는 스키마는 희망사항이고, 잘못된 콘텐츠는 크래시가 아니라 "조용히 이상한 차"로 나타나서 추적이 어렵다.

스탯 / 슬롯 / 등급 식별자는 `CarStats`가 단일 출처다. 문자열을 직접 하드코딩하지 않는다.

### 6. 애셋은 절차적 생성 또는 CC0

`.blend`, 손으로 그린 텍스처에 의존하지 않는다. 트랙은 스플라인에서 생성하고, 리버리는 셰이더 파라미터로 만든다. 외부 애셋은 CC0 / OFL / Apache-2.0만 쓰고 `docs/ASSET_CREDITS.md`에 출처를 남긴다.

### 7. 로그는 `Log` 오토로드로

`print()`를 직접 쓰지 않는다. 전용 서버 로그가 갈라지면 원인 추적이 불가능해진다.

```gdscript
Log.info("Race", "Lap %d completed by %s" % [lap, driver_name])
```

---

## 검증

AI가 "됐습니다"라고 말하는 것과 실제로 되는 것은 다르다. 변경 후에는 `./tools/check.sh`를 **실제로 실행해** 확인한다. 이 게이트는 다음을 순서대로 돌린다.

1. 리소스 임포트
2. 환경 자가 검증(`--selfcheck`) — Jolt 활성, 120Hz, 입력 액션 존재
3. GUT 단위 테스트 (`game/tests`)
4. AI 드라이버 랩타임 회귀 (Phase 1.7 이후 추가)

테스트는 `game/tests/unit/test_*.gd`에 두고 `GutTest`를 상속한다. 순수 로직은 `static` 함수로 빼서 노드 인스턴스 없이 테스트한다 — 코어가 헤드리스에서 돌아야 한다는 규칙과 같은 이유다.

물리 변경은 특히 조용히 망가진다. "고쳤는데 차가 못 달리게 됨"은 사람이 아니라 랩타임 회귀 테스트가 잡아야 한다.

---

## Git

- 모든 작업은 `main`에 커밋/푸시한다.
- 커밋 메시지 제목은 영어 명령형, 본문은 **왜**를 쓴다. 무엇을 바꿨는지는 diff에 있다.
- 접두어: `feat:` `fix:` `refactor:` `docs:` `test:` `chore:`
