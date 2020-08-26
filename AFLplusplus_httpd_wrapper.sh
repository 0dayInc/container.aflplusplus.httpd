#!/bin/bash --login
usage() {
  echo 'USAGE:'
  echo "${0}
    -h                    # Display USAGE

    -m <master || slave>  # REQUIRED
                          # afl++ Mode 

    -a <mod_auth_pam,...> # OPTIONAL / master MODE ONLY
                          # Comma-delimited httpd Modules to Instrument

    -f                    # OPTIONAL / master MODE ONLY
                          # Enable custom httpd.conf file
                          # for more advanced httpd mockups
                          # Resides in /fuzz_session/httpd.conf
                          # which is tmpfs and LOST AFTER REBOOT

    -d                    # OPTIONAL / master MODE ONLY
                          # Enable Custom Apache Document Root
                          # Resides in /fuzz_session/htdocs
                          # which is tmpfs and LOST AFTER REBOOT

    -n                    # OPTIONAL
                          # Nuke contents of multi-sync (New afl++ Session)

    -L                    # OPTIONAL
                          # List supported httpd modules to instrument
  "
  exit 1
}

list_supported_httpd_modules_to_instrument() {
  echo "List of Supported httpd Modules to Instrument:
    mod_auth_pam,
    mod_fastcgi,
    mod_ssl
  "
  exit 0
}

no_args='true'
custom_httpd_conf='false'
custom_docroot='false'
afl_mode=''
httpd_modules_for_instrumentation=''
nuke_multi_sync='false'

while getopts "hm:a:fdnL" flag; do
  case $flag in
    'h') usage;;
    'm') afl_mode="${OPTARG}";;
    'a') httpd_modules_for_instrumentation="${OPTARG}";;
    'n') nuke_multi_sync='true';;
    'f') custom_httpd_conf='true';;
    'd') custom_docroot='true';;
    'L') list_supported_httpd_modules_to_instrument;;
    *) usage;;
  esac
  no_args='false'
done

# If no args are passed, then return usage
if [[ $no_args == 'true' ]]; then
  usage
fi

if [[ $afl_mode != 'master' ]]; then
  if [[ $httpd_modules_for_instrumentation != '' || $custom_httpd_conf != 'false' || $custom_docroot != 'false' ]]; then
    echo "ERROR: -a || -f || -d Flags Can Only be Used with -m master"
    usage
  fi
fi

repo_root=$(pwd)
repo_name=`basename ${repo_root}`
docker_repo_root="/opt/${repo_name}"

fuzz_session_root='/fuzz_session'
httpd_test_cases="${repo_root}/httpd/test_cases"

afl_session_root="${fuzz_session_root}/AFLplusplus"
afl_input="${afl_session_root}/input"
afl_output="${afl_session_root}/multi_sync"

httpd_repo="${fuzz_session_root}/httpd"

# Ensure folder conventions are intact
if [[ ! -d $afl_session_root ]]; then
  mkdir $afl_session_root
  sudo chmod 777 $afl_session_root
  sudo mount -t tmpfs -o exec,nosuid,nodev,noatime,mode=1777,size=2G tmpfs $afl_session_root
fi

if [[ ! -d $fuzz_session_root/htdocs ]]; then
  mkdir $fuzz_session_root/htdocs
fi

if [[ ! -f $fuzz_session_root/httpd.conf ]]; then
  touch $fuzz_session_root/httpd.conf
fi

if [[ ! -d $afl_input ]]; then
  mkdir $afl_input
  sudo chmod 777 $afl_input
fi

if [[ $custom_httpd_conf == 'false' ]]; then
  target_binary="${httpd_repo}/BINROOT/bin/httpd -X"
else
  target_binary="${httpd_repo}/BINROOT/bin/httpd -X -f ${fuzz_session_root}/httpd.conf"
fi

# Copy httpd Test Cases to $afl_input Folder
cp $httpd_test_cases/* $afl_input

# Set ADL Mode
if [[ $afl_mode == 'master' ]]; then
  afl_mode_selection='-M httpd1'
else
  #next_slave_int=$(expr 1 + `ls $afl_output | grep httpd | tail -n 1 | sed 's/httpd//g'`)
  #afl_mode_selection="-S httpd${next_slave_int}"
  afl_mode_selection="-S httpd${RANDOM}"
fi

# Initialize Fuzz Session
fuzz_session_init="
  echo core > /proc/sys/kernel/core_pattern &&
  export AFL_AUTORESUME=1 &&
  afl-fuzz ${afl_mode_selection} -i ${afl_session_root}/input -o ${afl_session_root}/multi_sync -m 2048 -t 6000+ -- ${target_binary}
"

case $afl_mode in
  'master')
    # Build out afl_instrument_and_fuzz_session_init 
    # by parsing httpd_modules_for_instrumentation
    echo 'Building latest trunk of httpd...'
    afl_instrument_httpd="${docker_repo_root}/httpd/httpd_instrument_w_aflplusplus.sh"
    afl_instrument_and_fuzz_session_init="${afl_instrument_httpd} &&"

    delimit=',' read -r -a httpd_mod_arr <<< "$httpd_modules_for_instrumentation"
    for httpd_module in "${httpd_mod_arr[@]}"; do
      case $httpd_module in 
        'mod_auth_pam')
          echo "Instrumenting ${httpd_module}!"
          mod_auth_pam_test_cases="${repo_root}/mod_auth_pam/test_cases"
          cp $mod_auth_pam_test_cases/* $afl_input
          afl_instrument_mod_auth_pam="${docker_repo_root}/mod_auth_pam/mod_auth_pam_instrument_w_aflplusplus.sh"
          afl_instrument_and_fuzz_session_init="${afl_instrument_and_fuzz_session_init} ${afl_instrument_mod_auth_pam} &&"
          ;;
        'mod_fastcgi') 
          echo "Instrumenting ${httpd_module}!"
          mod_fastcgi_test_cases="${repo_root}/mod_fastcgi/test_cases"
          cp $mod_fastcgi_test_cases/* $afl_input
          afl_instrument_mod_fastcgi="${docker_repo_root}/mod_fastcgi/mod_fastcgi_instrument_w_aflplusplus.sh"
          afl_instrument_and_fuzz_session_init="${afl_instrument_and_fuzz_session_init} ${afl_instrument_mod_fastcgi} &&"
          ;;
        'mod_ssl')
          echo "Instrumenting ${httpd_module}!"
          mod_ssl_test_cases="${repo_root}/mod_ssl/test_cases"
          cp $mod_ssl_test_cases/* $afl_input
          afl_instrument_mod_ssl="${docker_repo_root}/mod_ssl/mod_ssl_instrument_w_aflplusplus.sh"
          afl_instrument_and_fuzz_session_init="${afl_instrument_and_fuzz_session_init} ${afl_instrument_mod_ssl} &&"
          ;;
        *) echo "Invalid httpd_module ${httpd_module}"
           echo 'Use -L to list modules supported.'
           usage;; 
      esac
    done

    # Nuke contents of multi-sync (New afl++ Session)
    # if -n was passed as arg
    if [[ -d $afl_output && $nuke_multi_sync == 'true' ]]; then
      sudo rm -rf $afl_output
    fi

    afl_instrument_and_fuzz_session_init="${afl_instrument_and_fuzz_session_init} ${fuzz_session_init}"

    echo $afl_instrument_httpd_and_fuzz_session_init
    
    # Instrument & Run Master
    sudo sysctl -w kernel.unprivileged_userns_clone=1
    if [[ $custom_docroot == 'false' ]]; then
      docker run \
        --privileged \
        --rm \
        --name aflplusplus.httpd.$RANDOM \
        --mount type=bind,source=`dirname ${repo_root}`,target=/opt \
        --mount type=bind,source=$fuzz_session_root,target=$fuzz_session_root \
        --interactive \
        --tty aflplusplus/aflplusplus \
        /bin/bash --login \
        -c "${afl_instrument_and_fuzz_session_init}"
    else
      docker run \
        --privileged \
        --rm \
        --name aflplusplus.httpd.$RANDOM \
        --mount type=bind,source=`dirname ${repo_root}`,target=/opt \
        --mount type=bind,source=$fuzz_session_root,target=$fuzz_session_root \
        --mount type=bind,source=$fuzz_session_root/htdocs,target=$httpd_repo/BINROOT/htdocs \
        --interactive \
        --tty aflplusplus/aflplusplus \
        /bin/bash --login \
        -c "${afl_instrument_and_fuzz_session_init}"
    fi
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
