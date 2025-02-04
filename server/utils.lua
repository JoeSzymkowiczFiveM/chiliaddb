local utils = {}

function utils.getSortedData(data)
    local keys = {}
    for key in pairs(data) do
        -- table.insert(keys, key)
        keys[#keys + 1] = key
    end
    table.sort(keys)
    
    local sortedData = {}
    for _, key in ipairs(keys) do
        sortedData[key] = data[key]
    end
    
    return sortedData, keys
end

function utils.advancedSearchLogic(v, k2, k3, v3)
    if k3 == '$or' or k3 == '$and' then
        local match = (k3 == '$or') and false or true
        for _, v4 in pairs(v3) do
            if (k3 == '$or' and v[k2] == v4) or (k3 == '$and' and v[k2] ~= v4) then
                match = (k3 == '$or')
                break
            end
        end
        return match
    else
        if type(v[k2]) ~= type(v3) then return false end
        local comparisonOps = {
            ['$gt'] = function(a, b) return a > b end,
            ['$gte'] = function(a, b) return a >= b end,
            ['$lt'] = function(a, b) return a < b end,
            ['$lte'] = function(a, b) return a <= b end,
            ['$ne'] = function(a, b) return a ~= b end,
            ['$eq'] = function(a, b) return a == b end
        }
        return comparisonOps[k3] and comparisonOps[k3](v[k2], v3) or false
    end
end

function utils.selfInsertId(id, documentData, fields)
    if type(fields) == 'string' then
        if not documentData[fields] then
            documentData[fields] = id
        end
    elseif type(fields) == 'table' then
        for i = 1, #fields do
            if not documentData[fields[i]] then
                documentData[fields[i]] = id
            end
        end
    end
    return documentData
end

function utils.dbAccessCheck(id)
    return IsPlayerAceAllowed(id, 'group.chiliaddb')
end

return utils