local clock, studio, calls, failProgression = 0, false, {}, false
local os = {clock=function() return clock end}
local warn = function() end
local Enum = {
	AnalyticsCustomFieldKeys={CustomField01={Name="CustomField01"},CustomField02={Name="CustomField02"},CustomField03={Name="CustomField03"}},
	AnalyticsProgressionType={Start=1,Complete=2,Fail=3},
	AnalyticsEconomyFlowType={Source=1,Sink=2},
}
local service = {}
function service:LogProgressionEvent(player,path,status,level,levelName,fields)
	assert(player.UserId and type(path)=="string" and type(status)=="number")
	assert(type(level)=="number" and level>=1 and level%1==0,"level must be fourth argument")
	assert(type(levelName)=="string" and type(fields)=="table","custom fields must be last")
	if failProgression then error("transient rate limit") end
	table.insert(calls,{"progression",path,status,level,levelName,fields})
end
function service:LogCustomEvent(player,name,value,fields)
	assert(player.UserId and type(name)=="string" and type(value)=="number")
	table.insert(calls,{name,value,fields})
end
function service:LogFunnelStepEvent(player,name,session,step,label)
	assert(type(step)=="number" and type(label)=="string")
	table.insert(calls,{"tutorial",step})
end
local game = {GetService=function(_,name)
	if name=="AnalyticsService" then return service end
	if name=="RunService" then return {IsStudio=function() return studio end} end
	error(name)
end}
local Analytics = __MODULE__
local player={UserId=1}
local a=Analytics.new(true)
a:Progression(player,"gamma","cards","Start",0)
assert(#calls==1 and calls[1][4]==1 and calls[1][5]=="cards" and calls[1][6].CustomField01=="cards")
a:MatchFinished(player,"gamma","cards",true,20,120,400)
assert(#calls==5 and calls[2][3]==Enum.AnalyticsProgressionType.Complete)
failProgression=true
a:Progression(player,"gamma","cards","Fail",10)
assert(a.enabled and a.failures.progression==1)
a:TutorialStep(player,2,"FirstTower")
a:Custom(player,"ChestOpened",1)
assert(#calls==7,"one failed category must not silence tutorial and rewards")
a:Progression(player,"gamma","cards","Fail",10)
assert(a.failures.progression==1,"failed category is rate limited")
clock=31;failProgression=false
a:Progression(player,"gamma","cards","Fail",10)
assert(#calls==8 and a.retryAt.progression==nil)
a:BeginSession(player);clock=40
a:Milestone(player,"FirstTowerSeconds","manhattan","tutorial")
a:Milestone(player,"FirstTowerSeconds","manhattan","tutorial")
assert(#calls==9 and calls[9][2]==9,"milestones are timed and deduplicated")
a:EndSession(player)
assert(a.sessions[1]==nil)
a:BeginSession(player);clock=45
a:MatchStarted(player,"manhattan","tutorial")
clock=55;a:MatchStarted(player,"manhattan","normal")
a:MatchStarted(player,"gamma","normal")
assert(#calls==11 and calls[10][1]=="FirstMatchSeconds" and calls[10][2]==5)
assert(calls[11][1]=="SecondMatchSeconds" and calls[11][2]==15)
a:BeginSession(player);a:ProfileReady(player,false)
clock=60;a:Milestone(player,"FirstTowerSeconds","manhattan","tutorial")
assert(calls[12][3].CustomField03=="new" and calls[13][3].CustomField03=="new","Same account cohort on all milestones")
studio=true
local b=Analytics.new(true)
b:Progression(player,"gamma","cards","Start",1)
b:Custom(player,"Ignored",0)
assert(#calls==13 and not b.enabled,"Studio must not pollute live measurements")
print("PASS analytics: strict argument order, isolated errors, retry, milestones and Studio guard")
