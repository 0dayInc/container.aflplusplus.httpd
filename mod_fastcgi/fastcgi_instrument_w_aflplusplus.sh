#!/bin/bash --login
# TODO: Get lto working
#preferred_afl='afl-clang-lto'
#preferred_aflplusplus='afl-fast-clang-lto++'
#preferred_afl='afl-clang'
#preferred_aflplusplus='afl-fast-clang++'
preferred_afl='afl-gcc'
preferred_aflplusplus='afl-g++'

docker_repo_root='/opt/container.aflplusplus.httpd'

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

github_root='https://github.com/FastCGI-Archives/FastCGI.com/raw/master/original_snapshot'
fastcgi_tar_gz='fcgi-2.4.1-SNAP-0910052249.tar.gz'
fastcgi_uri="${github_root}/${fastcgi_tar_gz}"

fastcgi_repo="${fuzz_session_root}/fcgi-2.4.1-SNAP-0910052249"
repo_name=`basename ${fastcgi_repo}`

if [[ ! -d $fastcgi_repo ]]; then
  mkdir $fastcgi_repo
fi

cd $fuzz_session_root && wget $fastcgi_uri && tar -xzvf $fastcgi_tar_gz

# Instrument fastcgi
cd ${fastcgi_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus ./configure
cd ${fastcgi_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus make
make install
