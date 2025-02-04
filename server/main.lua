-- TODO: Lots of cleanup is needed and apply validations and error handling uniformly across all functions.
-- TODO: think about setting whether tables are loaded at boot or on demand. maybe define in indexes how each collection should be loaded; at start or on demand.
-- TODO: Given that the nosync kvp functions aren't io or system intensive, maybe we just call them directly instead of spooling amendments
-- TODO: For operators that rely on numeric compareison, validate that the passed value is numeric, and remove the passed compison operate if not, ie lt, gt
-- TODO: Maybe implement a locking mechanism on each collection
if not lib.checkDependency('ox_lib', '3.28.1', true) then return end

local optionsHandlers = require 'server.optionsHandlers'
local queryHandlers = require 'server.queryHandlers'
local utils = require 'server.utils'

local collections = {}
local database = {}
local amendments = {}
local dbLoaded = false

local function databaseCollectionCheck(collection, resource)
    if database[collection] then return true end
    lib.print.warn(string.format("Collection %s does not exist. Called from %s", collection, resource))
    return false
end

local function lockCollection(collection)
    collections[collection].locked = true
end

local function unlockCollection(collection)
    collections[collection].locked = false
end

local function getCurrentCollectionIndex(data)
    if not data.collection then return end
    local collection = data.collection
    if not collections[collection] then
        -- lib.print.error(string.format("Collection %s ^1DOES NOT EXIST^7, called from %s", collection, resource))
        return
    end
    return collections[data.collection].currentIndex
end

local function insertUpdateIntoKvp(collection, id)
    local data = database[collection][id]
    if not data then return end
    SetResourceKvpNoSync(string.format("%s:%d", collection, id), json.encode(data))
end

local function deleteFromKvp(collection, id)
    DeleteResourceKvpNoSync(string.format("%s:%d", collection, id))
end

local function syncDataToKvp()
    local start, amendmentsCount = os.nanotime(), #amendments
    SetResourceKvpNoSync("collections", json.encode(collections))
    if amendmentsCount > 0 then
        lib.print.debug("Syncing database to KVP")
        for i = 1, #amendments do
            local amendment = amendments[i]
            if amendment.action == 'insert' or amendment.action == 'update' then
                insertUpdateIntoKvp(amendment.collection, amendment.id)
            elseif amendment.action == 'delete' then
                deleteFromKvp(amendment.collection, amendment.id)
            end
            amendments[i] = nil
        end
        amendments = {}
        lib.print.debug(string.format("Sync to KVP complete. %s amendments made. Elapsed: %.4f ms", amendmentsCount, (os.nanotime() - start) / 1e6))
    end
    FlushResourceKvp()
end

local function propagateDatabaseFromKvp()
    local responseDatabase = {}
    for k, _ in pairs(collections) do
        responseDatabase[k] = {}
        local colonPos = string.len(k) + 2
        local collectionKey = string.format("%s:", k)
        local kvpHandle = StartFindKvp(collectionKey)
        if kvpHandle ~= -1 then
            local key
            repeat
                key = FindKvp(kvpHandle)
                if key then
                    -- local index = tonumber(string.sub(key, colonPos, string.len(key)))
                    local index = tonumber(string.sub(key, colonPos))
                    if index then
                        responseDatabase[k][index] = json.decode(GetResourceKvpString(key))
                    end
                end
            until not key
            EndFindKvp(kvpHandle)
        end
    end
    return responseDatabase
end

local function incrementIndex(collection)
    if not database[collection] then database[collection] = {} end
    if collections[collection] then
        collections[collection].currentIndex = collections[collection].currentIndex + 1
    else
        collections[collection] = { currentIndex = 1 }
    end
    return collections[collection].currentIndex
end

local function addToAmendments(collName, id, action)
    for i = 1, #amendments do
        if action == 'insert' or action == 'update' then
            if amendments[i].collection == collName and amendments[i].id == id then
                -- lib.print.debug(string.format("Amendment already exists: %s %d %s", collName, id, action))
                return
            end
        end
        if action == 'delete' then
            if amendments[i].collection == collName and amendments[i].id == id and amendments[i].action == action then
                return
            end
        end
    end
    -- lib.print.debug(string.format("Adding amendment: %s %d %s", collName, id, action))
    amendments[#amendments + 1] = {collection = collName, id = id, action = action}
end

local function deleteDocument(collection, id)
    database[collection][id] = nil
    addToAmendments(collection, id, 'delete')
end

local function deleteDocuments(collection, ids)
    for i=1, #ids do
        deleteDocument(collection, ids[i])
    end
end

exports('find', function(data, resource)
    if not data or not data.collection then
        lib.print.error(string.format("Find call was improperly formatted, returning empty table. Called from %s. Sent data %s", resource, json.encode(data)))
        return {}
    end
    if not databaseCollectionCheck(data.collection, resource) then return {} end
    local foundCollection = database[data.collection]
    if not foundCollection then return {} end
    local responseData, keys = {}, {}
    if data.query then
        responseData, keys = queryHandlers.findQuery(foundCollection, data.query)
    else
        responseData, keys = utils.getSortedData(foundCollection)
    end
    responseData = data.options and optionsHandlers.findOptionsHandler(responseData, data.options, keys) or responseData
    return responseData
end)

exports('findOne', function(data, resource)
    if not data or not data.collection or not data.query then
        lib.print.error("FindOne call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(data))
        return false
    end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then return false end
    local query = data.query
    if query.id then
        local id = query.id
        if not type(id) == 'number' then
            print(string.format("passed id is not numeric, %s, returning empty collection", id))
            return {}
        end
        return database[collection][id]
    else
        local sortedCollection, _ = utils.getSortedData(database[collection]) --TODO: verify this is querying the collection in the correct order and truly getting first match
        for k, v in pairs(sortedCollection) do
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
                return data.options and optionsHandlers.findOneOptionsHandler(v, data.options) or v
            end
        end
    end
    return {}
end)

local function skipIfExistsHandler(collection, document, options)
    if not database[collection] then return true end
    for _, v in pairs(database[collection]) do
        local match = true
        for k2, _ in pairs(options.skipIfExists) do
            if v[k2] ~= document[k2] then
                match = false
                break
            end
        end
        if match then
            lib.print.debug(string.format("Record already exists in collection %s. Document %s", collection, json.encode(document)))
            return false
        end
    end
    return true
end

local function dropDatabase()
    amendments = {}
    for k, _ in pairs(database) do
        for k2, _ in pairs(database[k]) do
            DeleteResourceKvpNoSync(string.format("%s:%d", k, k2))
        end
    end
    database = {}
    DeleteResourceKvpNoSync("collections")
    collections = {}
    FlushResourceKvp()
    print("Wiped KVP and memory")
end

local function dropCollection(collection)
    if not database[collection] then
        lib.print.error(string.format("dropCollection failed. Collection %s does not exist", collection))
        return
    end
    local newAmendments = {}
    for i = 1, #amendments do
        if amendments[i].collection ~= collection then
            newAmendments[#newAmendments + 1] = amendments[i]
        end
    end
    amendments = newAmendments
    for k, _ in pairs(database[collection]) do
        DeleteResourceKvpNoSync(string.format("%s:%d", collection, k))
    end
    collections[collection] = nil
    database[collection] = nil
    SetResourceKvpNoSync("collections", json.encode(collections))
    FlushResourceKvp()
end

exports('insert', function(data, resource)
    if not data or not data.collection or not data.document then
        lib.print.error("insert call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(data))
        return false
    end
    --skipIfExists only works for non-table values
    if data.options and data.options.skipIfExists and skipIfExistsHandler(data.collection, data.document, data.options) == false then return false end
    local collection, document = tostring(data.collection), data.document
    local insertedId = incrementIndex(collection)
    local foundCollection = database[collection]
    document = data.options and optionsHandlers.insertOptionsHandler(insertedId, document, data.options) or document
    document.lastUpdated = os.time()
    if foundCollection[insertedId] then
        -- lib.print.debug(string.format("Record with id %d already exists in collection %s", insertedId, collection))
        return false
    end
    while collections[collection].locked do
        Wait(0)
    end
    lockCollection(collection)
    foundCollection[insertedId] = document
    addToAmendments(collection, insertedId, 'insert')
    unlockCollection(collection)
    return insertedId
end)

exports('update', function(data, resource)
    if not data or not data.collection or not data.query or not data.update then
        lib.print.error("update call was improperly formatted, returning false. Called from %s", resource, json.encode(data))
        return false
    end
    local collection = tostring(data.collection)
    -- if not databaseCollectionCheck(collection, resource) then return false end
    if data.query.id then
        local id = tonumber(data.query.id)
        if not id or not database[collection][id] then return false end
        while collections[collection].locked do
            Wait(0)
        end
        lockCollection(collection)

        for k, v in pairs(data.update) do
            database[collection][id][k] = v
        end
        database[collection][id].lastUpdated = os.time()
        addToAmendments(collection, id, 'update')
        unlockCollection(collection)
        return {id}
    else
        local responseData = {}
        if database[collection] then 
            for k, v in pairs(database[collection]) do
                local match = true
                for k2, v2 in pairs(data.query) do
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
                    while collections[collection].locked do
                        Wait(0)
                    end
                    lockCollection(collection)
                    for k2, v2 in pairs(data.update) do
                        database[collection][k][k2] = v2
                    end
                    database[collection][k].lastUpdated = os.time()
                    addToAmendments(collection, k, 'update')
                    responseData[#responseData + 1] = k
                    unlockCollection(collection)
                end
            end
        end
        if #responseData == 0 and data.options and data.options.upsert then
            local options = data.options
            local newInsertDocument = {}
            for k, v in pairs(data.query) do
                newInsertDocument[k] = newInsertDocument[k] or v
            end
            for k, v in pairs(data.update) do
                newInsertDocument[k] = newInsertDocument[k] or v
            end
            local insertedId = incrementIndex(collection)
            if options.selfInsertId then
                newInsertDocument = utils.selfInsertId(insertedId, newInsertDocument, options.selfInsertId)
            end
            newInsertDocument.lastUpdated = os.time()
            while collections[collection].locked do
                Wait(0)
            end

            lockCollection(collection)
            database[collection][insertedId] = newInsertDocument
            addToAmendments(collection, insertedId, 'insert')
            unlockCollection(collection)
            return {insertedId}
        end
        return responseData
    end
end)

exports('delete', function(data, resource)
    if not data or not data.collection or not data.query then 
        lib.print.error("delete call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(data))
        return false
    end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(data.collection, resource) then return false end
    local query = data.query
    if query.id then
        local id = tonumber(query.id)
        if not id or not database[collection][id] then return false end

        while collections[collection].locked do
            Wait(0)
        end
        lockCollection(collection)
        deleteDocument(collection, id)
        unlockCollection(collection)
        return {id}
    else
        local response = queryHandlers.delete(database[collection], query)
        while collections[collection].locked do
            Wait(0)
        end
        lockCollection(collection)
        deleteDocuments(collection, response)
        unlockCollection(collection)
        return response
    end
end)

exports('exists', function(data, resource)
    if not data or not data.collection or not data.query then
        lib.print.error("exists call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(data))
        return false
    end
    local collection = tostring(data.collection)
    local foundCollection = database[collection]
    if not foundCollection then return false end
    if data.query.id then
        local id = tonumber(data.query.id)
        if not id or not foundCollection[id] then return false end
        return true
    else
        for _, v in pairs(foundCollection) do
            local match = true
            for k2, v2 in pairs(data.query) do
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
                return true
            end
        end
        return false
    end
end)

exports('getCollectionCurrentIndex', getCurrentCollectionIndex)

exports('getAmendmentsCount', function()
    return #amendments
end)

exports('propagated', function()
    return dbLoaded
end)

exports('synckvp', syncDataToKvp)

exports('dropCollection', dropCollection)

exports('getCollectionDocumentCount', function(data, resource)
    if not data or not data.collection then
        lib.print.error("getCollectionDocumentCount call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(data))
        return false
    end
    local count = 0
    if not databaseCollectionCheck(data.collection, resource) then return 0 end
    for _ in pairs(database[data.collection]) do
        count = count + 1
    end
    return count
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    collections = json.decode(GetResourceKvpString("collections") or "{}")
    database = propagateDatabaseFromKvp()
    dbLoaded = true
end)

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then return end
    syncDataToKvp()
end)

lib.cron.new('*/5 * * * *', function()
    syncDataToKvp()
end)

lib.addCommand('cdb_drop', {
    help = 'Wipe KVP database, collection or index',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to wipe',
            optional = true,
        },
        {
            name = 'index',
            type = 'number',
            help = 'Specify the collection name to wipe',
            optional = true,
        },
    }
}, function(source, args, raw)
    if args.collection then
        if args.collection == 'all' then
            dropDatabase()
        else
            dropCollection(args.collection)
        end
    elseif args.collection and args.index then
        deleteDocument(args.collection, args.index)
    end
end)

lib.addCommand('cdb_sync', {
    help = 'Sync the database to KVP',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to wipe',
            optional = true,
        },
    }
}, function(source, args, raw)
    syncDataToKvp()
end)

lib.addCommand('cdb_show', {
    help = 'Display KVP collection',
    restricted = 'group.chiliaddb',
}, function(source, args, raw)
    local resources = {}
    for k, _ in pairs(collections) do
        local id = #resources + 1
        resources[id] = {id = id, name = k}
    end
    table.sort(resources, function (k1, k2) return k1.name < k2.name end )
    if source == 0 then return end
    TriggerClientEvent('chiliaddb:client:openExplorer', source, resources)
end)

lib.callback.register('chiliaddb:server:getCollectionData', function(source, collection)
    if not utils.dbAccessCheck(source) then return {} end
    return database[collection]
end)

RegisterNetEvent('chiliaddb:server:onChangeData', function(data)
    if not utils.dbAccessCheck(source) then return end
    if data.action == 'remove' then
        deleteDocument(data.collection, data.id)
    elseif data.action == 'replace' then
        database[data.collection][data.id] = data.data
        addToAmendments(data.collection, data.id, 'update')
    end
end)

lib.addCommand('cdb_print', {
    help = 'Wipe KVP database',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to print',
            optional = true,
        },
        {
            name = 'id',
            type = 'number',
            help = 'Specify the collection and id to print',
            optional = true,
        },
    }
}, function(source, args, raw)
    if args.collection and args.id then
        if not database[args.collection] then 
            lib.print.error(string.format("cdb_print command failed. Collection %s does not exist", args.collection))
            return
        end
        if not database[args.collection][args.id] then
            lib.print.error(string.format("cdb_print command failed. Index %d does not exist in collection %s", args.id, args.collection))
            return
        end
        local key = string.format("%s:%d", args.collection, args.id)
        print(key, json.encode(database[args.collection][args.id], {indent = true}))
    elseif args.collection then
        if args.collection == 'all' then
            print(json.encode(database, {indent = true}))
        else
            if not database[args.collection] then 
                lib.print.error(string.format("cdb_print command failed. Collection %s does not exist", args.collection))
                return
            end
            local key = string.format("%s", args.collection)
            print(key, json.encode(database[args.collection], {indent = true}))
        end
    end
end)

lib.addCommand('cdb_export', {
    help = 'Export the database to json file',
    restricted = 'group.chiliaddb',
}, function(source, args, raw)
    SaveResourceFile(GetCurrentResourceName(), "database.json", json.encode(database), -1)
    SaveResourceFile(GetCurrentResourceName(), "collections.json", json.encode(collections), -1)
end)

lib.addCommand('cdb_import', {
    help = 'Import the database from json file',
    restricted = 'group.chiliaddb',
}, function(source, args, raw)
    dropDatabase()
    collections = json.decode(LoadResourceFile(GetCurrentResourceName(), 'collections.json'))
    if not database then
        lib.print.error("cdb_import command failed. collections.json import failed or file could not be found")
        return
    end
    database = json.decode(LoadResourceFile(GetCurrentResourceName(), 'database.json'))
    if not database then
        collections = {}
        lib.print.error("cdb_import command failed. database.json import failed or file could not be found")
        return
    end
    for k, v in pairs(database) do
        for k2, v2 in pairs(v) do
            if v2 ~= nil then
                SetResourceKvpNoSync(string.format("%s:%d", k, k2), json.encode(v2))
            end
        end
    end
    SetResourceKvpNoSync("collections", json.encode(collections))
    FlushResourceKvp()
end)