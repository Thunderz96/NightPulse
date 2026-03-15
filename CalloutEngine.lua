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
-- Encounter IDs for unknown bosses can be found in-game during a fight:
--   /run print(select(7, EJ_GetEncounterInfo(EJ_GetCurrentEncounter())))
-- Bosses without confirmed IDs are commented out below — fill in and uncomment when found.
local ENCOUNTER_ABILITIES = {

    -- =========================================================
    -- NEXUS-POINT XENAS (Midnight new dungeon)
    -- =========================================================
    [2801] = {  -- Chief Corewright Kasreth
        { name="Reflux Charge",        castTimeSec=3.0, intervalSec=45, priority="high",
          tip="Run through Leyline Arrays to destroy them — use a defensive." },
        { name="Corespark Detonation",  castTimeSec=2.5, intervalSec=35, priority="high",
          tip="Massive knockback circle — outrange or pre-position away from center." },
        { name="Leyline Array",         castTimeSec=nil, intervalSec=nil, priority="high",
          tip="LETHAL — do not touch unless targeted by Reflux Charge." },
    },
    -- Corewarden Nysarra  (ID unknown — uncomment when confirmed)
    -- [????] = {
    --     { name="Lightscar Flare", castTimeSec=5.0, intervalSec=60, priority="high",
    --       tip="Dodge initial hit, then step INTO beam for 300% damage/healing buff." },
    --     { name="Nullify",         castTimeSec=2.0, intervalSec=20, priority="high",
    --       tip="INTERRUPT Grand Nullifier add — prevents group-wide silence." },
    -- },
    -- Lothraxion  (ID unknown — uncomment when confirmed)
    -- [????] = {
    --     { name="Divine Guile",         castTimeSec=6.0, intervalSec=50, priority="high",
    --       tip="Intermission — interrupt clone WITH horns. Hunter's Mark reveals real boss." },
    --     { name="Searing Rend",         castTimeSec=2.5, intervalSec=18, priority="high",
    --       tip="Frontal cleave — avoid the path even as ranged." },
    --     { name="Brilliant Dispersion", castTimeSec=3.0, intervalSec=32, priority="medium",
    --       tip="Dodge Fractured Images. 12.0.1: reaction delay added before images spawn." },
    -- },

    -- =========================================================
    -- ALGETH'AR ACADEMY (Dragonflight)
    -- =========================================================
    [2562] = {  -- Vexamus
        { name="Arcane Orbs", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Soak orbs before boss hits 100 energy — cycle personal defensives." },
    },
    [2563] = {  -- Overgrown Ancient
        { name="Germinate", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Stack tight on tank so Hungry Lashers spawn grouped for AoE burst." },
    },
    [2564] = {  -- Crawth
        { name="Deafening Screech", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Heavy AoE + silence — stop spellcasts and use 40%+ defensive." },
    },
    [2565] = {  -- Echo of Doragosa
        { name="Overwhelming Power", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Move to room edge at 2 stacks to drop Arcane Rift safely." },
    },

    -- =========================================================
    -- PIT OF SARON (Wrath of the Lich King)
    -- =========================================================
    [2150] = {  -- Forgemaster Garfrost
        { name="Glacial Overload", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Break LoS behind Saronite Ores immediately." },
    },
    [2001] = {  -- Ick and Krick
        { name="Death Bolt",  castTimeSec=2.0, intervalSec=nil, priority="high",
          tip="INTERRUPT — strict kick requirement." },
        { name="Toxic Waste", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Run immediately when fixated; dodge all green puddles." },
    },
    [837] = {   -- Scourgelord Tyrannus
        { name="Scourgelord's Reckoning", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Lethal player-targeted jump. 12.0.1: reaction window increased 25%." },
    },

    -- =========================================================
    -- SEAT OF THE TRIUMVIRATE (Legion)
    -- =========================================================
    [1912] = {  -- Zuraal the Ascended
        { name="Coalesced Void", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Slow/CC the add before it reaches the boss." },
    },
    [1913] = {  -- Saprish
        { name="Void Bomb",    castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Stack with group to handle bombs. 12.0.1: bombs spawn closer to targets." },
        { name="Dread Screech", castTimeSec=2.0, intervalSec=nil, priority="high",
          tip="INTERRUPT Shadewing add — lethal if missed." },
    },
    [1914] = {  -- Viceroy Nezhar
        { name="Collapsing Void", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Watch boss energy — pre-position for the massive knockback." },
        { name="Mind Flay",       castTimeSec=2.0, intervalSec=nil, priority="medium",
          tip="Interrupt your assigned cast. 12.0.1: multi-target bug fixed." },
    },
    [1915] = {  -- L'ura
        { name="Siphon Void", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Boss takes massive increased damage here — align all offensive CDs." },
    },

    -- =========================================================
    -- SKYREACH (Warlords of Draenor)
    -- =========================================================
    [1698] = {  -- Ranjit
        { name="Fan of Blades", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Use defensives for the bleed — don't stand on platform edge." },
    },
    [1699] = {  -- Araknath
        { name="Light Ray", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Rotate soak duties on the beam — use a defensive. 12.0.1: dmg -11%." },
    },
    [1700] = {  -- Rukhran
        { name="Sunwings", castTimeSec=nil, intervalSec=nil, priority="medium",
          tip="Stay close to boss to bait Sunwing spawns for easier group cleave." },
    },
    [1701] = {  -- High Sage Viryx
        { name="Scorching Ray", castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Use a strong defensive when targeted." },
        { name="Cast Down",     castTimeSec=nil, intervalSec=nil, priority="high",
          tip="Kill Solar Zealot before the drop — use Disengage/Blink if dropped." },
    },

    -- =========================================================
    -- MAGISTERS' TERRACE (Midnight remake) — all IDs unknown
    -- =========================================================
    -- [????] = {  -- Arcanotron Custos
    --     { name="Refueling Protocol", castTimeSec=16.0, intervalSec=50, priority="high",
    --       tip="Collect energy orbs to prevent boss reaching 100% damage stacks." },
    --     { name="Arcane Expulsion",   castTimeSec=2.5,  intervalSec=18, priority="high",
    --       tip="Targeted burst — stand still and use a personal defensive." },
    --     { name="Repulsing Slam",     castTimeSec=2.0,  intervalSec=25, priority="medium",
    --       tip="Tank knockback — avoid standing directly behind the tank." },
    -- },
    -- [????] = {  -- Seranel Sunlash
    --     { name="Wave of Silence", castTimeSec=2.0, intervalSec=45, priority="high",
    --       tip="Step into a Suppression Zone (black circles) to avoid 10s silence." },
    --     { name="Runic Mark",      castTimeSec=3.0, intervalSec=30, priority="high",
    --       tip="Clear DoT by entering a Suppression Zone — not if an ally is inside." },
    --     { name="Null Reaction",   castTimeSec=nil, intervalSec=22, priority="medium",
    --       tip="Reactive damage. 12.0.1: dmg reduced 16%." },
    -- },
    -- [????] = {  -- Gemellus
    --     { name="Neural Link",  castTimeSec=3.0, intervalSec=35, priority="high",
    --       tip="Move toward linked boss copy to reduce damage. 12.0.1: visuals improved." },
    --     { name="Cosmic Sting", castTimeSec=4.0, intervalSec=28, priority="high",
    --       tip="Creates ground puddles — Hunters Feign Death to cancel if targeted." },
    --     { name="Astral Grasp", castTimeSec=2.5, intervalSec=20, priority="medium",
    --       tip="High shadow burst. 12.0.1: cast frequency reduced." },
    -- },
    -- [????] = {  -- Degentrius
    --     { name="Unstable Void", castTimeSec=nil, intervalSec=40, priority="high",
    --       tip="Assign quadrants — soak orbs in your area to prevent lethal explosion." },
    --     { name="Void Totems",   castTimeSec=nil, intervalSec=15, priority="high",
    --       tip="Kill totems immediately — each adds 10% shadow damage taken." },
    -- },

    -- =========================================================
    -- MAISARA CAVERNS (Midnight new dungeon) — all IDs unknown
    -- =========================================================
    -- [????] = {  -- Muro'jin and Nekraxx
    --     { name="Carrion Swoop",    castTimeSec=1.5, intervalSec=22, priority="high",
    --       tip="Step into a Freezing Trap to stun the boss and avoid lethal damage." },
    --     { name="Infected Pinions", castTimeSec=2.5, intervalSec=30, priority="high",
    --       tip="Group disease — use personal defensives or disease dispels immediately." },
    --     { name="Barrage",          castTimeSec=4.0, intervalSec=40, priority="medium",
    --       tip="Tracking frontal — stand still if targeted so allies can dodge the path." },
    -- },
    -- [????] = {  -- Vordaza
    --     { name="Necrotic Convergence", castTimeSec=60.0, intervalSec=nil, priority="high",
    --       tip="Boss gains a massive shield — burn absorb to stop ramping group damage." },
    --     { name="Wrest Phantoms",       castTimeSec=nil,  intervalSec=25, priority="high",
    --       tip="Kite your phantom into another player's phantom to destroy them both." },
    --     { name="Unmake",               castTimeSec=2.0,  intervalSec=20, priority="high",
    --       tip="Wide frontal — stay within 30 yards; harder to dodge at max range." },
    -- },
    -- [????] = {  -- Rak'tul, Vessel of Souls
    --     { name="Soulrending Roar", castTimeSec=8.0, intervalSec=nil, priority="high",
    --       tip="Interrupt/CC the Malignant Soul add for a massive group damage buff." },
    --     { name="Crush Souls",      castTimeSec=3.0, intervalSec=40,  priority="high",
    --       tip="Leaps and plants Soulbind Totems — stack near tank to group totems." },
    --     { name="Soulbind Totem",   castTimeSec=nil, intervalSec=nil, priority="medium",
    --       tip="Applies gravity pull — run against it or use a movement ability." },
    -- },

    -- =========================================================
    -- WINDRUNNER SPIRE (Midnight new dungeon) — all IDs unknown
    -- =========================================================
    -- [????] = {  -- Emberdawn
    --     { name="Burning Gale",    castTimeSec=16.0, intervalSec=nil, priority="high",
    --       tip="Stay close to boss — reduces distance to dodge rotating fire frontals." },
    --     { name="Flaming Updraft", castTimeSec=3.0,  intervalSec=28,  priority="high",
    --       tip="Position near a wall before debuff expires to safely drop fire puddle." },
    -- },
    -- [????] = {  -- Derelict Duo (Kalis and Latch)
    --     { name="Debilitating Shriek", castTimeSec=6.0, intervalSec=nil, priority="high",
    --       tip="Uninterruptible — bait Latch's Heaving Yank into Kalis to stop it." },
    --     { name="Shadow Bolt",         castTimeSec=2.0, intervalSec=12,  priority="high",
    --       tip="Maintain strict interrupt rotation — unkicked casts deal massive damage." },
    -- },
    -- [????] = {  -- Commander Kroluk
    --     { name="Intimidating Shout", castTimeSec=2.0, intervalSec=30,  priority="high",
    --       tip="Stack within 5 yards of an ally when cast finishes — or get feared." },
    --     { name="Reckless Leap",      castTimeSec=1.5, intervalSec=22,  priority="high",
    --       tip="Targets farthest player — bait to room edge and use a defensive." },
    --     { name="Rallying Bellow",    castTimeSec=4.0, intervalSec=nil, priority="medium",
    --       tip="Boss immune + add phase at 66%/33% HP. 12.0.1: dmg -12.5%." },
    --     { name="Bladestorm",         castTimeSec=nil, intervalSec=45,  priority="medium",
    --       tip="Fixate mechanic. 12.0.1: movement penalty for targets reduced." },
    -- },
    -- [????] = {  -- The Restless Heart
    --     { name="Arrow Rain",         castTimeSec=5.0, intervalSec=65, priority="high",
    --       tip="Turbulent Arrows clear your lethal Squall Leap DoT stacks." },
    --     { name="Bolt Gale",          castTimeSec=2.5, intervalSec=30, priority="high",
    --       tip="Random targeted frontal. 12.0.1: width increased 25%." },
    --     { name="Bullseye Windblast", castTimeSec=3.0, intervalSec=45, priority="high",
    --       tip="Expanding stun rings — bounce over with a Turbulent Arrow." },
    -- },
}

-- Display names for each encounterID — used by the config UI
local BOSS_NAMES = {
    [2801] = "Chief Corewright Kasreth (Nexus-Point Xenas)",
    [2562] = "Vexamus (Algeth'ar Academy)",
    [2563] = "Overgrown Ancient (Algeth'ar Academy)",
    [2564] = "Crawth (Algeth'ar Academy)",
    [2565] = "Echo of Doragosa (Algeth'ar Academy)",
    [2150] = "Forgemaster Garfrost (Pit of Saron)",
    [2001] = "Ick and Krick (Pit of Saron)",
    [837]  = "Scourgelord Tyrannus (Pit of Saron)",
    [1912] = "Zuraal the Ascended (Seat of the Triumvirate)",
    [1913] = "Saprish (Seat of the Triumvirate)",
    [1914] = "Viceroy Nezhar (Seat of the Triumvirate)",
    [1915] = "L'ura (Seat of the Triumvirate)",
    [1698] = "Ranjit (Skyreach)",
    [1699] = "Araknath (Skyreach)",
    [1700] = "Rukhran (Skyreach)",
    [1701] = "High Sage Viryx (Skyreach)",
}

local PRIORITY_RANK  = { high=3, medium=2, low=1 }
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

-- ---- Filter helpers ----
function CE:GetAbilityKey(encounterID, abilityName)
    return tostring(encounterID) .. ":" .. abilityName
end

function CE:IsAbilityMuted(encounterID, abilityName)
    local muted = NightPulse:GetSetting("callouts", "mutedAbilities") or {}
    return muted[CE:GetAbilityKey(encounterID, abilityName)] == true
end

function CE:IsPriorityAllowed(priority)
    local min = NightPulse:GetSetting("callouts", "minPriority") or "medium"
    return (PRIORITY_RANK[priority] or 1) >= (PRIORITY_RANK[min] or 2)
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
                if CE:IsPriorityAllowed(ab.priority) and not CE:IsAbilityMuted(encounterID, ab.name) then
                    FireAlert(ab.name, ab.priority, ab.tip, "|cff888888[~3s]|r")
                end
                local ticker = C_Timer.NewTicker(ab.intervalSec, function()
                    if activeEncounterID ~= encounterID then return end
                    if CE:IsPriorityAllowed(ab.priority) and not CE:IsAbilityMuted(encounterID, ab.name) then
                        FireAlert(ab.name, ab.priority, ab.tip, "|cff888888[~3s]|r")
                    end
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
    local displayName = name or (unit.." cast")
    -- endMs/startMs are secret number values in Midnight — arithmetic is tainted.
    -- Wrap in pcall; if it fails we omit the duration display.
    local durationSec = nil
    if endMs and startMs then
        local ok2, result = pcall(function()
            return string.format("%.1f", (endMs - startMs) / 1000)
        end)
        if ok2 then durationSec = result end
    end
    -- notInterruptible is also a secret boolean in Midnight — wrap in pcall.
    local kickTag = ""
    local ok3, kresult = pcall(function()
        return (not notInterruptible) and " |cff00ff00[KICK?]|r" or ""
    end)
    if ok3 then kickTag = kresult end
    local durationTag = durationSec and (" ("..durationSec.."s)") or ""
    -- Apply priority and per-ability mute filters
    if not CE:IsPriorityAllowed("medium") then return end
    if activeEncounterID and CE:IsAbilityMuted(activeEncounterID, displayName) then return end
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

CE.encounters  = ENCOUNTER_ABILITIES
CE.bossNames   = BOSS_NAMES

NightPulse.CalloutEngine = CE
