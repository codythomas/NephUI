local ADDON_NAME, ns = ...
local NephUI = ns.Addon

NephUI.BuffDebuffFrames = NephUI.BuffDebuffFrames or {}
local BDF = NephUI.BuffDebuffFrames

local LSM = LibStub("LibSharedMedia-3.0")

-- Cache for styled auras to avoid re-styling
local styledAuras = {}

-- Create custom border overlay using textures instead of backdrop
local function CreateAuraBorderOverlay(auraFrame)
    if auraFrame.__nephuiBorderOverlay then return end
    
    local overlay = CreateFrame("Frame", nil, auraFrame)
    overlay:SetAllPoints(auraFrame.Icon or auraFrame)
    overlay:SetFrameLevel((auraFrame:GetFrameLevel() or 0) + 15)
    
    -- Create border textures for all four edges
    local edges = {"Top", "Bottom", "Left", "Right"}
    overlay.textures = {}
    
    for _, edge in ipairs(edges) do
        local tex = overlay:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(0, 0, 0, 1)
        overlay.textures[edge] = tex
        
        if edge == "Top" then
            tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", -1, 1)
            tex:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 1, 1)
            tex:SetHeight(1)
        elseif edge == "Bottom" then
            tex:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", -1, -1)
            tex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 1, -1)
            tex:SetHeight(1)
        elseif edge == "Left" then
            tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", -1, 1)
            tex:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", -1, -1)
            tex:SetWidth(1)
        elseif edge == "Right" then
            tex:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 1, 1)
            tex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 1, -1)
            tex:SetWidth(1)
        end
    end
    
    auraFrame.__nephuiBorderOverlay = overlay
end

-- Apply styling to a single aura frame
local function EnhanceAuraFrame(auraFrame, config)
    if not auraFrame or not config then return end
    if styledAuras[auraFrame] then return end
    
    local icon = auraFrame.Icon
    if not icon then return end
    
    -- Skip anchor frames
    if auraFrame.isAuraAnchor then return end
    
    -- Apply icon modifications
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    local iconSize = config.iconSize or 36
    icon:SetSize(iconSize, iconSize)
    
    -- Hide default borders
    if auraFrame.DebuffBorder then
        auraFrame.DebuffBorder:SetTexture(nil)
    end
    if auraFrame.BuffBorder then
        auraFrame.BuffBorder:SetTexture(nil)
    end
    if auraFrame.TempEnchantBorder then
        auraFrame.TempEnchantBorder:SetTexture(nil)
    end
    
    -- Create our custom border overlay
    CreateAuraBorderOverlay(auraFrame)
    
    -- Style duration text
    if auraFrame.Duration and config.duration then
        local durConfig = config.duration
        
        -- Check if duration text is enabled
        if durConfig.enabled ~= false then
            local font = NephUI:GetGlobalFont()
            
            auraFrame.Duration:ClearAllPoints()
            
            local anchorPoint = durConfig.anchorPoint or "BOTTOM"
            local offsetX = durConfig.offsetX or 0
            local offsetY = durConfig.offsetY or -2
            
            auraFrame.Duration:SetPoint(anchorPoint, icon, anchorPoint, offsetX, offsetY)
            auraFrame.Duration:SetFont(font, durConfig.fontSize or 12, durConfig.fontFlag or "OUTLINE")
            auraFrame.Duration:SetShadowOffset(0, 0)
            
            local textColor = durConfig.textColor or {1, 1, 1, 1}
            auraFrame.Duration:SetTextColor(
                textColor[1] or 1,
                textColor[2] or 1,
                textColor[3] or 1,
                textColor[4] or 1
            )
            
            auraFrame.Duration:Show()
        else
            auraFrame.Duration:Hide()
        end
    end
    
    -- Style count text
    if auraFrame.Count and config.count then
        local countConfig = config.count
        
        -- Check if count text is enabled
        if countConfig.enabled ~= false then
            local font = NephUI:GetGlobalFont()
            
            auraFrame.Count:ClearAllPoints()
            
            local anchorPoint = countConfig.anchorPoint or "TOPRIGHT"
            local offsetX = countConfig.offsetX or 0
            local offsetY = countConfig.offsetY or 0
            
            auraFrame.Count:SetPoint(anchorPoint, icon, anchorPoint, offsetX, offsetY)
            auraFrame.Count:SetFont(font, countConfig.fontSize or 12, countConfig.fontFlag or "OUTLINE")
            
            local textColor = countConfig.textColor or {1, 1, 1, 1}
            auraFrame.Count:SetTextColor(
                textColor[1] or 1,
                textColor[2] or 1,
                textColor[3] or 1,
                textColor[4] or 1
            )
            
            auraFrame.Count:Show()
        else
            auraFrame.Count:Hide()
        end
    end
    
    styledAuras[auraFrame] = true
end

local function ApplyGridLayout(auraFrames, container, iconSize, layoutConfig)
    if not auraFrames or not container then return end
    
    local db = NephUI.db.profile.buffDebuffFrames
    if not db then return end
    
    iconSize = iconSize or 38
    
    -- Use provided layout config, fall back to global layout if type-specific doesn't exist
    local layout = layoutConfig
    if not layout or not layout.iconsPerRow then
        -- Fall back to global layout if type-specific doesn't exist
        layout = db.layout or {}
    end
    
    -- Convert auraFrames table to array for easier indexing
    local auraArray = {}
    for _, aura in pairs(auraFrames) do
        if aura and aura:IsShown() and not aura.isAuraAnchor then
            table.insert(auraArray, aura)
        end
    end
    
    if #auraArray == 0 then return end
    
    local iconsPerRow = layout.iconsPerRow or 15
    local iconSpacing = layout.iconSpacing or 11
    local rowSpacing = layout.rowSpacing or 1
    local anchorSide = layout.anchorSide or "TOPRIGHT"
    
    -- Clear all points first
    for _, aura in ipairs(auraArray) do
        aura:ClearAllPoints()
    end
    
    -- Position each aura relative to container or previous aura
    local rowAnchors = {} -- Track the first aura in each row
    
    for i = 1, #auraArray do
        local aura = auraArray[i]
        local rowIndex = math.floor((i - 1) / iconsPerRow)
        local colIndex = (i - 1) % iconsPerRow
        
        if colIndex == 0 then
            -- First aura in row - anchor to container or previous row
            if rowIndex == 0 then
                -- First row - anchor to container
                aura:SetPoint(anchorSide, container, anchorSide, 0, 0)
            else
                -- Subsequent rows - anchor below previous row's first aura
                local prevRowAnchor = rowAnchors[rowIndex]
                if prevRowAnchor then
                    aura:SetPoint("TOPRIGHT", prevRowAnchor, "BOTTOMRIGHT", 0, -rowSpacing)
                end
            end
            rowAnchors[rowIndex + 1] = aura
        else
            -- Same row - anchor to previous aura in row
            local prevAura = auraArray[i - 1]
            if prevAura then
                aura:SetPoint("TOPRIGHT", prevAura, "TOPLEFT", -iconSpacing, 0)
            end
        end
    end
end

-- Process all buff frames
local function ProcessBuffFrames()
    local db = NephUI.db.profile.buffDebuffFrames
    if not db or not db.enabled then return end
    
    local buffConfig = db.buffs or {}
    if buffConfig.enabled == false then return end
    
    if not BuffFrame or not BuffFrame.auraFrames then return end
    
    local layoutConfig = buffConfig.layout
    
    -- Hide collapse button
    if BuffFrame.CollapseAndExpandButton then
        BuffFrame.CollapseAndExpandButton:SetAlpha(0)
        BuffFrame.CollapseAndExpandButton:SetScript("OnClick", nil)
    end
    
    -- Style each buff frame
    for _, auraFrame in pairs(BuffFrame.auraFrames) do
        EnhanceAuraFrame(auraFrame, buffConfig)
    end
    
    -- Apply grid layout
    local iconSize = buffConfig.iconSize or 36
    ApplyGridLayout(BuffFrame.auraFrames, BuffFrame, iconSize, layoutConfig)
end

-- Process all debuff frames
local function ProcessDebuffFrames()
    local db = NephUI.db.profile.buffDebuffFrames
    if not db or not db.enabled then return end
    
    local debuffConfig = db.debuffs or {}
    if debuffConfig.enabled == false then return end
    
    if not DebuffFrame or not DebuffFrame.auraFrames then return end
    
    local layoutConfig = debuffConfig.layout
    
    -- Style each debuff frame
    for _, auraFrame in pairs(DebuffFrame.auraFrames) do
        EnhanceAuraFrame(auraFrame, debuffConfig)
    end
    
    -- Apply grid layout
    local iconSize = debuffConfig.iconSize or 36
    ApplyGridLayout(DebuffFrame.auraFrames, DebuffFrame, iconSize, layoutConfig)
end

-- Hook into aura update functions
local function HookAuraUpdates()
    -- Hook buff frame updates
    if BuffFrame and BuffFrame.UpdateAuraButtons then
        hooksecurefunc(BuffFrame, "UpdateAuraButtons", function()
            C_Timer.After(0.1, function()
                ProcessBuffFrames()
            end)
        end)
    end
    
    -- Hook debuff frame updates
    if DebuffFrame and DebuffFrame.UpdateAuraButtons then
        hooksecurefunc(DebuffFrame, "UpdateAuraButtons", function()
            C_Timer.After(0.1, function()
                ProcessDebuffFrames()
            end)
        end)
    end
    
    -- Hook the generic aura update function if it exists
    if C_Timer and BuffFrame then
        local ticker = C_Timer.NewTicker(0.5, function()
            ProcessBuffFrames()
            ProcessDebuffFrames()
        end)
        BDF._updateTicker = ticker
    end
end

-- Hook edit mode
local function HookEditMode()
    if EditModeManagerFrame then
        local function RefreshOnEditMode()
            C_Timer.After(0.2, function()
                ProcessBuffFrames()
                ProcessDebuffFrames()
            end)
        end
        
        if EditModeManagerFrame.RegisterCallback then
            EditModeManagerFrame:RegisterCallback("EditModeEnter", RefreshOnEditMode)
            EditModeManagerFrame:RegisterCallback("EditModeExit", RefreshOnEditMode)
        end
        
        -- Fallback hooks
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", RefreshOnEditMode)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", RefreshOnEditMode)
    end
end

-- Initialize the module
function BDF:Initialize()
    local db = NephUI.db.profile.buffDebuffFrames
    if not db or not db.enabled then return end
    
    -- Wait for frames to be ready
    C_Timer.After(1.0, function()
        ProcessBuffFrames()
        ProcessDebuffFrames()
        HookAuraUpdates()
        HookEditMode()
    end)
end

-- Refresh all frames
function BDF:RefreshAll()
    styledAuras = {} -- Clear cache
    
    -- Clean up ticker if it exists
    if BDF._updateTicker then
        BDF._updateTicker:Cancel()
        BDF._updateTicker = nil
    end
    
    if NephUI.db.profile.buffDebuffFrames and NephUI.db.profile.buffDebuffFrames.enabled then
        ProcessBuffFrames()
        ProcessDebuffFrames()
        HookAuraUpdates()
    end
end

