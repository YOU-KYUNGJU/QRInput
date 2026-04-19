# CHANGELOG

## Unreleased
- 분석화학평가팀에 `cutoff_hour` 이후 `현재월 -> 다음월` 범위에서만 가장 가까운 미래 날짜 폴더를 우선 선택하는 규칙으로 조정
- 가공성능평가팀에 `recent_date_folder_count=2` 를 도입해 현재 날짜 기준 최근 2개 날짜 폴더를 함께 스캔하도록 조정
- CSV 스캐너를 오늘 날짜 폴더 우선, 루트 csv 마지막 fallback 구조로 정리
- 가공성능평가팀 파일 선택/행 스킵 사유 debug 로그 추가
- 로그인 후 메인/QR 전환과 가공성능평가팀 QR 처리 진단 보강
- 팀 시작 시 csv 대상 폴더 해석 결과를 재사용해서 네트워크 공유폴더 재탐색을 줄임
- 팀별 스크린샷 저장 경로를 설정 루트 기준 `yyyy\MM\yyyyMMdd` 날짜 폴더로 분리하고 파일서버 UNC 경로로 옮길 수 있게 조정

## 0.1.0
- 저장소 초기 구조 생성
- AGENTS.md 추가
- 공통 엔진 초안 추가
- 설정 템플릿 확장
- 테스트 시나리오 초안 추가

## 0.2.0
- 실행 가능한 저장소 구조 정리
- `src/`, `config/`, `docs/`, `tests/`, `logs/`, `runtime/` 구조 확정
- CSV 파서와 팀별 스캔 규칙 구현
- FITI 세션/로그/이력 기본 구현 추가
- `scripts/build.ps1` 빌드 스크립트 추가
- `docs/manual-test-checklist.md` 수동 테스트 체크리스트 추가
