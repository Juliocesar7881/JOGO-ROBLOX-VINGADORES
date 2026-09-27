--!nonstrict
-- Motion: poses and walks the jointed figures (heroes, enemies, bosses) by
-- writing Motor6D.Transform on this client only. Nothing here is replicated
-- or read by a rule: a figure standing still is exactly as correct as one
-- walking, this only makes the battle readable.
--
-- Walking is driven by distance, not time: the stride advances with how far
-- the figure actually moved this frame, so feet never slide at any speed and
-- stop when the enemy is frozen or stunned.
local Motion = {}

local JOINTS = { "Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist",
	"LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle", "LeftWing", "RightWing", "Tail1", "Tail2", "Tail3", "Tail4" }
local IDENTITY = CFrame.new()
local angles = CFrame.Angles
local sin, cos, max, abs, pi = math.sin, math.cos, math.max, math.abs, math.pi

-- Every joint of a figure by name (Motor6Ds live in the part they move).
function Motion.Joints(model)
	local joints, count = {}, 0
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Motor6D") and table.find(JOINTS, item.Name) then
			joints[item.Name] = item
			count += 1
		end
	end
	return count > 0 and joints or nil
end

function Motion.Reset(joints)
	for _, motor in pairs(joints or {}) do motor.Transform = IDENTITY end
end

local function set(joints, name, value)
	local motor = joints[name]
	if motor then motor.Transform = value end
end

-- How each family walks. stride: studs per step (at scale 1); hip/knee/arm:
-- swing in radians; lean: forward tilt of the whole body; arms: resting
-- shoulder pitch (1.3 = reaching forward like the classic shambler).
local GAITS = {
	shamble = { stride = 1.7, hip = 0.42, knee = 0.62, arm = 0.12, armRest = 1.32, elbow = 0.1, lean = -0.12, bob = 0.07, limp = 0.62, headRoll = 0.22, sway = 0.1 },
	sprint = { stride = 3.2, hip = 0.95, knee = 1.35, arm = 1.05, armRest = 0.1, elbow = 1.25, lean = -0.36, bob = 0.12, sway = 0.05 },
	stomp = { stride = 2.2, hip = 0.44, knee = 0.52, arm = 0.3, armRest = 0.06, elbow = 0.25, lean = -0.18, bob = 0.18, spread = 0.16, sway = 0.12, heavy = true },
	march = { stride = 2.0, hip = 0.6, knee = 0.62, arm = 0.5, armRest = 0.05, elbow = 0.2, lean = -0.02, bob = 0.06, shield = true },
	sneak = { stride = 1.8, hip = 0.5, knee = 0.7, arm = 0.2, armRest = 0.55, elbow = 0.7, lean = -0.4, bob = 0.04, crouch = 0.42 },
	hover = { stride = 4, hip = 0.12, knee = 0.2, arm = 0.1, armRest = 0.2, elbow = 0.3, lean = -0.28, bob = 0, hover = true },
	glide = { stride = 1.4, hip = 0.2, knee = 0.2, arm = 0.08, armRest = 0.25, elbow = 0.5, lean = 0, bob = 0.03 },
	stalk = { stride = 2.4, hip = 0.62, knee = 0.8, arm = 0.3, armRest = 0.45, elbow = 1.0, lean = -0.22, bob = 0.07 },
	reptile = { stride = 2.2, hip = 0.5, knee = 0.7, arm = 0.26, armRest = 0.75, elbow = 0.55, lean = -0.42, bob = 0.1, sway = 0.12 },
	regal = { stride = 2.2, hip = 0.4, knee = 0.36, arm = 0.2, armRest = 0.08, elbow = 0.15, lean = 0.04, bob = 0.04 },
}
Motion.Gaits = GAITS

-- Advances one enemy's walk. `moved` is the distance walked this frame,
-- `scale` the figure's size. Returns true when a foot lands (for dust).
function Motion.Walk(record, joints, gaitName, moved, scale, stopped, clock)
	local gait = GAITS[gaitName] or GAITS.shamble
	local before = record.stride or 0
	if not stopped then record.stride = before + moved / (gait.stride * math.max(scale, 0.3)) * pi end
	local p = record.stride or 0
	local s = sin(p)
	local swingL, swingR = s, -s
	local liftL, liftR = max(0, cos(p)), max(0, -cos(p))
	-- A frozen enemy holds its pose instead of snapping to attention.
	local amount = stopped and 0.25 or 1
	local limp = gait.limp or 1
	local crouch = gait.crouch or 0
	local breath = sin(clock * 2 + (record.phase or 0))
	if gait.hover then
		-- Flyers: legs trail, knees bent, the wings beat.
		local flap = sin(clock * 9 + (record.phase or 0))
		set(joints, "LeftHip", angles(-0.25 + 0.12 * s, 0, 0.05))
		set(joints, "RightHip", angles(-0.25 - 0.12 * s, 0, -0.05))
		set(joints, "LeftKnee", angles(-0.45, 0, 0))
		set(joints, "RightKnee", angles(-0.45, 0, 0))
		set(joints, "LeftShoulder", angles(0.2, 0, -0.5 - 0.1 * flap))
		set(joints, "RightShoulder", angles(0.2, 0, 0.5 + 0.1 * flap))
		set(joints, "LeftWing", angles(0, 0.2, 0.45 * flap))
		set(joints, "RightWing", angles(0, -0.2, -0.45 * flap))
		set(joints, "Root", angles(gait.lean, 0, 0.06 * sin(clock * 1.7)))
		return false
	end
	local hipSpread = gait.spread or 0
	set(joints, "LeftHip", angles(amount * gait.hip * swingL + crouch * 0.8, 0, -hipSpread))
	set(joints, "RightHip", angles(amount * gait.hip * swingR * limp + crouch * 0.8, 0, hipSpread))
	set(joints, "LeftKnee", angles(-amount * gait.knee * liftL - crouch * 1.2, 0, 0))
	set(joints, "RightKnee", angles(-amount * gait.knee * liftR * limp - crouch * 1.2, 0, 0))
	set(joints, "LeftAnkle", angles(amount * gait.knee * liftL * 0.35 + crouch * 0.4 - amount * gait.hip * swingL * 0.3, 0, 0))
	set(joints, "RightAnkle", angles(amount * gait.knee * liftR * 0.35 + crouch * 0.4 - amount * gait.hip * swingR * 0.3, 0, 0))
	-- Arms swing against the legs around each family's resting pose.
	local sway = (gait.sway or 0) * sin(p * 0.5)
	local leftArm = gait.armRest - amount * gait.arm * swingL
	local rightArm = gait.armRest - amount * gait.arm * swingR
	if gait.shield then leftArm = 0.85 end
	set(joints, "LeftShoulder", angles(leftArm, 0, -0.06 - hipSpread * 0.6))
	set(joints, "RightShoulder", angles(rightArm, 0, 0.06 + hipSpread * 0.6))
	set(joints, "LeftElbow", angles(gait.shield and 1.1 or gait.elbow, 0, 0))
	set(joints, "RightElbow", angles(gait.elbow, 0, 0))
	-- The body rides the steps: highest when the legs pass, lower at full
	-- stride, and heavy walkers roll side to side.
	-- Only the upper body leans, so the feet stay on the road.
	local bob = gait.bob * scale * (abs(cos(p)) - 0.5) * amount
	set(joints, "Root", CFrame.new(0, bob - crouch * 0.5 * scale, 0) * angles(0, 0, (gait.heavy and 0.08 or 0.03) * s * amount))
	set(joints, "Waist", angles(gait.lean + 0.02 * breath, 0.12 * s * amount, sway))
	set(joints, "Neck", angles(-gait.lean * 0.6, 0, (gait.headRoll or 0) + 0.04 * breath))
	-- A tail follows the hips a beat late.
	for index = 1, 4 do
		set(joints, "Tail" .. index, angles(0.05 * sin(p + index), 0.18 * sin(p * 0.5 - index * 0.6), 0))
	end
	local step = math.floor(p / pi)
	return not stopped and step ~= math.floor(before / pi)
end

-- A tower hero's pose this frame. pose: fire, cast, hop (0..1 envelopes),
-- stunned, breathe (idle -1..1), style (Catalog-driven attack kind).
function Motion.Hero(joints, pose)
	local fire, cast, hop, breathe = pose.fire or 0, pose.cast or 0, pose.hop or 0, pose.breathe or 0
	local style = pose.style or "shoot"
	-- Resting: arms a little away from the body, a slow breath.
	local lShoulder, lRoll, lElbow = 0.08, -0.12, 0.18
	local rShoulder, rRoll, rElbow = 0.08, 0.12, 0.18
	local waist, neck = 0.03 * breathe, -0.02 * breathe
	if style == "bow" then
		lShoulder, lRoll, lElbow = 1.45 * (0.35 + 0.65 * fire), 0, 0
		rShoulder, rRoll, rElbow = 1.3 * (0.3 + 0.7 * fire), 0.3, 1.9 * fire
	elseif style == "dual" or style == "rifle" then
		lShoulder, lElbow = 0.6 + 0.9 * fire, 0.3 * (1 - fire)
		rShoulder, rElbow = 0.7 + 0.85 * fire, 0.2 * (1 - fire)
		lRoll, rRoll = -0.1, 0.1
	elseif style == "smash" then
		-- Both fists up and down: weight goes into the waist.
		local progress = pose.fireProgress or fire
		local raise = progress < 0.45 and progress / 0.45 or math.max(0, 1 - (progress - 0.45) / 0.3)
		lShoulder, rShoulder = 0.2 + 2.6 * raise, 0.2 + 2.6 * raise
		lElbow, rElbow = 0.5 + 0.4 * raise, 0.5 + 0.4 * raise
		waist = waist + (progress > 0.45 and -0.35 * (1 - raise) or 0.12 * raise)
	elseif style == "strike" or style == "slash" then
		rShoulder, rRoll, rElbow = 0.3 + 1.5 * fire, 0.1 - 0.5 * fire, 0.9 * (1 - fire)
		lShoulder, lElbow = 0.5, 1.2
		waist = waist - 0.12 * fire
	elseif style == "magic" then
		lShoulder, rShoulder = 0.5 + 1.0 * fire, 0.5 + 1.0 * fire
		lRoll, rRoll = -0.25 + 0.2 * fire, 0.25 - 0.2 * fire
		lElbow, rElbow = 0.6 * (1 - fire), 0.6 * (1 - fire)
	elseif style == "beam" then
		lShoulder, rShoulder = 0.2 + 1.35 * fire, 0.2 + 1.35 * fire
		lRoll, rRoll = -0.1, 0.1
		lElbow, rElbow = 0.2 * (1 - fire), 0.2 * (1 - fire)
		neck = neck - 0.15 * fire
	elseif style == "throw" then
		rShoulder, rRoll, rElbow = 0.4 + 1.3 * fire, 0.2, 0.8 * (1 - fire)
		lShoulder, lElbow = 0.3 + 1.1 * fire, 1.2 * fire
	else
		-- Point and shoot: the right arm levels at the target and kicks back.
		local recoil = fire > 0.6 and (fire - 0.6) * 0.5 or 0
		rShoulder, rRoll, rElbow = 0.1 + 1.45 * fire + recoil, 0.12 * (1 - fire), 0.18 * (1 - fire)
		lShoulder, lElbow = 0.1 + 0.2 * fire, 0.3
	end
	if cast > 0 then
		-- The leader's power: both arms thrown up.
		lShoulder, rShoulder = lShoulder + (2.8 - lShoulder) * cast, rShoulder + (2.8 - rShoulder) * cast
		lRoll, rRoll = lRoll - 0.35 * cast, rRoll + 0.35 * cast
		lElbow, rElbow = lElbow * (1 - cast), rElbow * (1 - cast)
		neck = neck + 0.25 * cast
	end
	if hop > 0 then
		lShoulder, rShoulder = lShoulder + (2.4 - lShoulder) * hop, rShoulder + (2.4 - rShoulder) * hop
		lRoll, rRoll = lRoll - 0.6 * hop, rRoll + 0.6 * hop
	end
	if pose.stunned then
		-- Dazed: slumped over, head down, arms hanging.
		lShoulder, rShoulder, lElbow, rElbow = 0.25, 0.25, 0.1, 0.1
		waist, neck = -0.45, -0.5
	end
	set(joints, "LeftShoulder", angles(lShoulder, 0, lRoll))
	set(joints, "RightShoulder", angles(rShoulder, 0, rRoll))
	set(joints, "LeftElbow", angles(lElbow, 0, 0))
	set(joints, "RightElbow", angles(rElbow, 0, 0))
	set(joints, "Waist", angles(waist, 0, 0))
	set(joints, "Neck", angles(neck, 0, 0))
	-- A slight crouch when landing a heavy blow or bracing a cast.
	local progress = pose.fireProgress or 0
	local brace = (style == "smash" and progress > 0.45 and fire * 0.35 or 0) + 0.2 * cast
	set(joints, "LeftHip", angles(brace, 0, -0.05))
	set(joints, "RightHip", angles(brace, 0, 0.05))
	set(joints, "LeftKnee", angles(-brace * 1.6, 0, 0))
	set(joints, "RightKnee", angles(-brace * 1.6, 0, 0))
	set(joints, "LeftAnkle", angles(brace * 0.6, 0, 0))
	set(joints, "RightAnkle", angles(brace * 0.6, 0, 0))
	-- Breathing lifts the whole figure a little; a brace lowers it.
	set(joints, "Root", CFrame.new(0, 0.03 * breathe - brace * 0.5, 0))
end

return Motion
