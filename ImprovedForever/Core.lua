-- Improved Forever's core: the namespace every module shares. The core
-- addon (this folder) holds what more than one feature needs: the pad's
-- glyphs, ConfigKit, the bindings (Binds.lua), the window (Window.lua) and
-- the configuration panel (Menu.lua). Each feature is its own addon
-- (ImprovedForever_Wheel, ImprovedForever_Auction...), loaded after this
-- one, reaching it through the global ImprovedForever:
--   local IF = ImprovedForever
-- A module says it is there with IF.AddModule; one asks after another with
-- IF.Has("Auction") (or by the table it leaves, IF.Auction) before using it.
local addonName, IF = ...

ImprovedForever = IF
IF.name = addonName
IF.TITLE = "Improved Forever"
IF.TEX = "Interface\\AddOns\\ImprovedForever\\textures\\"

-- The R3 combos: what the wheels open on (ImprovedForever_Wheel), and the
-- bindings' shape for "a shoulder / trigger held + R3" (Binds.lua)
IF.COMBOS = { "R3", "L1", "L2", "R1", "R2" }
IF.COMBO_LABELS = { R3 = "R3", L1 = "L1 + R3", L2 = "L2 + R3", R1 = "R1 + R3", R2 = "R2 + R3" }

function IF.Print(msg)
    print("|cff33ccffImprovedForever|r: " .. tostring(msg))
end

function IF.InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

-- Called after anything that changes what the rings hold (the Wheel
-- module answers it)
function IF.RefreshRings()
    if IF.QueueRingRebuild then
        IF.QueueRingRebuild()
    end
end

---------------------------------------------------------------------------
-- Modules: { key, label, icon, addon } in the order they loaded
---------------------------------------------------------------------------
IF.modules = {}
local byKey = {}

function IF.AddModule(def)
    if byKey[def.key] then return byKey[def.key] end
    IF.modules[#IF.modules + 1] = def
    byKey[def.key] = def
    return def
end

function IF.Has(key)
    return byKey[key] ~= nil
end

function IF.Module(key)
    return byKey[key]
end

---------------------------------------------------------------------------
-- Slash commands: /if <command> ...; a module adds its own
---------------------------------------------------------------------------
local commands, commandOrder = {}, {}

-- fn(args, msg): args the words after the command (lower case), msg the
-- whole line as typed (its links intact)
function IF.AddCommand(name, fn, help)
    if not commands[name] then commandOrder[#commandOrder + 1] = name end
    commands[name] = { fn = fn, help = help }
end

function IF.RunCommand(msg)
    local words = { strsplit(" ", strtrim(msg or ""):lower()) }
    local name = table.remove(words, 1)
    local command = commands[name or ""]
    if command then return command.fn(words, msg) end
    if name == "help" then
        for _, key in ipairs(commandOrder) do
            local help = commands[key].help
            if help then IF.Print("/if " .. key .. ((help == "" or help:sub(1, 1) == ":") and "" or " ") .. help) end
        end
        return
    end
    if IF.Menu then IF.Menu.Toggle() end
end

SLASH_IMPROVEDFOREVER1 = "/if"
SLASH_IMPROVEDFOREVER2 = "/improvedforever"
SLASH_IMPROVEDFOREVER3 = "/improvedcontroller" -- its name before 0.3.0
SlashCmdList.IMPROVEDFOREVER = IF.RunCommand

-- A protected call of ours the game blocked: which one, said in chat (the
-- game's own dialog doesn't). Any of our addons.
local blocked = CreateFrame("Frame")
blocked:RegisterEvent("ADDON_ACTION_BLOCKED")
blocked:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blocked:SetScript("OnEvent", function(_, event, addon, func)
    if type(addon) == "string" and addon:find("^ImprovedForever") then
        IF.Print((event == "ADDON_ACTION_FORBIDDEN" and "forbidden: " or "blocked: ") .. tostring(func)
            .. (addon ~= addonName and (" (" .. addon .. ")") or ""))
    end
end)

---------------------------------------------------------------------------
-- Saved variables: ImprovedForeverDB (account), ImprovedForeverCharDB (per
-- character); a module keeps its settings in a table of its own in them
---------------------------------------------------------------------------
local loginCallbacks = {}

-- Runs after saved variables are ready (every module has loaded by then).
function IF.OnLogin(fn)
    table.insert(loginCallbacks, fn)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    ImprovedForeverDB = ImprovedForeverDB or {}
    IF.db = ImprovedForeverDB
    ImprovedForeverCharDB = ImprovedForeverCharDB or {}
    IF.charDB = ImprovedForeverCharDB
    for _, fn in ipairs(loginCallbacks) do
        fn()
    end
end)
