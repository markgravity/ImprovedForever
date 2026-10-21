-- What the copied margin (UI/Journey/Margin.lua) takes from Social Diary's
-- left page as it loads: the way to a person's page from their note. Ours
-- turns to the companion in the Journal (set once the pages are in).
local addonName, ns = ...

local YourDiary = ns.UI.YourDiary
YourDiary.ToPerson = function(guid)
    if YourDiary.OpenPerson then YourDiary.OpenPerson(guid) end
end
