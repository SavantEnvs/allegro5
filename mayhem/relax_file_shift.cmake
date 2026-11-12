# Included right after project(). al_fread32le/be build a signed int32 as (b << 24) | ..., which
# trips UBSan's shift-base check on every file with a high byte >= 0x80. Relax only that check, only
# for src/file.c (SPEC: relaxed checks are recorded in the PR).
set_source_files_properties("${CMAKE_SOURCE_DIR}/src/file.c" PROPERTIES COMPILE_OPTIONS "-fno-sanitize=shift-base")
