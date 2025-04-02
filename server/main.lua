-- TODO: Make databaseCollectionCheck less confusing is it's used for multiple purposes, see renameCollection

if not lib.checkDependency('ox_lib', '3.28.1', true) then
    print("^1FAILED^7 - ChiliadDB failed to start due to missing ox_lib dependency. Please make sure you have the latest version of ox_lib.")
    return
end

local optionsHandlers = require 'server.optionsHandlers'
local queryHandlers = require 'server.queryHandlers'
local utils = require 'server.utils'

local collections, database, documentLocks, collectionLocks, amendments, dbLoaded = {}, {}, {}, {}, {}, false

local function databaseCollectionCheck(collection, resource)
    if database[collection] then return true end
    lib.print.debug(string.format("Collection %s does not exist. Called from %s", collection, resource))
    return false
end

function DropDatabase()
    amendments = {}
    for k in pairs(database) do
        local ids = collections[k].ids
        for i=1, #ids do
            local k2 = ids[i]
            DeleteResourceKvpNoSync(string.format("%s:%d", k, k2))
        end
    end
    database = {}
    DeleteResourceKvpNoSync("collections")
    collections = {}
    FlushResourceKvp()
    lib.print.info("Wiped KVP and memory")
end

function DropCollection(collection)
    if not database[collection] then
        lib.print.error(string.format("dropCollection failed. Collection %s does not exist", collection))
        return false
    end
    local newAmendments = {}
    for i = 1, #amendments do
        if amendments[i].collection ~= collection then
            newAmendments[#newAmendments + 1] = amendments[i]
        end
    end
    amendments = newAmendments
    for i=1, #collections[collection].ids do
        DeleteResourceKvpNoSync(string.format("%s:%d", collection, collections[collection].ids[i]))
    end
    collections[collection] = nil
    database[collection] = nil
    SetResourceKvpNoSync("collections", json.encode(collections))
    FlushResourceKvp()
    return true
end

local function lockCollection(collection)
    while collectionLocks[collection] do Wait(0) end
    collectionLocks[collection] = true
end

local function unlockCollection(collection)
    collectionLocks[collection] = false
end

local function lockAllCollections()
    for k in pairs(collections) do
        lockCollection(k)
    end
end

local function unlockAllCollections()
    for k in pairs(collections) do
        unlockCollection(k)
    end
end

local function lockDocument(collection, id)
    documentLocks[collection] = documentLocks[collection] or {}
    while documentLocks[collection][id] do Wait(0) end
    documentLocks[collection][id] = true
end

local function unlockDocument(collection, id)
    documentLocks[collection][id] = nil
end

function BackupDatabase()
    CreateThread(function()
        lockAllCollections()
        SaveResourceFile(cache.resource, "collections.json", json.encode(collections), -1)
        SaveResourceFile(cache.resource, "database.json", json.encode(database), -1)
        unlockAllCollections()
        lib.print.info("Database backup completed")
    end)
end

function RestoreDatabase()
    CreateThread(function()
        DropDatabase()
        collections = json.decode(LoadResourceFile(cache.resource, 'collections.json'))
        SetResourceKvpNoSync("collections", json.encode(collections))
        database = json.decode(LoadResourceFile(cache.resource, 'database.json'))
        for k, v in pairs(database) do
            for k2, v2 in pairs(v) do
                if v2 ~= nil then
                    SetResourceKvpNoSync(string.format("%s:%d", k, k2), json.encode(v2))
                end
            end
        end
        unlockAllCollections()
        FlushResourceKvp()
        lib.print.info("Database restoration completed")
    end)
end

local function createCollection(collection)
    collections[collection] = {
        currentIndex = 0,
        ids = {}
    }
    database[collection] = {}
end

local function insertUpdateIntoKvp(collection, id)
    local data = database[collection][id]
    if not data then return end
    SetResourceKvpNoSync(string.format("%s:%d", collection, id), json.encode(data))
end

local function deleteFromKvp(collection, id)
    DeleteResourceKvpNoSync(string.format("%s:%d", collection, id))
end

function SyncDataToKvp()
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
        end
        amendments = {}
        lib.print.debug(string.format("Sync to KVP complete. %s amendments made. Elapsed: %.4f ms", amendmentsCount, (os.nanotime() - start) / 1e6))
    end
    FlushResourceKvp()
end

local function propagateDatabaseFromKvp()
    local responseDatabase = {}
    local nowTime = os.time()*1000
    for collectionName, collectionProps in pairs(collections) do
        responseDatabase[collectionName] = {}
        local colonPos = string.len(collectionName) + 2
        local collectionKey = string.format("%s:", collectionName)
        local kvpHandle = StartFindKvp(collectionKey)
        if kvpHandle ~= -1 then
            local key
            repeat
                key = FindKvp(kvpHandle)
                if key then
                    local index = tonumber(key:sub(colonPos))
                    if index then
                        local data = json.decode(GetResourceKvpString(key))
                        if collectionProps.retention then
                            if data.lastUpdated + collectionProps.retention >= nowTime then
                                responseDatabase[collectionName][index] = data
                            else
                                DeleteResourceKvpNoSync(key)
                            end
                        else
                            responseDatabase[collectionName][index] = data
                        end
                    end
                end
            until not key
            EndFindKvp(kvpHandle)
        end
    end
    return responseDatabase
end

local function incrementIndex(collection)
    if not collections[collection] then createCollection(collection) end
    local currentIndex = collections[collection].currentIndex + 1
    collections[collection].currentIndex = currentIndex
    collections[collection].ids[#collections[collection].ids + 1] = currentIndex
    return currentIndex
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

local function removeIdFromCollections(collection, id)
    local newIds = {}
    for i = 1, #collections[collection].ids do
        if collections[collection].ids[i] ~= id then
            newIds[#newIds + 1] = collections[collection].ids[i]
        end
    end
    collections[collection].ids = newIds
end

function DeleteDocument(collection, id)
    database[collection][id] = nil
    removeIdFromCollections(collection, id)
    addToAmendments(collection, id, 'delete')
end

local function deleteDocuments(collection, ids)
    for i=1, #ids do
        DeleteDocument(collection, ids[i])
    end
end

function ShowDatabaseCollections(source)
    if source == 0 then return end
    local resources = {}
    for k in pairs(collections) do
        if #collections[k].ids > 0 then
            local id = #resources + 1
            resources[id] = {id = id, name = k}
        end
    end
    table.sort(resources, function (k1, k2) return k1.name < k2.name end )
    TriggerClientEvent('chiliaddb:client:openExplorer', source, resources)
end

function PrintDatabaseInfo(args)
    if args.collection then
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
end

local function skipIfExistsHandler(collection, document, options)
    if not database[collection] then return true end
    local ids = collections[collection].ids
    for i=1, #ids do
        local k = ids[i]
        local v = database[collection][k]
        local match = true
        for k2 in pairs(options.skipIfExists) do
            if not v[k2] or v[k2] ~= document[k2] then
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

exports('find', function(data, resource)
    if not utils.paramChecker(data, resource, 'find') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return {} end
    local foundCollection, collection, query, responseData, keys = database[data.collection], tostring(data.collection), data.query, {}, {}
    if query then
        if query.id then
            return foundCollection[query.id]
        else
            responseData, keys = queryHandlers.find(collections[collection], foundCollection, query)
        end
    else
        responseData, keys = foundCollection, collections[collection].ids
    end
    if data.options and responseData then
        responseData = optionsHandlers.find(responseData, data.options, keys)
    end
    return responseData
end)

exports('findOne', function(data, resource)
    if not utils.paramChecker(data, resource, 'findOne') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return false end
    local query, collection, foundCollection, responseData, key = data.query, data.collection, database[data.collection], nil, nil
    if query then
        if query.id and foundCollection[query.id] then
            key = query.id
            responseData = foundCollection[key]
        else
            key, responseData = queryHandlers.findOne(collections[collection].ids, foundCollection, query)
        end
    else
        key = collections[collection].ids[1]
        responseData = foundCollection[key]
    end
    if data.options and responseData then
        responseData = optionsHandlers.findOne(responseData, data.options)
    end
---@diagnostic disable-next-line: redundant-return-value
    return responseData, key
end)

exports('update', function(data, resource)
    if not utils.paramChecker(data, resource, 'update') then return false end
    local collection, query = tostring(data.collection), data.query
    if query.id then
        local id = query.id
        if not database[collection] or not database[collection][id] then return false end
        lockDocument(collection, id)
        local document = database[collection][id]
        for k, v in pairs(data.update) do
            document[k] = v
        end
        document.lastUpdated = os.time()*1000
        unlockDocument(collection, id)
        addToAmendments(collection, id, 'update')
        return {id}
    else
        local responseData = {}
        if database[collection] then 
            local foundCollection = database[collection]
            local ids = collections[collection].ids
            for i=1, #ids do
                local k = ids[i]
                local v = foundCollection[k]
                if utils.queryMatch(v, query) then
                    lockDocument(collection, k)
                    local document = database[collection][k]
                    for k2, v2 in pairs(data.update) do
                        document[k2] = v2
                    end
                    document.lastUpdated = os.time()*1000
                    unlockDocument(collection, k)
                    addToAmendments(collection, k, 'update')
                    responseData[#responseData + 1] = k
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
            lockCollection(collection)
            database[collection][insertedId] = newInsertDocument
            database[collection][insertedId].lastUpdated = os.time()*1000
            addToAmendments(collection, insertedId, 'insert')
            unlockCollection(collection)
            return {insertedId}
        end
        return responseData
    end
end)

exports('delete', function(data, resource)
    if not utils.paramChecker(data, resource, 'delete') then return false end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then return false end
    local query = data.query
    if query.id then
        local id = query.id
        if database[collection][id] then
            lockCollection(collection)
            DeleteDocument(collection, id)
            unlockCollection(collection)
            return {id}
        end
        return false
    else
        local keys = {}
        local foundCollection = database[collection]
        local ids = collections[collection].ids
        for i=1, #ids do
            local k = ids[i]
            local v = foundCollection[k]
            if utils.queryMatch(v, query) then
                keys[#keys + 1] = k
            end
        end
        lockCollection(collection)
        deleteDocuments(collection, keys)
        unlockCollection(collection)
        return keys
    end
end)

exports('exists', function(data, resource)
    if not utils.paramChecker(data, resource, 'exists') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return false end
    local collection = data.collection
    local foundCollection, query = database[collection], data.query
    if query.id then
        return foundCollection[query.id] and true or false
    else
        return queryHandlers.exists(collections[collection].ids, foundCollection, data.query)
    end
end)

exports('insert', function(data, resource)
    if not utils.paramChecker(data, resource, 'insert') then return false end
    --skipIfExists only works for non-table values
    if data.options and data.options.skipIfExists and skipIfExistsHandler(data.collection, data.document, data.options) == false then return false end
    local collection, document = tostring(data.collection), data.document
    local insertedId = incrementIndex(collection)
    local foundCollection = database[collection]
    if data.options then
        document = optionsHandlers.insert(insertedId, document, data.options)
    end
    document.lastUpdated = os.time()*1000
    if foundCollection[insertedId] then
        return false
    end
    lockCollection(collection)
    foundCollection[insertedId] = document
    unlockCollection(collection)
    addToAmendments(collection, insertedId, 'insert')
    return insertedId
end)

exports('insertMany', function(data, resource)
    if not utils.paramChecker(data, resource, 'insertMany') then return false end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then
        createCollection(collection)
    end
    local responseData = {}
    lockCollection(collection)
    for i=1, #data.documents do
        local document = data.documents[i]
        if data.options and data.options.skipIfExists and not skipIfExistsHandler(collection, document, data.options) then
            responseData[#responseData + 1] = false
            goto continue
        end
        local insertedId = incrementIndex(collection)
        if data.options then
            document = optionsHandlers.insert(insertedId, document, data.options)
        end
        -- document = data.options and optionsHandlers.insert(insertedId, document, data.options) or document
        document.lastUpdated = os.time()*1000
        database[collection][insertedId] = document
        addToAmendments(collection, insertedId, 'insert')
        responseData[#responseData + 1] = insertedId
        ::continue::
    end
    unlockCollection(collection)
    return responseData
end)

exports('replaceOne', function(data, resource)
    if not utils.paramChecker(data, resource, 'replaceOne') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return false end
    local collection, document, foundCollection, query = tostring(data.collection), data.document, database[tostring(data.collection)], data.query
    if query.id then
        local id = query.id
        if not foundCollection or not foundCollection[id] then return false end
        lockDocument(collection, id)
        document.lastUpdated = os.time()*1000
        foundCollection[id] = document
        unlockDocument(collection, id)
        addToAmendments(collection, id, 'update')
        return id
    else
        local ids = collections[collection].ids
        for i=1, #ids do
            local k = ids[i]
            local v = foundCollection[k]
            local match = utils.queryMatch(v, query)
            if match then
                lockDocument(collection, k)
                document.lastUpdated = os.time()*1000
                foundCollection[k] = document
                unlockDocument(collection, k)
                addToAmendments(collection, k, 'update')
                return k
            end
        end
        return false
    end
end)

exports('aggregate', function(data, resource)
    if not utils.paramChecker(data, resource, 'aggregate') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return {} end
    local foundCollection, collection, query, responseData, keys, group = database[data.collection], tostring(data.collection), data.query, {}, {}, data.group
    if query then
        responseData, keys = queryHandlers.find(collections[collection], foundCollection, query)
    else
        responseData, keys = foundCollection, collections[collection].ids
    end

    if group then
        responseData = utils.groupHandler(responseData, group, keys)
    end
    return responseData
end)

exports('getAmendmentsCount', function()
    return #amendments
end)

exports('loaded', function()
    return dbLoaded
end)

exports('synckvp', SyncDataToKvp)

exports('dropCollection', DropCollection)

exports('getCollectionDocumentCount', function(collection, resource)
    if not collection then
        lib.print.error(string.format("getCollectionDocumentCount call was improperly formatted, returning false. Called from %s. Sent data %s", resource, collection))
        return false
    end
    collection = tostring(collection)
    if not databaseCollectionCheck(collection, resource) then return 0 end
    return #collections[collection].ids
end)

exports('createCollection', function(collection, resource)
    collection = tostring(collection)
    if not collection then
        lib.print.error(string.format("createCollection call was improperly formatted, returning false. Called from %s. Sent data %s", resource, collection))
        return false
    end
    if collections[collection] then
        lib.print.error(string.format("createCollection call failed. Collection %s already exists", collection))
        return false
    end
    createCollection(collection)
    return true
end)

function RenameCollection(collection, newName, resource)
    if not databaseCollectionCheck(collection, resource) then return false end
    if databaseCollectionCheck(newName, resource) then return false end

    collections[newName] = lib.table.deepclone(collections[collection])
    database[newName] = lib.table.deepclone(database[collection])
    DropCollection(collection)
    return true
end

exports('renameCollection', function(data, resource)
    if not utils.paramChecker(data, resource, 'renameCollection') then return false end
    local collection, newName = tostring(data.collection), tostring(data.newName)
    return RenameCollection(collection, newName, resource)
end)

exports('setCollectionProperties', function(data, resource)
    if not data or not data.collection or not data.retention then
        lib.print.error(string.format("setCollectionProperties call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(data)))
        return false
    end
    local retention, collection = data.retention, tostring(data.collection)
    if retention then
        if retention.remove then
            collections[collection].retention = nil
        else
            local calculatedMillis = utils.calculateMillis(retention)
            if not databaseCollectionCheck(collection, resource) then
                createCollection(collection)
            end
            collections[collection].retention = calculatedMillis
        end
    end
    return true
end)

exports('getCollectionProperties', function(collection, resource)
    collection = tostring(collection)
    if not collection then
        lib.print.error(string.format("getCollectionProperties call was improperly formatted, returning false. Called from %s. Sent data %s", resource, json.encode(collection)))
        return false
    end
    return collections[collection] or false
end)

exports('backupDatabase', function(resource)
    lib.print.info(string.format("BackupDatabase called from %s", resource))
    BackupDatabase()
end)

lib.callback.register('chiliaddb:server:getCollectionData', function(source, collection)
    if not utils.dbAccessCheck(source) then return {} end
    return database[collection]
end)

lib.callback.register('chiliaddb:server:createNewIndex', function(source, collection)
    if not utils.dbAccessCheck(source) then return {} end
    local insertedId = incrementIndex(collection)
    local foundCollection = database[collection]
    if foundCollection[insertedId] then
        return false
    end

    lockCollection(collection)
    local document = {}
    document.lastUpdated = os.time()*1000
    foundCollection[insertedId] = document
    addToAmendments(collection, insertedId, 'insert')
    unlockCollection(collection)
    return {id = insertedId, document = document}
end)

lib.callback.register('chiliaddb:server:createNewDocument', function(source, collection, id, document)
    if not utils.dbAccessCheck(source) then return {} end
    local foundCollection = database[collection]

    lockCollection(collection)
    document.lastUpdated = os.time()*1000
    foundCollection[id] = document
    addToAmendments(collection, id, 'insert')
    unlockCollection(collection)
    return true
end)


lib.callback.register('chiliaddb:server:deleteDocument', function(source, collection, id)
    if not utils.dbAccessCheck(source) or not database[collection][id] then return false end

    DeleteDocument(collection, id)
    return true
end)

lib.callback.register('chiliaddb:server:updateDocument', function(source, collection, id, data)
    if not utils.dbAccessCheck(source) or not database[collection][id] then return false end

    lockDocument(collection, id)
    data.lastUpdated = os.time()*1000
    database[collection][id] = data
    unlockDocument(collection, id)
    addToAmendments(collection, id, 'update')
    return true
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    collections = json.decode(GetResourceKvpString("collections") or "{}")
    database = propagateDatabaseFromKvp()
    dbLoaded = true
end)

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then return end
    SyncDataToKvp()
end)

local cronString = string.format('*/%s * * * *', GetConvarInt('chiliaddb:syncInterval', 5))
lib.cron.new(cronString, SyncDataToKvp)