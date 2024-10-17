require "prototypes.promethium-reprocessing"

-- remove "haste makes waste"

data.raw.module["speed-module"].effect.quality = nil
for i = 2, 50 do
    local module = data.raw.module["speed-module-" .. i]
    if module then module.effect.quality = nil end
end
