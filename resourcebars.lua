local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

--TABLES

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

    -- Fallback to Blizzard’s power bar colors
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


-- PRIMARY POWER BAR

function NephUI:GetPowerBar()
    if self.powerBar then return self.powerBar end

    local cfg = self.db.profile.powerBar
    local anchor = _G[cfg.attachTo] or UIParent

    local bar = CreateFrame("Frame", ADDON_NAME .. "PowerBar", anchor)
    bar:SetFrameStrata("MEDIUM")
    bar:SetHeight(cfg.height or 6)
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or 6))

    local width = cfg.width or 0
if width <= 0 then
    width = (anchor.__cdmIconWidth or anchor:GetWidth())

    -- Apply trim
    local pad = cfg.autoWidthPadding or 5.8
    width = width - (pad * 2)
    if width < 0 then width = 0 end
end

    bar:SetWidth(width)


    -- BACKGROUND
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    -- STATUS BAR
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetAllPoints()
    local tex = NephUI:GetGlobalTexture()
    bar.StatusBar:SetStatusBarTexture(tex)
    bar.StatusBar:SetFrameLevel(bar:GetFrameLevel())


    -- BORDER (simple 1px for now)
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetPoint("TOPLEFT", bar, -1, 1)
    bar.Border:SetPoint("BOTTOMRIGHT", bar, 1, -1)
    bar.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bar.Border:SetBackdropBorderColor(0, 0, 0, 1)

    -- TEXT FRAME
    bar.TextFrame = CreateFrame("Frame", nil, bar)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameLevel(bar.StatusBar:GetFrameLevel() + 2)

    bar.TextValue = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", cfg.textX or 0, cfg.textY or 0)
    bar.TextValue:SetJustifyH("CENTER")
    bar.TextValue:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
    bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:SetText("0")

    -- TICKS
    bar.ticks = {}

    bar:Hide()

    self.powerBar = bar
    return bar
end

function NephUI:UpdatePowerBar()
    local cfg = self.db.profile.powerBar
    if not cfg.enabled then
        if self.powerBar then self.powerBar:Hide() end
        return
    end

    local anchor = _G[cfg.attachTo]
    if not anchor or not anchor:IsShown() then
        if self.powerBar then self.powerBar:Hide() end
        return
    end

    local bar = self:GetPowerBar()
    local resource = GetPrimaryResource()
    
    if not resource then
        bar:Hide()
        return
    end

    -- Update layout
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or 6))
    bar:SetHeight(cfg.height or 6)

    local width = cfg.width or 0
if width <= 0 then
    width = (anchor.__cdmIconWidth or anchor:GetWidth())

    -- Apply trim
    local pad = cfg.autoWidthPadding or 5.8
    width = width - (pad * 2)
    if width < 0 then width = 0 end
end

    bar:SetWidth(width)

    -- Update background color
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    if bar.Background then
        bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end

    -- Update texture
    local tex = NephUI:GetGlobalTexture()
    bar.StatusBar:SetStatusBarTexture(tex)

    -- Get resource values
    local max, current, displayValue, valueType = GetPrimaryResourceValue(resource, cfg)
    if not max then
        bar:Hide()
        return
    end

    -- Set bar values
    bar.StatusBar:SetMinMaxValues(0, max)
    bar.StatusBar:SetValue(current)

    -- Set bar color
    if cfg.useClassColor then
        -- Class color
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            bar.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        else
            -- Fallback to resource color
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    elseif cfg.color then
        -- Custom color from GUI
        local r, g, b, a = cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4] or 1
        bar.StatusBar:SetStatusBarColor(r, g, b, a)
    else
        -- Default resource color
        local color = GetResourceColor(resource)
        bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
    end




    -- Update text
    if valueType == "percent" then
        bar.TextValue:SetText(string.format("%.0f%%", displayValue))
    else
        bar.TextValue:SetText(tostring(displayValue))
    end

    bar.TextValue:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
        bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:ClearAllPoints()
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", cfg.textX or 0, cfg.textY or 0)

    -- Show text based on config
    bar.TextFrame:SetShown(cfg.showText ~= false)

    -- Update ticks if this is a ticked power type
    self:UpdatePowerBarTicks(bar, resource, max)

    bar:Show()
end

function NephUI:UpdatePowerBarTicks(bar, resource, max)
    local cfg = self.db.profile.powerBar
    
    -- Hide all ticks first
    for _, tick in ipairs(bar.ticks) do
        tick:Hide()
    end

    if not cfg.showTicks or not tickedPowerTypes[resource] then
        return
    end

    local width = bar:GetWidth()
    local height = bar:GetHeight()
    if width <= 0 or height <= 0 then return end

    local needed = max - 1
    for i = 1, needed do
        local tick = bar.ticks[i]
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 1)
            bar.ticks[i] = tick
        end
        
        local x = (i / max) * width
        tick:ClearAllPoints()
        tick:SetPoint("LEFT", bar.StatusBar, "LEFT", x - 0.5, 0)
        tick:SetSize(1, height)
        tick:Show()
    end
end

-- SECONDARY POWER BAR

function NephUI:GetSecondaryPowerBar()
    if self.secondaryPowerBar then return self.secondaryPowerBar end

    local cfg = self.db.profile.secondaryPowerBar
    local anchor = _G[cfg.attachTo] or UIParent

    local bar = CreateFrame("Frame", ADDON_NAME .. "SecondaryPowerBar", anchor)
    bar:SetFrameStrata("MEDIUM")
    bar:SetHeight(cfg.height or 4)
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or 12))

    local width = cfg.width or 0
if width <= 0 then
    width = (anchor.__cdmIconWidth or anchor:GetWidth())

    -- Apply trim
    local pad = cfg.autoWidthPadding or 5.8
    width = width - (pad * 2)
    if width < 0 then width = 0 end
end

    bar:SetWidth(width)

    -- BACKGROUND
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    -- STATUS BAR (for non-fragmented resources)
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetAllPoints()
    local tex = NephUI:GetGlobalTexture()
    bar.StatusBar:SetStatusBarTexture(tex)
    bar.StatusBar:SetFrameLevel(bar:GetFrameLevel())


    -- BORDER
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetPoint("TOPLEFT", bar, -1, 1)
    bar.Border:SetPoint("BOTTOMRIGHT", bar, 1, -1)
    bar.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bar.Border:SetBackdropBorderColor(0, 0, 0, 1)

    -- TEXT FRAME
    bar.TextFrame = CreateFrame("Frame", nil, bar)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameLevel(bar.StatusBar:GetFrameLevel() + 2)

    bar.TextValue = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", cfg.textX or 0, cfg.textY or 0)
    bar.TextValue:SetJustifyH("CENTER")
    bar.TextValue:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
    bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:SetText("0")

    -- Fake decimal for Destro shards
    bar.SoulShardDecimal = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.SoulShardDecimal:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
    bar.SoulShardDecimal:SetShadowOffset(0, 0)
    bar.SoulShardDecimal:SetText(".")
    bar.SoulShardDecimal:Hide()


    -- FRAGMENTED POWER BARS (for Runes)
    bar.FragmentedPowerBars = {}
    bar.FragmentedPowerBarTexts = {}

    -- TICKS
    bar.ticks = {}

    bar:Hide()

    self.secondaryPowerBar = bar
    return bar
end

function NephUI:CreateFragmentedPowerBars(bar, resource)
    local cfg = self.db.profile.secondaryPowerBar
    local maxPower = UnitPowerMax("player", resource)
    
    for i = 1, maxPower do
        if not bar.FragmentedPowerBars[i] then
            local fragmentBar = CreateFrame("StatusBar", nil, bar)
            local tex = NephUI:GetGlobalTexture()
            fragmentBar:SetStatusBarTexture(tex)
            fragmentBar:GetStatusBarTexture()
            fragmentBar:SetOrientation("HORIZONTAL")
            fragmentBar:SetFrameLevel(bar.StatusBar:GetFrameLevel())
            bar.FragmentedPowerBars[i] = fragmentBar
            
            -- Create text for reload time display
            local text = fragmentBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("CENTER", fragmentBar, "CENTER", cfg.runeTimerTextX or 0, cfg.runeTimerTextY or 0)
            text:SetJustifyH("CENTER")
            text:SetFont(NephUI:GetGlobalFont(), cfg.runeTimerTextSize or 10, "OUTLINE")
            text:SetShadowOffset(0, 0)
            text:SetText("")
            bar.FragmentedPowerBarTexts[i] = text
        end
    end
end

function NephUI:UpdateFragmentedPowerDisplay(bar, resource)
    local cfg = self.db.profile.secondaryPowerBar
    local maxPower = UnitPowerMax("player", resource)
    if maxPower <= 0 then return end

    local barWidth = bar:GetWidth()
    local barHeight = bar:GetHeight()
    local fragmentedBarWidth = barWidth / maxPower
    
    -- Hide the main status bar fill (we display bars representing one (1) unit of resource each)
    bar.StatusBar:SetAlpha(0)

    -- Update texture for all fragmented bars
    local tex = NephUI:GetGlobalTexture()
    for i = 1, maxPower do
        if bar.FragmentedPowerBars[i] then
            bar.FragmentedPowerBars[i]:SetStatusBarTexture(tex)
        end
    end

    local color
    if cfg.useClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            color = { r = classColor.r, g = classColor.g, b = classColor.b }
        else
            color = GetResourceColor(resource)
        end
    elseif cfg.color then
        -- Custom color from GUI
        local r, g, b, a = cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4] or 1
        color = { r = r, g = g, b = b }
    else
        -- Default resource color
        color = GetResourceColor(resource)
    end


    if resource == Enum.PowerType.Runes then
        -- Collect rune states: ready and recharging
        local readyList = {}
        local cdList = {}
        local now = GetTime()
        
        for i = 1, maxPower do
            local start, duration, runeReady = GetRuneCooldown(i)
            if runeReady then
                table.insert(readyList, { index = i })
            else
                if start and duration and duration > 0 then
                    local elapsed = now - start
                    local remaining = math.max(0, duration - elapsed)
                    local frac = math.max(0, math.min(1, elapsed / duration))
                    table.insert(cdList, { index = i, remaining = remaining, frac = frac })
                else
                    table.insert(cdList, { index = i, remaining = math.huge, frac = 0 })
                end
            end
        end

        -- Sort cdList by ascending remaining time
        table.sort(cdList, function(a, b)
            return a.remaining < b.remaining
        end)

        -- Build final display order: ready runes first, then CD runes sorted
        local displayOrder = {}
        local readyLookup = {}
        local cdLookup = {}
        
        for _, v in ipairs(readyList) do
            table.insert(displayOrder, v.index)
            readyLookup[v.index] = true
        end
        
        for _, v in ipairs(cdList) do
            table.insert(displayOrder, v.index)
            cdLookup[v.index] = v
        end

        for pos = 1, #displayOrder do
            local runeIndex = displayOrder[pos]
            local runeFrame = bar.FragmentedPowerBars[runeIndex]
            local runeText = bar.FragmentedPowerBarTexts[runeIndex]

            if runeFrame then
                runeFrame:ClearAllPoints()
                runeFrame:SetSize(fragmentedBarWidth, barHeight)
                runeFrame:SetPoint("LEFT", bar, "LEFT", (pos - 1) * fragmentedBarWidth, 0)

                -- Update rune timer text position and font size
                if runeText then
                    runeText:ClearAllPoints()
                    runeText:SetPoint("CENTER", runeFrame, "CENTER", cfg.runeTimerTextX or 0, cfg.runeTimerTextY or 0)
                    runeText:SetFont(NephUI:GetGlobalFont(), cfg.runeTimerTextSize or 10, "OUTLINE")
                    runeText:SetShadowOffset(0, 0)
                end

                if readyLookup[runeIndex] then
                    -- Ready rune
                    runeFrame:SetMinMaxValues(0, 1)
                    runeFrame:SetValue(1)
                    runeText:SetText("")
                    runeFrame:SetStatusBarColor(color.r, color.g, color.b)
                else
                    -- Recharging rune
                    local cdInfo = cdLookup[runeIndex]
                    if cdInfo then
                        runeFrame:SetMinMaxValues(0, 1)
                        runeFrame:SetValue(cdInfo.frac)
                        
                        -- Only show timer text if enabled
                        if cfg.showFragmentedPowerBarText ~= false then
                            runeText:SetText(string.format("%.1f", math.max(0, cdInfo.remaining)))
                        else
                            runeText:SetText("")
                        end
                        
                        runeFrame:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                    else
                        runeFrame:SetMinMaxValues(0, 1)
                        runeFrame:SetValue(0)
                        runeText:SetText("")
                        runeFrame:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                    end
                end

                runeFrame:Show()
            end
        end

        -- Hide any extra rune frames beyond current maxPower
        for i = maxPower + 1, #bar.FragmentedPowerBars do
            if bar.FragmentedPowerBars[i] then
                bar.FragmentedPowerBars[i]:Hide()
                if bar.FragmentedPowerBarTexts[i] then
                    bar.FragmentedPowerBarTexts[i]:SetText("")
                end
            end
        end
        
        -- Add ticks between rune segments if enabled
        if cfg.showTicks then
            for i = 1, maxPower - 1 do
                local tick = bar.ticks[i]
                if not tick then
                    tick = bar:CreateTexture(nil, "OVERLAY")
                    tick:SetColorTexture(0, 0, 0, 1)
                    bar.ticks[i] = tick
                end
                
                local x = i * fragmentedBarWidth
                tick:ClearAllPoints()
                tick:SetPoint("LEFT", bar, "LEFT", x - 0.5, 0)
                tick:SetSize(1, barHeight)
                tick:Show()
            end
            
            -- Hide extra ticks
            for i = maxPower, #bar.ticks do
                if bar.ticks[i] then
                    bar.ticks[i]:Hide()
                end
            end
        else
            -- Hide all ticks if disabled
            for _, tick in ipairs(bar.ticks) do
                tick:Hide()
            end
        end
    end
end

function NephUI:UpdateSecondaryPowerBarTicks(bar, resource, max)
    local cfg = self.db.profile.secondaryPowerBar
    
    -- Hide all ticks first
    for _, tick in ipairs(bar.ticks) do
        tick:Hide()
    end

    -- Don't show ticks if disabled, not a ticked power type, or if it's fragmented
    if not cfg.showTicks or not tickedPowerTypes[resource] or fragmentedPowerTypes[resource] then
        return
    end

    local width  = bar:GetWidth()
    local height = bar:GetHeight()
    if width <= 0 or height <= 0 then return end

    -- For Soul Shards, use the display max (not the internal fractional max)
    local displayMax = max
    if resource == Enum.PowerType.SoulShards then
        displayMax = UnitPowerMax("player", resource) -- non-fractional max (usually 5)
    end

    local needed = displayMax - 1
    for i = 1, needed do
        local tick = bar.ticks[i]
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 1)
            bar.ticks[i] = tick
        end
        
        local x = (i / displayMax) * width
        tick:ClearAllPoints()
        tick:SetPoint("LEFT", bar.StatusBar, "LEFT", x - 0.5, 0)
        tick:SetSize(1, height)
        tick:Show()
    end
end


function NephUI:UpdateSecondaryPowerBar()
    local cfg = self.db.profile.secondaryPowerBar
    if not cfg.enabled then
        if self.secondaryPowerBar then self.secondaryPowerBar:Hide() end
        return
    end

    local anchor = _G[cfg.attachTo]
    if not anchor or not anchor:IsShown() then
        if self.secondaryPowerBar then self.secondaryPowerBar:Hide() end
        return
    end

    local bar = self:GetSecondaryPowerBar()
    local resource = GetSecondaryResource()
    
    if not resource then
        bar:Hide()
        return
    end

    -- Update layout
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or 12))
    bar:SetHeight(cfg.height or 4)

    local width = cfg.width or 0
    if width <= 0 then
        width = anchor.__cdmIconWidth
            or (self.powerBar and self.powerBar:IsShown() and self.powerBar:GetWidth())
            or anchor:GetWidth()

        -- Apply trim
        local pad = cfg.autoWidthPadding or 5.8
        width = width - (pad * 2)
        if width < 0 then width = 0 end
    end

    bar:SetWidth(width)

    -- Update background color
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    if bar.Background then
        bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end

    -- Update texture
    local tex = NephUI:GetGlobalTexture()
    bar.StatusBar:SetStatusBarTexture(tex)

    -- Get resource values
    local max, current, displayValue, valueType = GetSecondaryResourceValue(resource)
    if not max then
        bar:Hide()
        return
    end

    -- Handle fragmented power types (Runes)
    if fragmentedPowerTypes[resource] then
        self:CreateFragmentedPowerBars(bar, resource)
        self:UpdateFragmentedPowerDisplay(bar, resource)

        bar.StatusBar:SetMinMaxValues(0, max)
        bar.StatusBar:SetValue(current)

        if cfg.useClassColor then
            -- Class color
            local _, class = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                bar.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
            else
                local color = GetResourceColor(resource)
                bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        elseif cfg.color then
            -- Custom color
            local r, g, b, a = cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4] or 1
            bar.StatusBar:SetStatusBarColor(r, g, b, a)
        else
            -- Default resource color
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
end


        bar.TextValue:SetText(tostring(current))
    else
    -- Normal bar display
    bar.StatusBar:SetAlpha(1)
    bar.StatusBar:SetMinMaxValues(0, max)
    bar.StatusBar:SetValue(current)

    -- Set bar color
    if cfg.useClassColor then
        -- Class color
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            bar.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        else
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    elseif cfg.color then
        -- Custom color
        local r, g, b, a = cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4] or 1
        bar.StatusBar:SetStatusBarColor(r, g, b, a)
    else
        -- Default resource color
        local color = GetResourceColor(resource)
        bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
    end


    -- Update text (safe: uses only displayValue)
    bar.TextValue:SetText(tostring(displayValue or 0))
    
    -- Hide fragmented bars
    for _, fragmentBar in ipairs(bar.FragmentedPowerBars) do
        fragmentBar:Hide()
    end
end

    bar.TextValue:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
    bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:ClearAllPoints()
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", cfg.textX or 0, cfg.textY or 0)

    if bar.SoulShardDecimal then
        bar.SoulShardDecimal:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
        bar.SoulShardDecimal:SetShadowOffset(0, 0)
    end


    -- Show text
    bar.TextFrame:SetShown(cfg.showText ~= false)

    if not fragmentedPowerTypes[resource] then
        self:UpdateSecondaryPowerBarTicks(bar, resource, max)
    end

        -- Handle fake decimal
    if bar.SoulShardDecimal then
        local _, class = UnitClass("player")
        local spec = GetSpecialization()

        if resource == Enum.PowerType.SoulShards
            and class == "WARLOCK"
            and spec == 3
        then
            bar.SoulShardDecimal:ClearAllPoints()
            bar.SoulShardDecimal:SetPoint("CENTER", bar.TextValue, "CENTER", 0, 0)
            bar.SoulShardDecimal:Show()
        else
            bar.SoulShardDecimal:Hide()
        end
    end


    bar:Show()
end

-- EVENT HANDLER

function NephUI:OnUnitPower(_, unit)
    -- Be forgiving: if unit is nil or not "player", still update.
    -- It's cheap and avoids missing power updates.
    if unit and unit ~= "player" then
        return
    end

    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
end


-- REFRESH

local oldRefreshAll = NephUI.RefreshAll
function NephUI:RefreshAll()
    if oldRefreshAll then
        oldRefreshAll(self)
    end
    
    -- Refresh resource bars with new settings
    for _, name in ipairs(self.viewers) do
        local viewer = _G[name]
        if viewer and viewer:IsShown() then
            self:ApplyViewerSkin(viewer)
        end
    end
    
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
    self:UpdateCastBarLayout()
    
    -- Refresh unit frames if they exist
    if self.UnitFrames and self.UnitFrames.RefreshFrames then
        self.UnitFrames:RefreshFrames()
    end
end

-- RUNE UPDATE TICKER

local runeUpdateTicker = nil

local function StartRuneUpdateTicker(self)
    if runeUpdateTicker then return end
    
    runeUpdateTicker = C_Timer.NewTicker(0.1, function()
        local resource = GetSecondaryResource()
        if resource == Enum.PowerType.Runes then
            local bar = self.secondaryPowerBar
            if bar and bar:IsShown() and fragmentedPowerTypes[resource] then
                self:UpdateFragmentedPowerDisplay(bar, resource)
            end
        else
            -- Stop ticker if not on a DK anymore
            if runeUpdateTicker then
                runeUpdateTicker:Cancel()
                runeUpdateTicker = nil
            end
        end
    end)
end

local function StopRuneUpdateTicker()
    if runeUpdateTicker then
        runeUpdateTicker:Cancel()
        runeUpdateTicker = nil
    end
end

-- SOUL FRAGMENTS UPDATE TICKER

local soulUpdateTicker = nil

local function StartSoulUpdateTicker(self)
    if soulUpdateTicker then return end
    
    soulUpdateTicker = C_Timer.NewTicker(0.1, function()
        local resource = GetSecondaryResource()
        if resource == "SOUL" then
            local bar = self.secondaryPowerBar
            if bar and bar:IsShown() then
                self:UpdateSecondaryPowerBar()
            end
        else
            -- Stop ticker if not on a DH with soul resource anymore
            if soulUpdateTicker then
                soulUpdateTicker:Cancel()
                soulUpdateTicker = nil
            end
        end
    end)
end

local function StopSoulUpdateTicker()
    if soulUpdateTicker then
        soulUpdateTicker:Cancel()
        soulUpdateTicker = nil
    end
end

-- INITIALIZATION

local function InitializeResourceBars(self)
    -- Register additional events
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnShapeshiftChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        EnsureDemonHunterSoulBar()
        self:OnUnitPower()
    end)

    -- POWER UPDATES
    self:RegisterEvent("UNIT_POWER_FREQUENT", "OnUnitPower")
    self:RegisterEvent("UNIT_POWER_UPDATE", "OnUnitPower")

    -- Ensure Demon Hunter soul bar is spawned
    EnsureDemonHunterSoulBar()

    -- Start rune ticker if we're a death knight
    local _, class = UnitClass("player")
    if class == "DEATHKNIGHT" then
        StartRuneUpdateTicker(self)
    end
    
    -- Start soul fragments ticker if we're a demon hunter with soul resource
    local resource = GetSecondaryResource()
    if resource == "SOUL" then
        StartSoulUpdateTicker(self)
    end

    -- Initial update
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
end


function NephUI:OnSpecChanged()
    -- Ensure Demon Hunter soul bar is spawned when spec changes
    EnsureDemonHunterSoulBar()
    
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
    
    -- Start/stop rune ticker based on class
    local resource = GetSecondaryResource()
    if resource == Enum.PowerType.Runes then
        StartRuneUpdateTicker(self)
        StopSoulUpdateTicker()
    elseif resource == "SOUL" then
        StartSoulUpdateTicker(self)
        StopRuneUpdateTicker()
    else
        StopRuneUpdateTicker()
        StopSoulUpdateTicker()
    end
end

function NephUI:OnShapeshiftChanged()
    -- Druid form changes affect primary/secondary resources
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
end
-- Hook into that shit
local oldOnEnable = NephUI.OnEnable
function NephUI:OnEnable()
    if oldOnEnable then
        oldOnEnable(self)
    end
    InitializeResourceBars(self)
end