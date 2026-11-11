# STAGE_0_1_PROMPT — Stage 0.1 프로젝트 기반 감사 및 보완

사용 시점: `MASTER_PROMPT` 결과를 사용자가 승인한 뒤, 첫 번째 작업으로 1회.
제작 계획의 Stage 0.1은 "Godot 프로젝트 골격, 폴더 구조, `project.godot`, `.gitignore`, `CLAUDE.md`(코딩 규약) — 프로젝트 실행 가능"이다. 문서(`handoff.md`)에는 이미 완료로 적혀 있지만 이 세션은 그것을 **믿지 않고 직접 확인**한다. 갭이 없으면 코드 변경 없이 끝나는 것이 정상 결과다.

아래 `---` 이후를 Claude에게 붙여 넣는다.

---

너는 Apex 프로젝트의 수석 개발자다. 이번 작업은 **Stage 0.1의 현재 상태 감사**와, 갭이 있을 때에 한한 **최소 보완**이다.

## 작업 범위

포함:
- Godot 프로젝트 구조, `game/project.godot` 설정, 폴더 구조, `.gitignore`, 초기 씬과 실행 구조 조사
- 제작 계획 Stage 0.1 산출물과의 대조
- 대조에서 발견된 **누락/오류에 한한** 최소 수정
- 실제 Godot 실행 검증
- `docs/DEVELOPMENT_STATUS.md` 갱신

제외 (하지 않는다):
- Stage 0.2 이후 작업 (새 린트 도구, 새 테스트 프레임워크, CI 변경)
- Phase 1.8 튜닝 및 모든 물리/차량/타이어/트랙/AI 코드 변경
- `game/net`, `game/server`, `backend/`에 실제 코드 추가
- 기존 주석 일괄 삭제, 파일 이동/이름 변경, 스타일 정리
- 기존 파일을 통째로 교체하는 것 — 수정은 필요한 줄만, 이유를 먼저 보고한 뒤

## 절차

### 1. 읽기와 상태 확인

`CLAUDE.md` → `handoff.md` → `docs/DEVELOPMENT_STATUS.md` → `docs/PRODUCTION_PLAN.md`의 PART A-2(구조)와 Stage 0 → `docs/PRD.md`의 해당 부분.
`git status`, `git log -5`, 현재 브랜치를 확인한다.

### 2. 감사 체크리스트

항목마다 **확인한 방법과 결과**를 기록한다. "문서에 그렇게 써 있다"는 확인이 아니다.

**A. 프로젝트 설정 (`game/project.godot`)**

| 항목 | 기대 (문서 기준) | 확인 방법 |
|---|---|---|
| 엔진 버전 | Godot 4.4 고정 | `./tools/godot.sh --version`, `config/features` |
| 렌더러 | Forward Plus | `rendering/renderer/rendering_method` |
| 물리 엔진 | Jolt Physics | `physics/3d/physics_engine`, `--selfcheck` |
| 물리 틱 | 120 Hz | `physics/common/physics_ticks_per_second`, `--selfcheck` |
| 정적 타입 경고 | `untyped_declaration`, `unsafe_*` 활성 | `[debug]` 절 |
| 오토로드 | `Log`, `GameConfig`, `DataRegistry` | `[autoload]` 절, 각 파일 존재 |
| 입력 액션 | throttle, brake, steer_left, steer_right, energy_boost, pit_request, camera_cycle, look_back, reset_car, pause | `[input]` 절, `--selfcheck` |
| 메인 씬 | `res://main.tscn` 존재 | 파일 존재 |
| 텍스트 전용 | GUI 에디터 없이 편집 가능한 형식 | 파일 형식 |

**B. 폴더 구조** — `PRODUCTION_PLAN.md` PART A-2와 `CLAUDE.md` 디렉터리 표를 대조한다.

- `game/{core,ai,client,net,track,data,ui,server,tests}`, `backend/`, `tools/`, `docs/`가 실제로 있는지
- 빈 디렉터리는 `.gitkeep`이 있는지(`game/net`, `game/server`, `backend`는 이 단계에서 비어 있는 것이 정상)
- 문서에 없는데 존재하는 디렉터리/파일, 문서에 있는데 없는 것을 구분해서 기록한다 (예: `game/addons/gut`은 벤더링된 GUT)

**C. `.gitignore`**

- `.godot/`, `bin/`, 내보내기 산출물, 백엔드 빌드 산출물, 로컬 비밀 파일이 무시되는지 `git check-ignore -v`로 확인
- 무시되어야 할 것이 추적되고 있지 않은지: `git ls-files | grep -E '^game/\.godot|^bin/'`
- 추적되어야 할 것이 무시되고 있지 않은지: `.uid` 파일, `game/data/*.json`, `game/addons/gut`

**D. 초기 씬과 실행 구조**

- `game/main.tscn`, `game/main.gd`의 부팅 분기(CLIENT / SIMULATION / DEDICATED_SERVER / selfcheck)를 읽고 `GameConfig`의 인자 파싱과 일치하는지
- 부팅 시 `DataRegistry`가 데이터를 검증하는지

**E. 도구와 게이트**

- `tools/install_godot.sh`, `tools/godot.sh`, `tools/check.sh`가 `CLAUDE.md`의 설명과 일치하는지
- `.github/workflows/ci.yml`이 `check.sh`를 실행하는지 (GitHub에서의 실제 실행 결과는 확인할 수 없으면 "미확인")

### 3. 실행 검증

```bash
./tools/install_godot.sh
./tools/godot.sh --version
./tools/godot.sh --headless --path game -- --selfcheck
./tools/check.sh
./tools/godot.sh --headless --path game --quit-after 120
timeout 10 ./tools/godot.sh --headless --path game -- --server --port=27015
```

- 각 명령의 출력을 끝까지 읽는다. 종료 코드 0만으로 통과 처리하지 않는다 (Godot은 파스 에러에도 0을 반환할 수 있다. `check.sh`가 출력을 스캔한다).
- 마지막 명령은 시간 제한으로 종료되는 것이 정상이며, 부팅 로그가 찍혔는지만 본다. 현재 전용 서버 모드는 네트워킹이 없다.
- 실행하지 못한 명령은 이유와 함께 "미확인"으로 기록한다.

### 4. 갭 판정과 보완

- 갭 = 계획서 Stage 0.1 산출물에 해당하는데 없거나 틀린 것, 또는 실행이 실패하는 것.
- 갭이 **없으면** 코드와 설정을 수정하지 않는다. 문서만 갱신하고 끝낸다.
- 갭이 있으면 수정 전에 다음을 보고한다: 갭 내용, 근거, 최소 수정안, 영향 범위. 그 뒤 필요한 줄만 수정한다.
- 선호나 취향의 차이(예: 폴더 이름을 더 좋게 바꾸기)는 갭이 아니다. 수정하지 않고 "제안"으로만 보고한다.
- 새 파일은 갭을 메우는 데 꼭 필요할 때만 만든다. 새 코드에는 주석을 달지 않는다.

### 5. 완료 조건

모두 만족해야 완료다.

1. 체크리스트 A~E의 모든 항목에 확인 방법과 결과(일치 / 불일치 / 미확인)가 기록되어 있다.
2. `./tools/check.sh`가 처음부터 끝까지 통과한다 (변경이 있었다면 변경 후 다시 실행한 결과).
3. `--selfcheck`가 통과하고, 클라이언트 헤드리스 부팅이 에러 없이 시작된다.
4. 변경한 파일이 있다면 모두 갭과 1:1로 대응하며, 그 외 파일은 `git diff --stat`에 나타나지 않는다.
5. 기존 기능이 그대로다: 테스트 개수와 AI 랩타임 회귀 결과가 변경 전과 같다 (변경 전 값은 `docs/DEVELOPMENT_STATUS.md` §2: 173 테스트, 플라잉 랩 1:04.467).
6. `docs/DEVELOPMENT_STATUS.md`가 갱신되어 있다.

### 6. 문서 갱신 (`docs/DEVELOPMENT_STATUS.md`)

- §2 마지막 검증: 일시, 커밋, 명령, 결과
- §3 Stage 0.1 행: 감사 수행 사실과 결과
- §6 / §7: 새로 발견한 문제와 위험 (고치지 않은 것 포함)
- §8: 다음 작업 (Phase 1.8 사용자 주행 판정 대기)
- §11: 변경 이력 한 줄

### 7. 커밋과 보고

- 코드/설정 변경이 있으면 변경 단위로 커밋 (`check.sh` 통과 후), 문서 갱신은 별도 커밋.
- 보고: 체크리스트 결과 표, 실행 결과 요약, 수정 내역(없으면 "수정 없음"), 확인하지 못한 것, 다음 작업.
- 다음 작업 제안으로 끝낸다: Phase 1.8은 사람의 직접 주행 판정이 필요하므로 AI가 시작하지 않는다. 이후 작업은 `WORK_PROMPT_TEMPLATE.md`로 지시받는다.
