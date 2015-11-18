require "config"
local json = require "cjson"

local iplist = ngx.shared.access_iplist
local total = ngx.shared.access_total
local ip = ngx.var.remote_addr
local optionIsOn = function (options) return options == "on" and true or false end
IpRateLimit = optionIsOn(IpRateLimit)

local RateLimit = "RateLimit"
local TotalRateLimit = "TotalRateLimit"

function is_blocked()
    local total_times = total:incr('total', 1)
    if total_times == nil then
        total_times = 1
        total:set('total', 1, 1)
    end

    if total_times > total_rps then
        return {
            ['msg'] = 'request too frequently, please wait for a moment',
            ['result'] = TotalRateLimit,
        }
    end

    local ip_times = iplist:incr(ip, 1)
    if ip_times == nil then
        ip_times = 1
        iplist:set(ip, 1, 1)
    end

    -- 超单ip访问次数，超一次重新封多一秒
    if ip_times > ip_rps then
        local sec = (ip_times - ip_rps)
        iplist:set(ip, ip_times, sec)
        return {
            ['msg'] = ip..' is blocked for '..sec..' seconds',
            ['result'] = RateLimit, 
        }
    end
end

function main()
    if IpRateLimit then
        local res = is_blocked()
        if res then
            ngx.req.set_header("Content-Type", "text/plain")
            -- ngx.say(res['msg'])
            ngx.say(json.encode(res))
            ngx.status = ngx.HTTP_FORBIDDEN
            return
        end
    end
end

main()
