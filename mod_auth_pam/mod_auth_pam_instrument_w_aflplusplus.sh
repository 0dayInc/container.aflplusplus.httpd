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

mod_auth_pam_tar_gz='mod_auth_pam-2.0-1.1.1.tar.gz'
mod_auth_pam_uri="http://pam.sourceforge.net/mod_auth_pam/dist/${mod_auth_pam_tar_gz}"
httpd_repo="${fuzz_session_root}/httpd"
httpd_prefix="${httpd_repo}/BINROOT"
mod_auth_pam_repo="${httpd_repo}/mod_auth_pam"
repo_name=`basename ${mod_auth_pam_repo}`

cd $httpd_repo && wget $mod_auth_pam_uri && tar -xzvf $mod_auth_pam_tar_gz

# Instrument mod_auth_pam
export PATH=$PATH:${httpd_prefix}/bin
apt install -y libpam0g-dev
cd ${mod_auth_pam_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus make && make install
# This symlink is to properly reference absolute path of pam_unix.so found in /etc/pam.d/httpd
ln -s /lib/x86_64-linux-gnu/security /lib/security

# Overwrite Default httpd.conf w/ One that Support Basic AuthN
mod_auth_pam_httpd_conf="${docker_repo_root}/mod_auth_pam/mod_auth_pam_httpd.conf"
cp $httpd_prefix/conf/httpd.conf $httpd_prefix/conf/httpd.conf.ORIG
cp $mod_auth_pam_httpd_conf $httpd_prefix/conf/httpd.conf
