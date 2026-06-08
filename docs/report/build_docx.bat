@echo off
REM ============================================================
REM  BRELOW 레포트북 → 단일 docx 빌드 (Windows cmd 용)
REM
REM  사용법:
REM    1. pandoc 설치  →  winget install --id JohnMacFarlane.Pandoc -e
REM    2. 새 cmd 창 열어서 이 폴더로 cd
REM    3. build_docx.bat 실행 (그냥 더블 클릭도 OK)
REM
REM  출력: BRELOW_report.docx
REM ============================================================

cd /d "%~dp0"

where pandoc >nul 2>nul
if errorlevel 1 (
  echo [ERROR] pandoc 이 PATH 에 없습니다.
  echo         winget install --id JohnMacFarlane.Pandoc -e  로 설치 후
  echo         새 cmd 창에서 다시 실행하세요.
  pause
  exit /b 1
)

echo [build] pandoc 으로 12 챕터를 단일 docx 로 병합합니다...
pandoc ^
  01_introduction.md ^
  02_system_overview.md ^
  03_hardware.md ^
  04_firmware.md ^
  05_ble_protocol.md ^
  06_clinical.md ^
  07_app.md ^
  08_data.md ^
  09_companion.md ^
  10_validation.md ^
  11_conclusion.md ^
  appendix.md ^
  -o BRELOW_report.docx ^
  --toc --toc-depth=2 ^
  -V lang=ko-KR

if errorlevel 1 (
  echo [ERROR] pandoc 변환 실패.
  pause
  exit /b 1
)

echo [done] BRELOW_report.docx 생성 완료.
echo        파일 위치: %~dp0BRELOW_report.docx
pause
