local queryHandlers = {}
local utils = require 'server.utils'

function queryHandlers.findQuery(collection, query)
    local responseData = {}
    for k, v in pairs(collection) do
        local match = utils.queryMatch(v, query)
        if match then
            responseData[k] = v
        end
    end
    return utils.getSortedData(responseData)
end

function queryHandlers.delete(collection, query)
    local responseData = {}
        for k, v in pairs(collection) do
            local match = utils.queryMatch(v, query)
            if match then
                responseData[#responseData + 1] = k
            end
        end
    return responseData
end

function queryHandlers.exists(collection, query)
    for _, v in pairs(collection) do
        local match = utils.queryMatch(v, query)
        if match then
            return true
        end
    end
    return false
end

return queryHandlers