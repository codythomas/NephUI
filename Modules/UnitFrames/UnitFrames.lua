local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

-- Unit Frame System
NephUI.UnitFrames = NephUI.UnitFrames or {}
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

-- Export helper functions
UF.UnitToFrameName = UnitToFrameName
UF.DEFAULT_UNITFRAME_STRATA = DEFAULT_UNITFRAME_STRATA
UF.GetUnitFrameConfig = GetUnitFrameConfig
UF.ResolveFrameName = ResolveFrameName

-- Media resolution
function UF:ResolveMedia()
    self.Media = self.Media or {}
    
    -- Always use global font
    self.Media.Font = NephUI:GetGlobalFont()
    
    -- Check for texture overrides in General settings, otherwise use global texture
    local db = NephUI.db and NephUI.db.profile and NephUI.db.profile.unitFrames
    local GeneralDB = db and db.General
    local foregroundOverride = GeneralDB and GeneralDB.ForegroundTexture
    local backgroundOverride = GeneralDB and GeneralDB.BackgroundTexture
    
    self.Media.ForegroundTexture = NephUI:GetTexture(foregroundOverride)
    self.Media.BackgroundTexture = NephUI:GetTexture(backgroundOverride)
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

function UF:Initialize()
    local db = NephUI.db.profile.unitFrames
    if not db or not db.enabled then return end
    
    -- Resolve media
    self:ResolveMedia()
    
    -- Hide default unit frames
    if self.HideDefaultUnitFrames then
        self:HideDefaultUnitFrames()
    end
    
    -- Hook cooldown viewer and anchor frames
    if self.HookCooldownViewer then
        self:HookCooldownViewer()
    end
    if self.HookAnchorFrames then
        self:HookAnchorFrames()
    end
    
    -- Hook edit mode
    if self.HookEditMode then
        self:HookEditMode()
    end
    
    -- Create unit frames
    local units = {"player", "target", "targettarget", "pet", "focus"}
    for _, unit in ipairs(units) do
        if self.CreateUnitFrame then
            self:CreateUnitFrame(unit)
        end
    end
    
    -- Create boss frames (up to 5)
    for i = 1, 5 do
        local unit = "boss" .. i
        if self.CreateUnitFrame then
            self:CreateUnitFrame(unit)
        end
    end
    
    -- Hook target and focus power bars
    if self.HookTargetAndFocusPowerBars then
        C_Timer.After(0.1, function()
            self:HookTargetAndFocusPowerBars()
        end)
    end
end

function UF:RefreshFrames()
    local db = NephUI.db.profile.unitFrames
    if not db or not db.enabled then return end
    
    -- Resolve media with latest settings
    self:ResolveMedia()
    
    -- Update all unit frames
    local units = {"player", "target", "targettarget", "pet", "focus"}
    for _, unit in ipairs(units) do
        if self.UpdateUnitFrame then
            self:UpdateUnitFrame(unit)
        end
    end
    
    -- Update boss frames
    for i = 1, 5 do
        local unit = "boss" .. i
        if self.UpdateUnitFrame then
            self:UpdateUnitFrame(unit)
        end
    end
    
    -- Update edit mode anchors
    if self.UpdateEditModeAnchors then
        self:UpdateEditModeAnchors()
    end
end

-- Expose to main addon for backwards compatibility
NephUI.UnitFrames = UF

