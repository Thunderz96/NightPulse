-- ============================================================
-- NightPulse ProgressionLog.lua
-- ============================================================
local PL = {}

local function FormatDate(timestamp) return date("%Y-%m-%d", timestamp) end

local function TrimLog()
    local runs   = NightPulse.db.progressionLog.runs
    local maxLen = NightPulse:GetSetting("progressionLog", "maxEntries") or 200
    while #runs > maxLen do table.remove(runs, 1) end
end

local function AddRun(record)
    record.timestamp = time(); record.date = FormatDate(record.timestamp)
    table.insert(NightPulse.db.progressionLog.runs, record)
    TrimLog()
end

local pendingRun = nil

local function OnChallengeModeStart()
    local mapID, _, level = C_ChallengeMode.GetActiveKeystoneInfo()
    local mapName = C_Map.GetMapInfo(mapID) and C_Map.GetMapInfo(mapID).name or "Unknown"
    pendingRun = { type="mythicplus", dungeon=mapName, keyLevel=level, startTime=GetTime() }
end

local function OnChallengeModeCompleted()
    if not pendingRun then return end
    local ok, mapID, level, elapsedMs, onTime, upgrade = pcall(C_ChallengeMode.GetCompletionInfo)
    if not ok then elapsedMs=nil; onTime=false end
    pendingRun.timed      = onTime
    pendingRun.elapsedMin = elapsedMs and (math.floor(elapsedMs/60000*10)/10) or nil
    AddRun(pendingRun)
    local timedStr = onTime and "|cff00ff00[TIMED]|r" or "|cffff4444[untimed]|r"
    NightPulse:Print("|cffffff00+"..pendingRun.keyLevel.." "..pendingRun.dungeon.."|r "..timedStr..
        (pendingRun.elapsedMin and (" — "..pendingRun.elapsedMin.."min") or ""))
    pendingRun = nil
end

local function OnChallengeModeReset()
    if pendingRun then pendingRun.timed=false; pendingRun.failed=true; AddRun(pendingRun); pendingRun=nil end
end

local function OnBossKill(event, bossID, name)
    local difficulty = select(3, GetInstanceInfo())
    local diffNames  = { [14]="Normal",[15]="Heroic",[16]="Mythic",[17]="LFR" }
    AddRun({ type="raid", dungeon=name or ("Boss "..bossID), bossKill=true, difficulty=diffNames[difficulty] or tostring(difficulty) })
    NightPulse:Print("|cff00ff00Boss kill:|r "..(name or "?").." ("..(diffNames[difficulty] or "?")..")")
end

local function OnEncounterEnd(event, encounterID, encounterName, difficultyID, groupSize, success)
    if success == 1 then return end
    local diffNames = { [14]="Normal",[15]="Heroic",[16]="Mythic",[17]="LFR" }
    AddRun({ type="raid", dungeon=encounterName or ("Encounter "..encounterID), bossKill=false,
             difficulty=diffNames[difficultyID] or tostring(difficultyID), failed=true })
end

function NightPulse:PrintRecentRuns(count)
    count = count or 10
    local runs = NightPulse.db.progressionLog.runs
    if #runs == 0 then NightPulse:Print("No runs recorded yet."); return end
    NightPulse:Print("── Recent runs (last "..count..") ──")
    local shown = 0
    for i = #runs, 1, -1 do
        if shown >= count then break end
        local r = runs[i]
        if r.type == "mythicplus" then
            local status = r.timed and "|cff00ff00✓|r" or "|cffff4444✗|r"
            local fail   = r.failed and " |cff666666[abandoned]|r" or ""
            NightPulse:Print(r.date.."  |cffffff00+"..r.keyLevel.." "..r.dungeon.."|r  "..status..
                (r.elapsedMin and ("  "..r.elapsedMin.."m") or "")..fail)
        elseif r.type == "raid" then
            local status = r.bossKill and "|cff00ff00Kill|r" or "|cffff4444Wipe|r"
            NightPulse:Print(r.date.."  "..r.dungeon.."  |cff9f7fff"..(r.difficulty or "?").."|r  "..status)
        end
        shown = shown + 1
    end
end

function NightPulse:BestKey()
    local best = nil
    for _, r in ipairs(NightPulse.db.progressionLog.runs) do
        if r.type=="mythicplus" and r.timed then
            if not best or r.keyLevel > best.keyLevel then best = r end
        end
    end
    if best then
        NightPulse:Print("Best timed key: |cffffff00+"..best.keyLevel.." "..best.dungeon.."|r on "..best.date)
    else
        NightPulse:Print("No timed keys recorded yet.")
    end
end

