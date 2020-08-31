#!/bin/bash --login
# TODO: Get lto working
docker_repo_root='/opt/container.aflplusplus.httpd'

# Define Target Instrumentation via instrumentation_globals.sh
source $docker_repo_root/instrumentation_globals.sh

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

mod_fastcgi_github='https://github.com/FastCGI-Archives/mod_fastcgi'

httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"
mod_fastcgi_repo="${httpd_repo}/modules/mod_fastcgi"
repo_name=`basename ${mod_fastcgi_repo}`

cd `dirname ${mod_fastcgi_repo}`
git clone $mod_fastcgi_github

# Instrument mod_fastcgi
cd ${mod_fastcgi_repo}
cp Makefile.AP2 Makefile
sed -i 's/\/usr\/local\/apache2/\/fuzz_session\/httpd_src/g' Makefile
CC=$preferred_afl CXX=$preferred_aflplusplus RANLIB=$preferred_afl_ranlib AR=$preferred_afl_ar NM=$preferred_alf_nm make
make install
