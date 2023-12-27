local pickups = {}
CreateThread(function()
	while not Config.Multichar do
		Wait(0)
		if NetworkIsPlayerActive(PlayerId()) then
			exports.spawnmanager:setAutoSpawn(false)
			DoScreenFadeOut(0)
			Wait(500)
			TriggerServerEvent('esx:onPlayerJoined')
			break
		end
	end
end)

RegisterNetEvent("esx:requestModel", function(model)
    ESX.Streaming.RequestModel(model)
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer, isNew, skin)
	ESX.PlayerData = xPlayer

	if Config.Multichar then
		Wait(3000)
	else
		exports.spawnmanager:spawnPlayer({
			x = ESX.PlayerData.coords.x,
			y = ESX.PlayerData.coords.y,
			z = ESX.PlayerData.coords.z + 0.25,
			heading = ESX.PlayerData.coords.heading,
			model = `mp_m_freemode_01`,
			skipFade = false
		}, function()
			TriggerServerEvent('esx:onPlayerSpawn')
			TriggerEvent('esx:onPlayerSpawn')
			TriggerEvent('esx:restoreLoadout')

			if isNew then
				TriggerEvent('skinchanger:loadDefaultModel', skin.sex == 0)
			elseif skin then
				TriggerEvent('skinchanger:loadSkin', skin)
			end

			TriggerEvent('esx:loadingScreenOff')
			ShutdownLoadingScreen()
			ShutdownLoadingScreenNui()
		end)
	end

	ESX.PlayerLoaded = true

	while ESX.PlayerData.ped == nil do Wait(20) end

	if Config.EnablePVP then
		SetCanAttackFriendly(ESX.PlayerData.ped, true, false)
		NetworkSetFriendlyFireOption(true)
	end

	local playerId = PlayerId()

	-- RemoveHudComponents
	for i=1, #(Config.RemoveHudComponents) do
		if Config.RemoveHudComponents[i] then
			SetHudComponentPosition(i, 999999.0, 999999.0)
		end
	end

	-- DisableNPCDrops
	if Config.DisableNPCDrops then
		local weaponPickups = {`PICKUP_WEAPON_CARBINERIFLE`, `PICKUP_WEAPON_PISTOL`, `PICKUP_WEAPON_PUMPSHOTGUN`}
		for i = 1, #weaponPickups do
			ToggleUsePickupsForPlayer(playerId, weaponPickups[i], false)
		end
	end

	-- DisableVehicleRewards
	if Config.DisableVehicleRewards then
		AddEventHandler('esx:enteredVehicle', function(vehicle)
			if GetVehicleClass(vehicle) == 18 then
				CreateThread(function()
					while true do
						DisablePlayerVehicleRewards(playerId)
						if not IsPedInAnyVehicle(ESX.PlayerData.ped, false) then
							break
						end

						Wait(0)
					end
				end)
			end
		end)
	end

	if Config.DisableHealthRegeneration or Config.DisableWeaponWheel or Config.DisableAimAssist then
		CreateThread(function()
			while true do
				if Config.DisableHealthRegeneration then
					SetPlayerHealthRechargeMultiplier(playerId, 0.0)
				end

				if Config.DisableWeaponWheel then
					BlockWeaponWheelThisFrame()
					DisableControlAction(0, 37, true)
				end

				if Config.DisableDisplayAmmo then
					DisplayAmmoThisFrame(false)
				end

				if Config.DisableAimAssist then
					if IsPedArmed(ESX.PlayerData.ped, 4) then
						SetPlayerLockonRangeOverride(playerId, 2.0)
					end
				end

				Wait(0)
			end
		end)
	end
	SetDefaultVehicleNumberPlateTextPattern(-1, Config.CustomAIPlates)
	StartServerSyncLoops()
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
	ESX.PlayerLoaded = false
end)

RegisterNetEvent('esx:setMaxWeight')
AddEventHandler('esx:setMaxWeight', function(newMaxWeight) ESX.SetPlayerData("maxWeight", newMaxWeight) end)

local function onPlayerSpawn()
	ESX.SetPlayerData('ped', PlayerPedId())
	ESX.SetPlayerData('dead', false)
end

AddEventHandler('playerSpawned', onPlayerSpawn)
AddEventHandler('esx:onPlayerSpawn', onPlayerSpawn)

AddEventHandler('esx:onPlayerDeath', function()
	ESX.SetPlayerData('ped', PlayerPedId())
	ESX.SetPlayerData('dead', true)
end)

AddEventHandler('skinchanger:modelLoaded', function()
	while not ESX.PlayerLoaded do
		Wait(100)
	end
	TriggerEvent('esx:restoreLoadout')
end)

AddEventHandler('esx:restoreLoadout', function()
	ESX.SetPlayerData('ped', PlayerPedId())

	if not Config.OxInventory then
		local ammoTypes = {}
		RemoveAllPedWeapons(ESX.PlayerData.ped, true)

		for _,v in ipairs(ESX.PlayerData.loadout) do
			local weaponName = v.name
			local weaponHash = joaat(weaponName)

			GiveWeaponToPed(ESX.PlayerData.ped, weaponHash, 0, false, false)
			SetPedWeaponTintIndex(ESX.PlayerData.ped, weaponHash, v.tintIndex)

			local ammoType = GetPedAmmoTypeFromWeapon(ESX.PlayerData.ped, weaponHash)

			for _,v2 in ipairs(v.components) do
				local componentHash = ESX.GetWeaponComponent(weaponName, v2).hash
				GiveWeaponComponentToPed(ESX.PlayerData.ped, weaponHash, componentHash)
			end

			if not ammoTypes[ammoType] then
				AddAmmoToPed(ESX.PlayerData.ped, weaponHash, v.ammo)
				ammoTypes[ammoType] = true
			end
		end
	end
end)

AddStateBagChangeHandler('VehicleProperties', nil, function(_, _, value)
	if value then
			Wait(0)
			local NetId = value.NetId
			local Vehicle = NetworkGetEntityFromNetworkId(NetId)
            local Tries = 0
			while Vehicle == 0 do
				Vehicle = NetworkGetEntityFromNetworkId(NetId)
				Wait(100)
				Tries = Tries + 1
				if Tries > 300 then
					break
				end
			end
			if NetworkGetEntityOwner(Vehicle) == PlayerId() then
				ESX.Game.SetVehicleProperties(Vehicle, value)
			end
	end
end)

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
	for i=1, #(ESX.PlayerData.accounts) do
		if ESX.PlayerData.accounts[i].name == account.name then
			ESX.PlayerData.accounts[i] = account
			break
		end
	end

	ESX.SetPlayerData('accounts', ESX.PlayerData.accounts)
end)

if not Config.OxInventory then
	RegisterNetEvent('esx:addInventoryItem')
	AddEventHandler('esx:addInventoryItem', function(item, count, showNotification)
		for k,v in ipairs(ESX.PlayerData.inventory) do
			if v.name == item then
				ESX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
				ESX.PlayerData.inventory[k].count = count
				break
			end
		end

		if showNotification then
			ESX.UI.ShowInventoryItemNotification(true, item, count)
		end

		if ESX.UI.Menu.IsOpen('default', 'es_extended') then
			ESX.ShowInventory()
		end
	end)

	RegisterNetEvent('esx:removeInventoryItem')
	AddEventHandler('esx:removeInventoryItem', function(item, count, showNotification)
		for k,v in ipairs(ESX.PlayerData.inventory) do
			if v.name == item then
				ESX.UI.ShowInventoryItemNotification(false, v.label, v.count - count)
				ESX.PlayerData.inventory[k].count = count
				break
			end
		end

		if showNotification then
			ESX.UI.ShowInventoryItemNotification(false, item, count)
		end

		if ESX.UI.Menu.IsOpen('default', 'es_extended') then
			ESX.ShowInventory()
		end
	end)

	RegisterNetEvent('esx:addWeapon')
	AddEventHandler('esx:addWeapon', function()
		print("[^1ERROR^7] event ^5'esx:addWeapon'^7 Has Been Removed. Please use ^5xPlayer.addWeapon^7 Instead!")
	end)

	RegisterNetEvent('esx:addWeaponComponent')
	AddEventHandler('esx:addWeaponComponent', function()
		print("[^1ERROR^7] event ^5'esx:addWeaponComponent'^7 Has Been Removed. Please use ^5xPlayer.addWeaponComponent^7 Instead!")
	end)

	RegisterNetEvent('esx:setWeaponAmmo')
	AddEventHandler('esx:setWeaponAmmo', function()
		print("[^1ERROR^7] event ^5'esx:setWeaponAmmo'^7 Has Been Removed. Please use ^5xPlayer.addWeaponAmmo^7 Instead!")
	end)

	RegisterNetEvent('esx:setWeaponTint')
	AddEventHandler('esx:setWeaponTint', function(weapon, weaponTintIndex)
		SetPedWeaponTintIndex(ESX.PlayerData.ped, joaat(weapon), weaponTintIndex)
	end)

	RegisterNetEvent('esx:removeWeapon')
	AddEventHandler('esx:removeWeapon', function(weapon)
		RemoveWeaponFromPed(ESX.PlayerData.ped, joaat(weapon))
		SetPedAmmo(ESX.PlayerData.ped, joaat(weapon), 0)
	end)

	RegisterNetEvent('esx:removeWeaponComponent')
	AddEventHandler('esx:removeWeaponComponent', function(weapon, weaponComponent)
		local componentHash = ESX.GetWeaponComponent(weapon, weaponComponent).hash
		RemoveWeaponComponentFromPed(ESX.PlayerData.ped, joaat(weapon), componentHash)
	end)
end

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(Job)
	ESX.SetPlayerData('job', Job)
end)

if not Config.OxInventory then
	RegisterNetEvent('esx:createPickup')
	AddEventHandler('esx:createPickup', function(pickupId, label, coords, type, name, components, tintIndex)
		local function setObjectProperties(object)
			SetEntityAsMissionEntity(object, true, false)
			PlaceObjectOnGroundProperly(object)
			FreezeEntityPosition(object, true)
			SetEntityCollision(object, false, true)

			pickups[pickupId] = {
				obj = object,
				label = label,
				inRange = false,
				coords = vector3(coords.x, coords.y, coords.z)
			}
		end

		if type == 'item_weapon' then
			local weaponHash = joaat(name)
			ESX.Streaming.RequestWeaponAsset(weaponHash)
			local pickupObject = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
			SetWeaponObjectTintIndex(pickupObject, tintIndex)

			for _,v in ipairs(components) do
				local component = ESX.GetWeaponComponent(name, v)
				GiveWeaponComponentToWeaponObject(pickupObject, component.hash)
			end

			setObjectProperties(pickupObject)
		else
			ESX.Game.SpawnLocalObject('prop_money_bag_01', coords, setObjectProperties)
		end
	end)

	RegisterNetEvent('esx:createMissingPickups')
	AddEventHandler('esx:createMissingPickups', function(missingPickups)
		for pickupId, pickup in pairs(missingPickups) do
			TriggerEvent('esx:createPickup', pickupId, pickup.label, pickup.coords - vector3(0,0, 1.0), pickup.type, pickup.name, pickup.components, pickup.tintIndex)
		end
	end)
end

RegisterNetEvent('esx:registerSuggestions')
AddEventHandler('esx:registerSuggestions', function(registeredCommands)
	for name,command in pairs(registeredCommands) do
		if command.suggestion then
			TriggerEvent('chat:addSuggestion', ('/%s'):format(name), command.suggestion.help, command.suggestion.arguments)
		end
	end
end)

if not Config.OxInventory then
	RegisterNetEvent('esx:removePickup')
	AddEventHandler('esx:removePickup', function(pickupId)
		if pickups[pickupId] and pickups[pickupId].obj then
			ESX.Game.DeleteObject(pickups[pickupId].obj)
			pickups[pickupId] = nil
		end
	end)
end

function StartServerSyncLoops()
	if not Config.OxInventory then
			-- keep track of ammo

			CreateThread(function()
					local currentWeapon = {Ammo = 0}
					while ESX.PlayerLoaded do
						local sleep = 1500
						if GetSelectedPedWeapon(ESX.PlayerData.ped) ~= -1569615261 then
							sleep = 1000
							local _, weaponHash = GetCurrentPedWeapon(ESX.PlayerData.ped, true)
							local weapon = ESX.GetWeaponFromHash(weaponHash)
							if weapon then
								local ammoCount = GetAmmoInPedWeapon(ESX.PlayerData.ped, weaponHash)
								if weapon.name ~= currentWeapon.name then
									currentWeapon.Ammo = ammoCount
									currentWeapon.name = weapon.name
								else
									if ammoCount ~= currentWeapon.Ammo then
										currentWeapon.Ammo = ammoCount
										TriggerServerEvent('esx:updateWeaponAmmo', weapon.name, ammoCount)
									end
								end
							end
						end
					Wait(sleep)
				end
			end)
	end
end

-- disable wanted level
if not Config.EnableWantedLevel then
	ClearPlayerWantedLevel(PlayerId())
	SetMaxWantedLevel(0)
end

----- Admin commnads from esx_adminplus
RegisterNetEvent("esx:tpm")
AddEventHandler("esx:tpm", function()
	local GetEntityCoords = GetEntityCoords
	local GetGroundZFor_3dCoord = GetGroundZFor_3dCoord
	local GetFirstBlipInfoId = GetFirstBlipInfoId
	local DoesBlipExist = DoesBlipExist
	local DoScreenFadeOut = DoScreenFadeOut
	local GetBlipInfoIdCoord = GetBlipInfoIdCoord
	local GetVehiclePedIsIn = GetVehiclePedIsIn

	ESX.TriggerServerCallback("esx:isUserAdmin", function(admin)
		if admin then
			local blipMarker = GetFirstBlipInfoId(8)
			if not DoesBlipExist(blipMarker) then
			 ESX.ShowNotification(_U('nowaipoint'), true, false, 140)
			 return 'marker'
			end

			-- Fade screen to hide how clients get teleported.
			DoScreenFadeOut(650)
			while not IsScreenFadedOut() do
					Wait(0)
			end

			local ped, coords = ESX.PlayerData.ped, GetBlipInfoIdCoord(blipMarker)
			local vehicle = GetVehiclePedIsIn(ped, false)
			local oldCoords = GetEntityCoords(ped)

			-- Unpack coords instead of having to unpack them while iterating.
			-- 825.0 seems to be the max a player can reach while 0.0 being the lowest.
			local x, y, groundZ, Z_START = coords['x'], coords['y'], 850.0, 950.0
			local found = false
			if vehicle > 0 then
				FreezeEntityPosition(vehicle, true)
			else
				FreezeEntityPosition(ped, true)
			end

			for i = Z_START, 0, -25.0 do
					local z = i
					if (i % 2) ~= 0 then
						z = Z_START - i
					end

					NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
					local curTime = GetGameTimer()
					while IsNetworkLoadingScene() do
						if GetGameTimer() - curTime > 1000 then
						break
					end
					Wait(0)
					end
					NewLoadSceneStop()
					SetPedCoordsKeepVehicle(ped, x, y, z)

					while not HasCollisionLoadedAroundEntity(ped) do
						RequestCollisionAtCoord(x, y, z)
						if GetGameTimer() - curTime > 1000 then
							break
						end
						Wait(0)
					end

					-- Get ground coord. As mentioned in the natives, this only works if the client is in render distance.
					found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
					if found then
						Wait(0)
						SetPedCoordsKeepVehicle(ped, x, y, groundZ)
						break
					end
					Wait(0)
			end

			-- Remove black screen once the loop has ended.
			DoScreenFadeIn(650)
			if vehicle > 0 then
				FreezeEntityPosition(vehicle, false)
			else
				FreezeEntityPosition(ped, false)
			end

			if not found then
				-- If we can't find the coords, set the coords to the old ones.
				-- We don't unpack them before since they aren't in a loop and only called once.
				SetPedCoordsKeepVehicle(ped, oldCoords['x'], oldCoords['y'], oldCoords['z'] - 1.0)
				ESX.ShowNotification(_U('tpm_success'), true, false, 140)
			end

			-- If Z coord was found, set coords in found coords.
			SetPedCoordsKeepVehicle(ped, x, y, groundZ)
			ESX.ShowNotification(_U('tpm_success'), true, false, 140)
		end
	end)
end)

RegisterNetEvent("esx:repairPedVehicle")
AddEventHandler("esx:repairPedVehicle", function()
	local GetVehiclePedIsIn = GetVehiclePedIsIn

	ESX.TriggerServerCallback("esx:isUserAdmin", function(admin)
		if not admin then
			return
		end
		local ped = ESX.PlayerData.ped
		if IsPedInAnyVehicle(ped, false) then
			local vehicle = GetVehiclePedIsIn(ped, false)
			SetVehicleEngineHealth(vehicle, 1000)
			SetVehicleEngineOn(vehicle, true, true)
			SetVehicleFixed(vehicle)
			SetVehicleDirtLevel(vehicle, 0)
			ESX.ShowNotification(_U('command_repair_success'), true, false, 140)
		else
			ESX.ShowNotification(_U('not_in_vehicle'), true, false, 140)
		end
	end)
end)

RegisterNetEvent("esx:freezePlayer")
AddEventHandler("esx:freezePlayer", function(input)
    local player = PlayerId()
    if input == 'freeze' then
        SetEntityCollision(ESX.PlayerData.ped, false)
        FreezeEntityPosition(ESX.PlayerData.ped, true)
        SetPlayerInvincible(player, true)
    elseif input == 'unfreeze' then
        SetEntityCollision(ESX.PlayerData.ped, true)
	    FreezeEntityPosition(ESX.PlayerData.ped, false)
        SetPlayerInvincible(player, false)
    end
end)

RegisterNetEvent("esx:GetVehicleType", function(Model, Request)
	local ReturnedType = "automobile"
	local IsValidModel = IsModelInCdimage(Model)
	if IsValidModel == true or IsValidModel == 1 then
		local VehicleType = GetVehicleClassFromName(Model)

		if VehicleType == 15 then
			ReturnedType = "heli"
		elseif VehicleType == 16 then
			ReturnedType = "plane"
		elseif VehicleType == 14 then
			ReturnedType = "boat"
		elseif VehicleType == 11 then
			ReturnedType = "trailer"
		elseif VehicleType == 21 then
			ReturnedType = "train"
		elseif VehicleType == 13 or VehicleType == 8 then
			ReturnedType = "bike"
		end
		if Model == `submersible` or Model == `submersible2` then
			ReturnedType = "submarine"
		end
	else
		ReturnedType = false
	end
	TriggerServerEvent("esx:ReturnVehicleType", ReturnedType, Request)
end)

local DoNotUse = {
	'essentialmode',
	'es_admin2',
	'basic-gamemode',
	'mapmanager',
	'fivem-map-skater',
	'fivem-map-hipster',
	'qb-core',
	'default_spawnpoint',
	'ox_core',
}

for i=1, #DoNotUse do
	if GetResourceState(DoNotUse[i]) == 'started' or GetResourceState(DoNotUse[i]) == 'starting' then
		print("[^1ERROR^7] YOU ARE USING A RESOURCE THAT WILL BREAK ^1ESX^7, PLEASE REMOVE ^5"..DoNotUse[i].."^7")
	end
end