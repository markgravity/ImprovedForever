local _, IQT = ...

-- The tracker's context menus (right-click on a block), as the
-- game builds them (MenuUtil.CreateContextMenu with a rootDescription), shown
-- in our dropdown (Dropdown.lua): the fork calls
-- IFObjectiveTrackerMenu.CreateContextMenu instead of MenuUtil's
-- (tools/fork_objective_tracker.py), the game's Menu can't be opened from
-- addon code on Forever.

local Menu = {}
IFObjectiveTrackerMenu = Menu

-- An element description: what the generators call on it; anything else
-- the game's has does nothing here
local Description = {}
local nop = function() end
setmetatable(Description, { __index = function() return nop end })
local DescriptionMeta = { __index = Description }

function Description:SetEnabled(enabled)
	self.entry.enabled = enabled and true or false
end

local function NewRoot(list)
	local root = setmetatable({ list = list }, DescriptionMeta)
	local function Add(entry)
		list[#list + 1] = entry
		return setmetatable({ entry = entry, list = list }, DescriptionMeta)
	end
	function root:CreateTitle(text)
		return Add({ kind = "title", text = text })
	end
	function root:CreateDivider()
		return Add({ kind = "divider" })
	end
	function root:CreateSpacer()
		return Add({ kind = "divider" })
	end
	function root:CreateButton(text, onClick, data)
		return Add({ kind = "button", text = text, onSelect = function() onClick(data) end })
	end
	function root:CreateRadio(text, isSelected, onSelect, data)
		return Add({ kind = "radio", text = text,
			isSelected = function() return isSelected(data) end,
			onSelect = function() onSelect(data) end })
	end
	function root:CreateCheckbox(text, isSelected, onSelect, data)
		return Add({ kind = "checkbox", text = text,
			isSelected = function() return isSelected(data) end,
			onSelect = function() onSelect(data) end })
	end
	return root
end

-- -> menu: menu:SetClosedCallback(fn)
function Menu.CreateContextMenu(owner, generator)
	local list = {}
	local ok, err = pcall(generator, owner, NewRoot(list))
	if not ok then
		IQT.Print("menu: " .. tostring(err))
	end
	local menu = {}
	function menu:SetClosedCallback(fn) self.closed = fn end
	if #list == 0 then return menu end
	local opts = {
		onClose = function()
			if menu.closed then menu.closed() end
		end,
	}
	-- (shown on the next frame: the click that opened it is over by then)
	C_Timer.After(0, function() IQT.ShowMenu(list, opts) end)
	return menu
end
