-- Automatic quality. A phone that cannot hold the frame rate in a battle
-- drops to the reduced-effects setting by itself (the same switch as Options,
-- so the player can turn it back on): two five-second windows in a row under
-- MIN_FPS, counted only while a wave is running. A hitch (alt-tab, a loading
-- stall, a slow first frame) is not the device's speed and is ignored. It
-- triggers at most once per session, so a player who turns the effects back
-- on is not argued with.
local AutoQuality = {}
AutoQuality.__index = AutoQuality

AutoQuality.WINDOW, AutoQuality.MIN_FPS, AutoQuality.STRIKES, AutoQuality.HITCH = 5, 27, 2, 0.5

-- options.active(): a wave is running; options.reduced(): effects are already
-- reduced; options.reduce(): switch them down (and tell the player).
function AutoQuality.new(options)
	return setmetatable({ options = options, time = 0, frames = 0, strikes = 0, done = false }, AutoQuality)
end

function AutoQuality:Step(dt)
	if self.done then return end
	local options = self.options
	if not options.active() or options.reduced() then
		self.time, self.frames, self.strikes = 0, 0, 0
		return
	end
	if type(dt) ~= "number" or dt <= 0 or dt > AutoQuality.HITCH then return end
	self.time += dt
	self.frames += 1
	if self.time < AutoQuality.WINDOW then return end
	local fps = self.frames / self.time
	self.time, self.frames = 0, 0
	if fps < AutoQuality.MIN_FPS then
		self.strikes += 1
		if self.strikes >= AutoQuality.STRIKES then
			self.done = true
			options.reduce()
		end
	else
		self.strikes = 0
	end
end

return AutoQuality
