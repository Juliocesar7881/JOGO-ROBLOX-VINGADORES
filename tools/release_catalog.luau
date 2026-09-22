local Catalog = require("../src/shared/Catalog")
local Config = require("../src/shared/Config")
for _,category in ipairs({"Passes","Consumables","Heroes"}) do
	local keys = {}
	for key in pairs(Catalog.Products[category]) do table.insert(keys,key) end
	table.sort(keys)
	for _,key in ipairs(keys) do
		local def=Catalog.Products[category][key]
		print("PRODUCT|"..category.."|"..key.."|"..def.price)
	end
end
local sounds = {}
for key in pairs(Config.Audio) do table.insert(sounds,key) end
table.sort(sounds)
for _,key in ipairs(sounds) do print("AUDIO|"..key) end
