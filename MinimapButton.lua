-- ============================================================
-- NightPulse MinimapButton.lua
-- ============================================================
-- Draggable minimap button that toggles the main NightPulse
-- window. Angle position is saved to NightPulse.db between
-- sessions. Ported from MidnightCheck's minimap implementation.
-- ============================================================

local MM = {}
NightPulse.Minimap = MM

local minimapButton
local currentAngle  -- in radians

local RADIUS = 80

local function UpdatePosition(angle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * RADIUS,
        math.sin(angle) * RADIUS)
end

local function SaveAngle()
    if NightPulse.db then
        NightPulse.db.ui.minimapAngle = math.deg(currentAngle)
    end
end

local function BuildMinimapButton()
    minimapButton = CreateFrame("Button", "NightPulseMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Background circle
    local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")

    -- Icon — 237538 = spell_holy_borrowedtime (purple clock, fits M+ theme)
    -- Swap this fileID for any icon you prefer.
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(237538)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    -- Tracking border ring
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    -- Restore saved angle, defaulting to 225 degrees (bottom-left)
    local savedDeg = (NightPulse.db and NightPulse.db.ui.minimapAngle) or 225
    currentAngle = math.rad(savedDeg)
    UpdatePosition(currentAngle)

    -- Drag to reposition around the minimap ring
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local xpos, ypos = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local cx = Minimap:GetLeft() + Minimap:GetWidth()  / 2
            local cy = Minimap:GetBottom() + Minimap:GetHeight() / 2
            xpos = xpos / scale - Minimap:GetLeft() - Minimap:GetWidth()  / 2
            ypos = ypos / scale - Minimap:GetBottom() - Minimap:GetHeight() / 2
            currentAngle = math.atan2(ypos, xpos)
            UpdatePosition(currentAngle)
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
        SaveAngle()
    end)

    -- Left-click toggles the main window
    minimapButton:SetScript("OnClick", function()
        NightPulse:ToggleMainWindow()
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff9f7fffNightPulse|r")
        GameTooltip:AddLine("Left-Click to open/close.", 1, 1, 1)
        GameTooltip:AddLine("Drag to reposition.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Called from Core.lua's PLAYER_LOGIN handler once db is ready
function MM:Init()
    BuildMinimapButton()
end

-- Allow showing/hiding via settings (future use)
function MM:Show() if minimapButton then minimapButton:Show() end end
function MM:Hide() if minimapButton then minimapButton:Hide() end end

