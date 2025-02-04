# ❓ Advanced query Operators
ChiliadDB supports advanced query operators that allow for more complex search criteria. These operators can be used within the query parameter to perform comparisons other than simple equality.

### `$gt`
The `$gt` operator matches documents where the field value is greater than the specified value.
```lua
local result = ChiliadDB.find({collection = 'test', query = { age = { ['$gt'] = 18 } }})
print(json.encode(result, {indent=true})) -- returns documents where age is greater than 18
```

### `$gte`

The `$gte` operator matches documents where the field value is greater than or equal to the specified value.
```lua
local result = ChiliadDB.find({collection = 'test', query = { age = { ['$gte'] = 18 } }})
print(json.encode(result, {indent=true})) -- returns documents where age is greater than or equal to 18
```

### `$lt`

The `$lt` operator matches documents where the field value is less than the specified value.
```lua
local result = ChiliadDB.find({collection = 'test', query = { age = { ['$lt'] = 18 } }})
print(json.encode(result, {indent=true})) -- returns documents where age is less than 18
```

### `$lte`

The `$lte` operator matches documents where the field value is less than or equal to the specified value.
```lua
local result = ChiliadDB.find({collection = 'test', query = { age = { ['$lte'] = 18 } }})
print(json.encode(result, {indent=true})) -- returns documents where age is less than or equal to 18
```

### `$ne`

The `$ne` operator matches documents where the field value is not equal to the specified value.
```lua
local result = ChiliadDB.find({collection = 'test', query = { permission = { ['$ne'] = 'admin' } }})
print(json.encode(result, {indent=true})) -- returns documents where permission is not 'admin'
```

### `$eq`

The `$eq` operator matches documents where the field value is equal to the specified value. This is the default behavior if no operator is specified.
```lua
local result = ChiliadDB.find({collection = 'test', query = { permission = { ['$eq'] = 'admin' } }})
print(json.encode(result, {indent=true})) -- returns documents where permission is 'admin'
```

These operators can be combined to create more complex queries, allowing for powerful and flexible data retrieval.
