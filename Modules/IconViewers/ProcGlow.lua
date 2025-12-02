local ADDON_NAME, ns = ...
local NephUI = ns.Addon

NephUI.ProcGlow = NephUI.ProcGlow or {}
local ProcGlow = NephUI.ProcGlow

-- Get LibCustomGlow for glow effects
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- Track which icons currently have active glows
local activeGlowIcons = {}  -- [icon] = true

-- LibCustomGlow glow types
ProcGlow.LibCustomGlowTypes = {
    "Pixel Glow",
    "Autocast Shine",
    "Action Button Glow",
    "Proc Glow",
}

-- Get viewer padding for a button
local function GetViewerPadding(button)
    if not button then return 0 end
    
    -- Walk up the parent chain to find if this button is inside a viewer
    local frame = button
    local maxDepth = 10
    local depth = 0
    
    while frame and depth < maxDepth do
        local frameName = frame:GetName()
        if frameName and NephUI.viewers then
            for _, viewerName in ipairs(NephUI.viewers) do
                if frameName == viewerName then
                    local settings = NephUI.db.profile.viewers[viewerName]
                    if settings then
                        return settings.padding or 5
                    end
                end
            end
        end
        frame = frame:GetParent()
        depth = depth + 1
    end
    
    return 0
end

-- Get settings for proc glow (viewers only)
local function GetProcGlowSettings()
    local settings = NephUI.db.profile.viewers.general.procGlow
    if not settings or not settings.enabled then return nil end
    return settings
end

-- Apply LibCustomGlow effects
local function ApplyLibCustomGlow(icon, settings)
    if not LCG then return false end
    if not icon then return false end
    
    local glowType = settings.glowType or "Pixel Glow"
    local color = settings.loopColor or {0.95, 0.95, 0.32, 1}
    -- Ensure color has alpha
    if not color[4] then
        color[4] = 1
    end
    local lines = settings.lcgLines or 14
    local frequency = settings.lcgFrequency or 0.25
    local thickness = settings.lcgThickness or 2
    local baseXOffset = settings.lcgXOffset or -7
    local baseYOffset = settings.lcgYOffset or -7
    
    -- Get viewer padding to account for icon texture inset
    local padding = GetViewerPadding(icon)
    
    -- Adjust offsets to account for padding
    -- Padding insets the icon texture from the button frame
    -- Icon texture is at: button TOPLEFT + (padding, -padding) to button BOTTOMRIGHT + (-padding, padding)
    -- For the glow to align with the icon texture, we need to offset by padding
    -- baseXOffset: positive = expand outward from icon texture, negative = shrink inward
    -- We add padding so the glow aligns with the icon texture edge
    local xOffset = baseXOffset + padding
    local yOffset = baseYOffset + padding
    
    -- Use viewer glow key
    local glowKey = "_NephUICustomGlow"
    
    -- Stop any existing glow first
    ProcGlow:StopGlow(icon)
    
    -- Hide Blizzard's glow
    local region = icon.SpellActivationAlert
    if region then
        if region.ProcLoopFlipbook then
            region.ProcLoopFlipbook:Hide()
        end
        if region.ProcStartFlipbook then
            region.ProcStartFlipbook:Hide()
        end
    end
    
    if glowType == "Pixel Glow" then
        LCG.PixelGlow_Start(icon, color, lines, frequency, nil, thickness, 0, 0, true, glowKey)
        local glowFrame = icon["_PixelGlow" .. glowKey]
        if glowFrame then
            glowFrame:ClearAllPoints()
            -- xOffset: positive = expand outward, negative = shrink inward
            glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -xOffset, xOffset)
            glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", xOffset, -xOffset)
        end
    elseif glowType == "Autocast Shine" then
        LCG.AutoCastGlow_Start(icon, color, lines, frequency, 1, 0, 0, glowKey)
        local glowFrame = icon["_AutoCastGlow" .. glowKey]
        if glowFrame then
            glowFrame:ClearAllPoints()
            glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -xOffset, xOffset)
            glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", xOffset, -xOffset)
        end
    elseif glowType == "Action Button Glow" then
        LCG.ButtonGlow_Start(icon, color, frequency)
    elseif glowType == "Proc Glow" then
        LCG.ProcGlow_Start(icon, {
            color = color,
            startAnim = true,
            xOffset = xOffset,
            yOffset = yOffset,
            key = glowKey
        })
    end
    
    -- Flag that we have a custom glow active
    icon._NephUICustomGlowActive = true
    activeGlowIcons[icon] = true
    
    return true
end

-- Stop all glow effects on an icon
function ProcGlow:StopGlow(icon)
    if not icon then return end
    
    -- Stop LibCustomGlow effects (viewer key only)
    if LCG then
        pcall(LCG.PixelGlow_Stop, icon, "_NephUICustomGlow")
        pcall(LCG.AutoCastGlow_Stop, icon, "_NephUICustomGlow")
        pcall(LCG.ProcGlow_Stop, icon, "_NephUICustomGlow")
    end
    
    icon._NephUICustomGlowActive = nil
    activeGlowIcons[icon] = nil
end

-- Main function to start glow on a button (viewers only)
function ProcGlow:StartGlow(icon)
    if not icon then return end
    
    -- Skip action bar buttons - they're handled by ActionBarGlow
    local buttonName = icon:GetName() or ""
    if buttonName:match("ActionButton") or buttonName:match("MultiBar") or 
       buttonName:match("PetActionButton") or buttonName:match("StanceButton") then
        return
    end
    
    -- Already has our glow? Skip
    if icon._NephUICustomGlowActive then return end
    
    local settings = GetProcGlowSettings()
    if not settings then return end
    
    -- Always use LibCustomGlow
    if icon:IsShown() then
        ApplyLibCustomGlow(icon, settings)
    end
end

-- Hook function for ActionButtonSpellAlertManager:ShowAlert
local function Hook_ShowAlert(frame, button)
    local targetButton = button or frame
    if not targetButton then return end
    
    -- Skip action bar buttons - they're handled by ActionBarGlow
    local buttonName = targetButton:GetName() or ""
    if buttonName:match("ActionButton") or buttonName:match("MultiBar") or 
       buttonName:match("PetActionButton") or buttonName:match("StanceButton") then
        return
    end
    
    -- Handle different function signatures (viewers only)
    if ProcGlow.StartGlow then
        ProcGlow:StartGlow(targetButton)
    end
end

-- Hook into Blizzard's glow system
local function SetupGlowHooks()
    -- Hook ActionButton_ShowOverlayGlow - this is called when a proc happens
    if type(ActionButton_ShowOverlayGlow) == "function" then
        hooksecurefunc("ActionButton_ShowOverlayGlow", function(button)
            if not button then return end
            
            -- Skip action bar buttons - they're handled by ActionBarGlow
            local buttonName = button:GetName() or ""
            if buttonName:match("ActionButton") or buttonName:match("MultiBar") or 
               buttonName:match("PetActionButton") or buttonName:match("StanceButton") then
                return
            end
            
            -- Apply immediately (viewers only)
            if button:IsShown() then
                ProcGlow:StartGlow(button)
            end
        end)
    end
    
    -- Hook ActionButton_HideOverlayGlow - this is called when proc ends
    if type(ActionButton_HideOverlayGlow) == "function" then
        hooksecurefunc("ActionButton_HideOverlayGlow", function(button)
            if not button then return end
            
            -- Skip action bar buttons - they're handled by ActionBarGlow
            local buttonName = button:GetName() or ""
            if buttonName:match("ActionButton") or buttonName:match("MultiBar") or 
               buttonName:match("PetActionButton") or buttonName:match("StanceButton") then
                return
            end
            
            ProcGlow:StopGlow(button)
        end)
    end
    
    -- Also listen for spell activation events directly
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    eventFrame:SetScript("OnEvent", function(self, event, spellID)
        if not spellID then return end
        
        -- Find the icon with this spellID in our viewers
        local viewers = NephUI.viewers or {
            "EssentialCooldownViewer",
            "UtilityCooldownViewer",
            "BuffIconCooldownViewer",
        }
        
        for _, viewerName in ipairs(viewers) do
            local viewer = _G[viewerName]
            if viewer then
                local children = {viewer:GetChildren()}
                for _, child in ipairs(children) do
                    if child:IsShown() then
                        -- Wrap spell ID access and comparison in pcall to handle "secret" values
                        local matched = false
                        pcall(function()
                            local iconSpellID = child.spellID or child.SpellID or 
                                               (child.GetSpellID and child:GetSpellID())
                            if iconSpellID and iconSpellID == spellID then
                                matched = true
                            end
                        end)
                        
                        if matched then
                            if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
                                -- Apply immediately
                                ProcGlow:StartGlow(child)
                            else
                                ProcGlow:StopGlow(child)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Initialize the module
function ProcGlow:Initialize()
    local settings = GetProcGlowSettings()
    if not settings or not settings.enabled then return end
    
    -- Set up hooks immediately
    SetupGlowHooks()
    
    -- Hook into the spell alert manager (wait for it to be available)
    C_Timer.After(0.5, function()
        if ActionButtonSpellAlertManager then
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", Hook_ShowAlert)
        end
    end)
end

-- Refresh all proc glows (viewers only)
function ProcGlow:RefreshAll()
    local settings = GetProcGlowSettings()
    if not settings or not settings.enabled then return end
    
    -- Store which icons had glows before refresh
    local iconsWithGlows = {}
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            -- Only track viewer icons
            local buttonName = icon:GetName() or ""
            if not (buttonName:match("ActionButton") or buttonName:match("MultiBar") or 
                    buttonName:match("PetActionButton") or buttonName:match("StanceButton")) then
                iconsWithGlows[icon] = true
            end
        end
    end
    
    -- Stop all existing custom glows
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            self:StopGlow(icon)
        end
    end
    wipe(activeGlowIcons)
    
    -- Re-apply glows to icons that had them before (if settings allow)
    for icon, _ in pairs(iconsWithGlows) do
        if icon and icon:IsShown() then
            self:StartGlow(icon)
        end
    end
end
