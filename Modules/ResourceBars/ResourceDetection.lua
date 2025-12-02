local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Tables
local buildVersion = select(4, GetBuildInfo())
local HAS_UNIT_POWER_PERCENT = type(UnitPowerPercent) == "function"

local tickedPowerTypes = {
    [Enum.PowerType.ArcaneCharges] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.Runes] = true,
    [Enum.PowerType.SoulShards] = true,
}

local fragmentedPowerTypes = {
    [Enum.PowerType.Runes] = true,
}

-- Export tables for use in other ResourceBars files
NephUI.ResourceBars = NephUI.ResourceBars or {}
NephUI.ResourceBars.tickedPowerTypes = tickedPowerTypes
NephUI.ResourceBars.fragmentedPowerTypes = fragmentedPowerTypes
NephUI.ResourceBars.HAS_UNIT_POWER_PERCENT = HAS_UNIT_POWER_PERCENT

-- RESOURCE DETECTION

local function GetPrimaryResource()
    local playerClass = select(2, UnitClass("player"))
    local primaryResources = {
        ["DEATHKNIGHT"] = Enum.PowerType.RunicPower,
        ["DEMONHUNTER"] = Enum.PowerType.Fury,
        ["DRUID"]       = {
            [0]   = Enum.PowerType.Mana, -- Human
            [1]   = Enum.PowerType.Energy, -- Cat
            [5]   = Enum.PowerType.Rage, -- Bear
            [27]  = Enum.PowerType.Mana, -- Travel
            [31]  = Enum.PowerType.LunarPower, -- Moonkin
        },
        ["EVOKER"]      = Enum.PowerType.Mana,
        ["HUNTER"]      = Enum.PowerType.Focus,
        ["MAGE"]        = Enum.PowerType.Mana,
        ["MONK"]        = {
            [268] = Enum.PowerType.Energy, -- Brewmaster
            [269] = Enum.PowerType.Energy, -- Windwalker
            [270] = Enum.PowerType.Mana, -- Mistweaver
        },
        ["PALADIN"]     = Enum.PowerType.Mana,
        ["PRIEST"]      = {
            [256] = Enum.PowerType.Mana, -- Disciple
            [257] = Enum.PowerType.Mana, -- Holy,
            [258] = Enum.PowerType.Insanity, -- Shadow,
        },
        ["ROGUE"]       = Enum.PowerType.Energy,
        ["SHAMAN"]      = {
            [262] = Enum.PowerType.Maelstrom, -- Elemental
            [263] = Enum.PowerType.Mana, -- Enhancement
            [264] = Enum.PowerType.Mana, -- Restoration
        },
        ["WARLOCK"]     = Enum.PowerType.Mana,
        ["WARRIOR"]     = Enum.PowerType.Rage,
    }

    local spec = GetSpecialization()
    local specID = GetSpecializationInfo(spec)

    -- Druid: form-based
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        return primaryResources[playerClass][formID or 0]
    end

    if type(primaryResources[playerClass]) == "table" then
        return primaryResources[playerClass][specID]
    else 
        return primaryResources[playerClass]
    end
end

local function GetSecondaryResource()
    local playerClass = select(2, UnitClass("player"))
    local secondaryResources = {
        ["DEATHKNIGHT"] = Enum.PowerType.Runes,
        ["DEMONHUNTER"] = {
            [1480] = "SOUL", -- Aldrachi Reaver
        },
        ["DRUID"]       = {
            [1]    = Enum.PowerType.ComboPoints, -- Cat
            [31]   = Enum.PowerType.Mana, -- Moonkin
        },
        ["EVOKER"]      = Enum.PowerType.Essence,
        ["HUNTER"]      = nil,
        ["MAGE"]        = {
            [62]   = Enum.PowerType.ArcaneCharges, -- Arcane
        },
        ["MONK"]        = {
            [268]  = "STAGGER", -- Brewmaster
            [269]  = Enum.PowerType.Chi, -- Windwalker
        },
        ["PALADIN"]     = Enum.PowerType.HolyPower,
        ["PRIEST"]      = {
            [258]  = Enum.PowerType.Mana, -- Shadow
        },
        ["ROGUE"]       = Enum.PowerType.ComboPoints,
        ["SHAMAN"]      = {
            [262]  = Enum.PowerType.Mana, -- Elemental
        },
        ["WARLOCK"]     = Enum.PowerType.SoulShards,
        ["WARRIOR"]     = nil,
    }

    local spec = GetSpecialization()
    local specID = GetSpecializationInfo(spec)

    -- Druid: form-based
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        return secondaryResources[playerClass][formID or 0]
    end

    if type(secondaryResources[playerClass]) == "table" then
        return secondaryResources[playerClass][specID]
    else 
        return secondaryResources[playerClass]
    end
end

local function GetResourceColor(resource)
    local color = nil
    
    -- Blizzard PowerType lookup name (fallback)
    local powerName = nil
    if type(resource) == "number" then
        for name, value in pairs(Enum.PowerType) do
            if value == resource then
                powerName = name:gsub("(%u)", "_%1"):gsub("^_", ""):upper()
                break
            end
        end
    end

    if resource == "STAGGER" then
        -- Monk
        color = { r = 0.00, g = 1.00, b = 0.59 }

    elseif resource == "SOUL" then
        -- Demon Hunter soul fragments
        color = { r = 0.64, g = 0.19, b = 0.79 }

    elseif resource == Enum.PowerType.SoulShards then
        -- Warlock soul shards (WARLOCK class color)
        color = { r = 0.58, g = 0.51, b = 0.79 }

    elseif resource == Enum.PowerType.Runes then
        -- Death Knight
        color = { r = 0.77, g = 0.12, b = 0.23 }

    elseif resource == Enum.PowerType.Essence then
        -- Evoker
        color = { r = 0.20, g = 0.58, b = 0.50 }

    elseif resource == Enum.PowerType.ComboPoints then
        -- Rogue
        color = { r = 1.00, g = 0.96, b = 0.41 }

    elseif resource == Enum.PowerType.Chi then
        -- Monk
        color = { r = 0.00, g = 1.00, b = 0.59 }
    end

    ---------------------------------------------------------

    -- Fallback to Blizzard's power bar colors
    return color
        or GetPowerBarColor(powerName)
        or GetPowerBarColor(resource)
        or GetPowerBarColor("MANA")
end

-- DEMON HUNTER SOUL FRAGMENTS BAR HANDLING

local function EnsureDemonHunterSoulBar()
    -- Ensure the Demon Hunter soul fragments bar is always shown and functional
    -- This is needed even when custom unit frames are enabled
    local _, class = UnitClass("player")
    if class ~= "DEMONHUNTER" then return end
    
    local spec = GetSpecialization()
    if spec ~= 3 then return end -- Only for spec 3 (Aldrachi Reaver)
    
    local soulBar = _G["DemonHunterSoulFragmentsBar"]
    if soulBar then
        -- Reparent to UIParent if not already (so it's not affected by PlayerFrame)
        if soulBar:GetParent() ~= UIParent then
            if not InCombatLockdown() then
                soulBar:SetParent(UIParent)
            end
        end
        -- Ensure it's shown (even if PlayerFrame is hidden)
        if not soulBar:IsShown() then
            soulBar:Show()
            soulBar:SetAlpha(0)
        end
        -- Unhook any hide scripts that might prevent it from showing
        if not InCombatLockdown() then
            soulBar:SetScript("OnShow", nil)
            -- Set OnHide to immediately show it again
            soulBar:SetScript("OnHide", function(self)
                if not InCombatLockdown() then
                    self:Show()
                    self:SetAlpha(0)
                end
            end)
        end
    end
end

-- GET RESOURCE VALUES

local function GetPrimaryResourceValue(resource, cfg)
    if not resource then return nil, nil, nil, nil end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    if cfg.showManaAsPercent and resource == Enum.PowerType.Mana then
        if HAS_UNIT_POWER_PERCENT then
            return max, current, UnitPowerPercent("player", resource, false, true), "percent"
        else
            return max, current, math.floor((current / max) * 100 + 0.5), "percent"
        end
    else
        return max, current, current, "number"
    end
end

local function GetSecondaryResourceValue(resource)
    if not resource then return nil, nil, nil, nil end

    if resource == "STAGGER" then
        local stagger = UnitStagger("player") or 0
        local maxHealth = UnitHealthMax("player") or 1
        return maxHealth, stagger, stagger, "number"
    end

    if resource == "SOUL" then
        -- DH souls – get from default Blizzard bar
        local soulBar = _G["DemonHunterSoulFragmentsBar"]
        if not soulBar then return nil, nil, nil, nil end
        
        -- Ensure the bar is shown (even if PlayerFrame is hidden)
        if not soulBar:IsShown() then
            soulBar:Show()
            soulBar:SetAlpha(0)
        end

        local current = soulBar:GetValue()
        local _, max = soulBar:GetMinMaxValues()

        return max, current, current, "number"
    end

    if resource == Enum.PowerType.Runes then
        local current = 0
        local max = UnitPowerMax("player", resource)
        if max <= 0 then return nil, nil, nil, nil end

        for i = 1, max do
            local runeReady = select(3, GetRuneCooldown(i))
            if runeReady then
                current = current + 1
            end
        end

        return max, current, current, "number"
    end

    if resource == Enum.PowerType.SoulShards then
        local _, class = UnitClass("player")
        if class == "WARLOCK" then
            local spec = GetSpecialization()

            -- Destruction: use FRAGMENTS (0–50) directly for bar + text
            if spec == 3 then
                local current = UnitPower("player", resource, true)          -- 0–50
                local max     = UnitPowerMax("player", resource, true)       -- 0–50
                if max <= 0 then return nil, nil, nil, nil end

                -- bar fill = fragments, text = fragments (34, 45, etc.)
                return max, current, current, "number"
            end
        end

        -- Any other spec/class that somehow hits SoulShards:
        -- use NORMAL shard count (0–5) for both bar + text
        local current = UnitPower("player", resource)             -- 0–5
        local max     = UnitPowerMax("player", resource)          -- 0–5
        if max <= 0 then return nil, nil, nil, nil end

        -- bar = 0–5, text = 3, 4, 5 etc.
        return max, current, current, "number"
    end

    -- Default case for all other power types (ComboPoints, Chi, HolyPower, etc.)
    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    return max, current, current, "number"
end

-- Export functions
NephUI.ResourceBars.GetPrimaryResource = GetPrimaryResource
NephUI.ResourceBars.GetSecondaryResource = GetSecondaryResource
NephUI.ResourceBars.GetResourceColor = GetResourceColor
NephUI.ResourceBars.EnsureDemonHunterSoulBar = EnsureDemonHunterSoulBar
NephUI.ResourceBars.GetPrimaryResourceValue = GetPrimaryResourceValue
NephUI.ResourceBars.GetSecondaryResourceValue = GetSecondaryResourceValue

