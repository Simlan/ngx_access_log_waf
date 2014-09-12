local conf = require "config"


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
    if next(conf.ip_white_list) ~= nil then
        for _, ip in pairs(conf.ip_white_list) do
            if ip == IP then
                return true
            end
        end
    end
    return false
end

local function block_ip(IP)
    if next(conf.ip_block_list) ~= nil then
        for _, ip in pairs(conf.ip_block_list) do
            if ip == IP then
                return true
            end
        end
    end
    return false
end

local function limit(key, rate, period)
    -- period: by second
    -- rate: count of period limit.
    local shared = ngx.shared.waf_shared
    local req_count,_ = shared:get(key)
    
    if req_count then
        if req_count > rate then
            return true
        else
            shared:incr(key, 1)
        end
    else
        shared:set(key, 1, period)
    end
    return false
end

local function _get_last_weekday_rate(uri, weekday, key_interval)
    local uri_info = config.map[uri]
    if uri_info == nil then
        local interval_info = {rate=config.mix_rate}
        local weekday_info = {key_interval=interval_info}
        uri_info = {weekday=weekday_info}
        config.map[uri] = uri_info
        return config.mix_rate
    end

    local weekday_info = uri_info[weekday]
    if weekday_info == nil then
        local interval_info = {rate=config.mix_rate}
        uri_info[weekday] = {key_interval = interval_info}
        return config.mix_rate
    end

    local interval_info = weekday_info[key_interval]
    if interval_info == nil then
        interval_info = {rate=config.mix_rate}
        weekday_info[key_interval] = interval_info
        return config.mix_rate
    end
    rate = interval_info['rate']
    return rate and rate or config.mix_rate
end

local function access()
    local ip = get_client_ip()
    if white_ip(ip) then
        -- pass, let it accessed
        return
    elseif block_ip(ip) then
        ngx.log(ngx.WARN, 'block IP[', IP, '] want to access. Was deny.')
        ngx.say("IP Block.")
        ngx.exit(403)
        return
    else
        local uri = ngx.var.uri
        local now = ngx.now() -- seconds
        local day_second = os.date('%H', now) * 3600 + os.date('%M', now) * 60 + os.date('%S', now)
        local interval = day_second - (day_second % config.interval)
        local key = os.date('%H:%M:%S', interval)
        local weekday = os.date('%W', now)        
        local rate = _get_last_weekday_rate(uri, weekday, key) 
        rate = rate + rate * (config.drift / 100)
        ngx.log(ngx.WARN, 'URI[',uri, '] Rate[', rate,']')

        if limit(uri .. key, rate, config.interval) then
            ngx.log(ngx.ERR,'URI[',uri, '] Was Limit in Rate[', rate,']')
            ngx.exit(406)
            return
        end
        ngx.log(ngx.INFO, 'URI[',uri, '] no limit.')
    end
end

access()
