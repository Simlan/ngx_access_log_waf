module(..., package.seeall)

map_file='/home/huangchuantong/ngx_access_log_waf/map.json'

interval=60 -- by second
-- if this time-interval is nil, set mix rate 
mix_rate=10

learning=true

drift=20 -- 20%

ip_white_list={"127.0.0.1"}

ip_block_list={}
