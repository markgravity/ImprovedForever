-- Forked from WoW Forever's Blizzard_ObjectiveTracker/Blizzard_ObjectiveTracker.lua by
-- tools/fork_objective_tracker.py: don't edit, rerun the script.
IFObjectiveTrackerFrameMixin = { };

local function GetQuestBlockNavAnchor(block)
	if block.poiButton then
		SmartNavigation_MarkFrameIgnored(block.HeaderButton);
		return block:GetPOIButton();
	else
		SmartNavigation_ClearIgnoreStatus(block.HeaderButton);
		return block.HeaderButton;
	end
end

function IFObjectiveTrackerFrameMixin:OnLoad()
	IFObjectiveTrackerContainerMixin.OnLoad(self);

	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("QUEST_ACCEPTED");

	self:RegisterForTransitions();
end

function IFObjectiveTrackerFrameMixin:OnEvent(event, ...)
	if event == "ZONE_CHANGED_NEW_AREA" then
		C_QuestLog.SortQuestWatches();
	elseif event == "ZONE_CHANGED" then
		local mapID = C_Map.GetBestMapForUnit("player");
		if mapID ~= self.lastSortMapID then
			C_QuestLog.SortQuestWatches();
			self.lastSortMapID = mapID;
		end
	elseif ( event == "QUEST_ACCEPTED" ) then
		local questID = ...;
		if not C_QuestLog.IsQuestBounty(questID) and not C_QuestLog.IsQuestTask(questID) then
			if GetCVarBool("autoQuestWatch") and C_QuestLog.GetNumQuestWatches() < Constants.QuestWatchConsts.MAX_QUEST_WATCHES then
				C_QuestLog.AddQuestWatch(questID);
			end
		end
	end
end

function IFObjectiveTrackerFrameMixin:ShouldShowHeader()
	if C_GameRules.IsGameRuleActive(Enum.GameRule.ObjectiveTrackerDisabled) then
		return false;
	end

	if not self:HasAnyModules() then
		return false;
	end

	return true;
end

function IFObjectiveTrackerFrameMixin:UpdateHeaderPosition()
	local y = 0;
	for topPaddingProvider in pairs(self.topPaddingProviders) do
		y = y - topPaddingProvider:GetTopPadding();
	end
	self.Header:SetPoint("TOPLEFT", self.Header:GetParent(), "TOPLEFT", 0, y);
end

function IFObjectiveTrackerFrameMixin:Update(dirtyUpdate)
	if not self:ShouldShowHeader() then
		self.Header:Hide();
		return false;
	end

	self.Header:Show();

	local retValue = IFObjectiveTrackerContainerMixin.Update(self, dirtyUpdate);

	if InputUtil.IsGamepadUIEnabled() then
		self:UpdateSmartNavigationOverrides();

		if IFQuestObjectiveTracker:HasContents() then
			local currentButton = SmartNavigation:GetCurrentButton();
			if currentButton and not currentButton:IsShown() then
				self:SetTrackerTargetButton();
			end
		else
			self:SmartNavigationCloseHandler();
		end
	end
	self:UpdateHeaderPosition();
	return retValue;
end

function IFObjectiveTrackerFrameMixin:SetTrackerTargetButton()
	local firstBlock = IFQuestObjectiveTracker.firstBlock;
	if firstBlock then
		local firstPOIButton = GetQuestBlockNavAnchor(firstBlock);
		SmartNavigation:SetTargetButtonForFrame(self, firstPOIButton);
	end
end

function IFObjectiveTrackerFrameMixin:UpdateSmartNavigationOverrides()
	local questModule = IFQuestObjectiveTracker;
	if questModule:HasContents() then
		local infos = questModule:BuildQuestWatchInfos();
		for index, questWatchInfo in ipairs(infos) do
			-- Get current and adjacent blocks.
			local questID = questWatchInfo.quest:GetID();
			local currentBlock = questModule:GetExistingBlock(questID);

			local nextBlock = nil
			if infos[index + 1] then
				local nextQuestID = infos[index + 1].quest:GetID();
				nextBlock = questModule:GetExistingBlock(nextQuestID);
			end

			local prevBlock = nil
			if infos[index - 1] then
				local prevQuestID = infos[index - 1].quest:GetID();
				prevBlock = questModule:GetExistingBlock(prevQuestID);
			end

			if currentBlock then
				local currentPOIButton = GetQuestBlockNavAnchor(currentBlock);
				SmartNavigation_ClearJumpNavigationOverrides(currentPOIButton);

				-- Update item button overrides.
				local currentItemButton = currentBlock.ItemButton;
				if currentItemButton then
					-- Left/right directional.
					SmartNavigation_ClearJumpNavigationOverrides(currentItemButton);
					SmartNavigation_AddJumpNavigationOverride(currentPOIButton, SMART_NAV_INPUT_DIRECTION.RIGHT, currentItemButton);
					SmartNavigation_AddJumpNavigationOverride(currentItemButton, SMART_NAV_INPUT_DIRECTION.LEFT, currentPOIButton);

					-- Down directional.
					if nextBlock then
						local nextItemButton = nextBlock.ItemButton;
						if nextItemButton then
							SmartNavigation_AddJumpNavigationOverride(currentItemButton, SMART_NAV_INPUT_DIRECTION.DOWN, nextItemButton);
						else
							local nextPOIbutton = GetQuestBlockNavAnchor(nextBlock);
							SmartNavigation_AddJumpNavigationOverride(currentItemButton, SMART_NAV_INPUT_DIRECTION.DOWN, nextPOIbutton);
						end
					end
					-- Up directional.
					if prevBlock then
						local prevItemButton = prevBlock.ItemButton;
						if prevItemButton then
							SmartNavigation_AddJumpNavigationOverride(currentItemButton, SMART_NAV_INPUT_DIRECTION.UP, prevItemButton);
						else
							local prevPOIbutton = GetQuestBlockNavAnchor(prevBlock);
							SmartNavigation_AddJumpNavigationOverride(currentItemButton, SMART_NAV_INPUT_DIRECTION.UP, prevPOIbutton);
						end
					end
				else
					-- Ignore right navigation if this block does not have an item.
					SmartNavigation_AddIgnoreInputNavigationOverride(currentPOIButton, SMART_NAV_INPUT_DIRECTION.RIGHT);
				end
			end
		end

		-- Setup first button overrides.
		local firstBlock = questModule.firstBlock;
		if firstBlock then
			-- Account for the AutoQuestPopup button by setting the necessary navigation overrides.
			local firstButton = firstBlock;
			if (firstBlock.GetPOIButton) then
				firstButton = GetQuestBlockNavAnchor(firstBlock);
			else
				local nextBlock = firstBlock.nextBlock;
				if nextBlock then
					local nextButton = nextBlock;
					if (nextBlock.GetPOIButton) then
						nextButton = GetQuestBlockNavAnchor(nextBlock);
					end
					SmartNavigation_AddJumpNavigationOverride(firstButton, SMART_NAV_INPUT_DIRECTION.DOWN, nextButton);
					SmartNavigation_AddJumpNavigationOverride(nextButton, SMART_NAV_INPUT_DIRECTION.UP, firstButton);
				end
			end

			local header = questModule.Header;
			SmartNavigation_AddJumpNavigationOverride(firstButton, SMART_NAV_INPUT_DIRECTION.UP, header);
			SmartNavigation_AddJumpNavigationOverride(header, SMART_NAV_INPUT_DIRECTION.DOWN, firstButton);

			local firstItemButton = questModule.firstBlock.ItemButton;
			if firstItemButton then
				SmartNavigation_AddJumpNavigationOverride(firstItemButton, SMART_NAV_INPUT_DIRECTION.UP, header);
			end
		end
	end
end

function IFObjectiveTrackerFrameMixin:SelectFirstButton()
	local questModule = IFQuestObjectiveTracker;
	local firstBlock = questModule.firstBlock;
	if firstBlock then
		if (firstBlock.GetPOIButton) then
			SmartNavigation:SelectButton(GetQuestBlockNavAnchor(firstBlock));
		else
			SmartNavigation:SelectButton(firstBlock);
		end
	else
		SmartNavigation:SelectButton(questModule.Header);
	end
end

function IFObjectiveTrackerFrameMixin:OnSmartNavFocus()
	if not IFQuestObjectiveTracker:HasContents() then
		self:SmartNavigationCloseHandler();
		return;
	end

	self:SelectFirstButton();
end

function IFObjectiveTrackerFrameMixin:SmartNavigationCloseHandler()
	IFObjectiveTrackerPad.FrameHidden(self);
end

function IFObjectiveTrackerFrameMixin:FocusGamepad()
	self.gamepadFooter:ShowAndActivateBindings();
end

function IFObjectiveTrackerFrameMixin:UnfocusGamepad()
	self.gamepadFooter:HideAndDeactivateBindings();
end

function IFObjectiveTrackerFrameMixin:FocusQuestFromTracker()
	local focusedButton = SmartNavigation:GetCurrentButton();
	if focusedButton then
		focusedButton:Click();
	end
end

function IFObjectiveTrackerFrameMixin:OpenQuestOptionsFromTracker()
	local focusedButton = SmartNavigation:GetCurrentButton();
	if focusedButton then
		local block = focusedButton:GetParent();
		if block then
			block.HeaderButton:Click("RightButton");
			local popupFrame = GamepadMode.FrameControlsManager:GetActiveFrame();
			if popupFrame then
				popupFrame:ClearAllPoints();
				popupFrame:SetPoint("TOPRIGHT", block.poiButton or block.HeaderButton, "TOPLEFT");

			end
		end
	end
end

function IFObjectiveTrackerFrameMixin:OpenQuestDetailsFromTracker()
	local focusedButton = SmartNavigation:GetCurrentButton();
	if focusedButton then
		local block = focusedButton:GetParent();
		if block then
			self:SmartNavigationCloseHandler();
			block.HeaderButton:Click();
		end
	end
end

function IFObjectiveTrackerFrameMixin:UntrackQuestFromTracker()
	local focusedButton = SmartNavigation:GetCurrentButton();
	if focusedButton then
		local block = focusedButton:GetParent();
		if block then
			self:SmartNavigationCloseHandler();
			C_QuestLog.RemoveQuestWatch(block.id);
		end
	end
end

function IFObjectiveTrackerFrameMixin:MinimizeTrackerModule()
	local focusedButton = SmartNavigation:GetCurrentButton();
	if focusedButton then
		local minimizeButton = focusedButton.MinimizeButton;
		if minimizeButton then
			minimizeButton:Click();
		end
	end
end

function IFObjectiveTrackerFrameMixin:BindQuestItemFromTracker()
	local focusedButton = SmartNavigation:GetCurrentButton();
	if focusedButton then
		local itemID = focusedButton:GetItemID();
		if itemID then
			self:SmartNavigationCloseHandler();
			GamepadActionBarEditFrame:BindItem(itemID);
		end
	end
end

function IFObjectiveTrackerFrameMixin:SetUpGamepad()
	local focusAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_BOTTOM, GenerateClosure(self.FocusQuestFromTracker, self), CONTEXT_ACTION_LABEL_FOCUS);
	focusAction:AddButtonContext("ButtonContext_QuestPOIButton");

	local optionsAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_TOP, GenerateClosure(self.OpenQuestOptionsFromTracker, self), CONTEXT_ACTION_LABEL_OPTIONS);
	optionsAction:AddButtonContext("ButtonContext_QuestPOIButton");
	optionsAction:AddButtonContext("ButtonContext_QuestHeaderButton");

	local detailsAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_LEFT, GenerateClosure(self.OpenQuestDetailsFromTracker, self), OBJECTIVES_SHOW_QUEST_MAP);
	detailsAction:AddButtonContext("ButtonContext_QuestPOIButton");

	local detailsHeaderAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_BOTTOM, GenerateClosure(self.OpenQuestDetailsFromTracker, self), CONTEXT_ACTION_LABEL_DETAILS);
	detailsHeaderAction:AddButtonContext("ButtonContext_QuestHeaderButton");

	local untrackAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_LEFT, GenerateClosure(self.UntrackQuestFromTracker, self), OBJECTIVES_STOP_TRACKING);
	untrackAction:AddButtonContext("ButtonContext_QuestHeaderButton");

	local minimizeAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_BOTTOM, GenerateClosure(self.MinimizeTrackerModule, self), ACTION_LABEL_SELECT);
	minimizeAction:AddButtonContext("ButtonContext_ModuleHeaderButton");

	local bindQuestItemAction = GamepadSharedUtility.CreatePromptedBinding(GAMEPAD_FACE_LEFT, GenerateClosure(self.BindQuestItemFromTracker, self), CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR);
	bindQuestItemAction:AddButtonContext("ButtonContext_TrackerQuestItem");

	-- NineSlice gets resized to match the size of the tracker frame, but has an alpha of 0 so we
	-- don't want it as footer parent, since that would hide the footer.
	local gamepadFooterAnchor = CreateFrame("FRAME", nil, self);
	gamepadFooterAnchor:SetPoint("TOPLEFT", self.NineSlice);
	gamepadFooterAnchor:SetPoint("BOTTOMRIGHT", self.NineSlice);

	self.gamepadFooter = GamepadSharedUtility.CreatePromptedBindingFooter(self, "ObjectiveTrackerFooter");
	self.gamepadFooter:AddPromptedBinding(focusAction);
	self.gamepadFooter:AddPromptedBinding(optionsAction);
	self.gamepadFooter:AddPromptedBinding(detailsAction);
	self.gamepadFooter:AddPromptedBinding(detailsHeaderAction);
	self.gamepadFooter:AddPromptedBinding(untrackAction);
	self.gamepadFooter:AddPromptedBinding(minimizeAction);
	self.gamepadFooter:AddPromptedBinding(bindQuestItemAction);
	self.gamepadFooter:AddStandardSelectPrompt();
	self.gamepadFooter:AddStandardBackPrompt();
	self.gamepadFooter:SetParentFrame(gamepadFooterAnchor);
	self.gamepadFooter:SetAlignmentType(PromptedBindingFooterMixin.ALIGNMENT_TYPE.RIGHT);
	self.gamepadFooter:Finalize();

	SmartNavigation_AddIgnoreInputNavigationOverride(IFQuestObjectiveTracker.Header, SMART_NAV_INPUT_DIRECTION.RIGHT);
	SmartNavigation_AddIgnoreInputNavigationOverride(IFQuestObjectiveTracker.Header, SMART_NAV_INPUT_DIRECTION.LEFT);
end

function IFObjectiveTrackerFrameMixin:InitializeGamepad()
	self.Header.MinimizeButton:Hide();
end

function IFObjectiveTrackerFrameMixin:UninitializeGamepad()
	self.Header.MinimizeButton:Show();
end

function IFObjectiveTrackerFrameMixin:RegisterForTransitions()
	InputUtil.RegisterForInterfaceTransitions(self, nil);
	InputUtil.RegisterGamepadSetup(self, GenerateClosure(self.SetUpGamepad, self));
	InputUtil.RegisterGamepadInit(self, GenerateClosure(self.InitializeGamepad, self));
	InputUtil.RegisterGamepadUninit(self, GenerateClosure(self.UninitializeGamepad, self));
end
