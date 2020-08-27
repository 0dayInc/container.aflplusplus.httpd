#!/bin/bash --login
# TODO: Get lto working
#preferred_afl='afl-clang-lto'
#preferred_aflplusplus='afl-clang-lto++'
#preferred_afl='afl-clang-fast'
#preferred_aflplusplus='afl-clang-fast++'
preferred_afl='afl-gcc'
preferred_aflplusplus='afl-g++'

docker_repo_root='/opt/container.aflplusplus.httpd'

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

github_root='https://github.com/FastCGI-Archives/FastCGI.com/raw/master/original_snapshot'
mod_fastcgi_tar_gz='mod_fastcgi-SNAP-0910052141.tar.gz'
mod_fastcgi_uri="${github_root}/${mod_fastcgi_tar_gz}"

httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"
mod_fastcgi_repo="${httpd_repo}/mod_fastcgi-SNAP-0910052141"
repo_name=`basename ${mod_fastcgi_repo}`

cd $httpd_repo && wget $mod_fastcgi_uri && tar -xzvf $mod_fastcgi_tar_gz

# Instrument mod_fastcgi
cd ${mod_fastcgi_repo}
cp Makefile.AP2 Makefile
CC=$preferred_afl CXX=$preferred_aflplusplus make top_dir=$httpd_repo
make install
