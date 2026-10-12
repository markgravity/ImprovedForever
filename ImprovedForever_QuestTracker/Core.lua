-- Improved Forever: Quest Tracker. The game's objective tracker, replaced by
-- our own copy of it (Tracker/: the game's own code and templates, forked by
-- tools/fork_objective_tracker.py), so it looks and works the same, and
-- what we add needs nothing of the game's changed:
--   sorting (Sort.lua): the order the quests show in
--   a sound when a tracked quest's objective completes (ObjectiveSound.lua)
--   menus as the game's (Dropdown.lua, Tracker/Menu.lua)
--   the controller (Tracker/Pad.lua), quest items (Tracker/Items.lua)
-- set up in its tab (QuestTrackerEditor.lua). Its files share this addon's
-- own table (IQT), left to the other modules as IF.QuestTracker.
local addonName, IQT = ...
local IF = ImprovedForever

IQT.name = addonName
IF.QuestTracker = IQT
IF.AddModule({ key = "quests", label = "Quest Tracker", icon = IF.TEX .. "ic_mod_quests", addon = addonName })

-- Our copy uses the game's tracker fonts (Edit Mode's text size) and is
-- placed over the game's own: both must be there before Tracker/'s XML
if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker") then
	pcall(C_AddOns.LoadAddOn, "Blizzard_ObjectiveTracker")
end

-- Our tracker's own caches, never the game's shared ones (QuestCache,
-- QuestUtil's group cache): an entry made first by our code is tainted,
-- and the game's tracker reading it taints its gamepad focus (closing it
-- gets SetPreferredGamepadInteractTarget forbidden). The fork calls these
-- instead (tools/fork_objective_tracker.py): IFQuestCache is made in
-- Tracker/Blizzard_Quest.lua (the game's quest object, copied).

local canCreateGroup = {}
function IFCanCreateQuestGroup(questID)
	local can = canCreateGroup[questID]
	if can == nil then
		can = C_LFGList and C_LFGList.CanCreateQuestGroup and C_LFGList.CanCreateQuestGroup(questID) or false
		canCreateGroup[questID] = can
	end
	return can
end

-- Sort modes ("none": the game's own order)
IQT.SORTS = {
	{ id = "none",          text = "Off (Blizzard sort)" },
	{ id = "zone",          text = "by Zone" },
	{ id = "level",         text = "by Level" },
	{ id = "levelReversed", text = "by Level (reversed)" },
	{ id = "title",         text = "by Title" },
	{ id = "distance",      text = "by Distance" },
}

IQT.COMPLETED = {
	{ id = "none",   text = "Keep in place" },
	{ id = "top",    text = "Completed at top" },
	{ id = "bottom", text = "Completed at bottom" },
}

local DEFAULTS = {
	sort = "none",
	sortCompleted = "none",
	currentZoneFirst = true,
	objectiveSound = true,
	focusFirst = true,
}

-- Per character, in Improved Forever's own (IF.charDB.questTracker)
function IQT.Settings()
	IF.charDB.questTracker = IF.charDB.questTracker or {}
	local db = IF.charDB.questTracker
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then
			db[k] = v
		end
	end
	return db
end

function IQT.Print(msg)
	IF.Print("Quest Tracker: " .. msg)
end

function IQT.IsActive()
	local db = IQT.Settings()
	return db.sort ~= "none" or db.sortCompleted ~= "none" or db.focusFirst
end

-- The focused (super-tracked) quest
function IQT.FocusedQuestID()
	local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	return id ~= 0 and id or nil
end

-- Lay our tracker out again (after a setting changed)
function IQT.Refresh()
	if IFObjectiveTrackerManager then
		IFObjectiveTrackerManager:UpdateAll()
	end
end

-- (a sort that moves as you do: the distance one)
local ticker
local function Login()
	IQT.Settings()
	-- (the taint bisect's switches, gone)
	if ImprovedForeverDB then ImprovedForeverDB.qtBisect = nil end
	if not C_QuestLog.GetDistanceSqToQuest then
		for i, entry in ipairs(IQT.SORTS) do
			if entry.id == "distance" then
				tremove(IQT.SORTS, i)
				break
			end
		end
		if IQT.Settings().sort == "distance" then
			IQT.Settings().sort = "none"
		end
	end
	IQT.InitObjectiveSound()
	ticker = ticker or C_Timer.NewTicker(2, function()
		if IQT.Settings().sort == "distance" and IFObjectiveTrackerFrame and IFObjectiveTrackerFrame:IsVisible() then
			IFQuestObjectiveTracker:MarkDirty()
		end
	end)
end
IF.OnLogin(Login)
