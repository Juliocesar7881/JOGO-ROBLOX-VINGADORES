--!nonstrict
-- The measurements the launch plan asks for: tutorial completion, abandonment
-- by wave, match duration, gold per minute, time to unlock a hero, squad
-- composition and technical faults.
--
-- Every call is wrapped: analytics must never be able to fail a match. Studio
-- sessions are skipped so test runs do not pollute the live funnels.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}
Analytics.__index = Analytics

local FUNNEL = "Tutorial"

local function fieldKeys()
	local ok, keys = pcall(function()
		return {
			Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
			Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
			Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
		}
	end)
	return ok and keys or nil
end

function Analytics.new(enabled)
	local self = setmetatable({}, Analytics)
	self.enabled = enabled ~= false and not RunService:IsStudio()
	self.keys = self.enabled and fieldKeys() or nil
	self.counts = {}
	self.failures, self.retryAt, self.sessions = {}, {}, {}
	return self
end

function Analytics:_fields(first, second, third)
	if not self.keys then return nil end
	local fields = {}
	local values = { first, second, third }
	for index, key in ipairs(self.keys) do
		if values[index] ~= nil then fields[key] = tostring(values[index]) end
	end
	return next(fields) and fields or nil
end

function Analytics:_call(name, callback)
	self.counts[name] = (self.counts[name] or 0) + 1
	if not self.enabled then return end
	if os.clock() < (self.retryAt[name] or 0) then return end
	local ok, problem = pcall(callback)
	if not ok then
		-- A transient limit or one invalid event must not silence every funnel.
		self.failures[name] = (self.failures[name] or 0) + 1
		self.retryAt[name] = os.clock() + 30
		warn("[Analytics] retry in 30s for " .. name .. ": " .. tostring(problem))
	else
		self.retryAt[name] = nil
	end
end

function Analytics:BeginSession(player)
	self.sessions[player.UserId] = { started = os.clock(), seen = {} }
end

function Analytics:ProfileReady(player, returning)
	local session=self.sessions[player.UserId]
	if not session then return end
	session.cohort=returning and "returning" or "new"
	self:Milestone(player,"ProfileReadySeconds")
end

-- Once per connection, in seconds since joining. These are observed events,
-- not client claims; AFK time is never mistaken for a completed match.
function Analytics:Milestone(player, name, mapId, modeId)
	local session = self.sessions[player.UserId]
	if not session or session.seen[name] then return end
	session.seen[name] = true
	self:Custom(player, name, math.max(0, os.clock() - session.started), mapId, modeId,session.cohort)
end

function Analytics:EndSession(player)
	self.sessions[player.UserId] = nil
end

function Analytics:MatchStarted(player, mapId, modeId)
	local session = self.sessions[player.UserId]
	if not session then return end
	session.matches = (session.matches or 0) + 1
	if session.matches <= 2 then
		self:Milestone(player, session.matches == 1 and "FirstMatchSeconds" or "SecondMatchSeconds", mapId, modeId)
	end
end

function Analytics:Custom(player, eventName, value, first, second, third)
	self:_call(eventName, function()
		AnalyticsService:LogCustomEvent(player, eventName, tonumber(value) or 0, self:_fields(first, second, third))
	end)
end

-- Gold entering or leaving an account, so the economy can be read without
-- guessing from aggregate balances.
function Analytics:Economy(player, source, amount, balance, transaction, sku)
	if (tonumber(amount) or 0) <= 0 then return end
	self:_call("economy", function()
		AnalyticsService:LogEconomyEvent(
			player,
			source and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink,
			"Gold",
			math.floor(amount),
			math.max(0, math.floor(tonumber(balance) or 0)),
			tostring(transaction or "Gameplay"),
			sku and tostring(sku) or nil
		)
	end)
end

function Analytics:TutorialStep(player, step, name)
	self:_call("tutorial", function()
		AnalyticsService:LogFunnelStepEvent(player, FUNNEL, nil, math.floor(step), tostring(name))
	end)
end

-- status is "Start", "Complete" or "Fail"; level carries the wave reached, which
-- is what turns abandonment into a readable curve.
function Analytics:Progression(player, mapId, modeId, status, wave)
	self:_call("progression", function()
		local progression = Enum.AnalyticsProgressionType[status]
		AnalyticsService:LogProgressionEvent(
			player,
			tostring(mapId),
			progression,
			math.max(1, math.floor(tonumber(wave) or 1)),
			tostring(modeId),
			self:_fields(modeId, wave)
		)
	end)
end

function Analytics:MatchFinished(player, mapId, modeId, victory, waves, seconds, gold)
	seconds = math.max(1, math.floor(tonumber(seconds) or 1))
	self:Progression(player, mapId, modeId, victory and "Complete" or "Fail", waves)
	self:Custom(player, "MatchDuration", seconds, mapId, modeId, victory and "win" or "loss")
	self:Custom(player, "GoldPerMinute", math.floor((tonumber(gold) or 0) * 60 / seconds), mapId, modeId)
	self:Custom(player, "WavesCleared", waves, mapId, modeId)
end

-- One value per field keeps every event under Roblox's limit of 8,000 values
-- per field (a whole team as one string ran past it and read as "Other"):
-- who leads the team (that hero gives the power) and each hero fielded.
function Analytics:Composition(player, loadout, mapId)
	if type(loadout) ~= "table" or #loadout == 0 then return end
	self:Custom(player, "TeamLeader", #loadout, tostring(loadout[1]), mapId)
	for _, heroId in ipairs(loadout) do
		self:Custom(player, "TeamHero", 1, tostring(heroId), mapId)
	end
end

function Analytics:HeroUnlocked(player, heroId, level, minutesPlayed)
	self:Custom(player, "HeroUnlocked", math.floor(tonumber(minutesPlayed) or 0), heroId, level)
end

function Analytics:Fault(player, area, detail)
	self:Custom(player, "Fault", 1, area, detail)
end

function Analytics:Report()
	return table.clone(self.counts)
end

return Analytics
