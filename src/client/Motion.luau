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

-- A rig for figures whose parts are all anchored (a preview in a ViewportFrame,
-- where no physics runs): the joint tree, so a pose can be solved by hand.
function Motion.Rig(model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart", true)
	if not root then return nil end
	local children, parents = {}, {}
	for _, item in ipairs(model:GetDescendants()) do
		if (item:IsA("Motor6D") or item:IsA("Weld")) and item.Part0 and item.Part1 then
			children[item.Part0] = children[item.Part0] or {}
			table.insert(children[item.Part0], item)
			parents[item.Part1] = item
		end
	end
	return { root = root, children = children, parents = parents, joints = Motion.Joints(model) }
end

-- Motor6D.Transform is applied by physics after the render callback. Resolve
-- just this chain for a shot emitted in the same callback, without teleporting
-- the live rig or waiting a frame for Attachment.WorldPosition to catch up.
function Motion.Point(rig, host, position)
	if not rig or not host then return nil end
	local frame, part = CFrame.new(position), host
	while rig.parents[part] do
		local joint = rig.parents[part]
		frame = joint.C0 * (joint:IsA("Motor6D") and joint.Transform or IDENTITY) * (joint.C1 or IDENTITY):Inverse() * frame
		part = joint.Part0
	end
	return (part.CFrame * frame).Position
end

-- Places every part from the root outward: each child sits where its parent's
-- joint puts it, with the joint's current Transform. Motor6D.Transform is what
-- Motion.Hero writes, so the same pose that moves a tower moves a preview.
function Motion.Solve(rig)
	local queue, head = { rig.root }, 1
	while queue[head] do
		local part = queue[head]
		head += 1
		for _, joint in ipairs(rig.children[part] or {}) do
			local transform = joint:IsA("Motor6D") and joint.Transform or IDENTITY
			joint.Part1.CFrame = part.CFrame * (joint.C0 or IDENTITY) * transform * (joint.C1 or IDENTITY):Inverse()
			table.insert(queue, joint.Part1)
		end
	end
end

-- Blinking (owner, 16/10): a hero's eyes shut for a moment every few seconds,
-- now and then twice in a row. Nothing is added to the figure: the white, the
-- iris, the pupil, the highlight and any glow in the eye hide, and the drawn lid (EyeLine, and the
-- lash with it) drops to the middle of the eye on its weld, so a figure in the
-- world and one in a viewport (Motion.Solve) blink alike. A face without drawn
-- eyes (a mask, a visor, the infected) is left alone.
local OPEN_EYE = { Sclera = true, Iris = true, Pupil = true, Catchlight = true, EyeGlow = true }
local LID = { EyeLine = true, Lash = true }
local BLINK_SPAN, BLINK_SHUT = 4.2, 0.13

local function noise(n)
	local x = sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

-- Whether the eyes are shut at `t` seconds; `seed` keeps neighbours out of step.
-- One blink in every 4.2 s window, somewhere in its first 3.4 s; about one in
-- five is a double blink.
function Motion.BlinkClosed(t, seed)
	seed = seed or 0
	local shift = seed * 1.618
	local cycle = math.floor((t + shift) / BLINK_SPAN)
	local at = cycle * BLINK_SPAN - shift + 0.5 + noise(cycle + seed * 7.31) * 2.9
	local since = t - at
	if since >= 0 and since < BLINK_SHUT then return true end
	return noise(cycle * 3.7 + seed) < 0.22 and since >= 0.24 and since < 0.24 + BLINK_SHUT
end

-- The pieces that blink on a figure (its face parts are welded to its Head),
-- or nil when it has no drawn eye.
function Motion.Eyes(model)
	local head = model and model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then return nil end
	local open, lids, whites = {}, {}, {}
	for _, piece in ipairs(model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		if fit and fit:IsA("Weld") and fit.Part0 == head then
			if OPEN_EYE[piece.Name] then
				table.insert(open, { part = piece, shown = piece.Transparency or 0 })
				if piece.Name == "Sclera" then table.insert(whites, fit.C0.Position) end
			elseif LID[piece.Name] then
				table.insert(lids, { weld = fit, rest = fit.C0 })
			end
		end
	end
	if #whites == 0 or #lids == 0 then return nil end
	-- Each lid shuts a little below the middle of the eye on its own side.
	for _, lid in ipairs(lids) do
		local x, eye = lid.rest.Position.X, nil
		for _, white in ipairs(whites) do
			if not eye or abs(white.X - x) < abs(eye.X - x) then eye = white end
		end
		local drop = max(0, lid.rest.Position.Y - (eye.Y - head.Size.Y * 0.02))
		lid.shut = CFrame.new(0, -drop, 0) * lid.rest
	end
	return { open = open, lids = lids, closed = false }
end

-- Opens or shuts the eyes found by Motion.Eyes; only a change touches a part.
function Motion.SetEyes(eyes, shut)
	shut = shut == true
	if not eyes or eyes.closed == shut then return end
	eyes.closed = shut
	for _, piece in ipairs(eyes.open) do piece.part.Transparency = shut and 1 or piece.shown end
	for _, lid in ipairs(eyes.lids) do lid.weld.C0 = shut and lid.shut or lid.rest end
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
-- Impact starts on the confirmed shot, then settles with a long recovery for
-- heavy attacks. Live preparation comes from the server's Windup cue; only
-- portraits use the optional interval prediction. Neither creates a hit.
function Motion.AttackEnvelope(age, interval, style)
	local heavy=style=="smash" or style=="strike" or style=="slash"
	local duration=math.min(heavy and 0.55 or 0.32,math.max(0.12,(interval or 1)*0.7))
	local progress=math.clamp(age/duration,0,1)
	local impact=(1-progress)^2
	local prepare=0
	local lead=math.min(heavy and 0.23 or 0.15,math.max(0.04,(interval or 1)*0.25))
	if interval and age>=interval-lead and age<interval then
		local t=math.clamp((age-interval+lead)/lead,0,1)
		prepare=t*t*(3-2*t)
	end
	return impact,prepare,progress
end

function Motion.WindupEnvelope(age, duration)
	if not duration or duration <= 0 or age < 0 or age >= duration then return 0 end
	local t = math.clamp(age / duration, 0, 1)
	return t * t * (3 - 2 * t)
end

function Motion.Hero(joints, pose)
	local fire, cast, hop, breathe = pose.fire or 0, pose.cast or 0, pose.hop or 0, pose.breathe or 0
	local prepare=pose.prepare or 0
	local style = pose.style or "shoot"
	-- Resting: arms a little away from the body, a slow breath.
	local lShoulder, lRoll, lElbow = 0.08, -0.12, 0.18
	local rShoulder, rRoll, rElbow = 0.08, 0.12, 0.18
	local waist, neck = 0.03 * breathe, -0.02 * breathe
	local twist, lift, shift = 0, 0, 0
	local rElbowRoll = 0
	local progress = math.clamp(pose.fireProgress or 0, 0, 1)
	local recover = sin(progress * pi) * (1 - progress)
	if style == "bow" then
		lShoulder, lRoll, lElbow = 1.1+0.35*prepare, 0, 0
		rShoulder, rRoll, rElbow = 1.0+0.3*prepare+0.15*fire, 0.3, 0.7+1.2*prepare-0.5*fire
		twist=-0.2*prepare+0.08*fire
	elseif style == "dual" or style == "rifle" then
		lShoulder, lElbow = 0.6 + 0.9 * fire, 0.3 * (1 - fire)
		rShoulder, rElbow = 0.7 + 0.85 * fire, 0.2 * (1 - fire)
		lRoll, rRoll = -0.1, 0.1
	elseif style == "smash" then
		lShoulder, rShoulder = 0.2+2.5*prepare+0.5*fire+0.35*recover, 0.2+2.5*prepare+0.5*fire+0.35*recover
		lElbow, rElbow = 0.35+0.55*prepare+0.7*recover, 0.35+0.55*prepare+0.7*recover
		lRoll, rRoll = -0.15-0.12*prepare, 0.15+0.12*prepare
		waist=waist+0.14*prepare-0.38*fire+0.12*recover
	elseif style == "punch" then
		-- Alternating jabs: the side that swings changes with every attack, the other
		-- fist stays up as a guard and the waist turns into the blow.
		local leftJab = (pose.count or 0) % 2 == 0
		if leftJab then
			lShoulder, lRoll, lElbow = 0.3 + 1.6 * fire, 0.05, 0.9 * (1 - fire)
			rShoulder, rRoll, rElbow = 0.9, 0.1, 1.4
		else
			rShoulder, rRoll, rElbow = 0.3 + 1.6 * fire, -0.05, 0.9 * (1 - fire)
			lShoulder, lRoll, lElbow = 0.9, -0.1, 1.4
		end
		twist = (leftJab and -0.5 or 0.5) * (fire-0.45*prepare)
		waist = waist - 0.08 * fire
	elseif style == "fly" then
		-- Hovering: the body floats on a slow bob with the legs trailing; the arms
		-- reach forward when the heat ray fires.
		lShoulder, rShoulder = 0.25 + 1.25 * fire, 0.25 + 1.25 * fire
		lRoll, rRoll = -0.12, 0.12
		lElbow, rElbow = 0.15, 0.15
		waist = waist + 0.1
		lift = 1.25 + 0.18 * sin((pose.t or 0) * 2.2)
	elseif style == "strike" or style == "slash" then
		rShoulder, rRoll, rElbow = 0.3+1.5*fire+1.8*prepare, 0.1-0.65*fire+0.35*prepare, 0.9*(1-fire)
		lShoulder, lElbow = 0.5, 1.2
		waist = waist - 0.12 * fire
		twist=-0.35*prepare+0.45*fire
	elseif style == "magic" then
		lShoulder, rShoulder = 0.5 + 1.0 * fire+0.25*prepare, 0.5 + 1.0 * fire+0.25*prepare
		lRoll, rRoll = -0.25+0.2*fire-0.5*prepare, 0.25-0.2*fire+0.5*prepare
		lElbow, rElbow = 0.6 * (1 - fire)+0.9*prepare, 0.6 * (1 - fire)+0.9*prepare
		waist=waist+0.08*prepare-0.07*fire
	elseif style == "beam" then
		lShoulder, rShoulder = 0.2 + 1.35 * fire, 0.2 + 1.35 * fire
		lRoll, rRoll = -0.1, 0.1
		lElbow, rElbow = 0.2 * (1 - fire), 0.2 * (1 - fire)
		neck = neck - 0.15 * fire
	elseif style == "throw" then
		rShoulder, rRoll, rElbow = 0.4 + 1.3 * fire, 0.2, 0.8 * (1 - fire)
		lShoulder, lElbow = 0.3 + 1.1 * fire, 1.2 * fire
	elseif style == "idle" then
		-- At ease (the lobby's heroes): the arms hang a little out from the body
		-- and sway with each breath, and the weight moves slowly from one foot to
		-- the other, the chest leaning back against it.
		local t = pose.t or 0
		lShoulder, lRoll, lElbow = 0.05 + 0.04 * breathe, -0.1 - 0.025 * breathe, 0.22 + 0.04 * breathe
		rShoulder, rRoll, rElbow = 0.05 - 0.04 * breathe, 0.1 + 0.025 * breathe, 0.22 - 0.04 * breathe
		shift = 0.045 * sin(t * 0.55) + 0.012 * sin(t * 1.3)
		-- A wave (pose.wave 0..1, for a visitor walking up): the right arm goes up
		-- and out, the forearm swings from side to side.
		local wave = math.clamp(pose.wave or 0, 0, 1)
		if wave > 0 then
			rShoulder = rShoulder + (2.7 - rShoulder) * wave
			rRoll = rRoll + (0.38 - rRoll) * wave
			rElbow = rElbow + (0.35 - rElbow) * wave
			rElbowRoll = 0.55 * sin(t * 10) * wave
		end
	else
		-- Point and shoot: the right arm levels at the target and kicks back.
		rShoulder, rRoll, rElbow = 0.65+0.75*prepare+0.95*fire, 0.12*(1-fire), 0.18+0.32*fire
		lShoulder, lElbow = 0.1 + 0.2 * fire, 0.3
		waist=waist+0.08*fire-0.03*prepare
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
	set(joints, "RightElbow", angles(rElbow, 0, rElbowRoll))
	set(joints, "Waist", angles(waist, twist, -shift * 0.7))
	set(joints, "Neck", angles(neck, 0, 0))
	-- A slight crouch when landing a heavy blow or bracing a cast; a flier's legs
	-- trail behind it instead.
	local brace = (style == "smash" and (fire * 0.35+prepare*0.18+recover*0.12) or 0) + 0.2 * cast
	local trail = lift > 0 and 0.35 or 0
	set(joints, "LeftHip", angles(brace + trail, 0, -0.05 - shift))
	set(joints, "RightHip", angles(brace + trail * 0.8, 0, 0.05 - shift))
	set(joints, "LeftKnee", angles(-brace * 1.6 - trail * 0.2, 0, 0))
	set(joints, "RightKnee", angles(-brace * 1.6 - trail * 0.3, 0, 0))
	set(joints, "LeftAnkle", angles(brace * 0.6, 0, 0))
	set(joints, "RightAnkle", angles(brace * 0.6, 0, 0))
	-- Breathing lifts the whole figure a little; a brace lowers it; a flier hovers.
	set(joints, "Root", CFrame.new(0, 0.03 * breathe - brace * 0.5 + lift, 0) * angles(0, 0, shift))
end

-- Rigs a live portrait (UI.heroPortraitLive) for Perform: its joint tree, where
-- the root stands and the hero's attack style. False when the figure has no joints.
function Motion.Prepare(live)
	local ok, rig = pcall(Motion.Rig, live.model)
	if not (ok and rig and rig.joints) then return false end
	live.rig, live.baseRoot = rig, rig.root.CFrame
	live.style = live.figure and live.figure:GetAttribute("PoseStyle") or "shoot"
	return true
end

-- A figure shown off in a preview (the revealed hero, the hero page). `live` is
-- what UI.heroPortraitLive returned plus rig/baseRoot/style; `since` the seconds
-- on its own clock; mode:
--   "rest"    the first frame: standing, no breath
--   "reveal"  a leap out of the chest with a full turn and both arms up, a landing,
--             a cheer, then the signature move on a loop
--   "idle"    breathing, with the signature move every few seconds, and at once
--             when `live.tapAt` is set to a recent `since` (a tap on the portrait)
-- The camera drifts a little to each side of the front view.
function Motion.Perform(live, since, mode)
	local rig = live.rig
	if not rig then return end
	local clamp = math.clamp
	local pose = { style = live.style, t = since, breathe = math.sin(since * 2.2) }
	local yaw, lift, squash = 0, 0, 0
	local function signature(age)
		-- Portraits include the preparation before the confirmed-impact pose.
		if age<0.23 then
			local t=math.clamp(age/0.23,0,1)
			pose.prepare=t*t*(3-2*t)
		else
			pose.fire,pose.prepare,pose.fireProgress=Motion.AttackEnvelope(age-0.23,1,live.style)
		end
	end
	if mode == "rest" or since < 0 then
		pose.breathe = 0
	elseif mode == "arrival" then
		-- A grounded entrance, then the real hero's signature. No full spin,
		-- repeated chest jump or universal arms-up cheer for every character.
		local u=clamp(since/0.65,0,1)
		yaw=-0.28*(1-u)^3
		lift=0.35*math.sin(math.pi*u)
		if since>0.65 and since<0.9 then squash=math.sin(math.pi*(since-0.65)/0.25)*0.35 end
		local cycle=(since-0.9)%4.2
		if since>0.9 and cycle<0.8 then
			signature(cycle)
		end
		pose.count=math.floor(math.max(0,since-0.9)/4.2)
	elseif mode == "idle" then
		local sinceTap = live.tapAt and since - live.tapAt or math.huge
		local cycle = (since + 0.6) % 3.6
		if sinceTap < 0.7 then
			signature(sinceTap)
		elseif cycle > 2.9 then
			signature(cycle-2.9)
		end
		pose.count = math.floor((since + 0.6) / 3.6) + (live.taps or 0)
	elseif since < 0.9 then
		-- The leap: up and down on an arc, one full turn, arms flung up.
		local u = since / 0.9
		lift = 1.8 * math.sin(math.pi * u)
		yaw = 2 * math.pi * (1 - (1 - u) ^ 3)
		pose.hop = math.sin(math.pi * clamp(u * 1.15, 0, 1))
	elseif since < 1.15 then
		-- The landing: a short crouch.
		local u = (since - 0.9) / 0.25
		squash = math.sin(math.pi * u)
		pose.cast = 0.35 * squash
	elseif since < 2.7 then
		-- The cheer: both arms up, a little bounce.
		local u = clamp((since - 1.15) / 0.3, 0, 1)
		pose.cast = u
		lift = 0.18 * math.abs(math.sin((since - 1.15) * 5)) * u
	else
		-- Signature move on a loop, easing back to a breath in between.
		local cycle = (since - 2.7) % 2.4
		pose.cast = clamp(1 - (since - 2.7) / 0.5, 0, 1)
		if cycle < 0.7 then
			signature(cycle)
		end
		pose.count = math.floor((since - 2.7) / 2.4)
	end
	Motion.Hero(rig.joints, pose)
	if live.eyes == nil then live.eyes = Motion.Eyes(live.figure or live.model) or false end
	if live.eyes then Motion.SetEyes(live.eyes, mode ~= "rest" and since > 0.4 and Motion.BlinkClosed(since, 0.6)) end
	if squash > 0 and rig.joints.Root then rig.joints.Root.Transform = CFrame.new(0, -0.45 * squash, 0) * rig.joints.Root.Transform end
	rig.root.CFrame = live.baseRoot * CFrame.new(0, lift, 0) * CFrame.Angles(0, yaw, 0)
	Motion.Solve(rig)
	local swing = mode == "rest" and 0 or (mode == "arrival" and 0.12 or (mode == "idle" and 0.3 or 0.45)) * math.sin(since * 0.8)
	local offset = CFrame.Angles(0, swing, 0) * live.offset
	live.camera.CFrame = CFrame.lookAt(live.focus + offset, live.focus)
end

return Motion
