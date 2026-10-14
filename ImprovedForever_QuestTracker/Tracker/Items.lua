local _, IQT = ...

-- Quest items: the tracker's item button (the fork's, drawn as the game's:
-- icon, count, cooldown, range, glow) gets a secure button over it that
-- uses the item, as only a secure click can. The secure ones are ours, not
-- in the tracker (a secure frame in it would lock the tracker's layout in
-- combat): kept over theirs out of combat; when combat starts, left where
-- they are on screen (the tracker can move under them) until it ends.
-- The pad's A on an item clicks its secure button (Pad.lua).
local Items = {}
IQT.Items = Items

local pool, active = {}, {}   -- active: item button -> secure button
local ITEM_MODULES = { "IFQuestObjectiveTracker", "IFCampaignQuestObjectiveTracker",
	"IFBonusObjectiveTracker", "IFWorldQuestObjectiveTracker" }
local count = 0

local function NewSecure()
	count = count + 1
	local b = CreateFrame("Button", "ImprovedForeverTrackerItem" .. count, nil, "SecureActionButtonTemplate")
	b:SetParent(UIParent)
	b:SetFrameStrata("LOW")
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("type", "item")
	local highlight = b:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints()
	b:SetScript("OnEnter", function(self)
		if self.visual and self.visual:IsVisible() then self.visual:OnEnter() end
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	-- (a shift-click links it, as the game's: the visual's own click)
	b:SetScript("PreClick", function(self, mouse)
		if self.visual and IsModifiedClick("CHATLINK") then self.visual:OnClick(mouse) end
	end)
	return b
end

local function ItemOf(visual)
	local index = visual:GetAttribute("questLogIndex")
	local link = index and GetQuestLogSpecialItemInfo(index)
	local itemID = link and C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
	return itemID and ("item:" .. itemID) or link
end

local function Attach(visual)
	local b = active[visual]
	if not b then
		b = tremove(pool) or NewSecure()
		active[visual] = b
		b.visual = visual
	end
	b:SetAttribute("item", ItemOf(visual))
	b:ClearAllPoints()
	b:SetAllPoints(visual)
	b:SetFrameLevel(visual:GetFrameLevel() + 10)
	b:Show()
	visual:EnableMouse(false)
end

local function Detach(visual)
	local b = active[visual]
	if not b then return end
	active[visual] = nil
	b.visual = nil
	b:Hide()
	b:ClearAllPoints()
	b:SetAttribute("item", nil)
	pool[#pool + 1] = b
end

-- Every shown item button with its secure button over it (out of combat)
function Items.Sync()
	if InCombatLockdown() then
		Items.pending = true
		return
	end
	Items.pending = nil
	local shown = {}
	-- (every module that shows quest items: the quests', the campaign's,
	-- the bonus objectives' and world quests')
	for _, name in ipairs(ITEM_MODULES) do
		local module = _G[name]
		for _, frame in pairs(module and module.usedRightEdgeFrames or {}) do
			if frame.template == "IFQuestObjectiveItemButtonTemplate" and frame:IsVisible() then
				shown[frame] = true
				Attach(frame)
			end
		end
	end
	for visual in pairs(active) do
		if not shown[visual] then Detach(visual) end
	end
end

-- The secure button over an item button (for the pad)
function Items.SecureFor(visual)
	local b = visual and active[visual]
	return b and b:IsShown() and b:GetName() or nil
end

-- Combat: left where they are on screen
local function Pin()
	local scale = UIParent:GetEffectiveScale()
	for visual, b in pairs(active) do
		local left, bottom, width, height = visual:GetRect()
		if left then
			local k = visual:GetEffectiveScale() / scale
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * k, bottom * k)
			b:SetSize(width * k, height * k)
		end
	end
end

-- The tracker's own click uses nothing (ours does): a link only
local OnClick = IFQuestObjectiveItemButtonMixin.OnClick
function IFQuestObjectiveItemButtonMixin:OnClick(button)
	if IsModifiedClick("CHATLINK") and ChatFrameUtil.GetActiveWindow() then
		return OnClick(self, button)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (still allowed here)
		Pin()
	else
		Items.Sync()
	end
end)
