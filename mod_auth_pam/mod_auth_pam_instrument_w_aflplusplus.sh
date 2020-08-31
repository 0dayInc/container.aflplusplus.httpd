#!/bin/bash --login
docker_repo_root='/opt/container.aflplusplus.httpd'

# Define Target Instrumentation via instrumentation_globals.sh
source $docker_repo_root/instrumentation_globals.sh

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

mod_auth_pam_tar_gz='mod_auth_pam-2.0-1.1.1.tar.gz'
mod_auth_pam_uri="http://pam.sourceforge.net/mod_auth_pam/dist/${mod_auth_pam_tar_gz}"
httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"
mod_auth_pam_repo="${httpd_repo}/modules/mod_auth_pam"
repo_name=`basename ${mod_auth_pam_repo}`

cd `dirname ${mod_auth_pam_repo}`
wget $mod_auth_pam_uri
tar -xzvf $mod_auth_pam_tar_gz
mv $mod_auth_pam_tar_gz ${mod_auth_pam_repo}

# Instrument mod_auth_pam
apt install -y libpam0g-dev
export PATH=$PATH:${httpd_prefix}/bin
cd ${mod_auth_pam_repo}
CC=$preferred_afl CXX=$preferred_aflplusplus RANLIB=$preferred_afl_ranlib AR=$preferred_afl_ar NM=$preferred_afl_nm make
make install
# This symlink is to properly reference absolute path of pam_unix.so found in /etc/pam.d/httpd
ln -s /lib/x86_64-linux-gnu/security /lib/security
