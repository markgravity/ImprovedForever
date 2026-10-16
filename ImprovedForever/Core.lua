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

-- The Controller module is the core's since 0.8.0 (its tab: Bindings): an
-- old copy still installed is turned off for the next login, said once;
-- loaded meanwhile, its module and tab are left out (Menu.lua, Binds.lua)
local OLD_CONTROLLER = "ImprovedForever_Controller"
IF.OLD_CONTROLLER = OLD_CONTROLLER
local addons = _G.C_AddOns
if addons and addons.DoesAddOnExist and addons.DoesAddOnExist(OLD_CONTROLLER) and addons.DisableAddOn then
    pcall(addons.DisableAddOn, OLD_CONTROLLER)
    IF.oldController = true
end

-- Gather became Minimap in 0.7.0: an old Gather still installed beside it is
-- turned off for the next login, said once; loaded meanwhile, its module,
-- tab and binding are left out (Menu.lua, Binds.lua). (Without Minimap
-- installed, it's left alone, its settings too.)
local OLD_GATHER = "ImprovedForever_Gather"
if addons and addons.DoesAddOnExist and addons.DoesAddOnExist(OLD_GATHER)
    and addons.DoesAddOnExist("ImprovedForever_Minimap") and addons.DisableAddOn then
    pcall(addons.DisableAddOn, OLD_GATHER)
    IF.oldGather = true
end

function IF.AddModule(def)
    if def.addon == OLD_CONTROLLER or (IF.oldGather and def.addon == OLD_GATHER) then return def end
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
    -- The Library module became the Wiki, and Gather the Minimap (when it's
    -- installed): their settings and key bindings, and the places a binding
    -- is kept (wheels, combos), move over
    local db = IF.db
    local renames = { library = "wiki" }
    local A = _G.C_AddOns
    if A and A.DoesAddOnExist and A.DoesAddOnExist("ImprovedForever_Minimap") then
        renames.gather = "minimap"
        -- (an old Gather loaded with it writes its own again: dropped next time)
        if db.gather ~= nil then
            if db.minimap == nil then db.minimap = db.gather end
            db.gather = nil
        end
        if db.gatherKey ~= nil then
            if db.minimapKey == nil then db.minimapKey = db.gatherKey end
            db.gatherKey = nil
        end
    end
    if db.library ~= nil and db.wiki == nil then db.wiki, db.library = db.library, nil end
    local function Rename(t, seen)
        if type(t) ~= "table" or seen[t] then return end
        seen[t] = true
        for old, new in pairs(renames) do
            if t[old] ~= nil and t[new] == nil then t[new], t[old] = t[old], nil end
        end
        for k, v in pairs(t) do
            if type(v) == "string" and renames[v] then t[k] = renames[v] else Rename(v, seen) end
        end
    end
    Rename(db.keyBinds, {}); Rename(db.combos, {}); Rename(db.wheelKeys, {})
    Rename(IF.charDB.wheels, {}); Rename(IF.charDB.recent, {})
    for _, fn in ipairs(loginCallbacks) do
        fn()
    end
    if IF.oldController then
        IF.Print("Improved Forever: Controller is now part of the core (its tab: Bindings) and has been"
            .. " turned off; remove it from your AddOns folder or CurseForge.")
    end
    if IF.oldGather then
        IF.Print("Improved Forever: Gather is now Improved Forever: Minimap and has been turned off;"
            .. " remove it from your AddOns folder or CurseForge.")
    end
end)
