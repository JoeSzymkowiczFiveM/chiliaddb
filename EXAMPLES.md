# 📝 Usage Examples

Below are several examples usages examples of functions within ChiliadDB.

## 🏎️ ChiliadDB.ready
`ready` is triggered once the datastore has been loaded and the resource is ready to accept calls. It is not guaranteed that ChiliadDB has propagated by the time subsequent resources are started. If you're resource needs to be initially loaded with data on start, use this.
```lua
ChiliadDB.ready(function()
    print('ChiliadDB is loaded and ready for calls')
end)
```

## ✏️ ChiliadDB.insert
`insert` is how you create a new document in the datastore. At the moment, the driver can create a single document each call, and will return
a numeric id for the inserted document, or false if insert encountered errors or skipped
```lua
local resultInsert = ChiliadDB.insert({collection = 'test', document = {permission = 'god', name = 'Joe', citizenid = 1}})
print(resultInsert) -- resultInsert is a numeric id for the inserted document, or false if insert encountered errors
```

## ✏️ ChiliadDB.insertMany
`insertMany` is how you create one or many documents in the datastore. At the moment, the driver can create a single document each call, and will return
a numeric id for the inserted document, or false if insert encountered errors or skipped
```lua
local resultInsert = ChiliadDB.insertMany({collection = 'test', documents = {
    {permission = 'god', name = 'Joe', citizenid = 1},
    {permission = 'admin', name = 'David', citizenid = 2},
}})
print(resultInsert) -- resultInsert is an array of ids that were inserted, given the order of the documents
```

### `.insert` and `.insertMany` options
You can pass `options` parameters, to the `insert` function to further modify how documents are created.

#### selfInsertId
This allows you to specify one or many field names, that will be populated with the index that the record will be stored with. For example, you can specify 'charId', and the 'charId' field will be added to the stored record with the set index of that record. This can be a single string or a table of strings.
```lua
local resultInsertId = ChiliadDB.insert({collection = 'test', document = {permission = 'admin', name = 'Joseph', citizenid = 1}, options = {selfInsertId = 'charId'}})
local resultFindOneId = ChiliadDB.findOne({collection = 'test', query = { id = resultInsertId } })
print(resultFindOneId) -- resultFindOneId will include a field charId with the numeric inserted id
```

#### skipIfExists
This will abort insert if an existing record in the collection matches specific field values.
```lua
local resultInsertSkip = ChiliadDB.insert({collection = 'test', document = {permission = 'admin', name = 'Joseph', citizenid = 1}, options = {skipIfExists = {citizenid = true}}})
print(resultInsertSkip) -- resultInsertSkip will be false as the insert example above already created a record with that `citizenid`, and no new document was created
```


## ✏️ ChiliadDB.update
`update` is how you would modify one or more existing documents in the datastore, given the selection query. It's important to note that it is possible to change the datatype of exist values with this function. Be very careful.
```lua
local resultUpdate = ChiliadDB.update({collection = 'test', query = {age = {['$lt'] = 11}}, update = { name = 'Joseph' }})
print(json.encode(resultUpdate, {indent=true}))
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
You can also use the `id` parameter in the `query` to specific a specific index from the specified collection that you want. `id` must be numeric.
```

### `.find` options
You can pass `options` parameters, to further help the search and response of the `find` function.

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
local findOneDocument, findOneKey = ChiliadDB.findOne({collection = 'test', query = { permission = 'god' }, update = {  permission = 'normie' } })
print(json.encode(resultFindOne, {indent=true})) -- resultFindOne is the resulting document table, or nil if no result found
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
ChiliadDB.delete({collection = 'test'}, query = { permission = 'god' })
```


## ❓ ChiliadDB.exists
`exists` is used to determine if any records in the collection match the provided criteria. This returns `true` if a match is found, `false` if no match is found.
```lua
local resultExists = ChiliadDB.exists({collection = 'test'}, query = { permission = 'pleb' })
print(result) -- resultExists is return if a record in the specified collection matches the included criteria; false if not
```


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


## ⚙️ ChiliadDB.getCollectionProperties
`getCollectionProperties` will retrieve the proprties of the requested collection name, like the `currentIndex`, etc. If the collection doesn't exist, this will return false.
```lua
local resultExists = ChiliadDB.getCollectionProperties('testCollection')
```


## ⚙️ ChiliadDB.setCollectionProperties
`setCollectionProperties` will retrieve the proprties of the requested collection name, like the `retention`, etc. If the collection doesn't exist, this will create the collection.
```lua
local resultExists = ChiliadDB.setCollectionProperties({collection = 'testCollection', retention = {seconds = 5, minutes = 1}})
```

### `.setCollectionProperties` settings
You can modify a number of parameters on collections that change behaviors of documents in that collection.

#### retention
This sets the amount of time documents, unmodified, in this collection will be retained within the collection. This can be set using `seconds`, `minutes`, `hours`, `days`, `months`. Upon startup of the datastore, if the `lastUpdated` values on the document exceeds the `retention` amount, it will be not be loaded into the datastore and deleted from the KVP.