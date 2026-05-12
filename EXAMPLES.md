# 📝 Usage Examples

Below are several examples usages examples of functions within ChiliadDB.

## 🏎️ ChiliadDB.ready
`ready` is triggered once the datastore has been loaded and the resource is ready to accept calls. It is not guaranteed that ChiliadDB has propagated by the time subsequent resources are started. If you're resource needs to be initially loaded with data on start, use this.
```lua
ChiliadDB.ready(function()
    print('ChiliadDB is loaded and ready for calls')
end)
```

## ✏️ ChiliadDB.insertOne
`insertOne` is how you create a new document in the datastore. At the moment, the driver can create a single document each call, and will return
a numeric id for the inserted document, or false if insertOne encountered errors or skipped
```lua
local resultInsert = ChiliadDB.insertOne({collection = 'test', document = {permission = 'god', name = 'Joe', citizenid = 1}})
print(resultInsert) -- resultInsert is a numeric id for the inserted document, or false if insertOne encountered errors
```

## ✏️ ChiliadDB.insert
`insert` is how you create one or many documents in the datastore. It returns
an array of ids for the inserted documents, in the order they were provided
```lua
local resultInsert = ChiliadDB.insert({collection = 'test', documents = {
    {permission = 'god', name = 'Joe', citizenid = 1},
    {permission = 'admin', name = 'David', citizenid = 2},
}})
print(resultInsert) -- resultInsert is an array of ids that were inserted, given the order of the documents
```

### `.insertOne` and `.insert` options
You can pass `options` parameters, to the `insertOne` or `insert` functions to further modify how documents are created.

#### selfInsertId
This allows you to specify one or many field names, that will be populated with the index that the record will be stored with. For example, you can specify 'charId', and the 'charId' field will be added to the stored record with the set index of that record. This can be a single string or a table of strings.
```lua
local resultInsertId = ChiliadDB.insertOne({collection = 'test', document = {permission = 'admin', name = 'Joseph', citizenid = 1}, options = {selfInsertId = 'charId'}})
local resultFindOneId = ChiliadDB.findOne({collection = 'test', query = { id = resultInsertId } })
print(resultFindOneId) -- resultFindOneId will include a field charId with the numeric inserted id
```

#### skipIfExists
This will abort insert if an existing record in the collection matches specific field values.
```lua
local resultInsertSkip = ChiliadDB.insertOne({collection = 'test', document = {permission = 'admin', name = 'Joseph', citizenid = 1}, options = {skipIfExists = {citizenid = true}}})
print(resultInsertSkip) -- resultInsertSkip will be false as the insertOne example above already created a record with that `citizenid`, and no new document was created
```


## ✏️ ChiliadDB.update
`update` is how you would modify one or more existing documents in the datastore, given the selection query. It's important to note that it is possible to change the datatype of exist values with this function. Be very careful.
```lua
local resultUpdate = ChiliadDB.update({collection = 'test', query = {age = {['$lt'] = 11}}, update = { name = 'Joseph' }})
print(json.encode(resultUpdate, {indent=true}))
```


## ✏️ ChiliadDB.updateOne
`updateOne` is similar to `update` but modifies only the **first** matching document and returns its numeric id, or `false` if no match was found. Useful when you know there is at most one record and want to avoid accidental bulk updates.
```lua
local updatedId = ChiliadDB.updateOne({collection = 'players', query = {steamid = 'steam:abc123'}, update = {cash = 5000}})
print(updatedId) -- the numeric id of the updated document, or false
```


## ✏️ ChiliadDB.replaceOne
`replaceOne` will find the first matching document given the query filter, and replace the entire document with the provided `update` contents.
```lua
local resultReplaceOne = ChiliadDB.replaceOne({collection = 'test', query = {id = 1}, document = { name2 = 'Joseph' }})
print(json.encode(resultReplaceOne, {indent=true}))
```


## 🔎 ChiliadDB.find
`find` is a basic search, similar to a SQL `select` that can return no to many records from a single collection, given the query parameters. If one or more results are returned, they are in an array of tables, where the keys are the associated records indexes.
```lua
local resultFind = ChiliadDB.find({collection = 'test', query = { permission = 'god' } })
print(json.encode(resultFind, {indent=true})) -- resultFind is an empty table or an array of tables
```
You can also use the `id` parameter in the `query` to specify a specific index from the specified collection that you want. `id` must be numeric.

### `.find` options
You can pass `options` parameters, to further help the search and response of the `find` function.

#### sort
This will sort the results by the specified field before any other options (such as `limit`) are applied. Provide a table with `field` (the document field to sort by) and `order` (`'asc'` for ascending, `'desc'` for descending, defaults to `'asc'`). Pair with `excludeIndexes` to receive a sequentially ordered array.
```lua
-- Get the top 10 players by score, returned as an ordered array
local topPlayers = ChiliadDB.find({
    collection = 'leaderboard',
    options = {
        sort = { field = 'score', order = 'desc' },
        limit = 10,
        excludeIndexes = true
    }
})
print(json.encode(topPlayers, {indent=true}))
```

#### limit
This will limit the response records to the number specified in the `limit` value

#### excludeIndexes
This will remove the associated index/key from each record in the response, and pass back an entirely sequential array of tables. It's worth noting that since the you can delete records from the datastore, it's possible to create 'holes' in the indexes.

#### excludeFields
This will specify any fields that should not be included in the the response object(s).

#### includeFields
This will limit the fields in each response object(s) to the specified fields.


## 🔎 ChiliadDB.findOne
`findOne` is similar to `find` but returns the first match in the collection given the query criteria, using the numeric index as a sort order, and only return a single table.
```lua
local findOneDocument, findOneKey = ChiliadDB.findOne({collection = 'test', query = { permission = 'god' } })
print(json.encode(findOneDocument, {indent=true})) -- findOneDocument is the resulting document table, or nil if no result found
print(findOneKey) -- findOneKey is a numeric key, or nil if no result found
```

### `.findOne` options
You can pass `options` parameters, to further help the search and response of the `findOne` function.

#### excludeFields
This will specify any fields that should not be included in the the response object(s).

#### includeFields
This will limit the fields in each response object(s) to the specified fields.


## 🗑️ ChiliadDB.delete
`delete` is how you would remove one or more existing documents in the datastore, given the selection query. To guarentee removal of a single document, use the `id` key in the query criteria.
```lua
ChiliadDB.delete({collection = 'test', query = { permission = 'god' }})
```


## 🗑️ ChiliadDB.deleteOne
`deleteOne` removes only the **first** matching document and returns its numeric id, or `false` if no match was found. Safer than `delete` when you only intend to remove a single record.
```lua
local deletedId = ChiliadDB.deleteOne({collection = 'logs', query = {type = 'temp'}})
print(deletedId) -- the numeric id of the deleted document, or false
```


## ❓ ChiliadDB.exists
`exists` is used to determine if any records in the collection match the provided criteria. This returns `true` if a match is found, `false` if no match is found.
```lua
local resultExists = ChiliadDB.exists({collection = 'test', query = { permission = 'pleb' }})
print(resultExists) -- resultExists is true if a record in the specified collection matches the included criteria; false if not
```


## 🔢 ChiliadDB.count
`count` returns the number of documents in a collection that match an optional query. If no `query` is provided, the total document count for the collection is returned. Returns `0` if the collection does not exist.
```lua
-- Count all documents in a collection
local total = ChiliadDB.count({collection = 'players'})
print(total)

-- Count documents matching a query
local policePlayers = ChiliadDB.count({collection = 'players', query = {job = 'police'}})
print(policePlayers)
```


## 🔎 ChiliadDB.aggregate
`aggregate` lets you query for specific documents, and then create groupings within that set based on like data within those documents.
```lua
local aggregateResult = ChiliadDB.aggregate({collection = 'characters', query = {name = "test4"}, group = { fields = {"class"}, sum = "age", alias = "ageSum"} })
print(json.encode(aggregateResult, {indent=true}))
-- aggregateResult is the resulting aggregate of documents in the characters collection, with the name "test4". Those documents are then grouped by distinct values
-- in the "class" field, and within each grouping, the values of the "age" fielded are added together, to a new output field called "ageSum".
```

### `group` parameters explained
This function requires a couple specific parameters, to use it correctly. They are:

#### fields
This is one or more fields that woulld be aggregrated by like values, to create the groupings in the produced output.

#### sum
This is the target column that will be aggregated by the fields defined before.

#### alias
This allows you to name the aggregated column something else.


## 📗 ChiliadDB.createCollection
`createCollection` will create a new collection
```lua
local resultExists = ChiliadDB.createCollection('testCollection')
```


## 🗑️ ChiliadDB.dropCollection
`dropCollection` will remove the collection specified and any documents within in.
```lua
local resultExists = ChiliadDB.dropCollection('testCollection')
```


## ❓ ChiliadDB.collectionExists
`collectionExists` checks whether a named collection exists in the database without needing to catch errors from other exports. Returns `true` if the collection exists, `false` otherwise.
```lua
if ChiliadDB.collectionExists('players') then
    print('players collection is available')
else
    print('players collection does not exist')
end
```


## ⚙️ ChiliadDB.getCollectionProperties
`getCollectionProperties` will retrieve the proprties of the requested collection name, like the `currentIndex`, etc. If the collection doesn't exist, this will return false.
```lua
local resultExists = ChiliadDB.getCollectionProperties('testCollection')
```


## ⚙️ ChiliadDB.setCollectionRetention
`setCollectionRetention` sets or removes the retention policy on a collection. Documents whose `lastUpdated` timestamp is older than the retention period will be pruned when the datastore next starts. If the collection does not exist it will be created automatically.
```lua
-- Set a retention period of 1 minute and 5 seconds
ChiliadDB.setCollectionRetention({collection = 'tempTokens', retention = {minutes = 1, seconds = 5}})

-- Remove the retention policy from a collection
ChiliadDB.setCollectionRetention({collection = 'tempTokens', remove = true})
```

### `retention` time units
You can combine any of the following time unit keys: `seconds`, `minutes`, `hours`, `days`, `months`. Upon startup of the datastore, any document whose `lastUpdated` value is older than the computed retention period will be discarded and removed from KVP.
