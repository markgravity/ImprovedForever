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

-- Our quest objects' data load (Tracker/Blizzard_Quest.lua), never the
-- game's shared QuestEventListener: it keeps one callback list per quest
-- and runs it in a row, so the game's callbacks after ours would run
-- tainted, filling the game's quest objects its tracker reads (closing its
-- gamepad focus gets forbidden). A quest in the log has its data: the
-- callback runs now. Else asked for, run when it arrives (from the server,
-- so never inside our call).
local questLoads = {}
local questLoader = CreateFrame("Frame")
questLoader:SetScript("OnEvent", function(_, _, questID, success)
	local list = questLoads[questID]
	if not list then return end
	questLoads[questID] = nil
	if success then
		for _, callback in ipairs(list) do
			xpcall(callback, CallErrorHandler)
		end
	end
end)
questLoader:RegisterEvent("QUEST_DATA_LOAD_RESULT")

IFQuestEventListener = {}
function IFQuestEventListener:AddCallback(questID, callback)
	if HaveQuestData(questID) then
		callback()
		return
	end
	local list = questLoads[questID]
	if not list then
		list = {}
		questLoads[questID] = list
	end
	list[#list + 1] = callback
	if #list == 1 then
		C_QuestLog.RequestLoadQuestByID(questID)
	end
end

-- fn once both PLAYER_ENTERING_WORLD and VARIABLES_LOADED have come (and a
-- frame after: the game's tracker set up by then). Never the game's
-- EventUtil.ContinueAfterAllEvents: its EventRegistry counts each event's
-- registrations in an attribute of a shared frame, which ours would write
-- (unregistering on the event): the game's own waiter, ObjectiveTracker-
-- Manager:Init's, then reads it and sets the whole tracker up tainted
-- (closing its gamepad focus forbidden). Sessions where ours ran first.
local afterLoad, loadEvents = {}, { PLAYER_ENTERING_WORLD = false, VARIABLES_LOADED = false }
local loadWaiter = CreateFrame("Frame")
loadWaiter:RegisterEvent("PLAYER_ENTERING_WORLD")
loadWaiter:RegisterEvent("VARIABLES_LOADED")
loadWaiter:SetScript("OnEvent", function(self, event)
	loadEvents[event] = true
	if not (loadEvents.PLAYER_ENTERING_WORLD and loadEvents.VARIABLES_LOADED) then return end
	self:UnregisterAllEvents()
	C_Timer.After(0, function()
		for _, fn in ipairs(afterLoad) do fn() end
		afterLoad = nil
	end)
end)

function IQT.AfterLoad(fn)
	if afterLoad then
		afterLoad[#afterLoad + 1] = fn
	else
		fn()
	end
end
-- (the fork's: tools/fork_objective_tracker.py)
IFObjectiveTrackerAfterLoad = IQT.AfterLoad

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
	-- (the taint bisect's switches and the watch order probe's log, gone)
	if ImprovedForeverDB then
		ImprovedForeverDB.qtBisect = nil
		ImprovedForeverDB.qtOrderLog = nil
		ImprovedForeverDB.qtTaintLog = nil
	end
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
