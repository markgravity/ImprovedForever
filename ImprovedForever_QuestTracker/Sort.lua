local _, IQT = ...

-- The order our tracker shows the quests in. Its quest module builds its
-- list of tracked quests (BuildQuestWatchInfos, in the game's watch order)
-- and lays them out in that order (Tracker/Patch.lua): here the list is
-- sorted as the settings say, before the layout. The game's watch list is
-- then put in the same order (SyncWatchOrder): its tracker, unseen under
-- ours, lays its quests out in that order, and the game's D-pad goes
-- through them top to bottom. While it has the pad, our order is held
-- (Tracker/Pad.lua): the rows still under the cursor, no re-sync.

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

-- Each module's quests, in our order (questIDs), for SyncWatchOrder
IQT.sortedIDs = {}

-- infos: the module's list ({ quest, index }), in the game's order;
-- sorted in place as the settings say
function IQT.SortWatchInfos(infos, module)
	if not IQT.IsActive() or #infos < 2 then
		IQT.sortedIDs[module] = nil
		return infos
	end
	local db = IQT.Settings()
	local headers, playerZone, money = ZoneHeaders(), GetRealZoneText() or "", GetMoney()
	local described = {}
	for i, info in ipairs(infos) do
		local d = Describe(info.quest:GetID(), headers, playerZone, money)
		d.info, d.order = info, i
		described[i] = d
	end

	-- (while the game's tracker has the pad: the order held as it was, the
	-- rows still under the cursor; a quest new since, after them)
	local rows = IQT.sortRows
	if IQT.padHeld and rows then
		tsort(described, function(a, b)
			local ra, rb = rows[a.questID], rows[b.questID]
			ra, rb = ra and ra.rank or math.huge, rb and rb.rank or math.huge
			if ra ~= rb then return ra < rb end
			return a.order < b.order
		end)
		for i, d in ipairs(described) do
			infos[i] = d.info
		end
		return infos
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
	-- (both quest modules sort: their rows merged)
	rows = rows or {}
	local ids = {}
	for i, d in ipairs(described) do
		infos[i] = d.info
		ids[i] = d.questID
		rows[d.questID] = { rank = i, pinned = focused == d.questID, completed = d.completed,
			grouped = db.sortCompleted ~= "none" }
	end
	IQT.sortRows = rows
	IQT.sortedIDs[module] = ids
	return infos
end

-- The game's watch list in our order: up to the last quest out of place,
-- each one taken off and watched again, last first (in Forever a new watch
-- goes first in the list). Its tracker gets QUEST_WATCH_LIST_CHANGED and
-- lays out again (its blocks kept: a quest watched again in the same frame
-- keeps its block, no fanfare). Not while the game's tracker has the pad
-- (its rows would move under the cursor), nor in combat. An order the game
-- didn't take isn't tried again (no loop).
local MODULES = { "IFCampaignQuestObjectiveTracker", "IFQuestObjectiveTracker" }
local tried

function IQT.SyncWatchOrder()
	if IQT.padHeld or not IQT.IsActive() or InCombatLockdown() then return end
	if not (C_QuestLog.RemoveQuestWatch and C_QuestLog.AddQuestWatch) then return end
	local current, watched = {}, {}
	for i = 1, C_QuestLog.GetNumQuestWatches() do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		if id then
			current[#current + 1] = id
			watched[id] = true
		end
	end
	-- (ours first, then the watches neither module shows, as they are)
	local target, seen = {}, {}
	for _, name in ipairs(MODULES) do
		for _, id in ipairs(_G[name] and IQT.sortedIDs[_G[name]] or {}) do
			if watched[id] and not seen[id] then
				seen[id] = true
				target[#target + 1] = id
			end
		end
	end
	for _, id in ipairs(current) do
		if not seen[id] then
			seen[id] = true
			target[#target + 1] = id
		end
	end
	local last
	for i = #target, 1, -1 do
		if current[i] ~= target[i] then
			last = i
			break
		end
	end
	if not last then
		tried = nil
		return
	end
	local key = table.concat(target, ",")
	if key == tried then return end
	tried = key
	for i = last, 1, -1 do
		local id = target[i]
		local watchType = C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id)
		C_QuestLog.RemoveQuestWatch(id)
		C_QuestLog.AddQuestWatch(id, watchType)
	end
end

-- The debug tag on a quest's header (/if quests debug rows): its place in
-- our order, its distance (the game's, read now) and what put it there
function IQT.DebugTag(questID)
	local parts = {}
	local row = IQT.sortRows and IQT.sortRows[questID]
	parts[#parts + 1] = (row and ("#" .. row.rank) or "#?") .. (IQT.padHeld and " (pad: held)" or "")
	if not C_QuestLog.GetDistanceSqToQuest then
		parts[#parts + 1] = "no distance API"
	else
		local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
		if not distanceSq then
			parts[#parts + 1] = "no POI"
		elseif not onContinent then
			parts[#parts + 1] = ("%d yd, off continent"):format(math.sqrt(distanceSq) + 0.5)
		else
			parts[#parts + 1] = ("%d yd"):format(math.sqrt(distanceSq) + 0.5)
		end
	end
	if questID == IQT.FocusedQuestID() then
		parts[#parts + 1] = row and row.pinned and "focused, pinned" or "focused"
	end
	if row and row.grouped and row.completed then
		parts[#parts + 1] = "completed"
	end
	return "|cff9d9d9d[" .. table.concat(parts, " · ") .. "]|r"
end

function IQT.SetDebugRows(on)
	IQT.debugRows = on and true or false
	IQT.Refresh()
end

function IQT.SetSort(id)
	IQT.Settings().sort = id
	IQT.sortRows = nil   -- (a held order dropped: the new one shows)
	IQT.Refresh()
end

function IQT.SetSortCompleted(id)
	IQT.Settings().sortCompleted = id
	IQT.sortRows = nil   -- (a held order dropped: the new one shows)
	IQT.Refresh()
end

function IQT.SetFocusFirst(on)
	IQT.Settings().focusFirst = on and true or false
	IQT.sortRows = nil   -- (a held order dropped: the new one shows)
	IQT.Refresh()
end

function IQT.SetCurrentZoneFirst(on)
	IQT.Settings().currentZoneFirst = on and true or false
	IQT.sortRows = nil   -- (a held order dropped: the new one shows)
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
		IQT.Print(("%d. %s [%d] shown=%s %s"):format(i, C_QuestLog.GetTitleForQuestID(questID) or "?", questID,
			tostring(block and block:IsShown() or false), IQT.DebugTag(questID)))
	end
end
