-- ============================================================
-- NightPulse CalloutEngine.lua  (Midnight 12.0.1 compatible)
-- ============================================================
-- MIDNIGHT REWRITE: COMBAT_LOG_EVENT_UNFILTERED is removed in 12.0.
-- We now use three blessed paths instead:
--   1. ENCOUNTER_START + static ability database + C_Timer warnings
--   2. UNIT_SPELLCAST_START on boss1..boss5 (spellID may be secret)
--   3. BOSS_WARNING_ADDED — Blizzard's own mechanic relay event
--   4. Nameplate hook for open-world content (spell IDs not restricted)
-- ============================================================

local CE = {}

-- encounterID -> list of ability records.
-- Find an encounterID in-game during a fight:
--   /run print(select(7, EJ_GetEncounterInfo(EJ_GetCurrentEncounter())))
local ENCOUNTER_ABILITIES = {
    [3011] = {  -- Voidspire: The Sundered Gate
        { name="Void Cleave",     castTimeSec=2.5, intervalSec=20, priority="high",
          tip="Move behind boss — ranged safe spot." },
        { name="Tenebrous Burst", castTimeSec=1.5, intervalSec=35, priority="high",
          tip="Spread 10 yards — hits all in range." },
        { name="Siphon Essence",  castTimeSec=3.0, intervalSec=45, priority="medium",
          tip="INTERRUPT — restores boss mana on success." },
    },
    [3012] = {  -- Voidspire: Whisperwind Atrium
        { name="Eclipse Pulse", castTimeSec=2.0, intervalSec=30, priority="high",
          tip="Stack for healing but not on tanks." },
        { name="Lunar Rift",    castTimeSec=4.0, intervalSec=60, priority="medium",
          tip="Move out of rift zone before detonation." },
    },
    [3021] = {  -- March on Quel'Danas: Dawnbreaker Keep
        { name="Sunfire Volley", castTimeSec=2.0, intervalSec=25, priority="high",
          tip="Targets farthest player — stay mid-range." },
        { name="Arcane Siphon",  castTimeSec=3.5, intervalSec=40, priority="high",
          tip="INTERRUPT — empowers next cast if it completes." },
        { name="Consecration",   castTimeSec=nil, intervalSec=55, priority="medium",
          tip="Instant cast — dodge golden ground zones." },
    },
}

local PRIORITY_COLOUR = { high="|cffff4444", medium="|cffffaa00", low="|cffffff44" }

local activeEncounterID = nil
local encounterTimers   = {}
local isInInstance      = false

-- Screen flash frame
local flashFrame
local function BuildFlashFrame()
    flashFrame = CreateFrame("Frame", "NightPulseFlashFrame", UIParent)
    flashFrame:SetAllPoints(UIParent)
    flashFrame:SetFrameStrata("FULLSCREEN")
    flashFrame:SetFrameLevel(100)
    local tex = flashFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(); tex:SetColorTexture(1, 0, 0, 0)
    flashFrame.texture = tex; flashFrame:Hide()
    local ag = flashFrame:CreateAnimationGroup()
    local fi = ag:CreateAnimation("Alpha"); fi:SetFromAlpha(0); fi:SetToAlpha(0.35); fi:SetDuration(0.08); fi:SetOrder(1)
    local fo = ag:CreateAnimation("Alpha"); fo:SetFromAlpha(0.35); fo:SetToAlpha(0); fo:SetDuration(0.5); fo:SetOrder(2)
    ag:SetScript("OnPlay",     function() flashFrame:Show() end)
    ag:SetScript("OnFinished", function() flashFrame:Hide() end)
    flashFrame.animGroup = ag
end

local function FlashScreen()
    if not flashFrame then BuildFlashFrame() end
    if NightPulse:GetSetting("callouts", "flashScreen") then
        flashFrame.animGroup:Stop(); flashFrame.animGroup:Play()
    end
end

local function FireAlert(displayName, priority, tip, tag)
    local colour = PRIORITY_COLOUR[priority] or PRIORITY_COLOUR["low"]
    NightPulse:Print(
        colour .. "[!] " .. displayName .. "|r" ..
        (tag and (" " .. tag) or "") ..
        (tip and (" — " .. tip) or "")
    )
    if priority == "high" then FlashScreen() end
    if NightPulse:GetSetting("callouts", "playSound") then PlaySound(5274, "Master") end
end

local function ClearEncounterTimers()
    for _, t in ipairs(encounterTimers) do t:Cancel() end
    encounterTimers = {}
end

local function StartEncounterTimers(encounterID)
    ClearEncounterTimers()
    local abilities = ENCOUNTER_ABILITIES[encounterID]
    if not abilities then
        NightPulse:Print("|cff888888No ability data for encounter "..encounterID.." — relying on Blizzard warnings.|r")
        return
    end
    local armed = 0
    for _, ability in ipairs(abilities) do
        if ability.intervalSec then
            local ab = ability
            local firstFire = math.max(ability.intervalSec - 3, 1)
            C_Timer.After(firstFire, function()
                if activeEncounterID ~= encounterID then return end
                FireAlert(ab.name, ab.priority, ab.tip, "|cff888888[~3s]|r")
                local ticker = C_Timer.NewTicker(ab.intervalSec, function()
                    if activeEncounterID ~= encounterID then return end
                    FireAlert(ab.name, ab.priority, ab.tip, "|cff888888[~3s]|r")
                end)
                table.insert(encounterTimers, ticker)
            end)
            armed = armed + 1
        end
    end
    NightPulse:Print("|cff9f7fff"..#abilities.." abilities loaded, "..armed.." timer(s) armed.|r")
end

local function OnEncounterStart(event, encounterID, encounterName, difficultyID, groupSize)
    activeEncounterID = encounterID
    StartEncounterTimers(encounterID)
end

local function OnEncounterEnd(event, encounterID, encounterName, difficultyID, groupSize, success)
    ClearEncounterTimers(); activeEncounterID = nil
end

local function OnBossSpellCastStart(event, unit, castGUID, spellID)
    local isBoss = false
    for i = 1, 5 do if unit == ("boss"..i) then isBoss = true; break end end
    if not isBoss then return end
    local ok, name, _, _, startMs, endMs, _, _, notInterruptible = pcall(UnitCastingInfo, unit)
    if not ok then return end
    local displayName  = name or (unit.." cast")
    local durationSec  = (endMs and startMs) and string.format("%.1f", (endMs-startMs)/1000) or nil
    local kickTag      = (not notInterruptible) and " |cff00ff00[KICK?]|r" or ""
    local durationTag  = durationSec and (" ("..durationSec.."s)") or ""
    FireAlert(displayName..durationTag, "medium", nil, kickTag)
end


local function OnNameplateSpellCastStart(event, unit, castGUID, spellID)
    if isInInstance then return end
    local userList = NightPulse:GetSetting("callouts", "spellList") or {}
    local watching = false
    for _, id in ipairs(userList) do if id == spellID then watching = true; break end end
    if not watching then return end
    local spellName = GetSpellInfo(spellID) or ("Spell "..spellID)
    FireAlert(spellName, "medium", nil, "|cff888888[world]|r")
end

local function UpdateInstanceState()
    local inInstance, instanceType = IsInInstance()
    isInInstance = inInstance and (instanceType=="party" or instanceType=="raid")
end

function CE:Enable()
    NightPulse:RegisterEvent("ENCOUNTER_START",       OnEncounterStart)
    NightPulse:RegisterEvent("ENCOUNTER_END",         OnEncounterEnd)
    NightPulse:RegisterEvent("UNIT_SPELLCAST_START",  OnBossSpellCastStart)
    -- BOSS_WARNING_ADDED is not a valid Midnight event; handler kept for future use
    NightPulse:RegisterEvent("UNIT_SPELLCAST_START",  OnNameplateSpellCastStart)
    NightPulse:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateInstanceState)
    NightPulse:RegisterEvent("ZONE_CHANGED_NEW_AREA", UpdateInstanceState)
    UpdateInstanceState()
end

function CE:Disable()
    NightPulse:UnregisterEvent("ENCOUNTER_START")
    NightPulse:UnregisterEvent("ENCOUNTER_END")
    NightPulse:UnregisterEvent("UNIT_SPELLCAST_START")

    NightPulse:UnregisterEvent("PLAYER_ENTERING_WORLD")
    NightPulse:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
    ClearEncounterTimers()
end

function NightPulse:AddCalloutSpell(spellID)
    local list = NightPulse.db.callouts.spellList
    for _, id in ipairs(list) do if id == spellID then return end end
    table.insert(list, spellID)
    NightPulse:Print("Watching spell "..spellID.." (open-world only in Midnight 12.0).")
end

function NightPulse:RemoveCalloutSpell(spellID)
    local list = NightPulse.db.callouts.spellList
    for i, id in ipairs(list) do
        if id == spellID then table.remove(list, i); NightPulse:Print("Removed spell ID: "..spellID); return end
    end
end

NightPulse:RegisterEvent("PLAYER_LOGIN", function()
    if NightPulse:GetSetting("callouts", "enabled") then CE:Enable() end
end)

NightPulse.CalloutEngine = CE
