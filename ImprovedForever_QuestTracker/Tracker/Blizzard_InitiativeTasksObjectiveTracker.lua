-- Forked from WoW Forever's Blizzard_ObjectiveTracker/Blizzard_InitiativeTasksObjectiveTracker.lua by
-- tools/fork_objective_tracker.py: don't edit, rerun the script.
local settings = {
	headerText = TRACKER_HEADER_INITIATIVE_TASKS,
	events = { "INITIATIVE_TASKS_TRACKED_UPDATED", "INITIATIVE_TASKS_TRACKED_LIST_CHANGED", "NEIGHBORHOOD_INITIATIVE_UPDATED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" },
	blockTemplate = "IFObjectiveTrackerAnimBlockTemplate",
	lineTemplate = "IFObjectiveTrackerAnimLineTemplate",
};

--! TODO:
--! this is a stripped down version of Monthly Activities Objective Tracker
--! still needs: open to initiative frame, fan fare, and initiatve complete turn in animation etc.

IFInitiativeTasksObjectiveTrackerMixin = CreateFromMixins(IFObjectiveTrackerModuleMixin, settings);

function IFInitiativeTasksObjectiveTrackerMixin:RequestInitiativeInfoIfTracking()
	local trackedTasks = C_NeighborhoodInitiative.GetTrackedInitiativeTasks();
	if #trackedTasks.trackedIDs > 0 then
		C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo();
	end
end

function IFInitiativeTasksObjectiveTrackerMixin:InitModule()
	self:RequestInitiativeInfoIfTracking();
end

function IFInitiativeTasksObjectiveTrackerMixin:OnEvent(event, ...)
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		self:RequestInitiativeInfoIfTracking();
	elseif event == "INITIATIVE_TASKS_TRACKED_UPDATED" or event == "INITIATIVE_TASKS_TRACKED_LIST_CHANGED" or event == "NEIGHBORHOOD_INITIATIVE_UPDATED" then
		self:MarkDirty();
	end
end

function IFInitiativeTasksObjectiveTrackerMixin:OnBlockHeaderClick(block, mouseButton)
	if IsModifiedClick("CHATLINK") and ChatFrameUtil.GetActiveWindow() then
		local initiativeTaskLink = C_NeighborhoodInitiative.GetInitiativeTaskChatLink(block.id);
		ChatFrameUtil.InsertLink(initiativeTaskLink);
	elseif mouseButton ~= "RightButton" then
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			self:UntrackInitiativeTask(block.id);
		else
			HousingFramesUtil.OpenFrameToTaskID(block.id)
		end

		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	else
		IFObjectiveTrackerMenu.CreateContextMenu(self:GetContextMenuParent(), function(owner, rootDescription)
			rootDescription:SetTag("MENU_MONTHLY_ACTVITIES_TRACKER");

			rootDescription:CreateTitle(block.name);
			rootDescription:CreateButton(OBJECTIVES_VIEW_IN_ENDEAVORS_TAB, function()
				HousingFramesUtil.OpenFrameToTaskID(block.id)
			end);
			rootDescription:CreateButton(OBJECTIVES_STOP_TRACKING, function()
				self:UntrackInitiativeTask(block.id);
			end);
		end);
	end
end

function IFInitiativeTasksObjectiveTrackerMixin:UntrackInitiativeTask(taskID)
	C_NeighborhoodInitiative.RemoveTrackedInitiativeTask(taskID);
end

function IFInitiativeTasksObjectiveTrackerMixin:LayoutContents()
	local trackedTasks = C_NeighborhoodInitiative.GetTrackedInitiativeTasks().trackedIDs;
	for i = 1, #trackedTasks do
		local taskID = trackedTasks[i];
		local taskInfo = C_NeighborhoodInitiative.GetInitiativeTaskInfo(taskID);
		if taskInfo and not taskInfo.completed then
			if not self:AddTask(taskInfo) then
				return;
			end
		end
	end
end

function IFInitiativeTasksObjectiveTrackerMixin:AddTask(taskInfo)
	local taskName = taskInfo.taskName;
	local requirements = taskInfo.requirementsList;

	local block = self:GetBlock(taskInfo.ID);
	block.name = taskName;
	block:SetHeader(taskName);
	-- criteria
	for index, requirement in ipairs(requirements) do
		if not requirement.completed then
			local criteriaString = requirement.requirementText;
			criteriaString = string.gsub(criteriaString, " / ", "/");
			block:AddObjective(index, criteriaString, nil, nil, IF_OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE, IF_OBJECTIVE_TRACKER_COLOR["Normal"]);
		end
	end
	
	return self:LayoutBlock(block);
end
