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

local function Stop()
	if not mirroring then return end
	mirroring, pointed = false, nil
	if cursor then cursor:Hide() end
	HidePointer(false)
	PadOrder(false)
end

mirror:SetScript("OnUpdate", function()
	if not NativeFocused() or not IFObjectiveTrackerFrame:IsVisible() then
		return Stop()
	end
	mirroring = true
	PadOrder(true)
	local nav = _G.SmartNavigation
	local ok, current = pcall(function() return nav and nav:GetCurrentButton() end)
	local target = ok and Target(current) or nil
	if target and target:IsVisible() then
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
