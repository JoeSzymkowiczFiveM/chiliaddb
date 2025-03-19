local queryHandlers = {}
local utils = require 'server.utils'

function queryHandlers.find(collection, data, query)
    local responseData, keys = {}, {}
    local ids = collection.ids
    for i=1, #ids do
        local k = ids[i]
        local v = data[k]
        if utils.queryMatch(v, query) then
            responseData[k] = v
            keys[#keys + 1] = k
        end
    end
    return responseData, keys
end

function queryHandlers.findOne(ids, collection, query)
    for i=1, #ids do
        local k = ids[i]
        local v = collection[k]
        if utils.queryMatch(v, query) then
            return k, v
        end
    end
    return nil, nil
end

function queryHandlers.delete(collection, query)
    local responseData = {}
        for k, v in pairs(collection) do
            if utils.queryMatch(v, query) then
                responseData[#responseData + 1] = k
            end
        end
    return responseData
end

function queryHandlers.exists(ids, collection, query)
    for i=1, #ids do
        local k = ids[i]
        local v = collection[k]
        if utils.queryMatch(v, query) then
            return true
        end
    end
    return false
end

return queryHandlers