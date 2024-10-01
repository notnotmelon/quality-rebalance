local buffed_entities_to_extend = {}

local function make_effected_by_quality(entity, buff_function)
	if entity.hidden then return end
	if not entity.minable then return end
	if entity.created_effect then
		log('Entity ' .. entity.name .. ' already has a created_effect. Skipping quality buff.')
		return
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

for _, chest in pairs(data.raw.container) do
	make_effected_by_quality(chest, function(entity, quality_level)
		local old_inventory_size = entity.inventory_size
		entity.inventory_size = old_inventory_size + math.floor(quality_level / 10 * old_inventory_size)
	end)
end

data:extend(buffed_entities_to_extend)