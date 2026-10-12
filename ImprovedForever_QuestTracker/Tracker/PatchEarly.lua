-- Our copy of the tracker's frame (the forked Blizzard_ObjectiveTracker.lua),
-- changed before its XML makes it (Blizzard_ObjectiveTracker.xml, next in
-- the TOC): it sits over the game's tracker, its size (that one, unseen,
-- stays for Edit Mode to place and size, and for the game's gamepad focus:
-- Patch.lua), and the game's gamepad navigation (SmartNavigation, the frame
-- manager) is never touched: ours is Pad.lua.
local _, IQT = ...

local M = IFObjectiveTrackerFrameMixin

-- Ours is in this (hidden while Edit Mode shows the game's: Patch.lua)
IQT.holder = CreateFrame("Frame", nil, nil)
IQT.holder:SetParent(UIParent)
IQT.holder:SetAllPoints(UIParent)

-- Where the game's tracker is, its size (Edit Mode moves and sizes that one)
function IQT.PlaceTracker(frame)
	local native = ObjectiveTrackerFrame
	frame:SetParent(IQT.holder)
	frame:ClearAllPoints()
	if native then
		-- (above it: its unseen buttons under ours never get the mouse)
		frame:SetFrameStrata(native:GetFrameStrata())
		frame:SetFrameLevel(native:GetFrameLevel() + 30)
		frame:SetPoint("TOPLEFT", native, "TOPLEFT")
		frame:SetPoint("TOPRIGHT", native, "TOPRIGHT")
		if not IQT.Off("hooks") then
			native:HookScript("OnSizeChanged", function() frame:UpdateHeight() end)
		end
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -85, -180)
		frame:SetHeight(600)
	end
end

function M:OnLoad()
	IFObjectiveTrackerContainerMixin.OnLoad(self)
	-- (no events: the game's tracker still watches new quests and sorts
	-- its watches)
	IQT.PlaceTracker(self)
end

function M:OnEvent()
end

function M:Update(dirtyUpdate)
	if not self:ShouldShowHeader() then
		self.Header:Hide()
		return false
	end
	self.Header:Show()
	local retValue = IFObjectiveTrackerContainerMixin.Update(self, dirtyUpdate)
	self:UpdateHeaderPosition()
	if IQT.OnTrackerUpdate then
		IQT.OnTrackerUpdate()
	end
	return retValue
end

-- Placed and sized by the game's tracker, never by the managed frames
function M:IsInDefaultPosition()
	return false
end

function M:UpdateHeight()
	local native = ObjectiveTrackerFrame
	local height = native and native:GetHeight()
	if height and height > 0 then
		self:SetHeight(height)
	end
end
