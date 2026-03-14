-- ============================================================
-- NightPulse Core.lua
-- ============================================================

NightPulse = {}

local DEFAULTS = {
    callouts = {
        enabled     = true,
        flashScreen = true,
        playSound   = true,
        spellList   = {},
    },
    affixTracker = {
        enabled     = true,
        showOnLogin = true,
        warnSeconds = 5,
    },
    progressionLog = {
        enabled    = true,
        maxEntries = 200,
        runs       = {},
    },
    ui = {
        locked       = false,
        scale        = 1.0,
        minimapAngle = 225,
        point        = { "CENTER", "UIParent", "CENTER", 0, 0 },
    },
}

local eventHandlers = {}
local coreFrame = CreateFrame("Frame", "NightPulseCoreFrame", UIParent)

coreFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = eventHandlers[event]
    if not handlers then return end
    for _, fn in ipairs(handlers) do
        local ok, err = pcall(fn, event, ...)
        if not ok then
            NightPulse:Print("|cffff4444[Error] " .. tostring(err) .. "|r")
        end
    end
end)

function NightPulse:RegisterEvent(event, fn)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        coreFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], fn)
end

function NightPulse:UnregisterEvent(event)
    eventHandlers[event] = nil
    coreFrame:UnregisterEvent(event)
end

function NightPulse:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9f7fffNightPulse|r " .. tostring(msg))
end

function NightPulse:GetSetting(module, key)
    if self.db and self.db[module] then return self.db[module][key] end
    if DEFAULTS[module] then return DEFAULTS[module][key] end
    return nil
end

function NightPulse:SetSetting(module, key, value)
    if self.db and self.db[module] then self.db[module][key] = value end
end

local function mergeMissing(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then dst[k] = {}; mergeMissing(dst[k], v)
            else dst[k] = v end
        elseif type(dst[k]) == "table" and type(v) == "table" then
            mergeMissing(dst[k], v)
        end
    end
end

NightPulse:RegisterEvent("ADDON_LOADED", function(event, addonName)
    if addonName ~= "NightPulse" then return end
    if NightPulseDB == nil then NightPulseDB = {} end
    mergeMissing(NightPulseDB, DEFAULTS)
    NightPulse.db = NightPulseDB
    NightPulse:Print("v2.0 loaded (Midnight 12.0.1). Type |cffffd700/np|r or click the minimap button.")
end)

-- Fallback init + minimap button built here (world is ready at PLAYER_LOGIN)
NightPulse:RegisterEvent("PLAYER_LOGIN", function()
    if not NightPulse.db then
        if NightPulseDB == nil then NightPulseDB = {} end
        mergeMissing(NightPulseDB, DEFAULTS)
        NightPulse.db = NightPulseDB
    end
    -- Build the minimap button now that Minimap frame exists
    if NightPulse.Minimap then NightPulse.Minimap:Init() end
end)

SLASH_NIGHTPULSE1 = "/np"
SLASH_NIGHTPULSE2 = "/nightpulse"
SlashCmdList["NIGHTPULSE"] = function(msg)
    if NightPulse.ToggleMainWindow then NightPulse:ToggleMainWindow()
    else NightPulse:Print("UI not ready yet.") end
end
