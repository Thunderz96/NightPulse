-- ============================================================
-- NightPulse AffixTracker.lua
-- ============================================================
local AT = {}

local AFFIX_INFO = {
    [3]  = { name="Volcanic",     dangerous=false, tip="Step off volcanic plumes." },
    [6]  = { name="Raging",       dangerous=true,  tip="Mobs enrage at 30% — use Soothe or CC." },
    [7]  = { name="Bolstering",   dangerous=true,  tip="Kill mobs together — let off-targets die fast." },
    [8]  = { name="Sanguine",     dangerous=true,  tip="Kite mobs out of sanguine pools." },
    [11] = { name="Bursting",     dangerous=true,  tip="Spread out — Bursting stacks hard." },
    [12] = { name="Grievous",     dangerous=false, tip="Top off group between pulls." },
    [13] = { name="Explosive",    dangerous=false, tip="Kill the orbs — high ranged priority." },
    [14] = { name="Quaking",      dangerous=true,  tip="Stop casting 1s before quake — spread from party." },
    [122]= { name="Inspiring",    dangerous=false, tip="Pull inspiring mobs away from each other." },
    [123]= { name="Spiteful",     dangerous=true,  tip="Shade targets a random player — kite it." },
    [124]= { name="Storming",     dangerous=true,  tip="Dodge tornadoes — lethal in melee." },
    [134]= { name="Entangling",   dangerous=false, tip="Moving breaks entangle faster." },
    [135]= { name="Afflicted",    dangerous=false, tip="DPS the Afflicted Soul — fixed 60s timer." },
    [136]= { name="Incorporeal",  dangerous=true,  tip="CC the Incorporeal Being — spawns every 90s." },
}

local TIMED_AFFIXES = {
    [136] = { name="Incorporeal Being", intervalSec=90 },
    [135] = { name="Afflicted Soul",    intervalSec=60 },
}

local timerTickers   = {}
local activeAffixes  = {}

local function PrintAffixes()
    if #activeAffixes == 0 then NightPulse:Print("No affixes detected — are you in a Mythic+ key?"); return end
    NightPulse:Print("── This week's affixes ──")
    for _, affixID in ipairs(activeAffixes) do
        local info = AFFIX_INFO[affixID]
        if info then
            local danger = info.dangerous and " |cffff4444[!]|r" or ""
            NightPulse:Print("|cffffff00"..info.name.."|r"..danger.." — "..info.tip)
        else
            NightPulse:Print("|cffffff00Affix "..affixID.."|r (unknown — check Wowhead)")
        end
    end
end

function NightPulse:PrintAffixes() PrintAffixes() end

local function StopAffixTimers()
    for _, ticker in pairs(timerTickers) do ticker:Cancel() end
    timerTickers = {}
end

local function StartAffixTimers()
    StopAffixTimers()
    local warnSec = NightPulse:GetSetting("affixTracker", "warnSeconds") or 5
    for _, affixID in ipairs(activeAffixes) do
        local timedInfo = TIMED_AFFIXES[affixID]
        if timedInfo then
            local interval = timedInfo.intervalSec
            local elapsed  = 0
            timerTickers[affixID] = C_Timer.NewTicker(1, function()
                elapsed = elapsed + 1
                local remaining = interval - (elapsed % interval)
                if remaining == warnSec then
                    NightPulse:Print("|cffffaa00[AFFIX] "..timedInfo.name.." spawns in "..warnSec.."s!|r")
                    PlaySound(5274, "Master")
                end
            end)
        end
    end
end

function AT:RefreshAffixes()
    activeAffixes = {}
    local affixInfo = C_MythicPlus.GetCurrentAffixes()
    if affixInfo then
        for _, entry in ipairs(affixInfo) do table.insert(activeAffixes, entry.id) end
    end
end

local function OnChallengeModeStart()
    AT:RefreshAffixes(); StartAffixTimers()
    NightPulse:Print("|cff00ff00Mythic+ key started — affix timers active.|r")
end

local function OnChallengeModeCompleted() StopAffixTimers(); NightPulse:Print("Key ended — affix timers stopped.") end
local function OnChallengeModeReset()     StopAffixTimers() end

function AT:Enable()
    NightPulse:RegisterEvent("CHALLENGE_MODE_START",     OnChallengeModeStart)
    NightPulse:RegisterEvent("CHALLENGE_MODE_COMPLETED", OnChallengeModeCompleted)
    NightPulse:RegisterEvent("CHALLENGE_MODE_RESET",     OnChallengeModeReset)
end

function AT:Disable()
    NightPulse:UnregisterEvent("CHALLENGE_MODE_START")
    NightPulse:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
    NightPulse:UnregisterEvent("CHALLENGE_MODE_RESET")
    StopAffixTimers()
end

NightPulse:RegisterEvent("PLAYER_LOGIN", function()
    if not NightPulse:GetSetting("affixTracker", "enabled") then return end
    AT:Enable(); AT:RefreshAffixes()
    if NightPulse:GetSetting("affixTracker", "showOnLogin") then
        C_Timer.After(2, function() PrintAffixes() end)
    end
end)

NightPulse.AffixTracker = AT
