```
$ git clone https://github.com/0dayInc/container.aflplusplus.httpd
$ cd container.aflplusplus.httpd
$ ./AFLplusplus_httpd_wrapper.sh -h
```

Example Usage:
```
$ ./AFLplusplus_httpd_wrapper.sh -m master -d -f
```

In a new terminal window (following execution of the command above):
```
$ echo "IM UNIQUE" > /fuzz_session/htdocs/index.html
```

To add another CPU core into the fuzzing mix, open a new terminal window:
```
$ ./AFLplusplus_httpd_wrapper.sh -m slave
```

To check out the requests being made by afl++:
```
$ docker exec -it $(docker ps -a | grep aflplusplus.httpd | awk '{ print $NF}') tail -f /fuzz_session/httpd/BINROOT/logs/access_log
```

Apache log files (access_log and error_log) are rotated every minute (fills up fast w/ multiple cores fuzzing ~ 1000 - 3000 HTTP reuqest mutations / second / core.


If you want a custom httpd.conf file, use -f flag to enable reading /fuzz_session/httpd.conf

If you want a custom DOCROOT, use -d flag to enable /fuzz_session/htdocs for your custom application
