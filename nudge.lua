local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LibEditModeOverride = LibStub("LibEditModeOverride-1.0", true)

-- Extra nudge targets: Blizzard Edit Mode unit frame anchors
-- These are the invisible movers that our reskinned unit frames use.
local UNIT_ANCHOR_FRAMES = {
    PlayerFrame = "Player",
    TargetFrame = "Target",
    FocusFrame  = "Focus",
    PetFrame    = "Pet",
}

local function IsNudgeTargetFrameName(frameName)
    if not frameName then return false end

    -- Our cooldown viewers
    if NephUI.viewers then
        for _, viewerName in ipairs(NephUI.viewers) do
            if frameName == viewerName then
                return true
            end
        end
    end

    -- Blizzard unit-frame anchors
    if UNIT_ANCHOR_FRAMES[frameName] then
        return true
    end

    return false
end

local function GetNudgeDisplayName(frameName)
    if not frameName then
        return ""
    end

    -- Friendly names for unit-frame anchors
    local unitLabel = UNIT_ANCHOR_FRAMES[frameName]
    if unitLabel then
        return unitLabel
    end

    -- Fallback: prettify viewer names
    return frameName
        :gsub("CooldownViewer", "")
        :gsub("Icon", " Icon")
end

-- Nudge Frame for Viewer / Anchor Positioning

local NudgeFrame = CreateFrame("Frame", ADDON_NAME .. "NudgeFrame", UIParent, "BackdropTemplate")
NephUI.nudgeFrame = NudgeFrame

-- Frame properties
NudgeFrame:SetSize(200, 320)
NudgeFrame:SetFrameStrata("DIALOG")
NudgeFrame:SetClampedToScreen(true)
NudgeFrame:EnableMouse(true)
NudgeFrame:SetMovable(false)
NudgeFrame:Hide()

-- Backdrop
NudgeFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

-- Position docked to Edit Mode frame
function NudgeFrame:UpdatePosition()
    if EditModeManagerFrame then
        self:ClearAllPoints()
        self:SetPoint("RIGHT", EditModeManagerFrame, "LEFT", -5, 0)
    end
end

-- Title text
local title = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("Viewer Position")

-- Info text showing current selection
local infoText = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
infoText:SetPoint("TOP", title, "BOTTOM", 0, -8)
infoText:SetWidth(180)
infoText:SetWordWrap(true)
NudgeFrame.infoText = infoText

-- Position display
local posText = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
posText:SetPoint("TOP", infoText, "BOTTOM", 0, -8)
posText:SetWidth(180)
posText:SetJustifyH("CENTER")
NudgeFrame.posText = posText

-- Helper function to create arrow buttons
local function CreateArrowButton(parent, direction, x, yFromTop)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)
    button:SetPoint("TOP", parent, "TOP", x, yFromTop)
    
    -- Button background
    button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
    -- Rotate texture based on direction
    local texture = button:GetNormalTexture()
    if direction == "UP" then
        texture:SetRotation(math.rad(90))
        button:GetPushedTexture():SetRotation(math.rad(90))
    elseif direction == "DOWN" then
        texture:SetRotation(math.rad(270))
        button:GetPushedTexture():SetRotation(math.rad(270))
    elseif direction == "LEFT" then
        texture:SetRotation(math.rad(180))
        button:GetPushedTexture():SetRotation(math.rad(180))
    elseif direction == "RIGHT" then
        texture:SetRotation(math.rad(0))
        button:GetPushedTexture():SetRotation(math.rad(0))
    end
    
    button:SetScript("OnClick", function()
        NephUI:NudgeSelectedViewer(direction)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Nudge " .. direction:lower())
        GameTooltip:AddLine("Move selected viewer 1 pixel " .. direction:lower(), 1, 1, 1)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return button
end

-- Create directional buttons
NudgeFrame.upButton = CreateArrowButton(NudgeFrame, "UP", 0, -90)
NudgeFrame.downButton = CreateArrowButton(NudgeFrame, "DOWN", 0, -150)
NudgeFrame.leftButton = CreateArrowButton(NudgeFrame, "LEFT", -25, -120)
NudgeFrame.rightButton = CreateArrowButton(NudgeFrame, "RIGHT", 25, -120)

-- Close button
local closeButton = CreateFrame("Button", nil, NudgeFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function()
    NudgeFrame:Hide()
end)

-- Nudge amount slider
local amountSlider = CreateFrame("Slider", nil, NudgeFrame, "OptionsSliderTemplate")
amountSlider:SetPoint("BOTTOM", 0, 60)
amountSlider:SetMinMaxValues(1, 10)
amountSlider:SetValueStep(1)
amountSlider:SetObeyStepOnDrag(true)
amountSlider:SetWidth(150)
amountSlider:SetHeight(15)
NudgeFrame.amountSlider = amountSlider

-- Slider label
local amountLabel = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
amountLabel:SetPoint("BOTTOM", amountSlider, "TOP", 0, 2)
amountLabel:SetText("Nudge Amount: 1px")
NudgeFrame.amountLabel = amountLabel

-- Slider min/max labels
amountSlider.Low:SetText("1")
amountSlider.High:SetText("10")

-- Slider value change handler
amountSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    NephUI.db.profile.nudgeAmount = value
    amountLabel:SetText("Nudge Amount: " .. value .. "px")
end)

-- Viewer selector dropdown
local viewerDropdown = CreateFrame("Frame", ADDON_NAME .. "ViewerDropdown", NudgeFrame, "UIDropDownMenuTemplate")
viewerDropdown:SetPoint("BOTTOM", 0, 20)
NudgeFrame.viewerDropdown = viewerDropdown

-- Dropdown label
local dropdownLabel = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dropdownLabel:SetPoint("BOTTOM", viewerDropdown, "TOP", 0, 0)
dropdownLabel:SetText("Select Viewer:")

-- Initialize dropdown
local function ViewerDropdown_Initialize(self, level)
    local info = UIDropDownMenu_CreateInfo()

    -- Cooldown viewers
    if NephUI.viewers then
        for _, viewerName in ipairs(NephUI.viewers) do
            local displayName = GetNudgeDisplayName(viewerName)

            info.text = displayName
            info.value = viewerName
            info.func = function()
                NephUI:SelectViewer(viewerName)
                UIDropDownMenu_SetText(viewerDropdown, displayName)
                CloseDropDownMenus()
            end
            info.checked = (NephUI.selectedViewer == viewerName)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    -- Blizzard unit-frame anchors
    for frameName, label in pairs(UNIT_ANCHOR_FRAMES) do
        local displayName = label

        info.text = displayName
        info.value = frameName
        info.func = function()
            NephUI:SelectViewer(frameName)
            UIDropDownMenu_SetText(viewerDropdown, displayName)
            CloseDropDownMenus()
        end
        info.checked = (NephUI.selectedViewer == frameName)
        UIDropDownMenu_AddButton(info, level)
    end
end

UIDropDownMenu_Initialize(viewerDropdown, ViewerDropdown_Initialize)
UIDropDownMenu_SetWidth(viewerDropdown, 150)
UIDropDownMenu_SetText(viewerDropdown, "Select...")

-- Update info display
function NudgeFrame:UpdateInfo()
    local viewerName = NephUI.selectedViewer
    local viewer = viewerName and _G[viewerName]
    
    if viewer then
        local displayName = GetNudgeDisplayName(viewerName)
        self.infoText:SetText(displayName)
        self.infoText:SetTextColor(0, 1, 0)
        
        -- Show position
        local point, relativeTo, relativePoint, xOfs, yOfs = viewer:GetPoint(1)
        if point then
            self.posText:SetFormattedText("Position: %.1f, %.1f", xOfs or 0, yOfs or 0)
            self.posText:SetTextColor(1, 1, 1)
        else
            self.posText:SetText("No position data")
            self.posText:SetTextColor(0.7, 0.7, 0.7)
        end
        
        -- Enable controls
        self.upButton:Enable()
        self.downButton:Enable()
        self.leftButton:Enable()
        self.rightButton:Enable()
        self.amountSlider:Enable()
    else
        self.infoText:SetText("Click a viewer in Edit Mode")
        self.infoText:SetTextColor(0.7, 0.7, 0.7)
        self.posText:SetText("")
        
        -- Disable controls
        self.upButton:Disable()
        self.downButton:Disable()
        self.leftButton:Disable()
        self.rightButton:Disable()
        self.amountSlider:Disable()
    end
end

-- Update amount slider
function NudgeFrame:UpdateAmountSlider()
    local amount = NephUI.db.profile.nudgeAmount or 1
    self.amountSlider:SetValue(amount)
    self.amountLabel:SetText("Nudge Amount: " .. amount .. "px")
end

-- Update visibility
function NudgeFrame:UpdateVisibility()
    if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
        self:UpdatePosition()
        self:Show()
        self:UpdateInfo()
        self:UpdateAmountSlider()
    else
        self:Hide()
    end
end

-- Update on show
NudgeFrame:SetScript("OnShow", function(self)
    self:UpdatePosition()
    self:UpdateInfo()
    self:UpdateAmountSlider()
end)

-- Edit Mode Click Detection

local clickDetector = CreateFrame("Frame")
clickDetector:Hide()
local lastClickedFrame = nil

function NephUI:EnableClickDetection()
    clickDetector:Show()
    clickDetector:SetScript("OnUpdate", function(self, elapsed)
        if IsMouseButtonDown("LeftButton") then
            local frames = GetMouseFoci()
            if frames and #frames > 0 then
                for _, frame in ipairs(frames) do
                    if frame and frame ~= WorldFrame then
                        local frameName = frame:GetName()

                        -- Check if this is one of our viewers or unit-frame anchors
                        if IsNudgeTargetFrameName(frameName) then
                            if lastClickedFrame ~= frame then
                                lastClickedFrame = frame
                                NephUI:SelectViewer(frameName)
                            end
                            return
                        end
                    end
                end
            end
        else
            lastClickedFrame = nil
        end
    end)
end

function NephUI:DisableClickDetection()
    clickDetector:Hide()
    clickDetector:SetScript("OnUpdate", nil)
    lastClickedFrame = nil
end

-- Viewer Selection & Nudging

-- Select a viewer for nudging
function NephUI:SelectViewer(viewerName)
    if not viewerName or not _G[viewerName] then
        self.selectedViewer = nil
        if self.nudgeFrame then
            self.nudgeFrame:UpdateInfo()
        end
        return
    end
    
    self.selectedViewer = viewerName
    
    if self.nudgeFrame then
        self.nudgeFrame:UpdateInfo()
        local displayName = GetNudgeDisplayName(viewerName)
        UIDropDownMenu_SetText(self.nudgeFrame.viewerDropdown, displayName)
        
        -- Show the nudge frame if in edit mode
        if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
            self.nudgeFrame:Show()
            self.nudgeFrame:UpdatePosition()
        end
    end
end

-- Ensure LibEditModeOverride is ready and layouts are loaded
local function EnsureEditModeReady()
    if not LibEditModeOverride then
        return false
    end
    
    if not LibEditModeOverride:IsReady() then
        return false
    end
    
    if not LibEditModeOverride:AreLayoutsLoaded() then
        LibEditModeOverride:LoadLayouts()
    end
    
    return LibEditModeOverride:CanEditActiveLayout()
end

-- Nudge the selected viewer
function NephUI:NudgeSelectedViewer(direction)
    if not self.selectedViewer then return false end

    local viewer = _G[self.selectedViewer]
    if not viewer then return false end

    local amount = self.db.profile.nudgeAmount or 1

    -- Get current point from the Edit Mode system frame
    local point, relativeTo, relativePoint, xOfs, yOfs = viewer:GetPoint(1)
    if not point then return false end

    local newX = xOfs or 0
    local newY = yOfs or 0

    if direction == "UP" then
        newY = newY + amount
    elseif direction == "DOWN" then
        newY = newY - amount
    elseif direction == "LEFT" then
        newX = newX - amount
    elseif direction == "RIGHT" then
        newX = newX + amount
    end

    -- Use LibEditModeOverride if available (cleaner, more reliable)
    if LibEditModeOverride and EnsureEditModeReady() and LibEditModeOverride:HasEditModeSettings(viewer) then
        -- Use the library's ReanchorFrame method which properly registers with Edit Mode
        local success, err = pcall(function()
            LibEditModeOverride:ReanchorFrame(viewer, point, relativeTo, relativePoint, newX, newY)
        end)
        
        if success then
            -- Update the display in your nudge panel
            if self.nudgeFrame and self.nudgeFrame:IsShown() then
                self.nudgeFrame:UpdateInfo()
            end
            return true
        end
    end

    -- Fallback to manual method if library isn't available or frame isn't registered
    viewer:ClearAllPoints()
    viewer:SetPoint(point, relativeTo, relativePoint, newX, newY)

    -- Tell Edit Mode that THIS system's position changed
    if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
        if EditModeManagerFrame.OnSystemPositionChange then
            -- Properly register that this Edit Mode system has a new position
            EditModeManagerFrame:OnSystemPositionChange(viewer)
        elseif EditModeManagerFrame.SetHasActiveChanges then
            -- Fallback: at least mark as dirty
            EditModeManagerFrame:SetHasActiveChanges(true)
        end
    end

    -- Update the display in your nudge panel
    if self.nudgeFrame and self.nudgeFrame:IsShown() then
        self.nudgeFrame:UpdateInfo()
    end

    return true
end

-- Hook Edit Mode enter/exit
local function SetupEditModeHooks()
    if not EditModeManagerFrame then return end
    
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        -- Ensure LibEditModeOverride layouts are loaded when entering Edit Mode
        if LibEditModeOverride and LibEditModeOverride:IsReady() then
            if not LibEditModeOverride:AreLayoutsLoaded() then
                LibEditModeOverride:LoadLayouts()
            end
        end
        
        NephUI.nudgeFrame:UpdateVisibility()
        NephUI:EnableClickDetection()
    end)
    
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        NephUI.nudgeFrame:Hide()
        NephUI:DisableClickDetection()
        NephUI.selectedViewer = nil
    end)
end

if EditModeManagerFrame then
    SetupEditModeHooks()
else
    -- Wait for EditModeManagerFrame to load
    local waitFrame = CreateFrame("Frame")
    waitFrame:RegisterEvent("ADDON_LOADED")
    waitFrame:SetScript("OnEvent", function(self, event, addon)
        if EditModeManagerFrame then
            SetupEditModeHooks()
            self:UnregisterAllEvents()
        end
    end)
end

-- Add nudgeamount
local oldOnInitialize = NephUI.OnInitialize
function NephUI:OnInitialize()
    if oldOnInitialize then
        oldOnInitialize(self)
    end
    
    -- Add nudgeAmount default
    if not self.db.profile.nudgeAmount then
        self.db.profile.nudgeAmount = 1
    end
end