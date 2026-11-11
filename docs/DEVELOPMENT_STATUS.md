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
- 2026-11-11 세션 전반: 전체 분석(§10, §12), Stage 0.1 감사(§13), Jolt 경고 규명(B1), AI 슬립 관리, CI 확인(R8).
- 2026-11-11 세션 후반: 이론 랩 정직화와 드라이버 추종 개선(R13, B6), **저속 수치 진동 수정(B9, 차량 물리 변경)**, 좌우 대칭·저속 정지 프로브 추가(R12), 에어로 밸런스 여유 발견(R14), Claude Code Game Studios 에이전트/스킬 설치(§14). Phase 1.8 판정은 하지 않았다.
- 근거: `handoff.md` §6.19~§6.22, 아래 §2의 `check.sh` 통과.

## 2. 마지막 검증

| 항목 | 내용 |
|---|---|
| 일시 | 2026-11-11 |
| 기준 커밋 | 코드는 `48e803e`(브랜치 `claude/tender-fermi-xszs0k`). 이후 커밋은 문서만 바꿨다 |
| 환경 | 클라우드 컨테이너(4코어), 디스플레이 없음, Godot 4.4.stable.official.4c311cbee |
| 명령 | `./tools/check.sh` |
| 결과 | **통과** (종료 코드 0, 소요 약 37초) |
| GUT 단위 테스트 | 13 스크립트, **223** 테스트 전부 통과, 3072 assert (세션 시작 시 173 / 1430) |
| 환경 자가 검증 | 통과 (Jolt, 120Hz, 데이터 로드: 부품 12, 티어 7, 컴파운드 3, 트랙 1) |
| 물리 프로브 | **35개** PASS(세션 시작 시 28. 좌우 대칭 3, 저속 정지 4 추가). 0-100 km/h 4.03 s, 0-200 km/h 7.05 s, 235 km/h에서 제동 평균 2.3 g, 최고속 350 / 280 km/h, 좌우 선회 157.6° / 157.6°, 정지 시 좌우 하중 차 0 N |
| AI 랩타임 회귀 | 통과(5개 PASS). 엔벌로프 310 km/h / 2.42 g / 2.27 g, 이론 랩 1:00.810, 랩 1 1:06.592, 플라잉 랩 1:01.367, 기준값 1:01.367 |
| 랩타임 기준값 이동 | 64.467 → 61.517(`d98e0e0`, 목표 속도와 드라이버 변경) → 61.367(`48e803e`, 저속 진동 수정). 사유는 각 커밋 본문과 `handoff.md` §6.20, §6.21 |
| 게이트 민감도 확인 | 항력 0.70 → 1.10: +2.233 s 실패. 0.74: +0.225 s 통과. 타이어 마찰 1.70 → 1.60: +0.683 s 실패(`d98e0e0` 시점). 새 프로브 7개는 수정 전 물리에서 6건 실패 |
| 파라미터 스윕 | `./tools/sweep.sh` 종료 코드 0(79초). 아래 표 |
| 자동주행 클라이언트 | `--headless --fixed-fps 30 --quit-after 4300 -- --autopilot`: 랩 1 1:07.225, 랩 2 1:02.058 |
| 화면 캡처 | `./tools/screenshot.sh <png> 26`: 차가 노면 위에서 정자세로 217 km/h, HUD 표시 정상(눈으로 확인) |
| 틱레이트 수렴 확인 | 코너 탈출 시나리오를 120 Hz와 960 Hz에서 실행. 새 바퀴 적분은 두 틱레이트에서 같은 결과, 옛 적분은 120 Hz에서만 다른 결과(`handoff.md` §6.22) |
| GitHub Actions | `main` 최근 실행 성공, 작업 브랜치는 실행 없음(R8) |
| 실행하지 않은 것 | 사람이 직접 주행, 디스플레이가 있는 환경에서의 클라이언트 실행, 실제 키보드/패드 입력, CI에서의 이 브랜치 검증 |

스윕 (2026-11-11, `driven lap`은 플라잉 랩):

| 다운포스 | 최고속 | 횡G | ideal | driven | driven − ideal | 세션 시작 시 driven (ideal) |
|---|---|---|---|---|---|---|
| 2.0 | 339 km/h | 1.82 g | 1:05.098 | 1:05.133 | +0.035 s | DNF (1:01.306) |
| 3.0 | 317 km/h | 2.25 g | 1:01.607 | 1:02.183 | +0.576 s | 1:08.675 (0:58.336) |
| 4.0 | 310 km/h | 2.42 g | 1:00.810 | 1:01.367 | +0.557 s | 1:01.642 (0:57.651) |
| 5.0 | 295 km/h | 2.54 g | 1:00.529 | 1:01.200 | +0.671 s | 1:01.475 (0:57.452) |
| 6.0 | 280 km/h | 2.71 g | 1:00.560 | 1:01.450 | +0.890 s | 1:01.917 (0:58.011) |

- 다섯 세팅 전부 완주. 최속은 5.0(내부 최적), 스윕의 PRD §27 검사 4건 통과.
- 중간 단계 표(슬립 관리만 넣은 시점, 이론 랩만 고친 시점)는 `handoff.md` §6.19, §6.20에 있다.
- 세션 시작 시와 지금은 차량 물리가 다르다(B9). 2.0과 3.0은 물리 수정 직전(1:04.533, 1:01.983)보다 느려졌는데 실측 횡G가 내려갔기 때문이다.

관찰된 경고:

- `Jolt Physics job system exceeded the maximum number of jobs` 경고가 실행에 따라 0~2회 나온다. 하네스의 스텝 속도가 원인이고 결과에 영향이 없다(§6 B1, `handoff.md` §6.18).
- GUT 요약의 `Total orphans`는 GUT 자체 객체가 섞인 값이다(`handoff.md` §6.13).

## 3. 작업 현황 (제작 계획 작업 번호 기준)

| 작업 | 상태 | 근거 / 비고 |
|---|---|---|
| Stage 0.1 프로젝트 골격 | 완료 | 2026-11-11 `STAGE_0_1_PROMPT` 감사 수행. 체크리스트 A~E 전 항목 일치, 갭 없음, 코드 변경 없음. 결과는 §13 |
| Stage 0.2 검증 게이트(GUT + CI) | 완료 | `tools/check.sh` 통과. CI는 `main`에서 성공 확인(R8). 워크플로는 `push: main`과 `pull_request`에서만 돈다 |
| Stage 0.3 데이터 스키마 + 검증 로더 | 완료 | `DataRegistry` 부팅 검증 통과, `test_data_registry.gd` 통과 |
| Phase 1.1 차량 물리 코어 | 완료(자동 검증 범위) | `RigidBody3D` + 레이캐스트 서스펜션 + 슬립 기반 타이어. 2026-11-11 저속 수치 진동 수정(`48e803e`, B9). 프로브 35개 통과. 조종감은 미판정 |
| Phase 1.2 입력 / 카메라 / 주행 씬 | 완료(자동 검증 범위) | `test_player_input.gd` 통과. 실제 키보드/패드 조작은 미확인 |
| Phase 1.3 트랙 지오메트리 | 완료 | `test_track_geometry.gd`, 프로브 통과. 시각 확인은 이번 세션에서 미실행 |
| Phase 1.4 트랙 DSL 컴파일러 | 완료 | Aurora 4032 m 컴파일, 닫힘 검증 통과 |
| Phase 1.5 랩 / 섹터 / 역주행 | 완료 | `test_lap_timer.gd` 통과 |
| Phase 1.6 레이싱 라인 + 속도 프로파일 | 완료 | `test_racing_line.gd` 통과. 2026-11-11 속도 구간별 가속도, 마찰원, 기본 상수 정정(`d98e0e0`) |
| Phase 1.7 헤드리스 AI 드라이버 | 완료 | 랩타임 회귀 통과. 다운포스 2.0~6.0 전부 완주, 이론 랩 대비 0.04~0.89초(`e383fd8`, `d98e0e0`) |
| PART C-4 파라미터 스윕 | 완료(도구) | `tools/sweep.sh` 실행, 결과는 §2. 엔벌로프가 속도 구간별 가속도를 잰다 |
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
| B1 | 물리 프로브 실행 중 Jolt 경고 `job system exceeded the maximum number of jobs` | 원인 규명, 수정 안 함 | 하네스가 물리 스텝을 실시간보다 훨씬 빠르게(초당 약 3400스텝) 연달아 돌릴 때만 나온다. 프로브 `--fixed-fps 30` 7/10, `--fixed-fps 120` 8/10, 랩타임 회귀 1/7, 클라이언트 헤드리스 0/5, `--autopilot` 0/3. 결과 수치는 경고 유무와 무관하게 동일. 상세와 고치지 않은 이유는 `handoff.md` §6.18 |
| B2 | 기존 코드에 주석이 많다. `CLAUDE.md`의 주석 금지 규칙은 `40dc384`에서 추가되었고 이전에 작성된 파일은 그대로다. `game/` 내 `.gd` 46개 중 33개(grep 기준)와 `tools/*.sh` 5개 전부, `tiers.json`/`parts.json`의 `_comment` 필드에서 확인 | 미결 | 일괄 삭제는 범위 밖 변경이므로 하지 않음. 삭제 여부는 사용자 결정 필요 |
| B3 | `handoff.md` §5가 "같은 GDScript 물리를 돌리므로 서버 권위 판정이 구조적으로 공짜"라고 적고 있다. 동일 코드가 동일 결과를 보장하지 않으므로(`CLAUDE.md` 기술적 제약) 과대 표현이다 | 미결 | `handoff.md`는 이번 문서 작업 범위 밖이라 수정하지 않음 |
| B5 | 문서 간 불일치(코드 변경 불필요, 문서만 해당). (1) `handoff.md` §2 "이론 랩타임 약 58초" ↔ 같은 문서와 `lap_probe` 출력의 1:01.363. (2) `handoff.md` §7 "모든 작업은 `main`에 커밋/푸시" ↔ `CLAUDE.md` Git 절(브랜치 지정 우선). (3) `handoff.md` §8 디렉터리 목록에 `docs/prompts`, `DEVELOPMENT_STATUS` 없음. (4) `PRODUCTION_PLAN` A-2 구조에 `game/ai`, `game/client` 없음(`CLAUDE.md`에는 있음). (5) `PRODUCTION_PLAN` A-1 "클라/서버 물리 불일치가 구조적으로 발생하지 않는다" ↔ `CLAUDE.md` 기술적 제약(B3과 같은 성격). (6) `PRODUCTION_PLAN` Phase 3 게이트의 "(§7 검증)"은 문맥상 §27. (7) `PRODUCTION_PLAN` 1.5 "체크포인트 통과 판정" ↔ 구현은 센터라인 오프셋 기반(`handoff.md` §6.11에 사유 기재). (8) `PRODUCTION_PLAN` B-1 DSL 예시(`{"straight": 850}`, `drs_zones`) ↔ 실제 형식(`{"kind": "straight", "length_m": 850}`, `pit` 객체). (9) `main.gd` 상단 독스트링 "Stage 0.1 has no gameplay scenes yet"는 낡은 기존 주석 | 일부 해결 | (1)(2)(3)은 `handoff.md`에서 정정함. (4)~(8)은 `PRODUCTION_PLAN.md`(승인 대상), (9)는 기존 주석(B2)이라 그대로 둠 |
| B6 | `RacingLine` 기본 상수가 기본 차량과 맞지 않았다(최고속 350 km/h는 다운포스 1.5의 값, 횡 2.2 g) | **해결**(`d98e0e0`) | 기본 차량 실측(2.4 g / 2.1 g / 310 km/h)으로 정정. 랩타임 게이트는 상수 대신 실측 엔벌로프를 쓴다 |
| B7 | `DriverInput.energy`, 입력 액션 `energy_boost`/`pit_request`는 정의만 있고 소비하는 코드가 없다(`grep` 확인). `parts.json` 12종에 `grade` 필드가 없다 | 정상(미착수 단계) | Phase 4.6 / 4.5 / 3.1 작업 대상. 버그 아님 |
| B8 | 열린 PR #2(`claude/project-understanding-next-tasks-vmsblv` → `main`). `7b3d7bf` 위에 커밋 3개, 13파일 +1137줄: 헤드리스 조종감 프로브(`HandlingMetrics`, `feel_probe`, `feel_sweep`, `tools/feel.sh`, `docs/DRIVING_FEEL.md`) | 미결(사용자 결정) | 이 브랜치와 병합을 시험함(커밋 안 함): 충돌은 `handoff.md` 하나. 프로브 7항목 중 6개 통과, "에어로 밸런스 +0.01 여유" 1개 실패. 그 PR이 기록한 절벽 위치(0.465~0.47)는 옛 바퀴 적분의 수치 오차였다(R14). 처음에 "다른 구조의 병행 구현"이라고 적은 것은 Actions 목록의 커밋 제목만 보고 한 오판이었다 |
| B9 | **저속 수치 진동.** 약 100 km/h 아래에서 물리가 틱마다 진동했다: 정지 시 좌우 바퀴 하중이 0 ↔ 3500~4400 N으로 교대(~50 km/h까지), 앞바퀴 슬립률 부호가 매 틱 반전해 ±2000~2900 N 종력 발생, 정지한 차가 최대 0.18 m/s로 이동, 좌우 조향 결과 비대칭(165.4° / 157.9°) | **해결**(`48e803e`) | 롤 관성을 트랙 폭에서 계산, 바퀴 회전을 타이어 강성 포함해 적분, 저속 횡력 상한. 차량 물리가 바뀌어 프로브 수치와 기준값이 움직였다. `handoff.md` §6.21 |
| B4 | `CLAUDE.md` 구판은 "모든 작업은 `main`에 커밋/푸시"였다. 세션이 작업 브랜치를 지정하는 경우와 충돌해 이번에 브랜치 지정 우선으로 정리함 | 해결(문서) | |

## 7. 해결되지 않은 기술적 위험

| # | 위험 | 영향 | 비고 |
|---|---|---|---|
| R1 | **조종감 미검증** | 프로젝트 근간. 계획서 PART G 최대 리스크 | 사람이 주행해야 함 |
| R2 | 정지 풀스로틀 휠스핀이 플레이어에게 가혹한지 미판정 | 조작 접근성, PRD §58 보조 | 1.8에서 결정 |
| R3 | AI의 저다운포스 차량 제어 | **해소.** 다운포스 2.0~6.0 전부 완주, 이론 랩 대비 0.04~0.89초. 3.0은 +0.576초(목표 +3.0초 이내 충족) | `handoff.md` §6.19, §6.20 |
| R4 | 스윕이 트랙 1개만 봄 | PRD §27의 "트랙마다 최적 세팅 상이" 미검증 | Phase 6.1 이후 |
| R5 | 서버/클라 물리 동일 코드의 결과 일치 미보장, 클라 예측·되감기 재조정 가능 여부 미검증 | Phase 2 전체. 억울한 충돌 방지(PRD §90) | Phase 2.1에서 별도 검증 |
| R6 | 랩 판정이 센터라인 근접 거리 기반이라 피트레인 도입 시 전제가 깨짐 | Phase 4.5 | `handoff.md` §6.11 |
| R7 | 랩타임 기준값(`BASELINE_LAP_S`)이 현재 차량 세팅에 묶임 | 의도적 물리 변경 시 사유 없이 옮기면 게이트 무력화 | `CLAUDE.md` 검증 절 |
| R8 | CI 실행 결과 | **확인함.** `main`의 최근 실행은 #16(`7b3d7bf`, push, 2026-09-10) 성공이고 `Run checks` 단계가 27초에 통과했다. `main`의 이전 실행 #15도 성공. 작업 브랜치 `claude/tender-fermi-xszs0k`는 실행이 0건이다(워크플로가 `push: main`과 `pull_request`에서만 돌고 이 브랜치에는 PR이 없다) | 2026-11-11 GitHub Actions 조회. 이 브랜치의 변경은 CI에서 검증된 적이 없다 |
| R9 | 8인 서버 물리 부하 미측정 | Phase 2.7 | |
| R10 | 차량 상태가 직렬화/복원 단위로 묶여 있지 않다. 재현에 필요한 상태는 `RigidBody3D` 변환·선속도·각속도, `CarBody.gear`/`engine_rpm`/`_shift_timer`/`_shift_cooldown`, 바퀴 4개의 `angular_velocity`다. `teleport_to()`는 초기화만 하고 임의 상태 복원 API는 없다. Jolt 내부 상태(접촉 캐시)는 GDScript에서 저장할 수 없다 | Phase 2.1 클라 예측/재조정. 되감기 재시뮬레이션 가능 여부가 미결인 이유 | 근거: `core/car_body.gd`, `core/wheel.gd`. 입력은 `DriverInput` 값으로 주입되고 난수는 쓰지 않는다(`grep` 0건) |
| R11 | 물리 스텝이 씬 트리의 `_physics_process`와 Jolt 전역 스텝에 묶여 있어 차 한 대만 따로 N틱 재시뮬레이션할 수 없다(`PhysicsServer3D` 수동 스텝 미사용) | Phase 2.1. 서버 재조정 방식 선택을 제약 | 추측 아님: `CarBody._physics_process`가 `apply_force` 후 엔진 스텝에 맡김. 대안 비교는 2.1의 아키텍처 검토에서 수행 |
| R12 | 게이트가 못 보는 회귀: (b) 연석/런오프 주행 거동, (c) 고저차(Aurora는 평지. 뱅킹은 Aurora 코너 3곳에 있어 랩 주행으로 간접 검증됨), (d) 실시간 프레임 페이싱(게이트는 전부 `--fixed-fps`), (e) 렌더링/HUD(캡처는 게이트 밖) | 조용한 회귀 | (a) 좌우 대칭은 프로브 추가로 해소(`48e803e`). 그 프로브가 B9를 찾아냈다 |
| R13 | 이론 랩(`ideal lap`)이 낙관적이었다 | **해소**(`d98e0e0`). 풀스로틀 구간 손실 2.1~2.7초 → 0.1~0.3초 | `handoff.md` §6.20 |
| R14 | **에어로 밸런스 여유가 0.01이다.** 출고값 0.45, 0.46에서는 정상 선회 중 스핀(앞 하중 배분 0.46과 같은 값) | 고속 뒤 안정감(Phase 1.8), 윙 세팅 범위(Phase 3.3), PRD §26과의 충돌 | 세팅 문제라 고치지 않음. 사람의 주행 판정이 필요. `handoff.md` §6.22 |
| R15 | 엔벌로프의 횡G와 제동G가 속도와 무관한 단일 값이다. 다운포스 차량은 그립이 속도에 따라 달라진다 | 코너 속도 분포가 넓은 트랙에서 목표 속도가 틀어짐. Phase 3.9, 6.1 | 가속도는 구간별로 재도록 고쳤으나 횡/제동은 그대로. 스키드패드가 풀 락으로 재는 것도 최대 횡G를 낮게 잡는다(추정) |
| R16 | 120 Hz 양해 적분의 안정 여유. 롤 축은 서스펜션만으로 여유의 약 46%를 쓴다(`test_the_dampers_and_tyres_cannot_overdrive_the_roll_axis_in_one_tick`이 60% 미만을 지킨다) | 서스펜션 강성/댐핑이나 차량 질량을 바꾸는 세팅(Phase 3.3)이 진동을 되살릴 수 있다 | 저속 정지 프로브 4개가 감시한다 |

## 8. 다음 작업 우선순위와 완료 조건

2026-11-11 `MASTER_PROMPT` 실행으로 수립한 계획이다. `PRODUCTION_PLAN.md` PART D 순서를 따른다. "착수 가능" 열이 `아니오`인 작업은 선행 조건이 풀리기 전에는 시작하지 않는다.

| 순위 | 작업 | 목표 / 완료 조건 | 검증 기준 | 선행 | 영향 범위 / 위험 | 착수 가능 |
|---|---|---|---|---|---|---|
| 1 | **Phase 1.8 + Phase 1 게이트 (사람)** | 사람이 20분 이상 주행해 YES/NO 판정. NO면 문제점 목록을 남긴다. 판정은 본 문서에 기록 | `./tools/godot.sh --path game` 직접 주행. 볼 항목은 `handoff.md` §10의 4개 | 디스플레이가 있는 PC | 없음(코드 변경 전). R1, R2 | **사람만 가능** |
| 1a | 1.8 튜닝 반복 (판정이 NO일 때) | 사람이 적은 문제점 1건당 1세션. 변경마다 `check.sh` 통과, 랩타임 기준값 이동 시 사유 기록, 스윕 표 전후 비교 | `check.sh`, `sweep.sh`, 사람 재주행 | 1의 피드백 | `game/core` 차량 파라미터. R7 | 피드백 수신 후 |
| 2 | ~~이론 랩 정확도 개선 (R13, B6)~~ | **완료**(`d98e0e0`). 풀스로틀 구간 손실 0.1~0.3초 | `sweep.sh` 표(§2) | — | — | 완료 |
| 3 | 게이트 공백 보강 (R12) | 좌조향 프로브는 **완료**(`48e803e`). 남은 것: 연석/런오프 주행, 고저차 구간 프로브 | `check.sh`에 새 PASS 줄 | 고저차는 트랙 데이터가 필요 | `game/tests/sim/physics_probe.gd`만 | 예(지시가 있을 때) |
| 3a | 엔벌로프의 횡G/제동G를 속도 구간별로 측정 (R15) | 스키드패드를 여러 속도에서, 풀 락이 아닌 최대 횡G 조향으로 측정. 완료 조건: 스윕에서 `driven − ideal`이 전 세팅 0.5초 이내 | `sweep.sh` 전후 표, 랩타임 기준값은 사유와 함께 갱신 | 없음 | `game/tests/sim/performance_envelope.gd`, `game/track/racing_line.gd` | 예(지시가 있을 때) |
| 3b | PR #2 조종감 프로브 처리 (B8) | 가져올 경우: `handoff.md` 충돌 해소, 에어로 밸런스 여유 게이트를 실제 값(R14)에 맞게 재설계, 수치 재측정 | `check.sh`, `tools/feel.sh` | 사용자 결정 | `game/tests/sim`, `tools` | 결정 후 |
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
- R14: 에어로 밸런스 여유 0.01을 넓힐지(`aero_balance` 또는 `front_weight_bias` 조정). 사람의 주행 판정 후
- B8: 열린 PR #2(조종감 프로브)를 가져올지. 가져오면 여유 게이트 재설계 필요
- 이 브랜치(`claude/tender-fermi-xszs0k`)를 `main`에 병합할 시점. 병합 전에는 CI가 돌지 않는다
- B5: `handoff.md`, `PRODUCTION_PLAN.md`의 문서 불일치를 고칠지
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
| 2026-11-11 | `STAGE_0_1_PROMPT` 실행: 체크리스트 A~E 전 항목 일치, 갭 없음, 코드 변경 없음(§13) |
| 2026-11-11 | B1 Jolt 경고 원인 규명(`handoff.md` §6.18). 코드 변경 없음 |
| 2026-11-11 | R3: AI 드라이버에 슬립 관리 추가(`e383fd8`). 스윕 전후 표를 §2에 기록. 조건 2(3.0이 ideal +3.0초 이내)는 미달 |
| 2026-11-11 | 마무리: R8 CI 결과 확인(`main` 성공, 작업 브랜치 실행 없음), 최종 `check.sh` 통과(184 테스트, 프로브 28, 랩 1:04.467), §1·§2·§9 갱신 |
| 2026-11-11 | R13/B6: 이론 랩 정직화(속도 구간별 가속도, 마찰원, 기본 상수 정정)와 드라이버 추종 개선(`d98e0e0`). 기준값 64.467 → 61.517 |
| 2026-11-11 | Claude Code Game Studios 에이전트/스킬 설치(`9420399`, §14) |
| 2026-11-11 | B9: 저속 수치 진동 수정(`48e803e`, 차량 물리 변경). 좌우 대칭·저속 정지 프로브 7개 추가. 기준값 61.517 → 61.367 |
| 2026-11-11 | R14 에어로 밸런스 여유 발견, R15·R16 추가, B8 정정(PR #2 시험 병합), `handoff.md`의 문서 불일치 B5 (1)~(3) 정정 |

## 12. 구조와 의존성 (2026-11-11 조사)

- 의존 방향: `client`, `ui`, `tests/sim` → `ai` → `track` → `core`. `core`는 `Input.*`, `get_viewport()`, 카메라를 참조하지 않는다(`grep` 0건). 예외적으로 `track/track.gd`가 `Log` 오토로드를 쓴다.
- `core` 안에서 씬 트리에 붙는 것은 `CarBody`(`RigidBody3D`)와 오토로드 3개(`Log`, `GameConfig`, `DataRegistry`)다. 나머지는 `RefCounted`와 `static` 함수다.
- 입력은 값으로 주입된다(`CarBody.input: DriverInput`). 시간은 `_physics_process`의 `delta`와 틱 수에서 온다. 랩타임은 틱 수 기반이다(`handoff.md` §6.15c).
- `PerformanceEnvelope`와 `LapRunner`가 `game/tests/sim`에 있다. Phase 3.6(성능 분석)과 4.2(엔지니어 추천)가 이 측정 로직을 쓰려면 위치를 옮겨야 한다(리팩터링 승인 필요).
- 데이터와 검증기의 짝: `parts.json`↔`validate_parts`, `tiers.json`↔`validate_tiers`, `tyre_compounds.json`↔`validate_compounds`, `tracks/*.json`↔`validate_track`. 빠진 짝 없음.
- 선행 조건: Phase 1 게이트(사람) → 2.1 → 2.2/2.4/2.5 → 2.3 → 2.6/2.7. 3.1 → 3.2 → 3.3/3.4 → 3.9, 3.9는 6.1(트랙 추가) 없이는 Phase 3 게이트("트랙 A 최적이 트랙 B에서 느림")를 판정할 수 없다. 4.5는 R6 해결이 선행. 5.x는 2.x 완료가 선행.
- 백엔드: 현재 단계에서 불필요함을 확인. `backend/`는 `.gitkeep`뿐이고 도입 시점은 Phase 5.1, 선행 조건은 Phase 2~4 게이트다.

## 13. Stage 0.1 감사 결과 (2026-11-11)

`docs/prompts/STAGE_0_1_PROMPT.md` 체크리스트. 판정은 `일치` / `불일치` / `미확인`. **갭 없음. 코드와 설정을 수정하지 않았다.**

| 항목 | 확인 방법 | 결과 |
|---|---|---|
| A. 엔진 버전 4.4 | `./tools/godot.sh --version` → `4.4.stable.official.4c311cbee`, `config/features=("4.4", "Forward Plus")` | 일치 |
| A. 렌더러 | `rendering/renderer/rendering_method="forward_plus"` | 일치 |
| A. 물리 엔진 | `3d/physics_engine="Jolt Physics"`, `--selfcheck` 통과, 부팅 로그 `Jolt Physics` | 일치 |
| A. 물리 틱 | `common/physics_ticks_per_second=120`, `--selfcheck` 통과 | 일치 |
| A. 정적 타입 경고 | `[debug]`의 `untyped_declaration=1`, `unsafe_property_access=1`, `unsafe_method_access=1`, `unsafe_cast=1` | 일치(경고 수준. 오류로 승격되어 있지는 않다) |
| A. 오토로드 | `[autoload]`에 `Log`, `GameConfig`, `DataRegistry`, 세 파일 존재(`game/core/`) | 일치 |
| A. 입력 액션 10종 | `[input]` 절과 `--selfcheck`의 `required_actions` 검사 통과 | 일치 |
| A. 메인 씬 | `run/main_scene="res://main.tscn"`, 파일 존재(노드 1개 + `main.gd`) | 일치 |
| A. 텍스트 전용 | `project.godot`, `main.tscn` 모두 텍스트. `.tres`/바이너리 리소스 없음 | 일치 |
| B. 폴더 구조 | `ls`: `game/{core,ai,client,net,track,data,ui,server,tests}`, `backend`, `tools`, `docs` 전부 존재 | 일치 |
| B. 빈 디렉터리 | `game/net`, `game/server`, `backend`에 `.gitkeep`만 있음 | 일치 |
| B. 문서에 없는 것 | `game/addons/gut`(벤더링된 GUT 9.3.1, `ASSET_CREDITS.md`에 기재), `game/ai`·`game/client`는 `CLAUDE.md`에만 있고 `PRODUCTION_PLAN` A-2에는 없음(B5-4) | 일치(문서 차이만) |
| C. 무시 대상 | `git check-ignore -v`: `game/.godot/`, `bin/`, `/build/`, `/export/`, `/backend/bin/`, `.env`, `*.local.json`, `export_presets.cfg` 전부 무시됨 | 일치 |
| C. 무시되어야 할 것이 추적되는지 | `git ls-files \| grep -E '^game/\.godot\|^bin/'` 0건, `git ls-files -ci --exclude-standard` 0건 | 일치 |
| C. 추적되어야 할 것 | `.uid` 114개 추적, `game/data/*.json`·`game/addons/gut` 무시되지 않음 | 일치 |
| D. 부팅 분기 | `main.gd`: `selfcheck` 인자 우선 → `DEDICATED_SERVER` / `SIMULATION`(`laptime`, `sweep`, 기본 프로브) / `CLIENT`. `GameConfig.resolve_mode`의 우선순위(`--server` > `--sim` > 빌드 피처 > 클라이언트)와 일치. `test_game_config.gd` 통과 | 일치 |
| D. 부팅 시 데이터 검증 | `DataRegistry._ready()`가 `reload()`로 4종을 검증. 부팅 로그 `Loaded 12 parts, 7 tiers, 3 compounds, 1 tracks` | 일치 |
| E. 도구 | `install_godot.sh`(4.4-stable 고정, `bin/godot`), `godot.sh`(`$GODOT` → `bin/godot` → PATH), `check.sh`(임포트/컴파일 → selfcheck → GUT → 프로브 → 랩타임) 모두 `CLAUDE.md` 설명과 같음 | 일치 |
| E. CI | `.github/workflows/ci.yml`이 `install_godot.sh` 후 `check.sh` 실행. 트리거는 `push: main`, `pull_request` | 일치. 실제 실행 결과는 R8 |

실행 검증(전부 이번 세션에서 실행):

| 명령 | 결과 |
|---|---|
| `./tools/install_godot.sh` | 설치됨, `4.4.stable.official.4c311cbee` |
| `./tools/godot.sh --headless --path game -- --selfcheck` | `Selfcheck passed`, 종료 코드 0 |
| `./tools/check.sh` | 통과(§2) |
| `./tools/godot.sh --headless --path game --quit-after 120` | `Client boot` → `Track: Built 4032 m from 1009 cross-sections` → `TestDrive: Ready (autopilot=false)`, 오류 없음 |
| `timeout 10 ./tools/godot.sh --headless --path game -- --server --port=27015` | `mode=DEDICATED_SERVER`, `Dedicated server boot (port 27015)`. 시간 제한으로 종료(정상). 네트워킹 없음 |

갭이 아니라 제안으로만 남기는 것(수정하지 않음):

- 비어 있지 않은 디렉터리에 `.gitkeep`이 남아 있다: `game/data`, `game/tests`, `game/track`, `game/ui`, `tools`.
- `export_presets.cfg`가 무시된다. Phase 2.2의 헤드리스 서버 export는 이 파일을 추적해야 재현된다. 2.2 착수 시 `.gitignore`에서 빼야 한다.
- 데이터 검증 오류는 `--selfcheck`에서만 종료 코드로 이어진다. 클라이언트/서버 모드에서는 `Log.error`만 남기고 부팅을 계속한다. 서버(Phase 2.2)는 잘못된 데이터로 뜨면 안 되므로 그때 결정이 필요하다.
- CI 잡 이름이 `Selfcheck and unit tests`인데 실제로는 프로브와 랩타임 회귀까지 돈다(표시만의 문제).
- CI가 PR 없는 작업 브랜치의 푸시에서는 돌지 않는다.

## 14. Claude Code Game Studios 설치 (2026-11-11)

사용자 요청으로 `Donchitos/Claude-Code-Game-Studios`(MIT, 커밋 `abc0de7`)를 `.claude/`에 넣었다. 사용자가 고른 범위는 "에이전트 + 스킬만"이다.

| 넣은 것 | 넣지 않은 것 |
|---|---|
| `.claude/agents`(49), `.claude/skills`(78), `.claude/rules`, `.claude/docs`, `.claude/engines`, `.claude/genres`, `.claude/scripts`(스킬이 호출하는 스크립트), 라이선스 사본 | `.claude/hooks`(18개, 커밋·푸시·파일 쓰기마다 자동 실행), `.claude/settings.json`(권한·훅 설정), 템플릿의 `CLAUDE.md`, `project.yaml` |

- 이 프로젝트의 `CLAUDE.md`가 그대로 정본이다. 템플릿의 경로별 규칙(`.claude/rules`)은 `src/**`를 대상으로 하므로 `game/**`에는 적용되지 않는다.
- `project.yaml`이 없으므로 스킬은 기본값(엔진 Web, 코드 루트 `src/`)으로 동작한다. Godot와 `game/` 구조에 맞추려면 `project.yaml`을 추가해야 한다(미결).
- 스킬 78개 중 60개가 `.claude/scripts`를, 87개 파일이 `project.yaml`을 참조한다. 각 스킬이 이 저장소 구조에서 제대로 동작하는지는 **미확인**이다.
- 출처는 `docs/ASSET_CREDITS.md`에 기록했다.
