if not IsDuplicityVersion() then return end

local chiliaddb = exports.chiliaddb
local resourceName = GetCurrentResourceName()
local GetResourceState = GetResourceState

ChiliadDB = setmetatable({}, {
    __index = function(self, index)
        self[index] = function(...)
            return chiliaddb[index](nil, ..., resourceName)
        end

        return self[index]
    end
})

local function onReady(cb)
    while GetResourceState('chiliaddb') ~= 'started' do
        Wait(50)
    end

    repeat
        Wait(5)
    until chiliaddb:loaded()
    cb()
end

ChiliadDB.ready = setmetatable({
    await = onReady
}, {
    __call = function(_, cb)
        Citizen.CreateThreadNow(function() onReady(cb) end)
    end,
})

_ENV.ChiliadDB = ChiliadDB
