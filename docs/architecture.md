# 아키텍처

## 1. 목표 구조
`공통 엔진 + 팀별 설정 + 처리 이력` 구조로 운영한다.

## 2. 레이어
### 2.1 Runner
- 실행 잠금 확인
- 설정 파일 목록 로드
- 팀별 순차 실행
- 종료 코드 반환

### 2.2 Team Profile Loader
- ini 로드
- 필수값 검증
- 기본값 보정
- 민감정보 분리 여부 확인

### 2.3 CSV Scanner
- 대상 날짜 폴더 계산
- 파일 선별 정책 적용
- CSV 목록 반환

### 2.4 Receipt Extractor
- direct 모드
- compose 모드
- 정규식 검증
- 행 스킵 사유 반환

### 2.5 FITI Session Manager
- 기존 FITI 종료
- FITI 실행
- 로그인
- QR 창 진입
- 세션 끊김 감지/재로그인

### 2.6 QR Executor
- 행 입력
- 입력 검증
- 체크 박스 보정
- 저장 수행
- 저장 확인

### 2.7 History Store
- 성공 이력 조회
- 고유 키 생성
- 중복 처리 방지
- 재실행 복구

### 2.8 Logger
- run summary csv
- row result csv
- debug txt(optional)
- screenshot path 기록

## 3. 처리 상태 모델
행 단위 상태:
- pending
- skipped_invalid
- skipped_done
- sent
- verified
- checkbox_checked
- saved
- success
- failed_retryable
- failed_terminal

파일 단위 상태:
- file_pending
- file_partial
- file_success
- file_failed

팀 단위 상태:
- team_started
- team_login_failed
- team_running
- team_finished
- team_wait_next_schedule

## 4. 실행 흐름
1. lock 확인
2. 설정 목록 로드
3. 팀별 순차 실행
4. FITI 새 실행
5. CSV 스캔
6. 파일별 행 처리
7. 이력 기록
8. FITI 종료
9. 다음 팀 진행
10. 전체 요약 로그 저장

## 5. 설계 원칙
1. 팀 차이는 config로만 주입
2. 공통 함수는 분기보다 전략 선택 구조 사용
3. 실패는 종료보다 기록과 복구 우선
4. 운영 로그와 디버그 로그 분리
5. 성공 이력 기반으로 미처리 건만 재시도
