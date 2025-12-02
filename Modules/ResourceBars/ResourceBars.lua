local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Create namespace
NephUI.ResourceBars = NephUI.ResourceBars or {}
local ResourceBars = NephUI.ResourceBars

-- Get functions from sub-modules
local GetPrimaryResource = ResourceBars.GetPrimaryResource
local GetSecondaryResource = ResourceBars.GetSecondaryResource
local EnsureDemonHunterSoulBar = ResourceBars.EnsureDemonHunterSoulBar
local StartRuneUpdateTicker = ResourceBars.StartRuneUpdateTicker
local StopRuneUpdateTicker = ResourceBars.StopRuneUpdateTicker
local StartSoulUpdateTicker = ResourceBars.StartSoulUpdateTicker
local StopSoulUpdateTicker = ResourceBars.StopSoulUpdateTicker

-- EVENT HANDLER

function ResourceBars:OnUnitPower(_, unit)
    -- Be forgiving: if unit is nil or not "player", still update.
    -- It's cheap and avoids missing power updates.
    if unit and unit ~= "player" then
        return
    end

    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
end

-- REFRESH

function ResourceBars:RefreshAll()
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
end

-- EVENT HANDLERS

function ResourceBars:OnSpecChanged()
    -- Ensure Demon Hunter soul bar is spawned when spec changes
    EnsureDemonHunterSoulBar()
    
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
    
    -- Start/stop rune ticker based on class
    local resource = GetSecondaryResource()
    if resource == Enum.PowerType.Runes then
        StartRuneUpdateTicker()
        StopSoulUpdateTicker()
    elseif resource == "SOUL" then
        StartSoulUpdateTicker()
        StopRuneUpdateTicker()
    else
        StopRuneUpdateTicker()
        StopSoulUpdateTicker()
    end
end

function ResourceBars:OnShapeshiftChanged()
    -- Druid form changes affect primary/secondary resources
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
end

-- INITIALIZATION

function ResourceBars:Initialize()
    -- Register additional events
    NephUI:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        ResourceBars:OnSpecChanged()
    end)
    NephUI:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        ResourceBars:OnShapeshiftChanged()
    end)
    NephUI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        EnsureDemonHunterSoulBar()
        ResourceBars:OnUnitPower()
    end)

    -- POWER UPDATES
    NephUI:RegisterEvent("UNIT_POWER_FREQUENT", function(_, unit)
        ResourceBars:OnUnitPower(_, unit)
    end)
    NephUI:RegisterEvent("UNIT_POWER_UPDATE", function(_, unit)
        ResourceBars:OnUnitPower(_, unit)
    end)
    NephUI:RegisterEvent("UNIT_MAXPOWER", function(_, unit)
        ResourceBars:OnUnitPower(_, unit)
    end)

    -- Ensure Demon Hunter soul bar is spawned
    EnsureDemonHunterSoulBar()

    -- Start rune ticker if we're a death knight
    local _, class = UnitClass("player")
    if class == "DEATHKNIGHT" then
        StartRuneUpdateTicker()
    end
    
    -- Start soul fragments ticker if we're a demon hunter with soul resource
    local resource = GetSecondaryResource()
    if resource == "SOUL" then
        StartSoulUpdateTicker()
    end

    -- Initial update (delayed to ensure anchor frames are ready)
    C_Timer.After(0.1, function()
        ResourceBars:UpdatePowerBar()
        ResourceBars:UpdateSecondaryPowerBar()
    end)
    
    -- Also update after a short delay to catch any late-loading frames
    C_Timer.After(0.5, function()
        ResourceBars:UpdatePowerBar()
        ResourceBars:UpdateSecondaryPowerBar()
    end)
    
    -- Periodic out-of-combat update ticker (updates every 0.5 seconds when not in combat)
    -- This ensures bars update even when UNIT_POWER_FREQUENT doesn't fire
    -- UNIT_POWER_FREQUENT only fires frequently in combat, so we need this for out-of-combat updates
    if not ResourceBars.updateTicker then
        ResourceBars.updateTicker = C_Timer.NewTicker(0.5, function()
            -- Only update when not in combat (UNIT_POWER_FREQUENT handles in-combat updates)
            if not UnitAffectingCombat("player") then
                ResourceBars:UpdatePowerBar()
                ResourceBars:UpdateSecondaryPowerBar()
            end
        end)
    end
end

-- Expose event handlers to main addon for backwards compatibility
NephUI.OnUnitPower = function(self, _, unit) return ResourceBars:OnUnitPower(_, unit) end
NephUI.OnSpecChanged = function(self) return ResourceBars:OnSpecChanged() end
NephUI.OnShapeshiftChanged = function(self) return ResourceBars:OnShapeshiftChanged() end

