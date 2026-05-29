# 로그 정책

## 1. 로그 종류
### run_summary.csv
실행 단위 요약 로그

저장 위치:
- `run_log_dir\yyyy\MM\yyyyMMdd_run_summary.csv`

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

저장 위치:
- `team.*.log_dir\yyyy\MM\yyyyMMdd_row_results.csv`

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

저장 위치:
- `history_dir\yyyy\MM\yyyyMMdd_history_success.csv`
- 기존 루트 `history_success.csv`가 있으면 호환성 때문에 함께 읽는다

컬럼:
- team
- source_file
- row_no
- receipt_no
- unique_key
- success_at

### debug artifacts
로그인 실패, 세션 이상 등 원인 분석이 필요한 경우 `debug_log_dir` 아래에 디버그 txt와 진단용 png를 남긴다.
진단 png 경로는 debug txt에 함께 기록한다.
디버그 txt의 로그인 관련 텍스트는 계정/비밀번호를 마스킹한다.
CSV 선택 경로는 `team_file_selected`, 파일 단위 집계는 `csv_scan_begin`/`csv_scan_end`로 남긴다.
행이 처리 대상에서 빠진 이유는 `row_skipped`, 접수번호 추출 실패는 `row_invalid`, 기존 성공 이력 스킵은 `row_skipped_done`으로 남긴다.
오늘 같은 팀/파트에서 이미 성공한 접수번호를 사전 스킵한 행은 `status=skipped_done`, `reason=duplicate_receipt_today`로 `row_results.csv`에 남긴다.
빈 스캔 열을 만나 파일 처리를 종료한 경우 debug 로그에 `csv_scan_stop`을 남긴다.

## 2. 고유 키 원칙
기본 키:
`team + source_file + row_no + receipt_no`

receipt_no가 절대 유일하다고 확인되기 전까지는 source_file과 row_no를 포함한다.
같은 날짜의 사전 중복 스킵(`duplicate_receipt_today`)은 `team_name + part_name + receipt_no` 범위로 판단한다.
`history_success.csv`에는 part 컬럼을 추가하지 않고 `source_file` 경로를 현재 팀 설정과 대조해 파트를 복원한다.

## 3. 상태값
- success
- failed
- skipped_invalid
- skipped_done
- retried
- session_relogin
- wait_next_schedule

## 4. 스크린샷 정책
1. 성공 건 중 `reason=checked_and_saved` 인 경우에만 기본적으로 스크린샷을 저장한다
2. 성공 건 중 `reason=already_checked` 는 `already_checked_success_screenshot_enabled=false` 이면 기본적으로 스크린샷을 저장하지 않는다
3. 실패 건은 계속 저장한다
4. 경로는 row_results.csv에 기록
5. `team.*.screenshot_dir` 는 운영 중에는 로컬 캐시 루트 경로로 저장하고 실제 파일은 `screenshot_dir\yyyy\MM\yyyyMMdd` 아래에 만든다
6. 파일명은 `yyyyMMdd_HHmmss_team_receipt_status.png` 형식으로 저장한다
7. 서버 보관이 필요하면 `config/qr_input.local.ini` 또는 `config/qr_input_config.template.ini` 에 `team.*.screenshot_sync_dir` 를 두고 `scripts/sync_screenshots.ps1` 로 별도 동기화한다
8. 로그인/세션 진단용 스크린샷은 운영 이력용이 아니라 debug 로그용으로만 저장한다
9. 로그인 창이 그대로 보이는 구간은 진단 스크린샷 저장을 피하고 텍스트 로그 중심으로 남긴다

## 5. 운영 규칙
1. 로그는 append 방식
2. CSV 헤더는 파일 최초 생성 시 1회만 기록
3. 디버그용 txt는 선택
4. 분석용 로그와 운영용 알림은 분리
5. 누적 CSV 로그는 날짜 접두사와 `yyyy\MM` 월별 폴더로 분리한다
