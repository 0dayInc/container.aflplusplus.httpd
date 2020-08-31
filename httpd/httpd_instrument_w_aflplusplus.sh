#!/bin/bash --login
# TODO: Get lto working
#preferred_afl='afl-clang-lto'
#preferred_aflplusplus='afl-clang-lto++'
preferred_afl='afl-clang-fast'
preferred_aflplusplus='afl-clang-fast++'

# HYPER INSTRUMENT:
export AFL_LLVM_INSTRUMENT=CFG,NGRAM-16
export AFL_LLVM_INSTRIM_LOOPHEAD=1
export AFL_KEEP_ASSEMBLY=1 &&
export AFL_HARDEN=1 &&
#  export AFL_USE_ASAN=1 &&
#  export AFL_USE_UBSAN=1 &&
#  export AFL_USE_CFISAN=1 &&
#export AFL_AS='/usr/bin/afl-as'
#export AFL_USE_ASAN=1

docker_repo_root='/opt/container.aflplusplus.httpd'

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"

if [[ -d $httpd_repo ]]; then
  rm -rf $httpd_repo
fi

# Initialize Docker Container w Tooling ----------------------------------#
apt update
apt full-upgrade -y
apt install -y subversion libssl-dev pkg-config strace netstat-nat net-tools apt-file tcpdump lsof psmisc logrotate curl openssh-server git

# Install Radamsa to Support -R flag in afl-fuzz
# (i.e. Include Radamsa for test case mutation)
radamsa_root="${fuzz_session_root}/radamsa"
cd $fuzz_session_root
git clone https://gitlab.com/akihe/radamsa.git
cd $radamsa_root
make
make install
rm -rf $radamsa_root

# Configure logrotate to rotate logs every hour
logrotate_script='/usr/local/sbin/logrotate.sh'
mkdir /etc/logrotate.minute.d
echo 'include /etc/logrotate.minute.d' > /etc/logrotate.minute.conf
chmod 644 /etc/logrotate.minute.conf

cat << EOF | tee $logrotate_script
#!/bin/bash --login
/usr/sbin/logrotate /etc/logrotate.minute.conf
rm ${httpd_prefix}/logs/*_log.1
EOF
chmod 775 $logrotate_script

cat << EOF | tee /etc/logrotate.minute.d/httpd
${httpd_prefix}/logs/access_log {
  size 128M
  rotate 0
  copytruncate
  missingok
  notifempty
  nocreate
  nomail
}

${httpd_prefix}/logs/error_log {
  size 128M
  rotate 0
  copytruncate
  missingok
  notifempty
  nocreate
  nomail
}
EOF
(crontab -l 2>/dev/null; echo "* * * * * ${logrotate_script}") | crontab -
sleep 3
/etc/init.d/cron start
# EOI --------------------------------------------------------------------#

# Okay, now let's instrument httpd...
httpd_repo_root=`dirname ${httpd_repo}`
httpd_repo_name=`basename ${httpd_repo}`

cd $httpd_repo_root && svn checkout http://svn.apache.org/repos/asf/httpd/httpd/trunk $httpd_repo_name
cd $httpd_repo && svn checkout http://svn.apache.org/repos/asf/apr/apr/trunk srclib/apr

fuzz_httpd_w_aflplusplus_patch="${docker_repo_root}/httpd/patch_httpd_w_AFL_persistent_support.diff"

# Patch Apache to Support Preferred AFL CC & CXX
cd $httpd_repo && patch -p0 -i $fuzz_httpd_w_aflplusplus_patch  
if [[ $? != 0 ]]; then
  echo "INSTRUMENTATION PATCHING ERROR: ${fuzz_httpd_w_aflplusplus_patch}"
  echo "Please look above in STDOUT for errors related to patch command."
  exit 1
fi

# Instrument apache
cd $httpd_repo && CC=$preferred_afl CXX=$preferred_aflplusplus ./buildconf
cd ${httpd_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus ./configure --prefix=$httpd_prefix
cd ${httpd_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus make
cd ${httpd_repo} && make install
