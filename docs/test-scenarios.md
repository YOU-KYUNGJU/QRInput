# 테스트 시나리오

## 1. 접수번호 생성
### 분석화학평가팀 compose
입력:
- A=H231
- B=14717
- D=26
기대:
- `@H2312614717@`

### direct 우선 사용
입력:
- B=`@W2412600042@`
기대:
- 그대로 사용

## 2. CSV 행 스캔
1. 빈값 행은 스킵
2. 헤더 문자열은 스킵
3. direct 모드에서 `@.*@` 패턴만 처리
4. compose 모드에서 필수 열 누락 시 failed_invalid

## 3. 중복 방지
1. `yyyyMMdd_history_success.csv` 누적 이력에 같은 unique_key가 있으면 skipped_done
2. failed만 있고 success가 없으면 재시도 대상

## 4. 세션 복구
1. 로그인 창 재등장 시 session_relogin 처리
2. 3회 초과 시 team_wait_next_schedule

## 5. 파일 정책
1. keep_source_csv=true 이면 파일 이동 금지
2. move_processed_file=true 이면 전 행 성공 파일만 이동
3. partial 파일은 이동 금지

## 6. 수동 테스트 체크리스트
1. analysis config로 1회 실행
2. processing config로 1회 실행
3. 동일 CSV 재실행 시 success 건 스킵 확인
4. 실패 유도 후 다음 실행에서 재시도 확인
5. FITI 세션 종료 후 자동 재로그인 확인
