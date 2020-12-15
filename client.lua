local EntityInHands

RegisterNetEvent('carry:toggle')

local entityEnumerator = {
	__gc = function(enum)
		if enum.destructor and enum.handle then
			enum.destructor(enum.handle)
		end
		enum.destructor = nil
		enum.handle = nil
	end
}

function EnumerateEntities(firstFunc, nextFunc, endFunc)
	return coroutine.wrap(function()
		local iter, id = firstFunc()

		if not id or id == 0 then
			endFunc(iter)
			return
		end

		local enum = {handle = iter, destructor = endFunc}
		setmetatable(enum, entityEnumerator)

		local next = true
		repeat
			coroutine.yield(id)
			next, id = nextFunc(iter)
		until not next

		enum.destructor, enum.handle = nil, nil
		endFunc(iter)
	end)
end

function EnumerateObjects()
	return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

function EnumeratePeds()
	return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

function StartCarrying(entity)
	AttachEntityToEntity(entity, PlayerPedId(), 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, true, false, 0, true, false, false)
end

function GetClosestNetworkedEntity()
	local x1, y1, z1 = table.unpack(GetEntityCoords(PlayerPedId()))

	local minDistance
	local closestEntity

	for object in EnumerateObjects() do
		if NetworkGetEntityIsNetworked(object) then
			local x2, y2, z2 = table.unpack(GetEntityCoords(object))
			local distance = GetDistanceBetweenCoords(x1, y1, z1, x2, y2, z2, true)

			if distance < Config.MaxDistance and (not minDistance or distance < minDistance) then
				minDistance = distance
				closestEntity = object
			end
		end
	end

	for ped in EnumeratePeds() do
		if ped ~= PlayerPedId() and NetworkGetEntityIsNetworked(ped) then
			local x2, y2, z2 = table.unpack(GetEntityCoords(ped))
			local distance = GetDistanceBetweenCoords(x1, y1, z1, x2, y2, z2, true)

			if distance < Config.MaxDistance and (not minDistance or distance < minDistance) then
				minDistance = distance
				closestEntity = ped
			end
		end
	end

	return closestEntity
end

function PlayPickUpAnimation()
	TaskPlayAnim(PlayerPedId(), Config.PickUpAnimDict, Config.PickUpAnimName, 1.0, 1.0, -1, 0, 0, false, false, false, '', false)
end

function StartCarryingClosestEntity()
	local entity = GetClosestNetworkedEntity()

	if entity then
		PlayPickUpAnimation()

		Wait(750)

		StartCarrying(entity)

		return entity
	else
		return nil
	end
end

function PlayPutDownAnimation()
	TaskPlayAnim(PlayerPedId(), Config.PutDownAnimDict, Config.PutDownAnimName, 1.0, 1.0, -1, 0, 0, false, false, false, '', false)
end

function StopCarrying(entity)
	ClearPedTasks(PlayerPedId())

	PlayPutDownAnimation()

	Wait(500)

	DetachEntity(entity, false, true)
end

function PlayCarryingAnimation()
	TaskPlayAnim(PlayerPedId(), Config.CarryAnimDict, Config.CarryAnimName, speed, speed, -1, 25, 0, false, false, false, '', false)
end

function ToggleCarry()
	if EntityInHands then
		local entity = EntityInHands
		EntityInHands = nil
		StopCarrying(entity)
	else
		EntityInHands = StartCarryingClosestEntity()
	end
end

RegisterCommand('carry', function(source, args, raw)
	ToggleCarry()
end)

AddEventHandler('carry:toggle', ToggleCarry)

CreateThread(function()
	while true do
		Wait(0)

		if EntityInHands and not IsEntityPlayingAnim(PlayerPedId(), Config.CarryAnimDict, Config.CarryAnimName, 25) then
			PlayCarryingAnimation()
		end
	end
end)