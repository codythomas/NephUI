local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

-- Unit Frame System
NephUI.UnitFrames = {}
local UF = NephUI.UnitFrames

-- Unit to frame name mapping
local UnitToFrameName = {
    player = "NephUI_Player",
    target = "NephUI_Target",
    targettarget = "NephUI_TargetTarget",
    pet = "NephUI_Pet",
    focus = "NephUI_Focus",
    boss = "NephUI_Boss",
}

local DEFAULT_UNITFRAME_STRATA = "LOW"

local function GetUnitFrameConfig(unit)
    local profile = NephUI.db and NephUI.db.profile and NephUI.db.profile.unitFrames
    if not profile then return end
    local lookupUnit = unit
    if unit:match("^boss(%d+)$") then
        lookupUnit = "boss"
    end
    return profile[lookupUnit], profile
end

local function ResolveFrameName(unit)
    if unit:match("^boss(%d+)$") then
        local unitID = unit:match("^boss(%d+)$")
        return "NephUI_Boss" .. unitID
    end
    return UnitToFrameName[unit]
end

-- Media resolution
function UF:ResolveMedia()
    self.Media = self.Media or {}
    
    -- Always use global font/texture settings
    self.Media.Font = NephUI:GetGlobalFont()
    self.Media.ForegroundTexture = NephUI:GetGlobalTexture()
    self.Media.BackgroundTexture = NephUI:GetGlobalTexture()
end

-- Helper function for text justification
function UF:SetJustification(anchorFrom)
    if anchorFrom == "TOPLEFT" or anchorFrom == "LEFT" or anchorFrom == "BOTTOMLEFT" then
        return "LEFT"
    elseif anchorFrom == "TOPRIGHT" or anchorFrom == "RIGHT" or anchorFrom == "BOTTOMRIGHT" then
        return "RIGHT"
    else
        return "CENTER"
    end
end

function UF:ApplyFrameLayer(unitFrame, GeneralDB)
    if not unitFrame then return end
    local strata = DEFAULT_UNITFRAME_STRATA
    if GeneralDB and GeneralDB.FrameStrata then
        strata = GeneralDB.FrameStrata
    end
    if strata then
        unitFrame:SetFrameStrata(strata)
    end
    if GeneralDB and GeneralDB.FrameLevel then
        unitFrame:SetFrameLevel(GeneralDB.FrameLevel)
    end
end

-- Fetch unit color based on settings
local function FetchUnitColor(unit, DB, GeneralDB)
    if not DB or not DB.Frame then return 0.1, 0.1, 0.1, 1 end
    
    if DB.Frame.ClassColor then
        if unit == "pet" then
            local _, playerClass = UnitClass("player")
            if type(playerClass) == "string" then
                local playerClassColor = RAID_CLASS_COLORS[playerClass]
                if playerClassColor then
                    return playerClassColor.r, playerClassColor.g, playerClassColor.b
                end
            end
        end
    
        -- Safely check if unit is player (may return secret value in combat)
        local isPlayer = UnitIsPlayer(unit)
        if type(isPlayer) == "boolean" and isPlayer then
            local _, class = UnitClass(unit)
            if type(class) == "string" then
                local unitClassColor = RAID_CLASS_COLORS[class]
                if unitClassColor then
                    return unitClassColor.r, unitClassColor.g, unitClassColor.b
                end
            end
        end
    end
    
    if DB.Frame.ReactionColor then
        local reaction = UnitReaction(unit, "player")
        if type(reaction) == "number" then
            local reactionColors = GeneralDB and GeneralDB.CustomColors and GeneralDB.CustomColors.Reaction
            local reactionColor = reactionColors and reactionColors[reaction]
            if reactionColor then
                return reactionColor[1], reactionColor[2], reactionColor[3]
            end
        end
    end
    
    local fgColor = DB.Frame.FGColor or {0.1, 0.1, 0.1, 1}
    return fgColor[1], fgColor[2], fgColor[3], fgColor[4] or 1
end

-- Fetch name text color
local function FetchNameTextColor(unit, DB, GeneralDB)
    if not DB or not DB.Tags or not DB.Tags.Name then return 1, 1, 1 end
    
    if DB.Tags.Name.ColorByStatus then
        if unit == "pet" then
            local _, playerClass = UnitClass("player")
            if type(playerClass) == "string" then
                local playerClassColor = RAID_CLASS_COLORS[playerClass]
                if playerClassColor then
                    return playerClassColor.r, playerClassColor.g, playerClassColor.b
                end
            end
        end
    
        -- Safely check if unit is player (may return secret value in combat)
        local isPlayer = UnitIsPlayer(unit)
        if type(isPlayer) == "boolean" and isPlayer then
            local _, class = UnitClass(unit)
            if type(class) == "string" then
                local classColor = RAID_CLASS_COLORS[class]
                if classColor then
                    return classColor.r, classColor.g, classColor.b
                end
            end
        end
        
        local reaction = UnitReaction(unit, "player")
        if type(reaction) == "number" then
            local reactionColors = GeneralDB and GeneralDB.CustomColors and GeneralDB.CustomColors.Reaction
            local reactionColor = reactionColors and reactionColors[reaction]
            if reactionColor then
                return reactionColor[1], reactionColor[2], reactionColor[3]
            end
        end
    end
    
    local unitTextColor = DB.Tags.Name.Color or {1, 1, 1, 1}
    return unitTextColor[1], unitTextColor[2], unitTextColor[3]
end

-- Helper to get PowerBar DB (handles both PowerBar and powerBar)
local function GetPowerBarDB(DB)
    return DB.PowerBar or DB.powerBar
end

-- Fetch power bar color
local function FetchPowerBarColor(unit)
    local db = NephUI.db.profile.unitFrames
    if not db then return 1, 1, 1, 1 end
    
    local dbUnit = unit
    if unit:match("^boss(%d+)$") then dbUnit = "boss" end
    local DB = db[dbUnit]
    local GeneralDB = db.General
    local PowerBarDB = DB and GetPowerBarDB(DB)
    if not DB or not PowerBarDB then return 1, 1, 1, 1 end
    
    if PowerBarDB.ColorByType then
        local powerToken = UnitPowerType(unit)
        if powerToken then
            local color = GeneralDB and GeneralDB.CustomColors and GeneralDB.CustomColors.Power and GeneralDB.CustomColors.Power[powerToken]
            if color then
                return color[1], color[2], color[3], color[4] or 1
            end
        end
    end
    
    local powerBarFG = PowerBarDB.FGColor or {0.5, 0.5, 0.5, 1}
    return powerBarFG[1], powerBarFG[2], powerBarFG[3], powerBarFG[4] or 1
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
    local auraWidth = (auraSettings.Width and auraSettings.Width > 0) and auraSettings.Width or frameWidth
    local auraHeight = (auraSettings.Height and auraSettings.Height > 0) and auraSettings.Height or 18
    local auraScale = auraSettings.Scale or 1
    local auraAlpha = auraSettings.Alpha or 1
    local auraOffsetX = auraSettings.OffsetX or 0
    local auraOffsetY = auraSettings.OffsetY or 2
    local showBuffs = auraSettings.ShowBuffs ~= false
    local showDebuffs = auraSettings.ShowDebuffs ~= false
    
    local iconSize = math.max(14, math.floor(auraHeight * 0.7 * auraScale + 0.5))
    local maxPerRow = math.max(1, math.min(12, math.floor(auraWidth / (iconSize + 2))))
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
            
            -- Add black border
            iconFrame:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
            
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
            
            -- Disable tooltips to avoid secret value errors
            iconFrame:SetScript("OnEnter", function(self)
                return
            end)
            iconFrame:SetScript("OnLeave", GameTooltip_Hide)
        else
            iconFrame:SetSize(iconSize, iconSize)
            iconFrame:SetAlpha(auraAlpha)
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
                auraOffsetX + col * (iconSize + 2),
                auraOffsetY + row * (iconSize + 2))
            
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

-- Update unit frame
local function UpdateUnitFrame(self, event, eventUnit, ...)
    local unit = self.unit
    if not unit or not UnitExists(unit) then return end
    
    -- Handle UNIT_AURA events for target frame
    if event == "UNIT_AURA" then
        if unit == "target" and eventUnit == "target" then
            UpdateTargetAuras(self)
        end
        return
    end
    
    -- Special handling for targettarget: UNIT_TARGET fires with "target" as the unit
    -- We need to update targettarget when target's target changes
    if unit == "targettarget" and event == "UNIT_TARGET" then
        if eventUnit == "target" then
            -- Target's target changed, update the frame
            -- Continue to update below
        else
            return
            end
        end
        
    -- If event has a unit parameter, only update if it matches our unit
    -- Exception: global events like PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED don't have unit params
    if eventUnit and eventUnit ~= unit then
        -- For events like UNIT_HEALTH, UNIT_NAME_UPDATE, check if it's for our unit
        if event and (event:match("^UNIT_") and eventUnit ~= unit) then
            return
            end
        end
        
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    
    local dbUnit = unit
    if unit:match("^boss(%d+)$") then dbUnit = "boss" end
    local DB = db[dbUnit]
    local GeneralDB = db.General
    if not DB then return end
    
    local unitHealth = UnitHealth(unit)
    local unitMaxHealth = UnitHealthMax(unit)
    local unitColorR, unitColorG, unitColorB = FetchUnitColor(unit, DB, GeneralDB)
    
    if self.healthBar then
        self.healthBar:SetMinMaxValues(0, unitMaxHealth)
        self.healthBar:SetValue(unitHealth)
        self.healthBar:SetStatusBarColor(unitColorR, unitColorG, unitColorB)
    end
    
    if self.HealthText then
        local isUnitDead = UnitIsDeadOrGhost(unit)
        if isUnitDead then
            self.HealthText:SetText("Dead")
        else
            local unitHealthPercent = UnitHealthPercent(unit, false, true) or 0
            local displayStyle = DB.Tags and DB.Tags.Health and DB.Tags.Health.DisplayStyle
            -- Migrate old DisplayPercent setting
            if displayStyle == nil then
                local displayPercentHealth = DB.Tags and DB.Tags.Health and DB.Tags.Health.DisplayPercent
                displayStyle = displayPercentHealth and "both" or "current"
            end
            displayStyle = displayStyle or "current"
            
            local healthText
            if displayStyle == "both" then
                healthText = AbbreviateLargeNumbers(unitHealth) .. string.format(" - %.0f%%", unitHealthPercent)
            elseif displayStyle == "both_reverse" then
                healthText = string.format("%.0f%%", unitHealthPercent) .. " - " .. AbbreviateLargeNumbers(unitHealth)
            elseif displayStyle == "percent" then
                healthText = string.format("%.0f%%", unitHealthPercent)
            else -- "current" or default
                healthText = AbbreviateLargeNumbers(unitHealth)
            end
            self.HealthText:SetText(healthText)
        end
    end
    
    if self.NameText then
        local statusColorR, statusColorG, statusColorB = FetchNameTextColor(unit, DB, GeneralDB)
        self.NameText:SetTextColor(statusColorR, statusColorG, statusColorB)
        -- Safely get unit name (may be secret value in combat)
        local unitName = UnitName(unit)
        if type(unitName) == "string" then
            self.NameText:SetText(unitName)
        else
            -- If secret value, keep existing text or use empty string
            self.NameText:SetText("")
        end
    end
    
    -- Power text (for player, target, focus, boss)
    if self.PowerText then
        local PowerTextDB = DB.Tags and DB.Tags.Power
        if PowerTextDB and PowerTextDB.Enabled ~= false then
            -- For target and focus: if power bar is hooked, get values from Blizzard's bar
            if (unit == "target" or unit == "focus") and self.powerBar and self.powerBar.__hookedToBlizzard then
                local blizzardFrame = (unit == "target") and _G["TargetFrame"] or _G["FocusFrame"]
                local blizzardPowerBar = blizzardFrame and (blizzardFrame.manabar or blizzardFrame.powerBar)
                if blizzardPowerBar and blizzardPowerBar:IsShown() then
                    local value = blizzardPowerBar:GetValue()
                    local min, max = blizzardPowerBar:GetMinMaxValues()
                    if min and max and type(value) == "number" and type(max) == "number" then
                        self.PowerText:SetFormattedText("%d / %d", value, max)
                        self.PowerText:Show()
                    else
                        self.PowerText:Hide()
                    end
                else
                    self.PowerText:Hide()
                end
            -- For other units: use normal UnitPower approach
            elseif unit == "player" or unit == "target" or unit == "focus" or unit:match("^boss%d+$") or UnitIsPlayer(unit) then
                -- Safely get power values (may be secret values in combat)
                local unitPower = UnitPower(unit)
                local unitMaxPower = UnitPowerMax(unit)
                
                if type(unitPower) == "number" and type(unitMaxPower) == "number" then
                    self.PowerText:SetFormattedText("%d / %d", unitPower, unitMaxPower)
                    self.PowerText:Show()
                else
                    -- Secret values - hide or keep last known state
                    self.PowerText:Hide()
                end
            else
                self.PowerText:SetText("")
                self.PowerText:Hide()
            end
        else
            self.PowerText:Hide()
        end
    end
    
    -- Update target auras if this is the target frame (always update, not just on specific events)
    if unit == "target" then
        UpdateTargetAuras(self)
    end
        end
        
-- Update power bar
local function UpdateUnitFramePowerBar(self, event, eventUnit, ...)
    local unit = self.unit
    if not unit then return end
    
    -- Handle target change events - always update for these (unit might be new target)
    local isTargetChangeEvent = (event == "PLAYER_TARGET_CHANGED" and unit == "target") or 
                                (event == "PLAYER_FOCUS_CHANGED" and unit == "focus")
    
    -- For target change events, check if unit exists, but still try to update
    if not isTargetChangeEvent then
        if not UnitExists(unit) then return end
    else
        -- For target change, if unit doesn't exist, hide the bar
        if not UnitExists(unit) then
            self:Hide()
            return
        end
    end
    
    -- If event has a unit parameter, only update if it matches our unit
    -- (UNIT_POWER_UPDATE, UNIT_POWER_FREQUENT, UNIT_MAXPOWER, UNIT_DISPLAYPOWER all pass unit)
    if eventUnit and eventUnit ~= unit then return end
    
    -- For target and focus: if hooked, skip value updates (values come from Blizzard's bars)
    local isTargetOrFocus = (unit == "target" or unit == "focus")
    if isTargetOrFocus and self.__hookedToBlizzard then
        -- Power bar is hooked to Blizzard's bar, only update color if needed
        -- Try to get power type for color (this should be safe)
        local pType = UnitPowerType(unit)
        if pType then
            local col = PowerBarColor[pType] or { r = 0.8, g = 0.8, b = 0.8 }
            self:SetStatusBarColor(col.r, col.g, col.b)
        end
        return
    end
    
    -- Get power type and values (may return nil/secret values in combat)
    local pType = UnitPowerType(unit)
    local unitPower = UnitPower(unit, pType)
    local unitMaxPower = UnitPowerMax(unit, pType)
    
    -- Check if values are numbers before comparing (secret values aren't numbers)
    local powerIsValid = type(unitPower) == "number"
    local maxPowerIsValid = type(unitMaxPower) == "number"
    
    -- If we have secret values, use safe defaults and skip the update
    if not powerIsValid or not maxPowerIsValid then
        -- Can't safely update in combat with secret values, just show the bar with last known state
        self:Show()
        return
    end
    
    -- Handle case where maxPower is 0 (no power type or dead unit)
    if unitMaxPower <= 0 then
        -- Still show the bar but with 0 values
        self:SetMinMaxValues(0, 1)
        self:SetValue(0)
        -- Get color even when power is 0
        if isTargetOrFocus then
            local col = PowerBarColor[pType] or { r = 0.8, g = 0.8, b = 0.8 }
            self:SetStatusBarColor(col.r, col.g, col.b)
        else
            local r, g, b, a = FetchPowerBarColor(unit)
            self:SetStatusBarColor(r, g, b, a)
        end
        self:Show()
        return
    end
    
    self:Show()
    
    -- Use PowerBarColor for target and focus, otherwise use FetchPowerBarColor
    if isTargetOrFocus then
        local col = PowerBarColor[pType] or { r = 0.8, g = 0.8, b = 0.8 }
        self:SetStatusBarColor(col.r, col.g, col.b)
    else
        local r, g, b, a = FetchPowerBarColor(unit)
        self:SetStatusBarColor(r, g, b, a)
    end
    
    self:SetMinMaxValues(0, unitMaxPower)
    self:SetValue(unitPower)
    
    -- Ensure background color is always applied (important when power is 0)
    if self.bg then
        local db = NephUI.db.profile.unitFrames
        if db then
            local dbUnit = unit
            if unit:match("^boss(%d+)$") then dbUnit = "boss" end
            local DB = db[dbUnit]
            if DB then
                local PowerBarDB = GetPowerBarDB(DB)
                if PowerBarDB then
                    local bgColor = PowerBarDB.BGColor
                    if not bgColor or type(bgColor) ~= "table" or not bgColor[1] or not bgColor[2] or not bgColor[3] then
                        bgColor = {0.1, 0.1, 0.1, 0.7}
                    end
                    local bgR, bgG, bgB, bgA = unpack(bgColor)
                    if not bgA then bgA = bgColor[4] or 0.7 end
                    self.bg:SetVertexColor(bgR, bgG, bgB, bgA)
                end
                end
            end
            end
        end
        
-- Shared event frame for deferred mouse disabling (protected in combat)
local mouseDisableEventFrame = nil
local pendingMouseDisableFrames = {}

local function ProcessPendingMouseDisables()
    if InCombatLockdown() then return end
    
    for frame, _ in pairs(pendingMouseDisableFrames) do
        if frame and not InCombatLockdown() then
            if frame.EnableMouse then
                frame:EnableMouse(false)
            end
            if frame.EnableMouseWheel then
                frame:EnableMouseWheel(false)
            end
            pendingMouseDisableFrames[frame] = nil
        end
    end
    
    -- Unregister if no more pending frames
    if mouseDisableEventFrame and not next(pendingMouseDisableFrames) then
        mouseDisableEventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function SafeDisableMouse(frame)
    if not frame then return end
    
    if InCombatLockdown() then
        -- Defer until out of combat
        pendingMouseDisableFrames[frame] = true
        
        -- Create shared event frame if needed
        if not mouseDisableEventFrame then
            mouseDisableEventFrame = CreateFrame("Frame")
            mouseDisableEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            mouseDisableEventFrame:SetScript("OnEvent", ProcessPendingMouseDisables)
        else
            mouseDisableEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    else
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.EnableMouseWheel then
            frame:EnableMouseWheel(false)
        end
    end
end

local function MaskFrame(unitFrame)
    if not unitFrame or unitFrame.__cdmMasked then return end
    unitFrame.__cdmMasked = true
    
    SafeDisableMouse(unitFrame)
    unitFrame:SetAlpha(0)
    unitFrame:HookScript("OnShow", function(self)
        self:SetAlpha(0)
        SafeDisableMouse(self)
    end)
end


function UF:HideDefaultUnitFrames()
    MaskFrame(PlayerFrame)
    MaskFrame(TargetFrame)
    MaskFrame(FocusFrame)
    MaskFrame(TargetFrameToT)
    MaskFrame(PetFrame)
    
    -- Hook TargetFrame.UpdateAuras to release Blizzard auras (prevents conflicts with our custom auras)
    if TargetFrame and not TargetFrame.__cdmAurasHooked and TargetFrame.UpdateAuras then
        TargetFrame.__cdmAurasHooked = true
        hooksecurefunc(TargetFrame, "UpdateAuras", function(frame)
            if frame ~= TargetFrame then return end
            if frame.auraPools and frame.auraPools.ReleaseAll then
                frame.auraPools:ReleaseAll()
            end
        end)
    end
    
    -- Hook FocusFrame.UpdateAuras similarly
    if FocusFrame and not FocusFrame.__cdmAurasHooked and FocusFrame.UpdateAuras then
        FocusFrame.__cdmAurasHooked = true
        hooksecurefunc(FocusFrame, "UpdateAuras", function(frame)
            if frame ~= FocusFrame then return end
            if frame.auraPools and frame.auraPools.ReleaseAll then
                frame.auraPools:ReleaseAll()
            end
        end)
    end
    
    -- Ensure Demon Hunter soul fragments bar is shown (even though PlayerFrame is hidden)
    -- This is needed for the soul resource to update properly
    local soulBar = _G["DemonHunterSoulFragmentsBar"]
    if soulBar then
        -- Unhook any hide scripts that might have been set by KillFrame or others
        soulBar:SetScript("OnShow", nil)
        soulBar:SetScript("OnHide", nil)
        -- Reparent to UIParent so it's not affected by PlayerFrame being hidden
        soulBar:SetParent(UIParent)
        -- Show the bar but make it invisible (alpha 0)
        soulBar:Show()
        soulBar:SetAlpha(0)
        -- Ensure it stays visible by preventing it from being hidden
        -- Hook OnHide to immediately show it again
        soulBar:SetScript("OnHide", function(self)
            if not InCombatLockdown() then
                self:Show()
                self:SetAlpha(0)
            end
        end)
            end
        end
        
-- Get anchor frame by name
local function GetAnchorFrame(anchorName)
    if not anchorName or anchorName == "" then
        return UIParent
    end
    
    local frame = _G[anchorName]
    if frame then
        return frame
    end
    
    -- Fallback to UIParent if frame not found
    return UIParent
end

-- Apply frame position using anchor frame name and offsets
function UF:ApplyFramePosition(unitFrame, unit, DB)
    if not unitFrame or not DB or not DB.Frame then return end

    -- Don't move frames in combat to avoid taint
    if InCombatLockdown() then
        return
    end

    unitFrame:ClearAllPoints()
    
    local anchorName = DB.Frame.AnchorFrame or "UIParent"
    local anchor = GetAnchorFrame(anchorName)
    local anchorFrom = DB.Frame.AnchorFrom or "CENTER"
    local anchorTo = DB.Frame.AnchorTo or "CENTER"
    local offsetX = DB.Frame.OffsetX or 0
    local offsetY = DB.Frame.OffsetY or 0
    
    -- Special positioning for cooldown viewer
    local ecv = _G["EssentialCooldownViewer"]
    if DB.Frame.AnchorToCooldown and ecv and anchor == ecv then
        local gapY = offsetY or -20
        
        if unit == "player" then
            unitFrame:SetPoint("RIGHT", ecv, "LEFT", -20 + (offsetX or 0), gapY)
            
            -- Update edit mode anchor position if it exists
            if unitFrame.editModeAnchor and not unitFrame.editModeAnchor.isMoving then
                unitFrame.editModeAnchor:ClearAllPoints()
                unitFrame.editModeAnchor:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
            end
            return
        elseif unit == "target" then
            unitFrame:SetPoint("LEFT", ecv, "RIGHT", 20 + (offsetX or 0), gapY)
            
            -- Update edit mode anchor position if it exists
            if unitFrame.editModeAnchor and not unitFrame.editModeAnchor.isMoving then
                unitFrame.editModeAnchor:ClearAllPoints()
                unitFrame.editModeAnchor:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
            end
            return
        end
    end
    
    -- Standard positioning
    unitFrame:SetPoint(anchorFrom, anchor, anchorTo, offsetX, offsetY)
    
    -- Update edit mode anchor position if it exists
    if unitFrame.editModeAnchor and not unitFrame.editModeAnchor.isMoving then
        unitFrame.editModeAnchor:ClearAllPoints()
        unitFrame.editModeAnchor:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
    end
end

-- Reposition all unit frames (used after initialization to ensure correct anchoring)
function UF:RepositionAllUnitFrames()
    if InCombatLockdown() then
        return
    end
    
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    
    local units = {"player", "target", "targettarget", "pet", "focus"}
    for _, unit in ipairs(units) do
        local unitDB = db[unit]
        if unitDB and unitDB.Enabled then
            local frameName = ResolveFrameName(unit)
            local unitFrame = frameName and _G[frameName]
            if unitFrame then
                self:ApplyFramePosition(unitFrame, unit, unitDB)
            end
        end
    end
end

-- Hook EssentialCooldownViewer for player and target frames
function UF:HookCooldownViewer()
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    
    -- Check if player or target has anchorToCooldown enabled
    local playerDB = db.player
    local targetDB = db.target
    local playerUsesCooldown = playerDB and playerDB.Frame and playerDB.Frame.AnchorToCooldown
    local targetUsesCooldown = targetDB and targetDB.Frame and targetDB.Frame.AnchorToCooldown
    
    -- If neither player nor target uses cooldown viewer, don't hook
    if not playerUsesCooldown and not targetUsesCooldown then
        return
    end
    
    -- Try to find EssentialCooldownViewer
    local ecv = _G["EssentialCooldownViewer"]
    
    -- If cooldown viewer doesn't exist, return (will retry on next call)
    if not ecv then
        return
    end
    
    -- If already hooked, return
    if ecv.__nephuiCooldownHooked then
        return
    end
    ecv.__nephuiCooldownHooked = true
    
    local function realign()
        -- Don't move frames in combat to avoid taint
        if InCombatLockdown() then
            return
        end
        
        -- Reposition player frame if it uses cooldown viewer
        if playerUsesCooldown then
            local frameName = ResolveFrameName("player")
            local unitFrame = frameName and _G[frameName]
            if unitFrame then
                self:ApplyFramePosition(unitFrame, "player", db.player)
            end
        end
        
        -- Reposition target frame if it uses cooldown viewer
        if targetUsesCooldown then
            local frameName = ResolveFrameName("target")
            local unitFrame = frameName and _G[frameName]
            if unitFrame then
                self:ApplyFramePosition(unitFrame, "target", db.target)
            end
        end
        
        -- Reposition all other unit frames (in case they're anchored to player/target)
        -- This ensures frames like targettarget, focus, or pet update when player/target moves
        local otherUnits = {"targettarget", "pet", "focus"}
        for _, unit in ipairs(otherUnits) do
            local unitDB = db[unit]
            if unitDB and unitDB.Enabled then
                local frameName = ResolveFrameName(unit)
                local unitFrame = frameName and _G[frameName]
                if unitFrame then
                    self:ApplyFramePosition(unitFrame, unit, unitDB)
                end
            end
        end
    end
    
    -- Hook the scripts
    ecv:HookScript("OnSizeChanged", realign)
    ecv:HookScript("OnShow", realign)
    ecv:HookScript("OnHide", realign)
    
    -- Initial realignment
    realign()
end

-- Hook anchor frames to reposition unit frames when they change
function UF:HookAnchorFrames()
    -- First, hook cooldown viewer if needed
    self:HookCooldownViewer()
    
    -- Also hook individual anchor frames (for non-cooldown viewer anchors)
    local function RepositionAllFrames()
        if InCombatLockdown() then
            return
        end
        
        local db = NephUI.db.profile.unitFrames
        if not db then return end
        
        for unit in pairs(UnitToFrameName) do
            local dbUnit = unit
            if unit:match("^boss(%d+)$") then dbUnit = "boss" end
            
            local DB = db[dbUnit]
            if DB and DB.Enabled then
                local frameName = ResolveFrameName(unit)
                local unitFrame = frameName and _G[frameName]
                if unitFrame then
                    self:ApplyFramePosition(unitFrame, unit, DB)
                end
            end
        end
    end
    
    -- Collect all unique anchor frame names from config (excluding EssentialCooldownViewer used by player/target)
    local anchorNames = {}
    if db then
        for unit in pairs(UnitToFrameName) do
            local dbUnit = unit
            if unit:match("^boss(%d+)$") then dbUnit = "boss" end
            
            local DB = db[dbUnit]
            if DB and DB.Frame and DB.Frame.AnchorFrame then
                local anchorName = DB.Frame.AnchorFrame
                -- Skip if this unit is using AnchorToCooldown (player/target only)
                local isUsingCooldownViewer = false
                if (unit == "player" or unit == "target") and DB.Frame.AnchorToCooldown then
                    if anchorName == "EssentialCooldownViewer" then
                        isUsingCooldownViewer = true
                    end
                end
                
                -- Skip EssentialCooldownViewer if it's being used via AnchorToCooldown toggle
                if anchorName and anchorName ~= "" and anchorName ~= "UIParent" 
                   and not (isUsingCooldownViewer and anchorName == "EssentialCooldownViewer") then
                    anchorNames[anchorName] = true
                end
            end
        end
    end
    
    -- Hook all other anchor frames that are actually being used
    for anchorName, _ in pairs(anchorNames) do
        local anchor = _G[anchorName]
        if anchor and not anchor.__nephuiHooked then
            anchor.__nephuiHooked = true
            anchor:HookScript("OnSizeChanged", RepositionAllFrames)
            anchor:HookScript("OnShow", RepositionAllFrames)
            anchor:HookScript("OnHide", RepositionAllFrames)
        end
    end
end

-- Create unit frame
function UF:CreateUnitFrame(unit)
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    
    local dbUnit = unit
    if unit:match("^boss(%d+)$") then dbUnit = "boss" end
    local DB = db[dbUnit]
    local GeneralDB = db.General
    if not DB or not DB.Enabled then return end
    
    local TagsDB = DB.Tags
    local NameDB = TagsDB and TagsDB.Name
    local HealthDB = TagsDB and TagsDB.Health
    local frameName = ResolveFrameName(unit)
    local unitFrame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    
    unitFrame:SetSize(DB.Frame.Width, DB.Frame.Height)
    self:ApplyFrameLayer(unitFrame, GeneralDB)
    self:ApplyFramePosition(unitFrame, unit, DB)
    
    -- Create edit mode anchor if needed (will be shown/hidden based on Edit Mode state)
    if not unitFrame.editModeAnchor then
        self:CreateEditModeAnchor(unit)
    end
    
    unitFrame:SetBackdrop({
        bgFile = self.Media.BackgroundTexture,
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    unitFrame:SetBackdropColor(unpack(DB.Frame.BGColor))
    unitFrame:SetBackdropBorderColor(0, 0, 0, 1)
    
    unitFrame.healthBar = CreateFrame("StatusBar", nil, unitFrame)
    unitFrame.healthBar:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 1, -1)
    unitFrame.healthBar:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -1, 1)
    unitFrame.healthBar:SetStatusBarTexture(self.Media.ForegroundTexture)
    
    if not unitFrame.healthBar.BG then
        unitFrame.healthBar.BG = unitFrame.healthBar:CreateTexture(nil, "BACKGROUND")
        unitFrame.healthBar.BG:SetAllPoints()
        unitFrame.healthBar.BG:SetTexture(self.Media.BackgroundTexture)
    end
    
    local bgR, bgG, bgB, bgA = unpack(DB.Frame.BGColor)
    unitFrame.healthBar.BG:SetVertexColor(bgR, bgG, bgB, bgA)
    
    -- Ensure media is resolved (in case it wasn't called yet)
    if not self.Media or not self.Media.Font then
        self:ResolveMedia()
    end
    
    -- Name text
    unitFrame.NameText = unitFrame.healthBar:CreateFontString(nil, "OVERLAY")
    unitFrame.NameText:SetFont(self.Media.Font, DB.Tags.Name.FontSize, GeneralDB.FontFlag)
    unitFrame.NameText:SetPoint(DB.Tags.Name.AnchorFrom, unitFrame, DB.Tags.Name.AnchorTo, DB.Tags.Name.OffsetX, DB.Tags.Name.OffsetY)
    unitFrame.NameText:SetJustifyH(self:SetJustification(DB.Tags.Name.AnchorFrom))
    local statusColorR, statusColorG, statusColorB = FetchNameTextColor(unit, DB, GeneralDB)
    unitFrame.NameText:SetTextColor(statusColorR, statusColorG, statusColorB)
    unitFrame.NameText:SetShadowColor(unpack(GeneralDB.FontShadows.Color))
    unitFrame.NameText:SetShadowOffset(GeneralDB.FontShadows.OffsetX, GeneralDB.FontShadows.OffsetY)
    if NameDB.Enabled then
        unitFrame.NameText:Show()
    else
        unitFrame.NameText:Hide()
    end
    
    -- Health text
    unitFrame.HealthText = unitFrame.healthBar:CreateFontString(nil, "OVERLAY")
    unitFrame.HealthText:SetFont(self.Media.Font, DB.Tags.Health.FontSize, GeneralDB.FontFlag)
    unitFrame.HealthText:SetPoint(DB.Tags.Health.AnchorFrom, unitFrame, DB.Tags.Health.AnchorTo, DB.Tags.Health.OffsetX, DB.Tags.Health.OffsetY)
    unitFrame.HealthText:SetJustifyH(self:SetJustification(DB.Tags.Health.AnchorFrom))
    unitFrame.HealthText:SetTextColor(unpack(DB.Tags.Health.Color))
    unitFrame.HealthText:SetShadowColor(unpack(GeneralDB.FontShadows.Color))
    unitFrame.HealthText:SetShadowOffset(GeneralDB.FontShadows.OffsetX, GeneralDB.FontShadows.OffsetY)
    if HealthDB.Enabled then
        unitFrame.HealthText:Show()
    else
        unitFrame.HealthText:Hide()
    end
    
    -- Power text (for player, target, focus, boss)
    local PowerTextDB = DB.Tags and DB.Tags.Power
    if PowerTextDB and (unit == "player" or unit == "target" or unit == "focus" or unit:match("^boss%d+$")) then
        unitFrame.PowerText = unitFrame.healthBar:CreateFontString(nil, "OVERLAY")
        unitFrame.PowerText:SetFont(self.Media.Font, PowerTextDB.FontSize or DB.Tags.Health.FontSize, GeneralDB.FontFlag)
        unitFrame.PowerText:SetPoint(PowerTextDB.AnchorFrom or "BOTTOMRIGHT", unitFrame, PowerTextDB.AnchorTo or "BOTTOMRIGHT", PowerTextDB.OffsetX or -4, PowerTextDB.OffsetY or 4)
        unitFrame.PowerText:SetJustifyH(self:SetJustification(PowerTextDB.AnchorFrom or "BOTTOMRIGHT"))
        unitFrame.PowerText:SetTextColor(unpack(PowerTextDB.Color or DB.Tags.Health.Color))
        unitFrame.PowerText:SetShadowColor(unpack(GeneralDB.FontShadows.Color))
        unitFrame.PowerText:SetShadowOffset(GeneralDB.FontShadows.OffsetX, GeneralDB.FontShadows.OffsetY)
        if PowerTextDB.Enabled ~= false then
            unitFrame.PowerText:Show()
        else
            unitFrame.PowerText:Hide()
        end
    end
    
    -- Power bar (for player, target, focus)
    if unit ~= "targettarget" and unit ~= "pet" then
        local PowerBarDB = GetPowerBarDB(DB)
        if PowerBarDB then
            local unitFramePowerBar = CreateFrame("StatusBar", nil, unitFrame)
            unitFrame.powerBar = unitFramePowerBar
            
            if PowerBarDB.Enabled then
                local barHeight = PowerBarDB.Height
                
                unitFramePowerBar:SetStatusBarTexture(self.Media.ForegroundTexture)
                unitFramePowerBar:SetHeight(barHeight)
                unitFramePowerBar:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOMLEFT", 1, 1)
                unitFramePowerBar:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -1, 1)
                
                if not unitFramePowerBar.bg then
                    unitFramePowerBar.bg = unitFramePowerBar:CreateTexture(nil, "BACKGROUND")
                    unitFramePowerBar.bg:SetAllPoints()
                end
                
                -- Set texture first, then color - ensure color is applied
                unitFramePowerBar.bg:SetTexture(self.Media.BackgroundTexture)
                -- Get BGColor from database - ensure we have a valid color
                local bgColor = PowerBarDB.BGColor
                if not bgColor or type(bgColor) ~= "table" or not bgColor[1] or not bgColor[2] or not bgColor[3] then
                    bgColor = {0.1, 0.1, 0.1, 0.7}
                end
                local r, g, b, a = unpack(bgColor)
                -- Ensure alpha is set (default to 0.7 if not provided)
                if not a then a = bgColor[4] or 0.7 end
                -- Apply vertex color - this tints the texture (WHITE8X8 will be tinted by this)
                unitFramePowerBar.bg:SetVertexColor(r, g, b, a)
                
                unitFramePowerBar:Show()
                -- Ensure color is applied after showing (sometimes needed for initial load)
                unitFramePowerBar.bg:SetVertexColor(r, g, b, a)
                
                unitFrame.healthBar:ClearAllPoints()
                unitFrame.healthBar:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 1, -1)
                unitFrame.healthBar:SetPoint("BOTTOMLEFT", unitFramePowerBar, "TOPLEFT", 0, 0)
                unitFrame.healthBar:SetPoint("BOTTOMRIGHT", unitFramePowerBar, "TOPRIGHT", 0, 0)
            else
                unitFramePowerBar:Hide()
                unitFrame.healthBar:ClearAllPoints()
                unitFrame.healthBar:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 1, -1)
                unitFrame.healthBar:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -1, 1)
            end
            
            unitFramePowerBar.unit = unit
            unitFramePowerBar:RegisterEvent("UNIT_POWER_UPDATE")
            unitFramePowerBar:RegisterEvent("UNIT_POWER_FREQUENT") -- More frequent updates in combat
            unitFramePowerBar:RegisterEvent("UNIT_MAXPOWER")
            unitFramePowerBar:RegisterEvent("UNIT_DISPLAYPOWER") -- For power type changes
            -- Register target change event for target/focus frames
            if unit == "target" then
                unitFramePowerBar:RegisterEvent("PLAYER_TARGET_CHANGED")
            elseif unit == "focus" then
                unitFramePowerBar:RegisterEvent("PLAYER_FOCUS_CHANGED")
            end
            unitFramePowerBar:SetScript("OnEvent", UpdateUnitFramePowerBar)
            UpdateUnitFramePowerBar(unitFramePowerBar)
        end
    end
    
    -- Frame attributes
    unitFrame.unit = unit
    unitFrame:RegisterForClicks("AnyUp")
    unitFrame:SetAttribute("unit", unit)
    unitFrame:SetAttribute("*type1", "target")
    unitFrame:SetAttribute("*type2", "togglemenu")
    
    -- Events
    unitFrame:RegisterEvent("UNIT_HEALTH")
    unitFrame:RegisterEvent("UNIT_MAXHEALTH")
    unitFrame:RegisterEvent("UNIT_NAME_UPDATE")
    unitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    unitFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- Register power events for power text updates
    if unit == "player" or unit == "target" or unit == "focus" or unit:match("^boss%d+$") then
        unitFrame:RegisterEvent("UNIT_POWER_UPDATE")
        unitFrame:RegisterEvent("UNIT_MAXPOWER")
    end
    
    -- Register UNIT_AURA for target frame to update auras
    if unit == "target" then
        unitFrame:RegisterEvent("UNIT_AURA")
    end
    
    -- Special event for targettarget: listen to when target's target changes
    if unit == "targettarget" then
        unitFrame:RegisterEvent("UNIT_TARGET")
    end
    
    RegisterUnitWatch(unitFrame, false)
    
    -- Tooltips über NephUI-Unitframes sind deaktiviert, damit es keine Probleme in Instanzen / mit Secret-Values gibt.
    unitFrame:SetScript("OnEnter", function(self)
        -- Tooltips disabled to prevent secret value errors
        -- Only handle any highlight/mouseover effects here if needed
    end)
    unitFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    if unit == "pet" then unitFrame:RegisterEvent("UNIT_PET") end
    if unit == "focus" then unitFrame:RegisterEvent("PLAYER_FOCUS_CHANGED") end
    
    unitFrame:SetScript("OnEvent", UpdateUnitFrame)
    UpdateUnitFrame(unitFrame)
    
    -- Update target auras if this is the target frame
    if unit == "target" then
        UpdateTargetAuras(unitFrame)
    end
end

-- Update unit frame
function UF:UpdateUnitFrame(unit)
    if not unit then return end
    
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    
    local dbUnit = unit
    if unit:match("^boss(%d+)$") then dbUnit = "boss" end
    local DB = db[dbUnit]
    local GeneralDB = db.General
    if not DB then return end
    
    local frameName = ResolveFrameName(unit)
    local unitFrame = _G[frameName]
    if not unitFrame then return end
    
    if not DB.Enabled then
        unitFrame:Hide()
        unitFrame:UnregisterAllEvents()
        return
    else
        unitFrame:Show()
    end
    
    unitFrame:SetSize(DB.Frame.Width, DB.Frame.Height)
    self:ApplyFrameLayer(unitFrame, GeneralDB)
    self:ApplyFramePosition(unitFrame, unit, DB)
    
    -- Update edit mode anchor if it exists
    if unitFrame.editModeAnchor then
        unitFrame.editModeAnchor:SetSize(DB.Frame.Width, DB.Frame.Height)
        if not unitFrame.editModeAnchor.isMoving then
            unitFrame.editModeAnchor:ClearAllPoints()
            unitFrame.editModeAnchor:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
        end
    end
    
    unitFrame:SetBackdrop({
        bgFile = self.Media.BackgroundTexture,
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    unitFrame:SetBackdropColor(unpack(DB.Frame.BGColor))
    unitFrame:SetBackdropBorderColor(0, 0, 0, 1)
    
    local unitHealthBar = unitFrame.healthBar
    local unitHealthBG = unitHealthBar.BG
    unitHealthBar:ClearAllPoints()
    unitHealthBar:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 1, -1)
    unitHealthBar:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -1, 1)
    unitFrame.healthBar:SetStatusBarTexture(self.Media.ForegroundTexture)
    
    local bgR, bgG, bgB, bgA = unpack(DB.Frame.BGColor)
    unitHealthBG:SetVertexColor(bgR, bgG, bgB, bgA)
    
    -- Ensure media is resolved with latest global font
    self:ResolveMedia()
    
    -- Update name text
    if unitFrame.NameText then
        local unitNameText = unitFrame.NameText
        local NameDB = DB.Tags.Name
        unitNameText:SetFont(self.Media.Font, NameDB.FontSize, GeneralDB.FontFlag)
        unitNameText:ClearAllPoints()
        unitNameText:SetPoint(NameDB.AnchorFrom, unitFrame, NameDB.AnchorTo, NameDB.OffsetX, NameDB.OffsetY)
        unitNameText:SetJustifyH(self:SetJustification(NameDB.AnchorFrom))
        unitNameText:SetShadowColor(unpack(GeneralDB.FontShadows.Color))
        unitNameText:SetShadowOffset(GeneralDB.FontShadows.OffsetX, GeneralDB.FontShadows.OffsetY)
        
        if NameDB.Enabled then
            unitNameText:Show()
        else
            unitNameText:Hide()
        end
    end
    
    -- Update health text
    if unitFrame.HealthText then
        local unitHealthText = unitFrame.HealthText
        local HDB = DB.Tags.Health
        
        unitHealthText:SetFont(self.Media.Font, HDB.FontSize, GeneralDB.FontFlag)
        unitHealthText:ClearAllPoints()
        unitHealthText:SetPoint(HDB.AnchorFrom, unitFrame, HDB.AnchorTo, HDB.OffsetX, HDB.OffsetY)
        unitHealthText:SetJustifyH(self:SetJustification(HDB.AnchorFrom))
        unitHealthText:SetTextColor(unpack(HDB.Color))
        unitHealthText:SetShadowColor(unpack(GeneralDB.FontShadows.Color))
        unitHealthText:SetShadowOffset(GeneralDB.FontShadows.OffsetX, GeneralDB.FontShadows.OffsetY)
        
        if HDB.Enabled then
            unitHealthText:Show()
        else
            unitHealthText:Hide()
        end
    end
    
    -- Update power text
    local PowerTextDB = DB.Tags and DB.Tags.Power
    if PowerTextDB and (unit == "player" or unit == "target" or unit == "focus" or unit:match("^boss%d+$")) then
        if not unitFrame.PowerText then
            unitFrame.PowerText = unitFrame.healthBar:CreateFontString(nil, "OVERLAY")
        end
        local unitPowerText = unitFrame.PowerText
        unitPowerText:SetFont(self.Media.Font, PowerTextDB.FontSize or DB.Tags.Health.FontSize, GeneralDB.FontFlag)
        unitPowerText:ClearAllPoints()
        unitPowerText:SetPoint(PowerTextDB.AnchorFrom or "BOTTOMRIGHT", unitFrame, PowerTextDB.AnchorTo or "BOTTOMRIGHT", PowerTextDB.OffsetX or -4, PowerTextDB.OffsetY or 4)
        unitPowerText:SetJustifyH(self:SetJustification(PowerTextDB.AnchorFrom or "BOTTOMRIGHT"))
        unitPowerText:SetTextColor(unpack(PowerTextDB.Color or DB.Tags.Health.Color))
        unitPowerText:SetShadowColor(unpack(GeneralDB.FontShadows.Color))
        unitPowerText:SetShadowOffset(GeneralDB.FontShadows.OffsetX, GeneralDB.FontShadows.OffsetY)
        
        if PowerTextDB.Enabled ~= false then
            unitPowerText:Show()
        else
            unitPowerText:Hide()
        end
    elseif unitFrame.PowerText then
        unitFrame.PowerText:Hide()
    end
    
    -- Update power bar
    local unitPowerBar = unitFrame.powerBar
    local PowerBarDB = GetPowerBarDB(DB)
    if unitPowerBar and PowerBarDB then
        if PowerBarDB.Enabled then
            local unitPowerBarHeight = PowerBarDB.Height
            unitPowerBar:SetHeight(unitPowerBarHeight)
            unitPowerBar:SetStatusBarTexture(self.Media.ForegroundTexture)
            unitPowerBar:ClearAllPoints()
            unitPowerBar:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOMLEFT", 1, 1)
            unitPowerBar:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -1, 1)
            
            if not unitPowerBar.bg then
                unitPowerBar.bg = unitPowerBar:CreateTexture(nil, "BACKGROUND")
                unitPowerBar.bg:SetAllPoints()
            end
            -- Set texture first, then color - ensure color is applied
            unitPowerBar.bg:SetTexture(self.Media.BackgroundTexture)
            -- Get BGColor from database - ensure we have a valid color
            local bgColor = PowerBarDB.BGColor
            if not bgColor or type(bgColor) ~= "table" or not bgColor[1] or not bgColor[2] or not bgColor[3] then
                bgColor = {0.1, 0.1, 0.1, 0.7}
            end
            local r, g, b, a = unpack(bgColor)
            -- Ensure alpha is set (default to 0.7 if not provided)
            if not a then a = bgColor[4] or 0.7 end
            -- Apply vertex color - this tints the texture (WHITE8X8 will be tinted by this)
            unitPowerBar.bg:SetVertexColor(r, g, b, a)
            
            unitPowerBar:Show()
            unitHealthBar:ClearAllPoints()
            unitHealthBar:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 1, -1)
            unitHealthBar:SetPoint("BOTTOMLEFT", unitPowerBar, "TOPLEFT", 0, 0)
            unitHealthBar:SetPoint("BOTTOMRIGHT", unitPowerBar, "TOPRIGHT", 0, 0)
            
            -- Force update power bar values when unit frame updates (e.g., target change)
            UpdateUnitFramePowerBar(unitPowerBar)
        else
            unitPowerBar:Hide()
            unitHealthBar:ClearAllPoints()
            unitHealthBar:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 1, -1)
            unitHealthBar:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -1, 1)
    end
end

    -- Re-register events
    unitFrame:UnregisterAllEvents()
    if DB.Enabled then
        unitFrame:RegisterEvent("UNIT_HEALTH")
        unitFrame:RegisterEvent("UNIT_MAXHEALTH")
        unitFrame:RegisterEvent("UNIT_NAME_UPDATE")
        unitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        unitFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        -- Register power events for power text updates
        if unit == "player" or unit == "target" or unit == "focus" or unit:match("^boss%d+$") then
            unitFrame:RegisterEvent("UNIT_POWER_UPDATE")
            unitFrame:RegisterEvent("UNIT_MAXPOWER")
        end
        -- Register UNIT_AURA for target frame to update auras
        if unit == "target" then
            unitFrame:RegisterEvent("UNIT_AURA")
        end
        -- Special event for targettarget: listen to when target's target changes
        if unit == "targettarget" then
            unitFrame:RegisterEvent("UNIT_TARGET")
        end
        if unit == "pet" then unitFrame:RegisterEvent("UNIT_PET") end
        if unit == "focus" then unitFrame:RegisterEvent("PLAYER_FOCUS_CHANGED") end
        unitFrame:SetScript("OnEvent", UpdateUnitFrame)
    else
        unitFrame:SetScript("OnEvent", nil)
        unitFrame:SetScript("OnEnter", nil)
        unitFrame:SetScript("OnLeave", nil)
    end
    
    if unitPowerBar then
        local PowerBarDB = GetPowerBarDB(DB)
        unitPowerBar:UnregisterAllEvents()
        if PowerBarDB and PowerBarDB.Enabled then
            unitPowerBar:RegisterEvent("UNIT_POWER_UPDATE")
            unitPowerBar:RegisterEvent("UNIT_POWER_FREQUENT") -- More frequent updates in combat
            unitPowerBar:RegisterEvent("UNIT_MAXPOWER")
            unitPowerBar:RegisterEvent("UNIT_DISPLAYPOWER") -- For power type changes
            -- Register target change event for target/focus frames
            if unit == "target" then
                unitPowerBar:RegisterEvent("PLAYER_TARGET_CHANGED")
            elseif unit == "focus" then
                unitPowerBar:RegisterEvent("PLAYER_FOCUS_CHANGED")
            end
            unitPowerBar:SetScript("OnEvent", UpdateUnitFramePowerBar)
            -- Force update immediately
            UpdateUnitFramePowerBar(unitPowerBar)
        else
            unitPowerBar:SetScript("OnEvent", nil)
    end
end

    UpdateUnitFrame(unitFrame)
    if unitPowerBar then
        UpdateUnitFramePowerBar(unitPowerBar)
    end
    
    -- Update target auras if this is the target frame
    if unit == "target" then
        UpdateTargetAuras(unitFrame)
    end
end

-- Hook into Blizzard's target and focus power bars to avoid secret value issues
function UF:HookTargetAndFocusPowerBars()
    -- Hook Target power bar
    local targetFrame = _G["TargetFrame"]
    local targetPowerBar = targetFrame and (targetFrame.manabar or targetFrame.powerBar)
    if targetPowerBar and not targetPowerBar.__nephuiHooked then
        targetPowerBar.__nephuiHooked = true
        
        -- Get our custom target power bar
        local targetUnitFrame = _G["NephUI_Target"]
        local customTargetPowerBar = targetUnitFrame and targetUnitFrame.powerBar
        
        if customTargetPowerBar then
            customTargetPowerBar.__hookedToBlizzard = true
            
            -- Function to sync values from Blizzard's bar to ours
            local function SyncTargetPowerBar()
                if not customTargetPowerBar then return end
                
                local value = targetPowerBar:GetValue()
                local min, max = targetPowerBar:GetMinMaxValues()
                if min and max then
                    customTargetPowerBar:SetMinMaxValues(min, max)
                    customTargetPowerBar:SetValue(value or 0)
                    
                    -- Update power text from Blizzard's bar values (check if enabled)
                    if targetUnitFrame and targetUnitFrame.PowerText then
                        local db = NephUI.db.profile.unitFrames
                        local PowerTextDB = db and db.target and db.target.Tags and db.target.Tags.Power
                        if PowerTextDB and PowerTextDB.Enabled ~= false then
                            local powerValue = value or 0
                            local maxValue = max
                            if type(powerValue) == "number" and type(maxValue) == "number" then
                                targetUnitFrame.PowerText:SetFormattedText("%d / %d", powerValue, maxValue)
                                targetUnitFrame.PowerText:Show()
                            end
                        else
                            targetUnitFrame.PowerText:Hide()
                        end
                    end
                end
            end
            
            -- Hook OnValueChanged to mirror values
            targetPowerBar:HookScript("OnValueChanged", function(self, value)
                if not customTargetPowerBar then return end
                SyncTargetPowerBar()
            end)
            
            -- Hook OnShow to sync when Blizzard's bar shows
            targetPowerBar:HookScript("OnShow", function(self)
                if not customTargetPowerBar then return end
                SyncTargetPowerBar()
                customTargetPowerBar:Show()
            end)
            
            -- Hook OnHide to hide our bar when Blizzard's hides
            targetPowerBar:HookScript("OnHide", function()
                if customTargetPowerBar then
                    customTargetPowerBar:Hide()
                end
            end)
            
            -- Hook OnUpdate to continuously sync values
            targetPowerBar:HookScript("OnUpdate", function(self, elapsed)
                if not customTargetPowerBar or not targetPowerBar:IsShown() then return end
                SyncTargetPowerBar()
            end)
            
            -- Initial sync if Blizzard's bar is already shown
            if targetPowerBar:IsShown() then
                SyncTargetPowerBar()
                customTargetPowerBar:Show()
            end
        end
    end
    
    -- Hook Focus power bar
    local focusFrame = _G["FocusFrame"]
    local focusPowerBar = focusFrame and (focusFrame.manabar or focusFrame.powerBar)
    if focusPowerBar and not focusPowerBar.__nephuiHooked then
        focusPowerBar.__nephuiHooked = true
        
        -- Get our custom focus power bar
        local focusUnitFrame = _G["NephUI_Focus"]
        local customFocusPowerBar = focusUnitFrame and focusUnitFrame.powerBar
        
        if customFocusPowerBar then
            customFocusPowerBar.__hookedToBlizzard = true
            
            -- Function to sync values from Blizzard's bar to ours
            local function SyncFocusPowerBar()
                if not customFocusPowerBar then return end
                
                local value = focusPowerBar:GetValue()
                local min, max = focusPowerBar:GetMinMaxValues()
                if min and max then
                    customFocusPowerBar:SetMinMaxValues(min, max)
                    customFocusPowerBar:SetValue(value or 0)
                    
                    -- Update power text from Blizzard's bar values (check if enabled)
                    if focusUnitFrame and focusUnitFrame.PowerText then
                        local db = NephUI.db.profile.unitFrames
                        local PowerTextDB = db and db.focus and db.focus.Tags and db.focus.Tags.Power
                        if PowerTextDB and PowerTextDB.Enabled ~= false then
                            local powerValue = value or 0
                            local maxValue = max
                            if type(powerValue) == "number" and type(maxValue) == "number" then
                                focusUnitFrame.PowerText:SetFormattedText("%d / %d", powerValue, maxValue)
                                focusUnitFrame.PowerText:Show()
                            end
                        else
                            focusUnitFrame.PowerText:Hide()
                        end
                    end
                end
            end
            
            -- Hook OnValueChanged to mirror values
            focusPowerBar:HookScript("OnValueChanged", function(self, value)
                if not customFocusPowerBar then return end
                SyncFocusPowerBar()
            end)
            
            -- Hook OnShow to sync when Blizzard's bar shows
            focusPowerBar:HookScript("OnShow", function(self)
                if not customFocusPowerBar then return end
                SyncFocusPowerBar()
                customFocusPowerBar:Show()
            end)
            
            -- Hook OnHide to hide our bar when Blizzard's hides
            focusPowerBar:HookScript("OnHide", function()
                if customFocusPowerBar then
                    customFocusPowerBar:Hide()
                end
            end)
            
            -- Hook OnUpdate to continuously sync values
            focusPowerBar:HookScript("OnUpdate", function(self, elapsed)
                if not customFocusPowerBar or not focusPowerBar:IsShown() then return end
                SyncFocusPowerBar()
            end)
            
            -- Initial sync if Blizzard's bar is already shown
            if focusPowerBar:IsShown() then
                SyncFocusPowerBar()
                customFocusPowerBar:Show()
            end
        end
    end
end

-- Create draggable anchor frame for a unit frame
function UF:CreateEditModeAnchor(unit)
    local frameName = ResolveFrameName(unit)
    local unitFrame = frameName and _G[frameName]
    if not unitFrame then return end
    
    -- Check if anchor already exists
    if unitFrame.editModeAnchor then
        return unitFrame.editModeAnchor
    end
    
    local anchor = CreateFrame("Frame", frameName .. "_EditModeAnchor", UIParent, "BackdropTemplate")
    anchor.unit = unit
    anchor.unitFrame = unitFrame
    
    -- Make it look like Blizzard's edit mode selection
    anchor:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    anchor:SetBackdropBorderColor(0.2, 0.5, 1, 0.8) -- Blue border like Blizzard
    
    -- Match size to unit frame
    anchor:SetSize(unitFrame:GetWidth() or 200, unitFrame:GetHeight() or 40)
    
    -- Make it draggable
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetClampedToScreen(true)
    
    -- Position it over the unit frame
    anchor:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
    
    -- Function to update unit frame position based on anchor position
    local function UpdateUnitFrameFromAnchor(anchor)
        if InCombatLockdown() then return end
        
        local db = NephUI.db.profile.unitFrames
        if not db then return end
        
        local dbUnit = anchor.unit
        if anchor.unit:match("^boss(%d+)$") then dbUnit = "boss" end
        
        local DB = db[dbUnit]
        if not DB or not DB.Frame then return end
        
        -- Get anchor frame
        local anchorFrameName = DB.Frame.AnchorFrame or "UIParent"
        local anchorFrame = GetAnchorFrame(anchorFrameName)
        
        -- Calculate offset from anchor frame
        local anchorX, anchorY = anchorFrame:GetCenter()
        local selfX, selfY = anchor:GetCenter()
        
        if anchorX and anchorY and selfX and selfY then
            local offsetX = selfX - anchorX
            local offsetY = selfY - anchorY
            
            -- Update database
            DB.Frame.OffsetX = offsetX
            DB.Frame.OffsetY = offsetY
            
            -- Reposition unit frame in real-time
            if unitFrame then
                unitFrame:ClearAllPoints()
                local anchorFrom = DB.Frame.AnchorFrom or "CENTER"
                local anchorTo = DB.Frame.AnchorTo or "CENTER"
                unitFrame:SetPoint(anchorFrom, anchorFrame, anchorTo, offsetX, offsetY)
            end
        end
    end
    
    -- Drag handlers
    anchor:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
        self.isMoving = true
        
        -- Set up OnUpdate to move unit frame in real-time while dragging
        self:SetScript("OnUpdate", function(self, elapsed)
            if not self.isMoving then
                self:SetScript("OnUpdate", nil)
                return
            end
            UpdateUnitFrameFromAnchor(self)
        end)
    end)
    
    anchor:SetScript("OnDragStop", function(self)
        if InCombatLockdown() then return end
        self:StopMovingOrSizing()
        self.isMoving = false
        
        -- Remove OnUpdate script
        self:SetScript("OnUpdate", nil)
        
        -- Final update to ensure database is saved
        UpdateUnitFrameFromAnchor(self)
    end)
    
    -- Hide by default
    anchor:Hide()
    
    unitFrame.editModeAnchor = anchor
    return anchor
end

-- Update edit mode anchors visibility and position
function UF:UpdateEditModeAnchors()
    local db = NephUI.db.profile.unitFrames
    if not db or not db.General then return end
    
    local toggleEnabled = db.General.ShowEditModeAnchors ~= false
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame.editModeActive
    
    -- Show anchors if Edit Mode is active OR if the toggle is enabled
    local showAnchors = inEditMode or toggleEnabled
    
    for unit in pairs(UnitToFrameName) do
        local frameName = ResolveFrameName(unit)
        local unitFrame = frameName and _G[frameName]
        if unitFrame and unitFrame:IsShown() then
            if not unitFrame.editModeAnchor then
                self:CreateEditModeAnchor(unit)
            end
            
            local anchor = unitFrame.editModeAnchor
            if anchor then
                if showAnchors then
                    -- Update anchor size to match unit frame
                    anchor:SetSize(unitFrame:GetWidth() or 200, unitFrame:GetHeight() or 40)
                    -- Only update position if not currently being dragged
                    if not anchor.isMoving then
                        anchor:ClearAllPoints()
                        anchor:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
                    end
                    anchor:Show()
                else
                    anchor:Hide()
                end
            end
        end
    end
end

-- Hook Edit Mode
function UF:HookEditMode()
    if self.EditModeHooked then return end
    self.EditModeHooked = true
    
    -- Wait for EditModeManagerFrame to exist
    local function TryHook()
        if not EditModeManagerFrame then
            return false
        end
        
        -- Hook EnterEditMode
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            self:UpdateEditModeAnchors()
        end)
        
        -- Hook ExitEditMode
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            self:UpdateEditModeAnchors()
        end)
        
        -- Periodic update to keep anchors in sync (in case unit frames move)
        if not self.AnchorUpdateTicker then
            self.AnchorUpdateTicker = C_Timer.NewTicker(0.1, function()
                local db = NephUI.db.profile.unitFrames
                local toggleEnabled = db and db.General and db.General.ShowEditModeAnchors ~= false
                local inEditMode = EditModeManagerFrame and EditModeManagerFrame.editModeActive
                
                -- Update if Edit Mode is active OR toggle is enabled
                if inEditMode or toggleEnabled then
                    self:UpdateEditModeAnchors()
                end
            end)
        end
        
        return true
    end
    
    if not TryHook() then
        -- Wait for EditModeManagerFrame to load
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("ADDON_LOADED")
        waiter:SetScript("OnEvent", function(self, event, addonName)
            if TryHook() then
                self:UnregisterAllEvents()
                self:SetScript("OnEvent", nil)
            end
        end)
    end
end

-- Initialize unit frames
function UF:Initialize()
    local db = NephUI.db.profile.unitFrames
    if not db or not db.enabled then return end
    
    -- Resolve media
    self:ResolveMedia()
    
    -- Hide default frames
    self:HideDefaultUnitFrames()
    
    -- Create unit frames
    self:CreateUnitFrame("player")
    self:CreateUnitFrame("target")
    self:CreateUnitFrame("targettarget")
    self:CreateUnitFrame("pet")
    self:CreateUnitFrame("focus")
    
    -- Reposition all frames after creation to ensure correct anchoring
    -- This is needed because frames that anchor to other unit frames need
    -- their anchors to be fully positioned first
    C_Timer.After(0.1, function()
        self:RepositionAllUnitFrames()
    end)
    C_Timer.After(0.5, function()
        self:RepositionAllUnitFrames()
    end)
    
    -- Hook anchor frames to reposition when they change
    -- Use multiple delays to catch anchor frames that are created later (like cooldown managers)
    C_Timer.After(0.5, function()
        self:HookAnchorFrames()
    end)
    C_Timer.After(1.0, function()
        self:HookAnchorFrames()
    end)
    C_Timer.After(2.0, function()
        self:HookAnchorFrames()
    end)
    
    -- Hook cooldown viewer
    C_Timer.After(1.0, function()
        self:HookCooldownViewer()
    end)
    
    -- Hook Edit Mode for anchor visibility
    C_Timer.After(0.5, function()
        self:HookEditMode()
    end)
    
    -- Hook into target and focus power bars (delay to ensure frames exist)
    C_Timer.After(0.1, function()
        self:HookTargetAndFocusPowerBars()
    end)
end

-- Refresh all frames
function UF:RefreshFrames()
    local db = NephUI.db.profile.unitFrames
    if not db then return end
    
    self:ResolveMedia()
    
    for unit in pairs(UnitToFrameName) do
        local frameName = ResolveFrameName(unit)
        local frame = _G[frameName]
        if frame then
            self:UpdateUnitFrame(unit)
        else
            self:CreateUnitFrame(unit)
        end
    end
    
    -- Re-hook anchor frames after refresh (retry to catch frames created later)
    C_Timer.After(0.5, function()
        self:HookAnchorFrames()
    end)
    C_Timer.After(1.0, function()
        self:HookAnchorFrames()
    end)
    
    -- Re-hook cooldown viewer after refresh
    C_Timer.After(1.0, function()
        self:HookCooldownViewer()
    end)
    
    -- Update edit mode anchors after refresh
    self:UpdateEditModeAnchors()
    
    -- Re-hook target and focus power bars after refresh
    C_Timer.After(0.1, function()
        self:HookTargetAndFocusPowerBars()
    end)
end