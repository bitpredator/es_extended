exports('getSharedObject', function()
	return ESX
end)

if GetResourceState('ox_inventory') ~= 'missing' then
	Config.OxInventory = true
end

RegisterNetEvent('esx:getSharedObject', function()
	print(('[^1ERROR^7] Resource ^5%s^7 Used the ^5getSharedObject^7 Event, this event ^1no longer exists!^7 Visit https://bitpredator.github.io/bptdevelopment/docs/esx-tutorial/sharedevent for how to fix!'):format(GetInvokingResource))
end)