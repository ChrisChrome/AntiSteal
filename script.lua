
-- SETTINGS --

-- GLOBALS --
message_strings = {
	usage_antisteal = "?as [status/on/off]",
	usage_lock = "?l [vehicle_id]",
	usage_unlock = "?u [vehicle_id]",
	status_format = "%d: %s",
	bad_vid = "Vehicle ID not found",
	not_owner = "You do not own this vehicle",
	locked_vehicles = "%d vehicles have been LOCKED",
	unlocked_vehicles = "%d vehicles have been UNLOCKED",
	locked_vehicle = "Vehicle %d has been LOCKED",
	unlocked_vehicle = "Vehicle %d has been UNLOCKED",
	cleanup = "Cleaned up %d vehicles",
	despawn = "Despawned vehicle %d"
}
announce_title = "[Anti-Steal]"
steam_ids = {}

-- CALLBACKS --
function onCreate(is_world_create)
	if g_savedata["user_vehicles"] == nil then g_savedata["user_vehicles"] = {} end
	if g_savedata["locked_vehicles"] == nil then g_savedata["locked_vehicles"] = {} end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	-- Only track user spawned vehicles
	if peer_id ~= -1 then
		local p = {}
		for i,e in pairs(server.getPlayers()) do
			if e.id == peer_id then
				p = e
			end
		end
		trackVehicle(vehicle_id, peer_id)
		lockVehicle(peer_id, vehicle_id)
		server.setVehicleTooltip(vehicle_id, "Name: "..server.getVehicleName(vehicle_id).."\nID: "..tostring(vehicle_id).."\nOwner: "..("..p.id..")".."..p.name)
		--server.setVehicleTooltip(vehicle_id, "ID: "..tostring(vehicle_id))
	end
end

function onVehicleDespawn(vehicle_id, peer_id)
	untrackVehicle(vehicle_id)
end

function onPlayerJoin(steam_id, name, peer_id, admin, auth)
	steam_ids[peer_id] = tostring(steam_id)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
	cleanup(peer_id)
end

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, ...)
	command = string.lower(command)
	local args = table.pack(...)
	if (command == "?d") or (command == "?despawn") then
		targ_vid = tonumber(args[1])
		if targ_vid == nil then
			server.announce("[Error]", "Please provide a valid vehicle ID", user_peer_id)
			return
		end
		if is_admin then
			server.despawnVehicle(targ_vid, true)
			untrackVehicle(targ_vid)
			server.notify(user_peer_id, "Admin Despawn", string.format(message_strings["despawn"], targ_vid), 1)
			return
		end
		despawn(user_peer_id, targ_vid)
	end
	if (command == "?c") or (command == "?clear") or (command == "?clean") or (command == "?cleanup") or (command == "?clr") then
		if args[1] and is_admin then
			targ_pid = tonumber(args[1])
			if targ_pid == nil then
				server.announce("[Error]", "Please provide a valid peer ID", user_peer_id)
				return
			end
			cleanup(targ_pid)
			server.notify(requester, "Admin Cleanup", string.format(message_strings["cleanup"], count), 1)
			return
		end
		cleanup(user_peer_id)
	end
	if (command == "?antisteal") or (command == "?as") then
		if args[1] == nil then
			server.announce(announce_title, message_strings["usage_antisteal"], user_peer_id)
		elseif args[1] == "status" then
			for vid, steam_id in pairs(g_savedata["user_vehicles"]) do
				if steam_ids[user_peer_id] == steam_id then
					local locked = false
					if g_savedata["locked_vehicles"][vid] ~= nil then
						locked = true
					end
					if locked then
						server.announce(announce_title, string.format(message_strings["status_format"], vid, "Locked"), user_peer_id)
					else
						server.announce(announce_title, string.format(message_strings["status_format"], vid, "Unlocked"), user_peer_id)
					end
				end
			end
		elseif args[1] == "on" then
			lockAllVehicles(user_peer_id)
		elseif args[1] == "off" then
			unlockAllVehicles(user_peer_id)
		end
	elseif (command == "?unlock") or (command == "?u") then
		if args[1] == nil then
			server.announce(announce_title, message_strings["usage_unlock"], user_peer_id)
		else
			local vid = tonumber(args[1], 10)
			if vid == nil then 
				server.announce(announce_title, message_strings["bad_vid"], user_peer_id)
				return
			end
			unlockVehicle(user_peer_id, vid)
		end
	elseif (command == "?lock") or (command  == "?l") then
		if args[1] == nil then
			server.announce(announce_title, message_strings["usage_lock"], user_peer_id)
		else
			local vid = tonumber(args[1], 10)
			if vid == nil then 
				server.announce(announce_title, message_strings["bad_vid"], user_peer_id)
				return
			end
			lockVehicle(user_peer_id, vid)
		end
	end
end

-- LOGIC --
function trackVehicle(vehicle_id, peer_id)
	g_savedata["user_vehicles"][vehicle_id] = steam_ids[peer_id]
end

function untrackVehicle(vehicle_id)
	g_savedata["user_vehicles"][vehicle_id] = nil
end

function despawn(requester, vid)
	if g_savedata["user_vehicles"][vid] == steam_ids[requester] then
		server.despawnVehicle(vehicle_id, true)
		untrackVehicle(vehicle_id)
		server.notify(requester, "Despawn", string.format(message_strings["despawn"], vid), 1)
	end
end

function cleanup(requester)
	local count = 0
	for vehicle_id, steam_id in pairs(g_savedata["user_vehicles"]) do
		if steam_id == steam_ids[requester] then
			server.despawnVehicle(vehicle_id, true)
			untrackVehicle(vehicle_id)
			count = count + 1
		end
	end
	server.notify(requester, "Cleanup", string.format(message_strings["cleanup"], count), 1)
end

function lockAllVehicles(requester)
	local count = 0
	for vehicle_id, steam_id in pairs(g_savedata["user_vehicles"]) do
		if steam_id == steam_ids[requester] then
			server.setVehicleEditable(vehicle_id, false)
			g_savedata["locked_vehicles"][vehicle_id] = steam_id
			count = count + 1
		end
	end
	server.notify(requester, "Anti-Steal", string.format(message_strings["locked_vehicles"], count), 1)
end

function unlockAllVehicles(requester)
	local count = 0
	for vehicle_id, steam_id in pairs(g_savedata["user_vehicles"]) do
		if steam_id == steam_ids[requester] then
			server.setVehicleEditable(vehicle_id, true)
			g_savedata["locked_vehicles"][vehicle_id] = nil
			count = count + 1
		end
	end
	server.notify(requester, "Anti-Steal", string.format(message_strings["unlocked_vehicles"], count), 1)
end

function lockVehicle(requester, vehicle_id)
	local steam_id = g_savedata["user_vehicles"][vehicle_id]
	if steam_id == steam_ids[requester] then
		server.setVehicleEditable(vehicle_id, false)
		g_savedata["locked_vehicles"][vehicle_id] = steam_id
		server.notify(requester, "Anti-Steal", string.format(message_strings["locked_vehicle"], vehicle_id), 1)
	else
		server.announce(announce_title, message_strings["not_owner"], requester)
	end
end

function unlockVehicle(requester, vehicle_id)
	local steam_id = g_savedata["user_vehicles"][vehicle_id]
	if steam_id == steam_ids[requester] then
		server.setVehicleEditable(vehicle_id, true)
		g_savedata["locked_vehicles"][vehicle_id] = nil
		server.notify(requester, "Anti-Steal", string.format(message_strings["unlocked_vehicle"], vehicle_id), 1)
	else
		server.announce(announce_title, message_strings["not_owner"], requester)
	end
end