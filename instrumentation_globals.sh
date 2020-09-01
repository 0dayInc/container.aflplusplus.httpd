#!/bin/bash --login
# INSTRUMENTATION GLOBALS:
# Define CC && CXX
export preferred_afl='afl-clang-lto'
export preferred_aflplusplus='afl-clang-lto++'
export preferred_afl_linker='afl-ld-lto'
export preferred_afl_ranlib='llvm-ranlib-11'
export preferred_afl_ar='llvm-ar-11'
export preferred_afl_nm='llvm-nm-11'

export AFL_LLVM_LTO_AUTODICTIONARY=1
export AFL_LLVM_MAP_DYNAMIC=1

# InsTrim uses CFG and markers to instrument
# just what is necessary in the binary in 
# llvm_mode. It is about 10-15% faster without
# disadvantages.
export AFL_LLVM_INSTRUMENT=CFG

# There is also an advanced mode which instruments 
# loops in a way so that afl-fuzz can see which loop 
# path has been selected but not being able to see how 
# often the loop has been rerun.  This again is a 
# tradeoff for speed for less path information.
#export AFL_LLVM_INSTRIM_LOOPHEAD=1

#export AFL_LLVM_LAF_SPLIT_SWITCHES=1
#export AFL_LLVM_LAF_SPLIT_COMPARES=1
#export AFL_LLVM_LAF_SPLIT_FLOATS=1
#export AFL_LLVM_LAF_ALL=1
#export AFL_HARDEN=1

# Use Address Sanitizer
#export AFL_USE_ASAN=1
#export ASAN_OPTIONS=verbosity=3,detect_leaks=0,abort_on_error=1,symbolize=0,check_initialization_order=true,detect_stack_use_after_return=true,strict_string_checks=true,detect_invalid_pointer_pairs=2 

# Use Memory Sanitizer
export AFL_USE_MSAN=1
#export MSAN_OPTIONS=exit_code=86,abort_on_error=1,symbolize=0,msan_track_origins=0,allocator_may_return_null=1

# Use Unexpected Behavior Sanitizer
#export AFL_USE_UBSAN=1

# Use Control Flow Integrity Sanitizer
#export AFL_USE_CFISAN=1
