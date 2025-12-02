local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Get UnitFrames module
local UF = NephUI.UnitFrames
if not UF then
    error("NephUI: UnitFrames module not initialized! Load UnitFrames.lua first.")
end

-- Get helper functions
local ResolveFrameName = UF.ResolveFrameName
local GetPowerBarDB = UF.GetPowerBarDB
local FetchUnitColor = UF.FetchUnitColor
local FetchNameTextColor = UF.FetchNameTextColor
local UpdateTargetAuras = UF.UpdateTargetAuras
local UpdateUnitFramePowerBar = UF.UpdateUnitFramePowerBar

-- Update unit frame event handler
local function UpdateUnitFrame(self, event, eventUnit, ...)
    local unit = self.unit
    if not unit or not UnitExists(unit) then return end
    
    -- Handle UNIT_AURA events for target frame
    if event == "UNIT_AURA" then
        if unit == "target" and eventUnit == "target" then
            if UpdateTargetAuras then
                UpdateTargetAuras(self)
            end
        end
        return
    end
    
    if unit == "targettarget" and event == "UNIT_TARGET" then
        if eventUnit == "target" then
        else
            return
        end
    end
        
    -- If event has a unit parameter, only update if it matches our unit
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
            
            local separator = (DB.Tags and DB.Tags.Health and DB.Tags.Health.Separator) or " - "
            local healthText
            if displayStyle == "both" then
                healthText = AbbreviateLargeNumbers(unitHealth) .. separator .. string.format("%.0f%%", unitHealthPercent)
            elseif displayStyle == "both_reverse" then
                healthText = string.format("%.0f%%", unitHealthPercent) .. separator .. AbbreviateLargeNumbers(unitHealth)
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
            local displayStyle = PowerTextDB.DisplayStyle or "both"
            
            -- For target and focus: if power bar is hooked, get values from Blizzard's bar
            if (unit == "target" or unit == "focus") and self.powerBar and self.powerBar.__hookedToBlizzard then
                local blizzardFrame = (unit == "target") and _G["TargetFrame"] or _G["FocusFrame"]
                local blizzardPowerBar = blizzardFrame and (blizzardFrame.manabar or blizzardFrame.powerBar)
                if blizzardPowerBar and blizzardPowerBar:IsShown() then
                    local value = blizzardPowerBar:GetValue()
                    local min, max = blizzardPowerBar:GetMinMaxValues()
                    if min and max and type(value) == "number" and type(max) == "number" then
                        if displayStyle == "current" then
                            self.PowerText:SetFormattedText("%d", value)
                        else
                            self.PowerText:SetFormattedText("%d / %d", value, max)
                        end
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
                    if displayStyle == "current" then
                        self.PowerText:SetFormattedText("%d", unitPower)
                    else
                        self.PowerText:SetFormattedText("%d / %d", unitPower, unitMaxPower)
                    end
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
    if unit == "target" and UpdateTargetAuras then
        UpdateTargetAuras(self)
    end
end

-- Export event handler
UF.UpdateUnitFrameEventHandler = UpdateUnitFrame

-- Update unit frame (UF function)
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
    if self.ApplyFramePosition then
        self:ApplyFramePosition(unitFrame, unit, DB)
    end
    
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
    
    -- Update alternate power bar first (for player only) - handled by AlternatePowerBar.lua
    -- Alternate power bar takes precedence over regular power bar for health bar positioning
    if unit == "player" then
        local AltPowerBarDB = DB.AlternatePowerBar
        if AltPowerBarDB and self.UpdateAlternatePowerBar then
            self:UpdateAlternatePowerBar(unitFrame, unit, DB, AltPowerBarDB)
        end
    end
    
    -- Update power bar (handled by PowerBars.lua)
    -- Only update if alternate power bar is not shown (alternate takes precedence)
    local unitPowerBar = unitFrame.powerBar
    local PowerBarDB = GetPowerBarDB(DB)
    local shouldUpdatePowerBar = true
    if unit == "player" then
        local altPowerBar = unitFrame.alternatePowerBar
        if altPowerBar and altPowerBar:IsShown() and DB.AlternatePowerBar and DB.AlternatePowerBar.Enabled then
            shouldUpdatePowerBar = false
        end
    end
    
    if shouldUpdatePowerBar and unitPowerBar and PowerBarDB and self.UpdatePowerBar then
        self:UpdatePowerBar(unitFrame, unit, DB, PowerBarDB)
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
            if UpdateUnitFramePowerBar then
                unitPowerBar:SetScript("OnEvent", UpdateUnitFramePowerBar)
                -- Force update immediately
                UpdateUnitFramePowerBar(unitPowerBar)
            end
        else
            unitPowerBar:SetScript("OnEvent", nil)
        end
    end
    
    -- Initial update
    UpdateUnitFrame(unitFrame)
    if unitPowerBar and UpdateUnitFramePowerBar then
        UpdateUnitFramePowerBar(unitPowerBar)
    end
    
    -- Update target auras if this is the target frame
    if unit == "target" and UpdateTargetAuras then
        UpdateTargetAuras(unitFrame)
    end
end

