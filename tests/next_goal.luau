local Catalog=require("../src/shared/Catalog")
local Rules=require("../src/shared/Rules")
return function(check,equal)
	local p={tutorialComplete=false,gold=100000,stats={chests=0},campaign={},quests={}}
	equal(Rules.NextGoal(p).target.portal,"training","Training before rewards or purchases")
	p.tutorialComplete=true
	p.rewards={freeChest={ready=true},claimable=3}
	equal(Rules.NextGoal(p).id,"freeChest","Free chest before spending earned Gold")
	p.paidRandomRestricted=true
	equal(Rules.NextGoal(p).target.panel,"rewards","Free rewards remain accessible to restricted accounts")
	p.rewards.freeChest.ready=false
	equal(Rules.NextGoal(p).id,"rewards","Already earned rewards first")
	p.rewards.claimable=0
	p.quests={ready={id="ready",progress=10,target=10,name={pt="Missão",en="Mission"}}}
	equal(Rules.NextGoal(p).id,"quest:ready","Finished mission before another match")
	p.quests.ready.claimed=true;p.talentPoints=2
	equal(Rules.NextGoal(p).target.panel,"talents","Unspent points are actionable")
	p.talentPoints=0
	equal(Rules.NextGoal(p).target.portal,"normal","Restricted accounts see campaign, never a paid random chest")
	p.paidRandomRestricted=false
	equal(Rules.NextGoal(p).target.chest,"rare","First chest uses existing earned-Gold purchase")
	p.stats.chests=1
	for index,mapId in ipairs({"manhattan","gamma","hydra","wakanda","asgard","latveria"}) do
		local goal=Rules.NextGoal(p)
		equal(Catalog.Destinations[goal.target.portal].mapId,mapId,"Next uncompleted campaign destination")
		equal(goal.progress,index-1,"Progress from real completed maps")
		equal(goal.total,#Catalog.MapOrder,"Campaign goal denominator")
		check(goal.text.pt~="" and goal.text.en~="","Both languages exist")
		p.campaign[mapId]={normal=true}
	end
	p.quests={a={id="a",progress=1,target=10,name={pt="A",en="A"}},b={id="b",progress=9,target=10,name={pt="B",en="B"}}}
	equal(Rules.NextGoal(p).id,"mission:b","Closest remaining mission at endgame")
	equal(p.quests.b.progress,9,"Suggestions never change progress")
	p.quests.b.claimed=true;p.quests.a.claimed=true
	equal(Rules.NextGoal(p).target.portal,"cards","Campaign-complete fallback uses unlocked Cards")
	check(Rules.NextGoal(nil)==nil,"No goal before profile load")
end
