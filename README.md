ngx_access_log_waf
==================

通过实时分析nginx 的access log 进行 WAF 防预


需求:
-----

- 通过分析 旧的access-log 中URL的调用频率，对请求URL设定合理调用频率范围，
- 以星期为波动周期，每分钟为采样单位，使调用范围自动更新，以适应用户增长。


基于以上需求，网上类似的WAF，如[ngx_lua_waf](https://github.com/loveshell/ngx_lua_waf) 并不合适。


例子
----
  URL: /restful/login
  在周一9:30的调用频率是最高的，假定为以下数值：
    - HTTP_status_code_200:100/s, 
    - HTTP_status_code_403:100/s，
  那么在下周一的同一时刻，其调用次数也应该在此范围正负 *10%* 侧认为正常。
