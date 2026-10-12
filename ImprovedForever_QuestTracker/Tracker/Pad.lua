local _, IQT = ...
local IF = ImprovedForever

-- The controller on our tracker: the game's own. The game's tracker runs
-- unseen under ours (Patch.lua) and keeps its gamepad focus: the shortcuts
-- bar's D-pad Up, its navigation, A / X / Y, quest items, L2 / R2, B and its
-- button legend are all the game's, untouched. Ours only shows where it is:
-- the game's cursor (SmartNavigation's pointer) is hidden while it's on the
-- game's tracker, and ours drawn on the same element of ours (the same
-- block, by its id). Nothing here takes a button or binds one: from addon
-- code either carries taint into the game's navigation (its window closing,
-- SetPreferredGamepadInteractTarget, gets forbidden).
-- The game's tracker lays its quests out in the watch order: while it has
-- the pad, ours shows them in that order too (our sort back after).
local Pad = {}
IQT.Pad = Pad

-- (the fork's quest menu gives the pad back with this on close: our menus
-- are the mouse's, the game's tracker has its own)
IFObjectiveTrackerPad = { FrameHidden = function() end }

-- Whether the game's (unseen) tracker has the game's gamepad focus
local function NativeFocused()
	local m = IF.Focus.Manager()
	return m and m.isUIFocused and m.focusedFrame ~= nil and m.focusedFrame == ObjectiveTrackerFrame or false
end

---------------------------------------------------------------------------
-- Ours for the game's: modules by name ("QuestObjectiveTracker" and ours,
-- "IFQuestObjectiveTracker"), blocks by template and id
---------------------------------------------------------------------------

local function Ours(native)
	local name = native and native.GetName and native:GetName()
	return name and _G["IF" .. name] or nil
end

local function OurBlock(native)
	local module = Ours(native.parentModule)
	local blocks = module and module.usedBlocks and module.usedBlocks["IF" .. tostring(native.template)]
	local block = blocks and blocks[native.id]
	return block and block:IsVisible() and block or nil
end

-- The game's quest item button's block
local function ItemBlock(item)
	for _, module in ipairs(ObjectiveTrackerFrame.modules or {}) do
		for _, blocks in pairs(module.usedBlocks or {}) do
			for _, block in pairs(blocks) do
				if block.ItemButton == item then return block end
			end
		end
	end
end

-- Our element for the game's focused one
local function Target(current)
	if not current then return nil end
	local parent = current:GetParent()
	if not parent then return nil end
	-- (a module's header, or the tracker's)
	if parent.Header == current then
		local ours = Ours(parent)
		return ours and ours.Header
	end
	-- (a block's POI button or title)
	if parent.parentModule and parent.id ~= nil then
		local block = OurBlock(parent)
		if not block then return nil end
		if current == parent.poiButton then return block.poiButton or block.HeaderButton or block end
		return block.HeaderButton or block
	end
	-- (a quest's item)
	local block = ItemBlock(current)
	block = block and OurBlock(block)
	return block and block.ItemButton
end

---------------------------------------------------------------------------
-- Drawn every frame while the game's tracker has the focus
---------------------------------------------------------------------------

local cursor, pointed
local mirroring = false
local mirror = CreateFrame("Frame")

local function Pointer()
	local nav = _G.SmartNavigation
	return nav and nav.Pointer
end

-- The game's cursor faded (IF.Focus.Fade: its alpha never set)
local function HidePointer(hide)
	IF.Focus.Fade(Pointer(), hide)
end

-- While the game's tracker has the pad, ours lists its quests in the
-- game's order (Patch.lua: no sort of ours), so the D-pad, the game's,
-- goes through them top to bottom
local function PadOrder(on)
	if IQT.padOrder == on then return end
	IQT.padOrder = on
	IQT.Refresh()
end

---------------------------------------------------------------------------
-- R3: our sort menu. Watched (IsKeyDown), never taken or bound: the game's
-- R3 still runs (its tooltips toggle); the menu takes the pad with its own
-- catcher (Dropdown.lua) and gives it back on B. Its prompt in the game's
-- legend (seemingly): our own glyph and words, not the game's templates.
---------------------------------------------------------------------------

local lastR3 = true     -- (counted only once seen up)

-- The prompt in the game's legend: the legend's own box (its background
-- and border) faded, ours drawn round its prompts and ours instead, so one
-- box shows; its prompts stay the game's (they follow what the cursor is
-- on). Laid out as the game's legend: 10 padding, 15 between prompts.
local LEGEND_PAD, PROMPT_GAP, ICON = 10, 15, 24
local box, boxParts

local function Box()
	if box then return box end
	box = CreateFrame("Frame", nil, nil)
	box:SetParent(UIParent)
	local slot = box:CreateTexture(nil, "BACKGROUND")
	slot:SetAllPoints()
	slot:SetAtlas("gamepad-footer-slot-bg")
	local border = box:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetAtlas("gamepad-footer-slot-frameneutral")
	local prompt = CreateFrame("Frame", nil, nil)
	prompt:SetParent(box)
	local icon = prompt:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON, ICON)
	icon:SetPoint("LEFT")
	box.icon = icon
	local text = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	text:SetText("Sort")
	box.text = text
	box.prompt = prompt
	box:Hide()
	return box
end

-- The game legend's box textures (its background and border)
local function LegendBox(legend)
	if boxParts and boxParts.legend == legend then return boxParts end
	boxParts = { legend = legend }
	-- (on the legend, or a frame of its: its prompts' holder)
	local frames = { legend }
	for _, child in ipairs({ legend:GetChildren() }) do frames[#frames + 1] = child end
	for _, frame in ipairs(frames) do
		for _, region in ipairs({ frame:GetRegions() }) do
			local atlas = region.GetAtlas and region:GetAtlas()
			if atlas and atlas:find("gamepad%-footer%-slot") then
				boxParts[#boxParts + 1] = region
			end
		end
	end
	return boxParts
end

local function Hint(show)
	local footer = ObjectiveTrackerFrame.gamepadFooter
	local legend = footer and footer.inputLegend
	if boxParts then
		for _, region in ipairs(boxParts) do IF.Focus.Fade(region, show and legend == boxParts.legend) end
	end
	if not show or not (legend and legend:IsVisible() and legend:GetLeft()) then
		if box then box:Hide() end
		return
	end
	local b = Box()
	local atlas = IF.GlyphAtlas and IF.GlyphAtlas("RS")
	if atlas then b.icon:SetAtlas(atlas) end
	b.prompt:SetSize(ICON + 4 + b.text:GetStringWidth(), ICON)
	b.prompt:ClearAllPoints()
	b.prompt:SetPoint("RIGHT", legend, "LEFT", LEGEND_PAD - PROMPT_GAP, 0)
	b:SetFrameStrata(legend:GetFrameStrata())
	b:SetFrameLevel(math.max(0, legend:GetFrameLevel() - 1))
	b:ClearAllPoints()
	b:SetPoint("TOP", legend, "TOP")
	b:SetPoint("BOTTOM", legend, "BOTTOM")
	b:SetPoint("LEFT", b.prompt, "LEFT", -LEGEND_PAD, 0)
	b:SetPoint("RIGHT", legend, "RIGHT")
	b:Show()
	for _, region in ipairs(LegendBox(legend)) do IF.Focus.Fade(region, true) end
end

local function WatchR3()
	local r3 = IsKeyDown and IsKeyDown("PADRSTICK") or false
	if r3 and not lastR3 and not InCombatLockdown() and not IQT.IsDropdownShown() then
		IQT.ToggleSortMenu(nil, { pad = true, anchor = pointed or IQT.sortButton,
			point = "TOPRIGHT", relativePoint = "TOPLEFT", x = -8, y = 0 })
	end
	lastR3 = r3
end

local function Stop()
	if not mirroring then return end
	mirroring, pointed = false, nil
	if cursor then cursor:Hide() end
	HidePointer(false)
	PadOrder(false)
	Hint(false)
	lastR3 = true
end

mirror:SetScript("OnUpdate", function()
	if not NativeFocused() or not IFObjectiveTrackerFrame:IsVisible() then
		return Stop()
	end
	mirroring = true
	PadOrder(true)
	WatchR3()
	Hint(not IQT.IsDropdownShown())
	local nav = _G.SmartNavigation
	local ok, current = pcall(function() return nav and nav:GetCurrentButton() end)
	local target = ok and Target(current) or nil
	-- (our menu open: the pad is there, its cursor with it)
	if IQT.IsDropdownShown() then
		pointed = nil
		if cursor then cursor:Hide() end
		HidePointer(true)
	elseif target and target:IsVisible() then
		cursor = cursor or IF.Focus.Cursor(IFObjectiveTrackerFrame)
		if target ~= pointed or not cursor:IsShown() then
			pointed = target
			cursor:Point(target)
		end
		-- (the game's cursor points at its unseen tracker: ours instead)
		HidePointer(true)
	else
		-- (nothing of ours there: the game's cursor as it is)
		pointed = nil
		if cursor then cursor:Hide() end
		HidePointer(false)
	end
end)

---------------------------------------------------------------------------
-- Collapsed as the game's: its A on a header minimizes the game's module,
-- ours follows (the other way, the mouse on ours, the game's can't be told)
---------------------------------------------------------------------------

local function FollowCollapse()
	local native = ObjectiveTrackerFrame
	if not native then return end
	local frames = { native }
	for _, module in ipairs(native.modules or {}) do frames[#frames + 1] = module end
	for _, frame in ipairs(frames) do
		local ours = Ours(frame)
		if ours and frame.SetCollapsed then
			hooksecurefunc(frame, "SetCollapsed", function(_, collapsed)
				if ours:IsCollapsed() ~= (collapsed and true or false) then
					ours:SetCollapsed(collapsed)
				end
			end)
		end
	end
end
EventUtil.ContinueAfterAllEvents(FollowCollapse, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
