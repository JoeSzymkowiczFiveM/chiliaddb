local optionsHandlers = {}
local utils = require 'server.utils'

local function filterFields(documentData, fields, findOne, include)
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

local function excludeFields(documentData, fields, findOne)
    return filterFields(documentData, fields, findOne, false)
end

local function includeFields(documentData, fields, findOne)
    return filterFields(documentData, fields, findOne, true)
end

local function excludeIndexes(responseData, keys)
    local newResponseData = {}
    for i = 1, #keys do
        if responseData[keys[i]] then
            newResponseData[#newResponseData + 1] = responseData[keys[i]]
        end
    end
    return newResponseData
end

local function limitResults(responseData, limit, keys)
    local newResponseData = {}
    for i = 1, limit do
        if responseData[keys[i]] then
            newResponseData[keys[i]] = responseData[keys[i]]
        end
    end
    return newResponseData
end

function optionsHandlers.findOptionsHandler(responseData, options, keys)
    responseData = options.excludeIndexes and excludeIndexes(responseData, keys) or responseData
    responseData = options.limit and limitResults(responseData, options.limit, keys) or responseData
    responseData = options.excludeFields and not options.includeFields and excludeFields(responseData, options.excludeFields, false) or responseData
    responseData = options.includeFields and not options.excludeFields and includeFields(responseData, options.includeFields, false) or responseData
    responseData, _ = utils.getSortedData(responseData)
    return responseData
end

function optionsHandlers.insertOptionsHandler(id, documentData, options)
    documentData = options.selfInsertId and utils.selfInsertId(id, documentData, options.selfInsertId) or documentData
    return documentData
end

function optionsHandlers.findOneOptionsHandler(responseData, options)
    responseData = options.excludeFields and not options.includeFields and excludeFields(responseData, options.excludeFields, true) or responseData
    responseData = options.includeFields and not options.excludeFields and includeFields(responseData, options.includeFields, true) or responseData
    return responseData
end

return optionsHandlers