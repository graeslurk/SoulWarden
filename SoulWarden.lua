-- Soul Warden: keeps a warlock's soul shards at a limit you choose. Each
-- press of the hotkey (or click of the macro) deletes one soul shard from
-- your normal bags until you're down to the limit. Shards in a soul bag are
-- counted but never deleted.

local ADDON_NAME, ns = ...
local L = ns.L

local PREFIX = "|cff9e75edSoul Warden|r: "
local SOUL_SHARD = 6265
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local MACRO_NAME = "Soul Warden"
local MACRO_ICON = "INV_Misc_Gem_Amethyst_02"
local MACRO_BODY = "/soulwarden delete"

local DEFAULTS = {
    maxShards = 10,
    announce = true, -- chat message for each deleted shard
    minimapButton = true,
    minimapAngle = 225, -- degrees around the minimap, 0 = right, 90 = top
}

local db -- SoulWardenDB

ns.SOUL_SHARD = SOUL_SHARD
ns.MAX_LIMIT = 40

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version")
if not ns.VERSION or ns.VERSION:find("^@") then
    ns.VERSION = "dev" -- running from source; the CurseForge packager fills in the real version
else
    ns.VERSION = ns.VERSION:gsub("^v", "") -- the packager uses the tag name, e.g. "v1.0.0"
end

local function Print(msg, ...)
    print(PREFIX .. (select("#", ...) > 0 and msg:format(...) or msg))
end
ns.Print = Print

-- Red text in the middle of the screen, like the game's own "can't do
-- that" messages. Used when a press does nothing, so spamming the key
-- doesn't fill the chat.
local function ShowError(msg, ...)
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(msg:format(...), 1, 0.1, 0.1, 1)
    else
        Print(msg, ...)
    end
end

------------------------------------------------------------------------
-- Counting
------------------------------------------------------------------------

-- Normal bags have no bag family. Soul bags (and other special bags) do.
local function IsNormalBag(bag)
    if bag == 0 then return true end
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    return family == 0
end

-- Returns the shards in normal bags and the shards in soul bags.
function ns.CountShards()
    local normal, soulBag = 0, 0
    for bag = 0, LAST_BAG do
        local isNormal = IsNormalBag(bag)
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == SOUL_SHARD then
                local count = info.stackCount or 1
                if isNormal then normal = normal + count else soulBag = soulBag + count end
            end
        end
    end
    return normal, soulBag
end

-- The last unlocked shard in your normal bags: bag, slot.
local function FindDeletableShard()
    for bag = LAST_BAG, 0, -1 do
        if IsNormalBag(bag) then
            for slot = C_Container.GetContainerNumSlots(bag), 1, -1 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == SOUL_SHARD and not info.isLocked then
                    return bag, slot
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Deleting
------------------------------------------------------------------------

-- Deletes one shard from your normal bags if you carry more than your
-- limit. Must run from a key press or click: the game only lets addons
-- delete items during one.
function ns.DeleteShard()
    if not db then return end
    if CursorHasItem() then
        ShowError(L["Put down the item on your cursor first."])
        return
    end

    local normal, soulBag = ns.CountShards()
    local total = normal + soulBag
    if total <= db.maxShards then
        return -- nothing to delete; stay quiet so spamming the key is harmless
    end
    if normal == 0 then
        ShowError(L["The shards over your limit are in your soul bag. Soul Warden leaves those alone."])
        return
    end

    local bag, slot = FindDeletableShard()
    if not bag then
        ShowError(L["Your soul shards are busy. Try again in a moment."])
        return
    end

    C_Container.PickupContainerItem(bag, slot)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or itemID ~= SOUL_SHARD then
        ClearCursor()
        return
    end
    DeleteCursorItem()

    if db.announce then
        Print(L["Deleted a soul shard. %d left, your limit is %d."], total - 1, db.maxShards)
    end
end

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

function ns.SetMaxShards(value)
    db.maxShards = math.max(0, math.min(ns.MAX_LIMIT, math.floor(value + 0.5)))
    if ns.RefreshWindow then ns.RefreshWindow() end
    if ns.RefreshMinimapButton then ns.RefreshMinimapButton() end
end

function ns.SetAnnounce(value)
    db.announce = value and true or false
end

-- Makes a "Soul Warden" macro that deletes a shard, and puts it on the
-- cursor to drop on an action bar. An existing one gets its text updated,
-- so macros made by older versions keep working.
function ns.CreateMacro()
    if InCombatLockdown() then
        Print(L["You can't make macros in combat."])
        return
    end
    local index = GetMacroIndexByName(MACRO_NAME)
    if index == 0 then
        local ok, created = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, MACRO_BODY)
        if not ok or not created or created == 0 then
            Print(L["Couldn't make the macro, your general macros may be full. Make one yourself with: /soulwarden delete"])
            return
        end
        index = created
    elseif select(3, GetMacroInfo(index)) ~= MACRO_BODY then
        index = EditMacro(index, nil, nil, MACRO_BODY) or index -- keeps its name and icon
    end
    PickupMacro(index)
    Print(L["The Soul Warden macro is on your cursor. Drop it on an action bar."])
end

-- Opens the game's Key Bindings, where Soul Warden has its own section.
function ns.OpenKeyBindings()
    if InCombatLockdown() then
        Print(L["You can't change key bindings in combat."])
        return
    end
    if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
    else
        Print(L["Open the game menu, then Key Bindings, and look for the Soul Warden section."])
    end
end

------------------------------------------------------------------------
-- Key bindings (Bindings.xml) and slash commands
------------------------------------------------------------------------

BINDING_NAME_SOULWARDEN_DELETE = L["Delete a soul shard over the limit"]
BINDING_NAME_SOULWARDEN_TOGGLE = L["Open Soul Warden"]

function SoulWarden_DeleteShard() ns.DeleteShard() end
function SoulWarden_ToggleWindow() ns.ToggleWindow() end

local function ShowHelp()
    Print(L["Commands:"])
    print(L["  /soulwarden - open the Soul Warden window"])
    print(L["  /soulwarden delete - delete one soul shard over your limit (use it in a macro)"])
    print(L["  /soulwarden max <number> - set the most soul shards to carry"])
    print(L["  /soulwarden chat - turn the message for each deleted shard on or off"])
    print(L["  /soulwarden minimap - show or hide the minimap button"])
end

SLASH_SOULWARDEN1 = "/soulwarden"
SlashCmdList.SOULWARDEN = function(msg)
    local command, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" then
        ns.ToggleWindow()
    elseif command == "delete" then
        ns.DeleteShard()
    elseif command == "max" then
        local value = tonumber(rest)
        if value and value >= 0 then
            ns.SetMaxShards(value)
            Print(L["You'll keep at most %d soul shards."], db.maxShards)
        else
            Print(L["Your limit is %d soul shards. Change it with /soulwarden max <number>."], db.maxShards)
        end
    elseif command == "chat" then
        ns.SetAnnounce(not db.announce)
        if ns.RefreshWindow then ns.RefreshWindow() end
        Print(db.announce and L["Chat message for deleted shards: on"] or L["Chat message for deleted shards: off"])
    elseif command == "minimap" then
        ns.SetMinimapButton(not db.minimapButton)
        if ns.RefreshWindow then ns.RefreshWindow() end
        Print(db.minimapButton and L["Minimap button: on"] or L["Minimap button: off"])
    else
        ShowHelp()
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SoulWardenDB = SoulWardenDB or {}
        db = SoulWardenDB
        for key, value in pairs(DEFAULTS) do
            if db[key] == nil then db[key] = value end
        end
        ns.db = db
    end
end)
