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

httpd_repo="${fuzz_session_root}/httpd"
httpd_prefix="${httpd_repo}/BINROOT"

if [[ -d $httpd_repo ]]; then
  rm -rf $httpd_repo
fi

apt update
apt full-upgrade -y
apt install -y subversion libssl-dev pkg-config strace netstat-nat net-tools apt-file tcpdump

httpd_repo_root=`dirname ${httpd_repo}`
httpd_repo_name=`basename ${httpd_repo}`

cd $httpd_repo_root && svn checkout http://svn.apache.org/repos/asf/httpd/httpd/trunk $httpd_repo_name
cd $httpd_repo && svn checkout http://svn.apache.org/repos/asf/apr/apr/trunk srclib/apr

fuzz_httpd_w_aflplusplus_patch="${docker_repo_root}/patch_httpd_w_AFL_persistent_support.diff"

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
  
# Disable Logging So We Don't Fill Up tmpfs Partition
sed -e '/Log/ s/^#*/#/' -i ${httpd_repo}/BINROOT/conf/httpd.conf
echo 'ErrorLog /dev/null' >> ${httpd_repo}/BINROOT/conf/httpd.conf
