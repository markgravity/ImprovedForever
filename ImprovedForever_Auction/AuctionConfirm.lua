-- A confirmation popup for the auction house's pages (posting, cancelling,
-- the server's price warning): our own frame (the game's StaticPopup from
-- addon code froze Forever), over the window it asks for, that window
-- dimmed. It doesn't take the pad itself: the window showing it hands it
-- its presses (C.Press) first; Cross accepts, from that very press (posting
-- and cancelling want a hardware event), Circle backs out.
-- C.Show(o): an item's header (as the Sell tab's), a message, a receipt
-- (as the Sell tab's), the buttons; o's fields at C.Show.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C

local C = {}
IF.AuctionConfirm = C

local W = 420

local ok, box = pcall(K.NewFrame, "Frame", "ImprovedForeverAuctionConfirm", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    box = K.NewFrame("Frame", "ImprovedForeverAuctionConfirm", UIParent, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
box:SetSize(W, 160)
box:SetFrameStrata("FULLSCREEN_DIALOG")
box:SetToplevel(true)
box:EnableMouse(true)
box:SetClampedToScreen(true)
box:Hide()
-- (its own focus glow, as the game's windows: it has the pad while up)
IF.Focus.Glow(box, true)

local titleText = box.TitleContainer and box.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(box, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

-- The window behind, dimmed
local shade = K.NewFrame("Frame", nil, UIParent)
shade:SetFrameStrata("FULLSCREEN")
shade:EnableMouse(true)
shade:Hide()
local shadeTex = shade:CreateTexture(nil, "BACKGROUND")
shadeTex:SetAllPoints()
shadeTex:SetColorTexture(0, 0, 0, 0.55)

-- The header, as the Sell tab's: the item's icon (how many on it), its
-- name in its quality's colour, a line under it
local icon = box:CreateTexture(nil, "ARTWORK")
icon:SetSize(40, 40)
icon:SetPoint("TOPLEFT", 18, -36)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local iconBorder = box:CreateTexture(nil, "OVERLAY")
iconBorder:SetPoint("TOPLEFT", icon, -1, 1)
iconBorder:SetPoint("BOTTOMRIGHT", icon, 1, -1)
iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
iconBorder:SetBlendMode("ADD")
iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
local count = box:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
local name = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
name:SetPoint("RIGHT", box, "RIGHT", -18, 0)
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
local sub = K.ChatText(box, 11, KC.help)
sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
sub:SetPoint("RIGHT", box, "RIGHT", -18, 0)
sub:SetJustifyH("LEFT")
sub:SetWordWrap(false)

-- A message (a warning, or what has no header)
local text = K.ChatText(box, 14, KC.cream)
text:SetJustifyH("LEFT")
text:SetJustifyV("TOP")
text:SetWordWrap(true)

-- The receipt: label left, amount right, a rule above the last (the total)
local LINE = 20
local receipt = K.NewFrame("Frame", nil, box)
receipt:SetPoint("LEFT", 22, 0)
receipt:SetPoint("RIGHT", -22, 0)
local receiptLines = {}
local function ReceiptLine(i)
    local line = receiptLines[i]
    if line then return line end
    line = {
        label = K.ChatText(receipt, 13, KC.help),
        value = K.ChatText(receipt, 13, KC.cream),
    }
    line.value:SetJustifyH("RIGHT")
    receiptLines[i] = line
    return line
end
local totalLabel = K.ChatText(receipt, 14, KC.cream)
local totalValue = K.ChatText(receipt, 14, KC.title)
totalValue:SetJustifyH("RIGHT")
local rule = receipt:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetColorTexture(0.45, 0.38, 0.25, 0.9)

-- The two buttons, the pad's glyphs on them (mouse clicks work too)
local function Button(onClick)
    local b = K.NewFrame("Button", nil, box, "UIPanelButtonTemplate")
    b:SetHeight(28)
    b:SetScript("OnClick", onClick)
    return b
end

local opts
local acceptButton = Button(function() C.Accept() end)
local cancelButton = Button(function() C.Cancel() end)
acceptButton:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -6, 14)
cancelButton:SetPoint("BOTTOMLEFT", box, "BOTTOM", 6, 14)

function C.IsShown()
    return box:IsShown()
end

-- o: { title, icon, count, name, quality, sub (the header; no name: none),
-- text (a message), lines = { { label, value } }, total = { label, value },
-- accept, cancel, onAccept, onCancel, over }
function C.Show(o)
    opts = o
    titleText:SetText(o.title or "Confirm")
    local y = -36
    -- The header
    local header = o.name ~= nil
    for _, part in ipairs({ icon, iconBorder, count, name, sub }) do part:SetShown(header) end
    if header then
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.quality or 1]
        icon:SetTexture(o.icon or 134400)
        iconBorder:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
        count:SetText((o.count or 1) > 1 and o.count or "")
        name:SetText(o.name)
        name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
        sub:SetText(o.sub or "")
        y = y - 40 - 14
    end
    -- The message
    text:SetShown(o.text ~= nil)
    if o.text then
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", 22, y)
        text:SetPoint("RIGHT", box, "RIGHT", -22, 0)
        text:SetText(o.text)
        y = y - text:GetStringHeight() - 14
    end
    -- The receipt
    local lines = o.lines or {}
    local hasReceipt = #lines > 0 or o.total ~= nil
    receipt:SetShown(hasReceipt)
    if hasReceipt then
        receipt:ClearAllPoints()
        receipt:SetPoint("TOPLEFT", 22, y)
        receipt:SetPoint("TOPRIGHT", -22, y)
        local ry = 0
        for i, l in ipairs(lines) do
            local line = ReceiptLine(i)
            line.label:ClearAllPoints()
            line.label:SetPoint("TOPLEFT", 0, ry)
            line.value:ClearAllPoints()
            line.value:SetPoint("TOPRIGHT", 0, ry)
            line.label:SetText(l[1])
            line.value:SetText(l[2])
            line.label:Show()
            line.value:Show()
            ry = ry - LINE
        end
        for i = #lines + 1, #receiptLines do
            receiptLines[i].label:Hide()
            receiptLines[i].value:Hide()
        end
        rule:SetShown(o.total ~= nil and #lines > 0)
        totalLabel:SetShown(o.total ~= nil)
        totalValue:SetShown(o.total ~= nil)
        if o.total then
            if #lines > 0 then
                rule:ClearAllPoints()
                rule:SetPoint("TOPLEFT", 0, ry - 3)
                rule:SetPoint("TOPRIGHT", 0, ry - 3)
                ry = ry - 9
            end
            totalLabel:ClearAllPoints()
            totalLabel:SetPoint("TOPLEFT", 0, ry)
            totalValue:ClearAllPoints()
            totalValue:SetPoint("TOPRIGHT", 0, ry)
            totalLabel:SetText(o.total[1])
            totalValue:SetText(o.total[2])
            ry = ry - LINE
        end
        receipt:SetHeight(-ry)
        y = y + ry - 8
    end
    -- (the pad's glyphs on them; with the mouse only the words)
    local pad = IF.Input.Pad()
    acceptButton:SetText((pad and (IF.GlyphText("A", 18) .. " ") or "") .. (o.accept or "OK"))
    cancelButton:SetText((pad and (IF.GlyphText("B", 18) .. " ") or "") .. (o.cancel or "Cancel"))
    acceptButton:SetWidth(math.max(140, acceptButton:GetTextWidth() + 30))
    cancelButton:SetWidth(math.max(140, cancelButton:GetTextWidth() + 30))
    local over = o.over or UIParent
    box:ClearAllPoints()
    box:SetPoint("CENTER", over, "CENTER", 0, 20)
    box:SetHeight(-y + 14 + 28 + 14)
    shade:ClearAllPoints()
    shade:SetAllPoints(over)
    shade:Show()
    box:Show()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850)
end

local function Close()
    box:Hide()
    shade:Hide()
end

function C.Accept()
    local o = opts
    if not o then return Close() end
    opts = nil
    Close()
    if o.onAccept then o.onAccept() end
end

function C.Cancel()
    local o = opts
    opts = nil
    Close()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851)
    if o and o.onCancel then o.onCancel() end
end

function C.Hide()
    opts = nil
    Close()
end

-- A press from the window behind: Cross accepts, Circle backs out, the
-- rest wait (true: taken)
function C.Press(name)
    if not box:IsShown() then return false end
    if name == "A" then
        C.Accept()
    elseif name == "B" then
        C.Cancel()
    end
    return true
end

-- Gone with the auction house or as combat starts
local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function() C.Hide() end)
tinsert(UISpecialFrames, box:GetName())
-- (closed by Escape: as Cancel, its onCancel told)
box:SetScript("OnHide", function()
    shade:Hide()
    local o = opts
    opts = nil
    if o and o.onCancel then o.onCancel() end
end)
