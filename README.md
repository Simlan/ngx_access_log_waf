ngx_access_log_waf
==================

通过实时分析nginx 的access log 进行 WAF 防预


需求:
-----

- 通过分析 旧的access-log 中URL的调用频率，对请求URL设定合理调用频率范围，
- 以星期为波动周期，每分钟为采样单位，倒是调用范围自动更新，以适应用户增长。


基于以上需求，网上类似的WAF，如[ngx_lua_waf](https://github.com/loveshell/ngx_lua_waf) 并不合适。
