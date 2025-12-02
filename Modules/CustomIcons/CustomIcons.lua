local ADDON_NAME, ns = ...
local NephUI = ns.Addon

NephUI.CustomIcons = NephUI.CustomIcons or {}
local CustomIcons = NephUI.CustomIcons

local customItemIcons = {}

local function ApplyCustomIconBorder(iconFrame, settings)
    if not iconFrame or not iconFrame.border then return end
    
    local border = iconFrame.border
    local edgeSize = settings.borderSize or 0
    
    local function SafeSetBackdrop(frame, backdropInfo)
        if InCombatLockdown() then
            if not NephUI.__cdmPendingBackdrops then
                NephUI.__cdmPendingBackdrops = {}
            end
            NephUI.__cdmPendingBackdrops[frame] = true
            
            if not NephUI.__cdmBackdropEventFrame then
                local eventFrame = CreateFrame("Frame")
                eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                eventFrame:SetScript("OnEvent", function(self)
                    if NephUI.__cdmPendingBackdrops then
                        for pendingFrame, _ in pairs(NephUI.__cdmPendingBackdrops) do
                            if pendingFrame and pendingFrame:IsVisible() then
                                local settings = pendingFrame.__cdmBackdropSettings
                                if settings then
                                    if settings.backdropInfo then
                                        pcall(pendingFrame.SetBackdrop, pendingFrame, settings.backdropInfo)
                                        if settings.borderColor then
                                            pcall(pendingFrame.SetBackdropBorderColor, pendingFrame, unpack(settings.borderColor))
                                        end
                                    else
                                        pcall(pendingFrame.Hide, pendingFrame)
                                    end
                                end
                                pendingFrame.__cdmBackdropPending = nil
                                pendingFrame.__cdmBackdropSettings = nil
                            end
                        end
                        NephUI.__cdmPendingBackdrops = {}
                    end
                end)
                NephUI.__cdmBackdropEventFrame = eventFrame
            end
            
            border.__cdmBackdropPending = true
            border.__cdmBackdropSettings = {
                backdropInfo = backdropInfo,
                borderColor = settings.borderColor
            }
            NephUI.__cdmBackdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
                if not border.__cdmBackdropPending then
                    border:Hide()
                end
            end
        end
    end
end

-- Create a custom item icon
local function CreateCustomItemIcon(itemID, parent)
    if not itemID or not parent then return nil end
    
    -- Try to get fresh item info
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
    
    -- If not available, request it and return nil (will retry later)
    if not itemName then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    
    -- Create button frame (matches Blizzard's cooldown frame structure)
    local frame = CreateFrame("Button", "NephUI_CustomItem_" .. itemID, parent)
    frame:SetSize(40, 40)
    
    -- Create icon texture (main artwork layer)
    local icon = frame:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(frame)
    icon:SetTexture(itemTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Zoom in by 8% on all sides
    
    -- Create border frame (for custom borders)
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    border:Hide()  -- Will be shown when border is applied
    
    -- Create cooldown frame overlay
    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints(frame)
    cd:SetDrawEdge(true)
    cd:SetDrawSwipe(true)
    cd:SetSwipeColor(0, 0, 0, 0.8)
    cd:SetHideCountdownNumbers(false)
    cd:SetReverse(false)
    
    -- Count text (lower right corner) - positioned above border
    -- Create a separate frame for count text at higher frame level than border
    local countTextFrame = CreateFrame("Frame", nil, frame)
    countTextFrame:SetAllPoints(frame)
    countTextFrame:SetFrameLevel(frame:GetFrameLevel() + 2)  -- Higher than border (which is at +1)
    
    local countText = countTextFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetJustifyH("RIGHT")
    countText:SetTextColor(1, 1, 1, 1)
    countText:SetShadowOffset(0, 0)
    countText:SetShadowColor(0, 0, 0, 1)
    
    local settings = NephUI.db.profile.customIcons
    local fontSize = (settings and settings.countTextSize) or 16
    local countTextX = (settings and settings.countTextX) or -2
    local countTextY = (settings and settings.countTextY) or 2
    local fontPath = NephUI:GetGlobalFont()
    
    countText:SetFont(fontPath, fontSize, "OUTLINE")
    countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", countTextX, countTextY)
    
    frame._NephUI_customItem = true
    frame._NephUI_itemID = itemID
    frame._NephUI_itemName = itemName
    frame.icon = icon
    frame.Icon = icon
    frame.cooldown = cd
    frame.Cooldown = cd
    frame.count = countText
    frame.border = border
    frame.Border = border
    
    frame:EnableMouse(true)
    
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and self:GetParent() then
            self:GetParent():StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        if self:GetParent() then
            self:GetParent():StopMovingOrSizing()
        end
    end)
    
    return frame
end

local function UpdateCustomItemCooldown(itemID, iconFrame)
    if not iconFrame or not iconFrame.cooldown or not iconFrame.icon then return end
    
    local isEquippedItem = iconFrame._NephUI_slotID ~= nil
    
    local start, duration, enable = GetItemCooldown(itemID)
    local isOnCooldown = false
    
    if duration and duration > 1.5 then
        local currentTime = GetTime()
        local endTime = start + duration
        if currentTime < endTime then
            isOnCooldown = true
        end
        
        if not iconFrame._lastCooldownDuration or math.abs(iconFrame._lastCooldownDuration - duration) > 0.1 then
            iconFrame.cooldown:SetCooldown(start, duration)
            iconFrame._lastCooldownDuration = duration
        else
            iconFrame.cooldown:SetCooldown(start, duration)
        end
    else
        if iconFrame._lastCooldownDuration then
            iconFrame.cooldown:Clear()
            iconFrame._lastCooldownDuration = nil
        end
    end
    
    -- Handle icon appearance based on equipped status and cooldown
    if isEquippedItem then
        -- For equipped items, hide count
        if iconFrame.count then
            iconFrame.count:Hide()
        end
        
        -- Desaturate when on cooldown, otherwise show normally
        if isOnCooldown then
            iconFrame.icon:SetDesaturated(true)
            iconFrame.icon:SetAlpha(1.0)
        else
            iconFrame.icon:SetDesaturated(false)
            iconFrame.icon:SetAlpha(1.0)
        end
    else
        -- Check if player has item in bags
        local itemCount = C_Item.GetItemCount(itemID, false, false, false)
        
        -- Always show count (including 0)
        if iconFrame.count then
            iconFrame.count:SetText(itemCount)
            iconFrame.count:Show()
            
            -- Color code the count
            if itemCount == 0 then
                iconFrame.count:SetTextColor(0.5, 0.5, 0.5, 1)  -- Gray when 0
            else
                iconFrame.count:SetTextColor(1, 1, 1, 1)  -- White when > 0
            end
        end
        
        -- Desaturate icon if on cooldown OR no items in bags
        if isOnCooldown or itemCount == 0 then
            iconFrame.icon:SetDesaturated(true)
            if itemCount == 0 then
                iconFrame.icon:SetAlpha(0.5)  -- Dim if no items
            else
                iconFrame.icon:SetAlpha(1.0)  -- Full alpha if on cooldown but have items
            end
        else
            iconFrame.icon:SetDesaturated(false)
            iconFrame.icon:SetAlpha(1.0)
        end
    end
end

-- Update all custom item cooldowns
local function UpdateAllCustomItemCooldowns()
    for itemID, iconFrame in pairs(customItemIcons) do
        UpdateCustomItemCooldown(itemID, iconFrame)
    end
    
    -- Also update trinket/weapon slot icons (handled by Trinkets module)
    if CustomIcons.UpdateTrinketCooldowns then
        CustomIcons:UpdateTrinketCooldowns()
    end
end

-- Check if an item is usable by the player
local function IsItemUsable(itemID)
    if not itemID then return false end
    
    -- Use C_Item.IsUsableItem if available (retail WoW/Beta)
    if C_Item and C_Item.IsUsableItem then
        return C_Item.IsUsableItem(itemID) == true
    end
    
    -- Fallback: check if item exists and is obtainable
    local itemName = GetItemInfo(itemID)
    return itemName ~= nil
end

-- Helper function to get anchor frame
local function GetAnchorFrame(anchorName)
    if not anchorName or anchorName == "" then
        return UIParent
    end
    local frame = _G[anchorName]
    if frame then
        return frame
    end
    return nil  -- Return nil if frame doesn't exist yet (instead of UIParent)
end

-- Export functions for use in other CustomIcons files
CustomIcons.customItemIcons = customItemIcons
CustomIcons.CreateCustomItemIcon = CreateCustomItemIcon
CustomIcons.UpdateCustomItemCooldown = UpdateCustomItemCooldown
CustomIcons.UpdateAllCustomItemCooldowns = UpdateAllCustomItemCooldowns
CustomIcons.IsItemUsable = IsItemUsable
CustomIcons.GetAnchorFrame = GetAnchorFrame
CustomIcons.ApplyCustomIconBorder = ApplyCustomIconBorder

-- MAIN CUSTOM ICONS FUNCTIONS

function CustomIcons:CreateCustomIconsTrackerFrame()
    if NephUI.customIconsTrackerFrame then return NephUI.customIconsTrackerFrame end
    
    local db = NephUI.db.profile.customIcons
    if not db or not db.enabled then return nil end
    
    local frame = CreateFrame("Frame", "NephUI_CustomIconsTrackerFrame", UIParent)
    frame:SetSize(200, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    
    -- Default position
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    
    frame._NephUI_CustomIconsTracker = true
    
    NephUI.customIconsTrackerFrame = frame
    
    -- Load and create icons for tracked items
    if db.trackedItems then
        for _, itemID in ipairs(db.trackedItems) do
            local icon = CreateCustomItemIcon(itemID, frame)
            if icon then
                customItemIcons[itemID] = icon
                UpdateCustomItemCooldown(itemID, icon)
            else
                -- Item data not loaded yet, retry after a delay
                C_Timer.After(1, function()
                    if not customItemIcons[itemID] then
                        local retryIcon = CreateCustomItemIcon(itemID, frame)
                        if retryIcon then
                            customItemIcons[itemID] = retryIcon
                            UpdateCustomItemCooldown(itemID, retryIcon)
                            if self.ApplyCustomIconsLayout then
                                self:ApplyCustomIconsLayout()
                            end
                        end
                    end
                end)
            end
        end
    end
    
    -- Rebuild GUI list after loading items (only if config is open)
    C_Timer.After(0.5, function()
        local AceConfigDialog = LibStub("AceConfigDialog-3.0")
        if AceConfigDialog and AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[ADDON_NAME] then
            if NephUI.RebuildTrackedItemsList then
                NephUI:RebuildTrackedItemsList()
            end
        end
    end)
    
    -- Apply layout
    if self.ApplyCustomIconsLayout then
        self:ApplyCustomIconsLayout()
    end
    
    -- Update cooldowns periodically
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.1 then  -- Update every 0.1 seconds
            self.elapsed = 0
            UpdateAllCustomItemCooldowns()
        end
    end)
    
    return frame
end

-- Update count text styling for all custom item icons
function CustomIcons:UpdateCountTextStyling()
    local settings = NephUI.db.profile.customIcons
    if not settings then return end
    
    local fontSize = settings.countTextSize or 16
    local countTextX = settings.countTextX or -2
    local countTextY = settings.countTextY or 2
    local fontPath = NephUI:GetGlobalFont()
    
    for itemID, iconFrame in pairs(customItemIcons) do
        if iconFrame and iconFrame.count then
            local countText = iconFrame.count
            countText:SetFont(fontPath, fontSize, "OUTLINE")
            countText:SetShadowOffset(0, 0)
            countText:ClearAllPoints()
            countText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", countTextX, countTextY)
        end
    end
end

function CustomIcons:ApplyCustomIconsLayout()
    if not NephUI.customIconsTrackerFrame then return end
    
    local db = NephUI.db.profile.customIcons
    if not db or not db.enabled then return end
    
    local settings = db.items or {}
    local container = NephUI.customIconsTrackerFrame
    local icons = {}
    
    -- Collect all icon frames in tracked order
    local hideUnusable = settings.hideUnusableItems or false
    if db.trackedItems then
        for _, itemID in ipairs(db.trackedItems) do
            local icon = customItemIcons[itemID]
            if icon then
                -- Check if we should hide unusable items
                if hideUnusable then
                    if IsItemUsable(itemID) then
                        table.insert(icons, icon)
                        icon:Show()  -- Ensure it's shown if usable
                    else
                        icon:Hide()  -- Hide if not usable
                    end
                else
                    table.insert(icons, icon)
                    icon:Show()  -- Show all items when toggle is disabled
                end
            end
        end
    end
    
    local count = #icons
    if count == 0 then return end
    
    -- Get settings
    local iconSize = settings.iconSize or 40
    local spacing = settings.spacing or -9
    local rowLimit = settings.rowLimit or 0
    local growthDirection = settings.growthDirection or "Centered"
    local aspectRatioValue = settings.aspectRatioCrop or 1.0
    
    -- Calculate icon dimensions with aspect ratio
    local iconWidth = iconSize
    local iconHeight = iconSize
    if aspectRatioValue > 1.0 then
        -- Wider than tall
        iconHeight = iconSize / aspectRatioValue
    elseif aspectRatioValue < 1.0 then
        -- Taller than wide
        iconWidth = iconSize * aspectRatioValue
    end
    
    -- Apply borders and set icon sizes
    for _, icon in ipairs(icons) do
        icon:SetSize(iconWidth, iconHeight)
        icon:ClearAllPoints()
        -- Apply border
        ApplyCustomIconBorder(icon, settings)
    end
    
    -- Handle anchoring
    local anchorFrame = GetAnchorFrame(settings.anchorFrame)
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 0
    
    -- Position container relative to anchor frame
    if anchorFrame and anchorFrame ~= UIParent then
        container:ClearAllPoints()
        container:SetPoint("CENTER", anchorFrame, "CENTER", offsetX, offsetY)
    elseif settings.anchorFrame and settings.anchorFrame ~= "" then
        -- Anchor frame specified but doesn't exist yet - retry after a delay
        C_Timer.After(0.5, function()
            if self.ApplyCustomIconsLayout then
                self:ApplyCustomIconsLayout()
            end
        end)
        return  -- Don't apply layout yet, wait for anchor frame
    else
        -- Default position if no anchor
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY - 200)
    end
    
    -- Apply layout based on growth direction
    if rowLimit <= 0 then
        -- Single row
        local totalWidth = count * iconWidth + (count - 1) * spacing
        local startX
        
        if growthDirection == "Left" then
            -- Left growth: first icon at center, others grow left
            startX = iconWidth / 2
            for i, icon in ipairs(icons) do
                local x = startX - (i - 1) * (iconWidth + spacing)
                icon:SetPoint("CENTER", container, "CENTER", x, 0)
                icon:Show()
            end
        elseif growthDirection == "Right" then
            -- Right growth: first icon at center, others grow right
            startX = -iconWidth / 2
            for i, icon in ipairs(icons) do
                local x = startX + (i - 1) * (iconWidth + spacing)
                icon:SetPoint("CENTER", container, "CENTER", x, 0)
                icon:Show()
            end
        else
            -- Centered (default)
            startX = -totalWidth / 2 + iconWidth / 2
            for i, icon in ipairs(icons) do
                local x = startX + (i - 1) * (iconWidth + spacing)
                icon:SetPoint("CENTER", container, "CENTER", x, 0)
                icon:Show()
            end
        end
    else
        -- Multi-row layout
        local numRows = math.ceil(count / rowLimit)
        local rowSpacing = iconHeight + spacing
        
        for i, icon in ipairs(icons) do
            local row = math.ceil(i / rowLimit)
            local rowStart = (row - 1) * rowLimit + 1
            local rowEnd = math.min(row * rowLimit, count)
            local rowCount = rowEnd - rowStart + 1
            local positionInRow = i - rowStart + 1
            
            local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
            local x, y
            
            if growthDirection == "Left" then
                -- Left growth: first icon in row at center, others grow left
                local firstIconX = iconWidth / 2
                x = firstIconX - (positionInRow - 1) * (iconWidth + spacing)
            elseif growthDirection == "Right" then
                -- Right growth: first icon in row at center, others grow right
                local firstIconX = -iconWidth / 2
                x = firstIconX + (positionInRow - 1) * (iconWidth + spacing)
            else
                -- Centered (default)
                local startX = -rowWidth / 2 + iconWidth / 2
                x = startX + (positionInRow - 1) * (iconWidth + spacing)
            end
            
            -- Vertical position (main row at y=0)
            y = -(row - 1) * rowSpacing
            
            icon:SetPoint("CENTER", container, "CENTER", x, y)
            icon:Show()
        end
    end
    
    -- Update all cooldowns
    UpdateAllCustomItemCooldowns()
    
    -- Update count text styling for all icons
    self:UpdateCountTextStyling()
end

function CustomIcons:AddCustomItem(itemID, retryCount)
    retryCount = retryCount or 0
    if not itemID then return false end
    
    local db = NephUI.db.profile.customIcons
    if not db then return false end
    
    -- Check if already tracked
    for _, id in ipairs(db.trackedItems) do
        if id == itemID then
            return false  -- Already tracked
        end
    end
    
    -- Add to tracked items list
    table.insert(db.trackedItems, itemID)
    
    -- Rebuild config list
    if NephUI.RebuildTrackedItemsList then
        NephUI:RebuildTrackedItemsList()
    end
    
    -- Create icon if tracker frame exists
    if NephUI.customIconsTrackerFrame then
        local icon = CreateCustomItemIcon(itemID, NephUI.customIconsTrackerFrame)
        if icon then
            customItemIcons[itemID] = icon
            UpdateCustomItemCooldown(itemID, icon)
            if self.ApplyCustomIconsLayout then
                self:ApplyCustomIconsLayout()
            end
        elseif retryCount < 5 then
            -- Item data not loaded yet, retry
            C_Timer.After(1, function()
                self:AddCustomItem(itemID, retryCount + 1)
            end)
        end
    end
    
    return true
end

function CustomIcons:RemoveCustomItem(itemID)
    if not itemID then return false end
    
    local db = NephUI.db.profile.customIcons
    if not db then return false end
    
    -- Remove from tracked items list
    for i, id in ipairs(db.trackedItems) do
        if id == itemID then
            table.remove(db.trackedItems, i)
            break
        end
    end
    
    -- Remove icon frame
    local icon = customItemIcons[itemID]
    if icon then
        icon:Hide()
        icon:SetParent(nil)
        customItemIcons[itemID] = nil
    end
    
    -- Rebuild config list
    if NephUI.RebuildTrackedItemsList then
        NephUI:RebuildTrackedItemsList()
    end
    
    -- Relayout
    if self.ApplyCustomIconsLayout then
        self:ApplyCustomIconsLayout()
    end
    
    return true
end

-- Expose to main addon for backwards compatibility
NephUI.CreateCustomIconsTrackerFrame = function(self) return CustomIcons:CreateCustomIconsTrackerFrame() end
NephUI.ApplyCustomIconsLayout = function(self) return CustomIcons:ApplyCustomIconsLayout() end
NephUI.AddCustomItem = function(self, itemID, retryCount) return CustomIcons:AddCustomItem(itemID, retryCount) end
NephUI.RemoveCustomItem = function(self, itemID) return CustomIcons:RemoveCustomItem(itemID) end

