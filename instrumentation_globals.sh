#!/bin/bash --login
# INSTRUMENTATION GLOBALS:
export AFL_LLVM_INSTRUMENT=CFG
export AFL_LLVM_INSTRIM_LOOPHEAD=1
export AFL_LLVM_LTO_AUTODICTIONARY=1
export AFL_LLVM_LAF_ALL=1
export AFL_HARDEN=1
#export AFL_USE_ASAN=1 # No Workie w/ afl-clang-fast
export AFL_USE_MSAN=1
export AFL_USE_UBSAN=1
#export AFL_USE_CFISAN=1 # No Workie w/ httpd
