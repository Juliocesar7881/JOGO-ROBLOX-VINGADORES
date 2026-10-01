-- Executed by test_ui_layout.py, which inlines the real UI module.
--
-- Roblox lays out the lobby's top bar from a mix of pixel offsets and
-- right-anchored buttons. That maths already produced one bug where the gold
-- counter rendered underneath the party button on a phone, and no other suite
-- can see it: nothing else in this project computes a screen rectangle.
local Stubs = __STUBS__
local UI = __UI__

local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL: " .. label)
	end
end

-- Real viewport widths, portrait phones through wide desktops. The client
-- treats anything under 820 as mobile, so both sides of that line are covered.
local DEVICES = {
	{ name = "phone-small", width = 320, mobile = true },
	{ name = "phone-se", width = 375, mobile = true },
	{ name = "phone-tall", width = 414, mobile = true },
	{ name = "android", width = 412, mobile = true },
	{ name = "tablet-portrait", width = 768, mobile = true },
	{ name = "tablet-landscape", width = 1024, mobile = false },
	{ name = "laptop", width = 1366, mobile = false },
	{ name = "desktop", width = 1920, mobile = false },
	{ name = "ultrawide", width = 3440, mobile = false },
}

-- The lobby's corner HUD at every width: the pill and the two buttons never
-- collide, however narrow the screen, and the buttons stay thumb-sized.
local function rectsOverlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
print("--- lobby corners ---")
for _, device in ipairs(DEVICES) do
	local H = UI.lobbyLayout(device.width, 720)
	local label = device.name .. " (" .. tostring(device.width) .. "px)"
	check(not rectsOverlap(H.pill, H.squad), label .. ": the gold pill never runs under the squad button")
	check(not rectsOverlap(H.squad, H.settings), label .. ": the squad button never overlaps settings")
	check(H.settings.x + H.settings.w <= math.max(320, device.width), label .. ": settings stays on screen")
	check(H.pill.w >= 100, label .. ": the gold pill keeps room for a number, got " .. H.pill.w)
	check(H.squad.w >= 46 and H.settings.w >= 46 and H.squad.h >= 48, label .. ": buttons stay thumb-sized")
	-- The whole point of the redesign: the corners are corners, not a bar.
	check(H.pill.w + H.squad.w + H.settings.w <= math.max(320, device.width) * 0.8 or device.width < 560,
		label .. ": the corner HUD leaves the middle of the top edge to the world")
end

--==============================================================================
-- Degenerate inputs must not produce negative or overlapping geometry
--==============================================================================
print("--- degenerate ---")
for _, width in ipairs({ 0, 1, 120, -500 }) do
	local H = UI.lobbyLayout(width, 0)
	check(H.pill.w > 0 and H.context.h > 0, "a " .. tostring(width) .. "px screen still clamps to a usable HUD")
	check(not rectsOverlap(H.pill, H.squad), "a " .. tostring(width) .. "px screen keeps the pill clear of the buttons")
end
local fallback = UI.lobbyLayout(nil, nil)
check(fallback.pill.w > 0, "a missing screen size falls back instead of erroring")

--==============================================================================
-- Real usable screens: viewport minus Roblox's topbar inset (58px, the worst
-- case) and, on notched iPhones, the safe-area insets. Phones are landscape
-- because that is the default StarterGui.ScreenOrientation; portrait is kept
-- as a secondary target in case the experience ever opts into it.
--==============================================================================
local SCREENS = {
	{ name = "android 360dp landscape", w = 640, h = 302 },
	{ name = "galaxy S landscape", w = 780, h = 302 },
	{ name = "iphone SE landscape", w = 667, h = 317 },
	{ name = "iphone 12 landscape (notch)", w = 754, h = 311 },
	{ name = "pixel landscape", w = 915, h = 354 },
	{ name = "iphone pro max landscape", w = 842, h = 372 },
	{ name = "android 412dp landscape", w = 732, h = 354 },
	{ name = "ipad landscape", w = 1024, h = 710 },
	{ name = "ipad air landscape", w = 1180, h = 762 },
	{ name = "ipad pro landscape", w = 1366, h = 966 },
	{ name = "ipad portrait", w = 768, h = 966 },
	{ name = "ipad air portrait", w = 820, h = 1122 },
	{ name = "small desktop window", w = 1024, h = 542 },
	{ name = "laptop 720p", w = 1280, h = 662 },
	{ name = "laptop 768p", w = 1366, h = 710 },
	{ name = "desktop 1080p", w = 1920, h = 1022 },
	{ name = "desktop 1440p", w = 2560, h = 1382 },
	{ name = "iphone SE portrait", w = 375, h = 609 },
	{ name = "iphone 12 portrait", w = 390, h = 732 },
	{ name = "android portrait", w = 360, h = 742 },
	{ name = "pixel portrait", w = 412, h = 857 },
	{ name = "iphone pro max portrait", w = 428, h = 810 },
}

local function inside(r, width, height)
	return r.x >= 0 and r.y >= 0 and r.x + r.w <= width and r.y + r.h <= height
end
local function within(child, parent)
	return child.x >= parent.x and child.y >= parent.y
		and child.x + child.w <= parent.x + parent.w and child.y + child.h <= parent.y + parent.h
end
local function overlaps(a, b)
	if a.w == 0 or a.h == 0 or b.w == 0 or b.h == 0 then return false end
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function describe(r) return string.format("(%d,%d %dx%d)", r.x, r.y, r.w, r.h) end

--==============================================================================
-- Match HUD
--==============================================================================
print("--- match hud ---")
for _, screen in ipairs(SCREENS) do
	for _, loadout in ipairs({ { skills = 2, vip = true }, { skills = 1, vip = false }, { skills = 0, vip = false } }) do
		local L = UI.matchLayout(screen.w, screen.h, loadout)
		local tag = screen.name .. " " .. screen.w .. "x" .. screen.h .. " [" .. loadout.skills .. (loadout.vip and "+vip" or "") .. "]"
		local named = {
			top = L.top, energy = L.energy, gold = L.gold, waveInfo = L.waveInfo, skip = L.skip, boss = L.boss,
			placement = L.placement, hint = L.hint, abilities = L.abilities, heroCards = L.heroCards, tower = L.tower,
		}
		for name, r in pairs(named) do
			check(inside(r, screen.w, screen.h), tag .. ": " .. name .. " stays on screen " .. describe(r))
		end
		for _, name in ipairs({ "wave", "map", "hpText", "hpBar" }) do
			check(within(L[name], L.top), tag .. ": " .. name .. " sits inside the top bar " .. describe(L[name]))
		end

		-- What is on screen together must never overlap. Skip only exists while
		-- preparing and the boss only during a wave; the placement bar, its hint
		-- and the tower panel are mutually exclusive selections.
		local always = { "top", "energy", "gold", "waveInfo", "abilities", "heroCards" }
		local allowed = {}
		if L.class.narrow then
			-- Portrait folds gold and energy into the top bar on purpose.
			allowed["top:energy"], allowed["top:gold"] = true, true
			allowed["energy:top"], allowed["gold:top"] = true, true
		end
		local function apart(a, b)
			if allowed[a .. ":" .. b] then return end
			check(not overlaps(named[a], named[b]), tag .. ": " .. a .. " " .. describe(named[a]) .. " overlaps " .. b .. " " .. describe(named[b]))
		end
		for i = 1, #always do
			for j = i + 1, #always do apart(always[i], always[j]) end
		end
		for _, transient in ipairs({ "skip", "boss" }) do
			for _, name in ipairs(always) do apart(transient, name) end
		end
		for _, selection in ipairs({ "placement", "hint", "tower" }) do
			for _, name in ipairs(always) do apart(selection, name) end
			apart(selection, "skip")
			apart(selection, "boss")
		end
		apart("hint", "placement")

		-- The tower panel must be as tall as its own content, or the upgrade
		-- button ends up off the panel — the exact landscape-phone bug this
		-- layout replaced.
		local need = L.towerVariant == "tall" and UI.TOWER_TALL_HEIGHT or UI.TOWER_WIDE_HEIGHT
		check(L.tower.h >= need, tag .. ": the " .. L.towerVariant .. " tower panel fits its content, got " .. L.tower.h .. "/" .. need)
		check(L.tower.w >= 250, tag .. ": the tower panel stays wide enough for its buttons, got " .. L.tower.w)

		-- Thumb-sized controls.
		check(L.skip.h >= 48 and L.buttonH >= 48, tag .. ": ready and ability buttons are thumb-sized")
		check(L.heroCards.h - 14 >= 48, tag .. ": hero cards stay tall enough to tap")
		check(L.heroCards.w >= L.cardW, tag .. ": at least one hero card is fully visible, band " .. L.heroCards.w)
		check(L.cardW >= 48, tag .. ": a hero slot is at least a thumb wide, got " .. L.cardW)
		-- All five slots side by side, so none hides behind the ability buttons
		-- (VIP's salute button may push the narrowest phone into scrolling).
		if not loadout.vip or screen.w >= 700 then
			check(5 * L.cardW + 4 * 7 + 14 <= L.heroCards.w, tag .. ": all five hero slots fit without scrolling, band " .. L.heroCards.w .. " slot " .. L.cardW)
		end
		check(L.placement.h - 12 >= 48, tag .. ": confirm and cancel are thumb-sized")
		check(L.waveInfo.w >= 120, tag .. ": the threat banner keeps room to be read, got " .. L.waveInfo.w)
	end
end

--==============================================================================
-- Battle protocol chooser
--==============================================================================
print("--- protocol ---")
for _, screen in ipairs(SCREENS) do
	local P = UI.protocolLayout(screen.w, screen.h)
	local tag = screen.name .. " " .. screen.w .. "x" .. screen.h
	check(inside(P.panel, screen.w, screen.h), tag .. ": the protocol panel fits the screen " .. describe(P.panel))
	for index = 1, 3 do
		check(within(P.cards[index], P.panel), tag .. ": card " .. index .. " sits inside the panel")
		check(within(P.buttons[index], P.cards[index]), tag .. ": CHOOSE " .. index .. " sits inside its card")
		check(inside(P.buttons[index], screen.w, screen.h), tag .. ": CHOOSE " .. index .. " is reachable on screen")
		check(P.buttons[index].h >= 48, tag .. ": CHOOSE " .. index .. " is tappable")
		check(P.descriptions[index].h >= 42, tag .. ": card " .. index .. " keeps at least three lines for its effect and tradeoff")
		for other = index + 1, 3 do
			check(not overlaps(P.cards[index], P.cards[other]), tag .. ": cards " .. index .. " and " .. other .. " do not overlap")
		end
	end
end

--==============================================================================
-- Lobby HUD
--==============================================================================
print("--- lobby hud ---")
for _, screen in ipairs(SCREENS) do
	local H = UI.lobbyLayout(screen.w, screen.h)
	local tag = screen.name .. " " .. screen.w .. "x" .. screen.h
	for _, name in ipairs({ "pill", "squad", "settings", "navigation", "elevator", "hint", "context", "contextRiding" }) do
		check(inside(H[name], screen.w, screen.h), tag .. ": lobby " .. name .. " stays on screen " .. describe(H[name]))
	end
	for _, corner in ipairs({ "pill", "squad", "settings" }) do
		if not H.class.short then
			check(not overlaps(H.context, H[corner]), tag .. ": a contextual panel never covers the " .. corner)
		end
		check(not overlaps(H.elevator, H[corner]), tag .. ": the elevator card never covers the " .. corner)
		check(not overlaps(H.navigation, H[corner]), tag .. ": navigation stays clear of " .. corner)
	end
	check(not overlaps(H.contextRiding, H.elevator), tag .. ": while riding, a panel stops above the elevator card")
	check(H.context.h >= 140, tag .. ": a contextual panel keeps usable height, got " .. H.context.h)
	check(H.contextRiding.h >= 120, tag .. ": a panel opened while riding keeps usable height, got " .. H.contextRiding.h)
	check(H.elevator.h >= 80, tag .. ": the elevator card fits its countdown and Leave button")
	-- A campaign car is taller (its row of difficulties) and still fits.
	local D = UI.lobbyLayout(screen.w, screen.h, { difficulty = true })
	check(inside(D.elevator, screen.w, screen.h) and (D.class.short or D.elevator.h >= H.elevator.h + UI.difficultyRowH(D.class)), tag .. ": the campaign card fits its difficulty row on screen " .. describe(D.elevator))
	for _, corner in ipairs({ "pill", "squad", "settings" }) do
		check(not overlaps(D.elevator, D[corner]), tag .. ": the campaign card never covers the " .. corner)
	end
	local DP = UI.contextLayout(screen.w, screen.h, { elevator = true, difficulty = true })
	check(not overlaps(DP, D.elevator) and DP.h - 72 >= 100, tag .. ": a panel opened in a campaign car stops above it and stays usable, got h " .. DP.h)
	-- Inventory and progression now have persistent, labelled navigation;
	-- keep its width bounded so it does not become four giant desktop strips.
	check(H.navigation.h >= 48 and H.navigation.w <= 720, tag .. ": navigation is tappable and bounded on desktop")
	local covered = H.pill.w * H.pill.h + H.squad.w * H.squad.h + H.settings.w * H.settings.h + H.navigation.w * H.navigation.h
	check(covered <= screen.w * screen.h * 0.23, tag .. ": at least 77% of the idle view remains world space")
	for _, wide in ipairs({false, true}) do
		for _, riding in ipairs({false, true}) do
			local P = UI.contextLayout(screen.w, screen.h, {wide = wide, elevator = riding})
			local label = tag .. (wide and " talent tree" or " inventory") .. (riding and " while boarding" or "")
			check(inside(P, screen.w, screen.h), label .. ": sheet stays on screen")
			check(P.h - 72 >= 100, label .. ": header and close button leave readable scrolling content")
			if riding then check(not overlaps(P, H.elevator), label .. ": countdown and Leave remain reachable") end
			if P.modal then
				check(H.class.short and P.y <= 14, label .. ": modal sheet reclaims the hidden top chrome")
			else
				for _, chrome in ipairs({"pill", "squad", "settings", "navigation"}) do
					check(not overlaps(P, H[chrome]), label .. ": panel leaves " .. chrome .. " accessible")
				end
			end
		end
	end
end

--==============================================================================
-- Number formatting is what the gold counter actually renders
--==============================================================================
print("--- formatting ---")
check(UI.format(0) == "0", "zero formats plainly")
check(UI.format(1234) == "1.234", "thousands use the Brazilian separator, got " .. UI.format(1234))
check(UI.format(1234567) == "1.234.567", "millions group correctly, got " .. UI.format(1234567))
check(UI.format(-4321) == "-4.321", "negatives keep their sign, got " .. UI.format(-4321))
check(UI.format(nil) == "0", "a missing amount formats as zero")

print(string.format("%s ui layout: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("ui layout failed", 0) end
