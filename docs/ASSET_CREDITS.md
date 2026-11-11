# 외부 애셋 / 의존성 출처

상업적 라이브 서비스가 목표이므로 **CC0 / OFL / MIT / Apache-2.0**만 사용한다. 새 애셋이나 라이브러리를 추가하면 반드시 여기에 기록한다.

## 라이브러리

| 항목 | 버전 | 라이선스 | 출처 | 용도 |
|---|---|---|---|---|
| GUT (Godot Unit Test) | 9.3.1 | MIT | https://github.com/bitwes/Gut | 단위 테스트 프레임워크 (`game/addons/gut`) |
| Claude Code Game Studios | `abc0de7` (2026-11-09) | MIT | https://github.com/Donchitos/Claude-Code-Game-Studios | Claude Code용 에이전트 49개와 스킬 78개(`.claude/`). 에이전트, 스킬, 규칙, 문서, 엔진/장르 참조, 스킬이 호출하는 스크립트만 넣었다. 훅(설정 읽기용 `yaml-helper.sh` 하나만 예외), `settings.json`, 템플릿의 `CLAUDE.md`는 넣지 않았다. `project.yaml`은 이 프로젝트에 맞게 새로 썼다. 게임 빌드에는 포함되지 않는다 |
| Godot Engine | 4.4-stable | MIT | https://godotengine.org | 엔진. 리포에 포함하지 않고 `tools/install_godot.sh`로 설치 |

## 3D 모델

없음. 트랙은 스플라인에서 절차적으로 생성하고, 차량은 프리미티브에서 시작한다(`docs/PRODUCTION_PLAN.md` PART B).

## 텍스처

없음. 리버리는 셰이더 파라미터로 생성한다.

## 폰트

없음. UI 작업(Phase 6.3) 시 OFL 폰트를 추가하고 여기에 기록한다.

## 사운드

없음. Phase 6.10에서 추가 예정.
