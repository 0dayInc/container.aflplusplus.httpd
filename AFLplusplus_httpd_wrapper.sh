#!/bin/bash --login
usage() {
  echo 'USAGE:'
  echo "${0}
    -m <master || slave>  # afl++ Mode
    -a <mod_auth_pam,...> # Comma-delimited httpd Modules to Instrument
    -n                    # Nuke contents of multi-sync (New afl++ Session)
  "
  exit 1
}

httpd_modules_for_instrumentation=''
nuke_multi_sync='false'

while getopts 'a:m:' flag; do
  case "${flag}" in
    m) afl_mode="${OPTARG}" ;;
    a) httpd_modules_for_instrumentation="${OPTARG}" ;;
    n) nuke_multi_sync='true' ;;
    *) usage;;
  esac
done

repo_root=$(pwd)
repo_name=`basename ${repo_root}`
docker_repo_root="/opt/${repo_name}"

fuzz_session_root='/fuzz_session'
test_case_root="${docker_repo_root}/test_cases"
httpd_test_cases="${test_case_root}/httpd"

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

httpd_repo="${fuzz_session_root}/httpd"
target_binary="${httpd_repo}/BINROOT/bin/httpd -X"

if [[ ! -d $afl_session_root ]]; then
  mkdir $afl_session_root
  sudo chmod 777 $afl_session_root
  sudo mount -t tmpfs -o exec,nosuid,nodev,noatime,mode=1777,size=2G tmpfs $afl_session_root
fi

if [[ ! -d $afl_input ]]; then
  mkdir $afl_input
  sudo chmod 777 $afl_input
fi

# Update $afl_input w/ httpd Test Cases
cp $httpd_test_cases/* $afl_input

# Nuke contents of multi-sync (New afl++ Session) if -n was passed as arg
if [[ -d $afl_output && $nuke_multi_sync == 'true' ]]; then
  rm -rf $afl_output
fi

if [[ $afl_mode == 'master' ]]; then
  afl_mode_selection='-M httpd1'
else
  next_slave_int=$(expr 1 + `ls $afl_output | grep httpd | tail -n 1 | sed 's/httpd//g'`)
  afl_mode_selection="-S httpd${next_slave_int}"
  #afl_mode_selection="-S httpd${RANDOM}"
fi

fuzz_session_init="
  echo core > /proc/sys/kernel/core_pattern &&
  export AFL_AUTORESUME=1 &&
  afl-fuzz ${afl_mode_selection} -i ${afl_session_root}/input -o ${afl_session_root}/multi_sync -m 2048 -t 6000+ -- ${target_binary}
"

case $afl_mode in
  'master')
    echo 'Building latest trunk of httpd...'
    afl_instrument_httpd="${docker_repo_root}/httpd_instrument_w_aflplusplus.sh"

    # TODO: Choose if we want to incorporate additional 
    # Apache modules into fuzzing session
    afl_instrument_mod_auth_pam="${docker_repo_root}/mod_auth_pam/mod_auth_pam_instrument_w_aflplusplus.sh"

    #afl_instrument_httpd_and_fuzz_session_init="
    #  ${afl_instrument_httpd} && 
    #  ${afl_instrument_mod_auth_pam} && 
    #  ${fuzz_session_init}
    #"
    
    afl_instrument_httpd_and_fuzz_session_init="
      ${afl_instrument_httpd} && 
      ${fuzz_session_init}
    "
    
    # Instrument & Run Master
    sudo sysctl -w kernel.unprivileged_userns_clone=1
    docker run \
      --privileged \
      --rm \
      --name aflplusplus.httpd.$RANDOM \
      --mount type=bind,source=$repo_root,target=/opt \
      --mount type=bind,source=$fuzz_session_root,target=$fuzz_session_root \
      --interactive \
      --tty aflplusplus/aflplusplus \
      /bin/bash --login \
      -c "${afl_instrument_httpd_and_fuzz_session_init}"
    sudo sysctl -w kernel.unprivileged_userns_clone=0
    ;;

  'slave')
    # Run Slave
    afl_master_name=`docker ps -a | grep aflplusplus.httpd | awk '{print $NF}'`
    docker exec \
      --interactive \
      --tty $afl_master_name \
      /bin/bash --login \
      -c "${fuzz_session_init}"
      ;;

  *) usage;;
esac
