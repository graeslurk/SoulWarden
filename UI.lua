-- Soul Warden window: a dark, card-based window in the style of Pocket
-- Goblin, with the shard limit and the hotkey and macro.

local ADDON_NAME, ns = ...
local L = ns.L

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local WIDTH = 540
local HEADER_HEIGHT = 72
local CARD_WIDTH = WIDTH - 40

local C = {
    bg = { 0.047, 0.05, 0.058, 0.97 },
    windowBorder = { 0.17, 0.17, 0.19, 1 },
    card = { 0.078, 0.081, 0.092, 1 },
    cardBorder = { 0.16, 0.165, 0.18, 1 },
    control = { 0.11, 0.114, 0.126, 1 },
    controlHover = { 0.15, 0.154, 0.168, 1 },
    controlBorder = { 0.24, 0.245, 0.265, 1 },
    accent = { 0.62, 0.46, 0.93, 1 },
    accentHover = { 0.72, 0.57, 1, 1 },
    text = { 0.92, 0.92, 0.93, 1 },
    muted = { 0.53, 0.54, 0.58, 1 },
    off = { 0.2, 0.205, 0.225, 1 },
    knobOff = { 0.78, 0.78, 0.82, 1 },
    white = { 1, 1, 1, 1 },
}

local window
local updaters = {} -- controls and texts refreshed by RefreshWindow

------------------------------------------------------------------------
-- Drawing helpers
------------------------------------------------------------------------

local function SetColor(texture, color)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

-- A rounded rectangle that keeps its corners at any size (texture slicing).
-- file is "rounded" (filled) or "rounded-border" (1px outline).
local function Rounded(parent, layer, color, file)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    if texture.SetTextureSliceMargins then
        texture:SetTexture(MEDIA .. (file or "rounded"))
        texture:SetTextureSliceMargins(8, 8, 8, 8)
        texture:SetTextureSliceMode(Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0)
        SetColor(texture, color)
    elseif file == "rounded-border" then
        texture:Hide() -- no slicing support: skip outlines rather than draw a blob
    else
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
    return texture
end

local function Icon(parent, name, size, color, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(MEDIA .. name)
    texture:SetSize(size, size)
    SetColor(texture, color)
    return texture
end

local function Text(parent, size, color, layer)
    local text = parent:CreateFontString(nil, layer or "ARTWORK")
    text:SetFont(FONT, size, "")
    text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    text:SetShadowColor(0, 0, 0, 0.6)
    text:SetShadowOffset(1, -1)
    text:SetJustifyH("LEFT")
    return text
end

local function PlayToggleSound(on)
    if SOUNDKIT then
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

------------------------------------------------------------------------
-- Controls
------------------------------------------------------------------------

-- Pill-shaped on/off switch whose knob slides across.
local function CreateToggle(parent, get, set)
    local toggle = CreateFrame("Button", nil, parent)
    toggle:SetSize(48, 24)

    local track = toggle:CreateTexture(nil, "ARTWORK")
    track:SetTexture(MEDIA .. "pill")
    track:SetAllPoints()

    local knob = toggle:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(MEDIA .. "circle")
    knob:SetSize(18, 18)

    local pos = get() and 1 or 0
    local hovered = false

    local function paint()
        knob:SetPoint("LEFT", 3 + pos * 24, 0)
        local on = hovered and C.accentHover or C.accent
        local off = hovered and C.controlBorder or C.off
        track:SetVertexColor(Lerp(off[1], on[1], pos), Lerp(off[2], on[2], pos), Lerp(off[3], on[3], pos))
        knob:SetVertexColor(Lerp(C.knobOff[1], 1, pos), Lerp(C.knobOff[2], 1, pos), Lerp(C.knobOff[3], 1, pos))
    end

    local function animate(self, elapsed)
        local target = get() and 1 or 0
        local step = elapsed * 7
        if math.abs(target - pos) <= step then
            pos = target
            self:SetScript("OnUpdate", nil)
        else
            pos = pos + (target > pos and step or -step)
        end
        paint()
    end

    -- Slides to the current value, or jumps there when not animating.
    function toggle:Update(instant)
        if instant then
            if not self:GetScript("OnUpdate") then
                pos = get() and 1 or 0
                paint()
            end
        else
            self:SetScript("OnUpdate", animate)
        end
    end

    toggle:SetScript("OnClick", function(self)
        local value = not get()
        set(value)
        PlayToggleSound(value)
        self:Update()
    end)
    toggle:SetScript("OnEnter", function() hovered = true; paint() end)
    toggle:SetScript("OnLeave", function() hovered = false; paint() end)

    paint()
    updaters[#updaters + 1] = function() toggle:Update(true) end
    return toggle
end

-- Thin track with a coloured fill, a round knob and the value on the right.
local function CreateSlider(parent, minValue, maxValue, get, onChange, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width + 40, 24)

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 24)
    slider:SetPoint("LEFT")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetHitRectInsets(0, 0, -4, -4)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(C.off[1], C.off[2], C.off[3], 1)
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    fill:SetHeight(4)
    fill:SetPoint("LEFT")

    slider:SetThumbTexture(MEDIA .. "circle")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(16, 16)
    SetColor(thumb, C.white)

    local label = Text(holder, 15, C.text)
    label:SetPoint("RIGHT")
    label:SetJustifyH("RIGHT")

    local initializing = true
    slider:SetScript("OnValueChanged", function(_, newValue)
        local fraction = (newValue - minValue) / (maxValue - minValue)
        fill:SetWidth(math.max(1, 8 + fraction * (slider:GetWidth() - 16)))
        label:SetText(math.floor(newValue + 0.5))
        if not initializing then onChange(newValue) end
    end)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta)
    end)
    slider:SetValue(get())
    initializing = false

    updaters[#updaters + 1] = function()
        initializing = true
        slider:SetValue(get())
        initializing = false
    end
    return holder
end

-- Rounded button. style: nil (dark outline) or "primary" (filled).
local BUTTON_STYLES = {
    primary = { C.accent, C.accentHover, C.white },
}

local function CreateButton(parent, label, width, style)
    local filled = BUTTON_STYLES[style]
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 32)

    local bg = Rounded(button, "BACKGROUND", filled and filled[1] or C.control)
    local border = Rounded(button, "BORDER", filled and filled[1] or C.controlBorder, "rounded-border")
    local text = Text(button, 13, filled and filled[3] or C.text)
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:SetText(label)
    if filled then text:SetShadowOffset(0, 0) end

    local hovered = false
    local function paint()
        if not button:IsEnabled() then
            SetColor(bg, C.control)
            SetColor(border, C.cardBorder)
            text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        elseif filled then
            SetColor(bg, hovered and filled[2] or filled[1])
            SetColor(border, hovered and filled[2] or filled[1])
            text:SetTextColor(filled[3][1], filled[3][2], filled[3][3])
        else
            SetColor(bg, hovered and C.controlHover or C.control)
            SetColor(border, C.controlBorder)
            text:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    button:SetScript("OnEnable", paint)
    button:SetScript("OnDisable", paint)
    button:HookScript("OnEnter", function() hovered = true; paint() end)
    button:HookScript("OnLeave", function() hovered = false; paint() end)
    button:SetMotionScriptsWhileDisabled(true)
    paint()
    return button
end

-- Small rounded label, e.g. the version number.
local function CreateBadge(parent, color, background)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetHeight(20)
    Rounded(badge, "BACKGROUND", background)
    badge.text = Text(badge, 11, color)
    badge.text:SetPoint("CENTER")
    badge.text:SetShadowOffset(0, 0)
    function badge:SetText(text)
        self.text:SetText(text)
        self:SetWidth(self.text:GetStringWidth() + 18)
    end
    return badge
end

------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------

-- A rounded card with an uppercase title and an accent bar. Rows are added
-- with AddRow; LayoutCard stacks them and sizes the card.
local function CreateCard(parent, title)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(CARD_WIDTH)
    Rounded(card, "BACKGROUND", C.card)
    Rounded(card, "BORDER", C.cardBorder, "rounded-border")

    local bar = card:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    bar:SetSize(3, 14)
    bar:SetPoint("TOPLEFT", 20, -22)

    local label = Text(card, 13, C.text)
    label:SetPoint("LEFT", bar, "RIGHT", 10, 0)
    label:SetText(title:upper())

    card.rows = {}
    return card
end

-- A row with a title, a description and a control on the right.
-- makeControl(card) creates the control. Returns the description text, so
-- callers can change it.
local function AddRow(card, title, description, makeControl)
    local control = makeControl and makeControl(card)
    local titleText = Text(card, 14, C.text)
    titleText:SetText(title)
    local descText = Text(card, 12, C.muted)
    descText:SetText(description)
    descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    card.rows[#card.rows + 1] = { title = titleText, desc = descText, control = control }
    return descText
end

local function LayoutCard(card)
    local y = -56
    for _, row in ipairs(card.rows) do
        local control = row.control
        local textWidth = CARD_WIDTH - 40 - (control and control:GetWidth() + 24 or 0)
        row.title:SetWidth(textWidth)
        row.desc:SetWidth(textWidth)
        local textHeight = row.title:GetStringHeight() + 4 + row.desc:GetStringHeight()
        local rowHeight = math.max(textHeight, control and control:GetHeight() or 0)
        row.title:ClearAllPoints()
        row.title:SetPoint("TOPLEFT", 20, y - (rowHeight - textHeight) / 2)
        if control then
            control:ClearAllPoints()
            control:SetPoint("RIGHT", card, "TOPRIGHT", -20, y - rowHeight / 2)
        end
        y = y - rowHeight - 20
    end
    card:SetHeight(-y)
end

------------------------------------------------------------------------
-- Content
------------------------------------------------------------------------

local function CreateSettingsCard(parent)
    local card = CreateCard(parent, L["Settings"])
    AddRow(card, L["Maximum soul shards"],
        L["Each press of the hotkey deletes a shard until you're down to this many. Shards in a soul bag "
            .. "count too, but are never deleted."],
        function(p)
            return CreateSlider(p, 0, ns.MAX_LIMIT, function() return ns.db.maxShards end, ns.SetMaxShards, 140)
        end)
    AddRow(card, L["Chat message"], L["Say in chat each time a shard is deleted, and how many are left."],
        function(p)
            return CreateToggle(p, function() return ns.db.announce end, ns.SetAnnounce)
        end)
    AddRow(card, L["Minimap button"],
        L["Show a Soul Warden button on the minimap. Click it to open this window, drag it to move it."],
        function(p)
            return CreateToggle(p, function() return ns.db.minimapButton end, ns.SetMinimapButton)
        end)
    LayoutCard(card)
    return card
end

local function BindingText()
    local key = GetBindingKey("SOULWARDEN_DELETE")
    if key then
        return L["Your key: %s"]:format("|cffffffff" .. GetBindingText(key) .. "|r")
    end
    return L["No key set yet."]
end

local function CreateHotkeyCard(parent)
    local card = CreateCard(parent, L["Hotkey and macro"])
    local hotkeyText = AddRow(card, L["Hotkey"], "",
        function(p)
            local button = CreateButton(p, L["Key Bindings"], 130)
            button:SetScript("OnClick", function()
                window:Hide() -- would cover the game's settings
                ns.OpenKeyBindings()
            end)
            return button
        end)
    AddRow(card, L["Macro"],
        L["Each click of a macro with /soulwarden delete deletes one shard. Create one and drop it on an action bar."],
        function(p)
            local button = CreateButton(p, L["Create macro"], 130, "primary")
            button:SetScript("OnClick", ns.CreateMacro)
            return button
        end)

    local function updateHotkey()
        hotkeyText:SetText(L["Each press deletes one shard. Set it in the game's Key Bindings, under Soul Warden. "]
            .. BindingText())
    end
    updateHotkey()
    LayoutCard(card)
    updaters[#updaters + 1] = function()
        updateHotkey()
        LayoutCard(card)
    end
    return card
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    ns.db.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function CreateHeader()
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        SavePosition()
    end)

    local logo = Icon(header, "emblem", 48, C.white)
    logo:SetPoint("LEFT", 16, 0)

    local title = Text(header, 26, C.text)
    title:SetPoint("BOTTOMLEFT", logo, "RIGHT", 14, 0)
    title:SetText("|cff9e75edSoul|r Warden")

    local version = CreateBadge(header, C.accent, { C.accent[1], C.accent[2], C.accent[3], 0.16 })
    version:SetPoint("LEFT", title, "RIGHT", 12, 0)
    version:SetText(ns.VERSION == "dev" and "dev" or ("v" .. (ns.VERSION or "?")))

    local subtitle = Text(header, 13, C.muted)
    subtitle:SetPoint("TOPLEFT", logo, "RIGHT", 14, -4)
    subtitle:SetText(L["Keeps your soul shards in check"])

    local close = CreateFrame("Button", nil, header)
    close:SetSize(32, 32)
    close:SetPoint("RIGHT", -18, 0)
    local closeIcon = Icon(close, "icon-close", 18, C.muted)
    closeIcon:SetPoint("CENTER")
    close:SetScript("OnEnter", function() SetColor(closeIcon, C.text) end)
    close:SetScript("OnLeave", function() SetColor(closeIcon, C.muted) end)
    close:SetScript("OnClick", function() window:Hide() end)

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.55)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 1, 0)
    line:SetPoint("BOTTOMRIGHT", -1, 0)
end

-- Stacks the cards under the header and sizes the window to fit them.
local function LayoutWindow(cards)
    local y = -HEADER_HEIGHT - 20
    for _, card in ipairs(cards) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 20, y)
        y = y - card:GetHeight() - 16
    end
    window:SetHeight(-y + 4)
end

local function CreateWindow()
    window = CreateFrame("Frame", "SoulWardenFrame", UIParent, "BackdropTemplate")
    window:SetWidth(WIDTH)
    local saved = ns.db.window
    if saved and saved.point then
        window:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        window:SetPoint("CENTER")
    end
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    if window.SetDontSavePosition then window:SetDontSavePosition(true) end -- saved by us instead
    window:EnableMouse(true)
    window:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    window:SetBackdropColor(unpack(C.bg))
    window:SetBackdropBorderColor(unpack(C.windowBorder))
    window:Hide()

    -- Escape closes only this window, not the game options behind it.
    -- Keyboard propagation can't be changed in combat, so Escape is
    -- ignored then.
    window:EnableKeyboard(true)
    window:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
            C_Timer.After(0, function()
                if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
            end)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    CreateHeader()
    local cards = { CreateSettingsCard(window), CreateHotkeyCard(window) }
    LayoutWindow(cards)

    window:SetScript("OnShow", function(self)
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        self:RegisterEvent("UPDATE_BINDINGS")
        ns.RefreshWindow()
        LayoutWindow(cards)
    end)
    window:SetScript("OnHide", function(self)
        self:UnregisterEvent("UPDATE_BINDINGS")
    end)
    window:SetScript("OnEvent", function()
        ns.RefreshWindow()
        LayoutWindow(cards)
    end)
end

function ns.RefreshWindow()
    if not (window and window:IsShown()) then return end
    for _, update in ipairs(updaters) do update() end
end

-- show: true/false, or nil to toggle.
function ns.ToggleWindow(show)
    if not ns.db then return end
    if not window then CreateWindow() end
    if show == nil then show = not window:IsShown() end
    window:SetShown(show)
end

------------------------------------------------------------------------
-- Entry points: AddOns options panel and the minimap addon compartment
------------------------------------------------------------------------

if Settings and Settings.RegisterCanvasLayoutCategory then
    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Soul Warden")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(L["Settings are in the Soul Warden window (/soulwarden)."])

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    open:SetText(L["Open Soul Warden"])
    open:SetScript("OnClick", function() ns.ToggleWindow(true) end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Soul Warden")
    Settings.RegisterAddOnCategory(category)
end

function SoulWarden_OnAddonCompartmentClick()
    ns.ToggleWindow()
end
