-- Improved Forever: Journal. What the character does, kept a day at a time
-- (Journal.lua), written as a diary (JournalWriter.lua) and read in its
-- window, laid out as Spoken's Compendium (JournalBook.lua's pages in
-- JournalWindow.lua); set up in its tab (JournalEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "journal", label = "Journal", icon = IF.TEX .. "ic_mod_journal", addon = ... })

BINDING_HEADER_IMPROVEDFOREVER_JOURNAL = "Improved Forever: Journal"

-- /if journal [today | YYYY-MM-DD]: the journal, or a day of it
IF.AddCommand("journal", function(args)
    local day = args[1]
    if day == "today" then day = IF.Journal.TodayKey() end
    if day and not IF.Journal.KeyTime(day) then return IF.Print("/if journal [today | YYYY-MM-DD]") end
    IF.JournalBook.Open(day)
end, "[today | YYYY-MM-DD]: your journal, or a day of it")
