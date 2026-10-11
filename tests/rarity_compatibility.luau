local Catalog=require("../src/shared/Catalog")
local Rules=require("../src/shared/Rules")
local baseline=require("./rarity_baseline")

return function(check,equal,approx)
	local merged={common="common",rare="common",epic="rare",legendary="legendary",mythic="legendary"}
	equal(#Catalog.RarityOrder,3,"Exactly three collectible rarities")
	check(Catalog.Rarities.epic==nil and Catalog.Rarities.mythic==nil,"Retired rarities cannot leak into UI")
	for id,old in pairs(baseline.heroes) do
		local hero=Catalog.Heroes[id]
		equal(hero.rarity,merged[old.rarity],"Hero reclassified without changing ID: "..id)
		equal(Catalog.Products.Heroes[id] and Catalog.Products.Heroes[id].price or 0,old.robux,"Existing direct price: "..id)
		equal(Rules.GuaranteedPrice(id),old.guaranteed,"Existing guaranteed Gold price: "..id)
		for rank,cost in ipairs(old.abilityCosts) do equal(Rules.AbilityUpgrade(id,rank).cost,cost,"Existing ability price: "..id.." "..rank) end
		equal(hero.economy.duplicate.gold,old.duplicateGold,"Existing duplicate Gold: "..id)
		equal(hero.economy.duplicate.mastery,old.duplicateMastery,"Existing duplicate mastery: "..id)
		equal(hero.economy.cards,old.cards,"Existing duplicate cards: "..id)
	end
	for id,old in pairs(baseline.bases) do
		equal(Catalog.Bases[id].rarity,merged[old.rarity],"Base reclassified: "..id)
		equal(Catalog.Bases[id].economy.duplicate.gold,old.duplicateGold,"Existing base compensation: "..id)
		equal(Rules.GuaranteedPrice(id),old.guaranteed,"Existing base guaranteed price: "..id)
	end
	for chestId,old in pairs(baseline.chests) do
		local chest=Catalog.Chests[chestId]
		equal(chest.cost,old.cost,"Existing chest price: "..chestId)
		equal(chest.pity and chest.pity.after,old.pity and old.pity.after,"Existing guarantee threshold: "..chestId)
		local odds={common=0,rare=0,legendary=0}
		for rarity,weight in pairs(old.odds) do odds[merged[rarity]]+=weight end
		for rarity,weight in pairs(odds) do equal(chest.odds[rarity],weight,"Merged displayed odds: "..chestId.." "..rarity) end
		local hash=1
		local function mix(value) for i=1,#value do hash=(hash*131+string.byte(value,i))%1000000007 end end
		local ids=chest.kind=="base" and Catalog.BaseOrder or Catalog.HeroOrder
		local items=chest.kind=="base" and Catalog.Bases or Catalog.Heroes
		for ownedCase=0,3 do
			local owned={};for i,id in ipairs(ids) do if ownedCase==3 or (ownedCase==1 and i%2==0) or (ownedCase==2 and i%3~=0) then owned[id]=true end end
			for _,pity in ipairs({0,chest.pity and chest.pity.after-1 or 0}) do
				local outcomes,forced=Rules.ChestOutcomes(chestId,pity,owned)
				local sum,byId=0,{}
				for _,entry in ipairs(outcomes) do
					check(not byId[entry.id],"One displayed outcome per item: "..chestId)
					check(not items[entry.id].starter,"No starter in actual or visual chest outcomes")
					check(not forced or entry.guaranteed,"Forced display contains only guarantee winners")
					equal(entry.rarity,items[entry.id].rarity,"Odds use the actual new rarity")
					byId[entry.id]=entry;sum+=entry.chance
				end
				approx(sum,100,"Displayed effective odds total 100: "..chestId)
				for a=0,20 do for b=0,20 do
					local outcome=Rules.RollChest(chestId,a/20,b/20,pity,owned)
					check(byId[outcome.itemId] and byId[outcome.itemId].chance>0,"Server draw appears in effective odds: "..chestId)
					mix(outcome.itemId..":"..tostring(outcome.duplicate)..":"..tostring(outcome.top)..":"..tostring(outcome.pity)..";")
				end end
			end
		end
		equal(hash,old.checksum,"All deterministic draws, fresh preference and guarantee resets preserved: "..chestId)
	end
end
