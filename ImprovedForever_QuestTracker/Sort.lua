local _, IQT = ...

-- The order our tracker shows the quests in. Its quest module builds its
-- list of tracked quests (BuildQuestWatchInfos, in the game's watch order)
-- and lays them out in that order (Tracker/Patch.lua): here the list is
-- sorted as the settings say, before the layout. The game's watch list is
-- never changed.

local tsort = table.sort
local strlower = string.lower

-- Squared distance to the quest's POI; quests off this continent or without
-- a POI sort last.
local function DistanceTo(questID)
	if not C_QuestLog.GetDistanceSqToQuest then return math.huge end
	local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
	if distanceSq and onContinent then
		return distanceSq
	end
	return math.huge
end

-- The quest log's zone headers, by questID
local function ZoneHeaders()
	local headers, current = {}, nil
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info then
			if info.isHeader then
				current = info.title
			elseif info.questID then
				headers[info.questID] = { zone = current, info = info }
			end
		end
	end
	return headers
end

-- What the sort needs of a quest
local function Describe(questID, headers, playerZone, money)
	local entry = headers[questID] or {}
	local info = entry.info
	local zone = entry.zone or ""
	local title = (info and info.title) or C_QuestLog.GetTitleForQuestID(questID) or ""
	local completed = C_QuestLog.IsComplete(questID) or C_QuestLog.ReadyForTurnIn(questID)
	-- Like WatchFrame / Kaliel's Tracker: no objectives = ready to hand in
	local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
	if not completed and logIndex and GetNumQuestLeaderBoards(logIndex) == 0
			and money >= (C_QuestLog.GetRequiredMoney(questID) or 0)
			and not (info and info.startEvent) then
		completed = true
	end
	return {
		questID = questID,
		title = strlower(title),
		level = info and (info.level or info.difficultyLevel) or 0,
		zone = zone,
		inZone = (zone == playerZone) or (info and info.isOnMap) and true or false,
		distance = IQT.Settings().sort == "distance" and DistanceTo(questID) or math.huge,
		completed = completed and true or false,
	}
end

local function ByTitle(a, b)
	if a.title ~= b.title then
		return a.title < b.title
	end
	return a.questID < b.questID
end

local COMPARATORS = {
	zone = function(a, b)
		if IQT.Settings().currentZoneFirst and a.inZone ~= b.inZone then
			return a.inZone
		end
		if a.zone ~= b.zone then
			return a.zone < b.zone
		end
		if a.level ~= b.level then
			return a.level < b.level
		end
		return ByTitle(a, b)
	end,
	level = function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		return ByTitle(a, b)
	end,
	levelReversed = function(a, b)
		if a.level ~= b.level then
			return a.level > b.level
		end
		return ByTitle(a, b)
	end,
	title = ByTitle,
	distance = function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return ByTitle(a, b)
	end,
}

-- infos: the quest module's list ({ quest, index }), in the game's order;
-- sorted in place as the settings say
function IQT.SortWatchInfos(infos)
	if not IQT.IsActive() or #infos < 2 then return infos end
	local db = IQT.Settings()
	local headers, playerZone, money = ZoneHeaders(), GetRealZoneText() or "", GetMoney()
	local described = {}
	for i, info in ipairs(infos) do
		local d = Describe(info.quest:GetID(), headers, playerZone, money)
		d.info, d.order = info, i
		described[i] = d
	end

	local cmp = COMPARATORS[db.sort]
	local focused = db.focusFirst and IQT.FocusedQuestID()
	-- (stable: ties keep the game's order)
	tsort(described, function(a, b)
		if focused and (a.questID == focused) ~= (b.questID == focused) then
			return a.questID == focused
		end
		if db.sortCompleted ~= "none" and a.completed ~= b.completed then
			if db.sortCompleted == "top" then return a.completed end
			return b.completed
		end
		if cmp and cmp(a, b) ~= cmp(b, a) then
			return cmp(a, b)
		end
		return a.order < b.order
	end)
	for i, d in ipairs(described) do
		infos[i] = d.info
	end
	return infos
end

function IQT.SetSort(id)
	IQT.Settings().sort = id
	IQT.Refresh()
end

function IQT.SetSortCompleted(id)
	IQT.Settings().sortCompleted = id
	IQT.Refresh()
end

function IQT.SetFocusFirst(on)
	IQT.Settings().focusFirst = on and true or false
	IQT.Refresh()
end

function IQT.SetCurrentZoneFirst(on)
	IQT.Settings().currentZoneFirst = on and true or false
	IQT.Refresh()
end

-- Tracked quests, in the order shown, with whether the tracker shows them
function IQT.Debug()
	local module = IFQuestObjectiveTracker
	if not module then
		IQT.Print("tracker not loaded")
		return
	end
	local infos = module:BuildQuestWatchInfos()
	IQT.Print(("watches %d, shown %s, collapsed %s, skipped %s"):format(C_QuestLog.GetNumQuestWatches(),
		tostring(IFObjectiveTrackerFrame:IsShown()), tostring(module:IsCollapsed()), tostring(module:HasSkippedBlocks())))
	for i, info in ipairs(infos) do
		local questID = info.quest:GetID()
		local block = module:GetExistingBlock(questID)
		IQT.Print(("%d. %s [%d] shown=%s"):format(i, C_QuestLog.GetTitleForQuestID(questID) or "?", questID,
			tostring(block and block:IsShown() or false)))
	end
end
