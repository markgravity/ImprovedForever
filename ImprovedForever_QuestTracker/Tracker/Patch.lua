local _, IQT = ...
local IF = ImprovedForever

-- Our tracker in the game's place:
-- * The game's tracker keeps running, unseen (its header, background and
--   modules drawn at alpha 0 by an animation of ours; never hidden, never
--   a property of its frames set: that taints), under ours: Edit Mode places and sizes it, ours
--   follows (PatchEarly.lua); the game's gamepad focus still goes to it
--   (the shortcuts bar's D-pad Up), its navigation and legend the game's,
--   ours showing where its cursor is (Pad.lua). Ours catches the mouse over its whole box, so the unseen
--   one under it never gets a click. In Edit Mode, the game's shows and
--   ours hides, to be moved as ever.
-- * Edit Mode's opacity and text size: the game's tracker's, followed (the
--   fonts are the same: ours inherit the game's tracker fonts).
-- * The quests in our order (Sort.lua), the sort menu's button on the
--   Quests header, the quest items' secure buttons (Items.lua).

local function EditMode()
	return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() or false
end

-- The game's tracker's parts we hide (the quest timer stays). Never by
-- their alpha (SetAlpha): a property of the game's frames set from addon
-- code taints its gamepad focus (closing it gets forbidden): IF.Focus.Fade,
-- an animation of ours, draws them at 0, their own alpha untouched.
local function NativeParts()
	local native = ObjectiveTrackerFrame
	local parts = { native.Header, native.NineSlice }
	for _, module in ipairs(native.modules or {}) do
		parts[#parts + 1] = module
	end
	return parts
end

local function Watch()
	local native = ObjectiveTrackerFrame
	if not native then return end
	local edit = EditMode()
	-- (ours hidden in Edit Mode; its animations too, so the game's shows)
	IQT.holder:SetShown(not edit)
	-- (above it, its unseen buttons under ours: the managed frames may
	-- re-parent it, its level with it)
	local ours = IFObjectiveTrackerFrame
	if ours:GetFrameLevel() < native:GetFrameLevel() + 30 then
		ours:SetFrameLevel(native:GetFrameLevel() + 30)
	end
	for _, part in ipairs(NativeParts()) do
		IF.Focus.Fade(part, not edit)
	end
end

if ObjectiveTrackerFrame then
	local watcher = CreateFrame("Frame")
	local since = 0
	watcher:SetScript("OnUpdate", function(_, elapsed)
		since = since + elapsed
		if since < 0.1 then return end
		since = 0
		Watch()
	end)
end

-- The mouse over our tracker's box (the game's unseen one is under it)
local blocker = CreateFrame("Frame", nil, nil)
blocker:SetParent(IFObjectiveTrackerFrame)
blocker:SetPoint("TOPLEFT", IFObjectiveTrackerFrame.NineSlice, "TOPLEFT")
blocker:SetPoint("BOTTOMRIGHT", IFObjectiveTrackerFrame.NineSlice, "BOTTOMRIGHT")
blocker:SetFrameLevel(IFObjectiveTrackerFrame:GetFrameLevel())
blocker:EnableMouse(true)
blocker:SetMouseMotionEnabled(true)

-- And over the game's unseen box: it isn't told of a collapse on ours
-- (Pad.lua), so where ours is shorter its quests would still take the
-- mouse (a tooltip, a click opening the map, a shift-click untracking).
-- Only anchored to it: none of its frames' properties set.
if ObjectiveTrackerFrame and ObjectiveTrackerFrame.NineSlice then
	local under = CreateFrame("Frame", nil, nil)
	under:SetParent(IFObjectiveTrackerFrame)
	under:SetPoint("TOPLEFT", ObjectiveTrackerFrame.NineSlice, "TOPLEFT")
	under:SetPoint("BOTTOMRIGHT", ObjectiveTrackerFrame.NineSlice, "BOTTOMRIGHT")
	under:SetFrameLevel(IFObjectiveTrackerFrame:GetFrameLevel())
	under:EnableMouse(true)
	under:SetMouseMotionEnabled(true)
	IQT.nativeBlocker = under
end

-- Edit Mode's opacity, as the game's tracker has it
local function MirrorOpacity()
	local alpha = ObjectiveTrackerManager and ObjectiveTrackerManager.backgroundAlpha
	if alpha then
		IFObjectiveTrackerManager:SetOpacity(alpha * 100)
	end
end

if ObjectiveTrackerManager then
	hooksecurefunc(ObjectiveTrackerManager, "SetOpacity", MirrorOpacity)
	-- (the fonts already changed: lay ours out again)
	hooksecurefunc(ObjectiveTrackerManager, "SetTextSize", function() IFObjectiveTrackerManager:UpdateAll() end)
	IQT.AfterLoad(MirrorOpacity)
end

-- The quests in our order (held while the game's tracker has the pad:
-- Pad.lua), the game's watch list kept in it (Sort.lua: SyncWatchOrder)
for _, module in ipairs({ IFQuestObjectiveTracker, IFCampaignQuestObjectiveTracker }) do
	local Build = module.BuildQuestWatchInfos
	module.BuildQuestWatchInfos = function(self)
		return IQT.SortWatchInfos(Build(self), self)
	end
	-- (/if quests debug rows: each quest's place and distance on its header)
	local GetBlock = module.GetBlock
	module.GetBlock = function(self, ...)
		local block, isExisting = GetBlock(self, ...)
		if block and not block.iqtSetHeader then
			block.iqtSetHeader = block.SetHeader
			block.SetHeader = function(b, text)
				if IQT.debugRows and b.id then
					text = text .. " " .. IQT.DebugTag(b.id)
				end
				return b.iqtSetHeader(b, text)
			end
		end
		return block, isExisting
	end
end

-- The sort menu's button: on the Quests header, left of its minimize
-- button, the tracker's own filter button art
local function SortButton()
	local header = IFQuestObjectiveTracker.Header
	local button = CreateFrame("Button", "ImprovedForeverQuestSortButton", nil, "IFObjectiveTrackerContainerFilterButtonTemplate")
	button:SetParent(header)
	button:SetHighlightAtlas("ui-questtrackerbutton-yellow-highlight", "ADD")
	button:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -2, 0)
	button:SetFrameLevel(header:GetFrameLevel() + 5)
	button:Show()
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnClick", function(self)
		GameTooltip:Hide()
		IQT.ToggleSortMenu(self)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Sort Quests")
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	IQT.sortButton = button
	-- (the header's add animation fades its minimize button in: this one too)
	header.AddAnim:HookScript("OnPlay", function() button:SetAlpha(0) end)
	header.AddAnim:HookScript("OnFinished", function() button:SetAlpha(1) end)
	header.AddAnim:HookScript("OnStop", function() button:SetAlpha(1) end)
end
SortButton()

-- After each layout: the items' secure buttons over them
function IQT.OnTrackerUpdate()
	IQT.Items.Sync()
	IQT.SyncWatchOrder()
end
