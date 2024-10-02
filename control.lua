script.on_event(defines.events.on_script_trigger_effect, function(event)
    if event.effect_id ~= 'on_built_quality_rebalance' then return end
    local entity = event.source_entity
    if not entity or not entity.valid then return end

    local name = entity.name
    local quality = entity.quality.level
    if quality == 0 then return end
    local buffed_name = name .. '-' .. entity.quality.name
    local buffed_entity = prototypes.entity[buffed_name]
    if not buffed_entity then return end

    entity.surface.create_entity{
        name = buffed_name,
        position = entity.position,
        direction = entity.direction,
        quality = entity.quality,
        force = entity.force_index,
        snap_to_grid = false,
        fast_replace = true,
        player = entity.last_user,
        character = entity.last_user and entity.last_user.character,
        spill = false,
        raise_built = true,
    }
end)