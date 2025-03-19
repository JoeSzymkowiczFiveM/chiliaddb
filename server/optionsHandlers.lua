local optionsHandlers = {}
local utils = require 'server.utils'

function optionsHandlers.find(responseData, options, keys)
    if options.excludeIndexes then
        responseData = utils.excludeIndexes(responseData, keys)
    end
    if options.limit then
        responseData = utils.limitResults(responseData, options.limit, keys)
    end
    if options.excludeFields and not options.includeFields then
        responseData = utils.excludeFields(responseData, options.excludeFields, false)
    elseif options.includeFields and not options.excludeFields then
        responseData = utils.includeFields(responseData, options.includeFields, false)
    end
    return responseData
end

function optionsHandlers.insert(id, documentData, options)
    if options.selfInsertId then
        documentData = utils.selfInsertId(id, documentData, options.selfInsertId)
    end
    return documentData
end

function optionsHandlers.findOne(responseData, options)
    if options.excludeFields and not options.includeFields then
        responseData = utils.excludeFields(responseData, options.excludeFields, true)
    elseif options.includeFields and not options.excludeFields then
        responseData = utils.includeFields(responseData, options.includeFields, true)
    end
    return responseData
end

return optionsHandlers