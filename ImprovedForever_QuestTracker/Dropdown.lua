local _, IQT = ...

-- Our dropdown, styled like the native Menu (Blizzard_Menu MenuStyle1 /
-- MenuVariants). Blizzard's Menu can't be opened from addon code on Forever:
-- it switches the gamepad binding set inside our call and the protected
-- SetPreferredGamepadInteractTarget gets blocked. This frame never touches
-- the gamepad manager; controller input is read directly.
--
-- IQT.ShowMenu(entries, opts) shows a list of entries:
--   { kind = "title" | "divider" | "button" | "radio" | "checkbox", text,
--     isSelected(), onSelect() }
-- opts: anchor (frame; else at the cursor), point / relativePoint,
-- onClose(), pad (true: the controller works it, as when opened from it).
-- A button closes the menu once chosen; radios and checkboxes leave it open.

local ROW_HEIGHT = 20
local INSET = { left = 8, top = 8, right = 8, bottom = 15 }
local PAD_WIDTH = 20

local dropdown
local rows = {}
local entries, opts = {}, {}
local focusIndex
local downSeen = {}

local function NewFrame(frameType, name, parent, template)
	local f = CreateFrame(frameType, name, nil, template)
	f:SetParent(parent)
	return f
end

---------------------------------------------------------------------------
-- Controller glyphs (InputIconTexture atlases per label style)
---------------------------------------------------------------------------

local GLYPHS = {
	Letters = { dpad = "gamepad-xbox1-dpadall-normal", select = "gamepad-xbox1-buttona-normal", close = "gamepad-xbox1-buttonb-normal" },
	Shapes  = { dpad = "gamepad-ps-dpadall-normal", select = "gamepad-ps-buttoncrox-normal", close = "gamepad-ps-buttoncircle-normal" },
	Reverse = { dpad = "gamepad-switch-128x-dpad-all-normal", select = "gamepad-switch-128x-face-b-normal", close = "gamepad-switch-128x-face-a-normal" },
}

local function GamepadActive()
	return C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
end

local function Style()
	local m = InputDeviceIconSetManager
	local s = m and m.GetActiveInputDeviceIconSet and m:GetActiveInputDeviceIconSet()
	if not s and C_GamePad and C_GamePad.GetDeviceMappedState then
		local st = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
		s = st and st.labelStyle
	end
	return (s == "Shapes" or s == "Reverse") and s or "Letters"
end

local function Glyph(key)
	local atlas = GLYPHS[Style()][key]
	if C_Texture.GetAtlasInfo(atlas) then
		return "|A:"..atlas..":16:16|a"
	end
	return ""
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function Selectable(entry)
	return entry and (entry.kind == "radio" or entry.kind == "checkbox" or entry.kind == "button")
		and entry.enabled ~= false
end

local function RefreshRow(row)
	local entry = row.entry
	if row.check then
		row.check:SetShown(entry.isSelected and entry.isSelected() and true or false)
	end
	row.highlight:SetShown(row.index == focusIndex)
end

local function Refresh()
	for i = 1, #entries do
		RefreshRow(rows[i])
	end
end

local function SetFocus(index)
	focusIndex = index
	Refresh()
end

local function Activate(index)
	local entry = entries[index]
	if not Selectable(entry) then return end
	if entry.onSelect then entry.onSelect() end
	if entry.kind == "checkbox" then
		PlaySound(entry.isSelected() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	if entry.kind == "button" then
		IQT.HideDropdown()
	else
		Refresh()
	end
end

local function CreateRow(parent)
	local row = NewFrame("Button", nil, parent)
	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetAllPoints()
	highlight:SetBlendMode("ADD")
	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	highlight:Hide()
	row.highlight = highlight

	row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.text:SetHeight(ROW_HEIGHT)
	row.text:SetJustifyH("LEFT")

	row.divider = row:CreateTexture(nil, "ARTWORK")
	row.divider:SetPoint("LEFT")
	row.divider:SetPoint("RIGHT")
	row.divider:SetHeight(13)
	row.divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")

	row.tickRadial = row:CreateTexture(nil, "ARTWORK")
	row.tickRadial:SetAtlas("common-dropdown-tickradial", true)
	row.tickRadial:SetPoint("LEFT", -3, 0)
	row.checkRadial = row:CreateTexture(nil, "OVERLAY")
	row.checkRadial:SetAtlas("common-dropdown-icon-radialtick-yellow", true)
	row.checkRadial:SetPoint("TOPLEFT", row.tickRadial, "TOPLEFT")

	row.tickSquare = row:CreateTexture(nil, "ARTWORK")
	row.tickSquare:SetAtlas("common-dropdown-ticksquare", true)
	row.tickSquare:SetPoint("LEFT")
	row.checkSquare = row:CreateTexture(nil, "OVERLAY")
	row.checkSquare:SetAtlas("common-dropdown-icon-checkmark-yellow", true)
	row.checkSquare:SetPoint("CENTER", row.tickSquare, "CENTER", 2, 1)

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnEnter", function(self)
		if Selectable(self.entry) then SetFocus(self.index) end
	end)
	row:SetScript("OnLeave", function(self)
		if focusIndex == self.index and not GamepadActive() then
			SetFocus(nil)
		end
	end)
	row:SetScript("OnClick", function(self) Activate(self.index) end)
	return row
end

-- Lays a row out for its entry; its content's width
local function SetUpRow(row, index, entry)
	row.index, row.entry = index, entry
	local kind = entry.kind
	row.text:ClearAllPoints()
	row.text:SetFontObject(kind == "title" and "GameFontNormal" or "GameFontHighlight")
	row.text:SetText(entry.text or "")
	row.text:SetShown(kind ~= "divider")
	row.divider:SetShown(kind == "divider")
	row.tickRadial:SetShown(kind == "radio")
	row.tickSquare:SetShown(kind == "checkbox")
	row.checkRadial:Hide()
	row.checkSquare:Hide()
	row.check = (kind == "radio" and row.checkRadial) or (kind == "checkbox" and row.checkSquare) or nil
	row:SetHeight(kind == "divider" and 13 or ROW_HEIGHT)
	row:EnableMouse(Selectable(entry) and true or false)
	if entry.enabled == false then
		row.text:SetFontObject("GameFontDisable")
	end
	if kind == "radio" then
		row.text:SetPoint("LEFT", row.tickRadial, "RIGHT", 1, 0)
		return row.tickRadial:GetWidth() - 3 + 1 + row.text:GetStringWidth()
	elseif kind == "checkbox" then
		row.text:SetPoint("LEFT", row.tickSquare, "RIGHT", 7, 1)
		return row.tickSquare:GetWidth() + 7 + row.text:GetStringWidth()
	elseif kind == "divider" then
		return 0
	end
	row.text:SetPoint("LEFT")
	return row.text:GetStringWidth()
end

---------------------------------------------------------------------------
-- Controller navigation
---------------------------------------------------------------------------

local function MoveFocus(step)
	local n = #entries
	local i = focusIndex or (step > 0 and 0 or n + 1)
	for _ = 1, n do
		i = i + step
		if i < 1 then i = n elseif i > n then i = 1 end
		if Selectable(entries[i]) then
			SetFocus(i)
			return
		end
	end
end

local function FirstIndex()
	for i, entry in ipairs(entries) do
		if Selectable(entry) and entry.kind == "radio" and entry.isSelected() then
			return i
		end
	end
	for i, entry in ipairs(entries) do
		if Selectable(entry) then return i end
	end
end

local function OnGamePadButtonDown(self, button)
	downSeen[button] = true
	if button == "PADDUP" then
		MoveFocus(-1)
	elseif button == "PADDDOWN" then
		MoveFocus(1)
	elseif button == "PAD1" then
		if focusIndex then
			Activate(focusIndex)
		end
	end
end

local function OnGamePadButtonUp(self, button)
	-- Only act on releases whose press we saw (the press that opened the
	-- dropdown must not close it), and close on release so it doesn't leak.
	if not downSeen[button] then return end
	downSeen[button] = nil
	if button == "PAD2" then
		IQT.HideDropdown()
	end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local function CreateDropdown()
	local f = NewFrame("Frame", "ImprovedForeverQuestDropdown", UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()

	local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetAtlas("common-dropdown-bg")
	bg:SetPoint("TOPLEFT", -10, 3)
	bg:SetPoint("BOTTOMRIGHT", 10, -3)
	bg:SetAlpha(0.925)

	local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", INSET.left, 6)
	hint:SetJustifyH("LEFT")
	f.hint = hint

	f:SetScript("OnGamePadButtonDown", OnGamePadButtonDown)
	f:SetScript("OnGamePadButtonUp", OnGamePadButtonUp)
	-- (setting the handler turns pad input on: off until shown)
	f:EnableGamePadButton(false)
	f:SetScript("OnHide", function(self)
		if not InCombatLockdown() then
			self:EnableGamePadButton(false)
		end
		self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		wipe(downSeen)
		local onClose = opts.onClose
		opts = {}
		if onClose then onClose() end
	end)
	f:SetScript("OnEvent", function(self, event)
		if event == "GLOBAL_MOUSE_DOWN" then
			if not self:IsMouseOver() and not (opts.anchor and opts.anchor:IsMouseOver()) then
				self:Hide()
			end
		elseif event == "PLAYER_REGEN_DISABLED" then
			self:Hide()
		end
	end)

	-- Escape closes it like other windows
	tinsert(UISpecialFrames, f:GetName())
	return f
end

function IQT.ShowMenu(list, options)
	if InCombatLockdown() then
		IQT.Print("Not available in combat.")
		return
	end
	dropdown = dropdown or CreateDropdown()
	if dropdown:IsShown() then dropdown:Hide() end
	entries, opts = list, options or {}

	local width, height = 0, INSET.top
	local previous
	for i, entry in ipairs(entries) do
		local row = rows[i] or CreateRow(dropdown)
		rows[i] = row
		row:ClearAllPoints()
		if previous then
			row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
		else
			row:SetPoint("TOPLEFT", INSET.left, -INSET.top)
		end
		row:SetPoint("RIGHT", -INSET.right, 0)
		width = math.max(width, SetUpRow(row, i, entry))
		height = height + row:GetHeight()
		row:Show()
		previous = row
	end
	for i = #entries + 1, #rows do rows[i]:Hide() end
	width = width + PAD_WIDTH + INSET.left + INSET.right
	height = height + INSET.bottom

	local gamepad = (opts.pad or GamepadActive()) and true or false
	if gamepad then
		dropdown.hint:SetText(Glyph("dpad").." Move   "..Glyph("select").." Select   "..Glyph("close").." Close")
		dropdown.hint:Show()
		width = math.max(width, dropdown.hint:GetStringWidth() + INSET.left + INSET.right)
		height = height + 16
	else
		dropdown.hint:Hide()
	end
	dropdown:SetSize(width, height)

	dropdown:ClearAllPoints()
	if opts.anchor then
		dropdown:SetPoint(opts.point or "TOPRIGHT", opts.anchor, opts.relativePoint or "BOTTOMRIGHT", opts.x or 0, opts.y or -4)
	else
		local x, y = GetCursorPosition()
		local scale = dropdown:GetEffectiveScale()
		dropdown:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	end

	focusIndex = gamepad and FirstIndex() or nil
	wipe(downSeen)
	dropdown:Show()
	dropdown:EnableGamePadButton(gamepad)
	Refresh()
	dropdown:RegisterEvent("GLOBAL_MOUSE_DOWN")
	dropdown:RegisterEvent("PLAYER_REGEN_DISABLED")
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function IQT.HideDropdown()
	if dropdown and dropdown:IsShown() then
		dropdown:Hide()
	end
end

function IQT.IsDropdownShown()
	return dropdown and dropdown:IsShown() or false
end

---------------------------------------------------------------------------
-- The sort menu (the Quests header's filter button, R3 on the tracker, the
-- key binding)
---------------------------------------------------------------------------

local function SortEntries()
	local list = {}
	list[#list + 1] = { kind = "title", text = "Sort Quests" }
	for _, s in ipairs(IQT.SORTS) do
		list[#list + 1] = {
			kind = "radio", text = s.text,
			isSelected = function() return IQT.Settings().sort == s.id end,
			onSelect = function() IQT.SetSort(s.id) end,
		}
	end
	list[#list + 1] = {
		kind = "checkbox", text = "Current zone first",
		isSelected = function() return IQT.Settings().currentZoneFirst end,
		onSelect = function() IQT.SetCurrentZoneFirst(not IQT.Settings().currentZoneFirst) end,
	}
	list[#list + 1] = {
		kind = "checkbox", text = "Focused quest on top",
		isSelected = function() return IQT.Settings().focusFirst end,
		onSelect = function() IQT.SetFocusFirst(not IQT.Settings().focusFirst) end,
	}
	list[#list + 1] = { kind = "divider" }
	list[#list + 1] = { kind = "title", text = "Completed Quests" }
	for _, c in ipairs(IQT.COMPLETED) do
		list[#list + 1] = {
			kind = "radio", text = c.text,
			isSelected = function() return IQT.Settings().sortCompleted == c.id end,
			onSelect = function() IQT.SetSortCompleted(c.id) end,
		}
	end
	list[#list + 1] = { kind = "divider" }
	list[#list + 1] = {
		kind = "checkbox", text = "Objective complete sound",
		isSelected = function() return IQT.Settings().objectiveSound end,
		onSelect = function() IQT.SetObjectiveSound(not IQT.Settings().objectiveSound) end,
	}
	return list
end

function IQT.ToggleSortMenu(anchor, options)
	if IQT.IsDropdownShown() then
		IQT.HideDropdown()
		return
	end
	options = options or {}
	if anchor and anchor:IsVisible() then options.anchor = anchor end
	IQT.ShowMenu(SortEntries(), options)
end

-- Key binding (Bindings.xml)
BINDING_HEADER_IMPROVEDFOREVER_QUESTS = "Improved Quest Tracker"
BINDING_NAME_IMPROVEDFOREVER_QUESTS_TOGGLE = "Toggle sort menu"

function ImprovedForever_ToggleQuestSort()
	IQT.ToggleSortMenu(IQT.sortButton)
end
