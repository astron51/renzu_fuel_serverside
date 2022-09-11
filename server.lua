ESX 					= nil
local CarFuelLevel 	= {}
local bReady 		= false
TriggerEvent(Config.ESX.ESXSHAREDOBJECT, function(obj) ESX = obj end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
	  	MySQL.ready(function()
			print("Renzu_Fuel_Modified : Fuel System Ready")
			bReady = true
		end)
		if Config.ServerSide then
			MySQL.Async.fetchAll('SELECT plate, vehicle FROM owned_vehicles', {}, function(data)
				for _,v in pairs(data) do
					local vehStat = json.decode(v.vehicle)
					table.insert(CarFuelLevel, {plate = v.plate, fuel = vehStat.fuelLevel})
				end
			end)
		end
	end
end)

ESX.RegisterServerCallback('renzu_fuel:GetServerFuelMaster', function(source, cb)
	cb(CarFuelLevel)
end)

ESX.RegisterServerCallback('renzu_fuel:GetJerryAmmo', function(src, cb)
	-- WEAPON_PETROLCAN
	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
	cb(weapon.metadata.ammo)
end)

RegisterNetEvent('renzu_fuel:JerryCanHandler')
AddEventHandler('renzu_fuel:JerryCanHandler', function(FuelLevel)
	-- WEAPON_PETROLCAN
	local weapon = exports.ox_inventory:GetCurrentWeapon(source)
	if weapon then
		weapon.metadata.ammo = FuelLevel
		exports.ox_inventory:SetDurability(source, weapon.slot, FuelLevel)
		exports.ox_inventory:SetMetadata(source, weapon.slot, weapon.metadata)
	end
end)

ESX.RegisterServerCallback('renzu_fuel:GetServerFuel', function(src, cb, plate)
	for i = 1, #CarFuelLevel do
		if CarFuelLevel[i].plate == plate then
			local vehInfo = {plate = CarFuelLevel[i].plate, fuel = CarFuelLevel[i].fuel}
			cb(vehInfo)
			break
		end
	end
end)

RegisterNetEvent('renzu_fuel:SetServerFuel')
AddEventHandler('renzu_fuel:SetServerFuel', function(plate, fuel)
	local found = false
	for i = 1, #CarFuelLevel do
		if CarFuelLevel[i].plate == plate then 
			found = true
			if fuel ~= CarFuelLevel[i].fuel then
				table.remove(CarFuelLevel, i)
				table.insert(CarFuelLevel, {plate = plate, fuel = fuel})
			end
			break 
		end
	end
	if not found then
		table.insert(CarFuelLevel, {plate = plate, fuel = fuel})
	end
end)

RegisterNetEvent('renzu_fuel:SetDBFuelLevel')
AddEventHandler('renzu_fuel:SetDBFuelLevel', function(plate, fuel)
	MySQL.scalar('SELECT vehicle FROM owned_vehicles WHERE plate = ?', { plate }, function(query)
		local data = json.decode(query)
		data.fuelLevel = fuel
		MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', { json.encode(data) , plate}, function(affectedRows)
			if affectedRows then
				print(plate .. " fuel level updated")
			end
		end)
		TriggerEvent('renzu_fuel:SetServerFuel', plate, fuel)
	end)
end)

RegisterServerEvent("renzu_fuel:payfuel")
AddEventHandler("renzu_fuel:payfuel",function(plate, price, jeryycan, vehicle, fuel, fuel2, fuel3)
	local source = source
	local output = {}
	output = {
		['price'] = Config.stock.default_price,
	}
	local xPlayer = ESX.GetPlayerFromId(source)
	if price > 0 then
		local amount = 0
		money = xPlayer.getMoney()
		if money >= price then
			if jeryycan then
			
				local TotalPetrolCan = exports.ox_inventory:GetItem(source, 'WEAPON_PETROLCAN', nil, true)
				exports.ox_inventory:RemoveItem(source, 'WEAPON_PETROLCAN', TotalPetrolCan)
				exports.ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1, nil, nil, function(success, reason)
					if success then
						xPlayer.removeMoney(price)
					else
						TriggerClientEvent("renzu_fuel:Notify",source,"Inventory is Full or something.")
					end
				end)
			else
				amount = math.floor(price/output.price)
				fuel = math.floor(fuel/output.price)
				TriggerClientEvent('renzu_fuel:syncfuel', -1, vehicle, fuel)
				if Config.ServerSide then
					TriggerEvent('renzu_fuel:SetDBFuelLevel', plate, (fuel3 + fuel))
				end
				TriggerClientEvent("renzu_fuel:Notify",source,"Paid <b>$"..price.." </b> in "..amount.." liters.")
				xPlayer.removeMoney(price)
			end
		else
			TriggerClientEvent('renzu_fuel:insuficiente', source, vehicle, fuel2)
			TriggerClientEvent("renzu_fuel:Notify",source,"Insuficient money.")
		end
	end
end)

Citizen.CreateThread(function()
	if Config.ServerSide then
		while true do
			if bReady then 
				print('Renzu_Fuel : Synchronizing Fuel Level in Database')
				for i = 1, #CarFuelLevel do
					MySQL.scalar('SELECT vehicle FROM owned_vehicles WHERE plate = ?', { CarFuelLevel[i].plate }, function(query)
						local data = json.decode(query)
						data.fuelLevel = CarFuelLevel[i].fuel
						MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', { json.encode(data) , CarFuelLevel[i].plate}, function(affectedRows)
							if affectedRows then
								print(CarFuelLevel[i].plate .. " Fuel Level : " .. CarFuelLevel[i].fuel)
							end
						end)
						TriggerEvent('renzu_fuel:SetServerFuel', plate, fuel)
					end)
				end
				print('Task Completed')
			end
			Citizen.Wait(60000 * Config.ServerSideInterval)
		end
	end
end)