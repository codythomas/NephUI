local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LibEditModeOverride = LibStub("LibEditModeOverride-1.0", true)

-- Store the currently selected frame
local currentSelectedFrame = nil
local currentSelectedFrameName = nil

-- Click detector frame (like EditModeTweaks)
local clickDetector = CreateFrame("Frame")
clickDetector:Hide()
local lastMouseOverFrame = nil

-- Walk up frame hierarchy to find a frame with systemInfo (Edit Mode system frame)
local function FindSystemFrame(frame)
    if not frame then return nil end
    
    -- Root frames we should never select and should stop at
    local rootFrames = {
        UIParent = true,
        WorldFrame = true,
        GlueParent = true,
    }
    
    local currentFrame = frame
    local maxDepth = 20 -- Prevent infinite loops
    local depth = 0
    local bestFrame = nil
    
    while currentFrame and depth < maxDepth do
        local frameName = currentFrame:GetName()
        
        -- Stop if we hit a root frame
        if frameName and rootFrames[frameName] then
            break
        end
        
        -- Check if this frame has systemInfo (Edit Mode system frame)
        if currentFrame.systemInfo then
            bestFrame = currentFrame
            -- Continue walking up to see if there's a better parent with systemInfo
        end
        
        -- Try to get the parent
        local parent = currentFrame:GetParent()
        if not parent or parent == currentFrame then
            break
        end
        currentFrame = parent
        depth = depth + 1
    end
    
    return bestFrame
end

-- Select a frame for nudging (based on EditModeTweaks approach)
local function SelectFrame(frame)
    if not frame then return end
    
    -- Filter out frames we don't want to select
    local frameName = frame:GetName()
    local nudgeFrameName = ADDON_NAME .. "NudgeFrame"
    if frameName == nudgeFrameName or 
       frameName == "EditModeManagerFrame" or
       (NudgeFrame and frame == NudgeFrame) or
       (EditModeManagerFrame and frame == EditModeManagerFrame) then
        return
    end
    
    -- Walk up the hierarchy to find the Edit Mode system frame
    local systemFrame = FindSystemFrame(frame)
    
    if systemFrame then
        currentSelectedFrame = systemFrame
        currentSelectedFrameName = systemFrame:GetName() or "Anonymous Frame"
    else
        -- If no system frame found, clear selection
        currentSelectedFrame = nil
        currentSelectedFrameName = nil
    end
end

-- Scan for frames with isSelected = true (Edit Mode's selection)
local function ScanForSelectedFrame()
    if not EditModeManagerFrame or not EditModeManagerFrame.editModeActive then
        return nil
    end
    
    -- Scan all frames for isSelected = true
    local selectedFrame = nil
    local frame = EnumerateFrames()
    
    while frame do
        if frame.isSelected == true then
            -- Found a selected frame, walk up to find the system frame
            selectedFrame = FindSystemFrame(frame)
            if selectedFrame then
                break
            end
            -- If no system frame found, use the selected frame itself
            selectedFrame = frame
            break
        end
        frame = EnumerateFrames(frame)
    end
    
    return selectedFrame
end

-- Enable click detection when Edit Mode is active
local function EnableClickDetection()
    if not EditModeManagerFrame or not EditModeManagerFrame.editModeActive then
        return
    end
    
    clickDetector:Show()
    clickDetector:SetScript("OnUpdate", function(self, elapsed)
        -- First, check for Edit Mode's isSelected frames (priority)
        local editModeSelected = ScanForSelectedFrame()
        local nudgeFrame = _G[ADDON_NAME .. "NudgeFrame"] or NephUI.nudgeFrame
        
        if editModeSelected then
            -- Only update if the selection changed
            if currentSelectedFrame ~= editModeSelected then
                currentSelectedFrame = editModeSelected
                currentSelectedFrameName = editModeSelected:GetName() or "Anonymous Frame"
                -- Update nudge frame display
                if nudgeFrame then
                    nudgeFrame:UpdatePosition()
                    nudgeFrame:UpdateInfo()
                    nudgeFrame:Show()
                end
            elseif nudgeFrame then
                -- Selection hasn't changed, but update position in case frame moved
                nudgeFrame:UpdatePosition()
            end
        else
            -- No Edit Mode selection - clear it and hide nudge frame
            if currentSelectedFrame then
                currentSelectedFrame = nil
                currentSelectedFrameName = nil
                if nudgeFrame then
                    nudgeFrame:Hide()
                end
            end
            
            -- If no Edit Mode selection, use click detection
            if IsMouseButtonDown("LeftButton") then
                local frames = GetMouseFoci()
                if frames and #frames > 0 then
                    local frame = frames[1]
                    if frame and frame ~= WorldFrame and frame ~= lastMouseOverFrame then
                        lastMouseOverFrame = frame
                        SelectFrame(frame)
                        -- Update nudge frame display
                        if nudgeFrame then
                            nudgeFrame:UpdatePosition()
                            nudgeFrame:UpdateInfo()
                            nudgeFrame:Show()
                        end
                    end
                end
            else
                lastMouseOverFrame = nil
            end
        end
    end)
end

-- Disable click detection when Edit Mode is inactive
local function DisableClickDetection()
    clickDetector:Hide()
    clickDetector:SetScript("OnUpdate", nil)
    lastMouseOverFrame = nil
    currentSelectedFrame = nil
    currentSelectedFrameName = nil
end

local function GetSelectedEditModeFrame()
    return currentSelectedFrame, currentSelectedFrameName
end

local function GetFrameDisplayName(frame, frameName)
    if not frame then return "No frame selected" end
    
    frameName = frameName or frame:GetName()
    if not frameName or frameName == "Anonymous Frame" then
        return "Selected Frame"
    end
    
    -- Try to get a nice display name
    if frameName == "PlayerFrame" then
        return "Player"
    elseif frameName == "TargetFrame" then
        return "Target"
    elseif frameName == "FocusFrame" then
        return "Focus"
    elseif frameName == "PetFrame" then
        return "Pet"
    else
        return frameName:gsub("CooldownViewer", ""):gsub("Icon", " Icon")
    end
end

local NudgeFrame = CreateFrame("Frame", ADDON_NAME .. "NudgeFrame", UIParent, "BackdropTemplate")
NephUI.nudgeFrame = NudgeFrame

NudgeFrame:SetSize(200, 200)
NudgeFrame:SetFrameStrata("DIALOG")
NudgeFrame:SetClampedToScreen(true)
NudgeFrame:EnableMouse(true)
NudgeFrame:SetMovable(false)
NudgeFrame:Hide()

NudgeFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

function NudgeFrame:UpdatePosition()
    local selectedFrame = GetSelectedEditModeFrame()
    if selectedFrame then
        self:ClearAllPoints()
        
        -- Get screen dimensions
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        
        -- Get frame position on screen (these can be nil if frame isn't shown)
        local frameLeft = selectedFrame:GetLeft()
        local frameRight = selectedFrame:GetRight()
        local frameTop = selectedFrame:GetTop()
        local frameBottom = selectedFrame:GetBottom()
        
        -- Default positioning (below frame, left-aligned)
        local attachPoint = "TOPLEFT"
        local relativePoint = "BOTTOMLEFT"
        local xOffset = 0
        local yOffset = -10
        
        -- Only calculate if we have valid frame positions
        if frameLeft and frameRight and frameTop and frameBottom then
            -- Calculate distances to edges
            local distToLeft = frameLeft
            local distToRight = screenWidth - frameRight
            local distToTop = screenHeight - frameTop
            local distToBottom = frameBottom
            
            -- Threshold for "near edge" (in pixels) - nudge frame is ~200px wide, 200px tall
            local edgeThreshold = 220
            
            -- Determine vertical positioning first
            local nearBottom = distToBottom < edgeThreshold
            local nearTop = distToTop < edgeThreshold
            
            -- Determine horizontal positioning
            local nearLeft = distToLeft < edgeThreshold
            local nearRight = distToRight < edgeThreshold
            
            -- Handle corners first (most restrictive)
            if nearBottom and nearLeft then
                -- Bottom-left corner: attach above and to the right
                attachPoint = "BOTTOMLEFT"
                relativePoint = "TOPLEFT"
                xOffset = 10
                yOffset = 10
            elseif nearBottom and nearRight then
                -- Bottom-right corner: attach above and to the left
                attachPoint = "BOTTOMRIGHT"
                relativePoint = "TOPRIGHT"
                xOffset = -10
                yOffset = 10
            elseif nearTop and nearLeft then
                -- Top-left corner: attach below and to the right
                attachPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xOffset = 10
                yOffset = -10
            elseif nearTop and nearRight then
                -- Top-right corner: attach below and to the left
                attachPoint = "TOPRIGHT"
                relativePoint = "BOTTOMRIGHT"
                xOffset = -10
                yOffset = -10
            -- Handle edges
            elseif nearBottom then
                -- Near bottom: attach above
                attachPoint = "BOTTOMLEFT"
                relativePoint = "TOPLEFT"
                xOffset = 0
                yOffset = 10
            elseif nearTop then
                -- Near top: attach below
                attachPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xOffset = 0
                yOffset = -10
            elseif nearLeft then
                -- Near left: attach to right side
                attachPoint = "TOPLEFT"
                relativePoint = "TOPRIGHT"
                xOffset = 10
                yOffset = 0
            elseif nearRight then
                -- Near right: attach to left side
                attachPoint = "TOPRIGHT"
                relativePoint = "TOPLEFT"
                xOffset = -10
                yOffset = 0
            end
        end
        
        self:SetPoint(attachPoint, selectedFrame, relativePoint, xOffset, yOffset)
    elseif EditModeManagerFrame then
        -- Fallback to EditModeManagerFrame if no frame selected
        self:ClearAllPoints()
        self:SetPoint("RIGHT", EditModeManagerFrame, "LEFT", -5, 0)
    end
end

local title = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("Nudge Frame")

local infoText = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
infoText:SetPoint("TOP", title, "BOTTOM", 0, -8)
infoText:SetWidth(180)
infoText:SetWordWrap(true)
NudgeFrame.infoText = infoText

local posText = NudgeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
posText:SetPoint("TOP", infoText, "BOTTOM", 0, -8)
posText:SetWidth(180)
posText:SetJustifyH("CENTER")
NudgeFrame.posText = posText

local function CreateArrowButton(parent, direction, x, yFromTop)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)
    button:SetPoint("TOP", parent, "TOP", x, yFromTop)
    
    button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
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
        NephUI:NudgeSelectedFrame(direction)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Nudge " .. direction:lower())
        GameTooltip:AddLine("Move selected frame 1 pixel " .. direction:lower(), 1, 1, 1)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return button
end

NudgeFrame.upButton = CreateArrowButton(NudgeFrame, "UP", 0, -70)
NudgeFrame.downButton = CreateArrowButton(NudgeFrame, "DOWN", 0, -130)
NudgeFrame.leftButton = CreateArrowButton(NudgeFrame, "LEFT", -25, -100)
NudgeFrame.rightButton = CreateArrowButton(NudgeFrame, "RIGHT", 25, -100)

local closeButton = CreateFrame("Button", nil, NudgeFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function()
    NudgeFrame:Hide()
end)

function NudgeFrame:UpdateInfo()
    local selectedFrame, frameName = GetSelectedEditModeFrame()
    
    if selectedFrame then
        local displayName = GetFrameDisplayName(selectedFrame, frameName)
        self.infoText:SetText(displayName)
        self.infoText:SetTextColor(0, 1, 0)
        
        -- Prefer showing Edit Mode anchorInfo offsets if available
        local xOfs, yOfs
        if selectedFrame.systemInfo and selectedFrame.systemInfo.anchorInfo then
            local anchor = selectedFrame.systemInfo.anchorInfo
            xOfs = anchor.offsetX or 0
            yOfs = anchor.offsetY or 0
        else
            -- Fallback to GetPoint
            local point, relativeTo, relativePoint, x, y = selectedFrame:GetPoint(1)
            xOfs = x or 0
            yOfs = y or 0
        end
        
        self.posText:SetFormattedText("Position: %.1f, %.1f", xOfs, yOfs)
        self.posText:SetTextColor(1, 1, 1)
        
        self.upButton:Enable()
        self.downButton:Enable()
        self.leftButton:Enable()
        self.rightButton:Enable()
    else
        self.infoText:SetText("No frame selected")
        self.infoText:SetTextColor(0.7, 0.7, 0.7)
        self.posText:SetText("")
        
        self.upButton:Disable()
        self.downButton:Disable()
        self.leftButton:Disable()
        self.rightButton:Disable()
    end
end

function NudgeFrame:UpdateVisibility()
    -- Update nudge frame visibility and position
    if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
        local selectedFrame, frameName = GetSelectedEditModeFrame()
        if selectedFrame then
            self:UpdatePosition()
            self:Show()
            self:UpdateInfo()
        else
            -- Hide if no frame selected
            self:Hide()
        end
    else
        self:Hide()
    end
end

NudgeFrame:SetScript("OnShow", function(self)
    self:UpdatePosition()
    self:UpdateInfo()
end)

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

function NephUI:NudgeSelectedFrame(direction)
    local selectedFrame, frameName = GetSelectedEditModeFrame()
    if not selectedFrame then return false end

    -- Must be in Edit Mode
    if not EditModeManagerFrame or not EditModeManagerFrame.editModeActive then
        return false
    end

    -- Always use 1 pixel
    local amount = 1

    -- The frame we selected in Edit Mode *is* the system frame (MinimapCluster, PlayerFrame, etc.)
    local systemFrame = selectedFrame

    -- Sanity check that this is actually an Edit Mode system
    -- EditModeTweaks ONLY works with frames that have systemInfo - if they don't have it, return false
    if not systemFrame.systemInfo then
        return false
    end

    local systemInfo = systemFrame.systemInfo
    -- Edit Mode stores its offsets in anchorInfo
    local anchor = systemInfo.anchorInfo or {}

    local xOffset = anchor.offsetX or 0
    local yOffset = anchor.offsetY or 0

    -- Apply the nudge
    if direction == "UP" then
        yOffset = yOffset + amount
    elseif direction == "DOWN" then
        yOffset = yOffset - amount
    elseif direction == "LEFT" then
        xOffset = xOffset - amount
    elseif direction == "RIGHT" then
        xOffset = xOffset + amount
    end

    -- Write back into anchorInfo so it saves properly
    anchor.offsetX = xOffset
    anchor.offsetY = yOffset
    systemInfo.anchorInfo = anchor
    systemFrame.systemInfo = systemInfo

    -- Flag the system/layout as dirty so the Save button lights up
    systemFrame.hasActiveChanges = true
    if EditModeManagerFrame.SetHasActiveChanges then
        EditModeManagerFrame:SetHasActiveChanges(true)
    end

    -- Directly reposition the frame
    local numPoints = systemFrame:GetNumPoints()
    if numPoints > 0 then
        local point, relativeTo, relativePoint = systemFrame:GetPoint(1)
        
        -- Use the anchor point from anchorInfo if available, otherwise use current
        local anchorPoint = anchor.point or point or "CENTER"
        local relativeFrame = anchor.relativeTo or relativeTo or UIParent
        local relativeAnchor = anchor.relativePoint or relativePoint or "CENTER"
        
        systemFrame:ClearAllPoints()
        systemFrame:SetPoint(anchorPoint, relativeFrame, relativeAnchor, xOffset, yOffset)
    end

    -- Update nudge frame display
    if self.nudgeFrame and self.nudgeFrame:IsShown() then
        self.nudgeFrame:UpdateInfo()
        self.nudgeFrame:UpdatePosition()
    end

    return true
end

-- Timer for periodic updates
local updateTicker = nil

local function SetupEditModeHooks()
    if not EditModeManagerFrame then return end
    
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        if LibEditModeOverride and LibEditModeOverride:IsReady() then
            if not LibEditModeOverride:AreLayoutsLoaded() then
                LibEditModeOverride:LoadLayouts()
            end
        end
        
        -- Enable click detection
        EnableClickDetection()
        
        -- Start periodic update ticker (updates every 0.1 seconds)
        if updateTicker then
            updateTicker:Cancel()
        end
        updateTicker = C_Timer.NewTicker(0.1, function()
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
                local selectedFrame = ScanForSelectedFrame()
                if selectedFrame then
                    if currentSelectedFrame ~= selectedFrame then
                        currentSelectedFrame = selectedFrame
                        currentSelectedFrameName = selectedFrame:GetName() or "Anonymous Frame"
                    end
                    if NudgeFrame then
                        NudgeFrame:UpdatePosition()
                        NudgeFrame:UpdateInfo()
                        NudgeFrame:Show()
                    end
                else
                    if currentSelectedFrame then
                        currentSelectedFrame = nil
                        currentSelectedFrameName = nil
                    end
                    if NudgeFrame then
                        NudgeFrame:Hide()
                    end
                end
            end
        end)
        
        -- Initial update
        NudgeFrame:UpdateVisibility()
    end)
    
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        -- Disable click detection
        DisableClickDetection()
        
        -- Stop the ticker
        if updateTicker then
            updateTicker:Cancel()
            updateTicker = nil
        end
        
        NudgeFrame:Hide()
        currentSelectedFrame = nil
        currentSelectedFrameName = nil
    end)
end

if EditModeManagerFrame then
    SetupEditModeHooks()
else
    local waitFrame = CreateFrame("Frame")
    waitFrame:RegisterEvent("ADDON_LOADED")
    waitFrame:SetScript("OnEvent", function(self, event, addon)
        if EditModeManagerFrame then
            SetupEditModeHooks()
            self:UnregisterAllEvents()
        end
    end)
end