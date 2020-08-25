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

mod_fastcgi_tar_gz='mod_fastcgi-2.0-1.1.1.tar.gz'
mod_fastcgi_uri="http://pam.sourceforge.net/mod_fastcgi/dist/${mod_fastcgi_tar_gz}"
httpd_repo="${fuzz_session_root}/httpd"
httpd_prefix="${httpd_repo}/BINROOT"
mod_fastcgi_repo="${httpd_repo}/mod_fastcgi"
repo_name=`basename ${mod_fastcgi_repo}`

cd $httpd_repo && wget $mod_fastcgi_uri && tar -xzvf $mod_fastcgi_tar_gz

# Instrument mod_fastcgi
export PATH=$PATH:${httpd_prefix}/bin
apt install -y libpam0g-dev
cd ${mod_fastcgi_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus make && make install
# This symlink is to properly reference absolute path of pam_unix.so found in /etc/pam.d/httpd
ln -s /lib/x86_64-linux-gnu/security /lib/security

# Overwrite Default httpd.conf w/ One that Support Basic AuthN
mod_fastcgi_httpd_conf="${docker_repo_root}/mod_fastcgi/mod_fastcgi_httpd.conf"
wget $mod_fastcgi_httpd_conf_uri
cp $httpd_prefix/conf/httpd.conf $httpd_prefix/conf/httpd.conf.ORIG
cp $mod_fastcgi_httpd_conf $httpd_prefix/conf/httpd.conf
