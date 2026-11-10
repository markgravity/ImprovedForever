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

local WIDTH_ORDER = { "off", "16:9", "21:9" }
local WIDTH_NAMES = { off = "Full screen", ["16:9"] = "16:9", ["21:9"] = "21:9" }

local FOCUS_ORDER = { "auto", "tank", "healer", "off" }
local FOCUS_NAMES = { auto = "Automatic", tank = "Tank", healer = "Healer", off = "Off" }

-- One switch for the bottom HUD's pieces: they only make sense together
-- (the player frame carries the experience ring, the lines and the chat
-- sit with it), so one setting writes them all
local BOTTOM = { "player", "minion", "hpLine", "mpLine", "xp", "pad", "chatAbove", "chatDim" }

local function ApplyBottom()
    IN.UnitFrames.Apply()
    IN.PartyCards.Apply()
    IN.PlayerHealth.Apply()
    IN.XPBar.Apply()
    IN.GamepadBar.Apply()
    IN.HudLayout.Apply()
    IN.ChatFade.Apply()
end

local function BottomHud(on)
    local s = IN.Settings()
    for _, key in ipairs(BOTTOM) do s[key] = on end
    ApplyBottom()
end

-- A slider on a setting that places the HUD: each change places it again
local function Place(key, label, tip, min, max, step, format)
    return {
        key = key, group = key:find("^player") and "bottom" or "top", section = key:find("^player") and "Player frame"
            or "Header position", label = label, tip = tip,
        slider = {
            min = min, max = max, step = step,
            get = function() return IN.Settings()[key] end,
            set = function(n)
                IN.Settings()[key] = n
                IN.UnitFrames.Place()
            end,
            format = format or function(n) return tostring(n) end,
        },
    }
end
local function Percent(n) return n .. "%" end

local ITEMS = {
    Item({
        key = "target", group = "top", section = "Target", label = "Target header",
        tip = "The target under the top of the screen: its health as a line, a portrait diamond with level "
            .. "and elite or rare marks, its name, quests and casts. Click for targeting, right click for "
            .. "its menu.",
    }, Toggle("target", "Target header", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "targetAuras", group = "top", section = "Target", label = "Target buffs and debuffs",
        tip = "Your debuffs on the target and its buffs as small icons under the target header, with their time "
            .. "left and stacks, filled by the game's own aura list (so they show in a fight too).",
    }, Toggle("targetAuras", "Target buffs and debuffs", function() IN.TargetAuras.Apply() end)),
    Item({
        key = "castRange", group = "top", section = "Target", label = "Target range",
        tip = "Out of reach of your longest-range harmful spell, the target's portrait turns grey and its "
            .. "health line faint.",
    }, Toggle("castRange", "Target range", function() end)),
    Place("headerX", "Header: right", "Moves the header (the target, quest arrow, zone names, banners) to the "
        .. "right (left with a minus), in pixels.", -900, 900, 10),
    Place("headerY", "Header: up", "Moves the header up (down with a minus), in pixels.", -700, 100, 10),
    Item({
        key = "nameplates", group = "top", section = "Nameplates", label = "Nameplates",
        tip = "The nameplates over mobs in our look: the name in gold, a thin health line in the nameplate's "
            .. "colour and the level in a small circle. Your target's is full size, the others softer. Off, "
            .. "the game's own.",
    }, Toggle("nameplates", "Nameplates", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateClassColors", group = "top", section = "Nameplates", label = "Class colours on player nameplates",
        tip = "Other players' name and health line in their class colour. Off, the name is gold like an NPC's "
            .. "and the line in the game's friend or foe colour. Needs the nameplates on.",
    }, Toggle("nameplateClassColors", "Class colours on player nameplates", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateHideBar", group = "top", section = "Nameplates", label = "Hide friendly NPC health bar",
        tip = "Hides the thin health line and the level circle on the nameplates of friendly NPCs (vendors, "
            .. "trainers, guards): the name alone, in the line's place. Mobs you can attack keep theirs. "
            .. "Needs the nameplates on.",
    }, Toggle("nameplateHideBar", "Hide friendly NPC health bar", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateHideBarPlayers", group = "top", section = "Nameplates", label = "Hide player nameplate health bar",
        tip = "The same for other players' nameplates: the name alone, without the health line and the "
            .. "level circle. Needs the nameplates on.",
    }, Toggle("nameplateHideBarPlayers", "Hide player nameplate health bar", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateFriendlyNPCs", group = "top", section = "Nameplates", label = "Friendly NPC nameplates",
        tip = "Plates over friendly NPCs (vendors, quest givers, guards) in the same look, instead of the "
            .. "game's plain green name. Turns the game's friendly NPC nameplates on; off puts your own "
            .. "choice back. Needs the nameplates on.",
    }, Toggle("nameplateFriendlyNPCs", "Friendly NPC nameplates", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateHideFarNames", group = "top", section = "Nameplates", label = "Hide the game's far names",
        tip = "Over units too far away for a nameplate the game draws their names itself, tiny, in its own "
            .. "colours. This hides them, so only our nameplates are left. Turns the game's unit name options "
            .. "off; off puts yours back. Needs the nameplates on.",
    }, Toggle("nameplateHideFarNames", "Hide the game's far names", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateDebuffs", group = "top", section = "Nameplates", label = "Nameplate debuffs",
        tip = "Your debuffs on a mob as small icons under its nameplate, with their time left and stacks. "
            .. "Needs the nameplates on.",
    }, Toggle("nameplateDebuffs", "Nameplate debuffs", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateCast", group = "top", section = "Nameplates", label = "Nameplate cast bars",
        tip = "What a mob or player casts as a thin bar under its nameplate, with the spell's name and icon: "
            .. "gold for a cast, green draining for a channel, grey when it can't be interrupted, red when it "
            .. "is. Needs the nameplates on.",
    }, Toggle("nameplateCast", "Nameplate cast bars", function() IN.Nameplates.Apply() end)),
    Item({
        key = "nameplateFont", group = "top", section = "Nameplates", label = "Nameplate name font",
        tip = "The font of the names over mobs: Morpheus (the default), Friz Quadrata, Arial Narrow or Skurri. "
            .. "A Russian, Korean or Chinese client always uses the game's own font, which has their letters.",
        value = function() return IN.Settings().nameplateFont end,
        text = function()
            for _, f in ipairs(IN.Nameplates.FONTS) do
                if f.key == IN.Settings().nameplateFont then return f.name end
            end
            return IN.Nameplates.FONTS[1].name
        end,
        options = function()
            local list = {}
            for _, f in ipairs(IN.Nameplates.FONTS) do list[#list + 1] = { action = f.key, name = f.name } end
            return list
        end,
        choose = function(action)
            IN.Settings().nameplateFont = action
            IN.Nameplates.Apply()
        end,
    }),
    {
        key = "nameplateNameSize", group = "top", section = "Nameplates", label = "Nameplate name size",
        tip = "How big the names over mobs are.",
        slider = {
            min = 8, max = 24, step = 1,
            get = function() return IN.Settings().nameplateNameSize end,
            set = function(n)
                IN.Settings().nameplateNameSize = n
                IN.Nameplates.Apply()
            end,
            format = function(n) return tostring(n) end,
        },
    },
    Item({
        key = "questArrow", group = "top", section = "Quests", label = "Quest arrow",
        tip = "The way to your focused quest near the top: its name, the yards left, and a diamond arrow "
            .. "that turns green as you head its way. Gives its place to the target, zone names and notices.",
    }, Toggle("questArrow", "Quest arrow", function() IN.QuestArrow.Apply() end)),
    Item({
        key = "questProgress", group = "top", section = "Quests", label = "Quest progress",
        tip = "Quest progress (\"Crystal Fragment: 6/12\") as a header for a few seconds. /if progresstest "
            .. "shows it.",
    }, Toggle("questProgress", "Quest progress", function() IN.QuestProgress.Apply() end)),
    Item({
        key = "levelBanner", group = "top", section = "Banners", label = "Level ups",
        tip = "Your level ups as a header: the new level, what it gave and what's new. /if leveltest shows "
            .. "it.",
    }, Toggle("levelBanner", "Level ups", function() IN.LevelBanner.Apply() end)),
    Item({
        key = "zoneBanner", group = "top", section = "Banners", label = "Zone names",
        tip = "The zone's name as you enter it, with its picture and subzone. /if zonetest shows it.",
    }, Toggle("zoneBanner", "Zone names", function() IN.ZoneBanner.Apply() end)),
    Item({
        key = "bottomHud", group = "bottom", section = "Player frame", label = "Player frame",
        tip = "Your player frame with its experience ring, your pet's card, health and power lines along "
            .. "the bottom edge, the action bar, and the chat as just its lines until used. Off, the "
            .. "game's own show.",
    }, OnOff(function()
        local s = IN.Settings()
        for _, key in ipairs(BOTTOM) do if s[key] then return true end end
        return false
    end, BottomHud, "Player frame")),
    Item({
        key = "hudWidth", group = "bottom", section = "Player frame", label = "Screen width",
        tip = "On an ultrawide screen, keeps the player frame, chat, buffs and action bar inside a 16:9 or 21:9 "
            .. "part in the middle, so they are not at the far edges. Full screen: to the screen's edges.",
        value = function() return IN.Settings().hudWidth end,
        text = function() return WIDTH_NAMES[IN.Settings().hudWidth] or "" end,
        options = function()
            local list = {}
            for _, key in ipairs(WIDTH_ORDER) do list[#list + 1] = { action = key, name = WIDTH_NAMES[key] } end
            return list
        end,
        choose = function(action)
            local s = IN.Settings()
            s.hudWidth = action
            -- (the game's pieces placed again for the new edges)
            s.hudPlaced = nil
            ApplyBottom()
        end,
    }),
    Place("playerX", "Player frame: right", "Moves the player frame (with its pet and party cards) to the right "
        .. "(left with a minus), in pixels. Out of combat only.", -200, 1400, 10),
    Place("playerY", "Player frame: up", "Moves the player frame up (down with a minus), in pixels.", -50, 700, 10),
    Place("playerScale", "Player frame: size", "How big the player frame is, in percent. The pet and party "
        .. "cards stay the same size and follow it.", 50, 150, 5, Percent),
    -- (each piece on its own, for those who want the action bar without the rest)
    Item({
        key = "player", group = "bottom", section = "Player frame", label = "Player card and ring",
        tip = "Your player card with its experience ring bottom left, and your pet's card. Off, the game's own "
            .. "show. The lines and the action bar are their own switches.",
    }, OnOff(function() return IN.Settings().player end, function(on)
        local s = IN.Settings()
        s.player, s.minion, s.xp = on, on, on
        ApplyBottom()
    end, "Player card and ring")),
    Item({
        key = "hpLine", group = "bottom", section = "Player frame", label = "Health line",
        tip = "Your health as a line along the bottom edge of the screen. Off, no line (the player card still "
            .. "shows it).",
    }, Toggle("hpLine", "Health line", ApplyBottom)),
    Item({
        key = "mpLine", group = "bottom", section = "Player frame", label = "Power line",
        tip = "Your mana, rage or energy as a line along the bottom edge of the screen (the green bar on a "
            .. "wide screen). Off, no line.",
    }, Toggle("mpLine", "Power line", ApplyBottom)),
    Item({
        key = "breath", group = "bottom", section = "Player frame", label = "Breath",
        tip = "Under water, your player frame fills with blue and drains as your breath runs out, in place "
            .. "of the game's breath bar. Other timers (fatigue) stay the game's.",
    }, Toggle("breath", "Breath", function() IN.Breath.Apply() end)),
    Item({
        key = "recentLoot", group = "bottom", section = "Player frame", label = "Recent loot",
        tip = "Your last four loots that matter as small tiles beside the bags: upgrades "
            .. "(green arrow), quest starters (gold !), recipes for your professions, finds worth more at "
            .. "the auction house, rares, mounts, pets and toys to learn, and bags that open. The rest "
            .. "flies to the bags' tile. Mouse over one for its tooltip.",
    }, Toggle("recentLoot", "Recent loot", function() IN.RecentLoot.Apply() end)),
    Item({
        key = "pad", group = "bottom", section = "Action bar", label = "Action bar",
        tip = "The gamepad bar as spell tiles bottom right. Off, the game's own gamepad bar shows.",
    }, Toggle("pad", "Action bar", ApplyBottom)),
    Item({
        key = "padStyle", group = "bottom", section = "Action bar", label = "Action bar style",
        tip = "The shape of the action bar's tiles (and the party spells' and cast bar's): Diamonds, Squares or "
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
        key = "gcd", group = "bottom", section = "Action bar", label = "Global cooldown",
        tip = "A swipe over the action bar's tiles while the global cooldown runs (after any spell), so you "
            .. "see when the next one can go. Off by default; the tiles show real cooldowns only.",
    }, Toggle("gcd", "Global cooldown", function() IN.GamepadBar.Apply() end)),
    Item({
        key = "hudAuras", group = "bottom", section = "Buffs & cooldowns", label = "Buffs along the bottom (experiment)",
        tip = "An experiment. The game's buffs and debuffs moved to the bottom, between the minion and "
            .. "party cards, written into your Edit Mode layout once.",
    }, Toggle("hudAuras", "Buffs along the bottom (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "buffTimeline", group = "bottom", section = "Buffs & cooldowns", label = "Buff row",
        tip = "Your buffs and debuffs as a row along the bottom: round icons with the time left, soonest "
            .. "gone nearest the middle. Replaces the game's buffs (Edit Mode shows them).",
    }, Toggle("buffTimeline", "Buff row", function() IN.BuffTimeline.Apply() end)),
    Item({
        key = "cooldownTimeline", group = "bottom", section = "Buffs & cooldowns", label = "Cooldown row",
        tip = "The cooldowns of your gamepad bar and on-use trinkets as a row along the bottom: red to "
            .. "green as they run down, flashing when ready. Replaces the game's Cooldown Manager.",
    }, Toggle("cooldownTimeline", "Cooldown row", function() IN.BuffTimeline.Apply() end)),
    Item({
        key = "hudCooldowns", group = "bottom", section = "Buffs & cooldowns", label = "Cooldowns beside the action bar (experiment)",
        tip = "An experiment. The game's Cooldown Manager moved left of the action bar, written into "
            .. "your Edit Mode layout once.",
    }, Toggle("hudCooldowns", "Cooldowns beside the action bar (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "cards", group = "bottom", section = "Party", label = "Party cards",
        tip = "Your party as cards along the bottom: model, class colour, level, name, health and power. "
            .. "Click to target, right click for the menu. Hidden in a raid.",
    }, Toggle("cards", "Party cards", function() IN.PartyCards.Apply() end)),
    Item({
        key = "cardFocus", group = "bottom", section = "Party", label = "Party cards focus",
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
        key = "partyPad", group = "bottom", section = "Party", label = "Party casting (L1, experiment)",
        tip = "An experiment. L1 held: the D-pad picks a party spell, a face button casts it on party "
            .. "member 1 to 4. Out of combat only; off or alone, L1 is the game's.",
    }, Toggle("partyPad", "Party casting (L1, experiment)", function() IN.PartyCards.Apply() end)),
    Item({
        key = "castBar", group = "body", section = "Cast bar", label = "Cast bar",
        tip = "Your casts as a long thin line over the party cards, filling out from the middle. Yellow "
            .. "cast, green channel, grey when it can't be interrupted, red when cut. Edit Mode shows the "
            .. "game's bar.",
    }, Toggle("castBar", "Cast bar", function() IN.PlayerCast.Apply() end)),
    {
        key = "castX", group = "body", section = "Cast bar", label = "Cast bar: right",
        tip = "Moves your cast bar to the right (left with a minus), in pixels.",
        slider = {
            min = -900, max = 900, step = 10,
            get = function() return IN.Settings().castX end,
            set = function(n)
                IN.Settings().castX = n
                IN.PlayerCast.Place()
            end,
            format = function(n) return tostring(n) end,
        },
    },
    {
        key = "castY", group = "body", section = "Cast bar", label = "Cast bar: up",
        tip = "Moves your cast bar up (down with a minus), in pixels.",
        slider = {
            min = -200, max = 700, step = 10,
            get = function() return IN.Settings().castY end,
            set = function(n)
                IN.Settings().castY = n
                IN.PlayerCast.Place()
            end,
            format = function(n) return tostring(n) end,
        },
    },
    Item({
        key = "npcDialog", group = "body", section = "NPC dialog", label = "NPC dialog as subtitles",
        tip = "NPC talk (greetings, quests, gossip) as subtitles low in the middle, in place of the game's "
            .. "window. Pad and mouse both work. With Spoken installed, its voice reads the words. With "
            .. "DialogueUI installed, it keeps the talking and this stays off.",
    }, Toggle("npcDialog", "NPC dialog as subtitles", function() IN.NpcDialog.Apply() end)),
    {
        key = "dialogX", group = "body", section = "NPC dialog", label = "NPC dialog: right",
        tip = "Moves the NPC subtitle to the right (left with a minus), in pixels.",
        slider = {
            min = -900, max = 900, step = 10,
            get = function() return IN.Settings().dialogX end,
            set = function(n)
                IN.Settings().dialogX = n
                IN.NpcDialog.Apply()
            end,
            format = function(n) return tostring(n) end,
        },
    },
    {
        key = "dialogY", group = "body", section = "NPC dialog", label = "NPC dialog: up",
        tip = "Moves the NPC subtitle up (down with a minus), in pixels, if the player frame or the lines "
            .. "cover its words.",
        slider = {
            min = -150, max = 600, step = 10,
            get = function() return IN.Settings().dialogY end,
            set = function(n)
                IN.Settings().dialogY = n
                IN.NpcDialog.Apply()
            end,
            format = function(n) return tostring(n) end,
        },
    },
}

local GROUPS = {
    { key = "top", label = "Header" },
    { key = "body", label = "Body" },
    { key = "bottom", label = "Footer" },
}

IF.InterfaceEditor = IF.SettingsPage({ key = "interface", label = "Immersion", module = "interface", order = 35 },
    GROUPS, ITEMS)
