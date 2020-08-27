```
$ git clone https://github.com/0dayInc/container.aflplusplus.httpd
$ cd container.aflplusplus.httpd
$ ./AFLplusplus_httpd_wrapper.sh -h
```

Example Usage:
```
$ ./AFLplusplus_httpd_wrapper.sh -m master
```

To add another CPU core into the fuzzing mix, open a new terminal window:
```
$ ./AFLplusplus_httpd_wrapper.sh -m slave
```

To check out the requests being made by afl++ within the master Container:
```
$ docker exec -it $(docker ps -a | grep aflplusplus.httpd | awk '{ print $NF}') tail -f /fuzz_session/httpd/logs/access_log
```

or from your host os simply execute:
```
$ tail -f /fuzz_session/httpd/logs/access_log
```

Apache log files (access_log and error_log) are rotated every minute (fills up logs fast when fuzzing w/ multiple cores ~ 1000-3000 HTTP mutated requests / second / core.


/fuzz_session/httpd/conf/httpd.conf can be configured and will persist between fuzz sessions, however, it is in /fuzz_session (i.e. tmpfs) and WILL BE LOST WHEN THE HOST OS IS REBOOTED...therefore backup your custom httpd.conf prior to rebooting your host OS.

If you want to deploy your own custom application, the DOCROOT resides in /fuzz_session/httpd/htdocs.  It is also in /fuzz_session (i.e. tmpfs) and WILL BE LOST WHEN THE HOST OS IS REBOOTED...therefore backup your custom DOCROOT prior to rebooting your host OS.

To add your own test cases, place them in ./userland/test_cases and they'll be copied into /fuzz_session/AFLplusplus/input.

Happy Fuzzing!
