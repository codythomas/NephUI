local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Get IconViewers module
local IconViewers = NephUI.IconViewers
if not IconViewers then
    error("NephUI: IconViewers module not initialized! Load IconViewers.lua first.")
end

-- Helper Functions

local function IsCooldownIconFrame(frame)
    return frame and (frame.icon or frame.Icon) and frame.Cooldown
end

local function StripBlizzardOverlay(icon)
    for _, region in ipairs({ icon:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            region:SetTexture("")
            region:Hide()
            region.Show = function() end
        end
    end
end

local function GetIconCountFont(icon)
    if not icon then return nil end

    -- 1. ChargeCount (charges)
    local charge = icon.ChargeCount
    if charge then
        local fs = charge.Current or charge.Text or charge.Count or nil

        if not fs and charge.GetRegions then
            for _, region in ipairs({ charge:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end

        if fs then
            return fs
        end
    end

    -- 2. Applications (Buff stacks)
    local apps = icon.Applications
    if apps and apps.GetRegions then
        for _, region in ipairs({ apps:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                return region
            end
        end
    end

    -- 3. Fallback: look for named stack text
    for _, region in ipairs({ icon:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            local name = region:GetName()
            if name and (name:find("Stack") or name:find("Applications")) then
                return region
            end
        end
    end

    return nil
end

local function CreateBorder(frame)
    if frame.border then return frame.border end

    local bord = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bord:SetPoint("TOPLEFT", frame, -1, 1)
    bord:SetPoint("BOTTOMRIGHT", frame, 1, -1)
    bord:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bord:SetBackdropBorderColor(0, 0, 0, 1)
    bord:SetFrameLevel(frame:GetFrameLevel() + 1)

    frame.border = bord
    return bord
end

-- Icon Skinning

function IconViewers:SkinIcon(icon, settings)
    -- Get the icon texture frame (handle both .icon and .Icon for compatibility)
    local iconTexture = icon.icon or icon.Icon
    if not icon or not iconTexture then return end

    -- Calculate icon dimensions from iconSize and aspectRatio (crop slider)
    local iconSize = settings.iconSize or 40
    -- Add 0.1 behind the scenes for better rendering (user cannot see or adjust this)
    iconSize = iconSize + 0.01
    local aspectRatioValue = 1.0 -- Default to square
    
    -- Get aspect ratio from crop slider or convert from string format
    if settings.aspectRatioCrop then
        aspectRatioValue = settings.aspectRatioCrop
    elseif settings.aspectRatio then
        -- Convert "16:9" format to numeric ratio
        local aspectW, aspectH = settings.aspectRatio:match("^(%d+%.?%d*):(%d+%.?%d*)$")
        if aspectW and aspectH then
            aspectRatioValue = tonumber(aspectW) / tonumber(aspectH)
        end
    end
    
    local iconWidth = iconSize
    local iconHeight = iconSize
    
    -- Calculate width/height based on aspect ratio value
    -- aspectRatioValue is width:height ratio (e.g., 1.78 for 16:9, 0.56 for 9:16)
    if aspectRatioValue and aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            -- Wider - width is longest, so width = iconSize
            iconWidth = iconSize
            iconHeight = iconSize / aspectRatioValue
        elseif aspectRatioValue < 1.0 then
            -- Taller - height is longest, so height = iconSize
            iconWidth = iconSize * aspectRatioValue
            iconHeight = iconSize
        end
    end
    
    local padding   = settings.padding or 5
    local zoom      = settings.zoom or 0
    local border    = icon.__CDM_Border
    local cdPadding = padding * 0.65

    -- This prevents stretching by cropping the texture to match the container aspect ratio
    iconTexture:ClearAllPoints()
    
    -- Fill the container
    iconTexture:SetPoint("TOPLEFT", icon, "TOPLEFT", padding, -padding)
    iconTexture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -padding, padding)
    
    -- Calculate texture coordinates based on aspect ratio to prevent stretching
    -- Use the same aspectRatioValue calculated above
    local left, right, top, bottom = 0, 1, 0, 1
    
    if aspectRatioValue and aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            -- Wider than tall (e.g., 1.78 for 16:9) - crop top/bottom
            local cropAmount = 1.0 - (1.0 / aspectRatioValue)
            local offset = cropAmount / 2.0
            top = offset
            bottom = 1.0 - offset
        elseif aspectRatioValue < 1.0 then
            -- Taller than wide (e.g., 0.56 for 9:16) - crop left/right
            local cropAmount = 1.0 - aspectRatioValue
            local offset = cropAmount / 2.0
            left = offset
            right = 1.0 - offset
        end
    end
    
    -- Apply zoom on top of aspect ratio crop
    if zoom > 0 then
        local currentWidth = right - left
        local currentHeight = bottom - top
        local visibleSize = 1.0 - (zoom * 2)
        
        local zoomedWidth = currentWidth * visibleSize
        local zoomedHeight = currentHeight * visibleSize
        
        local centerX = (left + right) / 2.0
        local centerY = (top + bottom) / 2.0
        
        left = centerX - (zoomedWidth / 2.0)
        right = centerX + (zoomedWidth / 2.0)
        top = centerY - (zoomedHeight / 2.0)
        bottom = centerY + (zoomedHeight / 2.0)
    end
    
    -- Apply texture coordinates - this zooms/crops instead of stretching
    iconTexture:SetTexCoord(left, right, top, bottom)
    
    -- Use SetWidth and SetHeight separately AND SetSize to ensure both dimensions are set independently
    icon:SetWidth(iconWidth)
    icon:SetHeight(iconHeight)
    -- Also call SetSize to ensure the frame properly registers the size change
    icon:SetSize(iconWidth, iconHeight)

    -- Cooldown glow
    if icon.CooldownFlash then
        icon.CooldownFlash:ClearAllPoints()
        icon.CooldownFlash:SetPoint("TOPLEFT", icon, "TOPLEFT", cdPadding, -cdPadding)
        icon.CooldownFlash:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cdPadding, cdPadding)
    end

    -- Cooldown swipe
    if icon.Cooldown then
        icon.Cooldown:ClearAllPoints()
        icon.Cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", cdPadding, -cdPadding)
        icon.Cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cdPadding, cdPadding)
    end

    -- Pandemic icon
    local picon = icon.PandemicIcon or icon.pandemicIcon or icon.Pandemic or icon.pandemic
    if not picon then
        for _, region in ipairs({ icon:GetChildren() }) do
            if region:GetName() and region:GetName():find("Pandemic") then
                picon = region
                break
            end
        end
    end

    if picon and picon.ClearAllPoints then
        picon:ClearAllPoints()
        picon:SetPoint("TOPLEFT", icon, "TOPLEFT", padding, -padding)
        picon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -padding, padding)
    end

    -- Out of range highlight
    local oor = icon.OutOfRange or icon.outOfRange or icon.oor
    if oor and oor.ClearAllPoints then
        oor:ClearAllPoints()
        oor:SetPoint("TOPLEFT", icon, "TOPLEFT", padding, -padding)
        oor:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -padding, padding)
    end

    -- Charge/stack text
    local fs = GetIconCountFont(icon)
    if fs and fs.ClearAllPoints then
        fs:ClearAllPoints()

        local point   = settings.chargeTextAnchor or "BOTTOMRIGHT"
        if point == "MIDDLE" then point = "CENTER" end
        
        local offsetX = settings.countTextOffsetX or 0
        local offsetY = settings.countTextOffsetY or 0

        fs:SetPoint(point, iconTexture, point, offsetX, offsetY)

        local desiredSize = settings.countTextSize
        if desiredSize and desiredSize > 0 then
            local font = NephUI:GetGlobalFont()
            fs:SetFont(font, desiredSize, "OUTLINE")
        end
    end

    -- Strip Blizzard overlay
    StripBlizzardOverlay(icon)

    -- Border
    if icon.IsForbidden and icon:IsForbidden() then
        icon.__cdmSkinned = true
        return
    end

    -- Don't create or modify border during combat to avoid secret value errors
    if InCombatLockdown() then
        -- Mark that border needs to be created/updated after combat
        icon.__cdmBorderPending = true
        -- Mark as skinned (everything except border is done) so it doesn't get re-processed
        icon.__cdmSkinned = true
        icon.__cdmSkinPending = nil
        return
    end

    if not border then
        border = CreateFrame("Frame", nil, icon, "BackdropTemplate")
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 0, 0)
        icon.__CDM_Border = border
        icon.__cdmBorderPending = nil
    end

    local edgeSize = tonumber(settings.borderSize) or 1
    
    -- Helper function to safely set backdrop (defers in combat to avoid secret value errors)
    local function SafeSetBackdrop(frame, backdropInfo)
        if not frame or not frame.SetBackdrop then return false end
        
        -- If in combat, defer backdrop setup to avoid secret value errors from GetWidth/GetHeight
        if InCombatLockdown() then
            -- Defer until out of combat
            -- Check if already pending by checking if frame is in pending table
            local alreadyPending = NephUI.__cdmPendingBackdrops and NephUI.__cdmPendingBackdrops[frame]
            if not alreadyPending then
                frame.__cdmBackdropPending = backdropInfo  -- Can be nil to remove backdrop
                frame.__cdmBackdropSettings = settings
                
                -- Create or reuse event frame for deferred backdrop setup
                if not NephUI.__cdmBackdropEventFrame then
                    local eventFrame = CreateFrame("Frame")
                    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                    eventFrame:SetScript("OnEvent", function(self)
                        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                        -- Process all pending backdrops
                        for pendingFrame in pairs(NephUI.__cdmPendingBackdrops or {}) do
                            if pendingFrame then
                                -- Frame is in pending table, so process it (backdropInfo could be nil to remove backdrop)
                                local pendingInfo = pendingFrame.__cdmBackdropPending
                                local pendingSettings = pendingFrame.__cdmBackdropSettings
                                if not InCombatLockdown() then
                                    -- Check if frame dimensions are safe before setting backdrop
                                    local widthOk, width = pcall(pendingFrame.GetWidth, pendingFrame)
                                    local heightOk, height = pcall(pendingFrame.GetHeight, pendingFrame)
                                    local dimensionsOk = false
                                    if widthOk and heightOk and width and height then
                                        local testOk = pcall(function() return width + height end)
                                        dimensionsOk = testOk and width > 0 and height > 0
                                    end
                                    
                                    if dimensionsOk then
                                        local ok = pcall(pendingFrame.SetBackdrop, pendingFrame, pendingInfo)
                                        if ok then
                                            if pendingInfo then
                                                -- Setting a backdrop
                                                pendingFrame:Show()
                                                -- Always set border color (use same fallback as normal path: black)
                                                if pendingSettings then
                                                    local r, g, b, a = unpack(pendingSettings.borderColor or { 0, 0, 0, 1 })
                                                    pendingFrame:SetBackdropBorderColor(r, g, b, a or 1)
                                                else
                                                    -- Fallback to black if no settings
                                                    pendingFrame:SetBackdropBorderColor(0, 0, 0, 1)
                                                end
                                            else
                                                -- Removing backdrop (nil)
                                                pendingFrame:Hide()
                                            end
                                        end
                                    end
                                    pendingFrame.__cdmBackdropPending = nil
                                    pendingFrame.__cdmBackdropSettings = nil
                                end
                            end
                        end
                        NephUI.__cdmPendingBackdrops = {}
                    end)
                    NephUI.__cdmBackdropEventFrame = eventFrame
                end
                
                -- Track this frame for deferred processing
                NephUI.__cdmPendingBackdrops = NephUI.__cdmPendingBackdrops or {}
                NephUI.__cdmPendingBackdrops[frame] = true
                NephUI.__cdmBackdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
            return false
        end
        
        -- Safe to set backdrop now (not in combat)
        -- But first check if frame dimensions are accessible (not tainted/secret values)
        local widthOk, width = pcall(frame.GetWidth, frame)
        local heightOk, height = pcall(frame.GetHeight, frame)
        
        -- Check if dimensions are secret values by trying arithmetic (secret values will error)
        local dimensionsOk = false
        if widthOk and heightOk and width and height then
            local testOk = pcall(function() return width + height end)
            dimensionsOk = testOk and width > 0 and height > 0
        end
        
        -- If we can't get dimensions safely or they're secret values, defer the backdrop setup
        if not dimensionsOk then
            -- Frame might be tainted or not properly sized, defer backdrop
            local alreadyPending = NephUI.__cdmPendingBackdrops and NephUI.__cdmPendingBackdrops[frame]
            if not alreadyPending then
                frame.__cdmBackdropPending = backdropInfo
                frame.__cdmBackdropSettings = settings
                
                if not NephUI.__cdmBackdropEventFrame then
                    local eventFrame = CreateFrame("Frame")
                    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                    eventFrame:SetScript("OnEvent", function(self)
                        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                        for pendingFrame in pairs(NephUI.__cdmPendingBackdrops or {}) do
                            if pendingFrame then
                                local pendingInfo = pendingFrame.__cdmBackdropPending
                                local pendingSettings = pendingFrame.__cdmBackdropSettings
                                if not InCombatLockdown() then
                                    -- Check if frame dimensions are safe before setting backdrop
                                    local widthOk, width = pcall(pendingFrame.GetWidth, pendingFrame)
                                    local heightOk, height = pcall(pendingFrame.GetHeight, pendingFrame)
                                    local dimensionsOk = false
                                    if widthOk and heightOk and width and height then
                                        local testOk = pcall(function() return width + height end)
                                        dimensionsOk = testOk and width > 0 and height > 0
                                    end
                                    
                                    if dimensionsOk then
                                        local ok = pcall(pendingFrame.SetBackdrop, pendingFrame, pendingInfo)
                                        if ok then
                                            if pendingInfo then
                                                pendingFrame:Show()
                                                if pendingSettings then
                                                    local r, g, b, a = unpack(pendingSettings.borderColor or { 0, 0, 0, 1 })
                                                    pendingFrame:SetBackdropBorderColor(r, g, b, a or 1)
                                                else
                                                    pendingFrame:SetBackdropBorderColor(0, 0, 0, 1)
                                                end
                                            else
                                                pendingFrame:Hide()
                                            end
                                        end
                                    end
                                    pendingFrame.__cdmBackdropPending = nil
                                    pendingFrame.__cdmBackdropSettings = nil
                                end
                            end
                        end
                        NephUI.__cdmPendingBackdrops = {}
                    end)
                    NephUI.__cdmBackdropEventFrame = eventFrame
                end
                
                NephUI.__cdmPendingBackdrops = NephUI.__cdmPendingBackdrops or {}
                NephUI.__cdmPendingBackdrops[frame] = true
                NephUI.__cdmBackdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
            return false
        end
        
        return pcall(frame.SetBackdrop, frame, backdropInfo)
    end
    
    if edgeSize <= 0 then
        if border.SetBackdrop then
            SafeSetBackdrop(border, nil)
        end
        border:Hide()
    else
        if border.SetBackdrop then
            local backdropInfo = {
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = edgeSize,
            }
            local ok = SafeSetBackdrop(border, backdropInfo)
            if ok then
                border:Show()
                local r, g, b, a = unpack(settings.borderColor or { 0, 0, 0, 1 })
                border:SetBackdropBorderColor(r, g, b, a or 1)
            else
                -- If deferred, hide for now (will show when backdrop is set)
                if not border.__cdmBackdropPending then
                    border:Hide()
                end
            end
        end
    end

    icon.__cdmSkinned = true
    icon.__cdmSkinPending = nil  -- Clear pending flag on successful skin
end

function IconViewers:SkinAllIconsInViewer(viewer)
    if not viewer or not viewer.GetName then return end

    local name     = viewer:GetName()
    local settings = NephUI.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    local container = viewer.viewerFrame or viewer
    local children  = { container:GetChildren() }

    for _, icon in ipairs(children) do
        if IsCooldownIconFrame(icon) and (icon.icon or icon.Icon) then
            local ok, err = pcall(self.SkinIcon, self, icon, settings)
            if not ok then
                icon.__cdmSkinError = true
                print("|cffff4444[NephUI] SkinIcon error for", name, "icon:", err, "|r")
            end
        end
    end
end

-- Expose to main addon for backwards compatibility
NephUI.SkinIcon = function(self, icon, settings) return IconViewers:SkinIcon(icon, settings) end
NephUI.SkinAllIconsInViewer = function(self, viewer) return IconViewers:SkinAllIconsInViewer(viewer) end

-- Hook to update proc glow when icons are skinned (aspect ratio changes)
if NephUI.ProcGlow and NephUI.ProcGlow.UpdateButtonGlow then
    local originalSkinIcon = IconViewers.SkinIcon
    function IconViewers:SkinIcon(icon, settings)
        local result = originalSkinIcon(self, icon, settings)
        
        -- Update proc glow if this icon has one (after aspect ratio is applied)
        if icon and icon.SpellActivationAlert then
            C_Timer.After(0.01, function()
                if NephUI.ProcGlow and NephUI.ProcGlow.UpdateButtonGlow then
                    NephUI.ProcGlow:UpdateButtonGlow(icon)
                end
            end)
        end
        
        return result
    end
end

