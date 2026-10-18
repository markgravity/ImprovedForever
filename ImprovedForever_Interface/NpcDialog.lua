-- Talking to an NPC as a subtitle, as Spoken (spoken.rusty.one) draws its
-- lines: low in the middle of the screen on a soft dark band, the NPC's
-- round face, its name in gold, " • " and the quest's title in grey, its
-- words in white under them, Spoken's progress line under those (the
-- game's widget status bar and the casting bar's spark), its round
-- controls; then, in the same look, the rewards (round), the quests or
-- options to pick (a round icon and their words, centred, one a line),
-- and the answers (the press's glyph and its word: Accept, Decline,
-- Goodbye...). For the game's quest window (greeting, offer, progress,
-- reward) and gossip window.
--
-- The game's windows keep running unseen under ours (IF.Focus.Fade, their
-- mouse covered: UF.Cover) and keep the game's gamepad focus: its D-pad,
-- A, B and right stick are the game's, untouched. Ours only shows where its
-- cursor is (SmartNavigation's current button: our row for it lit, no arrow) and
-- follows its text's scrolling. With the mouse, our rows and answers
-- answer through the quest and gossip API (AcceptQuest,
-- C_GossipInfo.SelectOptionByIndex...); the game's window then closes or
-- changes from its own events. Nothing here shows, hides or clicks a frame
-- of the game's.
--
-- With Spoken installed, its voice plays the NPC's words as it does for
-- the game's windows; ours shows whether it speaks, how far, and its button
-- to stop or hear it again. Its own subtitles are faded while ours show.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local ND = {}
IN.NpcDialog = ND

-- (Spoken's subtitle's numbers: its width, padding, face, gaps)
local WIDTH = 512
local PAD, TITLE_GAP, LABEL_GAP = 16, 8, 6
local FACE, FACE_GAP = 36, 8
local BAND_REACH = 40                   -- (the band past the words, each side)
local BAND_OVER_TOP, BAND_OVER_BOTTOM = 10, 4          -- (and past its top and bottom)
-- (Spoken's band's fades (its texture is 64 high: fading in over its top 28
-- rows, out over its last 8), kept this high however tall ours is, so a tall
-- page's answers don't lie in the fade, nor the band run on below them)
local BAND_TOP_ROWS, BAND_BOTTOM_ROWS = 28 / 64, 8 / 64
local BAND_TOP_FADE, BAND_BOTTOM_FADE = 40, 12
local BODY_MAX = 120                    -- (the words' height before they scroll: ~6 lines)
local PROGRESS_H, PROGRESS_SHARE = 7, 0.45
local BOTTOM_Y = 210                    -- (over the party cards and the spell tiles)
local ROW_H = 24
local ITEM = 30                         -- (a reward, round)
local GAP = 8
local GREY = { 0.62, 0.62, 0.62 }
local GOLD = { 1, 0.82, 0 }
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING = "gamepad-actionbar-circleslot-frame"
-- (Spoken's own band, when it's installed: its subtitle's shade)
local SPOKEN_BAND = "Interface\\AddOns\\Spoken\\Textures\\SubtitleBand"
local function SpokenLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Spoken") or false
end

local function Shadowed(fs, color)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

---------------------------------------------------------------------------
-- The subtitle
---------------------------------------------------------------------------
local panel = CreateFrame("Frame", "ImprovedForeverNpcDialog", UIParent)
panel:SetSize(WIDTH, 200)
panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, BOTTOM_Y)
-- (over Spoken's own subtitle, faded while ours shows but still taking the
-- mouse where it lies)
panel:SetFrameStrata("MEDIUM")
panel:EnableMouse(true)
panel:Hide()

-- (the band: dark in the middle, fading out to its sides and its top and
-- bottom edges)
local band = CreateFrame("Frame", nil, panel)
band:SetPoint("TOPLEFT", -BAND_REACH, 10)
band:SetPoint("BOTTOMRIGHT", BAND_REACH, -10)
band:SetFrameLevel(math.max(0, panel:GetFrameLevel() - 1))
local BAND_ALPHA, BAND_FADE = 0.6, 0.18
local function BandPart(points, gradient)
    local t = band:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(1, 1, 1, 1)
    for _, p in ipairs(points) do t:SetPoint(unpack(p)) end
    if gradient and t.SetGradient and CreateColor then
        t:SetGradient(gradient[1], CreateColor(0, 0, 0, gradient[2]), CreateColor(0, 0, 0, gradient[3]))
    else
        t:SetVertexColor(0, 0, 0, BAND_ALPHA)
    end
    return t
end
local bandParts = {}
do
    local fade = BAND_REACH * 2
    bandParts[1] = BandPart({ { "TOPLEFT", band, "TOPLEFT", fade, 0 }, { "BOTTOMRIGHT", band, "BOTTOMRIGHT", -fade, 0 } })
    bandParts[2] = BandPart({ { "TOPLEFT" }, { "BOTTOMRIGHT", band, "BOTTOMLEFT", fade, 0 } }, { "HORIZONTAL", 0, BAND_ALPHA })
    bandParts[3] = BandPart({ { "TOPRIGHT" }, { "BOTTOMLEFT", band, "BOTTOMRIGHT", -fade, 0 } }, { "HORIZONTAL", BAND_ALPHA, 0 })
end
-- (Spoken's, over the whole band, in place of ours when it's there: its
-- top fade, its middle stretched, its bottom fade)
local spokenBand = {}
do
    local function Slice(top, bottom)
        local t = band:CreateTexture(nil, "BACKGROUND", nil, 1)
        t.top, t.bottom = top, bottom
        t:Hide()
        spokenBand[#spokenBand + 1] = t
        return t
    end
    local head = Slice(0, BAND_TOP_ROWS)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(BAND_TOP_FADE)
    local foot = Slice(1 - BAND_BOTTOM_ROWS, 1)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(BAND_BOTTOM_FADE)
    local middle = Slice(BAND_TOP_ROWS, 1 - BAND_BOTTOM_ROWS)
    middle:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    middle:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
end
local function Band()
    local spoken = SpokenLoaded()
    for _, t in ipairs(spokenBand) do
        if spoken and not t:GetTexture() then
            t:SetTexture(SPOKEN_BAND)
            t:SetTexCoord(0, 1, t.top, t.bottom)
        end
        t:SetShown(spoken)
    end
    for _, t in ipairs(bandParts) do t:SetShown(not spoken) end
end

-- The NPC's face: Spoken's (its round face, a line's badge on it) when
-- it's installed (Spoken:CreateSpeakerFace, made once it's there), else
-- ours, round in the game's round slot's ring
local spokenFace
local function SpokenFace()
    if spokenFace ~= nil then return spokenFace or nil end
    local s = _G.Spoken
    if not (type(s) == "table" and s.CreateSpeakerFace) then return nil end
    local ok, f = pcall(s.CreateSpeakerFace, s, panel, FACE)
    spokenFace = ok and f or false
    return spokenFace or nil
end
local face = CreateFrame("Frame", nil, panel)
face:SetSize(FACE, FACE)
local portrait = face:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints()
local faceMask = face:CreateMaskTexture()
faceMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
faceMask:SetAllPoints()
portrait:AddMaskTexture(faceMask)
local faceRing = face:CreateTexture(nil, "OVERLAY")
faceRing:SetPoint("TOPLEFT", -3, 3)
faceRing:SetPoint("BOTTOMRIGHT", 3, -3)
faceRing:SetAtlas(RING)

-- Its name, " • ", the quest's title or Spoken's state, in one row
local name = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), GOLD)
local dot = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), GREY)
dot:SetText("•")
local title = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), GREY)
title:SetWordWrap(false)
local status = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), GREY)

-- The words: the game's quest font, white, centred; scrolled as the game's
-- window is (its right stick)
local scroll = CreateFrame("ScrollFrame", nil, panel)
scroll:SetWidth(WIDTH - 2 * PAD)
local page = CreateFrame("Frame", nil, scroll)
page:SetWidth(WIDTH - 2 * PAD)
scroll:SetScrollChild(page)
local body = Shadowed(page:CreateFontString(nil, "OVERLAY", "QuestFont"), { 1, 1, 1 })
body:SetPoint("TOP")
body:SetWidth(WIDTH - 2 * PAD)
body:SetJustifyH("CENTER")
body:SetSpacing(2)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 30)))
end)
local more = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
more:SetPoint("LEFT", scroll, "RIGHT", 4, 0)

-- Spoken's progress: the game's widget status bar (its frame, its yellow
-- fill) and the casting bar's spark at the fill's end
local track = CreateFrame("Frame", nil, panel)
track:SetSize(WIDTH * PROGRESS_SHARE, PROGRESS_H)
local fill = track:CreateTexture(nil, "ARTWORK")
local progressRoom = 0
do
    local k = PROGRESS_H / 31
    local function Piece(atlas, layer, width)
        local t = track:CreateTexture(nil, layer)
        t:SetAtlas(atlas)
        t:SetHeight(PROGRESS_H)
        if width then t:SetWidth(width * k) end
        return t
    end
    local info = C_Texture and C_Texture.GetAtlasInfo
    local l = info and info("widgetstatusbar-borderleft")
    local r = info and info("widgetstatusbar-borderright")
    if l and r then
        local left = Piece("widgetstatusbar-borderleft", "OVERLAY", l.width)
        local right = Piece("widgetstatusbar-borderright", "OVERLAY", r.width)
        local middle = Piece("widgetstatusbar-bordercenter", "OVERLAY")
        left:SetPoint("LEFT")
        right:SetPoint("RIGHT")
        middle:SetPoint("LEFT", left, "RIGHT")
        middle:SetPoint("RIGHT", right, "LEFT")
        progressRoom = 8 * k
        local back = track:CreateTexture(nil, "BACKGROUND")
        back:SetAtlas("widgetstatusbar-bgcenter")
        back:SetPoint("TOPLEFT", progressRoom - 2 * k, -2 * k)
        back:SetPoint("BOTTOMRIGHT", -(progressRoom - 2 * k), 2 * k)
        fill:SetAtlas("widgetstatusbar-fill-yellow")
        fill:SetHeight(PROGRESS_H - 4 * k)
    else
        local back = track:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0, 0, 0, 0.5)
        fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        fill:SetHeight(2)
    end
    fill:SetPoint("LEFT", track, "LEFT", progressRoom, 0)
    fill:SetWidth(0.01)
end
local spark = track:CreateTexture(nil, "OVERLAY", nil, 1)
spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
spark:SetBlendMode("ADD")
spark:SetSize(12, PROGRESS_H + 9)
spark:SetPoint("CENTER", fill, "RIGHT")

-- (Show all: the voice stopped, every word shown; Square, watched, or a
-- click; ND.ShowAll)
local showAllButton = CreateFrame("Button", nil, track)
showAllButton:SetHeight(16)
showAllButton:SetPoint("LEFT", track, "RIGHT", 10, 0)
showAllButton.text = Shadowed(showAllButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), GREY)
showAllButton.text:SetPoint("LEFT")
showAllButton:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
showAllButton:SetScript("OnLeave", function(self) self.text:SetTextColor(GREY[1], GREY[2], GREY[3]) end)
showAllButton:SetScript("OnClick", function() ND.ShowAll() end)

-- (0 to 1 of the way)
local function SetProgress(share)
    local room = math.max(0, track:GetWidth() - 2 * progressRoom)
    fill:SetWidth(math.max(0.01, room * math.max(0, math.min(1, share))))
    spark:SetShown(share > 0 and share < 1)
end

-- Rewards (round, in a row) and the quests and options (a line each), then
-- the answers
local itemLabel = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontNormal"), GOLD)
local items = CreateFrame("Frame", nil, panel)
items:SetSize(WIDTH, ITEM)
local extra = Shadowed(items:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
local rows = CreateFrame("Frame", nil, panel)
rows:SetWidth(WIDTH)
local answers = CreateFrame("Frame", nil, panel)
answers:SetSize(WIDTH, ROW_H)


---------------------------------------------------------------------------
-- Pools: a row (a quest or an option), a reward, an answer
---------------------------------------------------------------------------
-- (lit: the mouse on it or the game's cursor: its words gold)
local function Lit(button)
    local on = button.lit or button.pointed or false
    if button.text then
        local c = on and (button.litColor or GOLD) or (button.color or { 1, 1, 1 })
        button.text:SetTextColor(c[1], c[2], c[3])
    end
    if button.hl then button.hl:SetShown(on) end
end

local rowPool, itemPool, answerPool = {}, {}, {}

-- (an icon in the round slot's ring)
local function RoundIcon(parent, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    local ring = parent:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -size * 0.14, size * 0.14)
    ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", size * 0.14, -size * 0.14)
    ring:SetAtlas(RING)
    return icon, ring
end

local function Row(i)
    local r = rowPool[i]
    if r then return r end
    r = CreateFrame("Button", nil, rows)
    r:SetHeight(ROW_H)
    -- (its icon plain and small, as a line's bullet in Spoken's)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.text = Shadowed(r:CreateFontString(nil, "OVERLAY", "QuestFont"), { 1, 1, 1 })
    r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self) self.lit = true Lit(self) end)
    r:SetScript("OnLeave", function(self) self.lit = nil Lit(self) end)
    r:SetScript("OnClick", function(self) if self.Run then self.Run() end end)
    rowPool[i] = r
    return r
end

local function ItemButton(i)
    local b = itemPool[i]
    if b then return b end
    b = CreateFrame("Button", nil, items)
    b:SetSize(ITEM, ITEM)
    b.icon, b.ring = RoundIcon(b, ITEM)
    b.icon:SetPoint("CENTER")
    -- (no ring but the picked one's: round icons, as Spoken's face)
    b.ring:Hide()
    b.hl = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.hl:SetAllPoints(b.ring)
    b.hl:SetAtlas(RING)
    b.hl:SetBlendMode("ADD")
    b.hl:Hide()
    -- (the picked reward: its ring gold)
    b.chosen = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.chosen:SetAllPoints(b.ring)
    b.chosen:SetAtlas(RING)
    b.chosen:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", 2, -2)
    b:SetScript("OnEnter", function(self)
        self.lit = true
        Lit(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        pcall(GameTooltip.SetQuestItem, GameTooltip, self.kind, self.index)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.lit = nil
        Lit(self)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self) if self.Run then self.Run() end end)
    itemPool[i] = b
    return b
end

-- (an answer: the press's glyph (the pad's), its word in gold)
local function AnswerButton(i)
    local b = answerPool[i]
    if b then return b end
    b = CreateFrame("Button", nil, answers)
    b:SetHeight(ROW_H)
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.glyph:SetSize(20, 20)
    b.glyph:SetPoint("LEFT")
    b.text = Shadowed(b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), GOLD)
    -- (gold, white when lit: the mouse on it or the cursor)
    b.color, b.litColor = GOLD, { 1, 1, 1 }
    b:SetScript("OnEnter", function(self) self.lit = true Lit(self) end)
    b:SetScript("OnLeave", function(self) self.lit = nil Lit(self) end)
    -- (an answer leaves the page: Spoken's line for it stopped first)
    b:SetScript("OnClick", function(self)
        ND.StopLine()
        if self.Run then self.Run() end
    end)
    answerPool[i] = b
    return b
end

---------------------------------------------------------------------------
-- What the game's windows show now: a dialog { kind, native, unit, title,
-- text, rows = { { key, text, icon/atlas, Run } }, items = { { kind,
-- index, texture, count, choice } }, itemLabel, money, xp, answers = { {
-- key ("PAD1" / "PAD2"), text, Run, disabled } }, scrollFrame }
---------------------------------------------------------------------------
local choice = 0        -- (the reward picked with the mouse)

local function QuestItems(list, kind, count, label)
    local first = #list + 1
    for i = 1, count do
        local itemName, texture, number = GetQuestItemInfo(kind, i)
        if texture then
            list[#list + 1] = { kind = kind, index = i, texture = texture, count = number, name = itemName }
        end
    end
    return #list >= first and label or nil
end

local function Rewards(d)
    d.items = {}
    local choices = GetNumQuestChoices() or 0
    local label = QuestItems(d.items, "choice", choices, choices > 1 and "Choose one" or nil)
    if choices > 0 then
        for _, it in ipairs(d.items) do it.choice = true end
    end
    QuestItems(d.items, "reward", GetNumQuestRewards() or 0)
    local money = GetRewardMoney and GetRewardMoney() or 0
    local xp = GetRewardXP and GetRewardXP() or 0
    d.money = money > 0 and money or nil
    d.xp = xp > 0 and xp or nil
    d.itemLabel = label or ((#d.items > 0 or d.money or d.xp) and "Rewards" or nil)
end

-- (the chosen reward: the mouse's, else the game's window's)
local function Chosen()
    if choice > 0 then return choice end
    local info = _G.QuestInfoFrame
    return info and type(info.itemChoice) == "number" and info.itemChoice or 0
end

local function Greeting()
    local d = { kind = "greeting", text = GetGreetingText(), rows = {}, scrollFrame = _G.QuestGreetingScrollFrame }
    for i = 1, GetNumActiveQuests() or 0 do
        local _, complete = GetActiveTitle(i)
        d.rows[#d.rows + 1] = { key = "qactive:" .. i, text = (GetActiveTitle(i)),
            atlas = complete and "QuestTurnin" or "SideInProgressquesticon", Run = function() SelectActiveQuest(i) end }
    end
    for i = 1, GetNumAvailableQuests() or 0 do
        d.rows[#d.rows + 1] = { key = "qavail:" .. i, text = GetAvailableTitle(i), atlas = "QuestNormal",
            Run = function() SelectAvailableQuest(i) end }
    end
    d.answers = { { key = "PAD2", text = GOODBYE or "Goodbye", Run = CloseQuest } }
    return d
end

local function Detail()
    local d = { kind = "detail", title = GetTitleText(), text = GetQuestText(), scrollFrame = _G.QuestDetailScrollFrame }
    local objectives = GetObjectiveText and GetObjectiveText()
    if objectives and objectives ~= "" then
        d.extra = "|cffffd100" .. (QUEST_OBJECTIVES or "Objectives") .. "|r\n" .. objectives
    end
    Rewards(d)
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        d.answers = { { key = "PAD1", text = OKAY or "Okay", Run = AcknowledgeAutoAcceptQuest } }
    else
        d.answers = {
            { key = "PAD1", text = ACCEPT or "Accept", Run = AcceptQuest },
            { key = "PAD2", text = DECLINE or "Decline", Run = DeclineQuest },
        }
    end
    return d
end

local function Progress()
    local d = { kind = "progress", title = GetTitleText(), text = GetProgressText(), scrollFrame = _G.QuestProgressScrollFrame }
    d.items = {}
    d.itemLabel = QuestItems(d.items, "required", GetNumQuestItems() or 0, "Required items")
    local can = IsQuestCompletable()
    d.answers = {
        { key = "PAD1", text = CONTINUE or "Continue", Run = CompleteQuest, disabled = not can },
        { key = "PAD2", text = GOODBYE or "Goodbye", Run = CloseQuest },
    }
    return d
end

local function Reward()
    local d = { kind = "reward", title = GetTitleText(), text = GetRewardText(), scrollFrame = _G.QuestRewardScrollFrame }
    Rewards(d)
    local choices = GetNumQuestChoices() or 0
    d.answers = {
        { key = "PAD1", text = COMPLETE_QUEST or "Complete Quest", Run = function()
            local picked = choices == 1 and 1 or Chosen()
            if choices > 1 and picked <= 0 then
                UIErrorsFrame:AddMessage(ERR_QUEST_MUST_CHOOSE or "You must choose a reward.", 1, 0.1, 0.1)
                return
            end
            GetQuestReward(picked)
        end },
        { key = "PAD2", text = CANCEL or "Cancel", Run = CloseQuest },
    }
    return d
end

local function Gossip()
    local info = C_GossipInfo
    local d = { kind = "gossip", text = info.GetText(), rows = {} }
    local panel = GossipFrame and GossipFrame.GreetingPanel
    d.scrollBox = panel and panel.ScrollBox
    for _, quest in ipairs(info.GetAvailableQuests() or {}) do
        local id = quest.questID
        d.rows[#d.rows + 1] = { key = "avail:" .. tostring(id), text = quest.title,
            atlas = "QuestNormal", trivial = quest.isTrivial,
            Run = function() info.SelectAvailableQuest(id) end }
    end
    for _, quest in ipairs(info.GetActiveQuests() or {}) do
        local id = quest.questID
        d.rows[#d.rows + 1] = { key = "active:" .. tostring(id), text = quest.title,
            atlas = quest.isComplete and "QuestTurnin" or "SideInProgressquesticon",
            Run = function() info.SelectActiveQuest(id) end }
    end
    local options = info.GetOptions() or {}
    table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    for _, option in ipairs(options) do
        local index = option.orderIndex or 0
        d.rows[#d.rows + 1] = { key = "option:" .. tostring(index), text = option.name,
            texture = option.overrideIconID or option.icon, Run = function() info.SelectOptionByIndex(index) end }
    end
    d.answers = { { key = "PAD2", text = GOODBYE or "Goodbye", Run = info.CloseGossip } }
    return d
end

-- The window of the game's shown now and its dialog, or nil
local function Read()
    local gossip, quest = _G.GossipFrame, _G.QuestFrame
    if gossip and gossip:IsShown() and C_GossipInfo then
        local d = Gossip()
        d.native, d.unit = gossip, "npc"
        return d
    end
    if quest and quest:IsShown() then
        local d
        if _G.QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then d = Detail()
        elseif _G.QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then d = Progress()
        elseif _G.QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then d = Reward()
        elseif _G.QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then d = Greeting()
        end
        if d then d.native, d.unit = quest, "questnpc" end
        return d
    end
end

---------------------------------------------------------------------------
-- Spoken: its line for this NPC, if it has one
---------------------------------------------------------------------------
local function Spoken()
    local s = _G.Spoken
    return type(s) == "table" and s.IsCompatible and s:IsCompatible(1) and s or nil
end

local current           -- (the dialog shown)

-- Spoken's line now for ours: the clip and whether it speaks, or nil
local shownClip         -- (the one ours shows, remembered)
local function Line()
    local s = Spoken()
    if not (s and current) then return nil end
    local ok, clip = pcall(s.GetCurrent, s)
    local present = ok and type(clip) == "table" and clip.present
    if not present then return nil end
    if present.header ~= current.name and present.label ~= current.title then return nil end
    shownClip = clip
    local playing = s:GetNowPlaying() == clip and not s:IsPaused()
    return clip, playing
end

-- Whether Spoken has this page's line queued (speaking or not yet)
local function Queued()
    local s = Spoken()
    if not (s and current) then return false end
    local ok, queue = pcall(s.GetQueue, s)
    if not ok or type(queue) ~= "table" then return false end
    for _, clip in ipairs(queue) do
        local present = type(clip) == "table" and clip.present
        if present and (present.header == current.name or (current.title and present.label == current.title)) then
            return true
        end
    end
    return false
end

-- Whether Spoken's quest addon (Spoken_Quests: its env is the global
-- VoiceOver) has found no voice for the window opened last: the stage it
-- records for its read of it, in the frame of the game's event (gossip a
-- tenth of a second later), is one where no line was queued
local NO_VOICE = { ["data-lookup-failed"] = true, ["sound-disabled"] = true, ["file-playback-failed"] = true,
    ["queue-outranked"] = true, ["player-missing"] = true, ["quest-id-missing"] = true, ["autoplay-off"] = true,
    ["skipped"] = true, ["handler-missing"] = true, ["handler-error"] = true }
local eventAt           -- (when the game's window last opened or turned a page)
local function NoVoice()
    local vo = rawget(_G, "VoiceOver")
    local debug = type(vo) == "table" and rawget(vo, "Debug")
    local runtime = type(debug) == "table" and debug.runtime
    return type(runtime) == "table" and eventAt ~= nil and type(runtime.time) == "number"
        and runtime.time >= eventAt and NO_VOICE[runtime.stage] == true
end

-- Spoken's line for the page left (answered, closed, another page come):
-- stopped, if it's still the one speaking (the next page's own line, queued
-- behind it, then plays)
function ND.StopLine()
    local s = Spoken()
    if s and shownClip then
        local ok, head = pcall(s.GetCurrent, s)
        if ok and head == shownClip then pcall(s.Skip, s) end
    end
    shownClip = nil
end

local function Caption()
    local s = Spoken()
    local ok, caption = pcall(function() return s and s.GetCaption and s:GetCaption() end)
    return ok and type(caption) == "table" and caption or nil
end

local function Progressed()
    local caption = Caption()
    local f = caption and caption.progress
    if type(f) ~= "number" then return nil end
    local total = caption.totalWeight
    if f > 1 and type(total) == "number" and total > 0 then f = f / total end
    return math.max(0, math.min(1, f))
end

---------------------------------------------------------------------------
-- The words while Spoken speaks them, as its subtitle shows a line (its
-- UI/Subtitle.lua): pages of whole sentences (at most PAGE_SENTENCES and
-- MAX_LINES lines; a longer sentence turned at its phrases, then between
-- words), each page its letters' share of the line's time (or from the
-- line's word times), the page on screen fading out and the next in, its
-- letters typed in a little ahead of the voice, each line in a slot of its
-- finished width, centred, typed from the left
---------------------------------------------------------------------------
local PAGE_SENTENCES, MAX_LINES, LINE_GAP = 3, 4, 2
local PAGE_OUT, PAGE_IN = .18, .28
local HIGHLIGHT = "|cffffd100"
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local LINE_W = WIDTH - 2 * PAD

-- (on the panel, over the scroll frame's place, not in it: lines changing
-- every frame inside a scroll child weren't always drawn again until the
-- game's window lost and got back focus)
local typed = CreateFrame("Frame", nil, panel)
typed:SetPoint("TOPLEFT", scroll, "TOPLEFT")
typed:SetPoint("TOPRIGHT", scroll, "TOPRIGHT")
typed:Hide()
local measure = typed:CreateFontString(nil, "OVERLAY", "QuestFont")
measure:SetWordWrap(false)
measure:Hide()
local lines = {}

local function Characters(text)
    local _, count = text:gsub(UTF8_CHAR, "")
    return count
end

-- (its first `count` characters)
local function Prefix(text, count)
    local n = 0
    for at in text:gmatch("()" .. UTF8_CHAR) do
        if n >= count then return text:sub(1, at - 1) end
        n = n + 1
    end
    return text
end

local function Width(text)
    measure:SetText(text)
    return measure:GetStringWidth()
end

-- (the lines it wraps to at the words' width; a word wider than a line
-- broken between its letters)
local function Wrap(text)
    local wrapped, line = {}, ""
    local function Add(piece, joiner)
        local trial = line == "" and piece or line .. joiner .. piece
        if line == "" or Width(trial) <= LINE_W then
            line = trial
        else
            wrapped[#wrapped + 1] = line
            line = piece
        end
    end
    for word in text:gmatch("%S+") do
        if Width(word) <= LINE_W then
            Add(word, " ")
        else
            local joiner = " "
            for char in word:gmatch(UTF8_CHAR) do
                Add(char, joiner)
                joiner = ""
            end
        end
    end
    if line ~= "" then wrapped[#wrapped + 1] = line end
    return wrapped
end

-- (its sentences, each with its closing quote and the space after kept)
local function Sentences(text)
    local found, rest = {}, 1
    for sentence, finish in text:gmatch("([^%.!?]*[%.!?]+[\"')%]]*%s*)()") do
        found[#found + 1] = sentence
        rest = finish
    end
    local tail = text:sub(rest)
    if tail:find("%S") then found[#found + 1] = tail end
    return found
end

-- (a sentence's phrases: each ends after a comma, semicolon, colon or
-- dash, its closing quote and the space after kept)
local PHRASE_ENDS = { [","] = true, [";"] = true, [":"] = true, ["\226\128\148"] = true, ["\226\128\147"] = true }
local PHRASE_CLOSERS = { ['"'] = true, ["'"] = true, [")"] = true, ["]"] = true, ["\226\128\157"] = true,
    ["\226\128\153"] = true }
local function Phrases(sentence)
    local chars = {}
    for char in sentence:gmatch(UTF8_CHAR) do chars[#chars + 1] = char end
    local phrases, phrase, i = {}, "", 1
    while i <= #chars do
        local char = chars[i]
        phrase = phrase .. char
        local dash = char == "-" and chars[i + 1] == "-"
        if dash then
            i = i + 1
            phrase = phrase .. chars[i]
        end
        if PHRASE_ENDS[char] or dash then
            while chars[i + 1] and PHRASE_CLOSERS[chars[i + 1]] do
                i = i + 1
                phrase = phrase .. chars[i]
            end
            while chars[i + 1] and chars[i + 1]:find("^%s$") do
                i = i + 1
                phrase = phrase .. chars[i]
            end
            phrases[#phrases + 1] = phrase
            phrase = ""
        end
        i = i + 1
    end
    if phrase:find("%S") then phrases[#phrases + 1] = phrase end
    return phrases
end

-- (the pages, as Spoken's Paginate: { text, count (characters), rows })
local function Paginate(text)
    local function Fits(candidate) return #Wrap(candidate) <= MAX_LINES end
    local found = {}
    local sentences = Sentences(text)
    if #sentences <= PAGE_SENTENCES and Fits(text) then
        found[1] = text
    else
        local pageText, count = "", 0
        local function Close()
            if pageText:find("%S") then found[#found + 1] = (pageText:gsub("%s+$", "")) end
            pageText, count = "", 0
        end
        -- (a phrase longer than a page, cut between words into runs that fit)
        local function Cut(piece)
            local runs, run = {}, ""
            for word, space in piece:gmatch("(%S+)(%s*)") do
                if run ~= "" and not Fits(run .. word) then
                    runs[#runs + 1] = run
                    run = ""
                end
                run = run .. word .. space
            end
            if run:find("%S") then runs[#runs + 1] = run end
            return runs
        end
        for _, sentence in ipairs(sentences) do
            if Fits(sentence) then
                if count >= PAGE_SENTENCES or (pageText ~= "" and not Fits(pageText .. sentence)) then Close() end
                pageText, count = pageText .. sentence, count + 1
            else
                Close()
                for _, phrase in ipairs(Phrases(sentence)) do
                    for _, part in ipairs(Fits(phrase) and { phrase } or Cut(phrase)) do
                        if pageText ~= "" and not Fits(pageText .. part) then Close() end
                        pageText = pageText .. part
                    end
                end
                Close()
            end
        end
        Close()
    end
    local pages = {}
    for i, t in ipairs(found) do
        t = strtrim(t)
        pages[i] = { text = t, count = Characters(t), rows = #Wrap(t) }
    end
    return pages
end

-- (each page's start and length in the line's time: its letters' share,
-- never turned in under a second; with the line's own word times, when the
-- voice reaches its first word)
local function TimePages(pages, duration)
    local total, start = 0, 0
    for _, p in ipairs(pages) do total = total + p.count end
    total = math.max(1, total)
    for i, p in ipairs(pages) do
        p.length = duration * p.count / total
        if i > 1 then start = math.max(1, start) end
        p.start = start
        start = start + p.length
    end
    local s, caption = Spoken(), Caption()
    if not (s and s.SplitCaption and caption and caption.timed and type(caption.words) == "table") then return end
    local starts, word = { 0 }, 1
    for i, p in ipairs(pages) do
        if i > 1 then
            local w = caption.words[word]
            if not (type(w) == "table" and type(w.start) == "number") then return end
            starts[i] = w.start
        end
        local ok, split = pcall(s.SplitCaption, s, p.text)
        if not ok or type(split) ~= "table" then return end
        word = word + #split
    end
    if word - 1 ~= #caption.words then return end
    for i, p in ipairs(pages) do
        p.start, p.length = starts[i], (starts[i + 1] or duration) - starts[i]
    end
end

-- (the words' state: their pages, the line they're timed to, the page on
-- screen, its fade, when it turned, its rows typed so far)
local words = {}

local function LineString(i)
    if not lines[i] then
        local line = Shadowed(typed:CreateFontString(nil, "OVERLAY", "QuestFont"), { 1, 1, 1 })
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        line:SetWordWrap(false)
        lines[i] = line
    end
    return lines[i]
end

local function LineStep()
    measure:SetText("Ag")
    return measure:GetStringHeight() + LINE_GAP
end

-- (the height the words keep while they're typed: their tallest page's,
-- so what's under them stays put as pages turn)
local function TypedHeight()
    local most = 1
    for _, p in ipairs(words.pages or {}) do most = math.max(most, p.rows) end
    return most * LineStep() - LINE_GAP
end

-- (a page laid out: each row in a slot of its finished width, centred,
-- empty until typed; the rows in the middle of the words' height)
local function LayoutPage(text)
    local step = LineStep()
    words.rows = {}
    for i, row in ipairs(Wrap(text)) do
        words.rows[i] = { text = row, count = Characters(row) }
    end
    local top = math.floor((TypedHeight() - (#words.rows * step - LINE_GAP)) / 2)
    for i, row in ipairs(words.rows) do
        local line = LineString(i)
        if line.face then
            line:SetFontObject(QuestFont)
            line.face, line.size = nil, nil
        end
        line:SetAlpha(1)
        line:SetWidth(Width(row.text) + 2)
        line:ClearAllPoints()
        line:SetPoint("TOP", typed, "TOP", 0, -(top + (i - 1) * step))
        line:SetText("")
        line:Show()
    end
    for i = #words.rows + 1, #lines do lines[i]:Hide() end
    -- (where each word ends among the rows' characters, for the lit word)
    words.wordEnds = {}
    local total = 0
    for _, row in ipairs(words.rows) do
        for finish in row.text:gmatch("%S+()") do
            words.wordEnds[#words.wordEnds + 1] = total + Characters(row.text:sub(1, finish - 1))
        end
        total = total + row.count
    end
    words.revealed, words.revealedLit = nil, nil
end

-- (the rows holding the first `count` characters typed; the word `lit`
-- lit)
local function Reveal(count, lit)
    if count == words.revealed and (lit or 0) == words.revealedLit then return end
    words.revealed, words.revealedLit = count, lit or 0
    local from, to
    if lit then from, to = words.wordEnds[lit - 1] or 0, words.wordEnds[lit] end
    local offset = 0
    for i, row in ipairs(words.rows) do
        local text = count >= row.count and row.text or Prefix(row.text, count)
        if from and to > offset and from < offset + row.count then
            local head = Prefix(row.text, math.max(0, from - offset))
            local through = Prefix(row.text, to - offset)
            if #through > #text then through = text end
            if #head < #through then
                text = head .. HIGHLIGHT .. through:sub(#head + 1) .. "|r" .. text:sub(#through + 1)
            end
        end
        lines[i]:SetText(text)
        count = math.max(0, count - row.count)
        offset = offset + row.count
    end
end

-- (the word the voice is on, by its share of the page's time)
local function LitWord(p, elapsed)
    local at = (elapsed - p.start) / math.max(.5, p.length) * p.count
    if at < 0 or at >= p.count then return nil end
    for n, finish in ipairs(words.wordEnds or {}) do
        if at < finish then return n end
    end
end

-- (the words to follow the voice in: fresh for other words)
local function PrepareWords(text)
    if words.text == text then return end
    words = { text = text, pages = Paginate(text), active = words.active }
end

-- Spoken's own subtitle (SpokenEnv.Subtitle, its UI/Subtitle.lua), when
-- subtitles are how Spoken shows lines: it runs as ever under ours, faded
-- (FadeSubtitle), and ours copies its lines each frame (their words typed so
-- far, the lit word, their fades, where they sit), so ours reads exactly as
-- Spoken's would. Only read: nothing of Spoken's is set or called but its
-- Wrap (measuring) and DisplayStyle.
local function SpokenSubtitle()
    local env = rawget(_G, "SpokenEnv")
    if type(env) ~= "table" then return nil end
    local S, A = rawget(env, "Subtitle"), rawget(env, "Addon")
    if type(S) ~= "table" or type(A) ~= "table" or not S.frame or type(S.lines) ~= "table" then return nil end
    local ok, style = pcall(A.DisplayStyle, A)
    return ok and style == "subtitle" and S or nil
end

-- (the height its words keep: its tallest page's, or the lines it rolls
-- through)
local function MirrorHeight(S)
    local step = tonumber(S.lineStep)
    if not (step and type(S.pages) == "table") then return nil end
    if words.mirrorPages ~= S.pages or words.mirrorStep ~= step then
        local most = 1
        for _, p in ipairs(S.pages) do
            local ok, wrapped = pcall(S.Wrap, S, p.text)
            if ok and type(wrapped) == "table" then most = math.max(most, #wrapped) end
        end
        if #S.pages == 1 and tonumber(S.shownRows) then most = math.min(most, math.max(1, S.shownRows)) end
        words.mirrorPages, words.mirrorStep = S.pages, step
        words.mirrorHeight = most * step - LINE_GAP
    end
    return words.mirrorHeight
end

local function SpokenTranscript()
    local env = rawget(_G, "SpokenEnv")
    local T = type(env) == "table" and rawget(env, "Transcript")
    return type(T) == "table" and T or nil
end

-- (probe: why the words stall; a line a state change, in IF.db.ndLog,
-- written on /reload)
local logKey, logStarted
local function LogLine(text)
    if not IF.db then return end
    if not logStarted then
        logStarted = true
        IF.db.ndLog = { date("%H:%M:%S") }
    end
    local log = IF.db.ndLog
    if #log < 400 then log[#log + 1] = format("%.2f %s", GetTime() % 1000, text) end
end
local function Log(mirror, S, clip, playing)
    if not IF.db then return end
    local T = SpokenTranscript()
    local key = table.concat({ tostring(mirror), tostring(S ~= nil), tostring(S and S.wanted),
        tostring(S and S.clip == clip), tostring(playing), tostring(T and T.hasStarted), tostring(T and T.held),
        tostring(T and T.clip == clip), tostring(words.page), tostring(S and S.page) }, " ")
    if key == logKey then return end
    logKey = key
    -- (a fresh log each session)
    if not logStarted then
        logStarted = true
        IF.db.ndLog = { date("%H:%M:%S") }
    end
    local log = IF.db.ndLog
    if #log < 400 then
        log[#log + 1] = format("%.2f mirror=%s sub=%s wanted=%s subClip=%s playing=%s started=%s held=%s tClip=%s page=%s subPage=%s",
            GetTime() % 1000, strsplit(" ", key))
    end
end

-- (its lines, as they are now, in ours; the words' height changed: true)
local function MirrorWords(S)
    local height = S.wanted and S.rows and MirrorHeight(S)
    if not height then
        for _, line in ipairs(lines) do line:Hide() end
        return false
    end
    typed:SetAlpha(1)
    local step = S.lineStep
    local top = math.floor((height - ((S.shownRows or #S.rows) * step - LINE_GAP)) / 2)
    local wordsTop = tonumber(S.wordsTop) or 0
    for i, src in ipairs(S.lines) do
        local line = LineString(i)
        if src:IsShown() then
            local _, _, _, _, y = src:GetPoint(1)
            local face, size, flags = src:GetFont()
            if face and (face ~= line.face or size ~= line.size) then
                line:SetFont(face, size, flags or "")
                line.face, line.size = face, size
            end
            line:SetWidth(src:GetWidth())
            line:ClearAllPoints()
            line:SetPoint("TOP", typed, "TOP", 0, (y or 0) + wordsTop - top)
            line:SetText(src:GetText() or "")
            line:SetAlpha(src:GetAlpha())
            line:Show()
        else
            line:Hide()
        end
    end
    for i = #S.lines + 1, #lines do lines[i]:Hide() end
    words.revealed = nil
    return height ~= words.builtHeight
end

-- Each frame while typed: the page the voice is on, faded to, typed (Spoken's
-- own subtitle's lines when it runs; else ours, done the way it does them).
-- The words' height changed: true (laid out again)
local function FollowWords()
    local now = GetTime()
    local dt = now - (words.last or now)
    words.last = now
    local clip, playing = Line()
    -- (the time the voice has played, by our own clock: for while Spoken's
    -- captions haven't started on it (they wait while one of its windows
    -- fades out, and only then start the line's clock))
    if clip ~= words.playedClip then words.playedClip, words.played = clip, 0 end
    if playing then words.played = words.played + dt end
    local S = SpokenSubtitle()
    local mirror = S ~= nil and S.wanted and S.pages ~= nil and S.rows ~= nil and S.clip == clip
    Log(mirror, S, clip, playing)
    if mirror then
        words.mirror = true
        return MirrorWords(S)
    end
    -- (from Spoken's lines back to ours: laid out again)
    if words.mirror then words.mirror, words.page, words.fade = false, nil, nil end
    if not (clip and words.pages and #words.pages > 0) then
        for _, line in ipairs(lines) do line:Hide() end
        words.page, words.fade = nil, nil
        return
    end
    local duration = tonumber(clip.length)
    if not duration or duration <= 0 then duration = math.max(3, Characters(words.text) * .072) end
    if words.clip ~= clip then
        words.clip, words.page, words.fade = clip, nil, nil
        TimePages(words.pages, duration)
    end
    local T = SpokenTranscript()
    local share = T and T.hasStarted and T.clip == clip and Progressed()
    local elapsed = share and share * duration or words.played
    -- (the page on screen fading out, the next laid out once it's gone,
    -- then fading in)
    local alpha = 1
    local fade = words.fade
    if fade then
        fade.t = fade.t + dt
        if fade.phase == "out" then
            alpha = 1 - math.min(1, fade.t / PAGE_OUT)
            if fade.t >= PAGE_OUT then
                words.page, words.turnedAt = fade.to, elapsed
                LayoutPage(words.pages[fade.to].text)
                fade.phase, fade.t, alpha = "in", 0, 0
            end
        else
            local t = math.min(1, fade.t / PAGE_IN)
            alpha = 1 - (1 - t) * (1 - t)
            if t >= 1 then words.fade = nil end
        end
    end
    local index = 1
    for i, p in ipairs(words.pages) do
        if elapsed >= p.start then index = i end
    end
    if index ~= words.page then
        if words.page then
            fade = words.fade
            if fade and fade.phase == "out" then
                fade.to = index
            elseif not (fade and fade.to == index) then
                local from = fade and fade.alpha or 1
                words.fade = { to = index, t = (1 - from) * PAGE_OUT, phase = "out" }
                alpha = from
            end
        else
            words.page, words.turnedAt = index, elapsed
            LayoutPage(words.pages[index].text)
        end
    end
    if words.fade then words.fade.alpha = alpha end
    typed:SetAlpha(alpha)
    -- (typed a little ahead of the voice, so a page is whole a moment
    -- before it's read; whole while fading out; whole, the word lit, with
    -- Spoken's typing off)
    local p = words.pages[words.page]
    local caption = Caption()
    if caption and caption.typewriter == false then
        return Reveal(p.count, caption.highlight and LitWord(p, elapsed) or nil)
    end
    if words.fade and words.fade.phase == "out" then return Reveal(p.count) end
    if words.builtHeight ~= TypedHeight() then return true end
    local rate = p.count / math.max(.5, p.length - .4) + 10
    Reveal(math.floor(math.max(0, elapsed - math.max(p.start, words.turnedAt or 0)) * rate))
end

-- Spoken's own subtitle (SpokenSubtitleFrame, its UI/Subtitle.lua) faded
-- while ours shows (IF.Focus.Fade: a frame of another addon's, left as it
-- is): ours is the whole of it, the words whole, Spoken's line only as its
-- progress over the answers
local hadLine = false
local showAll = false    -- (Square / the mouse: the voice stopped, all the words)
-- (new words: Spoken's line for them waited for, as it queues the line a
-- moment after the game's window opens: as long as it's in Spoken's queue,
-- else LINE_WAIT, then the words fade in whole)
local LINE_WAIT, WORDS_IN = 0.8, 0.28
local waitUntil, wordsInFrom
local subtitleFaded = false
local function FadeSubtitle(on)
    local f = _G.SpokenSubtitleFrame
    if f and on ~= subtitleFaded then
        subtitleFaded = on
        IF.Focus.Fade(f, on)
    end
end

---------------------------------------------------------------------------
-- Laying it out, top to bottom, each part centred
---------------------------------------------------------------------------
local primary           -- (the cursor's spot when the game's is on none of ours: the first row)
local byKey = {}        -- (our row / reward for the game's button)

-- (a page's badge on Spoken's face: its quest moment, or gossip)
local BULLETS = { detail = "quest-accept", progress = "quest-progress", reward = "quest-complete",
    greeting = "gossip", gossip = "gossip" }

-- (whether Spoken speaks the page's words, and whether they're typed as it
-- does (speaking, or its line waited for) or shown whole: words.active)
local function WordsMode(d)
    local speaking = Spoken() ~= nil and Line() ~= nil
    if speaking then waitUntil = nil end
    if waitUntil and NoVoice() then waitUntil = nil end
    local waiting = waitUntil ~= nil and (GetTime() < waitUntil or Queued())
    words.active = (speaking or waiting) and not showAll and (d.text or "") ~= ""
    do
        local s = Spoken()
        local ok, head = pcall(function() return s and s:GetCurrent() end)
        local present = ok and type(head) == "table" and head.present or {}
        local playingOk, now = pcall(function() return s and s:GetNowPlaying() end)
        LogLine(format("build %s speaking=%s showAll=%s active=%s head=%s/%s ours=%s/%s nowPlayingIsHead=%s",
            tostring(d.kind), tostring(speaking), tostring(showAll), tostring(words.active),
            tostring(present.header), tostring(present.label), tostring(d.name), tostring(d.title),
            tostring(playingOk and now == head)))
    end
    return speaking
end

local function Build(d)
    -- (other words (another gossip page): followed from their start)
    if not current or current.text ~= d.text then
        showAll = false
        waitUntil = Spoken() and GetTime() + LINE_WAIT or nil
    end
    current = d
    wipe(byKey)
    primary = nil
    local unit = UnitExists(d.unit) and d.unit or "npc"
    d.name = UnitName(unit) or ""

    Band()

    -- (the face, the name, " • " and the quest's title, centred as one)
    if UnitExists(unit) then
        SetPortraitTexture(portrait, unit)
    else
        portrait:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    end
    name:SetText(d.name)
    local label = d.title and d.title ~= "" and ('"' .. d.title .. '"') or nil
    title:SetText(label or "")
    dot:SetShown(label ~= nil)
    title:SetShown(label ~= nil)
    title:SetWidth(0)
    local nameW = name:GetStringWidth()
    local labelW = label and math.min(title:GetStringWidth(), WIDTH - 2 * PAD - FACE - FACE_GAP - nameW - 40) or 0
    title:SetWidth(math.max(1, labelW))
    local rowW = FACE + FACE_GAP + nameW + (label and (LABEL_GAP * 2 + dot:GetStringWidth() + labelW) or 0)
    -- (Spoken's face in ours' place when it's there: who speaks, the
    -- page's badge)
    local shownFace = face
    local sf = SpokenFace()
    if sf then
        face:Hide()
        sf:Show()
        local guid = UnitExists(unit) and UnitGUID(unit) or nil
        if guid and issecretvalue and issecretvalue(guid) then guid = nil end
        local id = guid and tonumber((select(6, strsplit("-", guid))))
        pcall(sf.SetSpeaker, sf, { creatureID = id, guid = guid, bullet = BULLETS[d.kind] })
        shownFace = sf
    end
    shownFace:ClearAllPoints()
    shownFace:SetPoint("TOPLEFT", panel, "TOP", -rowW / 2, -PAD)
    name:ClearAllPoints()
    name:SetPoint("LEFT", shownFace, "RIGHT", FACE_GAP, 0)
    dot:ClearAllPoints()
    dot:SetPoint("LEFT", name, "RIGHT", LABEL_GAP, 0)
    title:ClearAllPoints()
    title:SetPoint("LEFT", dot, "RIGHT", LABEL_GAP, 0)
    status:ClearAllPoints()
    status:SetPoint("LEFT", label and title or name, "RIGHT", LABEL_GAP, 0)
    local y = PAD + FACE + TITLE_GAP

    local function Place(region, height, gap)
        region:ClearAllPoints()
        region:SetPoint("TOP", panel, "TOP", 0, -y)
        y = y + height + (gap or GAP)
    end

    -- (the words: while Spoken speaks them, the page it's on (as its
    -- subtitle); else (done, stopped, or Show all) all of them)
    local speaking = WordsMode(d)
    local h
    if words.active then
        -- (typed as the voice reads them: FollowWords)
        PrepareWords(d.text)
        local S = SpokenSubtitle()
        h = S and S.wanted and S.clip == Line() and MirrorHeight(S) or TypedHeight()
        words.builtHeight = h
        typed:SetHeight(h)
    else
        local text = d.text or ""
        if d.extra then text = text .. "\n\n" .. d.extra end
        body:SetText(text)
        h = body:GetStringHeight()
        words.page, words.fade = nil, nil
    end
    typed:SetShown(words.active)
    body:SetShown(not words.active)
    page:SetHeight(h)
    scroll:SetHeight(math.max(1, math.min(h, BODY_MAX)))
    scroll:SetVerticalScroll(0)
    Place(scroll, math.min(h, BODY_MAX), 12)

    -- (Spoken's line speaking: its progress, a line under the words on a
    -- quest's page (over its rewards), over the answers on the others; Show
    -- all beside it)
    local questPage = d.kind == "detail" or d.kind == "progress" or d.kind == "reward"
    track:SetShown(speaking)
    showAllButton:SetShown(speaking)
    if speaking then
        showAllButton.text:SetText((IF.Input.Pad() and (IF.GlyphText("PAD3", 16) .. " ") or "") .. "Show all")
        showAllButton:SetWidth(showAllButton.text:GetStringWidth())
    end
    if speaking and questPage then Place(track, PROGRESS_H, 12) end

    -- (the rewards or the items needed: their heading, then round icons,
    -- money and experience beside them)
    local list = d.items or {}
    local extras = {}
    if d.money then extras[#extras + 1] = IF.ItemValue.Money(d.money) end
    if d.xp then extras[#extras + 1] = d.xp .. " " .. (XP or "XP") end
    local hasItems = #list > 0 or #extras > 0
    itemLabel:SetText(d.itemLabel or "")
    itemLabel:SetShown(hasItems and d.itemLabel ~= nil)
    if itemLabel:IsShown() then Place(itemLabel, itemLabel:GetStringHeight(), 6) end
    extra:SetText(table.concat(extras, "    "))
    local extraW = #extras > 0 and (extra:GetStringWidth() + (#list > 0 and 14 or 0)) or 0
    local wide = #list * ITEM + math.max(0, #list - 1) * GAP + extraW
    for i, it in ipairs(list) do
        local b = ItemButton(i)
        b.kind, b.index, b.choice = it.kind, it.index, it.choice
        b.icon:SetTexture(it.texture)
        b.count:SetText(it.count and it.count > 1 and it.count or "")
        b.Run = it.choice and function()
            choice = it.index
            ND.Refresh()
        end or nil
        b:ClearAllPoints()
        b:SetPoint("LEFT", items, "CENTER", -wide / 2 + (i - 1) * (ITEM + GAP), 0)
        b:Show()
        byKey[it.kind .. ":" .. it.index] = b
    end
    for i = #list + 1, #itemPool do itemPool[i]:Hide() end
    extra:ClearAllPoints()
    extra:SetPoint("RIGHT", items, "CENTER", wide / 2, 0)
    items:SetShown(hasItems)
    if hasItems then Place(items, ITEM, 12) end

    -- (the quests and options: a round icon and the words, centred, one a
    -- line)
    local options = d.rows or {}
    for i, rowData in ipairs(options) do
        local r = Row(i)
        r.text:SetText(rowData.text or "")
        local shade = rowData.trivial and 0.6 or 1
        r.color = { shade, shade, shade }
        if rowData.atlas then r.icon:SetAtlas(rowData.atlas) else r.icon:SetTexture(rowData.texture) end
        local w = 16 + 6 + math.min(r.text:GetStringWidth(), WIDTH - 2 * PAD - 22)
        r:SetWidth(w)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.text:SetPoint("RIGHT", r, "RIGHT")
        r.Run = rowData.Run
        r:ClearAllPoints()
        r:SetPoint("TOP", rows, "TOP", 0, -(i - 1) * ROW_H)
        r:Show()
        Lit(r)
        byKey[rowData.key] = r
        primary = primary or r
    end
    for i = #options + 1, #rowPool do rowPool[i]:Hide() end
    rows:SetShown(#options > 0)
    if #options > 0 then
        rows:SetHeight(#options * ROW_H)
        Place(rows, #options * ROW_H, 10)
    end

    if speaking and not questPage then Place(track, PROGRESS_H, 10) end

    -- (the answers, in a row: the pad's glyph before each with the pad,
    -- the word alone with the mouse)
    local shown = {}
    for _, a in ipairs(d.answers or {}) do
        if not a.disabled then shown[#shown + 1] = a end
    end
    local pad = IF.Input.Pad()
    local width = 0
    for i, a in ipairs(shown) do
        local b = AnswerButton(i)
        local atlas = pad and IF.GlyphAtlas(a.key)
        if atlas then b.glyph:SetAtlas(atlas) end
        b.glyph:SetShown(atlas ~= nil and atlas ~= false)
        b.text:SetText(a.text)
        b.text:ClearAllPoints()
        if b.glyph:IsShown() then
            b.text:SetPoint("LEFT", b.glyph, "RIGHT", 4, 0)
        else
            b.text:SetPoint("LEFT")
        end
        b:SetWidth((b.glyph:IsShown() and 24 or 0) + b.text:GetStringWidth())
        b.Run = a.Run
        -- (the cursor's spot on a page with nothing to pick: the answer A
        -- gives (Accept, Continue...), as the game's window would)
        if a.key == "PAD1" and not primary then primary = b end
        width = width + b:GetWidth() + (i > 1 and 24 or 0)
    end
    local x = -width / 2
    for i = 1, #shown do
        local b = answerPool[i]
        b:ClearAllPoints()
        b:SetPoint("LEFT", answers, "CENTER", x, 0)
        x = x + b:GetWidth() + 24
        b:Show()
    end
    for i = #shown + 1, #answerPool do answerPool[i]:Hide() end
    answers:SetShown(#shown > 0)
    if #shown > 0 then Place(answers, ROW_H, 0) end

    panel:SetHeight(y + PAD)
    -- (the band a little past the top and bottom, BAND_REACH past each
    -- side)
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", -BAND_REACH, BAND_OVER_TOP)
    band:SetPoint("BOTTOMRIGHT", BAND_REACH, -BAND_OVER_BOTTOM)
    ND.Refresh()
end

---------------------------------------------------------------------------
-- Each frame: the reward picked, Spoken's state, the game's scrolling and
-- its cursor on ours
---------------------------------------------------------------------------
-- (the game's cursor and scroll hint faded while on its unseen window;
-- only changed when ours changes it: the Quest Tracker fades the cursor
-- too)
local pointer = false
local function HidePointer(hide)
    if pointer == hide then return end
    pointer = hide
    local nav = _G.SmartNavigation
    if nav and nav.Pointer then IF.Focus.Fade(nav.Pointer, hide) end
    if _G.GamepadScrollBarHint then IF.Focus.Fade(GamepadScrollBarHint, hide) end
end

-- Our row or reward for the game's focused button (by what it stands for)
local function KeyOf(button)
    if not button then return nil end
    if button.GetElementData then
        local ok, data = pcall(button.GetElementData, button)
        local info = ok and type(data) == "table" and data.info
        if info then
            if data.availableQuestButton then return "avail:" .. tostring(info.questID) end
            if data.activeQuestButton then return "active:" .. tostring(info.questID) end
            if data.titleOptionButton then return "option:" .. tostring(info.orderIndex) end
        end
    end
    if button.isActive ~= nil and button.GetID then
        return (button.isActive == 1 and "qactive:" or "qavail:") .. button:GetID()
    end
    if (button.type == "choice" or button.type == "reward") and button.GetID then
        return button.type .. ":" .. button:GetID()
    end
end

local pointed
local function Point(target)
    if pointed and pointed ~= target then
        pointed.pointed = nil
        Lit(pointed)
    end
    pointed = target
    if not target then return end
    target.pointed = true
    Lit(target)
end

local function NativeFocused()
    local m = IF.Focus.Manager()
    return m and m.isUIFocused and current and m.focusedFrame == current.native or false
end

function ND.Refresh()
    if not current then return end
    -- (rewards: the one picked marked)
    local chosen = Chosen()
    for _, b in ipairs(itemPool) do
        b.chosen:SetShown(b:IsShown() and b.choice and b.index == chosen or false)
    end
    -- (Spoken)
    -- (Spoken: "(Stopped)" after the title while its line for this NPC
    -- doesn't speak, as its subtitle; its progress)
    if Spoken() then
        local clip, playing = Line()
        status:SetText((clip and not playing) and ("(" .. (STOPPED or "Stopped") .. ")") or "")
        SetProgress(clip and (Progressed() or 0) or 0)
    else
        status:SetText("")
    end
end

-- (a trigger held: the press itself, or the modifier the game makes of it)
local EMULATED = { PADLTRIGGER = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" },
    PADRTRIGGER = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" } }
local MODIFIER_DOWN = { GamePadEmulateShift = IsShiftKeyDown, GamePadEmulateCtrl = IsControlKeyDown,
    GamePadEmulateAlt = IsAltKeyDown }
local function TriggerDown(key)
    if IsKeyDown and IsKeyDown(key) then return true end
    for _, cvar in ipairs(EMULATED[key]) do
        local down = MODIFIER_DOWN[cvar]
        if GetCVar(cvar) == key and down and down() then return true end
    end
    return false
end

-- Words too long for ours: L2 / R2 held scroll them up / down (watched,
-- never taken: the game's window keeps its buttons); the right stick is
-- the camera's (Camera)
local SCROLL_SPEED = 180        -- (px a second)
local scrolledAt
local function FollowScroll()
    local now = GetTime()
    local dt = math.min(0.1, now - (scrolledAt or now))
    scrolledAt = now
    local range = scroll:GetVerticalScrollRange()
    more:SetText(range > 1 and IF.Input.Pad()
        and (IF.GlyphText("PADLTRIGGER", 16) .. "\n" .. IF.GlyphText("PADRTRIGGER", 16)) or "")
    if range <= 1 or not IF.Input.Pad() or not NativeFocused() then return end
    local dir = (TriggerDown("PADRTRIGGER") and 1 or 0) - (TriggerDown("PADLTRIGGER") and 1 or 0)
    if dir ~= 0 then
        scroll:SetVerticalScroll(math.max(0, math.min(range, scroll:GetVerticalScroll() + dir * SCROLL_SPEED * dt)))
    end
end

-- The right stick turning the camera, as it does with no window open. The
-- game's window takes the stick to scroll its text (SmartNavigation's
-- right stick binding, left as it is), so the camera stops; ours reads the
-- stick and turns the camera itself (MoveView*Start / Stop), at the game's
-- pad camera speeds (GamePadCameraYawSpeed / PitchSpeed, gamepadInvert*).
-- (Ours scrolls with L2 / R2: FollowScroll.)
local STICK_DEAD = 0.15
local turning = { yaw = 0, pitch = 0 }

local function Turn(axis, speed, less, more)
    if math.abs(speed - turning[axis]) < 0.02 then return end
    if speed == 0 or (speed > 0) ~= (turning[axis] > 0) then
        if turning[axis] > 0 then more.stop() elseif turning[axis] < 0 then less.stop() end
    end
    if speed > 0 then more.start(speed) elseif speed < 0 then less.start(-speed) end
    turning[axis] = speed
end

local LEFT = { start = function(v) MoveViewLeftStart(v) end, stop = function() MoveViewLeftStop() end }
local RIGHT = { start = function(v) MoveViewRightStart(v) end, stop = function() MoveViewRightStop() end }
local DOWN = { start = function(v) MoveViewDownStart(v) end, stop = function() MoveViewDownStop() end }
local UP = { start = function(v) MoveViewUpStart(v) end, stop = function() MoveViewUpStop() end }

local function Axis(v)
    local a = math.abs(v)
    if a < STICK_DEAD then return 0 end
    a = (a - STICK_DEAD) / (1 - STICK_DEAD)
    return (v < 0 and -1 or 1) * a * a
end

local function Camera(on)
    local x, y = 0, 0
    if on and C_GamePad and C_GamePad.GetDeviceMappedState and IF.Input.Pad() then
        local ok, state = pcall(C_GamePad.GetDeviceMappedState, C_GamePad.GetActiveDeviceID())
        local stick = ok and type(state) == "table" and state.sticks and state.sticks[2]
        if stick and type(stick.x) == "number" and type(stick.y) == "number" then
            local yawSpeed = tonumber(GetCVar("GamePadCameraYawSpeed")) or 1
            local pitchSpeed = tonumber(GetCVar("GamePadCameraPitchSpeed")) or 1
            x = Axis(stick.x) * yawSpeed * (GetCVar("gamepadInvertYaw") == "1" and -1 or 1)
            y = Axis(stick.y) * pitchSpeed * (GetCVar("gamepadInvertPitch") == "1" and -1 or 1)
        end
    end
    Turn("yaw", x, LEFT, RIGHT)
    Turn("pitch", y, DOWN, UP)
end

---------------------------------------------------------------------------
-- On / off: ours shown while one of the game's is, the game's faded
---------------------------------------------------------------------------
local dirty = true
local squareDown = false

function ND.ShowAll(by)
    if showAll then return end
    LogLine("showAll by " .. tostring(by or "button"))
    showAll = true
    ND.StopLine()
    dirty = true
end
local signature
local faded

local function Fade(native, on)
    if faded and faded ~= native then
        IF.Focus.Fade(faded, false)
        UF.Cover(faded, false)
        faded = nil
    end
    if native then
        if on and faded ~= native then IF.Focus.Fade(native, true) end
        if not on and faded == native then IF.Focus.Fade(native, false) end
        faded = on and native or nil
        UF.Cover(native, on)
    end
end

local function Off()
    if current then ND.StopLine() end
    if current then Fade(current.native, false) end
    Fade(nil)
    current, signature = nil, nil
    Point(nil)
    HidePointer(false)
    FadeSubtitle(false)
    Camera(false)
    panel:Hide()
end

local function Tick()
    if not (IF.db and IN.Settings().npcDialog) then return Off() end
    local gossip, quest = _G.GossipFrame, _G.QuestFrame
    local open = (gossip and gossip:IsShown()) or (quest and quest:IsShown())
    if not open then return Off() end
    -- (a new page: read again; the game's window lays it out first)
    local panelName = gossip and gossip:IsShown() and "gossip"
        or (_G.QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() and "detail")
        or (_G.QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() and "progress")
        or (_G.QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() and "reward")
        or "greeting"
    -- (another page: the last one's line stopped, before this one's is read)
    if signature and panelName ~= signature then ND.StopLine() end
    -- (a line of Spoken's come or gone: laid out again, with its progress
    -- or without)
    local nowLine = Line() ~= nil
    if nowLine ~= hadLine then
        hadLine = nowLine
        dirty = true
    end
    -- (no line for the new words: they show whole; at once when Spoken said
    -- so, faded in after waiting)
    if waitUntil and NoVoice() then
        waitUntil = nil
        dirty = true
    elseif waitUntil and GetTime() >= waitUntil and not Queued() then
        waitUntil = nil
        wordsInFrom = GetTime()
        dirty = true
    end
    if wordsInFrom then
        local t = math.min(1, (GetTime() - wordsInFrom) / WORDS_IN)
        scroll:SetAlpha(1 - (1 - t) * (1 - t))
        if t >= 1 then wordsInFrom = nil end
    end
    -- (Square: stop it, show all. Watched, never taken: the game's window
    -- keeps its buttons)
    local square = IsKeyDown and IsKeyDown("PAD3") or false
    if square and not squareDown and current and NativeFocused() then ND.ShowAll("square") end
    squareDown = square
    if dirty or panelName ~= signature then
        if panelName ~= signature then choice, showAll = 0, false end
        dirty = false
        signature = panelName
        local d = Read()
        if not d then return Off() end
        Build(d)
    end
    -- (the words following the voice)
    if words.active and FollowWords() then dirty = true end
    Fade(current.native, true)
    FadeSubtitle(true)
    panel:Show()
    ND.Refresh()
    FollowScroll()
    Camera(true)
    -- (the game's cursor: our row for it lit, else the first row (or the
    -- answer A gives); no arrow of ours)
    if NativeFocused() and IF.Input.Pad() then
        local nav = _G.SmartNavigation
        local ok, button = pcall(function() return nav and nav:GetCurrentButton() end)
        local target = byKey[KeyOf(ok and button or nil) or ""]
        Point((target and target:IsShown() and target) or primary)
        HidePointer(true)
    else
        Point(nil)
        HidePointer(false)
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    local ok, err = pcall(Tick)
    if not ok then
        ticker:SetScript("OnUpdate", nil)
        Off()
        IF.Print("Interface: NPC dialog stopped after an error: " .. tostring(err))
    end
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    -- (the quest log changing: only a list of quests to read again)
    if event == "QUEST_LOG_UPDATE" and not (current and (current.kind == "gossip" or current.kind == "greeting")) then
        return
    end
    if event ~= "QUEST_LOG_UPDATE" and event ~= "QUEST_ITEM_UPDATE" then eventAt = GetTime() end
    dirty = true
end)

IF.Input.OnChange(function() dirty = true end)

function ND.Apply()
    dirty = true
end
