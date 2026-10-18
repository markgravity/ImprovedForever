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
		native:HookScript("OnSizeChanged", function() frame:UpdateHeight() end)
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

-- (its bottom kept FLOOR_GAP above the Interface module's spell diamonds,
-- when they're under it: ImprovedForever_Interface's GamepadBar.Rect, in
-- screen pixels; the container fits what it has into the height left, as
-- the game's does)
local FLOOR_GAP, MIN_HEIGHT = 12, 80
local function Room(frame)
	local IF = _G.ImprovedForever
	local GB = IF and IF.Interface and IF.Interface.GamepadBar
	if not (GB and GB.Rect) then return nil end
	local l, _, r, t = GB.Rect()
	local fl, top, fr = frame:GetLeft(), frame:GetTop(), frame:GetRight()
	if not (l and fl and top and fr) then return nil end
	local k = frame:GetEffectiveScale()
	if fr * k <= l or fl * k >= r then return nil end
	return math.max(MIN_HEIGHT, (top * k - t) / k - FLOOR_GAP)
end

function M:UpdateHeight()
	local native = ObjectiveTrackerFrame
	local height = native and native:GetHeight()
	if height and height > 0 then
		local room = Room(self)
		if room and room < height then height = room end
		if math.abs((self:GetHeight() or 0) - height) > 0.5 then
			self:SetHeight(height)
		end
	end
end

-- (the diamonds come and go, the tracker moves: its height looked at
-- again now and then, by a frame of ours)
local heightWatch = CreateFrame("Frame")
local heightWait = 0
heightWatch:SetScript("OnUpdate", function(_, elapsed)
	heightWait = heightWait + elapsed
	if heightWait < 0.5 then return end
	heightWait = 0
	local frame = _G.IFObjectiveTrackerFrame
	if frame and frame.UpdateHeight then frame:UpdateHeight() end
end)
