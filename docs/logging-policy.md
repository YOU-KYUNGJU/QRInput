# 로그 정책

## 1. 로그 종류
### run_summary.csv
실행 단위 요약 로그

컬럼:
- run_id
- started_at
- finished_at
- team
- source_file_count
- source_row_count
- success_count
- failure_count
- relogin_count
- elapsed_ms
- longest_step
- note

### row_results.csv
행 단위 상세 로그

컬럼:
- run_id
- team
- source_file
- row_no
- receipt_no
- unique_key
- status
- error_code
- reason
- row_retry_count
- session_retry_count
- screenshot_path
- started_at
- finished_at
- elapsed_ms

### history_success.csv
재처리 제외용 성공 이력

컬럼:
- team
- source_file
- row_no
- receipt_no
- unique_key
- success_at

## 2. 고유 키 원칙
기본 키:
`team + source_file + row_no + receipt_no`

receipt_no가 절대 유일하다고 확인되기 전까지는 source_file과 row_no를 포함한다.

## 3. 상태값
- success
- failed
- skipped_invalid
- skipped_done
- retried
- session_relogin
- wait_next_schedule

## 4. 스크린샷 정책
1. 성공 건 저장
2. 실패 건 저장
3. 경로는 row_results.csv에 기록
4. 파일명은 `yyyyMMdd_HHmmss_team_row_receipt.png` 권장

## 5. 운영 규칙
1. 로그는 append 방식
2. CSV 헤더는 파일 최초 생성 시 1회만 기록
3. 디버그용 txt는 선택
4. 분석용 로그와 운영용 알림은 분리
