-- TODO: Make databaseCollectionCheck less confusing is it's used for multiple purposes, see renameCollection

if not lib.checkDependency('ox_lib', '3.28.1', true) then
    print(
        "^1FAILED^7 - ChiliadDB failed to start due to missing ox_lib dependency. Please make sure you have the latest version of ox_lib.")
    return
end

local optionsHandlers = require 'server.optionsHandlers'
local queryHandlers = require 'server.queryHandlers'
local utils = require 'server.utils'

local collections, database, collectionLocks, amendmentsList, amendmentsMap, secondaryIndexes, dbLoaded =
    {}, {}, {}, {}, {}, {}, false
local syncInProgress, syncPending = false, false
local collectionWriteQueues, collectionWriterRunning = {}, {}
local buildCollectionIndexes, rebuildAllIndexes

local function fireHook(collection, event, ...)
    TriggerEvent(string.format('chiliaddb:hook:%s:%s', collection, event), ...)
end

local function formatCaller(resource)
    return utils.formatCaller(resource)
end

local function databaseCollectionCheck(collection, resource)
    if database[collection] then return true end
    lib.print.debug(string.format("Collection %s does not exist. Called from %s", collection, formatCaller(resource)))
    return false
end

function DropDatabase()
    amendmentsList = {}
    amendmentsMap = {}
    for k in pairs(database) do
        local ids = collections[k].ids
        for i = 1, #ids do
            local k2 = ids[i]
            DeleteResourceKvpNoSync(string.format("%s:%d", k, k2))
        end
    end
    database = {}
    secondaryIndexes = {}
    DeleteResourceKvpNoSync("collections")
    collections = {}
    FlushResourceKvp()
    lib.print.info("Wiped KVP and memory")
end

function DropCollection(collection, resource)
    if not database[collection] then
        lib.print.error(string.format("dropCollection failed. Collection %s does not exist. Called from %s", collection,
            formatCaller(resource)))
        return false
    end
    local newList = {}
    for i = 1, #amendmentsList do
        local entry = amendmentsList[i]
        if entry.collection ~= collection then
            newList[#newList + 1] = entry
        else
            amendmentsMap[collection .. ':' .. entry.id] = nil
        end
    end
    amendmentsList = newList
    for i = 1, #collections[collection].ids do
        DeleteResourceKvpNoSync(string.format("%s:%d", collection, collections[collection].ids[i]))
    end
    collections[collection] = nil
    database[collection] = nil
    secondaryIndexes[collection] = nil
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

local function processCollectionWriteQueue(collection)
    collectionWriterRunning[collection] = true

    while true do
        local queue = collectionWriteQueues[collection]
        if not queue or #queue == 0 then
            collectionWriterRunning[collection] = false
            collectionWriteQueues[collection] = nil
            return
        end

        local item = table.remove(queue, 1)
        local ok, result = pcall(item.fn)
        item.complete(ok, result)
    end
end

local function runCollectionWrite(collection, fn)
    local queue = collectionWriteQueues[collection]

    if not collectionWriterRunning[collection] and (not queue or #queue == 0) then
        local ok, result = pcall(fn)
        if not ok then
            lib.print.error(string.format("Collection write queue failed for %s: %s", collection, result))
            return false
        end
        return result
    end

    if not queue then
        queue = {}
        collectionWriteQueues[collection] = queue
    end

    local done, success, result = false, false, nil

    queue[#queue + 1] = {
        fn = fn,
        complete = function(ok, value)
            success = ok
            result = value
            done = true
        end
    }

    if not collectionWriterRunning[collection] then
        CreateThread(function()
            processCollectionWriteQueue(collection)
        end)
    end

    while not done do
        Wait(0)
    end

    if not success then
        lib.print.error(string.format("Collection write queue failed for %s: %s", collection, result))
        return false
    end

    return result
end

function DropDocument(collection, id)
    collection = tostring(collection)
    id = tonumber(id)

    if not database[collection] then
        lib.print.error(string.format("dropDocument failed. Collection %s does not exist", collection))
        return false
    end

    if not id or not database[collection][id] then
        lib.print.error(string.format("dropDocument failed. Document %s does not exist in collection %s", tostring(id),
            collection))
        return false
    end

    return runCollectionWrite(collection, function()
        local deletedDoc = database[collection][id]
        DeleteDocument(collection, id)
        fireHook(collection, 'delete', id, deletedDoc)
        return true
    end)
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
        rebuildAllIndexes()
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

function ExportCollection(collection)
    collection = tostring(collection)
    if not database[collection] then
        lib.print.error(string.format("exportCollection failed. Collection %s does not exist", collection))
        return false
    end
    CreateThread(function()
        local payload = runCollectionWrite(collection, function()
            return json.encode({
                collection = collections[collection],
                documents = database[collection],
            })
        end)

        if not payload then return end

        local filename = string.format("%s.json", collection)
        SaveResourceFile(cache.resource, filename, payload, -1)
        lib.print.info(string.format("Collection '%s' exported to %s", collection, filename))
    end)
    return true
end

function ImportCollection(collection, filename)
    collection = tostring(collection)
    filename   = tostring(filename)
    CreateThread(function()
        local raw = LoadResourceFile(cache.resource, filename)
        if not raw then
            lib.print.error(string.format("importCollection failed. File '%s' not found", filename))
            return
        end
        local data = json.decode(raw)
        if not data or not data.collection or not data.documents then
            lib.print.error(string.format("importCollection failed. File '%s' has an invalid format", filename))
            return
        end
        if database[collection] then
            DropCollection(collection)
        end
        collections[collection] = data.collection
        database[collection]    = data.documents
        buildCollectionIndexes(collection)
        SetResourceKvpNoSync("collections", json.encode(collections))
        for k, v in pairs(data.documents) do
            if v ~= nil then
                SetResourceKvpNoSync(string.format("%s:%d", collection, k), json.encode(v))
            end
        end
        FlushResourceKvp()
        lib.print.info(string.format("Collection '%s' imported from '%s' (%d documents)", collection, filename,
            #collections[collection].ids))
    end)
    return true
end

local function createCollection(collection)
    collections[collection] = {
        currentIndex = 0,
        ids = {},
        indexes = {}
    }
    database[collection] = {}
    secondaryIndexes[collection] = {}
end

local indexSeparator = string.char(31)

local function normalizeIndexFields(fields)
    if type(fields) == 'string' then return { fields } end
    if type(fields) ~= 'table' then return nil end

    local normalized = {}
    for i = 1, #fields do
        if type(fields[i]) ~= 'string' or fields[i] == '' then return nil end
        normalized[#normalized + 1] = fields[i]
    end

    if #normalized == 0 then return nil end
    return normalized
end

local function getIndexName(fields)
    return table.concat(fields, indexSeparator)
end

local function isIndexableValue(value)
    return value ~= nil and type(value) ~= 'table'
end

local function getIndexKey(document, fields)
    if not document then return nil end

    local values = {}
    for i = 1, #fields do
        local value = document[fields[i]]
        if not isIndexableValue(value) then return nil end
        values[i] = string.format('%s:%s', type(value), tostring(value))
    end

    return table.concat(values, indexSeparator)
end

local function ensureIndexMetadata(collection)
    if not collections[collection] then createCollection(collection) end
    collections[collection].indexes = collections[collection].indexes or {}
    secondaryIndexes[collection] = secondaryIndexes[collection] or {}
end

local function addDocumentToIndexes(collection, id, document)
    local indexes = secondaryIndexes[collection]
    if not indexes then return true end

    for _, index in pairs(indexes) do
        local key = getIndexKey(document, index.fields)
        if key then
            if index.unique then
                local existing = index.map[key]
                if existing and existing ~= id then
                    return false, string.format('duplicate value for unique index %s', table.concat(index.fields, ','))
                end
                index.map[key] = id
            else
                index.map[key] = index.map[key] or {}
                index.map[key][id] = true
            end
        end
    end

    return true
end

local function removeDocumentFromIndexes(collection, id, document)
    local indexes = secondaryIndexes[collection]
    if not indexes then return end

    for _, index in pairs(indexes) do
        local key = getIndexKey(document, index.fields)
        if key then
            if index.unique then
                if index.map[key] == id then index.map[key] = nil end
            else
                local bucket = index.map[key]
                if bucket then
                    bucket[id] = nil
                    if not next(bucket) then index.map[key] = nil end
                end
            end
        end
    end
end

local function validateUniqueIndexes(collection, id, document)
    local indexes = secondaryIndexes[collection]
    if not indexes then return true end

    for _, index in pairs(indexes) do
        if index.unique then
            local key = getIndexKey(document, index.fields)
            local existing = key and index.map[key]
            if existing and existing ~= id then
                return false, string.format('duplicate value for unique index %s', table.concat(index.fields, ','))
            end
        end
    end

    return true
end

local function replaceDocumentInIndexes(collection, id, oldDocument, newDocument)
    local ok, err = validateUniqueIndexes(collection, id, newDocument)
    if not ok then return false, err end

    removeDocumentFromIndexes(collection, id, oldDocument)
    return addDocumentToIndexes(collection, id, newDocument)
end

buildCollectionIndexes = function(collection)
    ensureIndexMetadata(collection)
    secondaryIndexes[collection] = {}

    for name, definition in pairs(collections[collection].indexes) do
        local fields = normalizeIndexFields(definition.fields)
        if fields then
            secondaryIndexes[collection][name] = {
                fields = fields,
                unique = definition.unique == true,
                map = {}
            }
        end
    end

    local ids = collections[collection].ids or {}
    for i = 1, #ids do
        local id = ids[i]
        local ok, err = addDocumentToIndexes(collection, id, database[collection] and database[collection][id])
        if not ok then return false, err end
    end

    return true
end

rebuildAllIndexes = function()
    secondaryIndexes = {}
    for collection in pairs(collections) do
        local ok, err = buildCollectionIndexes(collection)
        if not ok then
            lib.print.error(string.format('Failed to build indexes for collection %s: %s', collection, err))
        end
    end
end

local function getIndexedIds(collection, query, preserveOrder)
    if not query or query.id then return nil end
    local indexes = secondaryIndexes[collection]
    if not indexes then return nil end

    for _, index in pairs(indexes) do
        local pseudoDocument = {}
        local indexable = true
        for i = 1, #index.fields do
            local field = index.fields[i]
            local value = query[field]
            if not isIndexableValue(value) then
                indexable = false
                break
            end
            pseudoDocument[field] = value
        end

        if indexable then
            local indexedValue = index.map[getIndexKey(pseudoDocument, index.fields)]
            if not indexedValue then return {} end
            if index.unique then return { indexedValue } end

            local ids = {}
            if preserveOrder then
                local collectionIds = collections[collection].ids
                for i = 1, #collectionIds do
                    local id = collectionIds[i]
                    if indexedValue[id] then ids[#ids + 1] = id end
                end
            else
                for id in pairs(indexedValue) do
                    ids[#ids + 1] = id
                end
            end
            return ids
        end
    end

    return nil
end

local function copyDocumentWithUpdate(document, update)
    local candidate = {}
    for k, v in pairs(document) do
        candidate[k] = v
    end
    for k, v in pairs(update) do
        candidate[k] = v
    end
    return candidate
end

local function insertDocument(collection, id, document)
    local ok, err = validateUniqueIndexes(collection, id, document)
    if not ok then
        lib.print.error(string.format('Insert failed for collection %s: %s', collection, err))
        return false
    end

    database[collection][id] = document
    addDocumentToIndexes(collection, id, document)
    return true
end

local function insertUpdateIntoKvp(collection, id)
    local data = database[collection][id]
    if not data then return end
    SetResourceKvpNoSync(string.format("%s:%d", collection, id), json.encode(data))
end

local function deleteFromKvp(collection, id)
    DeleteResourceKvpNoSync(string.format("%s:%d", collection, id))
end

local function doSyncToKvp()
    if syncInProgress then
        syncPending = true
        return false
    end

    syncInProgress = true

    repeat
        syncPending = false

        -- Snapshot and immediately reset so new writes accumulate in fresh structures
        -- while this batch is being written, without blocking the main thread.
        local batch = amendmentsList
        local batchCount = #batch
        amendmentsList = {}
        amendmentsMap = {}
        local start = os.nanotime()
        SetResourceKvpNoSync("collections", json.encode(collections))
        if batchCount > 0 then
            lib.print.debug("Syncing database to KVP")
            for i = 1, batchCount do
                local amendment = batch[i]
                if amendment.action == 'insert' or amendment.action == 'update' then
                    insertUpdateIntoKvp(amendment.collection, amendment.id)
                elseif amendment.action == 'delete' then
                    deleteFromKvp(amendment.collection, amendment.id)
                end
            end
            lib.print.debug(string.format("Sync to KVP complete. %s amendments made. Elapsed: %.4f ms", batchCount,
                (os.nanotime() - start) / 1e6))
        end
        FlushResourceKvp()
    until not syncPending

    syncInProgress = false
    return true
end

function SyncDataToKvp()
    if syncInProgress then
        syncPending = true
        return
    end

    CreateThread(doSyncToKvp)
end

local function propagateDatabaseFromKvp()
    local responseDatabase = {}
    local nowTime = os.time() * 1000
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
                        if collectionProps.retention then
                            local raw = GetResourceKvpString(key)
                            local lastUpdated = tonumber(raw:match('"lastUpdated"%s*:%s*(%d+)'))
                            if lastUpdated and lastUpdated + collectionProps.retention >= nowTime then
                                responseDatabase[collectionName][index] = json.decode(raw)
                            else
                                DeleteResourceKvpNoSync(key)
                            end
                        else
                            responseDatabase[collectionName][index] = json.decode(GetResourceKvpString(key))
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
    local key = collName .. ':' .. id
    local existing = amendmentsMap[key]
    if existing then
        if action == 'insert' or action == 'update' then
            return
        end
        if action == 'delete' then
            existing.action = 'delete'
            return
        end
    end
    local entry = { collection = collName, id = id, action = action }
    amendmentsMap[key] = entry
    amendmentsList[#amendmentsList + 1] = entry
end

local function removeIdFromCollections(collection, id)
    local ids = collections[collection].ids
    for i = 1, #ids do
        if ids[i] == id then
            ids[i] = ids[#ids]
            ids[#ids] = nil
            return
        end
    end
end

function DeleteDocument(collection, id)
    removeDocumentFromIndexes(collection, id, database[collection][id])
    database[collection][id] = nil
    removeIdFromCollections(collection, id)
    addToAmendments(collection, id, 'delete')
end

local function deleteDocuments(collection, ids)
    for i = 1, #ids do
        DeleteDocument(collection, ids[i])
    end
end

function ShowDatabaseCollections(source)
    if source == 0 then return end
    local resources = {}
    for k in pairs(collections) do
        if #collections[k].ids > 0 then
            local id = #resources + 1
            resources[id] = { id = id, name = k }
        end
    end
    table.sort(resources, function(k1, k2) return k1.name < k2.name end)
    TriggerClientEvent('chiliaddb:client:openExplorer', source, resources)
end

function PrintDatabaseInfo(args)
    if args.collection then
        if args.collection == 'all' then
            print(json.encode(database, { indent = true }))
        else
            if not database[args.collection] then
                lib.print.error(string.format("cdb_print command failed. Collection %s does not exist", args.collection))
                return
            end
            local key = string.format("%s", args.collection)
            if args.id then
                if not database[args.collection][args.id] then
                    lib.print.error(string.format("cdb_print command failed. Document %d does not exist in collection %s",
                        args.id, args.collection))
                    return
                end
                key = string.format("%s:%d", args.collection, args.id)
                print(key, json.encode(database[args.collection][args.id], { indent = true }))
            else
                local ids = collections[args.collection].ids
                for i = 1, #ids do
                    local id = ids[i]
                    print(string.format("%d:", id), json.encode(database[args.collection][id], { indent = true }))
                end
            end
        end
    end
end

local function skipIfExistsHandler(collection, document, options)
    if not database[collection] then return true end
    local query = {}
    for field in pairs(options.skipIfExists) do
        query[field] = document[field]
    end
    local ids = getIndexedIds(collection, query) or collections[collection].ids
    for i = 1, #ids do
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
            lib.print.debug(string.format("Record already exists in collection %s. Document %s", collection,
                json.encode(document)))
            return false
        end
    end
    return true
end

exports('find', function(data, resource)
    if not utils.paramChecker(data, resource, 'find') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return {} end
    local foundCollection, collection, query, responseData, keys = database[data.collection], tostring(data.collection),
        data.query, {}, {}
    if query then
        if query.id then
            return foundCollection[query.id]
        else
            local ids = getIndexedIds(collection, query) or collections[collection].ids
            responseData, keys = queryHandlers.find({ ids = ids }, foundCollection, query)
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
    local query, collection, foundCollection, responseData, key = data.query, data.collection, database[data.collection],
        nil, nil
    if query then
        if query.id and foundCollection[query.id] then
            key = query.id
            responseData = foundCollection[key]
        else
            local ids = getIndexedIds(collection, query, true) or collections[collection].ids
            key, responseData = queryHandlers.findOne(ids, foundCollection, query)
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

    return runCollectionWrite(collection, function()
        if query.id then
            local id = query.id
            if not database[collection] or not database[collection][id] then return false end
            local document = database[collection][id]
            local candidate = copyDocumentWithUpdate(document, data.update)
            candidate.lastUpdated = os.time() * 1000
            local ok, err = replaceDocumentInIndexes(collection, id, document, candidate)
            if not ok then
                lib.print.error(string.format('Update failed for collection %s: %s', collection, err))
                return false
            end
            database[collection][id] = candidate
            addToAmendments(collection, id, 'update')
            fireHook(collection, 'update', id, database[collection][id])
            return { id }
        else
            local responseData = {}
            if database[collection] then
                local foundCollection = database[collection]
                local ids = getIndexedIds(collection, query) or collections[collection].ids
                local now = os.time() * 1000
                for i = 1, #ids do
                    local k = ids[i]
                    local v = foundCollection[k]
                    if v and utils.queryMatch(v, query) then
                        local candidate = copyDocumentWithUpdate(v, data.update)
                        candidate.lastUpdated = now
                        local ok, err = replaceDocumentInIndexes(collection, k, v, candidate)
                        if not ok then
                            lib.print.error(string.format('Update failed for collection %s: %s', collection, err))
                            goto continueUpdate
                        end
                        database[collection][k] = candidate
                        addToAmendments(collection, k, 'update')
                        responseData[#responseData + 1] = k
                    end
                    ::continueUpdate::
                end
                if #responseData > 0 then
                    local updatedDocs = {}
                    for i = 1, #responseData do
                        updatedDocs[i] = database[collection][responseData[i]]
                    end
                    fireHook(collection, 'update', responseData, updatedDocs)
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
                newInsertDocument.lastUpdated = os.time() * 1000
                if not insertDocument(collection, insertedId, newInsertDocument) then return false end
                addToAmendments(collection, insertedId, 'insert')
                fireHook(collection, 'insert', insertedId, database[collection][insertedId])
                return { insertedId }
            end
            return responseData
        end
    end)
end)

exports('updateOne', function(data, resource)
    if not utils.paramChecker(data, resource, 'updateOne') then return false end
    local collection, query = tostring(data.collection), data.query

    return runCollectionWrite(collection, function()
        if query.id then
            local id = query.id
            if not database[collection] or not database[collection][id] then return false end
            local document = database[collection][id]
            local candidate = copyDocumentWithUpdate(document, data.update)
            candidate.lastUpdated = os.time() * 1000
            local ok, err = replaceDocumentInIndexes(collection, id, document, candidate)
            if not ok then
                lib.print.error(string.format('Update failed for collection %s: %s', collection, err))
                return false
            end
            database[collection][id] = candidate
            addToAmendments(collection, id, 'update')
            fireHook(collection, 'update', id, database[collection][id])
            return id
        else
            if not databaseCollectionCheck(collection, resource) then return false end
            local foundCollection = database[collection]
            local ids = getIndexedIds(collection, query, true) or collections[collection].ids
            for i = 1, #ids do
                local k = ids[i]
                local v = foundCollection[k]
                if v and utils.queryMatch(v, query) then
                    local candidate = copyDocumentWithUpdate(v, data.update)
                    candidate.lastUpdated = os.time() * 1000
                    local ok, err = replaceDocumentInIndexes(collection, k, v, candidate)
                    if not ok then
                        lib.print.error(string.format('Update failed for collection %s: %s', collection, err))
                        return false
                    end
                    database[collection][k] = candidate
                    addToAmendments(collection, k, 'update')
                    fireHook(collection, 'update', k, database[collection][k])
                    return k
                end
            end
            return false
        end
    end)
end)

exports('touch', function(data, resource)
    if not utils.paramChecker(data, resource, 'touch') then return false end
    local collection, query = tostring(data.collection), data.query

    return runCollectionWrite(collection, function()
        if query.id then
            local id = query.id
            if not database[collection] or not database[collection][id] then return false end
            database[collection][id].lastUpdated = os.time() * 1000
            addToAmendments(collection, id, 'update')
            -- fireHook(collection, 'update', id, database[collection][id])
            return { id }
        else
            local responseData = {}
            if database[collection] then
                local foundCollection = database[collection]
                local ids = collections[collection].ids
                local now = os.time() * 1000
                for i = 1, #ids do
                    local k = ids[i]
                    local v = foundCollection[k]
                    if utils.queryMatch(v, query) then
                        database[collection][k].lastUpdated = now
                        addToAmendments(collection, k, 'update')
                        responseData[#responseData + 1] = k
                    end
                end
                -- if #responseData > 0 then
                --     local updatedDocs = {}
                --     for i=1, #responseData do
                --         updatedDocs[i] = database[collection][responseData[i]]
                --     end
                --     fireHook(collection, 'update', responseData, updatedDocs)
                -- end
                -- debating whether touch should trigger update hooks, leaving it out for now since it can be used for non-semantic purposes like preventing record expiration, but can always be added back in later if there's demand for it
            end
            return responseData
        end
    end)
end)

exports('delete', function(data, resource)
    if not utils.paramChecker(data, resource, 'delete') then return false end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then return false end
    local query = data.query

    return runCollectionWrite(collection, function()
        if query.id then
            local id = query.id
            if database[collection][id] then
                local deletedDoc = database[collection][id]
                DeleteDocument(collection, id)
                fireHook(collection, 'delete', { id }, { deletedDoc })
                return { id }
            end
            return false
        else
            local ids = getIndexedIds(collection, query) or collections[collection].ids
            local keys = queryHandlers.delete({ ids = ids }, database[collection], query)
            local deletedDocs = {}
            for i = 1, #keys do
                deletedDocs[i] = database[collection][keys[i]]
            end
            deleteDocuments(collection, keys)
            fireHook(collection, 'delete', keys, deletedDocs)
            return keys
        end
    end)
end)

exports('deleteOne', function(data, resource)
    if not utils.paramChecker(data, resource, 'deleteOne') then return false end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then return false end
    local query = data.query

    return runCollectionWrite(collection, function()
        if query.id then
            local id = query.id
            if database[collection][id] then
                local deletedDoc = database[collection][id]
                DeleteDocument(collection, id)
                fireHook(collection, 'delete', id, deletedDoc)
                return id
            end
            return false
        else
            local ids = getIndexedIds(collection, query, true) or collections[collection].ids
            for i = 1, #ids do
                local k = ids[i]
                local v = database[collection][k]
                if v and utils.queryMatch(v, query) then
                    local deletedDoc = database[collection][k]
                    DeleteDocument(collection, k)
                    fireHook(collection, 'delete', k, deletedDoc)
                    return k
                end
            end
            return false
        end
    end)
end)

exports('exists', function(data, resource)
    if not utils.paramChecker(data, resource, 'exists') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return false end
    local collection = data.collection
    local foundCollection, query = database[collection], data.query
    if query.id then
        return foundCollection[query.id] and true or false
    else
        local ids = getIndexedIds(collection, query) or collections[collection].ids
        return queryHandlers.exists(ids, foundCollection, data.query)
    end
end)

exports('insertOne', function(data, resource)
    if not utils.paramChecker(data, resource, 'insertOne') then return false end
    local collection = tostring(data.collection)

    return runCollectionWrite(collection, function()
        --skipIfExists only works for non-table values
        if data.options and data.options.skipIfExists and skipIfExistsHandler(collection, data.document, data.options) == false then return false end

        local document = data.document
        local insertedId = incrementIndex(collection)
        local foundCollection = database[collection]
        if data.options then
            document = optionsHandlers.insert(insertedId, document, data.options)
        end
        document.lastUpdated = os.time() * 1000
        if foundCollection[insertedId] then
            return false
        end
        if not insertDocument(collection, insertedId, document) then return false end
        addToAmendments(collection, insertedId, 'insert')
        fireHook(collection, 'insert', insertedId, document)
        return insertedId
    end)
end)

exports('insert', function(data, resource)
    if not utils.paramChecker(data, resource, 'insert') then return false end
    local collection = tostring(data.collection)

    return runCollectionWrite(collection, function()
        if not databaseCollectionCheck(collection, resource) then
            createCollection(collection)
        end
        local responseData = {}
        local now = os.time() * 1000
        for i = 1, #data.documents do
            local document = data.documents[i]
            if data.options and data.options.skipIfExists and not skipIfExistsHandler(collection, document, data.options) then
                responseData[#responseData + 1] = false
                goto continue
            end
            local insertedId = incrementIndex(collection)
            if data.options then
                document = optionsHandlers.insert(insertedId, document, data.options)
            end
            document.lastUpdated = now
            if not insertDocument(collection, insertedId, document) then
                responseData[#responseData + 1] = false
                goto continue
            end
            addToAmendments(collection, insertedId, 'insert')
            responseData[#responseData + 1] = insertedId
            ::continue::
        end
        local insertedIds, insertedDocs = {}, {}
        for i = 1, #responseData do
            if responseData[i] then
                insertedIds[#insertedIds + 1] = responseData[i]
                insertedDocs[#insertedDocs + 1] = database[collection][responseData[i]]
            end
        end
        if #insertedIds > 0 then
            fireHook(collection, 'insert', insertedIds, insertedDocs)
        end
        return responseData
    end)
end)

exports('replaceOne', function(data, resource)
    if not utils.paramChecker(data, resource, 'replaceOne') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return false end
    local collection, foundCollection, query = tostring(data.collection), database[tostring(data.collection)], data
        .query

    return runCollectionWrite(collection, function()
        local document = data.document
        if query.id then
            local id = query.id
            if not foundCollection or not foundCollection[id] then return false end
            document.lastUpdated = os.time() * 1000
            local ok, err = replaceDocumentInIndexes(collection, id, foundCollection[id], document)
            if not ok then
                lib.print.error(string.format('Replace failed for collection %s: %s', collection, err))
                return false
            end
            foundCollection[id] = document
            addToAmendments(collection, id, 'update')
            fireHook(collection, 'update', id, document)
            return id
        else
            local ids = getIndexedIds(collection, query, true) or collections[collection].ids
            for i = 1, #ids do
                local k = ids[i]
                local v = foundCollection[k]
                local match = v and utils.queryMatch(v, query)
                if match then
                    document.lastUpdated = os.time() * 1000
                    local ok, err = replaceDocumentInIndexes(collection, k, foundCollection[k], document)
                    if not ok then
                        lib.print.error(string.format('Replace failed for collection %s: %s', collection, err))
                        return false
                    end
                    foundCollection[k] = document
                    addToAmendments(collection, k, 'update')
                    fireHook(collection, 'update', k, document)
                    return k
                end
            end
            return false
        end
    end)
end)

exports('aggregate', function(data, resource)
    if not utils.paramChecker(data, resource, 'aggregate') then return false end
    if not databaseCollectionCheck(data.collection, resource) then return {} end
    local foundCollection, collection, query, responseData, keys, group = database[data.collection],
        tostring(data.collection), data.query, {}, {}, data.group
    if query then
        local ids = getIndexedIds(collection, query) or collections[collection].ids
        responseData, keys = queryHandlers.find({ ids = ids }, foundCollection, query)
    else
        responseData, keys = foundCollection, collections[collection].ids
    end

    if group then
        responseData = utils.groupHandler(responseData, group, keys)
    end
    return responseData
end)

exports('getAmendmentsCount', function()
    return #amendmentsList
end)

exports('loaded', function()
    return dbLoaded
end)

exports('synckvp', SyncDataToKvp)

exports('dropCollection', DropCollection)

exports('getCollectionDocumentCount', function(collection, resource)
    if not collection then
        lib.print.error(string.format(
            "getCollectionDocumentCount call was improperly formatted, returning false. Called from %s. Sent data %s",
            formatCaller(resource), collection))
        return false
    end
    collection = tostring(collection)
    if not databaseCollectionCheck(collection, resource) then return 0 end
    return #collections[collection].ids
end)

exports('count', function(data, resource)
    if not utils.paramChecker(data, resource, 'count') then return false end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then return 0 end
    local query = data.query
    if not query then
        return #collections[collection].ids
    end
    local foundCollection = database[collection]
    local ids = getIndexedIds(collection, query) or collections[collection].ids
    local count = 0
    for i = 1, #ids do
        local k = ids[i]
        if utils.queryMatch(foundCollection[k], query) then
            count = count + 1
        end
    end
    return count
end)

exports('distinct', function(data, resource)
    if not utils.paramChecker(data, resource, 'distinct') then return false end
    local collection = tostring(data.collection)
    if not databaseCollectionCheck(collection, resource) then return {} end
    local field = tostring(data.field)
    local query = data.query
    local foundCollection = database[collection]
    local ids = query and getIndexedIds(collection, query) or collections[collection].ids
    return queryHandlers.distinct({ ids = ids }, foundCollection, field, query)
end)

exports('createCollection', function(collection, resource)
    collection = tostring(collection)
    if not collection then
        lib.print.error(string.format(
            "createCollection call was improperly formatted, returning false. Called from %s. Sent data %s",
            formatCaller(resource), collection))
        return false
    end
    if collections[collection] then
        lib.print.error(string.format("createCollection call failed. Collection %s already exists. Called from %s",
            collection,
            formatCaller(resource)))
        return false
    end
    createCollection(collection)
    return true
end)

exports('collectionExists', function(collection, resource)
    if not collection then
        lib.print.error(string.format("collectionExists call was improperly formatted, returning false. Called from %s.",
            formatCaller(resource)))
        return false
    end
    collection = tostring(collection)
    return collections[collection] ~= nil
end)

exports('ensureIndex', function(data, resource)
    if not utils.paramChecker(data, resource, 'ensureIndex') then return false end

    local collection = tostring(data.collection)
    local fields = normalizeIndexFields(data.fields)
    if not fields then
        lib.print.error(string.format('ensureIndex call has invalid fields. Called from %s.', formatCaller(resource)))
        return false
    end

    return runCollectionWrite(collection, function()
        ensureIndexMetadata(collection)
        local name = getIndexName(fields)
        local existing = collections[collection].indexes[name]
        local unique = data.unique == true

        if existing then
            if existing.unique == unique then return true end
            lib.print.error(string.format('ensureIndex call failed. Index already exists with different options in %s.',
                collection))
            return false
        end

        collections[collection].indexes[name] = {
            fields = fields,
            unique = unique
        }

        local ok, err = buildCollectionIndexes(collection)
        if not ok then
            collections[collection].indexes[name] = nil
            buildCollectionIndexes(collection)
            lib.print.error(string.format('ensureIndex call failed for collection %s: %s', collection, err))
            return false
        end

        return true
    end)
end)

function RenameCollection(collection, newName, resource)
    if not databaseCollectionCheck(collection, resource) then return false end
    if databaseCollectionCheck(newName, resource) then return false end

    lockCollection(collection)
    collectionLocks[newName] = true

    local oldCollectionMeta = collections[collection]
    local oldCollectionData = database[collection]

    collections[newName] = oldCollectionMeta
    database[newName] = oldCollectionData
    secondaryIndexes[newName] = secondaryIndexes[collection]
    collections[collection] = nil
    database[collection] = nil
    secondaryIndexes[collection] = nil

    local newAmendmentsList, newAmendmentsMap = {}, {}
    for i = 1, #amendmentsList do
        local entry = amendmentsList[i]
        if entry.collection == collection then
            entry.collection = newName
        end

        local amendmentKey = entry.collection .. ':' .. entry.id
        if not newAmendmentsMap[amendmentKey] then
            newAmendmentsMap[amendmentKey] = entry
            newAmendmentsList[#newAmendmentsList + 1] = entry
        else
            local existing = newAmendmentsMap[amendmentKey]
            if entry.action == 'delete' or existing.action ~= 'delete' then
                existing.action = entry.action
            end
        end
    end
    amendmentsList = newAmendmentsList
    amendmentsMap = newAmendmentsMap

    SetResourceKvpNoSync("collections", json.encode(collections))
    for i = 1, #oldCollectionMeta.ids do
        local id = oldCollectionMeta.ids[i]
        SetResourceKvpNoSync(string.format("%s:%d", newName, id), json.encode(oldCollectionData[id]))
        DeleteResourceKvpNoSync(string.format("%s:%d", collection, id))
    end

    collectionLocks[collection] = nil
    unlockCollection(newName)

    FlushResourceKvp()
    return true
end

exports('renameCollection', function(data, resource)
    if not utils.paramChecker(data, resource, 'renameCollection') then return false end
    local collection, newName = tostring(data.collection), tostring(data.newName)
    return RenameCollection(collection, newName, resource)
end)

exports('setCollectionRetention', function(data, resource)
    if not data or not data.collection then
        lib.print.error(string.format(
            "setCollectionRetention call was improperly formatted, returning false. Called from %s. Sent data %s",
            formatCaller(resource),
            json.encode(data)))
        return false
    end
    local collection = tostring(data.collection)
    if data.remove then
        if not databaseCollectionCheck(collection, resource) then return false end
        collections[collection].retention = nil
    else
        if not data.retention then
            lib.print.error(string.format(
                "setCollectionRetention call was improperly formatted, returning false. Called from %s. Sent data %s",
                formatCaller(resource), json.encode(data)))
            return false
        end
        if not databaseCollectionCheck(collection, resource) then
            createCollection(collection)
        end
        collections[collection].retention = utils.calculateMillis(data.retention)
    end
    return true
end)

exports('getCollectionProperties', function(collection, resource)
    collection = tostring(collection)
    if not collection then
        lib.print.error(string.format(
            "getCollectionProperties call was improperly formatted, returning false. Called from %s. Sent data %s",
            formatCaller(resource),
            json.encode(collection)))
        return false
    end
    return collections[collection] or false
end)

exports('backupDatabase', function(resource)
    lib.print.info(string.format("BackupDatabase called from %s", formatCaller(resource)))
    BackupDatabase()
end)

exports('exportCollection', function(collection, resource)
    if not collection then
        lib.print.error(string.format("exportCollection call was improperly formatted, returning false. Called from %s",
            formatCaller(resource)))
        return false
    end
    return ExportCollection(collection)
end)

exports('importCollection', function(data, resource)
    if not utils.paramChecker(data, resource, 'importCollection') then return false end
    if not data.filename then
        lib.print.error(string.format("importCollection call is missing 'filename'. Called from %s",
            formatCaller(resource)))
        return false
    end
    return ImportCollection(data.collection, data.filename)
end)

lib.callback.register('chiliaddb:server:getCollectionData', function(source, collection)
    if not utils.dbAccessCheck(source) then return {} end
    return database[collection]
end)

lib.callback.register('chiliaddb:server:getCollectionPage', function(source, collection, offset, limit, documentId)
    if not utils.dbAccessCheck(source) then return { ok = false, error = 'Access denied' } end

    collection = tostring(collection or '')
    if not database[collection] or not collections[collection] then
        return { ok = false, error = string.format('Collection %s does not exist', collection) }
    end

    limit = math.floor(tonumber(limit) or 50)
    if limit < 1 then limit = 50 end
    if limit > 500 then limit = 500 end

    local ids = collections[collection].ids or {}
    local total = #ids
    local documents = {}
    local pageIds = {}

    if documentId ~= nil and documentId ~= '' then
        local id = tonumber(documentId)
        if not id then
            return { ok = false, error = 'Document ID must be a number' }
        end

        local document = database[collection][id]
        if not document then
            return { ok = false, error = string.format('Document %s does not exist in %s', id, collection) }
        end

        documents[tostring(id)] = document
        pageIds[1] = id

        return {
            ok = true,
            collection = collection,
            documents = documents,
            ids = pageIds,
            offset = 0,
            limit = 1,
            total = total,
            hasPrevious = false,
            hasNext = false,
        }
    end

    offset = math.floor(tonumber(offset) or 0)
    if offset < 0 then offset = 0 end
    if total > 0 and offset >= total then
        offset = math.max(total - limit, 0)
    end

    local last = math.min(offset + limit, total)
    local pageIndex = 1
    for i = offset + 1, last do
        local id = ids[i]
        local document = database[collection][id]
        if document then
            documents[tostring(id)] = document
            pageIds[pageIndex] = id
            pageIndex = pageIndex + 1
        end
    end

    return {
        ok = true,
        collection = collection,
        documents = documents,
        ids = pageIds,
        offset = offset,
        limit = limit,
        total = total,
        hasPrevious = offset > 0,
        hasNext = last < total,
    }
end)

lib.callback.register('chiliaddb:server:createNewIndex', function(source, collection)
    if not utils.dbAccessCheck(source) then return {} end

    return runCollectionWrite(collection, function()
        local insertedId = incrementIndex(collection)
        local foundCollection = database[collection]
        if foundCollection[insertedId] then
            return false
        end

        local document = {}
        document.lastUpdated = os.time() * 1000
        if not insertDocument(collection, insertedId, document) then return false end
        addToAmendments(collection, insertedId, 'insert')
        fireHook(collection, 'insert', insertedId, document)
        return { id = insertedId, document = document }
    end)
end)

lib.callback.register('chiliaddb:server:createNewDocument', function(source, collection, id, document)
    if not utils.dbAccessCheck(source) then return {} end

    return runCollectionWrite(collection, function()
        document.lastUpdated = os.time() * 1000
        if not insertDocument(collection, id, document) then return false end
        addToAmendments(collection, id, 'insert')
        fireHook(collection, 'insert', id, document)
        return true
    end)
end)


lib.callback.register('chiliaddb:server:deleteDocument', function(source, collection, id)
    if not utils.dbAccessCheck(source) or not database[collection][id] then return false end

    return runCollectionWrite(collection, function()
        local deletedDoc = database[collection][id]
        DeleteDocument(collection, id)
        fireHook(collection, 'delete', id, deletedDoc)
        return true
    end)
end)

lib.callback.register('chiliaddb:server:updateDocument', function(source, collection, id, data)
    if not utils.dbAccessCheck(source) or not database[collection][id] then return false end

    return runCollectionWrite(collection, function()
        data.lastUpdated = os.time() * 1000
        local ok, err = replaceDocumentInIndexes(collection, id, database[collection][id], data)
        if not ok then
            lib.print.error(string.format('Update failed for collection %s: %s', collection, err))
            return false
        end
        database[collection][id] = data
        addToAmendments(collection, id, 'update')
        fireHook(collection, 'update', id, data)
        return true
    end)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    collections = json.decode(GetResourceKvpString("collections") or "{}")
    database = propagateDatabaseFromKvp()
    rebuildAllIndexes()
    dbLoaded = true
end)

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then return end
    doSyncToKvp()
end)

AddEventHandler('playerDropped', function()
    doSyncToKvp()
end)

local cronString = string.format('*/%s * * * *', GetConvarInt('chiliaddb:syncInterval', 5))
lib.cron.new(cronString, SyncDataToKvp)
