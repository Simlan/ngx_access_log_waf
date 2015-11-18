简单ip rate limit
==================

简单的ip访问限频功能和黑白名单

##### ip限频:
限制单个ip每秒访问次数，限制每秒ip的访问总次数，配置项在lua/config.lua 。
- IpRateLimit,限频开关 on/off。
- ip_rps,单个ip每秒访问次数。
- total_rps,单每秒ip的访问总次数。

##### ip黑白名单:
nginx的deny和allow功能,配置项在conf/iplimite.conf。

##### reload配置：
以上配置修改候需要对nginx进行reload,方可生效。
```
$ kill -HUP `cat /the/path/nginx.pid`
```
