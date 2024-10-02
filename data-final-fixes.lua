local buffed_entities_to_extend = {}

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
					localised_string
				}
				return
			end
		end

		local entity_type = prototype.place_result and 'entity' or 'equipment'
		prototype.localised_description = {
			'?',
			{'', {entity_type .. '-description.' .. place_result}, '\n', localised_string},
			{'', {type .. '-description.' .. prototype.name},      '\n', localised_string},
			localised_string
		}
	else
		prototype.localised_description = {
			'?',
			{'', {type .. '-description.' .. prototype.name}, '\n', localised_string},
			localised_string
		}
	end
end

local function make_effected_by_quality(entity, buff_function, quality_description_localised_keys)
	if entity.hidden then return end
	if not entity.minable then return end
	if entity.created_effect then
		log('Entity ' .. entity.name .. ' already has a created_effect. Skipping quality buff.')
		return
	end

	for _, localised_key in pairs(quality_description_localised_keys) do
		add_to_description(entity.type, entity, {'description.quality-diamond', localised_key})
	end

	for _, quality in pairs(data.raw.quality) do
		local quality_level = quality.level
		if quality_level == 0 then goto continue end

		local buffed_entity = table.deepcopy(entity)
		buff_function(buffed_entity, quality_level)

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
			local old_inventory_size = entity.inventory_size
			entity.inventory_size = old_inventory_size + math.floor(quality_level / 10 * old_inventory_size)
		end, {
			{'description.storage-size'}
		})
	end
end

for _, elevated_rail_type in pairs {'rail-support', 'rail-ramp'} do
	for _, elevated_rail in pairs(data.raw[elevated_rail_type]) do
		make_effected_by_quality(elevated_rail, function(entity, quality_level)
			local old_support_range = entity.support_range or 15
			entity.support_range = old_support_range + math.floor(quality_level / 4 * old_support_range)
			add_to_description(entity.type, entity, {'description.support-range', tostring(entity.support_range)})
			if entity.name == 'rail-ramp-uncommon' then error(entity.name..serpent.block(entity.localised_description)) end
		end, {})
		add_to_description(elevated_rail.type, elevated_rail, {'description.support-range', tostring(elevated_rail.support_range or 15)})
	end
end

data:extend(buffed_entities_to_extend)
