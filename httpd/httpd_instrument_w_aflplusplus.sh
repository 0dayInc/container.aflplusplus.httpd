#!/bin/bash --login
other_repos_root='/opt'
docker_repo_root="${other_repos_root}/container.aflplusplus.httpd"
custom_mutators_root="${other_repos_root}/AFLplusplus/custom_mutators"
radamsa_root="${other_repos_root}/radamsa"

# Define Target Instrumentation via instrumentation_globals.sh
source $docker_repo_root/instrumentation_globals.sh

fuzz_session_root='/fuzz_session'

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

httpd_repo="${fuzz_session_root}/httpd_src"
httpd_prefix="${fuzz_session_root}/httpd"

vanilla_httpd_conf="${docker_repo_root}/httpd/conf/VANILLA.httpd.conf"

if [[ -d $httpd_repo ]]; then
  rm -rf $httpd_repo
fi

# Initialize Docker Container w Tooling ----------------------------------#
apt update
apt full-upgrade -y
apt install -y subversion libssl-dev pkg-config strace netstat-nat net-tools apt-file tcpdump lsof psmisc logrotate curl openssh-server git

# Install Radamsa to Support -R flag in afl-fuzz
# (i.e. Include Radamsa for test case mutation)
cd $other_repos_root
#git clone https://github.com/AFLplusplus/AFLplusplus
#cd $custom_mutators_root/radamsa

git clone https://gitlab.com/akihe/radamsa.git
cd $radamsa_root
make
make install

# TODO: Compile HongFuzz Mutator as well

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

printf 'Starting Cron Daemon...'
cd / && /etc/init.d/cron start
echo 'complete.'
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
cd $httpd_repo && CC=$preferred_afl CXX=$preferred_aflplusplus RANLIB=$preferred_afl_ranlib AR=$preferred_afl_ar NM=$preferred_alf_nm ./buildconf
cd ${httpd_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus RANLIB=$preferred_afl_ranlib AR=$preferred_afl_ar NM=$preferred_afl_nm ./configure --prefix=$httpd_prefix
cd ${httpd_repo} && CC=$preferred_afl CXX=$preferred_aflplusplus RANLIB=$preferred_afl_ranlib AR=$preferred_afl_ar NM=$preferred_afl_nm make
cd ${httpd_repo} && make install
cp $vanilla_httpd_conf $httpd_prefix/conf/httpd.conf
