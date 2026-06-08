# BRELOW — 졸업 작품 레포트북

> **프로젝트명**: BRELOW — 호흡근 양방향 훈련 디바이스 + 컴패니언 앱
> **소속**: 한남대학교 디자인팩토리 CPD
> **버전**: v4.1 (2026-06 기준)
> **저장 위치**: `docs/report/`

---

## 1. 본 문서의 구성

본 레포트북은 단일 markdown 파일이 아니라 **챕터별 분할 파일**로 구성된다. 검토와 편집이 용이하며, `pandoc` 으로 단일 docx/PDF 로 병합 가능하다.

```
docs/report/
├── 00_README.md            ← 본 문서 (목차/규약)
├── 01_introduction.md      서론 — 배경, 목표, 시장 조사
├── 02_system_overview.md   시스템 개요 — 아키텍처, 시나리오, 기능 인벤토리
├── 03_hardware.md          하드웨어 — BOM, 회로, 핀맵, 센서 원리
├── 04_firmware.md          펌웨어 — 모듈, state machine, 햅틱, 전원
├── 05_ble_protocol.md      BLE 프로토콜 — GATT, 5 char, 6 opcode
├── 06_clinical.md          임상 근거 — PImax/MEP, %적응형, 안전 상한
├── 07_app.md               앱 설계 — Flutter, 라우트, 화면, 캐릭터
├── 08_data.md              데이터 관리 — Drift / SharedPrefs / NVS / Firestore / Samsung Health
├── 09_companion.md         동반자 모드 + 알림
├── 10_validation.md        검증 — 빌드, BLE 안정성, 측정 정확도
├── 11_conclusion.md        결론 및 향후 개선
└── appendix.md             부록 — 디렉토리 트리, BLE 전문, 핀맵, 참고문헌
```

---

## 2. 목차 (전체)

| 장 | 제목 | 예상 분량 |
|---|---|---|
| 1 | 서론 | 4 p |
| 2 | 시스템 개요 | 4 p |
| 3 | 하드웨어 설계 | 6 p |
| 4 | 펌웨어 설계 | 8 p |
| 5 | 통신 프로토콜 | 5 p |
| 6 | 임상 근거 및 훈련 알고리즘 | 5 p |
| 7 | 앱 설계 | 10 p |
| 8 | 데이터 관리 | 4 p |
| 9 | 동반자 모드 및 알림 | 3 p |
| 10 | 검증 및 평가 | 4 p |
| 11 | 결론 | 2 p |
| 부록 | A 디렉토리 / B BLE / C 핀맵 / D 스크린샷 / E 참고문헌 | 5 p |
| **합계** | | **약 60 p** |

---

## 3. 작성 규약

### 3.1 문체

- **격식체** (~하다, ~한다) 위주.
- 임상 / 학술 용어는 한글(영문) 병기. 예: 최대 흡기압(PImax), 최대 호기압(MEP, Maximal Expiratory Pressure).
- 코드 식별자는 `백틱` 으로 감싼다. 예: `session::startSession()`.

### 3.2 표기

| 기호 | 의미 |
|---|---|
| ✅ | 구현 완료 |
| ⚠️ | 주의 / 제한 사항 |
| ❌ | 미구현 / 알려진 한계 |
| ▶ | 추후 개선 항목 |

### 3.3 단위

- 압력: **cmH₂O** (기본 단위). kPa 병기는 §3·§6 에 한정.
- 시간: 초(s) / 분 단위. 밀리초는 펌웨어 코드 인용 시에만.
- 코드 단위: 펌웨어 cmH₂O × 10 (정수), BLE wire 동일.

### 3.4 인용 / 참고 문헌

- 본문 내 인용: 「(저자 연도)」 또는 「[1]」.
- 전체 참고 문헌은 **부록 E**.
- 코드 인용 시 파일 경로 + 라인 번호: `firmware-esp32/src/session.cpp:123-145`.

### 3.5 그림 / 표 번호

- 그림 「그림 X.Y」, 표 「표 X.Y」 (X = 장 번호).
- 캡션은 그림 / 표 아래.

---

## 4. pandoc 변환 (단일 docx / PDF 생성)

### 4.1 pandoc 설치 (Windows)

```cmd
winget install --id JohnMacFarlane.Pandoc -e
```

설치 후 **새 cmd / PowerShell 창** 을 열어야 PATH 가 반영된다.

```cmd
pandoc --version
```

### 4.2 docx 빌드 — 가장 쉬운 방법 (Windows)

본 폴더의 `build_docx.bat` 를 **더블 클릭** 또는 cmd 에서 실행:

```cmd
cd C:\projects\cpd\BlowFit\docs\report
build_docx.bat
```

또는 PowerShell:

```powershell
cd C:\projects\cpd\BlowFit\docs\report
.\build_docx.ps1
```

결과: `BRELOW_report.docx` 가 같은 폴더에 생성된다.

### 4.3 한 줄 명령 (cmd 직접 입력)

```cmd
pandoc 01_introduction.md 02_system_overview.md 03_hardware.md 04_firmware.md 05_ble_protocol.md 06_clinical.md 07_app.md 08_data.md 09_companion.md 10_validation.md 11_conclusion.md appendix.md -o BRELOW_report.docx --toc --toc-depth=2 -V lang=ko-KR
```

> **주의** — Windows cmd 는 백슬래시(`\`) 줄 연속을 인식하지 않는다. 줄을 나누고 싶으면 `^` 를 끝에 붙이거나, 한 줄에 다 쓴다. PowerShell 은 백틱(`` ` ``) 을 줄 연속으로 사용한다.

### 4.4 macOS / Linux (bash)

```bash
cd docs/report
pandoc \
  01_introduction.md 02_system_overview.md \
  03_hardware.md 04_firmware.md 05_ble_protocol.md \
  06_clinical.md 07_app.md 08_data.md 09_companion.md \
  10_validation.md 11_conclusion.md appendix.md \
  -o BRELOW_report.docx \
  --toc --toc-depth=2 \
  -V lang=ko-KR
```

### 4.5 표지 / 머리말이 있는 템플릿 적용

워드로 `template.docx` 를 만들고 표지 · 머리말 · 글꼴을 잡아둔 뒤:

```cmd
pandoc ... -o BRELOW_report.docx --reference-doc=template.docx ...
```

### 4.6 PDF 변환 (선택)

xelatex + CJK 폰트 필요. Windows 에서는 MiKTeX 설치 후:

```cmd
pandoc 01_introduction.md ... appendix.md ^
  -o BRELOW_report.pdf ^
  --pdf-engine=xelatex ^
  -V CJKmainfont="Pretendard" ^
  --toc --toc-depth=2
```

PDF 가 어려우면 docx 로 만든 뒤 워드에서 "다른 이름으로 저장 → PDF" 가 가장 간단하다.

---

## 5. 작성 진행 상황

| Phase | 챕터 | 상태 |
|---|---|---|
| P0 | 00_README | ✅ |
| P1 | 03 / 04 / 05 | (진행) |
| P2 | 06 | |
| P3 | 07 | |
| P4 | 02 / 08 / 09 | |
| P5 | 10 / 11 / 01 | |
| P6 | 부록 | |

> 상태 추적은 본 README 의 본 표를 직접 갱신.

---

## 6. 1차 소스 (코드/문서) 매핑

각 챕터 작성 시 직접 인용 가능한 1차 자료의 위치:

| 챕터 | 1차 소스 |
|---|---|
| §3 하드웨어 | `firmware-esp32/docs/wiring.md`, `include/config.h::pins` |
| §4 펌웨어 | `firmware-esp32/include/*.h`, `firmware-esp32/src/session.cpp` |
| §5 BLE | `docs/ble-protocol.md`, `include/ble_uuids.h`, `src/ble_service.cpp` |
| §6 임상 | `include/config.h::session` (주석 인용), `app/lib/core/storage/pimax_mep_store.dart` |
| §7 앱 | `app/lib/main.dart` (라우트), `app/lib/features/**` |
| §8 데이터 | `app/lib/core/db/app_database.dart`, `app/lib/core/storage/*.dart` |
| §9 동반자 | `app/lib/core/pairing/pairing_service.dart` |
| §10 검증 | `app/test/**`, `firmware-esp32/test/**` |

---

*— 본 README 끝 —*
