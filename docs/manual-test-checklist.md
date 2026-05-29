# 수동 테스트 체크리스트

## 1. 사전 점검

1. 운영 PC 해상도와 배율이 기존 FITI 자동화 기준과 같은지 확인한다.
2. `config/qr_input.local.ini`가 운영값으로 채워져 있는지 확인한다.
3. 기존 FITI 실행 창이 모두 닫혀 있는지 확인한다.
4. 대상 CSV 폴더와 테스트용 CSV를 준비한다.
5. `logs/`, `runtime/`, `dist/` 경로에 쓰기 권한이 있는지 확인한다.

## 2. 빌드 확인

1. PowerShell에서 `.\scripts\build.ps1` 실행
2. `dist\QRinput_main.exe` 생성 확인
3. `dist\config\qr_input_config.template.ini` 복사 확인
4. 빌드 중 오류 메시지가 없는지 확인

## 3. 분석화학평가팀 단독 테스트

1. `config/qr_input.local.ini`에서 `team.processing.enabled=false`, `team.analysis_arylamine.enabled=false`로 잠시 변경
2. `QRinput_main.ahk` 또는 `dist\QRinput_main.exe` 실행
3. 로그인 창 자동 입력 확인
4. FITI 메인 창 진입 확인
5. QR 창 자동 오픈 확인
6. 접수번호가 `@H...@` 형식으로 처리되는지 확인
7. 체크 대상 건이 자동 체크되는지 확인
8. 다음 행으로 계속 진행되는지 확인
9. `logs\analysis\yyyy\MM\yyyyMMdd_row_results.csv` 생성 확인
10. `reason=checked_and_saved` 인 행은 `team.analysis.screenshot_dir\yyyy\MM\yyyyMMdd` 경로에 성공 스크린샷이 저장되는지 확인
11. `reason=already_checked` 인 행은 `screenshot_path`가 비어 있고 별도 성공 스크린샷 파일도 생기지 않는지 확인
12. `screenshot_dir`가 로컬 캐시일 때만 `.\scripts\sync_screenshots.ps1 -Team analysis` 실행 후 `team.analysis.screenshot_sync_dir\yyyy\MM\yyyyMMdd`에 동일 파일 반영 확인

## 3-1. 분석화학평가팀 아릴아민 단독 테스트

1. `config/qr_input.local.ini`에서 `team.analysis.enabled=false`, `team.processing.enabled=false`, `team.analysis_arylamine.enabled=true`로 변경
2. `QRinput_main.ahk` 또는 `dist\QRinput_main.exe` 실행
3. 로그인 창 자동 입력 확인
4. FITI 메인 창 진입 확인
5. QR 창 자동 오픈 확인
6. 접수번호가 `@H...@` 형식으로 생성되는지 확인
7. 체크 대상 건이 자동 체크되는지 확인
8. 다음 행으로 계속 진행되는지 확인
9. `logs\analysis_arylamine\yyyy\MM\yyyyMMdd_row_results.csv` 생성 확인
10. `reason=checked_and_saved` 인 행은 `team.analysis_arylamine.screenshot_dir\yyyy\MM\yyyyMMdd` 경로에 성공 스크린샷이 저장되는지 확인
11. `reason=already_checked` 인 행은 `screenshot_path`가 비어 있고 별도 성공 스크린샷 파일도 생기지 않는지 확인
12. `screenshot_dir`가 로컬 캐시일 때만 `.\scripts\sync_screenshots.ps1 -Team analysis_arylamine` 실행 후 `team.analysis_arylamine.screenshot_sync_dir\yyyy\MM\yyyyMMdd`에 동일 파일 반영 확인

## 4. 가공성능평가팀 단독 테스트

1. `config/qr_input.local.ini`에서 `team.analysis.enabled=false`, `team.analysis_arylamine.enabled=false`, `team.processing.enabled=true`로 변경
2. direct 모드 B열 중심 테스트 CSV로 실행
3. 헤더/안내 행을 스킵하고 `@...@` 형식만 처리되는지 확인
4. B2, B3 등 여러 행도 순차 처리되는지 확인
5. 체크 대상 건이 자동 체크되는지 확인
6. 다음 행으로 계속 진행되는지 확인
7. `logs\processing\yyyy\MM\yyyyMMdd_row_results.csv` 생성 확인
8. `reason=checked_and_saved` 인 행은 `team.processing.screenshot_dir\yyyy\MM\yyyyMMdd` 경로에 성공 스크린샷이 저장되는지 확인
9. `reason=already_checked` 인 행은 `screenshot_path`가 비어 있고 별도 성공 스크린샷 파일도 생기지 않는지 확인
10. `screenshot_dir`가 로컬 캐시일 때만 `.\scripts\sync_screenshots.ps1 -Team processing` 실행 후 `team.processing.screenshot_sync_dir\yyyy\MM\yyyyMMdd`에 동일 파일 반영 확인

## 5. 중복 방지 테스트

1. 동일 CSV로 두 번 실행한다.
2. 이미 성공한 행이 `skipped_done`으로 기록되는지 확인한다.
3. `logs\history\yyyy\MM\yyyyMMdd_history_success.csv`와 `row_results.csv`가 일치하는지 확인한다.
4. 같은 날짜의 같은 팀/파트에서 이미 `success` 처리된 접수번호가 다른 파일에서 다시 나타나면 `reason=duplicate_receipt_today`로 기록되는지 확인한다.
5. 같은 팀명이더라도 다른 파트 CSV에서는 같은 접수번호가 서로 `duplicate_receipt_today`로 막히지 않는지 확인한다.
6. 같은 접수번호라도 이전 시도가 `failed`뿐이면 다시 QR 처리되는지 확인한다.
7. 금요일 cutoff 이후에는 분석화학평가팀 2개 파트가 주말 폴더 대신 다음 평일 폴더를 우선 선택하는지 `team_files_ready`, `team_file_selected` 로그로 확인한다.

## 5-1. 가공성능평가팀 빠른 스킵 테스트

1. `team.processing.stop_file_on_empty_scan_column=true` 상태에서 B1에 유효 접수번호, B2가 빈 값인 CSV로 실행
2. `row=2`에서 `empty_scan_column`과 `csv_scan_stop`이 찍히고 같은 CSV의 이후 행은 처리되지 않는지 확인
3. 정오 이후 실행 시 과거 날짜 폴더 CSV가 선택되지 않는지 확인
4. 정오 이전 실행 시 과거 날짜 폴더 CSV 중 생성 시간이 17시 이후인 파일만 선택되는지 확인
5. 당일 날짜 폴더 CSV는 기존 `file_select_policy` 기준으로 처리되는지 확인

## 6. 실패/재시도 테스트

1. QR 입력이 실패하도록 일부러 창을 가리거나 잘못된 조건을 만든다.
2. 동일 행이 최대 3회 재시도되는지 확인한다.
3. 3회 실패 후 다음 행으로 넘어가는지 확인한다.
4. 실패 건도 스크린샷이 남는지 확인한다.
5. 다음 실행에서 실패 건이 다시 시도되는지 확인한다.

## 7. 세션 복구 테스트

1. 실행 중 FITI를 강제 종료하거나 로그인 창이 다시 뜨게 만든다.
2. 자동 재로그인이 최대 3회 시도되는지 확인한다.
3. 3회 실패 후 현재 실행이 `wait_next_schedule` 성격으로 종료되는지 확인한다.
4. 실패 내용이 `logs\debug`와 `row_results.csv`에 기록되는지 확인한다.

## 8. 종료 확인

1. 팀 작업 종료 후 FITI가 완전히 종료되는지 확인한다.
2. `runtime\qrinput.lock`이 정상 해제되는지 확인한다.
3. CSV 원본 파일은 이동되지 않고 그대로 남는지 확인한다.

## 9. 스케줄러 연동 전 최종 확인

1. 분석화학평가팀, 분석화학평가팀 아릴아민, 가공성능평가팀 각각 1회 이상 성공 실행
2. 중복 실행 차단 확인
3. 중복 처리 방지 확인
4. 실패 후 다음 실행 재시도 확인
5. 세션 복구 시나리오 1회 이상 검증
6. 로그와 로컬 스크린샷 경로 검증
7. `scripts\sync_screenshots.ps1` 동기화 검증
