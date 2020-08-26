```
$ git clone https://github.com/0dayInc/container.aflplusplus.httpd
$ cd container.aflplusplus.httpd
$ ./AFLplusplus_httpd_wrapper.sh -h
```

If you want a custom httpd.conf file, use -f flag to enable reading /fuzz_session/httpd.conf

If you want a custom DOCROOT, use -d flag to enable /fuzz_session/htdocs for your custom application
