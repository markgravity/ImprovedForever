-- The journal's voice: how its writer talks, by their race (the
-- character's own, or another picked in the Journal tab). A light touch,
-- at a few places (JournalWriter.lua): waking and lying down, a fall, growing
-- stronger, the day's coin, a stranger of my own kind, one cry on a great
-- moment a day, the name signed under the page. The rest is the same story.
local IF = ImprovedForever

local J = IF.Journal

-- Each voice (every part may be left out: the plain one is said then):
--   name: in the Journal tab; woke = { [bin] = "..." } (dawn, early, late,
--   midday, evening, night: how the day began); wakeAside (after it); bed
--   (after the day's last words); fell = { ... } (after a fall); stronger
--   (after growing stronger); cry (a great moment's cry); richer / poorer
--   (the day's coin, %s the amount); kin (my own kind, said of another);
--   sign (the name signed: %s the name, %s son / daughter)
local VOICES = {
    Human = {
        name = "Human", wakeAside = "and said a word to the Light", cry = "By the Light!",
        fell = { "The Light would see me up again.", "Not my finest hour, Light forgive me." },
        stronger = "The Light was with me.", bed = "A fair day's work.",
        richer = "All told, I ended the day %s the richer.", sign = "— %s of Stormwind",
    },
    Dwarf = {
        name = "Dwarf", wakeAside = "and could have used an ale", cry = "By my beard!",
        fell = { "Stone and steel, but I'd taken a beating.", "I'll not tell the lads at the Thunderbrew about that one." },
        stronger = "Stronger than a mountain goat, I'd wager.", bed = "A good day's graft.",
        richer = "All told, my purse was %s heavier.", poorer = "All told, my purse was %s lighter. Bah.",
        kin = "dwarf", sign = "— %s, %s of Khaz Modan",
    },
    NightElf = {
        name = "Night Elf", wakeAside = "beneath the fading moon", cry = "Elune be praised.",
        fell = { "Elune would see me back on my feet.", "Even the ancients fall, now and then." },
        stronger = "Elune's light was in me.", bed = "I rested beneath Elune's light.",
        richer = "Coin matters little to my kind, but I ended the day %s richer.", kin = "kaldorei",
        sign = "— %s, under Elune's light",
    },
    Gnome = {
        name = "Gnome", wakeAside = "with three ideas already rattling about", cry = "Fascinating!",
        fell = { "A minor setback. Purely temporary.", "Note to self: reinforce the armour plating." },
        stronger = "Efficiency up, by my estimate, a good eleven percent.", bed = "I filed my notes and slept.",
        richer = "Net gain for the day: %s, by my count.", poorer = "Net loss for the day: %s. Must recalculate.",
        kin = "gnome", sign = "— %s, tinker of Gnomeregan",
    },
    Orc = {
        name = "Orc", wakeAside = "ready for battle", cry = "Lok'tar!",
        fell = { "I fell. I rose. That is all.", "A warrior's death, and back again." },
        stronger = "The blood of my fathers burned hotter.", bed = "Enough for one day.",
        richer = "I took %s more than I had.", kin = "orc", sign = "— %s, for the Horde",
    },
    Scourge = {
        name = "Forsaken", woke = { dawn = "I rose before dawn, as the dead do", night = "I rose in the dead of night, as the dead do" },
        cry = "How tedious.",
        fell = { "Death again. It barely slows me.", "Dying is so tiresome." },
        stronger = "Not alive, but stronger.", bed = "The living need their sleep; I merely pause.",
        richer = "%s richer. Coin, at least, keeps.", kin = "Forsaken", sign = "— %s, of the Forsaken",
    },
    Tauren = {
        name = "Tauren", wakeAside = "and greeted the Earth Mother", cry = "The Earth Mother provides.",
        fell = { "The Earth Mother caught me, as she always does.", "Even the strongest bull stumbles." },
        stronger = "The Earth Mother's strength flowed through me.", bed = "The winds carried me to rest.",
        richer = "The day left me %s richer.", kin = "tauren", sign = "— %s, walking with the Earth Mother",
    },
    Troll = {
        name = "Troll", wakeAside = "with the loa watchin'", cry = "Dat be somethin', mon!",
        fell = { "Ha! Dey not be keepin' me down.", "De spirits sent me right back, mon." },
        stronger = "De loa be smilin' on me.", bed = "Dat be a good day, mon.",
        richer = "Ended de day %s richer, mon.", kin = "troll", sign = "— %s of the Darkspear",
    },
    -- Forever's Skyborne, the shen'dorei of Zephras Isle in Skywall: the High
    -- Order (Alliance), heirs of the Highborne scholars of Eldre'Thalas,
    -- reclaiming lost arcane lore so their people need lean on no spirit;
    -- the Windshapers (Horde), keepers of the wind spirits' gift of skysight,
    -- seeking their vanished elemental mentors
    HighOrder = {
        name = "High Order", wakeAside = "and set down a line in my study notes", cry = "Knowledge is its own wind.",
        fell = { "A lesson, painfully learned. I wrote it down.", "Even the Highborne were humbled, once." },
        stronger = "Another piece of the old lore was mine again.", bed = "I closed my books for the night.",
        richer = "I ended the day %s richer: more to spend on old tomes.", kin = "shen'dorei",
        sign = "— %s of the High Order, Valanaar",
    },
    Windshaper = {
        name = "Windshaper", wakeAside = "and listened for the winds", cry = "The winds answer!",
        fell = { "The winds fell silent, and so did I, for a while.", "I fell, but the air still holds me up." },
        stronger = "My skysight grew a little clearer.", bed = "I rested, and listened for our lost mentors on the wind.",
        richer = "The winds left me %s richer.", kin = "shen'dorei",
        sign = "— %s, Windshaper of Zephras Isle",
    },
}
J.VOICES = VOICES
J.VOICE_ORDER = { "Human", "Dwarf", "NightElf", "Gnome", "Orc", "Scourge", "Tauren", "Troll", "HighOrder", "Windshaper" }
-- Forever's own races by id (UnitRace's third): the Skyborne
local RACE_IDS = { [95] = "HighOrder", [96] = "Windshaper" }

-- The voice the journal writes in: the one picked (charDB.journal.voice),
-- else the character's race (Forever's Skyborne by their race id), else none
function J.Voice()
    local db = IF.charDB and IF.charDB.journal
    local picked = db and db.voice
    if picked and VOICES[picked] then return VOICES[picked], picked end
    local _, token, id = UnitRace("player")
    if RACE_IDS[id] then return VOICES[RACE_IDS[id]], RACE_IDS[id] end
    if token == "Undead" then token = "Scourge" end
    if VOICES[token] then return VOICES[token], token end
    return {}, nil
end

-- The name signed under a day's page
function J.Signature()
    local voice = J.Voice()
    local name = UnitName("player") or ""
    if not voice.sign then return "— " .. name end
    local sex = UnitSex and UnitSex("player")
    return format(voice.sign, name, sex == 3 and "daughter" or sex == 2 and "son" or "child")
end
