local open = "open"

areas:register_tag(open)

minetest.register_chatcommand("area_open", {
	params = "<ID>",
	description = "Toggle an area open (anyone can interact) or closed",
	func = function(name, param)
		local area_id = tonumber(param)
		if not area_id then
			return false, "Invalid usage, see /help area_open."
		elseif not areas.areas[area_id] then
			return false, "Area " .. area_id .. " does not exist."
		elseif not areas:isAreaOwner(area_id, name) then
			return false, "Area " .. area_id .. " is not owned by you."
		end
        areas:toggle_tag(area_id, open)
        local status = areas:has_tag(area_id, open)
		return true, ("Area %s."):format(status and "opened" or "closed")
	end
})

areas:register_on_interact_check(function(pos, name)
    local owned = false
	for area_id, area in pairs(areas:getAreasAtPos(pos)) do
		if area.owner == name or areas:has_tag(area_id, open) then
			return true
		else
			owned = true
            break
		end
	end
	return not owned
end)

areas:register_on_intersection_check(function(pos1, pos2, name, allow_open)
	-- Intersecting non-owned area ID, if found.
    local blocking_area

	local areas = self:getAreasIntersectingArea(pos1, pos2)
    for area_id, area in pairs(areas) do
        -- check for intersecting non-owned (blocking) areas.
        -- The area blocks if the area is closed or open areas aren't
        -- acceptable to the caller, and the area isn't owned.
        if (
                not (allow_open and areas:has_tag(area_id, open)) and
                (not name or not self:isAreaOwner(area_id, name))
        ) then
            blocking_area = area_id
            break
        end
    end

	if blocking_area then
		return false, blocking_area
	end

    return true
end)
