local buffed_entities_to_extend = {}

-- returns the default buff amount per quality level in vanilla
local function get_quality_buff(quality_level)
	return 1 + quality_level * 0.3
end

local function add_to_description(type, prototype, localised_string)
	if prototype.localised_description and prototype.localised_description ~= '' then
		prototype.localised_description = {'', prototype.localised_description, '\n', localised_string}
		return
	end

	local place_result = prototype.place_result or prototype.placed_as_equipment_result
	if type == 'item' and place_result then
		for _, machine in pairs(data.raw) do
			machine = machine[place_result]
			if machine and machine.localised_description then
				prototype.localised_description = {
					'?',
					{'', machine.localised_description, '\n', localised_string},
					localised_string,
					machine.localised_description
				}
				return
			end
		end

		local entity_type = prototype.place_result and 'entity' or 'equipment'
		prototype.localised_description = {
			'?',
			{'', {entity_type .. '-description.' .. place_result}, '\n', localised_string},
			{'', {type .. '-description.' .. prototype.name},      '\n', localised_string},
			localised_string,
			{entity_type .. '-description.' .. place_result},
			{type .. '-description.' .. prototype.name}
		}
	else
		prototype.localised_description = {
			'?',
			{'',                                       {type .. '-description.' .. prototype.name}, '\n', localised_string},
			localised_string,
			{type .. '-description.' .. prototype.name}
		}
	end
end

local function add_quality_factoriopedia_info(entity, factoriopedia_info)
	local factoriopedia_description = entity.factoriopedia_description

	for _, factoriopedia_info in pairs(factoriopedia_info or {}) do
		local header, factoriopedia_function = unpack(factoriopedia_info)
		local localised_string = {'', '[font=default-semibold]', header, '[/font]'}
		for _, quality in pairs(data.raw.quality) do
			local quality_level = quality.level
			if quality.hidden then goto continue end

			local quality_buff = tostring(factoriopedia_function(entity, quality_level))
			table.insert(localised_string, {'', '\n[img=quality.' .. quality.name .. '] ', {'quality-name.' .. quality.name}, ': [font=default-semibold]', quality_buff, '[/font]'})
			::continue::
		end

		if factoriopedia_description then
			factoriopedia_description = {'', factoriopedia_description, '\n\n', localised_string}
		else
			factoriopedia_description = localised_string
		end
	end

	entity.factoriopedia_description = factoriopedia_description
end

local function make_effected_by_quality(entity, buff_function, quality_description_localised_keys, factoriopedia_info)
	if entity.hidden then return end
	if not entity.minable then return end
	if entity.created_effect then
		log('Entity ' .. entity.name .. ' already has a created_effect. Skipping quality buff.')
		return
	end

	local quality_description = {''}
	for _, localised_key in pairs(quality_description_localised_keys) do
		if table_size(quality_description) ~= 1 then table.insert(quality_description, '\n') end
		table.insert(quality_description, {'description.quality-diamond', localised_key})
	end
	add_to_description('entity', entity, quality_description)

	add_quality_factoriopedia_info(entity, factoriopedia_info)

	for _, quality in pairs(data.raw.quality) do
		local quality_level = quality.level
		if quality_level == 0 then goto continue end

		local buffed_entity = table.deepcopy(entity)
		buff_function(buffed_entity, quality_level)

		buffed_entity.hidden = true
		buffed_entity.hidden_in_factoriopedia = true
		buffed_entity.factoriopedia_alternative = entity.name
		buffed_entity.name = entity.name .. '-' .. quality.name
		buffed_entity.localised_name = entity.localised_name or {
			'?',
			{'entity-name.' .. entity.name},
			{'item-name.' .. entity.name}
		}

		if not entity.placeable_by then
			if entity.minable.result then
				buffed_entity.placeable_by = {item = entity.minable.result, count = entity.minable.count or 1}
			elseif entity.minable.results then
				local placable_by = {}
				for _, result in pairs(entity.minable.results) do
					table.insert(placable_by, {item = result.name, count = result.amount or 1})
				end
				buffed_entity.placeable_by = placable_by
			end
		end

		buffed_entity.fast_replaceable_group = entity.fast_replaceable_group or entity.name

		table.insert(buffed_entities_to_extend, buffed_entity)

		::continue::
	end

	entity.created_effect = {
		type = 'direct',
		action_delivery = {
			type = 'instant',
			source_effects = {
				type = 'script',
				effect_id = 'on_built_quality_rebalance'
			}
		}
	}
end

for _, chest_type in pairs {'container', 'logistic-container', 'linked-container'} do
	for _, chest in pairs(data.raw[chest_type]) do
		make_effected_by_quality(chest, function(entity, quality_level)
			entity.inventory_size = math.floor(entity.inventory_size * get_quality_buff(quality_level))
		end, {
			{'description.storage-size'}
		}, {
			{{'quality-tooltip.storage-size'}, function(entity, quality_level) return math.floor(entity.inventory_size * get_quality_buff(quality_level)) end}
		})
	end
end

for _, elevated_rail_type in pairs {'rail-support', 'rail-ramp'} do
	for _, elevated_rail in pairs(data.raw[elevated_rail_type]) do
		make_effected_by_quality(elevated_rail, function(entity, quality_level)
			entity.support_range = math.floor((entity.support_range or 15) * get_quality_buff(quality_level))
		end, {
			{'description.support-range'}
		}, {
			{{'quality-tooltip.support-range'}, function(entity, quality_level) return math.floor((entity.support_range or 15) * get_quality_buff(quality_level)) end}
		})
	end
end

--[[ this crashes factorio
for _, belt_type in pairs {'transport-belt', 'underground-belt', 'splitter', 'linked-belt', 'lane-splitter', 'loader-1x1', 'loader'} do
	for _, belt in pairs(data.raw[belt_type]) do
		make_effected_by_quality(belt, function(entity, quality_level)
			entity.speed = entity.speed + entity.speed * (quality_level + 1) / 5
		end, {
			{'description.belt-speed'}
		}, {
			{{'quality-tooltip.belt-speed'}, function(entity, quality_level) return entity.speed + entity.speed * (quality_level + 1) / 5 end}
		})
	end
end--]]

for _, agricultural_tower in pairs(data.raw['agricultural-tower']) do
	make_effected_by_quality(agricultural_tower, function(entity, quality_level)
		entity.radius = entity.radius + quality_level / 2

		local speed = entity.crane.speed
		speed.arm.turn_rate = (speed.arm.turn_rate or 0.01) * get_quality_buff(quality_level)
		speed.arm.extension_speed = (speed.arm.extension_speed or 0.05) * get_quality_buff(quality_level)
		speed.grappler.vertical_turn_rate = (speed.grappler.vertical_turn_rate or 0.01) * get_quality_buff(quality_level)
		speed.grappler.horizontal_turn_rate = (speed.grappler.horizontal_turn_rate or 0.01) * get_quality_buff(quality_level)
		speed.grappler.extension_speed = (speed.grappler.extension_speed or 0.01) * get_quality_buff(quality_level)
	end, {
		{'description.harvest-speed'},
		{'description.harvest-radius'}
	}, {
		{{'quality-tooltip.harvest-speed'}, function(entity, quality_level) return tostring(get_quality_buff(quality_level) * 100) .. '%' end},
		{{'quality-tooltip.harvest-radius'}, function(entity, quality_level)
			local growth_grid_tile_size = entity.growth_grid_tile_size or 3
			local new_radius = (entity.radius + quality_level / 2) * growth_grid_tile_size
			return new_radius - new_radius % growth_grid_tile_size
		end}
	})
end

data:extend(buffed_entities_to_extend)
