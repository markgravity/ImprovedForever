-- Forked from WoW Forever's Blizzard_ObjectiveTracker/Blizzard_CampaignQuestObjectiveTracker.lua by
-- tools/fork_objective_tracker.py: don't edit, rerun the script.
local settings = {
	headerText = TRACKER_HEADER_CAMPAIGN_QUESTS,
	events = { "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_PATH_UPDATED" },
	lineTemplate = "IFObjectiveTrackerAnimLineTemplate",
};

IFCampaignQuestObjectiveTrackerMixin = CreateFromMixins(IFQuestObjectiveTrackerMixin, settings);

function IFCampaignQuestObjectiveTrackerMixin:ShouldDisplayQuest(quest)
	return (quest:GetQuestClassification() == Enum.QuestClassification.Campaign) and not quest:IsDisabledForSession();
end
