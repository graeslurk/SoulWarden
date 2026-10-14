-- Minimap button: the Soul Warden logo on the edge of the minimap. Click
-- it to open the window, drag it to move it around the minimap. A red
-- badge shows how many shards you're over your limit, and the tooltip
-- shows your shard count.

local ADDON_NAME, ns = ...
local L = ns.L

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SIZE = 31 -- same as other minimap buttons
local ICON_SIZE = 20 -- fills the hole in the gold ring
local EDGE_OFFSET = 10 -- how far outside the minimap's edge the button sits

-- Which quarters of the minimap are round, for minimap addons that change
-- its shape (GetMinimapShape). Order: bottom-right, bottom-left, top-right,
-- top-left. In a square quarter the button follows the corner instead.
local SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local button

local function SetAngle(angle)
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local quarter = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local shape = SHAPES[GetMinimapShape and GetMinimapShape() or "ROUND"] or SHAPES.ROUND
    local w = Minimap:GetWidth() / 2 + EDGE_OFFSET
    local h = Minimap:GetHeight() / 2 + EDGE_OFFSET
    if shape[quarter] then
        x, y = x * w, y * h
    else
        -- Push out along the diagonal, then flatten onto the square's edge.
        local diagonalW, diagonalH = math.sqrt(2 * w * w) - 10, math.sqrt(2 * h * h) - 10
        x = math.max(-w, math.min(x * diagonalW, w))
        y = math.max(-h, math.min(y * diagonalH, h))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- While dragging: follow the cursor around the minimap.
local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    SetAngle(ns.db.minimapAngle)
end

local function ShowTooltip(self)
    local normal, soulBag = ns.CountShards()
    local total, limit = normal + soulBag, ns.db.maxShards

    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Soul Warden", 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Soul shards"], total, 1, 0.82, 0, 1, 1, 1)
    if soulBag > 0 then
        GameTooltip:AddDoubleLine(L["In your soul bag"], soulBag, 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(L["Your limit"], limit, 1, 0.82, 0, 1, 1, 1)
    if total > limit then
        GameTooltip:AddLine(L["%d over your limit"]:format(total - limit), 1, 0.32, 0.32)
    else
        GameTooltip:AddLine(L["Within your limit"], 0.45, 0.8, 0.5)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Click to open the window. Drag to move this button."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function CreateButton()
    button = CreateFrame("Button", "SoulWardenMinimapButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    -- The game's own minimap button look: dark background, the icon, and
    -- the gold ring on top.
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    -- The logo cropped to just inside its purple ring, so only the crystal
    -- disc shows inside the gold one.
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MEDIA .. "icon")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Red badge with the number of shards over your limit.
    local badge = CreateFrame("Frame", nil, button)
    badge:SetSize(16, 16)
    badge:SetPoint("CENTER", button, "BOTTOMRIGHT", -3, 3)
    local badgeBg = badge:CreateTexture(nil, "ARTWORK")
    badgeBg:SetTexture(MEDIA .. "circle")
    badgeBg:SetVertexColor(0.86, 0.22, 0.22)
    badgeBg:SetAllPoints()
    local badgeText = badge:CreateFontString(nil, "OVERLAY")
    badgeText:SetFont(FONT, 10, "OUTLINE")
    badgeText:SetPoint("CENTER", 0, 0)
    button.badge, button.badgeText = badge, badgeText

    button:SetScript("OnClick", function() ns.ToggleWindow() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)

    SetAngle(ns.db.minimapAngle)
end

-- Updates the badge, and the tooltip if it's showing.
function ns.RefreshMinimapButton()
    if not (button and button:IsShown()) then return end
    local normal, soulBag = ns.CountShards()
    local over = normal + soulBag - ns.db.maxShards
    button.badge:SetShown(over > 0)
    button.badgeText:SetText(over > 99 and "99+" or over)
    if GameTooltip:IsOwned(button) then ShowTooltip(button) end
end

function ns.SetMinimapButton(show)
    ns.db.minimapButton = show and true or false
    if show and not button then CreateButton() end
    if button then button:SetShown(show) end
    ns.RefreshMinimapButton()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" and ns.db.minimapButton then CreateButton() end
    ns.RefreshMinimapButton()
end)
