local optionsHandlers = {}
local utils = require 'server.utils'

function optionsHandlers.findOptionsHandler(responseData, options, keys)
    responseData = options.excludeIndexes and utils.excludeIndexes(responseData, keys) or responseData
    responseData = options.limit and utils.limitResults(responseData, options.limit, keys) or responseData
    responseData = options.excludeFields and not options.includeFields and utils.excludeFields(responseData, options.excludeFields, false) or responseData
    responseData = options.includeFields and not options.excludeFields and utils.includeFields(responseData, options.includeFields, false) or responseData
    responseData, _ = utils.getSortedData(responseData)
    return responseData
end

function optionsHandlers.insertOptionsHandler(id, documentData, options)
    documentData = options.selfInsertId and utils.selfInsertId(id, documentData, options.selfInsertId) or documentData
    return documentData
end

function optionsHandlers.findOneOptionsHandler(responseData, options)
    responseData = options.excludeFields and not options.includeFields and utils.excludeFields(responseData, options.excludeFields, true) or responseData
    responseData = options.includeFields and not options.excludeFields and utils.includeFields(responseData, options.includeFields, true) or responseData
    return responseData
end

return optionsHandlers