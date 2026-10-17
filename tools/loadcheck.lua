-- Loads addons' files as the game would (their TOC's order, dependencies
-- first) against a stand-in for the WoW API, then fires ADDON_LOADED,
-- PLAYER_LOGIN and PLAYER_ENTERING_WORLD, and runs any extra checks; every
-- error said with where it happened. Catches a module reaching for another
-- that isn't loaded, a nil at load time, a login callback that fails.
-- Not a test of what the addons do: the API answers anything with a stub.
--
-- Usage (from the repo's root):
--   luajit tools/loadcheck.lua ImprovedForever ImprovedForever_Wheel ...
--   luajit tools/loadcheck.lua all        every folder with a TOC
--   luajit tools/loadcheck.lua each       core + each module alone, then all
local ROOT = "./"

---------------------------------------------------------------------------
-- Stubs: indexable, callable, anything they're asked returns another
---------------------------------------------------------------------------
local Stub
local stubMeta = {}
stubMeta.__index = function(t, k)
    local s = Stub()
    rawset(t, k, s)
    return s
end
stubMeta.__call = function() return Stub() end
stubMeta.__concat = function(a, b)
    return (type(a) == "table" and "" or tostring(a)) .. (type(b) == "table" and "" or tostring(b))
end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
    stubMeta[op] = function() return 0 end
end
stubMeta.__len = function() return 0 end
function Stub() return setmetatable({}, stubMeta) end

-- Frames: their scripts and events kept, the rest stubs
local frames = {}
local frameMeta = {}
local Frame
-- (an unknown field: a method returning a frame, or a field to index)
local memberMeta = {}
for k, v in pairs(stubMeta) do memberMeta[k] = v end
memberMeta.__call = function() return nil end
frameMeta.__index = function(t, k)
    local m = rawget(frameMeta, k)
    if m then return m end
    -- (the stand-in's own fields: unset)
    if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
    local s = setmetatable({}, memberMeta)
    rawset(t, k, s)
    return s
end
function frameMeta.SetScript(self, name, fn) self.__scripts[name] = fn end
function frameMeta.HookScript(self, name, fn) self.__scripts[name] = self.__scripts[name] or fn end
function frameMeta.GetScript(self, name) return self.__scripts[name] end
function frameMeta.RegisterEvent(self, e) self.__events[e] = true end
function frameMeta.UnregisterEvent(self, e) self.__events[e] = nil end
function frameMeta.RegisterUnitEvent(self, e) self.__events[e] = true end
function frameMeta.IsEventRegistered(self, e) return self.__events[e] == true end
function frameMeta.Show(self) self.__shown = true end
function frameMeta.Hide(self) self.__shown = false end
function frameMeta.SetShown(self, on) self.__shown = on and true or false end
function frameMeta.IsShown(self) return self.__shown end
function frameMeta.IsVisible(self) return self.__shown end
function frameMeta.GetWidth(self) return self.__w or 100 end
function frameMeta.GetHeight(self) return self.__h or 20 end
function frameMeta.SetWidth(self, w) self.__w = w end
function frameMeta.SetHeight(self, h) self.__h = h end
function frameMeta.SetSize(self, w, h) self.__w, self.__h = w, h end
function frameMeta.GetSize(self) return self.__w or 100, self.__h or 20 end
function frameMeta.GetStringWidth() return 50 end
function frameMeta.GetStringHeight() return 14 end
function frameMeta.GetText(self) return self.__text end
function frameMeta.SetText(self, t) self.__text = t end
function frameMeta.GetName(self) return self.__name end
function frameMeta.GetParent(self) return self.__parent end
function frameMeta.GetLeft() return 0 end
function frameMeta.GetRight() return 100 end
function frameMeta.GetTop() return 100 end
function frameMeta.GetBottom() return 0 end
function frameMeta.GetCenter() return 50, 50 end
function frameMeta.GetScale() return 1 end
function frameMeta.GetEffectiveScale() return 1 end
function frameMeta.GetAlpha() return 1 end
function frameMeta.GetFrameLevel() return 1 end
function frameMeta.GetNumPoints() return 0 end
function frameMeta.GetObjectType() return "Frame" end
function frameMeta.IsObjectType() return true end
function frameMeta.IsMouseOver() return false end
function frameMeta.IsForbidden() return false end
function frameMeta.GetAttribute(self, k) return self.__attr[k] end
function frameMeta.SetAttribute(self, k, v) self.__attr[k] = v end
function frameMeta.GetValue() return 0 end
function frameMeta.GetMinMaxValues() return 0, 1 end
function frameMeta.GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function frameMeta.GetNumChildren() return 0 end
function frameMeta.GetChildren() return end
function frameMeta.GetRegions() return end
function frameMeta.CreateTexture(self) return Frame(nil, self) end
function frameMeta.CreateFontString(self) return Frame(nil, self) end
function frameMeta.CreateMaskTexture(self) return Frame(nil, self) end
function frameMeta.CreateLine(self) return Frame(nil, self) end
function frameMeta.CreateAnimationGroup(self) return Frame(nil, self) end
function frameMeta.CreateAnimation(self)
    local a = Frame(nil, self)
    self.__anim = self.__anim or a
    return a
end
function frameMeta.GetAnimations(self) return self.__anim end

frameMeta.__call = function() return nil end

function Frame(name, parent)
    local f = setmetatable({ __scripts = {}, __events = {}, __attr = {}, __name = name, __parent = parent,
        __shown = true }, frameMeta)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

---------------------------------------------------------------------------
-- The API: what the addons read at load time, given real-ish answers
---------------------------------------------------------------------------
local env = _G
setmetatable(env, { __index = function(_, k)
    -- (our own globals and saved variables: nil until set; QuestieDB isn't
    -- installed)
    if type(k) == "string" and (k:find("^ImprovedForever") or k:find("^Questie")) then return nil end
    -- (other clients' APIs Forever doesn't have)
    if k == "WatchFrame" or k == "ShiftQuestWatches" or k == "GetSuperTrackedQuestID" then return nil end
    -- (the game's global strings: ITEM_MIN_LEVEL = "Requires Level %d"...)
    if type(k) == "string" and (k:find("^NUM_") or k:find("^MAX_")) then return 4 end
    if type(k) == "string" and k:find("^[A-Z][A-Z0-9_]+$") then
        rawset(env, k, k .. " %d")
        return k .. " %d"
    end
    -- (an unknown global: a frame, also callable as a function answering
    -- nil, as the game's are frames, tables or functions)
    local s = Frame(k)
    rawset(env, k, s)
    return s
end })

UIParent = Frame("UIParent")
WorldFrame = Frame("WorldFrame")
Minimap = Frame("Minimap")
GameTooltip = Frame("GameTooltip")
ItemRefTooltip = Frame("ItemRefTooltip")
function CreateFrame(_, name, parent) return Frame(name, parent) end
function GetTime() return 1000 end
function time() return os.time() end
date = os.date
function GetServerTime() return os.time() end
function InCombatLockdown() return false end
function IsKeyDown() return false end
function GetCVar() return "1" end
function GetCVarBool() return false end
function SetCVar() end
function GetLocale() return "enUS" end
function GetRealmName() return "Realm" end
function UnitName() return "Player", "Realm" end
function UnitLevel() return 60 end
function UnitClass() return "Mage", "MAGE", 8 end
function UnitRace() return "Human", "Human" end
function UnitFactionGroup() return "Alliance" end
function UnitGUID() return "Player-1-0001" end
function UnitExists() return true end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetBuildInfo() return "1.15.0", "1", "Oct 1 2026", 11500 end
function GetAddOnMetadata() return "0.3.0" end
function IsAddOnLoaded() return false end
function GetNumMacros() return 0, 0 end
function GetMacroInfo() return nil end
function GetBindingKey() return nil end
function GetItemInfo() return nil end
function GetInventoryItemID() return nil end
function GetNumSpellTabs() return 0 end
function GetMoney() return 0 end
function PlaySound() end
function hooksecurefunc() end
function issecurevariable() return true end
function securecall(fn, ...) return fn(...) end
function SetOverrideBinding() end
function SetOverrideBindingClick() end
function ClearOverrideBindings() end
function RegisterStateDriver() end
function UnregisterStateDriver() end
function GetCoinTextureString(c) return tostring(c) end
function debugprofilestop() return 0 end
NUM_BAG_SLOTS = 4
MAX_ACCOUNT_MACROS = 120
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, hex = "|cffffffff" } end })
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })
SlashCmdList = {}
Enum = Stub()
Settings = Stub()
C_Timer = { After = function() end, NewTicker = function() return Stub() end, NewTimer = function() return Stub() end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end,
    GetContainerItemInfo = function() return nil end, GetContainerNumFreeSlots = function() return 0, 0 end }
function GetContainerNumSlots() return 0 end
C_QuestLog = { GetNumQuestWatches = function() return 0 end, GetNumQuestLogEntries = function() return 0, 0 end,
    GetQuestIDForQuestWatchIndex = function() return nil end, AddQuestWatch = function() end,
    GetLogIndexForQuestID = function() return nil end, GetDistanceSqToQuest = function() return nil end,
    GetInfo = function() return nil end, IsComplete = function() return false end }
function GetNumQuestLeaderBoards() return 0 end
function GetNumQuestWatches() return 0 end
C_Texture = { GetAtlasInfo = function() return nil end }
C_CVar = { GetCVar = function() return "1" end, GetCVarBool = function() return false end, SetCVar = function() end }
C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return "0.3.0" end }
C_GamePad = { IsEnabled = function() return true end, GetActiveDeviceID = function() return 1 end,
    GetDeviceMappedState = function() return nil end, GetDeviceRawState = function() return nil end,
    GetCombinedDeviceID = function() return 1 end, GetPowerLevel = function() return nil end,
    SetVibration = function() end, StopVibration = function() end, ButtonIndexToBinding = function() return nil end }

-- Lua helpers the game adds
function strsplit(sep, s, n)
    local out, i = {}, 1
    s = tostring(s or "")
    while true do
        local a, b = s:find(sep, i, true)
        if not a or (n and #out == n - 1) then out[#out + 1] = s:sub(i) break end
        out[#out + 1] = s:sub(i, a - 1)
        i = b + 1
    end
    return unpack(out)
end
function strtrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function strjoin(sep, ...) return table.concat({ ... }, sep) end
function strlower(s) return s:lower() end
function strupper(s) return s:upper() end
function strmatch(s, p) return s:match(p) end
function strfind(...) return string.find(...) end
function strsub(...) return string.sub(...) end
function strlen(s) return #s end
function strrep(...) return string.rep(...) end
function gsub(...) return string.gsub(...) end
format = string.format
tinsert, tremove, tconcat, sort = table.insert, table.remove, table.concat, table.sort
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
function Mixin(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
function Clamp(v, a, b) return math.min(math.max(v, a), b) end
floor, ceil, abs, max, min, sqrt = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt
mod = math.fmod
bit = bit or require("bit")

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------
local failures = 0
local function report(where, err)
    failures = failures + 1
    -- (the traceback's lines in the addons only)
    local lines = {}
    for line in tostring(err):gmatch("[^\n]+") do
        if not line:find("loadcheck.lua") and not line:find("%[C%]") and line ~= "stack traceback:" then
            lines[#lines + 1] = line
        end
    end
    print("  ERROR " .. where .. ": " .. table.concat(lines, "\n      "))
end

local function readToc(folder)
    local fh = io.open(ROOT .. folder .. "/" .. folder .. ".toc")
    if not fh then return nil end
    local toc = { files = {}, deps = {}, opt = {} }
    for line in fh:lines() do
        line = line:gsub("\r", "")
        local tag, value = line:match("^##%s*([%w%-]+):%s*(.-)%s*$")
        if tag == "Dependencies" or tag == "RequiredDeps" then
            for d in value:gmatch("[^,%s]+") do toc.deps[#toc.deps + 1] = d end
        elseif tag == "OptionalDeps" then
            for d in value:gmatch("[^,%s]+") do toc.opt[#toc.opt + 1] = d end
        elseif not line:match("^#") and line:match("%S") then
            toc.files[#toc.files + 1] = line:match("^%s*(.-)%s*$")
        end
    end
    fh:close()
    return toc
end

local function loadAddon(folder, loaded, wanted)
    if loaded[folder] then return true end
    local toc = readToc(folder)
    if not toc then return false end
    loaded[folder] = "loading"
    for _, d in ipairs(toc.deps) do
        if not wanted[d] or not loadAddon(d, loaded, wanted) then
            print("  " .. folder .. ": missing dependency " .. d .. " (not loaded)")
            loaded[folder] = nil
            return false
        end
    end
    for _, d in ipairs(toc.opt) do
        if wanted[d] then loadAddon(d, loaded, wanted) end
    end
    local private = {}
    for _, file in ipairs(toc.files) do
        if file:match("%.lua$") then
            local chunk, err = loadfile(ROOT .. folder .. "/" .. file)
            if not chunk then
                report(folder .. "/" .. file, err)
            else
                local ok, e = xpcall(function() return chunk(folder, private) end, debug.traceback)
                if not ok then report(folder .. "/" .. file, e) end
            end
        end
    end
    loaded[folder] = true
    loaded[#loaded + 1] = folder
    return true
end

local function fire(event, ...)
    local args = { ... }
    for _, f in ipairs(frames) do
        local fn = f.__scripts.OnEvent
        if fn and f.__events[event] then
            local ok, e = xpcall(function() fn(f, event, unpack(args)) end, debug.traceback)
            if not ok then report("event " .. event .. " (" .. tostring(f.__name) .. ")", e) end
        end
    end
end

local function run(folders, checks)
    -- (each one's required addons with it, as the game insists on them)
    local wanted = {}
    local function want(f)
        if wanted[f] then return end
        wanted[f] = true
        local toc = readToc(f)
        for _, d in ipairs(toc and toc.deps or {}) do
            if readToc(d) then
                want(d)
                table.insert(folders, 1, d)
            end
        end
    end
    for _, f in ipairs({ unpack(folders) }) do want(f) end
    local loaded = {}
    for _, f in ipairs(folders) do loadAddon(f, loaded, wanted) end
    for _, f in ipairs(loaded) do fire("ADDON_LOADED", f) end
    fire("VARIABLES_LOADED")
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD", true, false)
    for _, check in ipairs(checks or {}) do
        local ok, e = xpcall(check.fn, debug.traceback)
        if not ok then report("check " .. check.name, e) end
    end
end

-- The folders with a TOC
local function allFolders()
    local list = {}
    local p = io.popen("ls -d " .. ROOT .. "ImprovedForever*/ 2>/dev/null")
    for line in p:lines() do
        local name = line:match("([^/]+)/?$")
        if name and readToc(name) then list[#list + 1] = name end
    end
    p:close()
    table.sort(list)
    return list
end

-- After loading: open each panel the modules give (what a player does first)
local CHECKS = {
    { name = "config panel", fn = function()
        local IF = rawget(_G, "ImprovedForever")
        if IF and IF.Menu and IF.Menu.Open then
            IF.Menu.Open()
            for _, tab in ipairs(IF.Menu.TABS or {}) do IF.Menu.SetTab(tab.key) end
            IF.Menu.Close()
        end
    end },
    { name = "config panel presses", fn = function()
        local IF = rawget(_G, "ImprovedForever")
        if not (IF and IF.Menu and #IF.Menu.TABS > 0) then return end
        local M = IF.Menu
        M.Open()
        for _, tab in ipairs(M.TABS) do
            M.SetTab(tab.key)
            for _, name in ipairs({ "DOWN", "DOWN", "RIGHT", "LEFT", "UP", "RT", "DOWN", "RIGHT", "LT",
                "Y", "UP", "LEFT", "A", "DOWN", "UP", "A", "B", "A", "B", "RT", "A", "DOWN", "A", "B" }) do
                if not M.IsOpen() then M.Open(tab.key) end
                M.Press(name)
            end
            local page = tab.page
            if page.StickStep then page:StickStep(1) M.Render() end
            if page.StickSide then page:StickSide(1) M.Render() end
        end
        M.Close()
    end },
    -- (the Wheel module: a wheel of each kind made, built and shown)
    { name = "wheel kinds", fn = function()
        local IF = rawget(_G, "ImprovedForever")
        local MW, KD = IF and IF.MyWheels, IF and IF.WheelKinds
        if not (MW and KD and IF.Menu) then return end
        local M = IF.Menu
        M.Open()
        M.SetTab("wheel")
        for _, kind in ipairs(KD.ORDER) do
            if #MW.List() >= MW.MAX then table.remove(MW.List(), 1) end
            local id = MW.Create(kind.key)
            IF.RingBuilders[MW.RingKey(id)]()
            MW.Page.key = MW.RingKey(id)
            for _, name in ipairs({ "RIGHT", "RT", "A", "Y", "X", "LEFT" }) do
                if not M.IsOpen() then M.Open("wheel") end
                M.Press(name)
            end
        end
        if KD.Equip then KD.Equip({ item = 1, slot = 13 }) end
        M.Close()
    end },
}

local args = { ... }
if args[1] == "each" then
    -- Each module alone with the core, in a fresh state each time
    local all = allFolders()
    local script = arg and arg[0] or "tools/loadcheck.lua"
    local total = 0
    for _, folder in ipairs(all) do
        if folder ~= "ImprovedForever" then
            print("== ImprovedForever + " .. folder)
            local ok = os.execute("luajit " .. script .. " ImprovedForever " .. folder)
            if ok ~= 0 and ok ~= true then total = total + 1 end
        end
    end
    print("== all")
    local ok = os.execute("luajit " .. script .. " all")
    if ok ~= 0 and ok ~= true then total = total + 1 end
    os.exit(total == 0 and 0 or 1)
end
local folders = args[1] == "all" and allFolders() or args
run(folders, CHECKS)
print(failures == 0 and "  ok" or ("  " .. failures .. " error(s)"))
os.exit(failures == 0 and 0 or 1)
