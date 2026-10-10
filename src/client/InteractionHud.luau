-- Shared presentation for live interactions and the Studio review fixtures.
-- No rewards or connection state are created here: the controller supplies them.
local InteractionHud = {}

function InteractionHud.afk(UI, parent, width, T, callbacks)
	local C = UI.Colors
	callbacks = callbacks or {}
	local banner = UI.roundFrame(parent, {Name = "AfkBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(width, 74), BackgroundColor3 = C.background}, C.gold)
	UI.windowSkin(banner, C.gold)
	local title = UI.fit(UI.label(banner, "", {Name = "AfkTitle", Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -120, 0, 30), TextSize = 22, Font = UI.Fonts.display}), 12)
	local detail = UI.fit(UI.label(banner, "", {Name = "AfkDetail", Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -120, 0, 32), TextSize = 16, TextWrapped = true, Font = UI.Fonts.body, TextColor3 = C.cream}), 11)
	local travel = UI.button(banner, T("Servidor AFK", "AFK server"), callbacks.travel, {Name = "AfkServerGo", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -104, 1, -6), Size = UDim2.fromOffset(120, 40), BackgroundColor3 = C.violet, TextSize = 14, Visible = false})
	UI.button(banner, T("Economia", "Saver"), callbacks.saver, {Name = "AfkEcoOn", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 11), Size = UDim2.fromOffset(92, 44), BackgroundColor3 = C.blue, TextSize = 13})
	local function setTravel(visible)
		travel.Visible = visible
		banner.Size = UDim2.fromOffset(width, visible and 120 or 74)
	end
	return {banner = banner, title = title, detail = detail, travel = travel, setTravel = setTravel}
end

function InteractionHud.prompt(UI, parent, objectText, actionText, key, activate)
	local C = UI.Colors
	local panel = UI.roundFrame(parent, {Name = "PromptPanel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background}, C.gold)
	UI.windowSkin(panel, C.gold)
	UI.stroke(panel, C.gold, 2.5)
	local cap = UI.frame(panel, {Name = "PromptKey", Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = C.gold})
	UI.corner(cap, 12)
	UI.stroke(cap, C.ink, 2.5)
	UI.angular(cap, C.cream, {cut=8})
	UI.oneLine(UI.label(cap, key, {Size = UDim2.fromScale(1, 1), TextSize = #key > 1 and 18 or 28, Font = UI.Fonts.display, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Center}), 10)
	UI.fit(UI.label(panel, objectText, {Name = "PromptObject", Position = UDim2.fromOffset(68, 6), Size = UDim2.new(1, -78, 0, 22), TextSize = 16, Font = UI.Fonts.display, TextColor3 = C.muted}), 10)
	UI.fit(UI.label(panel, actionText, {Name = "PromptAction", Position = UDim2.fromOffset(68, 28), Size = UDim2.new(1, -78, 0, 32), TextSize = 24, Font = UI.Fonts.display}), 12)
	UI.button(panel, "", activate, {Name = "PromptHit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5})
	return panel
end

return InteractionHud
