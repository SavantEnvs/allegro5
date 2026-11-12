#!/usr/bin/env bash
#
# Builds Allegro 5 twice: a sanitized static build that the fuzz harnesses link against, and a
# plain build of upstream's functional test driver that mayhem/test.sh runs. Idempotent and
# offline: every dependency is an apt -dev package installed by the Dockerfile.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

: "${SRC:=/mayhem}"
cd "$SRC"

# Options shared by both builds: static libraries, the X11 backend (it runs headless when no X
# server is reachable, which is how every harness and test runs), and no docs/examples/demos.
CMAKE_COMMON=(-G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX"
  -DSHARED=OFF -DWANT_DOCS=OFF -DWANT_DEMO=OFF -DWANT_EXAMPLES=OFF -DWANT_POPUP_EXAMPLES=OFF
  -DWANT_NATIVE_DIALOG=OFF -DWANT_PHYSFS=OFF)

# 1) Sanitized library for the fuzzers. fuzzer-no-link adds SanCov to the library code only.
FUZZ_DIR="$SRC/build/fuzz"
# Two UBSan checks are relaxed, everything else stays halting: -fsanitize=function, because Allegro
# stores destructors as void(*)(void *) and calls them through that type (every bitmap/font/sample
# teardown), and shift-base in src/file.c only (see mayhem/relax_file_shift.cmake).
SAN="$SANITIZER_FLAGS -fno-sanitize=function"
cmake -S "$SRC" -B "$FUZZ_DIR" "${CMAKE_COMMON[@]}" -DWANT_TESTS=OFF \
  -DCMAKE_PROJECT_INCLUDE="$SRC/mayhem/relax_file_shift.cmake" \
  -DCMAKE_C_FLAGS="$SAN -fsanitize=fuzzer-no-link $DEBUG_FLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="$SAN"
cmake --build "$FUZZ_DIR" -j"$MAYHEM_JOBS"

ALLEGRO_MODULES="allegro_image-static-5 allegro_audio-static-5 allegro_acodec-static-5
  allegro_font-static-5 allegro_ttf-static-5 allegro_memfile-static-5 allegro-static-5"
export PKG_CONFIG_PATH="$FUZZ_DIR/lib/pkgconfig"
A5_CFLAGS="-I$SRC/include -I$FUZZ_DIR/include -I$SRC/addons/image -I$SRC/addons/audio -I$SRC/addons/acodec
  -I$SRC/addons/font -I$SRC/addons/ttf -I$SRC/addons/memfile"
# shellcheck disable=SC2086
A5_LIBS="$(pkg-config --static --libs --define-variable=prefix="$FUZZ_DIR" $ALLEGRO_MODULES)"

# 2) Harnesses: libFuzzer binary + standalone reproducer each. lsan_off.cc turns LeakSanitizer off.
HARNESS_DIR="$SRC/mayhem/harnesses"
$CXX $SAN $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$FUZZ_DIR/lsan_off.o"
$CC $SAN $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$FUZZ_DIR/standalone_main.o"
for t in fuzz_bmp fuzz_tga fuzz_pcx fuzz_image fuzz_sample fuzz_config fuzz_ttf; do
  # shellcheck disable=SC2086
  $CC $SAN $DEBUG_FLAGS -I"$HARNESS_DIR" $A5_CFLAGS -c "$HARNESS_DIR/$t.c" -o "$FUZZ_DIR/$t.o"
  # shellcheck disable=SC2086
  $CC $SAN $DEBUG_FLAGS $LIB_FUZZING_ENGINE "$FUZZ_DIR/$t.o" "$FUZZ_DIR/lsan_off.o" \
    $A5_LIBS -lstdc++ -o "$SRC/$t"
  # shellcheck disable=SC2086
  $CC $SAN $DEBUG_FLAGS "$FUZZ_DIR/standalone_main.o" "$FUZZ_DIR/$t.o" "$FUZZ_DIR/lsan_off.o" \
    $A5_LIBS -lstdc++ -o "$SRC/$t-standalone"
done

# 3) Upstream's functional test driver with the project's normal flags, for mayhem/test.sh.
TEST_DIR="$SRC/build/test"
cmake -S "$SRC" -B "$TEST_DIR" "${CMAKE_COMMON[@]}" -DWANT_TESTS=ON \
  -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS"
cmake --build "$TEST_DIR" -j"$MAYHEM_JOBS" --target test_driver
