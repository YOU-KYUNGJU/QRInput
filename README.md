# QRInput

FITI 시험관리시스템 QR 입고 자동화를 `공통 엔진 + 팀별 설정` 구조로 운영하기 위한 저장소입니다.

대상 팀:
- 분석화학평가팀 pH/폼알데하이드
- 가공성능평가팀 수축율

## 저장소 구조

- `src/`: AHK 실행 코드
- `config/`: 설정 템플릿과 로컬 설정
- `docs/`: 아키텍처, 운영 정책, 수동 테스트 문서
- `tests/fixtures/`: 팀별 CSV 샘플
- `logs/`: 실행 로그와 처리 이력
- `runtime/`: lock 등 런타임 파일
- `scripts/`: 빌드/운영 보조 스크립트

## 실행 방법

1. `config/qr_input.local.ini`를 운영값으로 유지
2. 루트의 [QRinput_main.ahk](/c:/Users/eye2b/Documents/20260104/QRinput/QRinput_main.ahk) 실행
3. 또는 [src/QRinput_main.ahk](/c:/Users/eye2b/Documents/20260104/QRinput/src/QRinput_main.ahk) 직접 실행

## 빌드

PowerShell에서 아래 실행:

```powershell
.\scripts\build.ps1
```

빌드 산출물:
- `dist\QRinput_main.exe`
- `dist\config\qr_input_config.template.ini`
- `dist\docs\manual-test-checklist.md`

## 스크린샷 운영

운영 중 스크린샷은 `team.*.screenshot_dir` 로 지정한 로컬 캐시에 먼저 저장합니다.
서버 보관은 별도 동기화 스크립트로 분리합니다.
기본값으로 `reason=already_checked` 인 success 는 새 스크린샷을 만들지 않습니다.

```powershell
.\scripts\sync_screenshots.ps1
```

팀 하나만 동기화할 때:

```powershell
.\scripts\sync_screenshots.ps1 -Team analysis
```

## 테스트

수동 테스트 절차는 [docs/manual-test-checklist.md](/c:/Users/eye2b/Documents/20260104/QRinput/docs/manual-test-checklist.md)를 기준으로 진행합니다.

핵심 검증 항목:
- 팀별 로그인
- QR 창 진입
- compose/direct 접수번호 처리
- 체크박스 자동 보정
- 성공/실패 로그 기록
- 중복 처리 방지
- 세션 재로그인

## 주의

1. `config/qr_input.local.ini`는 민감정보가 있으므로 커밋하지 않습니다.
2. 좌표, 색상, 타임아웃은 코드가 아니라 설정에서 조정합니다.
3. 실제 FITI 연동 검증은 운영 PC에서 직접 확인해야 합니다.
