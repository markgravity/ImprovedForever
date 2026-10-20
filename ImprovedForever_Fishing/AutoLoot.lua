-- The game's loot window kept away while fishing: with a pole in hand the
-- game's own auto loot is on (autoLootDefault), so a catch is taken at
-- once and its window closes by itself (the fishing bar shows the catch
-- instead, CastBar.lua). Your own
-- setting is put back when the pole is put away; kept per character
-- (IF.charDB.fishingLootSaved) until then, so a /reload or a logout with
-- the pole in hand still puts it back. Off: /if fishloot.
local IF = ImprovedForever
local F = IF.Fishing

local CVAR = "autoLootDefault"

local function Get()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local ok, value = pcall(get, CVAR)
    return ok and value or nil
end

local function Set(value)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then pcall(set, CVAR, value) end
end

-- (on with a pole in hand, the player's own value back without one)
local function Apply()
    if not (IF.db and IF.charDB) then return end
    local want = F.Settings().autoLoot and F.PoleEquipped()
    local saved = IF.charDB.fishingLootSaved
    if want and saved == nil then
        local now = Get()
        if now and now ~= "1" then
            IF.charDB.fishingLootSaved = now
            Set("1")
        end
    elseif not want and saved ~= nil then
        Set(saved)
        IF.charDB.fishingLootSaved = nil
    end
end
F.ApplyAutoLoot = Apply

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", Apply)
IF.OnLogin(Apply)

-- /if fishloot: the auto loot while fishing on or off
IF.AddCommand("fishloot", function()
    local s = F.Settings()
    s.autoLoot = not s.autoLoot
    Apply()
    IF.Print("Fishing: auto loot with a pole in hand " .. (s.autoLoot and "on" or "off") .. ".")
end, ": auto loot while fishing on / off (keeps the loot window away)")
