-- ============================================================
-- NightPulse UI/MainWindow.lua  (Midnight 12.0.1)
-- ============================================================
-- BasicFrameTemplateWithInset was removed in Midnight 12.0.
-- We now use a plain Frame with BackdropTemplate and wire up
-- the title bar, close button, and content area ourselves.
-- ============================================================

local UI = {}
local mainFrame

local WINDOW_W  = 420
local WINDOW_H  = 500
local PADDING   = 16
local ROW_H     = 28
local SECTION_H = 22
local TITLE_H   = 28

local COLOR_HEADER = { 0.62, 0.47, 1.0, 1 }
local COLOR_BODY   = { 0.9,  0.9,  0.9, 1 }

local BACKDROP = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left=4, right=4, top=4, bottom=4 },
}

local function AddSectionLabel(parent, yOffset, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING, yOffset)
    label:SetText("|cff9f7fff" .. text .. "|r")
    return label
end

local function AddCheckbox(parent, yOffset, labelText, tooltipText, isChecked, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING - 4, yOffset)
    cb:SetChecked(isChecked)
    cb.text:SetText(labelText)
    cb.text:SetTextColor(unpack(COLOR_BODY))
    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if onChange then
        cb:SetScript("OnClick", function(self) onChange(self:GetChecked()) end)
    end
    return cb
end

local function AddButton(parent, yOffset, xOffset, labelText, onClick)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    btn:SetSize(120, 24)
    btn:SetText(labelText)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function BuildRunHistory(parent, yOffset)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     parent, "TOPLEFT",     PADDING,         yOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(PADDING + 20), PADDING)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(WINDOW_W - PADDING * 2 - 20, 1)
    scrollFrame:SetScrollChild(content)

    function UI:RefreshHistory()
        if content.lines then
            for _, line in ipairs(content.lines) do line:Hide() end
        end
        content.lines = {}
        local runs        = (NightPulse.db and NightPulse.db.progressionLog.runs) or {}
        local totalHeight = 0
        local lineY       = 0
        local count       = 0
        for i = #runs, 1, -1 do
            if count >= 40 then break end
            local r    = runs[i]; count = count + 1
            local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, lineY)
            line:SetWidth(content:GetWidth()); line:SetJustifyH("LEFT")
            local text
            if r.type == "mythicplus" then
                local status = r.timed and "|cff00ff00✓|r" or "|cffff4444✗|r"
                local fail   = r.failed and " |cff666666[abandoned]|r" or ""
                text = r.date.."  |cffffff00+"..r.keyLevel.." "..r.dungeon.."|r  "..status..
                       (r.elapsedMin and ("  "..r.elapsedMin.."m") or "")..fail
            elseif r.type == "raid" then
                text = r.date.."  |cff9f7fff"..(r.difficulty or "?").."|r  "..r.dungeon.."  "..
                       (r.bossKill and "|cff00ff00Kill|r" or "|cffff4444Wipe|r")
            else text = r.date.."  "..tostring(r.dungeon) end
            line:SetText(text)
            table.insert(content.lines, line)
            lineY = lineY - ROW_H; totalHeight = totalHeight + ROW_H
        end
        if count == 0 then
            local e = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            e:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            e:SetText("|cff888888No runs recorded yet — go push some keys!|r")
            table.insert(content.lines, e); totalHeight = ROW_H
        end
        content:SetHeight(math.max(totalHeight, 10))
    end
    return scrollFrame
end

local function BuildMainWindow()
    -- Plain Frame with BackdropTemplate — works in Midnight 12.0
    local f = CreateFrame("Frame", "NightPulseMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(WINDOW_W, WINDOW_H)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(0.4, 0.3, 0.7, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetFrameStrata("DIALOG")
    f:SetScript("OnDragStart", function(self)
        if NightPulse.db and not NightPulse.db.ui.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if NightPulse.db then
            local point, _, relPoint, x, y = self:GetPoint()
            NightPulse.db.ui.point = { point, "UIParent", relPoint, x, y }
        end
    end)

    -- Restore saved position using discrete locals (not unpack)
    local anchor, relAnchor, offX, offY = "CENTER", "CENTER", 0, 0
    if NightPulse.db and NightPulse.db.ui and NightPulse.db.ui.point then
        local p = NightPulse.db.ui.point
        anchor = p[1] or "CENTER"; relAnchor = p[3] or "CENTER"
        offX   = p[4] or 0;       offY      = p[5] or 0
    end
    f:SetPoint(anchor, UIParent, relAnchor, offX, offY)
    f:Hide()

    -- Title bar
    local titleBar = f:CreateTexture(nil, "ARTWORK")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(TITLE_H)
    titleBar:SetColorTexture(0.2, 0.14, 0.4, 0.9)

    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -8)
    titleText:SetText("|cff9f7fffNightPulse|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Content area starts below the title bar
    -- All UI elements are parented directly to f, offset by TITLE_H
    local yPos = -(TITLE_H + 8)

    AddSectionLabel(f, yPos, "Callout engine")
    yPos = yPos - SECTION_H

    AddCheckbox(f, yPos, "Enable callouts",
        "Warn when boss encounters and casts are detected.",
        NightPulse:GetSetting("callouts", "enabled"),
        function(checked)
            NightPulse:SetSetting("callouts", "enabled", checked)
            if checked then NightPulse.CalloutEngine:Enable()
                        else NightPulse.CalloutEngine:Disable() end
        end)
    yPos = yPos - ROW_H

    AddCheckbox(f, yPos, "Flash screen on high-priority",
        "Briefly flashes the screen edge red on dangerous casts.",
        NightPulse:GetSetting("callouts", "flashScreen"),
        function(checked) NightPulse:SetSetting("callouts", "flashScreen", checked) end)
    yPos = yPos - ROW_H

    AddCheckbox(f, yPos, "Play alert sound",
        "Plays a chime when a callout fires.",
        NightPulse:GetSetting("callouts", "playSound"),
        function(checked) NightPulse:SetSetting("callouts", "playSound", checked) end)
    yPos = yPos - ROW_H - 4

    AddSectionLabel(f, yPos, "Affix tracker")
    yPos = yPos - SECTION_H

    AddCheckbox(f, yPos, "Show affixes on login",
        "Prints this week's affix list with tips to chat on login.",
        NightPulse:GetSetting("affixTracker", "showOnLogin"),
        function(checked) NightPulse:SetSetting("affixTracker", "showOnLogin", checked) end)
    yPos = yPos - ROW_H

    AddButton(f, yPos, PADDING, "Show affixes now", function() NightPulse:PrintAffixes() end)
    yPos = yPos - ROW_H - 4

    AddSectionLabel(f, yPos, "Progression log")
    yPos = yPos - SECTION_H

    AddButton(f, yPos, PADDING,       "Last 10 runs", function() NightPulse:PrintRecentRuns(10) end)
    AddButton(f, yPos, PADDING + 130, "Best key",     function() NightPulse:BestKey() end)
    yPos = yPos - ROW_H - 2

    local sep = f:CreateTexture(nil, "OVERLAY")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  PADDING,  yPos)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, yPos)
    sep:SetHeight(1); sep:SetColorTexture(0.4, 0.3, 0.7, 0.6)
    yPos = yPos - 6

    BuildRunHistory(f, yPos)
    f:SetScript("OnShow", function() UI:RefreshHistory() end)
    mainFrame = f
end

function NightPulse:ToggleMainWindow()
    if not NightPulse.db then
        NightPulse:Print("Still loading — please wait a moment and try again.")
        return
    end
    if not mainFrame then BuildMainWindow() end
    if mainFrame:IsShown() then mainFrame:Hide()
    else UI:RefreshHistory(); mainFrame:Show() end
end

NightPulse.MainWindowUI = UI
