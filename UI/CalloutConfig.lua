-- ============================================================
-- NightPulse UI/CalloutConfig.lua  (Midnight 12.0.1)
-- Per-boss, per-ability callout filter panel
-- ============================================================

local configFrame

local BACKDROP = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left=4, right=4, top=4, bottom=4 },
}

local PRIORITY_LEVELS = { "high", "medium", "low" }
local PRIORITY_LABELS = { high="High only", medium="High + Med", low="All" }
local PRIORITY_COL    = { high="|cffff4444", medium="|cffffaa00", low="|cffffff44" }

local function BuildConfigWindow()
    local CE = NightPulse.CalloutEngine

    local f = CreateFrame("Frame", "NightPulseCalloutConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(420, 500)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(0.4, 0.3, 0.7, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetFrameStrata("DIALOG")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetPoint("CENTER")
    f:Hide()

    -- Title bar
    local titleBar = f:CreateTexture(nil, "ARTWORK")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(28)
    titleBar:SetColorTexture(0.2, 0.14, 0.4, 0.9)

    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -8)
    titleText:SetText("|cff9f7fffNightPulse|r — Callout Filters")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ---- Priority filter ----
    local yPos = -44

    local priLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yPos)
    priLabel:SetText("|cff9f7fffMinimum priority|r")
    yPos = yPos - 26

    local priButtons = {}
    local function UpdatePriButtons(selected)
        for lvl, btn in pairs(priButtons) do
            if lvl == selected then btn:LockHighlight()
            else btn:UnlockHighlight() end
        end
    end

    local priX = 16
    for _, lvl in ipairs(PRIORITY_LEVELS) do
        local btn = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", priX, yPos)
        btn:SetSize(118, 24)
        btn:SetText(PRIORITY_LABELS[lvl])
        local captured = lvl
        btn:SetScript("OnClick", function()
            NightPulse:SetSetting("callouts", "minPriority", captured)
            UpdatePriButtons(captured)
        end)
        priButtons[lvl] = btn
        priX = priX + 124
    end
    yPos = yPos - 34

    -- Separator
    local sep = f:CreateTexture(nil, "OVERLAY")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  16,  yPos)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, yPos)
    sep:SetHeight(1); sep:SetColorTexture(0.4, 0.3, 0.7, 0.5)
    yPos = yPos - 10

    local abLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    abLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yPos)
    abLabel:SetText("|cff9f7fffPer-ability mutes|r  |cff888888(uncheck to silence)|r")
    yPos = yPos - 26

    -- ---- Scrollable per-ability list ----
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",  16,   yPos)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 350)
    scrollFrame:SetScrollChild(content)

    local function RebuildAbilityList()
        if content.rows then
            for _, row in ipairs(content.rows) do row:Hide() end
        end
        content.rows = {}

        local ROW_H  = 22
        local INDENT = 14
        local rowY   = 0

        -- Sort encounter IDs so the list is stable across sessions
        local ids = {}
        for id in pairs(CE.encounters) do ids[#ids+1] = id end
        table.sort(ids)

        for _, encounterID in ipairs(ids) do
            local abilities = CE.encounters[encounterID]
            local bossName  = CE.bossNames[encounterID] or ("Encounter " .. encounterID)

            -- Boss header
            local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, rowY)
            header:SetText("|cff9f7fff" .. bossName .. "|r")
            header:SetWidth(content:GetWidth())
            table.insert(content.rows, header)
            rowY = rowY - ROW_H

            for _, ab in ipairs(abilities) do
                local key     = CE:GetAbilityKey(encounterID, ab.name)
                local muted   = NightPulse.db.callouts.mutedAbilities
                local isActive = not (muted[key] == true)

                local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT - 4, rowY + 4)
                cb:SetChecked(isActive)

                local col = PRIORITY_COL[ab.priority] or ""
                cb.text:SetText(col .. ab.name .. "|r")
                cb.text:SetTextColor(0.9, 0.9, 0.9)

                if ab.tip then
                    cb:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(ab.tip, 1, 1, 1, 1, true)
                        GameTooltip:Show()
                    end)
                    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end

                local capID   = encounterID
                local capName = ab.name
                cb:SetScript("OnClick", function(self)
                    local k = CE:GetAbilityKey(capID, capName)
                    if self:GetChecked() then
                        NightPulse.db.callouts.mutedAbilities[k] = nil
                    else
                        NightPulse.db.callouts.mutedAbilities[k] = true
                    end
                end)

                table.insert(content.rows, cb)
                rowY = rowY - ROW_H
            end

            rowY = rowY - 6  -- gap between bosses
        end

        content:SetHeight(math.max(-rowY, 10))
    end

    f:SetScript("OnShow", function()
        local cur = NightPulse:GetSetting("callouts", "minPriority") or "medium"
        UpdatePriButtons(cur)
        RebuildAbilityList()
    end)

    configFrame = f
end

function NightPulse:ToggleCalloutConfig()
    if not NightPulse.db then return end
    if not configFrame then BuildConfigWindow() end
    if configFrame:IsShown() then configFrame:Hide()
    else configFrame:Show() end
end
