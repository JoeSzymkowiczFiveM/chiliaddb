local queryHandlers = {}
local utils = require 'server.utils'

function queryHandlers.findQuery(collection, query)
    local responseData = {}
    for k, v in pairs(collection) do
        local match = true
        for k2, v2 in pairs(query) do
            if type(v2) == 'table' then
                for k3, v3 in pairs(v2) do
                    if not utils.advancedSearchLogic(v, k2, k3, v3) then
                        match = false
                        break
                    end
                end
            else
                if v[k2] ~= v2 then
                    match = false
                    break
                end
            end
        end
        if match then
            responseData[k] = v
        end
    end
    return utils.getSortedData(responseData)
end

function queryHandlers.delete(collection, query)
    local responseData = {}
        for k, v in pairs(collection) do
            local match = true
            for k2, v2 in pairs(query) do
                if type(v2) == 'table' then
                    for k3, v3 in pairs(v2) do
                        if not utils.advancedSearchLogic(v, k2, k3, v3) then
                            match = false
                            break
                        end
                    end
                else
                    if v[k2] ~= v2 then
                        match = false
                        break
                    end
                end
            end
            if match then
                responseData[#responseData + 1] = k
            end
        end
    return responseData
end

return queryHandlers