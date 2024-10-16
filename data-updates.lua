if not mods['space-age'] then return end

for _, recipe in pairs(data.raw.recipe) do
    if recipe.category == "crushing" and recipe.name ~= "promethium-asteroid-reprocessing" then
        local new_allowed_module_categories = {}
        if recipe.allowed_module_categories then
            for _, allowed_module_category in pairs(recipe.allowed_module_categories) do
                if allowed_module_category ~= "promethium-quality-hidden-module" then
                    table.insert(new_allowed_module_categories, allowed_module_category)
                end
            end
        else
            for _, module_category in pairs(data.raw['module-category']) do
                if module_category.name ~= "promethium-quality-hidden-module" then
                    table.insert(new_allowed_module_categories, module_category.name)
                end
            end
        end
        recipe.allowed_module_categories = new_allowed_module_categories
    end
end
