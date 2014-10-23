
local configig = require "config"
local json = require "cjson"

function read_map_file()
    local fp = io.open(config.map_file)
    if fp == nil then
        ngx.log(ngx.ERR, 'map file not found ->[', config.map_file, ']')
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

config.map = read_map_file()

for k, v in pairs(config.map) do
    ngx.log(ngx.ERR, k, ' type(v)=', type(config.map['/index']))
end
