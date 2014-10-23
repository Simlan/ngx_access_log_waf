local config = require "config"

local Const_Last_Key = 'Last_Key'
local Merge_Worker_PID = 'Worker_Pid'

local function get_client_ip()
    local IP = ngx.req.get_headers()["X-Real-IP"]
    if IP == nil then
        IP = ngx.var.remote_addr 
    end
    if IP == nil then
        IP = "unknown"
    end
    return IP
end

local function white_ip(IP)
    if next(config.ip_white_list) ~= nil then
        for _, ip in pairs(config.ip_white_list) do
            if ip == IP then
                return true
            end
        end
    end
    return false
end

local function block_ip(IP)
    if next(config.ip_block_list) ~= nil then
        for _, ip in pairs(config.ip_block_list) do
            if ip == IP then
                return true
            end
        end
    end
    return false
end

local function get_default_uri_rate(dict, uri, weekday, key_interval, rate_default)
    local uri_info = dict[uri]
    if uri_info == nil then
        local interval_info = {rate=rate_default}
        local weekday_info = {key_interval=interval_info}
        uri_info = {weekday=weekday_info}
        dict[uri] = uri_info
        return rate_default
    end

    local weekday_info = uri_info[weekday]
    if weekday_info == nil then
        local interval_info = {rate=rate_default}
        uri_info[weekday] = {key_interval=interval_info}
        return rate_default
    end

    local interval_info = weekday_info[key_interval]
    if interval_info == nil then
        interval_info = {rate=rate_default}
        weekday_info[key_interval] = interval_info
        return rate_default
    end
    local rate = interval_info['rate']
    return rate and rate or rate_default
end

local function limit(uri, interval, rate_limit, period)
    -- interval: format like '20:59:00' => 60 second-interval.
    -- period: by second
    -- rate_limit: count of period limit
    local key = uri .. interval
    local shared = ngx.shared.waf_shared
    local rate_now, _ = shared:get(key)
    
    if rate_now ~= nil then
        if rate_now > rate_limit then
            return true
        else
            local n = shared:incr(key, 1)
            ngx.log(ngx.INFO, 'shared:incr(', key, ') => ', n)
        end
    else
        shared:set(key, 1, period)
    end
    return false
end

local function get_last_weekday_rate(uri, weekday, interval)
    return get_default_uri_rate(config.map, uri, weekday, interval, config.mix_rate)
end

function str_split(s, d)
   local t = {}
   local i = 0
   local f
   local match = '(.-)' .. d .. '()'
   if string.find(s, d) == nil then
      return {s}
   end
   for sub, j in string.gfind(s, match) do
         i = i + 1
         t[i] = sub
         f = j
   end
   if i~= 0 then
      t[i+1] = strsub(s,f)
   end
   return t
end

local function merge(last_interval, weekday)
    local access_log = ngx.shared.waf_access
    
    local worker_pid, _ = access_log:get(Merge_Worker_PID)
    if worker_pid ~= nil then return end
    access_log:set(Merge_Worker_PID, ngx.worker.pid())

    local keys = access_log:get_keys(0) -- will lock the access_log, other worker can not access.
    local interval, uri
    for _, k in ipairs(keys) do
        repeat -- lua 没有continue语句，只能写个repeat true
            local cnt, _ = access_log:get(k)
            if cnt == nil then break end

            local split = str_split(k)
            if #split ~= 2 then break end
            interval, uri = split[1], split[2]

            if interval ~= last_interval then
                ngx.log(ngx.NOTICE, 'interval not match, last[', last_interval, '] find[', interval, '],uri->', uri)
                if cnt ~= nil then
                    access_log:set(k, cnt, config.interval - 1) -- let it exprie befor next interval.
                end
            else
                local uri_info = config.map[uri]
                if  uri_info then
                    ngx.log(ngx.NOTICE, 'URI[', uri,'] not in map-rule. pass it.')
                    break
                end
                
                local rate = get_last_weekday_rate(uri, weekday, interval)
                config.map[uri][weekday][interval]['rate'] = (rate + cnt) / 2
                access_log:set(k, cnt, 1) -- 1 second after exprie.    
            end
        until true
    end
    access_log:delete(Merge_Worker_PID)
end

-- record the day of interval-time that uri access-log conunt.
local function access_log(uri, interval)
    local access_log = ngx.shared.waf_access
    local key = interval .. ' ' .. uri
    local cnt, _ = access_log:get(key)

    if cnt == nil then
        return acess_log:incr(key, 1)
    else
        return access_log:set(key, 1)
    end
end

local function rate_limit()
    local uri = ngx.var.uri
    local now = ngx.now() -- return seconds
    local day_second = os.date('%H', now) * 3600 + os.date('%M', now) * 60 + os.date('%S', now)
    local interval = day_second - (day_second % config.interval) - (8 * 3600) -- local time (+8)
    local now_interval = os.date('%H:%M:%S', interval)
    ngx.log(ngx.INFO,'now=[', os.date('%X', now), '] s =', now) 
    ngx.log(ngx.INFO,'now_interval=[', os.date('%X', interval), '] i=',interval)

    local access_info = ngx.shared.waf_access
    local last_interval, _ = access_info:get(Const_Last_Key)
    if last_interval == nil then
        -- if the system time is change(rollback), it will be unexpected to.
        access_info:set(Const_Last_Key, now_interval)
        last_interval = now_interval
        ngx.log(ngx.INFO, 'Set last_interval=', last_interval, ' now-key=', now_interval)
    else
        ngx.log(ngx.INFO, 'Get last_interval=', last_interval, ' now-key=', now_interval)
    end

    local weekday = os.date('%w', now)        
    local rate = get_last_weekday_rate(uri, weekday, now_interval) 
    local rate_add_drift = rate + rate * (config.drift / 100)
    ngx.log(ngx.INFO, 'URI[',uri, '] Rate[', rate_add_drift,']')

    if limit(uri, now_interval, rate_add_drift, config.interval) then
        return true
    end
    
    if now_interval ~= last_interval then
        access_info:set(Const_Last_Key, now_interval)
        merge(last_interval, weekday) -- merge last interval time data to the [config.map] .
    else
        local now_rate = access_log(uri, now_interval)
        ngx.log(ngx.INFO, 'URI[', uri, '] rate[', now_rate, '/', drift, ']')
    end
end

local function access()
    local ip = get_client_ip()
    if white_ip(ip) then
        -- pass, let it accessed
        return
    elseif block_ip(ip) then
        ngx.log(ngx.INFO, 'block IP[', IP, '] want to access. Was deny.')
        ngx.say("IP Block.")
        ngx.exit(403)
    elseif rate_limit() then
        ngx.log(ngx.ERR,'URI[', uri, '] Was Limit in Rate[', rate, ']')
        ngx.exit(406)
    end
end

access()
