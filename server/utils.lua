local utils = {}

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
        local comparisonOps = {
            ['$gt'] = function(a, b) return type(a) == 'number' and type(b) == 'number' and a > b end,
            ['$gte'] = function(a, b) return type(a) == 'number' and type(b) == 'number' and a >= b end,
            ['$lt'] = function(a, b) return type(a) == 'number' and type(b) == 'number' and a < b end,
            ['$lte'] = function(a, b) return type(a) == 'number' and type(b) == 'number' and a <= b end,
            ['$ne'] = function(a, b) return a ~= b end,
            ['$eq'] = function(a, b) return a == b end,
            ['$exists'] = function(a, b) return (b and a ~= nil) or (not b and a == nil) end,
            ['$in'] = function(a, b) return type(b) == 'table' and lib.table.contains(b, a) end,
            ['$nin'] = function(a, b) return type(b) == 'table' and not lib.table.contains(b, a) end,
            ['$match'] = function(a, b) return string.match(a, b) end,
            ['$contains'] = function(a, b) return type(a) == 'table' and lib.table.contains(a, b) end,
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

function utils.queryMatch(document, query)
    for k2, v2 in pairs(query) do
        if type(v2) == 'table' then
            for k3, v3 in pairs(v2) do
                if not utils.advancedSearchLogic(document, k2, k3, v3) then
                    return false
                end
            end
        else
            if document[k2] ~= v2 then
                return false
            end
        end
    end
    return true
end

function utils.dbAccessCheck(id)
    return IsPlayerAceAllowed(id, 'group.chiliaddb')
end

function utils.filterFields(documentData, fields, findOne, include)
    local function shouldInclude(key)
        return include and fields[key] or not include and not fields[key]
    end

    if findOne then
        local newDocumentData = {}
        for key, value in pairs(documentData) do
            if shouldInclude(key) then
                newDocumentData[key] = value
            end
        end
        return newDocumentData
    else
        local newDocumentData = {}
        for index, document in pairs(documentData) do
            local newDocument = {}
            for key, value in pairs(document) do
                if shouldInclude(key) then
                    newDocument[key] = value
                end
            end
            newDocumentData[index] = newDocument
        end
        return newDocumentData
    end
end

function utils.excludeFields(documentData, fields, findOne)
    return utils.filterFields(documentData, fields, findOne, false)
end

function utils.includeFields(documentData, fields, findOne)
    return utils.filterFields(documentData, fields, findOne, true)
end

function utils.excludeIndexes(responseData, keys)
    local newResponseData = {}
    for i = 1, #keys do
        if responseData[keys[i]] then
            newResponseData[#newResponseData + 1] = responseData[keys[i]]
        end
    end
    return newResponseData
end

function utils.limitResults(responseData, limit, keys)
    local newResponseData = {}
    for i = 1, limit do
        if responseData[keys[i]] then
            newResponseData[keys[i]] = responseData[keys[i]]
        end
    end
    return newResponseData
end

function utils.calculateMillis(retention)
    local timeUnits = {months = 2592000, days = 86400, hours = 3600, minutes = 60, seconds = 1}
    local millis = 0
    for unit, seconds in pairs(timeUnits) do
        millis = millis + (retention[unit] or 0) * seconds
    end
    return millis * 1000
end

function utils.paramChecker(data, resource, export)
    if not data then
        lib.print.error(string.format("Missing data parameter. Called from %s.", resource))
        return false
    end

    local functionParams = {
        find = {'collection'},
        findOne = {'collection'},
        update = {'collection', 'query', 'update'},
        delete = {'collection', 'query'},
        exists = {'collection', 'query'},
        insert = {'collection', 'document'},
        insertMany = {'collection', 'documents'},
        replaceOne = {'collection', 'query', 'document'},
        renameCollection = {'collection', 'newName'},
        dropCollection = {'collection'},
        aggregate = {'collection', 'group'},
    }

    for _, param in ipairs(functionParams[export]) do
        if not data[param] then
            lib.print.error(string.format("%s call missing required parameter '%s'. Called from %s.", export, param, resource))
            return false
        end
    end

    return true
end

function utils.groupHandler(responseData, group, keys)
    if group.fields and group.sum then
        local aggregatedData = {}
        local sumAlias = group.alias or group.sum
        for i = 1, #keys do
            local key = keys[i]
            local document = responseData[key]
            local groupIds = {}
            for i=1, #group.fields do
                local field = group.fields[i]
                groupIds[#groupIds + 1] = document[field]
            end
            local idString = table.concat(groupIds, "_")
            if idString then
                if not aggregatedData[idString] then
                    aggregatedData[idString] = {
                        ids = {},
                        [sumAlias] = 0
                    }
                    for _, field in ipairs(group.fields) do
                        aggregatedData[idString][field] = document[field]
                    end
                end
                aggregatedData[idString][sumAlias] = (aggregatedData[idString][sumAlias] or 0) + (document[group.sum] or 0)
                aggregatedData[idString].ids[#aggregatedData[idString].ids + 1] = key
            end
        end
        responseData = {}
        for _, value in pairs(aggregatedData) do
            responseData[#responseData + 1] = value
        end
    end
    return responseData
end

return utils