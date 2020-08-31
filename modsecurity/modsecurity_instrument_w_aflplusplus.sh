#!/bin/bash --login
# TODO: Get lto working
#preferred_afl='afl-clang-lto'
#preferred_aflplusplus='afl-clang-lto++'
preferred_afl='afl-clang-fast'
preferred_aflplusplus='afl-clang-fast++'

docker_repo_root='/opt/container.aflplusplus.httpd'

# Define Target Instrumentation via instrumentation_globals.sh
source $docker_repo_root/instrumentation_globals.sh

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

modsecurity_github='https://github.com/SpiderLabs/ModSecurity'

httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"
modsecurity_repo="${httpd_repo}/modules/modsecurity"
repo_name=`basename ${modsecurity_repo}`

cd `dirname ${modsecurity_repo}`
git clone $fastcgi_github modsecurity

# Instrument modsecurity
cd ${modsecurity_repo}
CC=$preferred_afl CXX=$preferred_aflplusplus ./build.sh
CC=$preferred_afl CXX=$preferred_aflplusplus ./configure
CC=$preferred_afl CXX=$preferred_aflplusplus make
make install
