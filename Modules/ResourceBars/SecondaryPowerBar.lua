local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

-- Get ResourceBars module
local ResourceBars = NephUI.ResourceBars
if not ResourceBars then
    error("NephUI: ResourceBars module not initialized! Load ResourceDetection.lua first.")
end

-- Get functions from ResourceDetection
local GetSecondaryResource = ResourceBars.GetSecondaryResource
local GetResourceColor = ResourceBars.GetResourceColor
local GetSecondaryResourceValue = ResourceBars.GetSecondaryResourceValue
local tickedPowerTypes = ResourceBars.tickedPowerTypes
local fragmentedPowerTypes = ResourceBars.fragmentedPowerTypes

-- SECONDARY POWER BAR

function ResourceBars:GetSecondaryPowerBar()
    if NephUI.secondaryPowerBar then return NephUI.secondaryPowerBar end

    local cfg = NephUI.db.profile.secondaryPowerBar
    local anchor = _G[cfg.attachTo] or UIParent
    local anchorPoint = cfg.anchorPoint or "CENTER"

    local bar = CreateFrame("Frame", ADDON_NAME .. "SecondaryPowerBar", anchor)
    bar:SetFrameStrata("MEDIUM")
    bar:SetHeight(NephUI:Scale(cfg.height or 4))
    bar:SetPoint("CENTER", anchor, anchorPoint, NephUI:Scale(cfg.offsetX or 0), NephUI:Scale(cfg.offsetY or 12))

    local width = cfg.width or 0
    if width <= 0 then
        width = (anchor.__cdmIconWidth or anchor:GetWidth())
        -- Round down to handle decimal values (e.g., 100.9 -> 100) to prevent overflow
        width = math.floor(width)

        -- Apply trim - scale padding first, then subtract from pixel width
        local pad = NephUI:Scale(cfg.autoWidthPadding or 5.8)
        width = width - (pad * 2)
        if width < 0 then width = 0 end
        -- Width is already in pixels, no need to scale again
    else
        width = NephUI:Scale(width)
    end

    bar:SetWidth(width)

    -- BACKGROUND (lowest frame level)
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    -- STATUS BAR (for non-fragmented resources) - frame level 1
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetAllPoints()
    -- Use GetTexture helper: if cfg.texture is set, use it; otherwise use global texture
    local tex = NephUI:GetTexture(cfg.texture)
    bar.StatusBar:SetStatusBarTexture(tex)
    bar.StatusBar:SetFrameLevel(bar:GetFrameLevel() + 1)

    -- BORDER - frame level 2
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetFrameLevel(bar:GetFrameLevel() + 2)
    local borderSize = cfg.borderSize or 1
    local borderOffset = NephUI:Scale(borderSize)
    bar.Border:SetPoint("TOPLEFT", bar, -borderOffset, borderOffset)
    bar.Border:SetPoint("BOTTOMRIGHT", bar, borderOffset, -borderOffset)
    bar.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = borderSize,
    })
    local borderColor = cfg.borderColor or { 0, 0, 0, 1 }
    bar.Border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    -- TICKS FRAME - frame level 3
    bar.TicksFrame = CreateFrame("Frame", nil, bar)
    bar.TicksFrame:SetAllPoints(bar)
    bar.TicksFrame:SetFrameLevel(bar:GetFrameLevel() + 3)

    -- RUNE TIMER TEXT FRAME - frame level 3 (above border, same as ticks)
    bar.RuneTimerTextFrame = CreateFrame("Frame", nil, bar)
    bar.RuneTimerTextFrame:SetAllPoints(bar)
    bar.RuneTimerTextFrame:SetFrameLevel(bar:GetFrameLevel() + 3)

    -- TEXT FRAME - frame level 4 (highest)
    bar.TextFrame = CreateFrame("Frame", nil, bar)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + 4)

    bar.TextValue = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", NephUI:Scale(cfg.textX or 0), NephUI:Scale(cfg.textY or 0))
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

    NephUI.secondaryPowerBar = bar
    return bar
end

function ResourceBars:CreateFragmentedPowerBars(bar, resource)
    local cfg = NephUI.db.profile.secondaryPowerBar
    local maxPower = UnitPowerMax("player", resource)
    
    for i = 1, maxPower do
        if not bar.FragmentedPowerBars[i] then
            local fragmentBar = CreateFrame("StatusBar", nil, bar)
            -- Use GetTexture helper: if cfg.texture is set, use it; otherwise use global texture
            local tex = NephUI:GetTexture(cfg.texture)
            fragmentBar:SetStatusBarTexture(tex)
            fragmentBar:GetStatusBarTexture()
            fragmentBar:SetOrientation("HORIZONTAL")
            fragmentBar:SetFrameLevel(bar:GetFrameLevel() + 1)
            bar.FragmentedPowerBars[i] = fragmentBar
            
            -- Create text for reload time display (parented to RuneTimerTextFrame for higher frame level)
            local text = bar.RuneTimerTextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("TOP", fragmentBar, "TOP", NephUI:Scale(cfg.runeTimerTextX or 0), NephUI:Scale(cfg.runeTimerTextY or 0))
            text:SetJustifyH("CENTER")
            text:SetFont(NephUI:GetGlobalFont(), cfg.runeTimerTextSize or 10, "OUTLINE")
            text:SetShadowOffset(0, 0)
            text:SetText("")
            bar.FragmentedPowerBarTexts[i] = text
        end
    end
end

function ResourceBars:UpdateFragmentedPowerDisplay(bar, resource)
    local cfg = NephUI.db.profile.secondaryPowerBar
    local maxPower = UnitPowerMax("player", resource)
    if maxPower <= 0 then return end

    local barWidth = bar:GetWidth()
    local barHeight = bar:GetHeight()
    -- Calculate fragmented bar width - use floor to ensure pixel-perfect alignment
    -- This ensures each fragment is a whole pixel width, preventing sub-pixel rendering
    local fragmentedBarWidth = math.floor(barWidth / maxPower)
    
    -- Hide the main status bar fill (we display bars representing one (1) unit of resource each)
    bar.StatusBar:SetAlpha(0)

    -- Update texture for all fragmented bars (use per-bar texture if set, otherwise use global)
    local tex = NephUI:GetTexture(cfg.texture)
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
                -- Calculate position using whole pixel widths for pixel-perfect alignment
                local runeX = (pos - 1) * fragmentedBarWidth
                -- barHeight is already in pixels (from bar:GetHeight()), no need to scale
                runeFrame:SetSize(fragmentedBarWidth, barHeight)
                runeFrame:SetPoint("LEFT", bar, "LEFT", runeX, 0)

                -- Update rune timer text position and font size
                if runeText then
                    runeText:ClearAllPoints()
                    runeText:SetPoint("TOP", runeFrame, "TOP", NephUI:Scale(cfg.runeTimerTextX or 0), NephUI:Scale(cfg.runeTimerTextY or 0))
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
                    tick = bar.TicksFrame:CreateTexture(nil, "OVERLAY")
                    tick:SetColorTexture(0, 0, 0, 1)
                    bar.ticks[i] = tick
                end
                
                -- Calculate tick position using whole pixel widths for pixel-perfect alignment
                local tickX = i * fragmentedBarWidth
                tick:ClearAllPoints()
                tick:SetPoint("LEFT", bar, "LEFT", tickX, 0)
                -- Ensure tick width is at least 1 pixel to prevent disappearing
                local tickWidth = math.max(1, NephUI:Scale(1))
                -- barHeight is already in pixels (from bar:GetHeight()), no need to scale
                tick:SetSize(tickWidth, barHeight)
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

function ResourceBars:UpdateSecondaryPowerBarTicks(bar, resource, max)
    local cfg = NephUI.db.profile.secondaryPowerBar
    
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
            tick = bar.TicksFrame:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 1)
            bar.ticks[i] = tick
        end
        
        local x = (i / displayMax) * width
        tick:ClearAllPoints()
        -- x is already in pixels (calculated from bar width), no need to scale
        tick:SetPoint("LEFT", bar.StatusBar, "LEFT", x, 0)
        -- Ensure tick width is at least 1 pixel to prevent disappearing
        local tickWidth = math.max(1, NephUI:Scale(1))
        -- height is already in pixels (from bar:GetHeight()), no need to scale
        tick:SetSize(tickWidth, height)
        tick:Show()
    end
end

function ResourceBars:UpdateSecondaryPowerBar()
    local cfg = NephUI.db.profile.secondaryPowerBar
    if not cfg.enabled then
        if NephUI.secondaryPowerBar then NephUI.secondaryPowerBar:Hide() end
        return
    end

    local anchor = _G[cfg.attachTo]
    if not anchor or not anchor:IsShown() then
        if NephUI.secondaryPowerBar then NephUI.secondaryPowerBar:Hide() end
        return
    end

    local bar = self:GetSecondaryPowerBar()
    local resource = GetSecondaryResource()
    
    if not resource then
        bar:Hide()
        return
    end

    -- Update layout
    local anchorPoint = cfg.anchorPoint or "CENTER"
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, anchorPoint, NephUI:Scale(cfg.offsetX or 0), NephUI:Scale(cfg.offsetY or 12))
    bar:SetHeight(NephUI:Scale(cfg.height or 4))

    local width = cfg.width or 0
    if width <= 0 then
        width = anchor.__cdmIconWidth
            or (NephUI.powerBar and NephUI.powerBar:IsShown() and NephUI.powerBar:GetWidth())
            or anchor:GetWidth()
        -- Round down to handle decimal values (e.g., 100.9 -> 100) to prevent overflow
        width = math.floor(width)

        -- Apply trim - scale padding first, then subtract from pixel width
        local pad = NephUI:Scale(cfg.autoWidthPadding or 5.8)
        width = width - (pad * 2)
        if width < 0 then width = 0 end
        -- Width is already in pixels, no need to scale again
    else
        width = NephUI:Scale(width)
    end

    bar:SetWidth(width)

    -- Update background color
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    if bar.Background then
        bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end

    -- Update texture (use per-bar texture if set, otherwise use global)
    local tex = NephUI:GetTexture(cfg.texture)
    bar.StatusBar:SetStatusBarTexture(tex)

    -- Update border size and color
    local borderSize = cfg.borderSize or 1
    if bar.Border then
        local borderOffset = NephUI:Scale(borderSize)
        bar.Border:ClearAllPoints()
        bar.Border:SetPoint("TOPLEFT", bar, -borderOffset, borderOffset)
        bar.Border:SetPoint("BOTTOMRIGHT", bar, borderOffset, -borderOffset)
        bar.Border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        })
        -- Update border color
        local borderColor = cfg.borderColor or { 0, 0, 0, 1 }
        bar.Border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        -- Show/hide border based on size
        if borderSize > 0 then
            bar.Border:Show()
        else
            bar.Border:Hide()
        end
    end

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
            if r and g and b and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                bar.StatusBar:SetStatusBarColor(r, g, b, a or 1)
            else
                -- Fallback to default resource color if custom color is invalid
                local color = GetResourceColor(resource)
                bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
            end
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
            if r and g and b and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                bar.StatusBar:SetStatusBarColor(r, g, b, a or 1)
            else
                -- Fallback to default resource color if custom color is invalid
                local color = GetResourceColor(resource)
                bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
            end
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
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", NephUI:Scale(cfg.textX or 0), NephUI:Scale(cfg.textY or 0))

    if bar.SoulShardDecimal then
        bar.SoulShardDecimal:SetFont(NephUI:GetGlobalFont(), cfg.textSize or 12, "OUTLINE")
        bar.SoulShardDecimal:SetShadowOffset(0, 0)
    end

    -- Show text
    bar.TextFrame:SetShown(cfg.showText ~= false)

    -- Handle hide bar but show text option
    if cfg.hideBarShowText then
        -- Hide the bar visuals but keep text visible
        if bar.StatusBar then
            bar.StatusBar:Hide()
        end
        if bar.Background then
            bar.Background:Hide()
        end
        -- Hide border when bar is hidden
        if bar.Border then
            bar.Border:Hide()
        end
        -- Hide ticks when bar is hidden
        for _, tick in ipairs(bar.ticks) do
            tick:Hide()
        end
        -- Hide fragmented power bars (runes) when bar is hidden
        for _, fragmentBar in ipairs(bar.FragmentedPowerBars) do
            fragmentBar:Hide()
        end
        -- Hide rune timer texts when bar is hidden
        for _, runeText in ipairs(bar.FragmentedPowerBarTexts) do
            if runeText then
                runeText:Hide()
            end
        end
    else
        -- Show the bar visuals
        if bar.StatusBar then
            bar.StatusBar:Show()
        end
        if bar.Background then
            bar.Background:Show()
        end
        -- Show border if size > 0
        if bar.Border and (cfg.borderSize or 1) > 0 then
            bar.Border:Show()
        end
        -- Update ticks if this is a ticked power type and not fragmented
        if not fragmentedPowerTypes[resource] then
            self:UpdateSecondaryPowerBarTicks(bar, resource, max)
        end
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

-- Expose to main addon for backwards compatibility
NephUI.GetSecondaryPowerBar = function(self) return ResourceBars:GetSecondaryPowerBar() end
NephUI.UpdateSecondaryPowerBar = function(self) return ResourceBars:UpdateSecondaryPowerBar() end
NephUI.UpdateSecondaryPowerBarTicks = function(self, bar, resource, max) return ResourceBars:UpdateSecondaryPowerBarTicks(bar, resource, max) end
NephUI.CreateFragmentedPowerBars = function(self, bar, resource) return ResourceBars:CreateFragmentedPowerBars(bar, resource) end
NephUI.UpdateFragmentedPowerDisplay = function(self, bar, resource) return ResourceBars:UpdateFragmentedPowerDisplay(bar, resource) end

