# 팀 프로필

## 분석화학평가팀 pH/폼알데하이드
- 파트: `pH/폼알데하이드`
- 접수번호 생성: `compose`
- 조합 순서: `A + D + B`
- compose zero-padding: `receipt_compose_pad_spec=B:5`
- 행 스캔 기준 열: `A`
- 행 스캔 패턴: `^[A-Z][0-9]{3}$`
- cutoff: `14`
- 미래 날짜 폴더 사용: `true`
- 미래 폴더 모드: `next_business_day`
- cutoff 이후 오늘 폴더 신규 파일 추가 수집: `true`
- 오늘 폴더 생성 시각 기준: `14`
- 최근 날짜 폴더 개수: `1`
- 파일 선택 정책: `all_csv_in_target_folder`
- 실패 정책: `continue`
- 완료 파일 이동: 사용 안 함

## 분석화학평가팀 아릴아민
- 파트: `아릴아민`
- 접수번호 생성: `compose`
- 조합 순서: `A + D + B`
- compose zero-padding: `receipt_compose_pad_spec=B:5`
- 행 스캔 기준 열: `A`
- 행 스캔 패턴: `^[A-Z][0-9]{3}$`
- cutoff: `14`
- 미래 날짜 폴더 사용: `true`
- 미래 폴더 모드: `next_business_day`
- cutoff 이후 오늘 폴더 신규 파일 추가 수집: `true`
- 오늘 폴더 생성 시각 기준: `14`
- 최근 날짜 폴더 개수: `1`
- 파일 선택 정책: `all_csv_in_target_folder`
- 실패 정책: `continue`
- 완료 파일 이동: 사용 안 함

## 가공성능평가팀
- 파트: `수축율`
- 접수번호 생성: `direct`
- 직접 사용 열: `B`
- 행 스캔 기준 열: `B`
- 행 스캔 패턴: `^@[A-Z][A-Z0-9]+@$`
- cutoff: `10`
- 미래 날짜 폴더 사용: `false`
- 미래 폴더 모드: `nearest_future`
- 최근 날짜 폴더 개수: `2`
- 파일 선택 정책: `created_after_hour`
- 과거 날짜 스캔 허용 시각: `12` 이전
- 과거 날짜 파일 생성 시각 조건: `17` 이후
- 빈 스캔 열에서 파일 처리 중단: `true`
- 실패 정책: `continue`
- 완료 파일 이동: 선택 가능

## 공통 운영 정책
1. 실행 시작 전에 기존 FITI가 떠 있으면 종료한다.
2. 각 팀 작업 종료 후 FITI를 종료한다.
3. 세션 복구를 위한 자동 재로그인은 최대 3회 시도한다.
4. 각 행 처리 실패는 최대 3회 재시도한다.
5. 치명적 예외가 아니면 프로그램 전체를 멈추지 않고 다음 행 또는 다음 파일로 진행한다.
6. 성공과 실패 모두 CSV 로그와 스크린샷으로 남긴다.

## 설정으로만 관리할 항목
- 계정
- `csv_root_path`
- `cutoff_hour`
- `allow_future_folder`
- `future_folder_mode`
- `include_today_folder_after_cutoff`
- `today_file_created_after_hour`
- `recent_date_folder_count`
- `file_select_policy`
- `receipt_mode`
- `receipt_compose_pad_spec`
- 실패 정책
- 로그 경로
- 스크린샷 경로

## 폴더 선택 규칙
- 공통 기본값은 오늘 날짜 폴더 우선이다.
- 날짜 폴더 탐색 순서는 `root\yyyyMMdd` -> `root\yyyy\MM\yyyyMMdd` -> 재귀 탐색 -> root CSV fallback 이다.
- `allow_future_folder=true` 이고 cutoff 이후이면 미래 날짜 폴더를 찾는다.
- `future_folder_mode=nearest_future` 이면 오늘보다 큰 가장 가까운 날짜 폴더를 우선 선택한다.
- `future_folder_mode=next_business_day` 이면 다음 평일 날짜 폴더를 우선 선택한다.
- `include_today_folder_after_cutoff=true` 이면 cutoff 이후에도 오늘 날짜 폴더를 함께 훑되, `today_file_created_after_hour` 이상에 생성된 CSV만 추가 수집한다.
- `next_business_day` 모드에서 대상 폴더가 없으면 기존 미래 폴더 탐색 또는 오늘 폴더 fallback 으로 내려간다.
- `recent_date_folder_count > 1` 이면 오늘 기준 최근 날짜 폴더 여러 개를 모아 CSV를 수집한다.
- `previous_date_scan_before_hour` 이 설정되면 해당 시각 이후 과거 날짜 폴더 CSV는 제외한다.
- `previous_date_created_after_hour` 이 설정되면 과거 날짜 폴더 CSV 중 생성 시각이 기준 시각 이상인 파일만 포함한다.
- `stop_file_on_empty_scan_column=true` 이면 빈 스캔 열을 만나면 현재 CSV 처리를 종료하고 다음 파일로 넘어간다.
- `skip_today_success_receipt=true` 이면 같은 날짜의 같은 팀/파트에서 이미 성공한 접수번호는 `duplicate_receipt_today` 로 스킵한다.
