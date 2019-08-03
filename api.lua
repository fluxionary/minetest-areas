local hudHandlers = {}


areas.registered_on_adds = {}
areas.registered_on_removes = {}
areas.registered_on_moves = {}

function areas:registerOnAdd(func)
	table.insert(areas.registered_on_adds, func)
end

function areas:registerOnRemove(func)
	table.insert(areas.registered_on_removes, func)
end

function areas:registerOnMove(func)
	table.insert(areas.registered_on_moves, func)
end


--- Adds a function as a HUD handler, it will be able to add items to the Areas HUD element.
function areas:registerHudHandler(handler)
	table.insert(hudHandlers, handler)
end


function areas:getExternalHudEntries(pos)
	local areas = {}
	for _, func in pairs(hudHandlers) do
		func(pos, areas)
	end
	return areas
end

--- Returns a list of areas that include the provided position.
function areas:getAreasAtPos(pos)
	local res = {}

	if self.store then
		local a = self.store:get_areas_for_pos(pos, false, true)
		for store_id, store_area in pairs(a) do
			local id = tonumber(store_area.data)
			res[id] = self.areas[id]
		end
	else
		local px, py, pz = pos.x, pos.y, pos.z
		for id, area in pairs(self.areas) do
			local ap1, ap2 = area.pos1, area.pos2
			if
					(px >= ap1.x and px <= ap2.x) and
					(py >= ap1.y and py <= ap2.y) and
					(pz >= ap1.z and pz <= ap2.z) then
				res[id] = area
			end
		end
	end
	return res
end

--- Returns areas that intersect with the passed area.
function areas:getAreasIntersectingArea(pos1, pos2)
	local res = {}
	if self.store then
		local a = self.store:get_areas_in_area(pos1, pos2,
				true, false, true)
		for store_id, store_area in pairs(a) do
			local id = tonumber(store_area.data)
			res[id] = self.areas[id]
		end
	else
		self:sortPos(pos1, pos2)
		local p1x, p1y, p1z = pos1.x, pos1.y, pos1.z
		local p2x, p2y, p2z = pos2.x, pos2.y, pos2.z
		for id, area in pairs(self.areas) do
			local ap1, ap2 = area.pos1, area.pos2
			if
					(ap1.x <= p2x and ap2.x >= p1x) and
					(ap1.y <= p2y and ap2.y >= p1y) and
					(ap1.z <= p2z and ap2.z >= p1z) then
				-- Found an intersecting area.
				res[id] = area
			end
		end
	end
	return res
end

local registered_on_interact_checks = {}
function areas:register_on_interact_check(callback)
	table.insert(registered_on_interact_checks, callback)
end


-- Checks if the area is unprotected or owned by you
function areas:canInteract(pos, name)
	if minetest.check_player_privs(name, self.adminPrivs) then
		return true
	end

	for _, callback in ipairs(registered_on_interact_checks) do
		rv = callback(pos, name)
		if rv then
			return rv
		end
	end
end

-- Returns a table (list) of all players that own an area
function areas:getNodeOwners(pos)
	local owners = {}
	for _, area in pairs(self:getAreasAtPos(pos)) do
		table.insert(owners, area.owner)
	end
	return owners
end

local registered_on_intersection_checks = {}
function areas:register_on_intersection_check(callback)
	table.insert(registered_on_intersection_checks, callback)
end

--- Checks if the area intersects with an area that the player can't interact in.
-- Note that this fails and returns false when the specified area is fully
-- owned by the player, but with multiple protection zones, none of which
-- cover the entire checked area.
-- @param name (optional) Player name.  If not specified checks for any intersecting areas.
-- @param allow_open Whether open areas should be counted as if they didn't exist.
-- @return Boolean indicating whether the player can interact in that area.
-- @return Un-owned intersecting area ID, if found.
function areas:canInteractInArea(pos1, pos2, name, allow_open)
	if name and minetest.check_player_privs(name, self.adminPrivs) then
		return true
	end
	self:sortPos(pos1, pos2)

	local areas = self:getAreasIntersectingArea(pos1, pos2)
	for id, area in pairs(areas) do
		-- First check for a fully enclosing owned area.
		-- A little optimization: isAreaOwner isn't necessary
		-- here since we're iterating over all relevant areas.
		if area.owner == name and
				self:isSubarea(pos1, pos2, id) then
			return true
		end
	end

	for _, callback in ipairs(registered_on_intersection_checks) do
		rv, blocking_area = callback(pos1, pos2, name, allow_open)
	end

	-- There are no intersecting areas or they are only partially
	-- intersecting areas and they are all owned by the player.
	return true
end

------- TAGS api --------
areas.tags = {}

function areas:register_tag(tagname)
	areas.tags[tagname] = true
end

function areas:tag_area(area_id, tagname, value)
	local area = areas.areas[area_id]
	if not area then return false end
	if not areas.tags[tagname] then return false end
	if not area.tags then area.tags = {} end
	area.tags[tagname] = ((value or value == nil) and true) or false
	areas:save()
	return true
end

function areas:toggle_tag(area_id, tagname)
	local area = areas.areas[area_id]
	if not area then return false end
	if not areas.tags[tagname] then return false end
	if not area.tags then area.tags = {} end
	area.tags[tagname] = not area.tags[tagname]
	areas:save()
	return true
end


function areas:has_tag(area_id, tagname)
	local area = areas.areas[area_id]
	if not area then return false end
	if not areas.tags[tagname] then return false end
	if not areas.tags then return false end
	if area.tags[tagname] then return true else return false end
end


