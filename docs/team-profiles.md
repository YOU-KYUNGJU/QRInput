# 팀 프로필

## 분석화학평가팀
- 파트: pH/폼알데하이드
- 접수번호 생성: compose
- 기본 조합: A + D + B
- 행 스캔 기준: A열
- 날짜 cutoff: 오전 11시 기준
- 미래 날짜 폴더 허용: 예
- 실패 정책: continue
- 완료 파일 이동: 아니오
- 원본 CSV 유지: 예

## 가공성능평가팀
- 파트: 수축율
- 접수번호 생성: direct
- 기본 사용 열: B열
- 행 스캔 기준: B열
- 행 유효 패턴: `@.*@`
- 날짜 cutoff: 오전 10시 기준
- 미래 날짜 폴더 허용: 운영값으로 선택
- 실패 정책: continue
- 완료 파일 이동: 선택 가능
- 원본 CSV 유지: 예

## 공통 운영 정책
1. 실행 시작 전에 기존 FITI가 있으면 종료
2. 팀 작업 종료 후 FITI 종료
3. 세션 끊김 시 자동 재로그인 최대 3회
4. 행 실패는 최대 3회 재시도
5. 치명적 예외가 아니면 전체 프로그램은 멈추지 않음
6. 성공/실패 모두 CSV 로그와 스크린샷 기록

## 팀별 설정으로만 관리할 항목
- 계정
- csv_root_path
- cutoff_hour
- file_select_policy
- postprocess_mode
- receipt extraction mode
- failure policy
- screenshot/log path
- checkbox/save 판단 기준
