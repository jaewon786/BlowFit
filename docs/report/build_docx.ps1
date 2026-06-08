# ============================================================
#  BRELOW 레포트북 → 단일 docx 빌드 (PowerShell 용)
#
#  사용법:
#    1. pandoc 설치  →  winget install --id JohnMacFarlane.Pandoc -e
#    2. PowerShell 새 창 열어서:
#         cd C:\projects\cpd\BlowFit\docs\report
#         .\build_docx.ps1
#       (실행 정책 막혀 있으면 한 번 풀어주기:
#          Set-ExecutionPolicy -Scope CurrentUser RemoteSigned)
#
#  출력: BRELOW_report.docx
# ============================================================

Set-Location -Path $PSScriptRoot

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
  Write-Host "[ERROR] pandoc 이 PATH 에 없습니다." -ForegroundColor Red
  Write-Host "        winget install --id JohnMacFarlane.Pandoc -e  로 설치 후"
  Write-Host "        새 PowerShell 창에서 다시 실행하세요."
  exit 1
}

$chapters = @(
  '01_introduction.md',
  '02_system_overview.md',
  '03_hardware.md',
  '04_firmware.md',
  '05_ble_protocol.md',
  '06_clinical.md',
  '07_app.md',
  '08_data.md',
  '09_companion.md',
  '10_validation.md',
  '11_conclusion.md',
  'appendix.md'
)

Write-Host "[build] pandoc 으로 12 챕터를 단일 docx 로 병합합니다..."
pandoc $chapters `
  -o BRELOW_report.docx `
  --toc --toc-depth=2 `
  -V lang=ko-KR

if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] pandoc 변환 실패." -ForegroundColor Red
  exit 1
}

Write-Host "[done] BRELOW_report.docx 생성 완료." -ForegroundColor Green
Write-Host "        파일 위치: $PSScriptRoot\BRELOW_report.docx"
