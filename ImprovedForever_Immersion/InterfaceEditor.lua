-- The Interface tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- each change to the game's HUD on / off. UnitFrames.lua, XPBar.lua,
-- GamepadBar.lua, ChatView.lua, ChatFade.lua, NpcDialog.lua, QuestArrow.lua,
-- ZoneBanner.lua, LevelBanner.lua, TargetHeader.lua and QuestProgress.lua do
-- the work.
local IF = ImprovedForever
local IN = IF.Interface

local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function Toggle(key, label, after)
    return OnOff(function() return IN.Settings()[key] end, function(on)
        IN.Settings()[key] = on
        after()
    end, label)
end

local STYLE_NAMES = { diamond = "Diamonds", square = "Squares", circle = "Circles" }

local FOCUS_ORDER = { "auto", "tank", "healer", "off" }
local FOCUS_NAMES = { auto = "Automatic", tank = "Tank", healer = "Healer", off = "Off" }

-- One switch for the bottom HUD's pieces: they only make sense together
-- (the player frame carries the experience ring, the lines and the chat
-- sit with it), so one setting writes them all
local BOTTOM = { "player", "minion", "hpLine", "mpLine", "xp", "pad", "chatAbove", "chatDim" }

local function BottomHud(on)
    local s = IN.Settings()
    for _, key in ipairs(BOTTOM) do s[key] = on end
    IN.UnitFrames.Apply()
    IN.PartyCards.Apply()
    IN.PlayerHealth.Apply()
    IN.XPBar.Apply()
    IN.GamepadBar.Apply()
    IN.HudLayout.Apply()
    IN.ChatFade.Apply()
end

local ITEMS = {
    Item({
        key = "bottomHud", group = "bottom", label = "Player HUD",
        tip = "Your player frame with its experience ring, your pet's card, health and power lines along "
            .. "the bottom edge, the spell diamonds, and the chat as just its lines until used. Off, the "
            .. "game's own show.",
    }, OnOff(function()
        local s = IN.Settings()
        for _, key in ipairs(BOTTOM) do if s[key] then return true end end
        return false
    end, BottomHud, "Player HUD")),
    Item({
        key = "target", group = "top", label = "Target header",
        tip = "The target under the top of the screen: its health as a line, a portrait diamond with level "
            .. "and elite or rare marks, its name, quests and casts. Click for targeting, right click for "
            .. "its menu.",
    }, Toggle("target", "Target header", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "cards", group = "party", label = "Party cards",
        tip = "Your party as cards along the bottom: model, class colour, level, name, health and power. "
            .. "Click to target, right click for the menu. Hidden in a raid.",
    }, Toggle("cards", "Party cards", function() IN.PartyCards.Apply() end)),
    Item({
        key = "cardFocus", group = "party", label = "Party cards focus",
        tip = "What the party cards flag for your role. Tank: threat, green to red. Healer: who's hurt, "
            .. "flashing under 35%. Automatic uses your assigned role. /if cards tank (healer, dps) previews"
            .. " it.",
        value = function() return IN.Settings().cardFocus end,
        text = function() return FOCUS_NAMES[IN.Settings().cardFocus] or "" end,
        options = function()
            local list = {}
            for _, key in ipairs(FOCUS_ORDER) do list[#list + 1] = { action = key, name = FOCUS_NAMES[key] } end
            return list
        end,
        choose = function(action)
            IN.Settings().cardFocus = action
            IN.PartyCards.Apply()
        end,
    }),
    Item({
        key = "castBar", group = "cast", label = "Cast bar",
        tip = "Your casts as a long thin line over the party cards, filling out from the middle. Yellow "
            .. "cast, green channel, grey when it can't be interrupted, red when cut. Edit Mode shows the "
            .. "game's bar.",
    }, Toggle("castBar", "Cast bar", function() IN.PlayerCast.Apply() end)),
    Item({
        key = "breath", group = "bottom", label = "Breath",
        tip = "Under water, your player frame fills with blue and drains as your breath runs out, in place "
            .. "of the game's breath bar. Other timers (fatigue) stay the game's.",
    }, Toggle("breath", "Breath", function() IN.Breath.Apply() end)),
    Item({
        key = "castRange", group = "top", label = "Target range",
        tip = "Out of reach of your longest-range harmful spell, the target's portrait turns grey and its "
            .. "health line faint.",
    }, Toggle("castRange", "Target range", function() end)),
    Item({
        key = "questArrow", group = "top", label = "Quest arrow",
        tip = "The way to your focused quest near the top: its name, the yards left, and a diamond arrow "
            .. "that turns green as you head its way. Gives its place to the target, zone names and notices.",
    }, Toggle("questArrow", "Quest arrow", function() IN.QuestArrow.Apply() end)),
    Item({
        key = "levelBanner", group = "top", label = "Level ups",
        tip = "Your level ups as a header: the new level, what it gave and what's new. /if leveltest shows "
            .. "it.",
    }, Toggle("levelBanner", "Level ups", function() IN.LevelBanner.Apply() end)),
    Item({
        key = "questProgress", group = "top", label = "Quest progress",
        tip = "Quest progress (\"Crystal Fragment: 6/12\") as a header for a few seconds. /if progresstest "
            .. "shows it.",
    }, Toggle("questProgress", "Quest progress", function() IN.QuestProgress.Apply() end)),
    Item({
        key = "zoneBanner", group = "top", label = "Zone names",
        tip = "The zone's name as you enter it, with its picture and subzone. /if zonetest shows it.",
    }, Toggle("zoneBanner", "Zone names", function() IN.ZoneBanner.Apply() end)),
    Item({
        key = "recentLoot", group = "bottom", label = "Recent loot (experiment)",
        tip = "An experiment. Your last four loots that matter as small tiles beside the bags: upgrades "
            .. "(green arrow), quest starters (gold !), recipes for your professions, finds worth more at "
            .. "the auction house, rares, mounts, pets and toys to learn, and bags that open. The rest "
            .. "flies to the bags' tile. Mouse over one for its tooltip.",
    }, Toggle("recentLoot", "Recent loot (experiment)", function() IN.RecentLoot.Apply() end)),
    Item({
        key = "padStyle", group = "bottom", label = "Tile style",
        tip = "The shape of the spell tiles (and the party spells' and cast bar's): Diamonds, Squares or "
            .. "Circles.",
        value = function() return IN.Settings().padStyle end,
        text = function() return STYLE_NAMES[IN.Settings().padStyle] or "" end,
        options = function()
            local list = {}
            for _, key in ipairs(IN.GamepadBar.STYLE_ORDER) do list[#list + 1] = { action = key, name = STYLE_NAMES[key] } end
            return list
        end,
        choose = function(action)
            IN.Settings().padStyle = action
            IN.GamepadBar.Apply()
        end,
    }),
    Item({
        key = "partyPad", group = "party", label = "Party casting (L1, experiment)",
        tip = "An experiment. L1 held: the D-pad picks a party spell, a face button casts it on party "
            .. "member 1 to 4. Out of combat only; off or alone, L1 is the game's.",
    }, Toggle("partyPad", "Party casting (L1, experiment)", function() IN.PartyCards.Apply() end)),
    Item({
        key = "hudAuras", group = "auras", label = "Buffs along the bottom (experiment)",
        tip = "An experiment. The game's buffs and debuffs moved to the bottom, between the minion and "
            .. "party cards, written into your Edit Mode layout once.",
    }, Toggle("hudAuras", "Buffs along the bottom (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "buffTimeline", group = "auras", label = "Buff row",
        tip = "Your buffs and debuffs as a row along the bottom: round icons with the time left, soonest "
            .. "gone nearest the middle. Replaces the game's buffs (Edit Mode shows them).",
    }, Toggle("buffTimeline", "Buff row", function() IN.BuffTimeline.Apply() end)),
    Item({
        key = "cooldownTimeline", group = "auras", label = "Cooldown row",
        tip = "The cooldowns of your gamepad bar and on-use trinkets as a row along the bottom: red to "
            .. "green as they run down, flashing when ready. Replaces the game's Cooldown Manager.",
    }, Toggle("cooldownTimeline", "Cooldown row", function() IN.BuffTimeline.Apply() end)),
    Item({
        key = "hudCooldowns", group = "auras", label = "Cooldowns beside the diamonds (experiment)",
        tip = "An experiment. The game's Cooldown Manager moved left of the spell diamonds, written into "
            .. "your Edit Mode layout once.",
    }, Toggle("hudCooldowns", "Cooldowns beside the diamonds (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "npcDialog", group = "dialog", label = "NPC dialog as subtitles",
        tip = "NPC talk (greetings, quests, gossip) as subtitles low in the middle, in place of the game's "
            .. "window. Pad and mouse both work. With Spoken installed, its voice reads the words.",
    }, Toggle("npcDialog", "NPC dialog as subtitles", function() IN.NpcDialog.Apply() end)),
}

local GROUPS = {
    { key = "top", label = "Header" },
    { key = "bottom", label = "Player HUD" },
    { key = "party", label = "Party" },
    { key = "cast", label = "Cast bar" },
    { key = "auras", label = "Buffs & cooldowns" },
    { key = "dialog", label = "NPC dialog" },
}

IF.InterfaceEditor = IF.SettingsPage({ key = "interface", label = "Immersion", module = "interface", order = 35 },
    GROUPS, ITEMS)
