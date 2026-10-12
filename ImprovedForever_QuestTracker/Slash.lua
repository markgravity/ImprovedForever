local _, IQT = ...

local SORT_ALIASES = {
	off = "none", none = "none",
	zone = "zone",
	level = "level",
	levelr = "levelReversed", reverse = "levelReversed",
	title = "title", name = "title",
	distance = "distance", near = "distance",
}

local COMPLETED_ALIASES = {
	off = "none", none = "none",
	top = "top",
	bottom = "bottom",
}

local function NameOf(list, id)
	for _, e in ipairs(list) do
		if e.id == id then return e.text end
	end
	return id
end

local function PrintStatus()
	local db = IQT.Settings()
	IQT.Print("sort: "..NameOf(IQT.SORTS, db.sort)
		..", completed: "..NameOf(IQT.COMPLETED, db.sortCompleted)
		..", current zone first: "..(db.currentZoneFirst and "on" or "off")
		..", focused on top: "..(db.focusFirst and "on" or "off")
		..", objective sound: "..(db.objectiveSound and "on" or "off"))
	IQT.Print("/if quests sort off||zone||level||levelr||title||distance")
	IQT.Print("/if quests completed off||top||bottom")
	IQT.Print("/if quests zonefirst - toggle current zone first")
	IQT.Print("/if quests focus - toggle focused quest on top")
	IQT.Print("/if quests sound - toggle the objective complete sound")
	IQT.Print("/if quests menu - open the sort menu (also bindable in Key Bindings > AddOns)")
	IQT.Print("/if quests debug - list tracked quests and whether the tracker shows them")
	IQT.Print("Or use the filter button on the Quests header, or the Quest Tracker tab (/if).")
end

-- /if quests <command> (the words after "quests")
ImprovedForever.AddCommand("quests", function(args)
	local cmd, arg = args[1] or "", args[2]
	if cmd == "sort" and SORT_ALIASES[arg or ""] then
		IQT.SetSort(SORT_ALIASES[arg])
		PrintStatus()
	elseif cmd == "completed" and COMPLETED_ALIASES[arg or ""] then
		IQT.SetSortCompleted(COMPLETED_ALIASES[arg])
		PrintStatus()
	elseif cmd == "debug" then
		IQT.Debug()
	elseif cmd == "menu" then
		ImprovedForever_ToggleQuestSort()
	elseif cmd == "sound" then
		IQT.SetObjectiveSound(not IQT.Settings().objectiveSound)
		PrintStatus()
	elseif cmd == "focus" then
		IQT.SetFocusFirst(not IQT.Settings().focusFirst)
		PrintStatus()
	elseif cmd == "zonefirst" then
		IQT.SetCurrentZoneFirst(not IQT.Settings().currentZoneFirst)
		PrintStatus()
	else
		if cmd ~= "" then
			IQT.Print("Unknown command: "..cmd)
		end
		PrintStatus()
	end
end, "[sort|completed|zonefirst|focus|sound|menu|debug]: the quest tracker's sorting")
