# Apex — 개발 현황

실제 개발 진행 상황의 기록이다. 규칙은 `CLAUDE.md`, 설계 결정과 물리 함정은 `handoff.md`, 요구사항은 `docs/PRD.md`와 `docs/PRODUCTION_PLAN.md`에 있다.

## 갱신 규칙

- 작업이 끝날 때마다 이 문서를 갱신하고 같은 커밋 또는 바로 다음 커밋에 포함한다.
- 상태는 `완료` / `진행 중` / `미착수` / `미확인` / `차단` 다섯 가지만 쓴다.
- `완료`는 아래 "마지막 검증"에 기록된 명령으로 확인한 항목에만 쓴다. 확인하지 못했으면 `미확인`이다.
- 사람의 판정이 필요한 게이트(Phase 1 "운전이 재미있는가")는 사람이 판정하기 전까지 통과로 쓰지 않는다.
- 이 문서에 쓴 수치는 근거(명령, 로그, 커밋)와 함께 쓴다.

---

## 1. 현재 단계

**Phase 1 마무리 직전 — 1.8 드라이빙 필 튜닝과 Phase 1 게이트 대기.**

- Stage 0.1~0.3과 Phase 1.1~1.7이 구현되어 있고 자동 검증을 통과한다.
- 남은 것은 1.8이며, 사람이 직접 몰아본 판정이 필요하다. 이 판정 전에는 Phase 2 이후를 시작하지 않는다.
- 근거: `handoff.md` §2, §10 및 아래 §2의 `check.sh` 통과.

## 2. 마지막 검증

| 항목 | 내용 |
|---|---|
| 일시 | 2026-11-11 |
| 기준 커밋 | `7b3d7bf` (origin/main HEAD) |
| 환경 | 클라우드 컨테이너, 디스플레이 없음, Godot 4.4.stable.official.4c311cbee (`./tools/install_godot.sh`로 설치) |
| 명령 | `./tools/check.sh` |
| 결과 | **통과** (종료 코드 0, 소요 약 28초) |
| GUT 단위 테스트 | 13 스크립트, 173 테스트 전부 통과, 1430 assert |
| 환경 자가 검증 | 통과 (Jolt, 120Hz, 데이터 로드: 부품 12, 티어 7, 컴파운드 3, 트랙 1) |
| 물리 프로브 | 28개 PASS. 0-100 km/h 4.13 s, 0-200 km/h 7.17 s, 218 km/h에서 제동 평균 2.1 g, 최고속 350 km/h(저다운포스) / 280 km/h(고다운포스), 노면 그립 road 1.00 / runoff 0.55 |
| AI 랩타임 회귀 | 통과. Aurora 플라잉 랩 1:04.467, 기준값 1:04.467, 편차 0.000 s. 이론 랩 1:01.363 |
| 클라이언트 헤드리스 부팅 | `./tools/godot.sh --headless --path game --quit-after 120` 정상 부팅(`Client boot`, `TestDrive: Ready`) |
| 전용 서버 모드 | `./tools/godot.sh --headless --path game -- --server --port=27015` 부팅 로그(`mode=DEDICATED_SERVER`, `Dedicated server boot (port 27015)`)만 확인. 네트워킹은 없음 |
| 실행하지 않은 것 | `./tools/sweep.sh`(수 분 소요), `./tools/screenshot.sh`, 사람이 직접 주행, GitHub Actions 결과 |

관찰된 경고:

- 물리 프로브 중 `Jolt Physics job system exceeded the maximum number of jobs` 경고가 1회 출력된다. 테스트는 통과했고 원인은 조사하지 않았다. (§6 참조)
- GUT 요약에 `Total orphans = 18`이 출력된다. `handoff.md` §6.13에 따르면 GUT 자체 객체가 섞인 값이며 누수 감시는 `assert_no_new_orphans()`로 한다.

## 3. 작업 현황 (제작 계획 작업 번호 기준)

| 작업 | 상태 | 근거 / 비고 |
|---|---|---|
| Stage 0.1 프로젝트 골격 | 완료 | `game/project.godot`, 폴더 구조, `.gitignore`, `CLAUDE.md`. 헤드리스 부팅 확인. 세부 감사는 `STAGE_0_1_PROMPT` 미실행 |
| Stage 0.2 검증 게이트(GUT + CI) | 완료 | `tools/check.sh` 통과. CI 워크플로(`.github/workflows/ci.yml`)는 `push: main`과 `pull_request`에서만 돈다. 실행 결과는 R8 참조 |
| Stage 0.3 데이터 스키마 + 검증 로더 | 완료 | `DataRegistry` 부팅 검증 통과, `test_data_registry.gd` 통과 |
| Phase 1.1 차량 물리 코어 | 완료(자동 검증 범위) | `RigidBody3D` + 레이캐스트 서스펜션 + 슬립 기반 타이어. 프로브 통과. 조종감은 미판정 |
| Phase 1.2 입력 / 카메라 / 주행 씬 | 완료(자동 검증 범위) | `test_player_input.gd` 통과. 실제 키보드/패드 조작은 미확인 |
| Phase 1.3 트랙 지오메트리 | 완료 | `test_track_geometry.gd`, 프로브 통과. 시각 확인은 이번 세션에서 미실행 |
| Phase 1.4 트랙 DSL 컴파일러 | 완료 | Aurora 4032 m 컴파일, 닫힘 검증 통과 |
| Phase 1.5 랩 / 섹터 / 역주행 | 완료 | `test_lap_timer.gd` 통과 |
| Phase 1.6 레이싱 라인 + 속도 프로파일 | 완료 | `test_racing_line.gd` 통과. 기본 상수(횡 2.2 g, 최고속 350 km/h)가 기본 차량의 실측(2.41 g, 310 km/h)과 다르다(B6) |
| Phase 1.7 헤드리스 AI 드라이버 | 완료 | 랩타임 회귀 통과. 사람 대비 +5.1% 느림, 저다운포스 차량 제어 한계(§7) |
| PART C-4 파라미터 스윕 | 완료(도구) | `tools/sweep.sh` 실행(2026-11-11, 84초, 종료 코드 0). 결과가 `handoff.md` §6.17 표와 전 행 일치 |
| **Phase 1.8 드라이빙 필 튜닝** | **미착수** | 사람이 직접 주행하고 피드백을 줘야 시작 가능 |
| Phase 1 게이트 "운전이 재미있는가" | **미판정** | 사람이 20분 이상 주행해 판정. 자동화 불가 |
| Phase 2 (멀티플레이: 2.1~2.7) | 미착수 | `game/net`, `game/server`는 `.gitkeep`뿐. `--server` 모드는 `main.gd`에서 부팅 로그 한 줄만 남기며 네트워킹 코드는 없음 |
| Phase 3 (차량 제작: 3.1~3.9) | 미착수 | 일부 선행 요소만 존재: `parts.json` 12종, `CarStats`, `tyre_compounds.json` 3종, `PerformanceEnvelope`. 부품 시스템/Garage/손상은 미구현 |
| Phase 4 (퀄리파잉 + 전략: 4.1~4.8) | 미착수 | |
| Phase 5 (ELO / 백엔드: 5.1~5.8) | 미착수 | `backend/`는 `.gitkeep`뿐 |
| Phase 6 (라이브 콘텐츠: 6.1~6.11) | 미착수 | |

## 4. 진행 중인 작업

없음.

## 5. 미착수 작업

§3의 `미착수` 항목 전체. 착수 순서는 §8을 따른다.

## 6. 발견된 버그와 기술적 문제

| # | 내용 | 상태 | 비고 |
|---|---|---|---|
| B1 | 물리 프로브 실행 중 Jolt 경고 `job system exceeded the maximum number of jobs` | 미확인(원인 미조사) | 테스트는 통과. 프로브가 `--fixed-fps 30`에서 틱을 몰아 돌리는 구성과 관련 있는지 확인 필요. 서버/클라 실제 주행에서도 나오는지 미확인 |
| B2 | 기존 코드에 주석이 많다. `CLAUDE.md`의 주석 금지 규칙은 `40dc384`에서 추가되었고 이전에 작성된 파일은 그대로다. `game/` 내 `.gd` 46개 중 33개(grep 기준)와 `tools/*.sh` 5개 전부, `tiers.json`/`parts.json`의 `_comment` 필드에서 확인 | 미결 | 일괄 삭제는 범위 밖 변경이므로 하지 않음. 삭제 여부는 사용자 결정 필요 |
| B3 | `handoff.md` §5가 "같은 GDScript 물리를 돌리므로 서버 권위 판정이 구조적으로 공짜"라고 적고 있다. 동일 코드가 동일 결과를 보장하지 않으므로(`CLAUDE.md` 기술적 제약) 과대 표현이다 | 미결 | `handoff.md`는 이번 문서 작업 범위 밖이라 수정하지 않음 |
| B5 | 문서 간 불일치(코드 변경 불필요, 문서만 해당). (1) `handoff.md` §2 "이론 랩타임 약 58초" ↔ 같은 문서와 `lap_probe` 출력의 1:01.363. (2) `handoff.md` §7 "모든 작업은 `main`에 커밋/푸시" ↔ `CLAUDE.md` Git 절(브랜치 지정 우선). (3) `handoff.md` §8 디렉터리 목록에 `docs/prompts`, `DEVELOPMENT_STATUS` 없음. (4) `PRODUCTION_PLAN` A-2 구조에 `game/ai`, `game/client` 없음(`CLAUDE.md`에는 있음). (5) `PRODUCTION_PLAN` A-1 "클라/서버 물리 불일치가 구조적으로 발생하지 않는다" ↔ `CLAUDE.md` 기술적 제약(B3과 같은 성격). (6) `PRODUCTION_PLAN` Phase 3 게이트의 "(§7 검증)"은 문맥상 §27. (7) `PRODUCTION_PLAN` 1.5 "체크포인트 통과 판정" ↔ 구현은 센터라인 오프셋 기반(`handoff.md` §6.11에 사유 기재). (8) `PRODUCTION_PLAN` B-1 DSL 예시(`{"straight": 850}`, `drs_zones`) ↔ 실제 형식(`{"kind": "straight", "length_m": 850}`, `pit` 객체). (9) `main.gd` 상단 독스트링 "Stage 0.1 has no gameplay scenes yet"는 낡은 기존 주석 | 미결 | `handoff.md`, `PRODUCTION_PLAN.md`는 수정 금지/승인 대상이라 기록만 함 |
| B6 | `RacingLine` 기본 상수가 기본 차량과 맞지 않는다. `DEFAULT_TOP_SPEED_KPH = 350`은 다운포스 1.5의 최고속이고 기본 차량(다운포스 4.0)은 310 km/h다. `DEFAULT_LATERAL_G = 2.2`도 실측 2.41 g보다 낮다(스윕 엔벌로프 출력). `handoff.md` §6.14는 "프로브 실측값에서 가져왔다"고 적는다 | 미결 | 랩타임 회귀의 "이론 랩 1:01.363"과 "이론 대비 +5.1%"는 이 상수 기준이다. 상수를 고치면 AI 목표 속도가 바뀌어 기준값이 움직이므로 별도 승인 작업 |
| B7 | `DriverInput.energy`, 입력 액션 `energy_boost`/`pit_request`는 정의만 있고 소비하는 코드가 없다(`grep` 확인). `parts.json` 12종에 `grade` 필드가 없다 | 정상(미착수 단계) | Phase 4.6 / 4.5 / 3.1 작업 대상. 버그 아님 |
| B8 | 저장소에 병행 구현이 있다. 열린 PR #2(`claude/project-understanding-next-tasks-vmsblv` → `main`, 2026-09-10)는 커밋 메시지 기준으로 Stage 0을 다른 구조(60 Hz, `verify.sh`, `HANDOVER.md`/`PROGRESS.md`)로 다시 만들고 Phase 1.8 조종감 프로브를 넣었다. 현재 `main`/이 브랜치와 구조가 다르다 | 미결(사용자 결정) | GitHub Actions 조회 중 발견. 내용은 읽지 않았고 병합 가능 여부도 미확인 |
| B4 | `CLAUDE.md` 구판은 "모든 작업은 `main`에 커밋/푸시"였다. 세션이 작업 브랜치를 지정하는 경우와 충돌해 이번에 브랜치 지정 우선으로 정리함 | 해결(문서) | |

## 7. 해결되지 않은 기술적 위험

| # | 위험 | 영향 | 비고 |
|---|---|---|---|
| R1 | **조종감 미검증** | 프로젝트 근간. 계획서 PART G 최대 리스크 | 사람이 주행해야 함 |
| R2 | 정지 풀스로틀 휠스핀이 플레이어에게 가혹한지 미판정 | 조작 접근성, PRD §58 보조 | 1.8에서 결정 |
| R3 | AI가 저다운포스 차량을 완주하지 못함(다운포스 2.0 DNF, 3.0은 이론 랩 +10.3 s) | Phase 3.9 밸런스 스윕의 선결 조건 | `handoff.md` §6.17 |
| R4 | 스윕이 트랙 1개만 봄 | PRD §27의 "트랙마다 최적 세팅 상이" 미검증 | Phase 6.1 이후 |
| R5 | 서버/클라 물리 동일 코드의 결과 일치 미보장, 클라 예측·되감기 재조정 가능 여부 미검증 | Phase 2 전체. 억울한 충돌 방지(PRD §90) | Phase 2.1에서 별도 검증 |
| R6 | 랩 판정이 센터라인 근접 거리 기반이라 피트레인 도입 시 전제가 깨짐 | Phase 4.5 | `handoff.md` §6.11 |
| R7 | 랩타임 기준값(`BASELINE_LAP_S`)이 현재 차량 세팅에 묶임 | 의도적 물리 변경 시 사유 없이 옮기면 게이트 무력화 | `CLAUDE.md` 검증 절 |
| R8 | CI 실제 실행 결과 미확인 | 원격 게이트 신뢰성 | GitHub Actions 확인 필요 |
| R9 | 8인 서버 물리 부하 미측정 | Phase 2.7 | |
| R10 | 차량 상태가 직렬화/복원 단위로 묶여 있지 않다. 재현에 필요한 상태는 `RigidBody3D` 변환·선속도·각속도, `CarBody.gear`/`engine_rpm`/`_shift_timer`/`_shift_cooldown`, 바퀴 4개의 `angular_velocity`다. `teleport_to()`는 초기화만 하고 임의 상태 복원 API는 없다. Jolt 내부 상태(접촉 캐시)는 GDScript에서 저장할 수 없다 | Phase 2.1 클라 예측/재조정. 되감기 재시뮬레이션 가능 여부가 미결인 이유 | 근거: `core/car_body.gd`, `core/wheel.gd`. 입력은 `DriverInput` 값으로 주입되고 난수는 쓰지 않는다(`grep` 0건) |
| R11 | 물리 스텝이 씬 트리의 `_physics_process`와 Jolt 전역 스텝에 묶여 있어 차 한 대만 따로 N틱 재시뮬레이션할 수 없다(`PhysicsServer3D` 수동 스텝 미사용) | Phase 2.1. 서버 재조정 방식 선택을 제약 | 추측 아님: `CarBody._physics_process`가 `apply_force` 후 엔진 스텝에 맡김. 대안 비교는 2.1의 아키텍처 검토에서 수행 |
| R12 | 게이트가 못 보는 회귀: (a) 좌우 대칭성(Aurora는 우회전 서킷이고 프로브도 우조향만 봄), (b) 연석/런오프 주행 거동, (c) 고저차·뱅킹(`banking_deg`가 데이터에 있으나 주행 검증 없음), (d) 실시간 프레임 페이싱(게이트는 전부 `--fixed-fps`), (e) 렌더링/HUD(캡처는 게이트 밖) | 조용한 회귀 | (a)는 근거: `physics_probe.gd`의 `_probe_cornering`은 `steer=+1.0`만 사용. (c)는 미확인 |
| R13 | 이론 랩(`ideal lap`)이 낙관적이다. `PerformanceEnvelope`는 가속도를 100→200 km/h 구간에서 한 번 재서 전 속도에 적용하므로 고속에서 도달 불가능한 목표가 나온다 | 스윕의 `driven − ideal` 격차를 드라이버 실력으로 읽으면 틀림. Phase 3.9 | D 작업에서 측정. §2 스윕 절 참조 |

## 8. 다음 작업 우선순위와 완료 조건

2026-11-11 `MASTER_PROMPT` 실행으로 수립한 계획이다. `PRODUCTION_PLAN.md` PART D 순서를 따른다. "착수 가능" 열이 `아니오`인 작업은 선행 조건이 풀리기 전에는 시작하지 않는다.

| 순위 | 작업 | 목표 / 완료 조건 | 검증 기준 | 선행 | 영향 범위 / 위험 | 착수 가능 |
|---|---|---|---|---|---|---|
| 1 | **Phase 1.8 + Phase 1 게이트 (사람)** | 사람이 20분 이상 주행해 YES/NO 판정. NO면 문제점 목록을 남긴다. 판정은 본 문서에 기록 | `./tools/godot.sh --path game` 직접 주행. 볼 항목은 `handoff.md` §10의 4개 | 디스플레이가 있는 PC | 없음(코드 변경 전). R1, R2 | **사람만 가능** |
| 1a | 1.8 튜닝 반복 (판정이 NO일 때) | 사람이 적은 문제점 1건당 1세션. 변경마다 `check.sh` 통과, 랩타임 기준값 이동 시 사유 기록, 스윕 표 전후 비교 | `check.sh`, `sweep.sh`, 사람 재주행 | 1의 피드백 | `game/core` 차량 파라미터. R7 | 피드백 수신 후 |
| 2 | 이론 랩 정확도 개선 (R13, B6) | 엔벌로프가 속도 구간별 가속도를 재고 `RacingLine` 기본 상수를 기본 차량 실측에 맞춘다. 완료 조건: 스윕에서 풀스로틀 구간 손실이 랩당 1.0초 미만 | `sweep.sh` 전후 표, 랩타임 기준값은 사유와 함께 갱신 | 사용자 승인(기준값 이동 수반) | `game/track/racing_line.gd`, `game/tests/sim`. 기준값 이동 | 승인 후 |
| 3 | 게이트 공백 보강 (R12) | 좌조향 프로브, 뱅킹 구간 주행 프로브 추가 | `check.sh`에 새 PASS 줄 | 없음 | `game/tests/sim/physics_probe.gd`만 | 예(지시가 있을 때) |
| 4 | Phase 2.1 네트워크 아키텍처 | (1) 아키텍처 검토 보고서: 예측/보정 방식 후보 비교, R10·R11에 대한 답 (2) 승인 후 구현 (3) 지연/손실 시뮬레이션에서 8대 완주 | 보고서 승인, 헤드리스 다중 인스턴스 테스트 | **1의 YES** | `game/net`, `game/server`, `core/car_body.gd`(상태 저장/복원) | 아니오 |
| 5 | Phase 2.2~2.7 | 계획서 표의 각 항목. 세션당 1항목 | Phase 2 게이트: 8명이 억울한 충돌 없이 완주 | 4 | `game/net`, `game/server`, `game/ui` | 아니오 |
| 6 | Phase 3.1~3.9 | 3.9는 트랙이 2개 이상이어야 게이트 판정 가능(6.1의 일부를 당겨야 함. 순서 조정은 사용자 결정) | Phase 3 게이트 | Phase 2 게이트. 3.9는 R3 해소와 2번 | `game/core`, `game/data`, `game/ui` | 아니오 |
| 7 | Phase 4, 5, 6 | 계획서대로. 백엔드(Go/PostgreSQL/Redis)는 5.1에서 처음 도입 | 각 Phase 게이트 | 앞 Phase 게이트 | `backend/` 포함 | 아니오 |

사람의 개입이 필요한 지점: 1(주행 판정), 2(기준값 이동 승인), 4의 (1)(아키텍처 승인), 6의 순서 조정, 각 Phase 게이트.

계획서와 코드가 어긋나는 선택지(어느 쪽도 고르지 않음):

- 랩 판정: 계획서 1.5는 체크포인트, 코드는 센터라인 오프셋. 피트레인(4.5)에서 다시 결정해야 한다. 선택지는 (a) 피트 구간만 별도 커브로 분리 (b) 체크포인트 콜리전으로 전환.
- Phase 3 게이트는 트랙 2개를 요구하는데 트랙 추가는 6.1이다. 선택지는 (a) 6.1의 트랙 1개를 Phase 3으로 당김 (b) Phase 3 게이트를 다운포스 축 내부 최적 확인으로 한정.

## 9. 알려진 미해결 설계 항목 (사용자 결정 필요)

- B2: 기존 주석 일괄 삭제 여부
- B3: `handoff.md` §5 표현 수정 여부
- 정지 풀스로틀 휠스핀에 대한 플레이어 보조 제공 여부(R2)
- PRD §51 DRS 계열, §52 에너지 존: PRD에서 "슬립스트림 테스트 후 결정"으로 미확정

## 10. 요구사항 추적 (PRD ↔ 제작 계획 ↔ 코드)

2026-11-11 `MASTER_PROMPT` 실행으로 작성. 상태는 `완료` / `부분` / `미착수` / `미확인` / `미결`(PRD가 결정을 미룬 항목). 검증 근거가 테스트 이름이면 `./tools/check.sh`에서 통과한 것이다.

| PRD 절 | 요구사항 요약 | 제작 계획 작업 | 구현 위치 | 상태 | 검증 근거 |
|---|---|---|---|---|---|
| §1~3, §104~106 | 전체 루프(매칭→공개→준비→퀄리→GP→ELO) | 4.8 | 없음 | 미착수 | — |
| §4, §9, §11 | 상시 경쟁전, ELO 비초기화 | 5.x | 없음 | 미착수 | — |
| §5, §6, §65 | ELO 계산, 악용 방지 | 5.3 | 없음 | 미착수 / K-factor는 **미결** | PRD §6이 프로토타입 이후 결정으로 명시 |
| §7, §8 | 티어 7단계, 표시용 | 5.4 (데이터는 0.3) | `data/tiers.json`, `DataRegistry.resolve_tier` | 부분(데이터와 조회만) | `test_data_registry.gd`, `test_thresholds_do_not_overlap`. 구간 값은 PRD 표와 일치, "테스트 후 조정"으로 **미결** |
| §10, §82~84 | 콘텐츠 시즌, 시즌 패스, 미션 | 6.9 | 없음 | 미착수 | — |
| §12, §13 | 매칭(ELO/핑/대기/지역), 밴드 확장 | 5.2 | 없음 | 미착수 / 수치 **미결** | — |
| §14, §15, §55 | 매칭 후 트랙 공개, 로테이션 | 4.1, 6.2 | 없음(`--track=<id>` 인자만) | 미착수 | — |
| §16, §19 | 준비 단계 30초, 자동 확정 | 4.1 | 없음 | 미착수 | — |
| §17, §23 | 부품 9슬롯 교체 | 3.1 | `data/parts.json`(12종, 9슬롯), `CarStats.SLOTS`, `DataRegistry.validate_parts` | 부분(데이터와 검증만, 차량에 미적용) | `test_data_registry.gd` |
| §18, §75, §78 | 스킨/리버리, 성능 무영향 | 3.8 | 없음 | 미착수 | — |
| §20, §71, §96 | Engineer Recommendation | 4.2 | 없음 | 미착수 | — |
| §21 | 세팅 프리셋 5종 | 3.7 | 없음 | 미착수 | — |
| §22 | 고급 세팅 5종 | 3.3 | `CarSetup`에 대응 파라미터 존재(`downforce_area`, `aero_balance`, `gear_ratios`, `suspension_*`, `brake_balance`). 0~100 슬라이더 매핑 없음 | 부분 | `test_car_dynamics.gd`, `test_powertrain.gd` |
| §24 | 스탯 12종 | 3.1, 3.2 | `CarStats.STATS`(식별자), 스탯→물리 매핑 없음 | 부분 | `test_data_registry.gd` |
| §25, §26 | 등급 4단계, 등급≠강함 | 3.1 | `parts.json`에 `grade` 없음, `tuning` 필드만 | 미착수 | — |
| §27 | 다운포스↑→코너↑/최고속↓, 만능 차량 없음 | 1.1, C-4, 3.2, 3.9 | `core/aero.gd`, `tests/sim/setup_sweep.gd` | 부분(다운포스 축, 트랙 1개) | 프로브 `more downforce costs top speed`, 스윕 `PRD 27` 2건 + 내부 최적 확인. 기어비 축과 트랙 간 비교는 미착수 |
| §28 | 타이어 3종 | 3.4 | `data/tyre_compounds.json`, `validate_compounds` | 부분(데이터만, 물리 미적용) | `test_data_registry.gd` |
| §29, §30 | 타이어 마모, 운전 스타일 | 3.4 | 없음 | 미착수 | — |
| §31~34 | 손상, 충돌 판정, 리타이어 | 3.5, 2.3 | 없음 | 미착수 | — |
| §35 | Start Protection | 2.3 | 없음 | 미착수 | — |
| §36 | 역주행 방지(경고→고스트→퇴장) | 1.5 (감지), 이후 단계 미지정 | `core/lap_timer.gd`(`wrong_way_changed`, 무효 랩), HUD 표시 | 부분(감지와 랩 무효화만) | `test_lap_timer.gd`. 고스트/강제 퇴장은 **제작 계획에 대응 작업 없음** |
| §37~40, §91 | 퀄리파잉, UI, 서버 집계 | 4.3, 4.4 | 없음 | 미착수 | — |
| §41 | GP 상태 머신 | 2.5 | 없음 | 미착수 | — |
| §42, §50 | GP 핵심 시스템, 추월 요소 | 2.x~4.x | 주행만 | 부분 | 물리 프로브 |
| §43 | 레이스 5~15분 | 데이터 | `aurora_speedway.json` `race_laps: 8` | 완료(데이터 검증) | `test_a_lap_at_this_pace_fits_the_race_length` |
| §44~46 | 피트스톱, 시간, 전략 | 4.5 | 트랙 JSON `pit` 객체와 검증만 | 미착수 | `test_track_data.gd`(데이터 형식) |
| §47, §48 | 에너지 | 4.6 | `DriverInput.energy`, 입력 액션만(소비 코드 없음) | 미착수 | — |
| §49 | 슬립스트림 | 4.7 | 없음 | 미착수 | — |
| §51 | DRS | 후순위 | 없음 | **미결** | PRD가 슬립스트림 테스트 후 결정으로 명시 |
| §52 | 에너지 존 | 후순위 | 없음 | **미결** | 동일 |
| §53, §54 | 독창 트랙, 유형 5종 | 1.3, 1.4, 6.1 | `track/*`, `core/track_layout.gd`, `aurora_speedway.json`(고속 1종) | 부분(1/5 유형) | `test_track_data.gd`, `test_track_layout.gd`, `test_track_geometry.gd`, 프로브 `the shipped track loads` 외 |
| §56 | 트랙 분석 → 세팅 | 4.2 | 없음 | 미착수 | — |
| §57 | 조작(가속/브레이크/조향/에너지/피트/카메라) | 1.2 | `project.godot [input]`, `client/player_input.gd`, `client/chase_camera.gd` | 부분(에너지/피트는 액션만) | `--selfcheck`, `test_player_input.gd`. 실제 키보드/패드 조작은 **미확인** |
| §58 | 주행 보조 | 1.6 (라인), 이후 미지정 | `track/racing_line.gd`(데이터만, 플레이어용 표시/보조 없음) | 미착수 | 조향/브레이크 보조는 **제작 계획에 대응 작업 없음** |
| §59 | 차량 물리 요소 | 1.1 | `core/car_body.gd`, `wheel.gd`, `tyre_model.gd`, `aero.gd`, `powertrain.gd` | 부분(타이어 상태·충돌 제외). 조종감은 **미판정** | `test_car_dynamics.gd`, `test_tyre_model.gd`, `test_powertrain.gd`, 물리 프로브 28개 |
| §60 | 레이싱 라인 효과 | 1.6 | `track/racing_line.gd` | 완료(생성과 속도 프로파일) | `test_racing_line.gd` |
| §61 | 레이스 HUD | 2.6 | `ui/driving_hud.gd`(속도/기어/랩/섹터). 순위/갭/타이어/손상/에너지/피트 없음 | 부분 | 시각 확인은 이번 세션 **미확인** |
| §62 | 미니맵 | 2.6 | 없음 | 미착수 | — |
| §63, §64 | 결과/ELO 화면 | 5.4 | 없음 | 미착수 | — |
| §66 | 탈주 처리 | 5.5 | 없음 | 미착수 | — |
| §67, §97 | 친구, 라이벌 | 6.8 | 없음 | 미착수 | — |
| §68 | 일반전 | 6.7 | 없음 | 미착수 | — |
| §69, §70 | Garage, 성능 분석 | 3.6 | `tests/sim/performance_envelope.gd`(측정 로직만, 테스트 폴더에 있음) | 미착수 | — |
| §72 | 패배 분석 | 5.7 | 없음 | 미착수 | — |
| §73, §74, §76, §77, §79~81 | 팀, 드라이버 외형, 상점, 가챠, 과금, 부품 획득 | 6.9 (§73/74/76/81은 **대응 작업이 명시되지 않음**) | 없음 | 미착수 | — |
| §85 | 프로필 | 5.8 | 없음 | 미착수 | — |
| §86, §87 | 리플레이, 관전 | 6.4, 6.5 | 없음 | 미착수 | — |
| §88 | 날씨 | 후순위 | 없음 | 미착수(P3) | — |
| §89 | 서버 권위 | 2.1, 2.2, 2.4 | `GameConfig.Mode.DEDICATED_SERVER` 분기와 부팅 로그뿐 | 미착수 | `--server` 부팅 로그 확인 |
| §90 | 네트워크 보정 | 2.1, 2.3 | 없음 | 미착수 | — |
| §92 | Anti-Cheat | 5.6 | 없음 | 미착수 | — |
| §93, §94 | UI 구조, 홈 화면 | 6.3 | 없음 | 미착수 | — |
| §95 | 튜토리얼 | 6.6 | 없음 | 미착수 | — |
| §98 | 클럽/크루 | 후순위 | 없음 | 미착수(P3) | — |
| §99 | MVP 범위 | Phase 1~5 | 차량 1종·트랙 1개·주행만 | 부분 | — |
| §100 | 검증 질문 Q1~Q9 | Phase 4 게이트 | Q7만 수치로 일부 확인(스윕) | 부분 | 사람 판정 필요 |
| §101 Phase 1 | 운전이 재미있는가 | 1.8 + 게이트 | — | **미판정** | 사람 주행 필요 |
| §103-6 | RNG 통제 | 전 단계 | 난수 사용 0건 | 완료(현재 코드 범위) | `grep -rnE 'rand\|RandomNumber' game --include=*.gd`(addons 제외) 0건 |

집계(58행, 상태 열의 첫 값 기준): 완료 3, 부분 14, 미착수 38, 미결 2(§51, §52. 그 밖에 §6 K-factor, §7·§13 수치가 PRD에서 조정 대상으로 남아 있다), 미판정 1.

PRD에 있으나 제작 계획에 대응 작업이 없는 것: §36 역주행 고스트/강제 퇴장, §58 조향·브레이크 보조와 트랙 가이드, §73/§74 가상 팀, §76 드라이버 커스터마이징, §81 부품 획득 경로, §45 피트 크루 능력.
제작 계획에 있으나 PRD 근거가 약한 것: 2.7 8인 부하 테스트(§99 "멀티플레이"에서 인원 수 미명시. 8인은 §6 표의 8위에서 유추), PART C 검증 인프라 전체(개발 수단이므로 PRD 근거 불필요).

## 11. 변경 이력

| 일자 | 내용 |
|---|---|
| 2026-11-11 | 최초 작성. `origin/main` `7b3d7bf` 기준으로 저장소를 조사하고 `check.sh`를 실행해 기록함 |
| 2026-11-11 | `MASTER_PROMPT` 실행: §10 요구사항 추적 작성, §12 구조와 의존성 추가, §6에 B5~B8, §7에 R10~R13 추가, §8 실행 계획 수립. 기준선 `check.sh`(173 테스트, 프로브 28, 랩 1:04.467)와 `sweep.sh`(§6.17 표와 일치)를 실행함 |

## 12. 구조와 의존성 (2026-11-11 조사)

- 의존 방향: `client`, `ui`, `tests/sim` → `ai` → `track` → `core`. `core`는 `Input.*`, `get_viewport()`, 카메라를 참조하지 않는다(`grep` 0건). 예외적으로 `track/track.gd`가 `Log` 오토로드를 쓴다.
- `core` 안에서 씬 트리에 붙는 것은 `CarBody`(`RigidBody3D`)와 오토로드 3개(`Log`, `GameConfig`, `DataRegistry`)다. 나머지는 `RefCounted`와 `static` 함수다.
- 입력은 값으로 주입된다(`CarBody.input: DriverInput`). 시간은 `_physics_process`의 `delta`와 틱 수에서 온다. 랩타임은 틱 수 기반이다(`handoff.md` §6.15c).
- `PerformanceEnvelope`와 `LapRunner`가 `game/tests/sim`에 있다. Phase 3.6(성능 분석)과 4.2(엔지니어 추천)가 이 측정 로직을 쓰려면 위치를 옮겨야 한다(리팩터링 승인 필요).
- 데이터와 검증기의 짝: `parts.json`↔`validate_parts`, `tiers.json`↔`validate_tiers`, `tyre_compounds.json`↔`validate_compounds`, `tracks/*.json`↔`validate_track`. 빠진 짝 없음.
- 선행 조건: Phase 1 게이트(사람) → 2.1 → 2.2/2.4/2.5 → 2.3 → 2.6/2.7. 3.1 → 3.2 → 3.3/3.4 → 3.9, 3.9는 6.1(트랙 추가) 없이는 Phase 3 게이트("트랙 A 최적이 트랙 B에서 느림")를 판정할 수 없다. 4.5는 R6 해결이 선행. 5.x는 2.x 완료가 선행.
- 백엔드: 현재 단계에서 불필요함을 확인. `backend/`는 `.gitkeep`뿐이고 도입 시점은 Phase 5.1, 선행 조건은 Phase 2~4 게이트다.
