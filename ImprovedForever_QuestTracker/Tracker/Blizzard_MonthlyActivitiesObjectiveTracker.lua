-- Forked from WoW Forever's Blizzard_ObjectiveTracker/Blizzard_MonthlyActivitiesObjectiveTracker.lua by
-- tools/fork_objective_tracker.py: don't edit, rerun the script.
local settings = {
	headerText = TRACKER_HEADER_MONTHLY_ACTIVITIES,
	events = { "PERKS_ACTIVITY_COMPLETED", "PERKS_ACTIVITIES_TRACKED_UPDATED", "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED" },
	blockTemplate = "IFObjectiveTrackerAnimBlockTemplate",
	lineTemplate = "IFObjectiveTrackerAnimLineTemplate",
};

IFMonthlyActivitiesObjectiveTrackerMixin = CreateFromMixins(IFObjectiveTrackerModuleMixin, settings);

function IFMonthlyActivitiesObjectiveTrackerMixin:OnEvent(event, ...)
	if event == "PERKS_ACTIVITY_COMPLETED" then
		local perksActivityID = ...;
		local trackedActivities = C_PerksActivities.GetTrackedPerksActivities().trackedIDs;
		for i = 1, #trackedActivities do
			local activityID = trackedActivities[i];
			if activityID == perksActivityID then
				PlaySound(SOUNDKIT.TRADING_POST_UI_COMPLETING_ACTIVITIES);
				local block = self:GetExistingBlock(activityID);
				if block then
					block:PlayTurnInAnimation();
				end
				break;
			end
		end
	elseif event == "PERKS_ACTIVITIES_TRACKED_UPDATED" then
		self:MarkDirty();
	elseif event == "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED" then
		local perksActivityID, added = ...;
		if added then
			self:SetNeedsFanfare(perksActivityID);
		end
		self:MarkDirty();
	end
end

function IFMonthlyActivitiesObjectiveTrackerMixin:OnBlockHeaderClick(block, mouseButton)
	if IsModifiedClick("CHATLINK") and ChatFrameUtil.GetActiveWindow() then
		local perksActivityLink = C_PerksActivities.GetPerksActivityChatLink(block.id);
		ChatFrameUtil.InsertLink(perksActivityLink);
	elseif mouseButton ~= "RightButton" then
		if not EncounterJournal then
			EncounterJournal_LoadUI();
		end
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			self:UntrackPerksActivity(block.id);
		else
			MonthlyActivitiesFrame_OpenFrameToActivity(block.id);
		end

		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	else
		IFObjectiveTrackerMenu.CreateContextMenu(self:GetContextMenuParent(), function(owner, rootDescription)
			rootDescription:SetTag("MENU_MONTHLY_ACTVITIES_TRACKER");

			rootDescription:CreateTitle(block.name);
			rootDescription:CreateButton(OBJECTIVES_VIEW_IN_TRAVELERS_LOG, function()
				self:OpenFrameToActivity(block.id);
			end);
			rootDescription:CreateButton(OBJECTIVES_STOP_TRACKING, function()
				self:UntrackPerksActivity(block.id);
			end);
		end);
	end
end

function IFMonthlyActivitiesObjectiveTrackerMixin:OpenFrameToActivity(activityID)
	if not EncounterJournal then
		EncounterJournal_LoadUI();
	end
	MonthlyActivitiesFrame_OpenFrameToActivity(activityID);
end

function IFMonthlyActivitiesObjectiveTrackerMixin:UntrackPerksActivity(activityID)
	C_PerksActivities.RemoveTrackedPerksActivity(activityID);
end

function IFMonthlyActivitiesObjectiveTrackerMixin:LayoutContents()
	local trackedActivities = C_PerksActivities.GetTrackedPerksActivities().trackedIDs;
	for i = 1, #trackedActivities do
		local activityID = trackedActivities[i];
		local activityInfo = C_PerksActivities.GetPerksActivityInfo(activityID);
		if activityInfo and not activityInfo.completed then
			if not self:AddActivity(activityInfo) then
				return;
			end
		end
	end
end

function IFMonthlyActivitiesObjectiveTrackerMixin:AddActivity(activityInfo)
	local activityName = activityInfo.activityName;
	local requirements = activityInfo.requirementsList;
	local block = self:GetBlock(activityInfo.ID);
	block.name = activityName;
	block:SetHeader(activityName);
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
