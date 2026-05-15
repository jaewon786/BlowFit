# PlatformIO pre-build hook -- LVGL 라이브러리에서 ESP32-S3 (Xtensa) 와 호환
# 안 되는 source 파일들을 빌드에서 제외.
#
# 두 가지 방법 병행:
#   1. library.json 에 srcFilter 추가 (LDF 가 인식하면 효력 발생)
#   2. helium .S 파일을 .S.disabled 로 rename (PIO 가 어셈블 안 함, 가장 확실)
#
# 이유: LVGL 9.2+ 는 ARM Cortex-M55 Helium SIMD 어셈블리가 src/draw/sw/blend/
# helium/ 에 포함. ESP32-S3 Xtensa toolchain 이 ARM .S 를 컴파일 시도하면서
# "unknown opcode 'typedef'" 에러 발생. LDF chain 모드 + lib_archive=false 조합
# 에서 srcFilter 가 신뢰성 있게 적용 안 되어서 직접 rename 으로 차단.

import json
from pathlib import Path

Import("env")  # noqa: F821

LIBDEPS = Path(env.subst("$PROJECT_LIBDEPS_DIR"))  # noqa: F821
PIOENV  = env.subst("$PIOENV")                     # noqa: F821

lvgl_dir = LIBDEPS / PIOENV / "lvgl"
lib_json = lvgl_dir / "library.json"

# ---- (1) library.json 에 srcFilter 추가 ----
EXCLUDES = [
    "-<src/draw/sw/blend/helium/>",
    "-<src/draw/sw/blend/neon/>",
    "-<src/draw/nxp/>",
    "-<src/draw/renesas/>",
    "-<src/draw/sdl/>",
    "-<src/draw/opengles/>",
    "-<src/draw/vg_lite/>",
    "-<src/draw/dma2d/>",
    "-<src/draw/dave2d/>",
    "-<src/draw/g2d/>",
    "-<src/draw/pxp/>",
    "-<src/draw/vglite/>",
    "-<demos/>",
    "-<examples/>",
    "-<tests/>",
    "-<env_support/>",
    "-<docs/>",
    "-<scripts/>",
]

def patch_library_json():
    if not lib_json.exists():
        print(f"[patch_lvgl] {lib_json} not found yet -- will run on next build")
        return
    with open(lib_json, "r", encoding="utf-8") as f:
        data = json.load(f)
    build = data.setdefault("build", {})
    src_filter = build.get("srcFilter", ["+<*>"])
    if isinstance(src_filter, str):
        src_filter = [src_filter]
    changed = False
    for excl in EXCLUDES:
        if excl not in src_filter:
            src_filter.append(excl)
            changed = True
    if changed:
        build["srcFilter"] = src_filter
        with open(lib_json, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"[patch_lvgl] Patched {lib_json} -- srcFilter updated")
    else:
        print(f"[patch_lvgl] {lib_json} already patched -- skip")

# ---- (2) 호환 안 되는 .S / .c 파일을 .disabled 로 rename ----
DISABLE_PATTERNS = [
    # ARM Helium / NEON SIMD .S
    "src/draw/sw/blend/helium",
    "src/draw/sw/blend/neon",
    # 외부 GPU 드라이버 (ESP32 무관)
    "src/draw/nxp",
    "src/draw/renesas",
    "src/draw/sdl",
    "src/draw/opengles",
    "src/draw/vg_lite",
    "src/draw/dma2d",
    "src/draw/dave2d",
    "src/draw/g2d",
    "src/draw/pxp",
    "src/draw/vglite",
]
DISABLE_EXTS = (".S", ".c", ".cpp")

def disable_incompatible_sources():
    if not lvgl_dir.exists():
        print(f"[patch_lvgl] {lvgl_dir} not found yet")
        return
    count = 0
    for pat in DISABLE_PATTERNS:
        target_dir = lvgl_dir / pat
        if not target_dir.exists():
            continue
        for ext in DISABLE_EXTS:
            for src_file in target_dir.rglob(f"*{ext}"):
                disabled = src_file.with_suffix(src_file.suffix + ".disabled")
                if not disabled.exists():
                    src_file.rename(disabled)
                    count += 1
    if count > 0:
        print(f"[patch_lvgl] Renamed {count} incompatible source files to .disabled")
    else:
        print(f"[patch_lvgl] No new files to disable -- skip")

# 실행
patch_library_json()
disable_incompatible_sources()
