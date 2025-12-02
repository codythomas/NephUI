local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Get CastBars module
local CastBars = NephUI.CastBars
if not CastBars then
    error("NephUI: CastBars module not initialized! Load CastBars.lua first.")
end

local CreateBorder = CastBars.CreateBorder

-- FOCUS CAST BAR

function CastBars:GetFocusCastBar()
    if NephUI.focusCastBar then return NephUI.focusCastBar end

    local cfg    = NephUI.db.profile.focusCastBar
    local anchor = _G[cfg.attachTo] or UIParent
    local anchorPoint = cfg.anchorPoint or "CENTER"

    local bar = CreateFrame("Frame", ADDON_NAME .. "FocusCastBar", anchor)
    bar:SetFrameStrata("MEDIUM")

    local height = cfg.height or 10
    bar:SetHeight(NephUI:Scale(height))
    bar:SetPoint("CENTER", anchor, anchorPoint, NephUI:Scale(cfg.offsetX or 0), NephUI:Scale(cfg.offsetY or -50))
    
    local width = cfg.width or 0
    if width <= 0 then
        width = anchor:GetWidth() or 200
        -- anchor:GetWidth() returns pixels, no need to scale
    else
        width = NephUI:Scale(width)
    end
    bar:SetWidth(width)

    CreateBorder(bar)

    -- Status bar
    bar.status = CreateFrame("StatusBar", nil, bar)
    -- Use GetTexture helper: if cfg.texture is set, use it; otherwise use global texture
    local tex = NephUI:GetTexture(NephUI.db.profile.focusCastBar.texture)
    bar.status:SetStatusBarTexture(tex)

    local sbTex = bar.status:GetStatusBarTexture()
    if sbTex then
        sbTex:SetDrawLayer("BACKGROUND")
    end

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar.status)
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    -- Text
    bar.spellName = bar.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.spellName:SetJustifyH("LEFT")

    bar.timeText = bar.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.timeText:SetJustifyH("RIGHT")

    bar:Hide()

    NephUI.focusCastBar = bar
    return bar
end

function CastBars:UpdateFocusCastBarLayout()
    local cfg = NephUI.db.profile.focusCastBar
    if not cfg then return end
    
    local bar = NephUI.focusCastBar
    if not bar then return end
    
    if not cfg.enabled then
        bar:Hide()
        return
    end
    
    local anchor = _G[cfg.attachTo] or UIParent
    if not anchor or not anchor:IsShown() then
        bar:Hide()
        return
    end
    
    local anchorPoint = cfg.anchorPoint or "CENTER"
    local height = cfg.height or 18
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, anchorPoint, NephUI:Scale(cfg.offsetX or 0), NephUI:Scale(cfg.offsetY or -50))
    bar:SetHeight(NephUI:Scale(height))
    
    local width = cfg.width or 0
    if width <= 0 then
        width = anchor:GetWidth() or 200
        -- Round down to handle decimal values (e.g., 100.9 -> 100) to prevent overflow
        width = math.floor(width)
        
        -- Apply trim - scale padding first, then subtract from pixel width
        width = width - NephUI:Scale(2)
        if width < 0 then width = 0 end
        -- Width is already in pixels, no need to scale again
    else
        width = NephUI:Scale(width)
    end
    bar:SetWidth(width)
    
    if bar.border then
        bar.border:ClearAllPoints()
        local borderOffset = NephUI:Scale(1)
        bar.border:SetPoint("TOPLEFT", bar, -borderOffset, borderOffset)
        bar.border:SetPoint("BOTTOMRIGHT", bar, borderOffset, -borderOffset)
    end
    
    -- Icon: left side
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    -- Use bar height directly (already in pixels from SetHeight)
    bar.icon:SetWidth(bar:GetHeight())
    
    bar.status:ClearAllPoints()
    bar.status:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 0, 0)
    bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    
    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar.status)
    
    -- Update background color
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    
    -- Update texture (use per-bar texture if set, otherwise use global)
    local tex = NephUI:GetTexture(cfg.texture)
    bar.status:SetStatusBarTexture(tex)
    
    local sbTex = bar.status:GetStatusBarTexture()
    if sbTex then
        sbTex:SetDrawLayer("BACKGROUND")
    end
    
    -- Update status bar color
    local color = cfg.color or { 1.0, 0.0, 0.0, 1.0 }
    local r, g, b, a = color[1], color[2], color[3], color[4] or 1
    
    bar.status:SetStatusBarColor(r, g, b, a or 1)
    
    -- Text positioning
    bar.spellName:ClearAllPoints()
    bar.spellName:SetPoint("LEFT", bar.status, "LEFT", NephUI:Scale(4), 0)
    
    bar.timeText:ClearAllPoints()
    bar.timeText:SetPoint("RIGHT", bar.status, "RIGHT", NephUI:Scale(-4), 0)
    
    -- Update text size
    local font = NephUI:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 16, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)
    
    bar.timeText:SetFont(font, cfg.textSize or 16, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)
    
    -- Show/hide time text based on setting
    if cfg.showTimeText ~= false then
        bar.timeText:Show()
    else
        bar.timeText:Hide()
    end
end

function CastBars:HookFocusCastBar()
    -- Hook Focus cast bar
    local focusSpellbar = _G["FocusFrame"] and _G["FocusFrame"].spellbar
    if focusSpellbar and not focusSpellbar.__nephuiHooked then
        focusSpellbar.__nephuiHooked = true
        
        focusSpellbar:HookScript("OnShow", function(self)
            local cfg = NephUI.db.profile.focusCastBar
            if not cfg or not cfg.enabled then
                if NephUI.focusCastBar then NephUI.focusCastBar:Hide() end
                return
            end
            
            local bar = CastBars:GetFocusCastBar()
            if not bar then return end
            
            CastBars:UpdateFocusCastBarLayout()
            
            -- Get spell info from the default cast bar
            local spellID = self.spellID
            if spellID then
                bar.icon:SetTexture(C_Spell.GetSpellTexture(spellID) or 136243)
            end
            
            -- Get spell name from the text field
            if self.Text then
                bar.spellName:SetText(self.Text:GetText() or "Casting...")
            end
            
            -- Get min/max values and set up the cast bar
            local min, max = self:GetMinMaxValues()
            if min and max then
                bar.status:SetMinMaxValues(min, max)
                bar.status:SetValue(self:GetValue() or 0)
            end
            
            bar:Show()
        end)
        
        focusSpellbar:HookScript("OnHide", function()
            if NephUI.focusCastBar then
                NephUI.focusCastBar:Hide()
            end
        end)
        
        -- Hook OnUpdate to sync progress and time text
        -- Use simple format without "s" suffix (just use Blizzard's values directly)
        focusSpellbar:HookScript("OnUpdate", function(self, elapsed)
            local cfg = NephUI.db.profile.focusCastBar
            if not cfg or not cfg.enabled then return end
            
            local bar = NephUI.focusCastBar
            if not bar or not bar:IsShown() then return end
            
            local progress = self:GetValue()
            if progress then
                bar.status:SetValue(progress)
            end
            
            -- Update time text using Blizzard's values directly (avoids math on secret values)
            if bar.timeText and cfg.showTimeText ~= false then
                local min, max = self:GetMinMaxValues()
                if min and max then
                    bar.timeText:SetFormattedText("%.1f/%.1f", progress or 0, max)
                end
            end
        end)
    end
end

-- Expose to main addon for backwards compatibility
NephUI.GetFocusCastBar = function(self) return CastBars:GetFocusCastBar() end
NephUI.UpdateFocusCastBarLayout = function(self) return CastBars:UpdateFocusCastBarLayout() end

