#!/bin/bash --login
# TODO: Get lto working
#preferred_afl='afl-clang-lto'
#preferred_aflplusplus='afl-clang-lto++'
preferred_afl='afl-clang-fast'
preferred_aflplusplus='afl-clang-fast++'

docker_repo_root='/opt/container.aflplusplus.httpd'

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

fastcgi_github='https://github.com/FastCGI-Archives/mod_fastcgi'

httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"
mod_fastcgi_repo="${httpd_repo}/modules/mod_fastcgi"
repo_name=`basename ${mod_fastcgi_repo}`

cd `dirname ${mod_fastcgi_repo}`
git clone $fastcgi_github

# Instrument mod_fastcgi
cd ${mod_fastcgi_repo}
cp Makefile.AP2 Makefile
sed -i 's/\/usr\/local\/apache2/\/fuzz_session\/httpd_src/g' Makefile
CC=$preferred_afl CXX=$preferred_aflplusplus make
make install
