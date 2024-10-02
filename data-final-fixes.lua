local buffed_entities_to_extend = {}

-- returns the number and the si unit
local function big_number_format(n)
	local si_unit = 0
	while n >= 1000 do
		n = n / 1000
		si_unit = si_unit + 1
	end
	
	return n, si_unit
end

local si_units = {
	'si-prefix-symbol-kilo',
	'si-prefix-symbol-mega',
	'si-prefix-symbol-giga',
	'si-prefix-symbol-tera',
	'si-prefix-symbol-peta',
	'si-prefix-symbol-exa',
	'si-prefix-symbol-zetta',
	'si-prefix-symbol-yotta',
	'si-prefix-symbol-ronna',
	'si-prefix-symbol-quetta',
}

-- formats a number with a certian number of decimal points and adds the si unit
-- creates a localised string
local function big_number_si_format(n, decimal_points)
	local n, si_unit = big_number_format(n, decimal_points)
	n = string.format('%.' .. (decimal_points or 1) .. 'f', n)
	n = n:gsub('%.0+$', '')
	if si_unit == 0 then return n end
	return {'', n, {si_units[si_unit]}}
end

local function big_number_km_per_hr_format(n, decimal_points)
	n = string.format('%.' .. (decimal_points or 1) .. 'f', n)
	n = n:gsub('%.0+$', '')
	return {'', n, {'si-unit-kilometer-per-hour'}}
end

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

			local quality_buff = factoriopedia_function(entity, quality_level)
			if type(quality_buff) ~= 'table' then quality_buff = tostring(quality_buff) end
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

for _, offshore_pump in pairs(data.raw['offshore-pump']) do
	make_effected_by_quality(offshore_pump, function(entity, quality_level)
		entity.pumping_speed = entity.pumping_speed * get_quality_buff(quality_level)
	end, {
		{'description.pumping-speed'}
	}, {
		{{'quality-tooltip.pumping-speed'}, function(entity, quality_level) return tostring(60 * entity.pumping_speed * get_quality_buff(quality_level)) .. '/s' end}
	})
end

local function parse_energy(energy)
	local energy_suffix = energy:match('[a-zA-Z]*$', 1)
	local energy = tonumber(energy:match('[0-9]+', 1)) or 1
	return energy, energy_suffix
end

for _, locomotive in pairs(data.raw.locomotive) do
	make_effected_by_quality(locomotive, function(entity, quality_level)
		local max_power, energy_suffix = parse_energy(entity.max_power)
		entity.max_power = math.floor(max_power * get_quality_buff(quality_level)) .. energy_suffix
		entity.max_speed = entity.max_speed * (1 + quality_level / 10)
	end, {
		{'description.acceleration-power'},
		{'description.max-speed'}
	}, {
		{{'quality-tooltip.acceleration-power'}, function(entity, quality_level)
			local max_power, energy_suffix = parse_energy(entity.max_power)
			return math.floor(max_power * get_quality_buff(quality_level)) .. energy_suffix
		end},
		{{'quality-tooltip.max-speed'}, function(entity, quality_level) return big_number_km_per_hr_format(215.83 * entity.max_speed * (1 + quality_level / 20)) end}
	})
end

for _, cargo_wagon in pairs(data.raw['cargo-wagon']) do
	make_effected_by_quality(cargo_wagon, function(entity, quality_level)
		entity.inventory_size = math.floor(entity.inventory_size * get_quality_buff(quality_level))
	end, {
		{'description.storage-size'}
	}, {
		{{'quality-tooltip.storage-size'}, function(entity, quality_level)
			return math.floor(entity.inventory_size * get_quality_buff(quality_level))
		end}
	})
end

for _, fluid_wagon in pairs(data.raw['fluid-wagon']) do
	make_effected_by_quality(fluid_wagon, function(entity, quality_level)
		entity.capacity = math.floor(entity.capacity * (1 + quality_level / 5))
	end, {
		{'description.fluid-capacity'}
	}, {
		{{'quality-tooltip.storage-volume'}, function(entity, quality_level)
			return big_number_si_format(entity.capacity * (1 + quality_level / 5))
		end}
	})
end

for _, lamp in pairs(data.raw.lamp) do
	make_effected_by_quality(lamp, function(entity, quality_level)
		entity.light = {intensity = entity.light.intensity, size = entity.light.size * get_quality_buff(quality_level)}
	end, {
		{'description.light-size'}
	}, {
		{{'quality-tooltip.light-size'}, function(entity, quality_level) return entity.light.size * get_quality_buff(quality_level) end}
	})
end

for _, storage_tank in pairs(data.raw['storage-tank']) do
	make_effected_by_quality(storage_tank, function(entity, quality_level)
		entity.fluid_box.volume = entity.fluid_box.volume * (1 + quality_level / 5)
	end, {
		{'description.fluid-capacity'}
	}, {
		{{'quality-tooltip.storage-volume'}, function(entity, quality_level)
			return big_number_si_format(entity.fluid_box.volume * (1 + quality_level / 5))
		end
		}
	})
end

data:extend(buffed_entities_to_extend)
