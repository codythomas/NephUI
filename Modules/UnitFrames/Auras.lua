local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Get UnitFrames module
local UF = NephUI.UnitFrames
if not UF then
    error("NephUI: UnitFrames module not initialized! Load UnitFrames.lua first.")
end

-- Update target auras (buffs/debuffs)
local function UpdateTargetAuras(frame)
    if not frame or frame.unit ~= "target" then return end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        if frame.buffIcons then
            for _, iconFrame in ipairs(frame.buffIcons) do
                iconFrame:Hide()
            end
        end
        if frame.debuffIcons then
            for _, iconFrame in ipairs(frame.debuffIcons) do
                iconFrame:Hide()
            end
        end
        return
    end
    
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return
    end
    
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    local DB = db.target
    local GeneralDB = db.General
    if not DB then return end
    
    -- Get aura settings (with defaults)
    local auraSettings = DB.Auras or {}
    local frameWidth = frame:GetWidth() or 200
    local auraWidth = (auraSettings.Width and auraSettings.Width > 0) and auraSettings.Width or (frameWidth + 2)
    local auraHeight = (auraSettings.Height and auraSettings.Height > 0) and auraSettings.Height or 18
    local auraAlpha = auraSettings.Alpha or 1
    local auraOffsetX = auraSettings.OffsetX or 0
    local auraOffsetY = auraSettings.OffsetY or 2
    local auraSpacing = auraSettings.Spacing or 2
    local showBuffs = auraSettings.ShowBuffs ~= false
    local showDebuffs = auraSettings.ShowDebuffs ~= false
    
    local iconSize = math.max(14, math.floor(auraHeight * 0.7 + 0.5))
    local maxPerRow = math.max(1, math.min(12, math.floor(auraWidth / (iconSize + auraSpacing))))
    local rowLimit = auraSettings.RowLimit or 0 -- 0 = unlimited
    
    frame.buffIcons = frame.buffIcons or {}
    frame.debuffIcons = frame.debuffIcons or {}
    
    local function GetIcon(t, index, parent)
        local iconFrame = t[index]
        if not iconFrame then
            iconFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            t[index] = iconFrame
            iconFrame:SetSize(iconSize, iconSize)
            iconFrame:SetAlpha(auraAlpha)
            iconFrame:EnableMouse(true)
            
            -- Create icon texture first
            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            -- Zoom in by 0.08 (crop 4% from each edge, showing 92% of texture)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconFrame.icon = tex
            
            -- Cooldown swipe overlay
            local cd = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
            cd:SetAllPoints(iconFrame)
            cd:SetDrawEdge(false)
            cd:SetReverse(true)
            cd.noOCC = true
            cd.noCooldownCount = true
            iconFrame.cooldown = cd
            
            -- Create separate border frame (like SkinIcon does)
            -- Must be created after texture and cooldown
            local border = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
            -- Set explicit size - anchor to iconFrame (not texture) to avoid "secret value" errors
            -- Since texture uses SetAllPoints on iconFrame, this matches texture bounds
            border:SetAllPoints(iconFrame)
            -- Set frame level high enough to be above everything
            border:SetFrameLevel(iconFrame:GetFrameLevel() + 10)
            iconFrame.border = border
            
            -- Add black border (exactly like SkinIcon does, using lowercase x)
            -- Set backdrop after frame has explicit dimensions from SetAllPoints
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            border:SetBackdropBorderColor(0, 0, 0, 1)
            border:Show()
            
            -- Tooltip support using Blizzard's default anchor
            --[[CAUSING ERRORS
            local function SetTooltipDefault(owner)
                -- Use Blizzard's default anchor, which respects user settings
                if GameTooltip_SetDefaultAnchor then
                    GameTooltip_SetDefaultAnchor(GameTooltip, owner or UIParent)
                else
                    -- Fallback: behave like a typical default bottom-right tooltip
                    GameTooltip:SetOwner(owner or UIParent, "ANCHOR_NONE")
                    GameTooltip:ClearAllPoints()
                    GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 130)
                end
            end
            
            iconFrame:SetScript("OnEnter", function(self)
                if not self.unit or not self.auraIndex or not self.auraFilter then
                    return
                end
                if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
                    return
                end
                
                local auraData = C_UnitAuras.GetAuraDataByIndex(self.unit, self.auraIndex, self.auraFilter)
                if not auraData then
                    return
                end
                
                SetTooltipDefault(self)
                GameTooltip:SetUnitAura(self.unit, self.auraIndex, self.auraFilter)
            end)
            iconFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            --]]
        else
            iconFrame:SetSize(iconSize, iconSize)
            iconFrame:SetAlpha(auraAlpha)
            -- Ensure border is still properly anchored and shown if it exists
            if iconFrame.border then
                -- Anchor to iconFrame (not texture) to avoid "secret value" errors
                -- Since texture uses SetAllPoints on iconFrame, this matches texture bounds
                iconFrame.border:SetAllPoints(iconFrame)
                iconFrame.border:Show()
            end
        end
        return iconFrame
    end
    
    -- Hide old icons
    for _, fIcon in ipairs(frame.buffIcons) do
        fIcon:Hide()
    end
    for _, fIcon in ipairs(frame.debuffIcons) do
        fIcon:Hide()
    end
    
    local function Populate(containerTable, filter, isBuff, rowOffset, maxRows)
        local shown = 0
        local index = 1
        rowOffset = rowOffset or 0
        maxRows = maxRows or (rowLimit > 0 and rowLimit or 999)
        
        while true do
            local auraData = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if not auraData then
                break
            end
            
            shown = shown + 1
            local col = (shown - 1) % maxPerRow
            local row = math.floor((shown - 1) / maxPerRow) + rowOffset
            
            -- Check if we've exceeded the row limit
            if row >= maxRows then
                break
            end
            
            local iconFrame = GetIcon(containerTable, shown, frame)
            iconFrame.icon:SetTexture(auraData.icon)
            iconFrame.unit = unit
            iconFrame.auraIndex = index
            iconFrame.auraFilter = filter
            iconFrame.isBuff = isBuff and true or false
            iconFrame.auraInstanceID = auraData.auraInstanceID
            
            -- Cooldown swipe
            if iconFrame.cooldown then
                iconFrame.cooldown:Hide()
                local duration = auraData.duration
                local expirationTime = auraData.expirationTime
                if duration and expirationTime then
                    local ok = pcall(function()
                        local startTime = expirationTime - duration
                        if duration > 0 then
                            iconFrame.cooldown:SetCooldown(startTime, duration)
                        end
                    end)
                    if ok and duration and duration > 0 then
                        iconFrame.cooldown:Show()
                    end
                end
            end
            
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT",
                auraOffsetX + col * (iconSize + auraSpacing),
                auraOffsetY + row * (iconSize + auraSpacing))
            
            iconFrame:Show()
            
            index = index + 1
        end
        
        return shown
    end
    
    -- Debuffs first (closer to frame), buffs above
    local numDebuffs = 0
    local debuffRows = 0
    local maxDebuffRows = rowLimit > 0 and rowLimit or 999
    
    if showDebuffs then
        numDebuffs = Populate(frame.debuffIcons, "HARMFUL", false, 0, maxDebuffRows)
        if numDebuffs > 0 then
            debuffRows = math.floor((numDebuffs - 1) / maxPerRow) + 1
        end
    end
    
    -- Apply row limit to total rows (debuffs + buffs)
    local buffRowOffset = debuffRows
    local maxBuffRows = rowLimit > 0 and (rowLimit - debuffRows) or 999
    if showBuffs and maxBuffRows > 0 then
        Populate(frame.buffIcons, "HELPFUL", true, buffRowOffset, maxBuffRows)
    end
end

-- Export function
UF.UpdateTargetAuras = UpdateTargetAuras

