-- Read the actual runtime catalog/config, including generated hero products.
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
print("COUNT|heroes|"..#Catalog.HeroOrder)
print("COUNT|bases|"..#Catalog.BaseOrder)
print("COUNT|maps|"..#Catalog.MapOrder)
for _,category in ipairs({"Passes","Consumables","Heroes"}) do
	local keys={}
	for key in pairs(Catalog.Products[category]) do table.insert(keys,key) end
	table.sort(keys)
	for _,key in ipairs(keys) do
		local def=Catalog.Products[category][key]
		local configured=Config.Products[category][key]
		print(table.concat({"PRODUCT",category,key,tostring(configured and configured.id or 0),tostring(def.price),def.name.pt},"|"))
	end
end
for _,key in ipairs({"LobbyPlaceId","MatchPlaceId","AfkPlaceId","GroupId"}) do
	print("CONFIG|"..key.."|"..tostring(Config[key] or 0))
end
for _,key in ipairs({"sfxUi","sfxEvents","sfxSummon","sfxCombat","sfxPowers","sfxBoss","sfxWorld"}) do
	print("AUDIO|"..key.."|"..tostring(Config.Audio[key] or 0))
end
