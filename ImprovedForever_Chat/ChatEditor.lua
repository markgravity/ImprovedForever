-- The Chat tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- the line picker on / off. ChatLines.lua does the work.
local IF = ImprovedForever

local CL = IF.ChatLines
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local ITEMS = {
    Item({
        key = "enabled", group = "lines", label = "Chat lines",
        tip = "While the chat has the controller (its edit box open), D-pad Up goes up into its lines: the D-pad "
            .. "picks a line, left / right a link in it (its tooltip shows). Cross opens an item in the Library, "
            .. "Square puts the link in your message, Circle goes back to the edit box.",
        -- (with the mouse the chat's own links do it: Alt + click, the core's)
        note = function()
            if IF.Input.Pad() then return nil end
            return "For the controller. With the mouse the chat's own links do this: a click shows its tooltip, "
                .. "Shift + click puts it in your message"
                .. (IF.Library and ", Alt + click opens an item in the Library." or ".")
        end,
    }, OnOff(function() return CL.Settings().enabled end, function(on)
        CL.Settings().enabled = on
        if not on then CL.Close() end
    end, "Chat lines")),
}

local GROUPS = {
    { key = "lines", label = "Chat" },
}

IF.ChatEditor = IF.SettingsPage({ key = "chat", label = "Chat", module = "chat", order = 65 }, GROUPS, ITEMS)
