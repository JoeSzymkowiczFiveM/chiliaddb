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

RegisterNUICallback('onChangeData', function(data, cb)
    TriggerServerEvent('chiliaddb:server:onChangeData', data)
    cb(true)
end)