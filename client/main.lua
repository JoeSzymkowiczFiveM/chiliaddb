RegisterNetEvent('chiliaddb:client:openExplorer', function(result)
    if source == '' then return end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openJsonUi',
        data = result
    })
end)

RegisterNUICallback('closeUi', function(data, cb)
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback('getCollectionData', function(data, cb)
    local result = lib.callback.await('chiliaddb:server:getCollectionData', false, data.name)
    cb(result)
end)

RegisterNUICallback('createNewIndex', function(data, cb)
    local result = lib.callback.await('chiliaddb:server:createNewIndex', false, data.collection)
    cb(result)
end)

RegisterNUICallback('createNewDocument', function(data, cb)
    local result = lib.callback.await('chiliaddb:server:createNewDocument', false, data.collection, data.id, data.document)
    cb(result)
end)

RegisterNUICallback('deleteDocument', function(data, cb)
    local result = lib.callback.await('chiliaddb:server:deleteDocument', false, data.collection, data.id)
    cb(result)
end)

RegisterNUICallback('updateDocument', function(data, cb)
    local result = lib.callback.await('chiliaddb:server:updateDocument', false, data.collection, data.id, data.document)
    cb(result)
end)