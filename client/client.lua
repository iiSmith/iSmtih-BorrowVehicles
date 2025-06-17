local QBCore = exports['qb-core']:GetCoreObject()

local plateModel = "prop_fib_badge"
local animDict = "missfbi_s4mop"
local animName = "swipe_card"
local plate_net = nil

function startAnim()
    RequestModel(GetHashKey(plateModel))
    while not HasModelLoaded(GetHashKey(plateModel)) do
        Citizen.Wait(100)
    end

    ClearPedSecondaryTask(PlayerPedId())

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(100)
    end

    local playerPed = PlayerPedId()
    local plyCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 0.0, -5.0)

    local plateObject = CreateObject(GetHashKey(plateModel), plyCoords.x, plyCoords.y, plyCoords.z, true, true, false)

    local netid = ObjToNet(plateObject)
    SetNetworkIdExistsOnAllMachines(netid, true)
    SetNetworkIdCanMigrate(netid, false)

    TaskPlayAnim(playerPed, animDict, animName, 1.0, 1.0, -1, 50, 0, false, false, false)

    Citizen.Wait(800)

    AttachEntityToEntity(plateObject, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 0, true)

    plate_net = netid

    Citizen.Wait(3000)

    ClearPedSecondaryTask(playerPed)
    if plate_net then
        local obj = NetToObj(plate_net)
        if DoesEntityExist(obj) then
            DetachEntity(obj, true, true)
            DeleteEntity(obj)
        end
        plate_net = nil
    end
end

local function CheckNpcStatus(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver and driver ~= 0 and not IsPedAPlayer(driver) and not IsEntityDead(driver) then
        return true
    end
    return false
end

local function EjectNPC(vehicle, driverPed)
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 0, maxSeats - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 and ped ~= driverPed and not IsPedAPlayer(ped) and not IsEntityDead(ped) then
            TaskLeaveVehicle(ped, vehicle, 0)
            Wait(300)

            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            ClearPedTasksImmediately(ped)
            TaskSmartFleePed(ped, PlayerPedId(), 100.0, -1, false, false)
            SetPedKeepTask(ped, true)
        end
    end
end

local function BorrowVehicle(vehicle)
    startAnim()

    local driverPed = GetPedInVehicleSeat(vehicle, -1)
    if driverPed == 0 or IsEntityDead(driverPed) then return end

    SetVehicleDoorsLocked(vehicle, 4)

    EjectNPC(vehicle, driverPed)

    TaskLeaveVehicle(driverPed, vehicle, 0)

    Wait(1500)

    local playerPed = PlayerPedId()

    SetBlockingOfNonTemporaryEvents(driverPed, true)
    SetPedFleeAttributes(driverPed, 0, false)
    SetPedCombatAttributes(driverPed, 46, true)
    SetPedCombatAttributes(driverPed, 1424, true)

    TaskGoToEntity(driverPed, playerPed, -1, 2.0, 3.0, 1073741824, 0)

    while #(GetEntityCoords(driverPed) - GetEntityCoords(playerPed)) > 2.0 and not IsEntityDead(driverPed) do
        Wait(100)
    end

    if IsEntityDead(driverPed) then return end

    RequestAnimDict("anim@mp_player_intuppersalute")
    while not HasAnimDictLoaded("anim@mp_player_intuppersalute") do
        Wait(100)
    end

    TaskPlayAnim(driverPed, "anim@mp_player_intuppersalute", "idle_a", 8.0, -8.0, -1, 0, 0, false, false, false)

    Wait(2000)

    local plate = GetVehicleNumberPlateText(vehicle)

    TriggerEvent('vehiclekeys:client:SetOwner', plate)

    ClearPedTasks(driverPed)

    SetBlockingOfNonTemporaryEvents(driverPed, true)
    SetPedFleeAttributes(driverPed, 0, false)
    SetPedAsGroupMember(driverPed, GetPedGroupIndex(PlayerPedId()))

    TaskSmartFleePed(driverPed, playerPed, 100.0, -1, false, false)
    SetPedKeepTask(driverPed, true)

    SetVehicleDoorsLocked(vehicle, 1)
end


exports['qb-target']:AddGlobalVehicle({
    options = {
        {
            icon = "fas fa-car",
            label = "Borrow Vehicle",
            canInteract = function(entity, distance, data)
            local PlayerData = QBCore.Functions.GetPlayerData()

            if Config.Job.JobRequired == true then
                if not PlayerData or PlayerData.job.name ~= Config.Job.RequestedJob then
                    return false
                end
            end

            if Config.Job.ItemRequired == true then
                local item = QBCore.Functions.HasItem(Config.Job.RequestedItem)
                if not item then
                    return false
                end
            end

            if IsPedSittingInAnyVehicle(GetPlayerPed(-1))then
                return false
            end

            return CheckNpcStatus(entity)
            
            end,

            action = function(entity)
                BorrowVehicle(entity)
            end,
        },
    },
    distance = 2.5,
})
