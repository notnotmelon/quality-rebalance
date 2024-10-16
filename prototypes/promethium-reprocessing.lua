if not mods["space-age"] then return end

local item_sounds = require("__base__.prototypes.item_sounds")

local MAX_PROMETHIUM_QUALITY_RESEARCH_LEVEL = 300

data:extend {{
    type = "recipe",
    name = "promethium-asteroid-reprocessing",
    icon = "__quality-rebalance__/graphics/icons/promethium-asteroid-reprocessing.png",
    category = "crushing",
    subgroup = "space-crushing",
    order = "b-a-d",
    auto_recycle = false,
    enabled = false,
    ingredients = {{type = "item", name = "promethium-asteroid-chunk", amount = 1}},
    energy_required = 2,
    results = {
        {type = "item", name = "promethium-asteroid-chunk", amount = 1, probability = 0.8},
        {type = "item", name = "metallic-asteroid-chunk",   amount = 1, probability = 0.05},
        {type = "item", name = "carbonic-asteroid-chunk",   amount = 1, probability = 0.05},
        {type = "item", name = "oxide-asteroid-chunk",      amount = 1, probability = 0.05},
    },
    allow_productivity = false,
    allow_decomposition = false
}}

data:extend {{
    type = "technology",
    name = "promethium-quality",
    icons = util.technology_icon_constant_recipe_productivity("__space-age__/graphics/icons/starmap-shattered-planet.png"),
    icon_size = 256,
    effects = {
        {
            type = "nothing",
            use_icon_overlay_constant = false,
            recipe = "promethium-asteroid-reprocessing",
            effect_description = {"technology-effect.promethium-asteroid-reprocessing"},
            icons = {
                {
                    icon = "__quality-rebalance__/graphics/icons/promethium-asteroid-reprocessing.png",
                    icon_size = 64,
                },
                {
                    icon = "__core__/graphics/icons/technology/effect-constant/effect-constant-recipe-productivity.png",
                    icon_size = 64,
                    scale = 0.5,
                    shift = {0, 0},
                }
            }
        },
    },
    prerequisites = {"promethium-science-pack"},
    unit = {
        count_formula = "1.2^L*1000",
        ingredients = {
            {"automation-science-pack",      1},
            {"logistic-science-pack",        1},
            {"military-science-pack",        1},
            {"chemical-science-pack",        1},
            {"production-science-pack",      1},
            {"utility-science-pack",         1},
            {"space-science-pack",           1},
            {"metallurgic-science-pack",     1},
            {"electromagnetic-science-pack", 1},
            {"agricultural-science-pack",    1},
            {"cryogenic-science-pack",       1},
            {"promethium-science-pack",      1},
        },
        time = 120
    },
    max_level = "infinite",
    upgrade = true
}}
data.raw.technology["promethium-quality"].icons[1].icon_size = 512

data:extend {{
    type = "beacon",
    name = "promethium-quality-hidden-beacon",
    beacon_counter = "same_type",
    allowed_effects = {"quality"},
    module_slots = MAX_PROMETHIUM_QUALITY_RESEARCH_LEVEL,
    hidden = true,
    hidden_in_factoriopedia = true,
    supply_area_distance = 1,
    energy_usage = "1W",
    energy_source = {
        type = "void",
    },
    distribution_effectivity = 1,
    distribution_effectivity_bonus_per_quality_level = 0,
    is_military_target = false,
    quality_indicator_scale = 0,
    max_health = 1,
    alert_when_damaged = false,
    hide_resistances = true,
    collision_box = {{0, 0}, {0, 0}},
    selection_box = {{0, 0}, {0, 0}},
    collision_mask = {layers = {}},
    flags = {
        "not-blueprintable",
        "not-deconstructable",
        "not-flammable",
        "no-copy-paste",
        "not-selectable-in-game",
        "not-upgradable",
        "not-repairable",
        "not-on-map",
        "placeable-off-grid",
    },
}}

data:extend {{
    type = "module",
    name = "promethium-quality-hidden-module",
    icon = data.raw.module["quality-module-3"].icon,
    icon_size = data.raw.module["quality-module-3"].icon_size,
    colorblind_aid = {text = "Q"}, -- thanks boskid for giving me aids!
    inventory_move_sound = item_sounds.module_inventory_move,
    pick_sound = item_sounds.module_inventory_pickup,
    drop_sound = item_sounds.module_inventory_move,
    stack_size = 50,
    weight = 20 * kg,
    effect = {quality = 0.1},
    category = "promethium-quality-hidden-module",
    tier = 1,
    hidden = true,
    hidden_in_factoriopedia = true,
}}

data:extend {{
    type = "module-category",
    name = "promethium-quality-hidden-module",
}}

table.insert(data.raw.technology["promethium-science-pack"].effects, {
    type = "unlock-recipe",
    recipe = "promethium-asteroid-reprocessing",
})

data.raw["assembling-machine"].crusher.created_effect = {
    type = "direct",
    action_delivery = {
        type = "instant",
        source_effects = {
            type = "script",
            effect_id = "on_built_quality_rebalance"
        }
    }
}
