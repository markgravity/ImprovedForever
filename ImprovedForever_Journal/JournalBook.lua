-- The Journal's companions, for the book (Book/BookPages.lua): everyone
-- met with dealings between us, the best known first, and each one's face.
local IF = ImprovedForever

local J = IF.Journal

local ICON = "Interface\\Icons\\"

local JB = {}
IF.JournalBook = JB

-- Companions: everyone I've had dealings with (talk overheard alone isn't
-- enough), the best known first
local COMPANION = ICON .. "INV_Misc_GroupLooking"

-- Someone's face: their race's icon for their gender, else their class's,
-- else the group's: the game's own atlases (GetRaceAtlas, GetClassAtlas, as
-- the chat shows players), each only if this client has it
local function Avatar(p)
    if not p then return COMPANION end
    local race = p.raceToken and p.raceToken:lower()
    if race == "scourge" then race = "undead" end
    local gender = p.sex == 3 and "female" or p.sex == 2 and "male" or nil
    if race and gender and GetRaceAtlas then
        for _, hiRez in ipairs({ true, false }) do
            local ok, atlas = pcall(GetRaceAtlas, race, gender, hiRez)
            if ok and atlas and IF.HasAtlas(atlas) then return "atlas:" .. atlas end
        end
    end
    if p.classToken and GetClassAtlas then
        local ok, atlas = pcall(GetClassAtlas, p.classToken:lower())
        if ok and atlas and IF.HasAtlas(atlas) then return "atlas:" .. atlas end
    end
    return COMPANION
end
local function Companions()
    local list = {}
    local PE = J.People
    if not PE then return list end
    local people = IF.charDB and IF.charDB.journal and IF.charDB.journal.people or {}
    for name, p in pairs(people) do
        local n = p.n or {}
        local dealt = (n.grouped or 0) > 0 or (n.talks or 0) > 0 or (n.emotesIn or 0) + (n.emotesOut or 0) > 0
            or (n.trades or 0) + (n.gifts or 0) + (n.sent or 0) + (n.duels or 0) + (n.revivedMe or 0) > 0
        if dealt then list[#list + 1] = { name = name, p = p, score = PE.Score(p) } end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    return list
end

JB.Avatar, JB.Companions, JB.COMPANION = Avatar, Companions, COMPANION
