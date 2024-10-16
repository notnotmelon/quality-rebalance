local on_built_crusher

local function on_init()
    -- [crusher entity unit number] = {entity = crusher entity, beacon = beacon entity}
    storage.promethium_quality_beacons = storage.promethium_quality_beacons or {}
end

script.on_init(on_init)
script.on_configuration_changed(on_init)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    if event.effect_id ~= 'on_built_quality_rebalance' then return end
    local entity = event.source_entity
    if not entity or not entity.valid then return end

    if entity.name == 'crusher' then
        on_built_crusher(entity)
        return
    end

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

--[[ broken code until player.cursor_ghost shows the quality
script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.get_player(event.player_index)
    local cursor_ghost = player.cursor_ghost
    if not cursor_ghost then return end
    game.print(cursor_ghost)
end)
]]--

local function update_crusher_beacon(beacon)
    local force = beacon.force
    local research_level = force.technologies["promethium-quality"].level - 1
    local module_inventory = beacon.get_module_inventory()
    module_inventory.clear()
    if research_level == 0 then return end
    module_inventory.insert {name = "promethium-quality-hidden-module", count = research_level}
end

on_built_crusher = function(crusher)
    local beacon = crusher.surface.create_entity {
        name = "promethium-quality-hidden-beacon",
        position = crusher.position,
        force = crusher.force_index
    }
    beacon.destructible = false
    beacon.minable = false
    beacon.operable = false
    beacon.rotatable = false
    update_crusher_beacon(beacon)
    storage.promethium_quality_beacons[crusher.unit_number] = {entity = crusher, beacon = beacon}
end

script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
    local research = event.research
    if research.name ~= 'promethium-quality' then return end

    local new_beacon_data = {}
    local beacons = storage.promethium_quality_beacons
    for k, beacon_data in pairs(beacons) do
        local crusher, beacon = beacon_data.entity, beacon_data.beacon

        if not crusher or not crusher.valid then
            goto continue
        end

        if not beacon then
            on_built_crusher(crusher)
        else
            update_crusher_beacon(beacon)
        end
        new_beacon_data[crusher.unit_number] = beacon_data

        ::continue::
    end
end)