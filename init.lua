
local conf = require "config"
local json = require "cjson"

function read_map_file()
    local fp = io.open(conf.map_file)
    if fp == nil then
        ngx.log(ngx.ERR, 'map file not found ->[', conf.map_file, ']')
        return nil
    end
    local tb = cjson.decode(fp:read('*all'))
--    local ok, tb = pcall(cjson.decode, fp:read('*all'))
    local ok = true
    if not ok then
        ngx.log(ngx.ERR, 'cjson.decode map-file fail.->')
        return nil
    end
    if tb == nil then
        ngx.log(ngx.ERR, 'cjson.decode map-file fail.->[' , ok, ']')
    end
    fp:close()
    return tb
end

conf.map = read_map_file()

for k, v in pairs(conf.map) do
    ngx.log(ngx.ERR, k)
end
