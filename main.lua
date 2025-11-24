local ADDON_NAME, ns = ...

local NephUI = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0"
)

ns.Addon = NephUI

local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub("LibCustomGlow-1.0", true)

local AceSerializer = LibStub("AceSerializer-3.0", true)
local LibDeflate    = LibStub("LibDeflate", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local LibDualSpec   = LibStub("LibDualSpec-1.0", true)

LSM:Register("statusbar","Neph", [[Interface\AddOns\NephUI\Media\Neph]])
LSM:Register("font","EXPRESSWAY", [[Interface\AddOns\NephUI\Fonts\Expressway.TTF]])

-- Profile Import/Export

function NephUI:ExportProfileToString()
    if not self.db or not self.db.profile then
        return "No profile loaded."
    end
    if not AceSerializer or not LibDeflate then
        return "Export requires AceSerializer-3.0 and LibDeflate."
    end

    local serialized = AceSerializer:Serialize(self.db.profile)
    if not serialized or type(serialized) ~= "string" then
        return "Failed to serialize profile."
    end

    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return "Failed to compress profile."
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return "Failed to encode profile."
    end

    return "NUI1:" .. encoded
end

function NephUI:ImportProfileFromString(str)
    if not self.db or not self.db.profile then
        return false, "No profile loaded."
    end
    if not AceSerializer or not LibDeflate then
        return false, "Import requires AceSerializer-3.0 and LibDeflate."
    end
    if not str or str == "" then
        return false, "No data provided."
    end

    str = str:gsub("%s+", "")
    str = str:gsub("^CDM1:", "")  -- Backwards compatibility
    str = str:gsub("^NUI1:", "")

    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then
        return false, "Could not decode string (maybe corrupted)."
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return false, "Could not decompress data."
    end

    local ok, t = AceSerializer:Deserialize(serialized)
    if not ok or type(t) ~= "table" then
        return false, "Could not deserialize profile."
    end

    local profile = self.db.profile
    for k in pairs(profile) do
        profile[k] = nil
    end
    for k, v in pairs(t) do
        profile[k] = v
    end

    if self.RefreshAll then
        self:RefreshAll()
    end

    return true
end

-- Defaults

NephUI.viewers = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

local defaults = {
    profile = {
        general = {
            globalTexture = "Neph",
            globalFont = "EXPRESSWAY",
            uiScale = 0.6555,
        },
        viewers = {
            EssentialCooldownViewer = {
                enabled          = true,
                iconSize         = 58.1,
                aspectRatioCrop  = 1.0,
                spacing          = -9,
                zoom             = 0.08,
                borderSize       = 1,
                borderColor      = { 0, 0, 0, 1 },
                chargeTextAnchor = "BOTTOMRIGHT",
                countTextSize    = 16,
                countTextOffsetX = 0,
                countTextOffsetY = 0,
                rowLimit         = 0,
            },
            UtilityCooldownViewer = {
                enabled          = true,
                iconSize         = 54.1,
                aspectRatioCrop  = 1.0,
                spacing          = -9,
                zoom             = 0.08,
                borderSize       = 1,
                borderColor      = { 0, 0, 0, 1 },
                chargeTextAnchor = "BOTTOMRIGHT",
                countTextSize    = 16,
                countTextOffsetX = 0,
                countTextOffsetY = 0,
                rowLimit         = 0,
            },
            BuffIconCooldownViewer = {
                enabled          = true,
                iconSize         = 48.1,
                aspectRatioCrop  = 1.0,
                spacing          = -9,
                zoom             = 0.08,
                borderSize       = 1,
                borderColor      = { 0, 0, 0, 1 },
                chargeTextAnchor = "BOTTOMRIGHT",
                countTextSize    = 14,
                countTextOffsetX = 0,
                countTextOffsetY = 0,
                rowLimit         = 0,
                rowGrowDirection = "Up",
            },
        },
        powerBar = {
            enabled           = true,
            attachTo          = "EssentialCooldownViewer",
            height            = 14,
            offsetY           = 33,
            width             = 0,
            texture           = "Neph",
            useClassColor     = true,
            showManaAsPercent = true,
            showText          = true,
            showTicks         = true, 
            textSize          = 20,
            textX             = 0.5,
            textY             = 2,
            bgColor           = { 0.15, 0.15, 0.15, 1 },
        },
        secondaryPowerBar = {
            enabled       = true,
            attachTo      = "EssentialCooldownViewer",
            height        = 14,
            offsetY       = 50,
            width         = 0,
            texture       = "Neph",
            useClassColor = false,
            showText      = true,
            showTicks     = true,
            showFragmentedPowerBarText  = false,
            textSize      = 16,
            textX         = 0.5,
            textY         = 2,
            runeTimerTextSize = 10,
            runeTimerTextX    = 0,
            runeTimerTextY    = 0,
            bgColor       = { 0.15, 0.15, 0.15, 1 },
        },
        castBar = {
            enabled       = true,
            attachTo      = "EssentialCooldownViewer",
            height        = 24,
            offsetY       = -82.9,
            texture       = "Neph",
            color         = { 1.0, 0.7, 0.0, 1.0 },
            useClassColor = false,
            textSize      = 16,
            width         = 0,
            bgColor       = { 0.1, 0.1, 0.1, 1 },
            showTimeText  = true,
        },
        targetCastBar = {
            enabled       = true,
            attachTo      = "NephUI_Target",
            height        = 24.6,
            offsetY       = -39,
            texture       = "Neph",
            color         = { 1.0, 0.0, 0.0, 1.0 },
            textSize      = 16,
            width         = 0,
            bgColor       = { 0.1, 0.1, 0.1, 1 },
            showTimeText  = true,
        },
        focusCastBar = {
            enabled       = true,
            attachTo      = "NephUI_Focus",
            height        = 24,
            offsetY       = 29.2,
            texture       = "Neph",
            color         = { 1.0, 0.0, 0.0, 1.0 },
            textSize      = 16,
            width         = 0,
            bgColor       = { 0.1, 0.1, 0.1, 1 },
            showTimeText  = true,
        },
        customIcons = {
            enabled = true,
            countTextSize = 16,
            trackedItems = {224021, 241308},
            items = {
                iconSize = 42,
                aspectRatioCrop = 1.0,
                spacing = 1,
                rowLimit = 0,
                growthDirection = "Right",
                borderSize = 1,
                borderColor = { 0, 0, 0, 1 },
                anchorFrame = "NephUI_Player",
                offsetX = -94,
                offsetY = -46,
            },
            -- Trinkets settings (for equipped trinkets/weapons)
            trinkets = {
                trinket1 = true,
                trinket2 = true,
                weapon1 = true,
                weapon2 = true,
                iconSize = 42,
                aspectRatioCrop = 1.0,
                spacing = 1,
                rowLimit = 0,
                growthDirection = "Left",
                borderSize = 1,
                borderColor = { 0, 0, 0, 1 },
                anchorFrame = "NephUI_Player",
                offsetX = 94,
                offsetY = 46,
            },
        },
        unitFrames = {
            enabled = true,
            General = {
                ShowEditModeAnchors = false,
                Font = "EXPRESSWAY",
                FontFlag = "OUTLINE",
                FontShadows = {
                    Color = {0, 0, 0, 0},
                    OffsetX = 0,
                    OffsetY = 0
                },
                ForegroundTexture = "Neph",
                BackgroundTexture = "Neph",
                CustomColors = {
                    Reaction = {
                        [1] = {204/255, 64/255, 64/255},    -- Hated
                        [2] = {204/255, 64/255, 64/255},    -- Hostile
                        [3] = {204/255, 128/255, 64/255},   -- Unfriendly
                        [4] = {255/255, 234/255, 126/255},   -- Neutral
                        [5] = {64/255, 204/255, 64/255},    -- Friendly
                        [6] = {64/255, 204/255, 64/255},    -- Honored
                        [7] = {64/255, 204/255, 64/255},    -- Revered
                        [8] = {64/255, 204/255, 64/255},    -- Exalted
                    },
                    Power = {
                        [0] = {0, 0.50, 1},            -- Mana
                        [1] = {1, 0, 0},            -- Rage
                        [2] = {1, 0.5, 0.25},       -- Focus
                        [3] = {1, 1, 0},            -- Energy
                        [6] = {0, 0.82, 1},         -- Runic Power
                        [8] = {0.3, 0.52, 0.9},     -- Lunar Power
                        [11] = {0, 0.5, 1},         -- Maelstrom
                        [13] = {0.4, 0, 0.8},       -- Insanity
                        [17] = {0.79, 0.26, 0.99},  -- Fury
                        [18] = {1, 0.61, 0}         -- Pain
                    },
                },
            },
            player = {
                Enabled = true,
                Frame = {
                    Width = 272,
                    Height = 48,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    AnchorFrame = "EssentialCooldownViewer",
                    AnchorToCooldown = true,
                    OffsetX = 0,
                    OffsetY = 0,
                    ClassColor = true,
                    ReactionColor = false,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = false,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        OffsetX = 3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = true,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -3,
                        OffsetY = 3,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
            target = {
                Enabled = true,
                Frame = {
                    Width = 272,
                    Height = 48,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    AnchorFrame = "EssentialCooldownViewer",
                    AnchorToCooldown = true,
                    OffsetX = 0,
                    OffsetY = 0,
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = false,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        OffsetX = 3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = true,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = true,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -3,
                        OffsetY = 3,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
                Auras = {
                    Width = 0,  -- 0 = use frame width
                    Height = 18,
                    Scale = 2.5,
                    Alpha = 1,
                    RowLimit = 0,  -- 0 = unlimited
                    OffsetX = 0,
                    OffsetY = 2,
                    ShowBuffs = true,
                    ShowDebuffs = true,
                },
            },
            targettarget = {
                Enabled = true,
                Frame = {
                    Width = 122,
                    Height = 21,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    AnchorFrame = "NephUI_Target",
                    OffsetX = 198,
                    OffsetY = -14,
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        OffsetX = 0,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = false,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 14,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                },
            },
            pet = {
                Enabled = true,
                Frame = {
                    Width = 272,
                    Height = 21,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    AnchorFrame = "NephUI_Player",
                    OffsetX = 0,
                    OffsetY = 0,
                    ClassColor = true,
                    ReactionColor = false,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        OffsetX = 0,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = false,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -3,
                        OffsetY = 3,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
            focus = {
                Enabled = true,
                Frame = {
                    Width = 272,
                    Height = 32,
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    AnchorFrame = "NephUI_Player",
                        OffsetX = 0,
                        OffsetY = 84,
                    ClassColor = true,
                    ReactionColor = true,
                    FGColor = {26/255, 26/255, 26/255, 1.0},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                PowerBar = {
                    Enabled = true,
                    Height = 2,
                    ColorByType = true,
                    ColorBackgroundByType = true,
                    FGColor = {8/255, 8/255, 8/255, 0.8},
                    BGColor = {45/255, 45/255, 45/255, 1.0},
                },
                Tags = {
                    Name = {
                        Enabled = true,
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        OffsetX = 3,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        ColorByStatus = false,
                    },
                    Health = {
                        Enabled = true,
                        AnchorFrom = "RIGHT",
                        AnchorTo = "RIGHT",
                        OffsetX = -3,
                        OffsetY = 0,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                        DisplayPercent = true,
                    },
                    Power = {
                        Enabled = false,
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        OffsetX = -3,
                        OffsetY = 3,
                        FontSize = 12,
                        Color = {1, 1, 1, 1},
                    },
                },
            },
        },
    },
}

local function GetClassColor()
    local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    if not classColor then
        return 1, 1, 1
    end
    return classColor.r, classColor.g, classColor.b
end

-- Helper functions to get global font and texture
function NephUI:GetGlobalFont()
    local LSM = LibStub("LibSharedMedia-3.0")
    local fontName = self.db.profile.general.globalFont or "EXPRESSWAY"
    return LSM:Fetch("font", fontName) or [[Interface\AddOns\NephUI\Fonts\Expressway.TTF]]
end

function NephUI:GetGlobalTexture()
    local LSM = LibStub("LibSharedMedia-3.0")
    local textureName = self.db.profile.general.globalTexture or "Neph"
    return LSM:Fetch("statusbar", textureName) or "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
end

-- let it live

function NephUI:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("NephUIDB", defaults, true)
    ns.db = self.db

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied",  "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset",   "OnProfileChanged")

    -- Enhance database with LibDualSpec if available
    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(self.db, ADDON_NAME)
    end

    self:SetupOptions()
    self:RegisterChatCommand("nephui", "OpenConfig")
    self:RegisterChatCommand("nui", "OpenConfig")
    self:RegisterChatCommand("nephuirefresh", "ForceRefreshBuffIcons")
    
    -- Create minimap button
    self:CreateMinimapButton()
end

function NephUI:OnProfileChanged(event, db, profileKey)
    if self.RefreshAll then
        self:RefreshAll()
    end
end

function NephUI:OnEnable()
    -- Ensure cooldown viewer is enabled
    SetCVar("cooldownViewerEnabled", 1)
    
    -- Initialize UI scale
    if self.db.profile.general then
        local savedScale = self.db.profile.general.uiScale
        if savedScale and savedScale > 0 then
            UIParent:SetScale(savedScale)
        else
            -- If no saved scale, save the current scale
            self.db.profile.general.uiScale = UIParent:GetScale()
        end
    end
    
    self:HookViewers()

    -- Cast and channel bar updates
    self:RegisterEvent("UNIT_SPELLCAST_START",         "OnUnitSpellcastStart")
    self:RegisterEvent("UNIT_SPELLCAST_STOP",          "OnUnitSpellcastStop")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",   "OnUnitSpellcastStop")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED",        "OnUnitSpellcastStop")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnUnitSpellcastChannelStart")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",  "OnUnitSpellcastStop")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE","OnUnitSpellcastChannelUpdate")
    -- Empowered cast events
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START", "OnUnitSpellcastEmpowerStart")
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE","OnUnitSpellcastEmpowerUpdate")
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP", "OnUnitSpellcastEmpowerStop")
    
    -- Initialize cast bar layout
    self:UpdateCastBarLayout()
    
    -- Hook into target and focus cast bars (delay to ensure frames exist)
    C_Timer.After(0.1, function()
        self:HookTargetAndFocusCastBars()
    end)
    
    -- Initialize unit frames
    if self.UnitFrames and self.db.profile.unitFrames and self.db.profile.unitFrames.enabled then
        C_Timer.After(0.5, function()
            self.UnitFrames:Initialize()
            
            -- Hook into unit frame repositioning to update custom icon layouts
            local UF = self.UnitFrames
            if UF and UF.RepositionAllUnitFrames then
                local originalReposition = UF.RepositionAllUnitFrames
                UF.RepositionAllUnitFrames = function(self, ...)
                    originalReposition(self, ...)
                    -- Re-apply custom icon layouts after unit frames are repositioned
                    C_Timer.After(0.1, function()
                        if NephUI.customIconsTrackerFrame and NephUI.ApplyCustomIconsLayout then
                            NephUI:ApplyCustomIconsLayout()
                        end
                        if NephUI.trinketsTrackerFrame and NephUI.ApplyTrinketsLayout then
                            NephUI:ApplyTrinketsLayout()
                        end
                    end)
                end
            end
        end)
    end
    
    -- Auto-load and skin BuffIconCooldownViewer icons (replaces auto-opening settings)
    C_Timer.After(0.5, function()
        self:AutoLoadBuffIcons()
    end)
    
    -- Initialize custom icons tracker (delay to ensure unit frames are created first)
    -- Unit frames initialize at 0.5s and have internal delays, so wait longer
    C_Timer.After(1.5, function()
        self:CreateCustomIconsTrackerFrame()
        self:CreateTrinketsTrackerFrame()
    end)
    
    -- Retry layout application after unit frames are fully positioned
    C_Timer.After(2.5, function()
        if self.customIconsTrackerFrame and self.ApplyCustomIconsLayout then
            self:ApplyCustomIconsLayout()
        end
        if self.trinketsTrackerFrame and self.ApplyTrinketsLayout then
            self:ApplyTrinketsLayout()
        end
    end)
end

function NephUI:OpenConfig()
    LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
end

function NephUI:CreateMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LibDBIcon = LibStub("LibDBIcon-1.0", true)
    
    if not LDB or not LibDBIcon then
        return
    end
    
    -- Initialize minimap button database
    if not self.db.profile.minimap then
        self.db.profile.minimap = {
            hide = false,
        }
    end
    
    -- Create DataBroker object
    local dataObj = LDB:NewDataObject(ADDON_NAME, {
        type = "launcher",
        icon = "Interface\\AddOns\\NephUI\\Media\\nephui.tga",
        label = "NephUI",
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                self:OpenConfig()
            elseif button == "RightButton" then
                -- Right click could toggle something or show a menu
                -- For now, just open config
                self:OpenConfig()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText("NephUI")
            tooltip:AddLine("Left-click to open configuration", 1, 1, 1)
            tooltip:AddLine("Right-click to open configuration", 1, 1, 1)
        end,
    })
    
    -- Register with LibDBIcon
    LibDBIcon:Register(ADDON_NAME, dataObj, self.db.profile.minimap)
end

-- Helper Functions

local function CreateBorder(frame)
    if frame.border then return frame.border end

    local bord = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bord:SetPoint("TOPLEFT", frame, -1, 1)
    bord:SetPoint("BOTTOMRIGHT", frame, 1, -1)
    bord:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bord:SetBackdropBorderColor(0, 0, 0, 1)

    frame.border = bord
    return bord
end

local function IsCooldownIconFrame(frame)
    return frame and (frame.icon or frame.Icon) and frame.Cooldown
end

local function StripBlizzardOverlay(icon)
    for _, region in ipairs({ icon:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            region:SetTexture("")
            region:Hide()
            region.Show = function() end
        end
    end
end

local function GetIconCountFont(icon)
    if not icon then return nil end

    -- 1. ChargeCount (charges)
    local charge = icon.ChargeCount
    if charge then
        local fs = charge.Current or charge.Text or charge.Count or nil

        if not fs and charge.GetRegions then
            for _, region in ipairs({ charge:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end

        if fs then
            return fs
        end
    end

    -- 2. Applications (Buff stacks)
    local apps = icon.Applications
    if apps and apps.GetRegions then
        for _, region in ipairs({ apps:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                return region
            end
        end
    end

    -- 3. Fallback: look for named stack text
    for _, region in ipairs({ icon:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            local name = region:GetName()
            if name and (name:find("Stack") or name:find("Applications")) then
                return region
            end
        end
    end

    return nil
end

-- Icon Skinning

function NephUI:SkinIcon(icon, settings)
    -- Get the icon texture frame (handle both .icon and .Icon for compatibility)
    local iconTexture = icon.icon or icon.Icon
    if not icon or not iconTexture then return end

    -- Calculate icon dimensions from iconSize and aspectRatio (crop slider)
    local iconSize = settings.iconSize or 40
    local aspectRatioValue = 1.0 -- Default to square
    
    -- Get aspect ratio from crop slider or convert from string format
    if settings.aspectRatioCrop then
        aspectRatioValue = settings.aspectRatioCrop
    elseif settings.aspectRatio then
        -- Convert "16:9" format to numeric ratio
        local aspectW, aspectH = settings.aspectRatio:match("^(%d+%.?%d*):(%d+%.?%d*)$")
        if aspectW and aspectH then
            aspectRatioValue = tonumber(aspectW) / tonumber(aspectH)
        end
    end
    
    local iconWidth = iconSize
    local iconHeight = iconSize
    
    -- Calculate width/height based on aspect ratio value
    -- aspectRatioValue is width:height ratio (e.g., 1.78 for 16:9, 0.56 for 9:16)
    if aspectRatioValue and aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            -- Wider - width is longest, so width = iconSize
            iconWidth = iconSize
            iconHeight = iconSize / aspectRatioValue
        elseif aspectRatioValue < 1.0 then
            -- Taller - height is longest, so height = iconSize
            iconWidth = iconSize * aspectRatioValue
            iconHeight = iconSize
        end
    end
    
    local padding   = settings.padding or 5
    local zoom      = settings.zoom or 0
    local border    = icon.__CDM_Border
    local cdPadding = math.floor(padding * 0.7 + 0.5)

    -- This prevents stretching by cropping the texture to match the container aspect ratio
    iconTexture:ClearAllPoints()
    
    -- Fill the container
    iconTexture:SetPoint("TOPLEFT", icon, "TOPLEFT", padding, -padding)
    iconTexture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -padding, padding)
    
    -- Calculate texture coordinates based on aspect ratio to prevent stretching
    -- Use the same aspectRatioValue calculated above
    local left, right, top, bottom = 0, 1, 0, 1
    
    if aspectRatioValue and aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            -- Wider than tall (e.g., 1.78 for 16:9) - crop top/bottom
            local cropAmount = 1.0 - (1.0 / aspectRatioValue)
            local offset = cropAmount / 2.0
            top = offset
            bottom = 1.0 - offset
        elseif aspectRatioValue < 1.0 then
            -- Taller than wide (e.g., 0.56 for 9:16) - crop left/right
            local cropAmount = 1.0 - aspectRatioValue
            local offset = cropAmount / 2.0
            left = offset
            right = 1.0 - offset
        end
    end
    
    -- Apply zoom on top of aspect ratio crop
    if zoom > 0 then
        local currentWidth = right - left
        local currentHeight = bottom - top
        local visibleSize = 1.0 - (zoom * 2)
        
        local zoomedWidth = currentWidth * visibleSize
        local zoomedHeight = currentHeight * visibleSize
        
        local centerX = (left + right) / 2.0
        local centerY = (top + bottom) / 2.0
        
        left = centerX - (zoomedWidth / 2.0)
        right = centerX + (zoomedWidth / 2.0)
        top = centerY - (zoomedHeight / 2.0)
        bottom = centerY + (zoomedHeight / 2.0)
    end
    
    -- Apply texture coordinates - this zooms/crops instead of stretching
    iconTexture:SetTexCoord(left, right, top, bottom)
    
    -- Use SetWidth and SetHeight separately AND SetSize to ensure both dimensions are set independently
    icon:SetWidth(iconWidth)
    icon:SetHeight(iconHeight)
    -- Also call SetSize to ensure the frame properly registers the size change
    icon:SetSize(iconWidth, iconHeight)

    -- Cooldown glow
    if icon.CooldownFlash then
        icon.CooldownFlash:ClearAllPoints()
        icon.CooldownFlash:SetPoint("TOPLEFT", icon, "TOPLEFT", cdPadding, -cdPadding)
        icon.CooldownFlash:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cdPadding, cdPadding)
    end

    -- Cooldown swipe
    if icon.Cooldown then
        icon.Cooldown:ClearAllPoints()
        icon.Cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", cdPadding, -cdPadding)
        icon.Cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cdPadding, cdPadding)
    end

    -- Pandemic icon
    local picon = icon.PandemicIcon or icon.pandemicIcon or icon.Pandemic or icon.pandemic
    if not picon then
        for _, region in ipairs({ icon:GetChildren() }) do
            if region:GetName() and region:GetName():find("Pandemic") then
                picon = region
                break
            end
        end
    end

    if picon and picon.ClearAllPoints then
        picon:ClearAllPoints()
        picon:SetPoint("TOPLEFT", icon, "TOPLEFT", padding, -padding)
        picon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -padding, padding)
    end

    -- Out of range highlight
    local oor = icon.OutOfRange or icon.outOfRange or icon.oor
    if oor and oor.ClearAllPoints then
        oor:ClearAllPoints()
        oor:SetPoint("TOPLEFT", icon, "TOPLEFT", padding, -padding)
        oor:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -padding, padding)
    end

    -- Charge/stack text
    local fs = GetIconCountFont(icon)
    if fs and fs.ClearAllPoints then
        fs:ClearAllPoints()

        local point   = settings.chargeTextAnchor or "BOTTOMRIGHT"
        if point == "MIDDLE" then point = "CENTER" end
        
        local offsetX = settings.countTextOffsetX or 0
        local offsetY = settings.countTextOffsetY or 0

        fs:SetPoint(point, iconTexture, point, offsetX, offsetY)

        local desiredSize = settings.countTextSize
        if desiredSize and desiredSize > 0 then
            local font = self:GetGlobalFont()
            fs:SetFont(font, desiredSize, "OUTLINE")
        end
    end

    -- Strip Blizzard overlay
    StripBlizzardOverlay(icon)

    -- Border
    if icon.IsForbidden and icon:IsForbidden() then
        icon.__cdmSkinned = true
        return
    end

    if not border then
        border = CreateFrame("Frame", nil, icon, "BackdropTemplate")
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 0, 0)
        icon.__CDM_Border = border
    end

    local edgeSize = tonumber(settings.borderSize) or 1
    
    -- Helper function to safely set backdrop (defers in combat to avoid secret value errors)
    local function SafeSetBackdrop(frame, backdropInfo)
        if not frame or not frame.SetBackdrop then return false end
        
        -- If in combat, defer backdrop setup to avoid secret value errors from GetWidth/GetHeight
        if InCombatLockdown() then
            -- Defer until out of combat
            -- Check if already pending by checking if frame is in pending table
            local alreadyPending = NephUI.__cdmPendingBackdrops and NephUI.__cdmPendingBackdrops[frame]
            if not alreadyPending then
                frame.__cdmBackdropPending = backdropInfo  -- Can be nil to remove backdrop
                frame.__cdmBackdropSettings = settings
                
                -- Create or reuse event frame for deferred backdrop setup
                if not NephUI.__cdmBackdropEventFrame then
                    local eventFrame = CreateFrame("Frame")
                    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                    eventFrame:SetScript("OnEvent", function(self)
                        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                        -- Process all pending backdrops
                        for pendingFrame in pairs(NephUI.__cdmPendingBackdrops or {}) do
                            if pendingFrame then
                                -- Frame is in pending table, so process it (backdropInfo could be nil to remove backdrop)
                                local pendingInfo = pendingFrame.__cdmBackdropPending
                                local pendingSettings = pendingFrame.__cdmBackdropSettings
                                if not InCombatLockdown() then
                                    local ok = pcall(pendingFrame.SetBackdrop, pendingFrame, pendingInfo)
                                    if ok then
                                        if pendingInfo then
                                            -- Setting a backdrop
                                            pendingFrame:Show()
                                            -- Always set border color (use same fallback as normal path: black)
                                            if pendingSettings then
                                                local r, g, b, a = unpack(pendingSettings.borderColor or { 0, 0, 0, 1 })
                                                pendingFrame:SetBackdropBorderColor(r, g, b, a or 1)
                                            else
                                                -- Fallback to black if no settings
                                                pendingFrame:SetBackdropBorderColor(0, 0, 0, 1)
                                            end
                                        else
                                            -- Removing backdrop (nil)
                                            pendingFrame:Hide()
                                        end
                                    end
                                    pendingFrame.__cdmBackdropPending = nil
                                    pendingFrame.__cdmBackdropSettings = nil
                                end
                            end
                        end
                        NephUI.__cdmPendingBackdrops = {}
                    end)
                    NephUI.__cdmBackdropEventFrame = eventFrame
                end
                
                -- Track this frame for deferred processing
                NephUI.__cdmPendingBackdrops = NephUI.__cdmPendingBackdrops or {}
                NephUI.__cdmPendingBackdrops[frame] = true
                NephUI.__cdmBackdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
            return false
        end
        
        -- Safe to set backdrop now (not in combat)
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
                -- If deferred, hide for now (will show when backdrop is set)
                if not border.__cdmBackdropPending then
                    border:Hide()
                end
            end
        end
    end

    icon.__cdmSkinned = true
    icon.__cdmSkinPending = nil  -- Clear pending flag on successful skin
end

-- ====================================================================
-- CUSTOM ITEM ICONS SYSTEM
-- ====================================================================

-- Apply border to custom icon (similar to SkinIcon border logic)
local function ApplyCustomIconBorder(iconFrame, settings)
    if not iconFrame or not iconFrame.border then return end
    
    local border = iconFrame.border
    local edgeSize = settings.borderSize or 0
    
    -- Use the same SafeSetBackdrop function from SkinIcon
    local function SafeSetBackdrop(frame, backdropInfo)
        if InCombatLockdown() then
            -- Defer backdrop setting until out of combat
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

-- Storage for custom item icons
local customItemIcons = {} -- [itemID] = iconFrame
NephUI.customIconsTrackerFrame = nil
local customIconsTrackerFrame = NephUI.customIconsTrackerFrame  -- Alias for convenience

-- Storage for trinket/weapon slot icons
local trinketWeaponIcons = {} -- [slotID] = iconFrame
NephUI.trinketsTrackerFrame = nil
local trinketsTrackerFrame = NephUI.trinketsTrackerFrame  -- Alias for convenience
local slotMapping = {
    trinket1 = 13,
    trinket2 = 14,
    weapon1 = 16,
    weapon2 = 17,
}

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
    
    -- Count text (lower right corner) - on higher layer so it's above cooldown
    local countText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    countText:SetJustifyH("RIGHT")
    countText:SetTextColor(1, 1, 1, 1)
    countText:SetShadowOffset(1, -1)
    countText:SetShadowColor(0, 0, 0, 1)
    countText:SetDrawLayer("OVERLAY", 7)  -- Higher sublayer than cooldown text
    
    -- Apply font size from settings
    local settings = NephUI.db.profile.customIcons
    local fontSize = (settings and settings.countTextSize) or 14
    local fontPath = NephUI:GetGlobalFont()
    countText:SetFont(fontPath, fontSize, "OUTLINE")
    
    frame._NephUI_customItem = true
    frame._NephUI_itemID = itemID
    frame._NephUI_itemName = itemName
    frame.icon = icon
    frame.Icon = icon  -- Also set Icon (capital) to match Blizzard's pattern
    frame.cooldown = cd
    frame.Cooldown = cd  -- Also set Cooldown (capital) to match Blizzard's pattern
    frame.count = countText
    frame.border = border
    frame.Border = border  -- Also set Border (capital) to match Blizzard's pattern
    
    -- Enable mouse for dragging but no tooltips to avoid combat taint issues
    frame:EnableMouse(true)
    -- No OnEnter/OnLeave scripts = no tooltips
    
    -- Allow Shift+drag to propagate to parent tracker frame
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

-- Update custom item cooldown and count
local function UpdateCustomItemCooldown(itemID, iconFrame)
    if not iconFrame or not iconFrame.cooldown or not iconFrame.icon then return end
    
    -- Check if this is a trinket/weapon icon (equipped item)
    local isEquippedItem = iconFrame._NephUI_slotID ~= nil
    
    -- Update cooldown first to check if item is on cooldown
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
    
    -- Also update trinket/weapon slot icons
    for slotID, iconFrame in pairs(trinketWeaponIcons) do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID and iconFrame then
            UpdateCustomItemCooldown(itemID, iconFrame)
        end
    end
end

-- Get item ID from inventory slot
local function GetItemIDFromSlot(slotID)
    if not slotID then return nil end
    return GetInventoryItemID("player", slotID)
end

-- Update trinket/weapon icon for a specific slot
local function UpdateTrinketWeaponIcon(slotID, slotKey)
    if not slotID or not NephUI.trinketsTrackerFrame then return end
    
    local db = NephUI.db.profile.customIcons
    if not db or not db.trinkets then return end
    
    -- Check if this slot should be tracked
    local shouldTrack = db.trinkets[slotKey]
    if not shouldTrack then
        -- Remove icon if it exists
        local icon = trinketWeaponIcons[slotID]
        if icon then
            icon:Hide()
            icon:SetParent(nil)
            trinketWeaponIcons[slotID] = nil
        end
        return
    end
    
    -- Get item ID from slot
    local itemID = GetItemIDFromSlot(slotID)
    if not itemID then
        -- No item in slot, hide icon if it exists
        local icon = trinketWeaponIcons[slotID]
        if icon then
            icon:Hide()
        end
        return
    end
    
    -- Check if icon already exists
    local icon = trinketWeaponIcons[slotID]
    if icon then
        -- Update existing icon if item changed
        if icon._NephUI_itemID ~= itemID then
            -- Item changed, recreate icon
            icon:Hide()
            icon:SetParent(nil)
            trinketWeaponIcons[slotID] = nil
            icon = nil
        else
            -- Same item, just update cooldown
            UpdateCustomItemCooldown(itemID, icon)
            icon:Show()
            return
        end
    end
    
    -- Create new icon
    if not icon then
        icon = CreateCustomItemIcon(itemID, NephUI.trinketsTrackerFrame)
        if icon then
            icon._NephUI_slotID = slotID
            icon._NephUI_slotKey = slotKey
            trinketWeaponIcons[slotID] = icon
            UpdateCustomItemCooldown(itemID, icon)
            NephUI:ApplyTrinketsLayout()
        else
            -- Item data not loaded yet, retry
            C_Timer.After(1, function()
                NephUI:UpdateTrinketWeaponTracking()
            end)
        end
    end
end

-- Update all trinket/weapon tracking based on toggles
function NephUI:UpdateTrinketWeaponTracking()
    if not self.trinketsTrackerFrame then return end
    
    for slotKey, slotID in pairs(slotMapping) do
        UpdateTrinketWeaponIcon(slotID, slotKey)
    end
    
    -- Relayout after updating
    self:ApplyTrinketsLayout()
end

-- Add a custom item to tracking
function NephUI:AddCustomItem(itemID, retryCount)
    retryCount = retryCount or 0
    if not itemID then return false end
    
    local db = self.db.profile.customIcons
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
    if self.RebuildTrackedItemsList then
        self:RebuildTrackedItemsList()
    end
    
    -- Create icon if tracker frame exists
    if self.customIconsTrackerFrame then
        local icon = CreateCustomItemIcon(itemID, self.customIconsTrackerFrame)
        if icon then
            customItemIcons[itemID] = icon
            UpdateCustomItemCooldown(itemID, icon)
            self:ApplyCustomIconsLayout()
        elseif retryCount < 5 then
            -- Item data not loaded yet, retry
            C_Timer.After(1, function()
                self:AddCustomItem(itemID, retryCount + 1)
            end)
        end
    end
    
    return true
end

-- Remove a custom item from tracking
function NephUI:RemoveCustomItem(itemID)
    if not itemID then return false end
    
    local db = self.db.profile.customIcons
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
    if self.RebuildTrackedItemsList then
        self:RebuildTrackedItemsList()
    end
    
    -- Relayout
    self:ApplyCustomIconsLayout()
    
    return true
end

-- Create the custom icons tracker frame
function NephUI:CreateCustomIconsTrackerFrame()
    if self.customIconsTrackerFrame then return self.customIconsTrackerFrame end
    
    local db = self.db.profile.customIcons
    if not db or not db.enabled then return nil end
    
    local frame = CreateFrame("Frame", "NephUI_CustomIconsTrackerFrame", UIParent)
    frame:SetSize(200, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    
    -- Default position
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    
    frame._NephUI_CustomIconsTracker = true
    
    self.customIconsTrackerFrame = frame
    customIconsTrackerFrame = frame  -- Update alias
    
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
                            self:ApplyCustomIconsLayout()
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
            if self.RebuildTrackedItemsList then
                self:RebuildTrackedItemsList()
            end
        end
    end)
    
    -- Apply layout
    self:ApplyCustomIconsLayout()
    
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

-- Create the trinkets tracker frame
function NephUI:CreateTrinketsTrackerFrame()
    if self.trinketsTrackerFrame then return self.trinketsTrackerFrame end
    
    local db = self.db.profile.customIcons
    if not db or not db.enabled then return nil end
    
    local frame = CreateFrame("Frame", "NephUI_TrinketsTrackerFrame", UIParent)
    frame:SetSize(200, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    
    -- Default position (slightly offset from items frame)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    
    frame._NephUI_TrinketsTracker = true
    
    self.trinketsTrackerFrame = frame
    trinketsTrackerFrame = frame  -- Update alias
    
    -- Load trinket/weapon icons
    self:UpdateTrinketWeaponTracking()
    
    -- Hook into equipment changes
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            local slotID = ...
            -- Check if this is a tracked slot
            if trinketWeaponIcons[slotID] then
                C_Timer.After(0.1, function()
                    NephUI:UpdateTrinketWeaponTracking()
                end)
            end
        end
    end)
    
    -- Apply layout
    self:ApplyTrinketsLayout()
    
    return frame
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

-- Apply layout to custom icons (similar to ApplyViewerLayout)
function NephUI:ApplyCustomIconsLayout()
    if not self.customIconsTrackerFrame then return end
    
    local db = self.db.profile.customIcons
    if not db or not db.enabled then return end
    
    local settings = db.items or {}
    local container = self.customIconsTrackerFrame
    local icons = {}
    
    -- Collect all icon frames in tracked order
    if db.trackedItems then
        for _, itemID in ipairs(db.trackedItems) do
            local icon = customItemIcons[itemID]
            if icon then
                table.insert(icons, icon)
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
end

-- Apply layout to trinkets/weapons (similar to ApplyCustomIconsLayout)
function NephUI:ApplyTrinketsLayout()
    if not self.trinketsTrackerFrame then return end
    
    local db = self.db.profile.customIcons
    if not db or not db.enabled then return end
    
    local settings = db.trinkets or {}
    local container = self.trinketsTrackerFrame
    local icons = {}
    
    -- Collect trinket/weapon icons in order: trinket1, trinket2, weapon1, weapon2
    local slotOrder = {13, 14, 16, 17}  -- trinket1, trinket2, weapon1, weapon2
    for _, slotID in ipairs(slotOrder) do
        local icon = trinketWeaponIcons[slotID]
        if icon and icon:IsShown() then
            table.insert(icons, icon)
        end
    end
    
    local count = #icons
    if count == 0 then return end
    
    -- Get settings (exclude trinket toggles)
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
            if self.ApplyTrinketsLayout then
                self:ApplyTrinketsLayout()
            end
        end)
        return  -- Don't apply layout yet, wait for anchor frame
    else
        -- Default position if no anchor
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY - 250)
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
end

function NephUI:SkinAllIconsInViewer(viewer)
    if not viewer or not viewer.GetName then return end

    local name     = viewer:GetName()
    local settings = self.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    local container = viewer.viewerFrame or viewer
    local children  = { container:GetChildren() }

    for _, icon in ipairs(children) do
        if IsCooldownIconFrame(icon) and (icon.icon or icon.Icon) then
            local ok, err = pcall(self.SkinIcon, self, icon, settings)
            if not ok then
                icon.__cdmSkinError = true
                print("|cffff4444[NephUI] SkinIcon error for", name, "icon:", err, "|r")
            end
        end
    end
end

-- Viewer Layout

function NephUI:ApplyViewerLayout(viewer)
    if not viewer or not viewer.GetName then return end
    local name     = viewer:GetName()
    local settings = self.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    local container = viewer.viewerFrame or viewer
    local icons = {}

    for _, child in ipairs({ container:GetChildren() }) do
        if IsCooldownIconFrame(child) and child:IsShown() then
            table.insert(icons, child)
        end
    end

    local count = #icons
    if count == 0 then return end

    -- For BuffIconCooldownViewer, assign creation order if no layoutIndex
    if name == "BuffIconCooldownViewer" then
        for i, icon in ipairs(icons) do
            if not icon.layoutIndex and not icon:GetID() then
                icon.__cdmCreationOrder = icon.__cdmCreationOrder or i
            end
        end
    end

    -- Sort icons with fallback to creation order
    table.sort(icons, function(a, b)
        local la = a.layoutIndex or a:GetID() or a.__cdmCreationOrder or 0
        local lb = b.layoutIndex or b:GetID() or b.__cdmCreationOrder or 0
        return la < lb
    end)

    -- Calculate icon dimensions from iconSize and aspectRatio (crop slider)
    local iconSize = settings.iconSize or 32
    local aspectRatioValue = 1.0 -- Default to square
    
    -- Get aspect ratio from crop slider or convert from string format
    if settings.aspectRatioCrop then
        aspectRatioValue = settings.aspectRatioCrop
    elseif settings.aspectRatio then
        -- Convert "16:9" format to numeric ratio
        local aspectW, aspectH = settings.aspectRatio:match("^(%d+%.?%d*):(%d+%.?%d*)$")
        if aspectW and aspectH then
            aspectRatioValue = tonumber(aspectW) / tonumber(aspectH)
        end
    end
    
    local iconWidth = iconSize
    local iconHeight = iconSize
    
    -- Calculate width/height based on aspect ratio value
    if aspectRatioValue and aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            -- Wider - width is longest, so width = iconSize
            iconWidth = iconSize
            iconHeight = iconSize / aspectRatioValue
        elseif aspectRatioValue < 1.0 then
            -- Taller - height is longest, so height = iconSize
            iconWidth = iconSize * aspectRatioValue
            iconHeight = iconSize
        end
    end
    
    local spacing    = settings.spacing or 4
    local rowLimit   = settings.rowLimit or 0

    for _, icon in ipairs(icons) do
        -- Clear points first to ensure no constraints
        icon:ClearAllPoints()
        
        -- Set width and height separately to ensure both dimensions are independent
        -- Container size is NEVER affected by lockAspectRatio - only the .icon texture inside is
        -- Force both dimensions independently
        icon:SetWidth(iconWidth)
        icon:SetHeight(iconHeight)
        
        -- Also call SetSize to ensure the frame properly updates
        icon:SetSize(iconWidth, iconHeight)
    end

    -- If rowLimit is 0 or less, use single row (original behavior)
    if rowLimit <= 0 then
        local totalWidth = count * iconWidth + (count - 1) * spacing
        viewer.__cdmIconWidth = totalWidth

        local startX = -totalWidth / 2 + iconWidth / 2

        for i, icon in ipairs(icons) do
            local x = startX + (i - 1) * (iconWidth + spacing)
            icon:SetPoint("CENTER", container, "CENTER", x, 0)
        end
        
        -- Set viewer size for single row layout
        if not InCombatLockdown() then
            viewer:SetSize(totalWidth, iconHeight)
            viewer.__cdmIconHeight = iconHeight
        end
    else
        -- Multi-row layout with centered horizontal growth
        local numRows = math.ceil(count / rowLimit)
        local rowSpacing = iconHeight + spacing -- Vertical spacing between rows
        
        -- Calculate the maximum width for centering (use the widest row)
        local maxRowWidth = 0
        for row = 1, numRows do
            local rowStart = (row - 1) * rowLimit + 1
            local rowEnd = math.min(row * rowLimit, count)
            local rowCount = rowEnd - rowStart + 1
            if rowCount > 0 then
                local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
                if rowWidth > maxRowWidth then
                    maxRowWidth = rowWidth
                end
            end
        end
        
        viewer.__cdmIconWidth = maxRowWidth
        
        -- Get row growth direction (only for BuffIconCooldownViewer)
        local growDirection = "down"
        if name == "BuffIconCooldownViewer" then
            growDirection = settings.rowGrowDirection or "down"
        end
        
        -- Place icons in rows
        -- Main row (row 1) is ALWAYS locked at y=0 (container center)
        -- This ensures it never moves when row limit changes and rows are added/removed
        -- Other rows are positioned relative to the main row
        for i, icon in ipairs(icons) do
            local row = math.ceil(i / rowLimit)
            local rowStart = (row - 1) * rowLimit + 1
            local rowEnd = math.min(row * rowLimit, count)
            local rowCount = rowEnd - rowStart + 1
            local positionInRow = i - rowStart + 1
            
            -- Calculate centered horizontal position for this row
            local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
            local startX = -rowWidth / 2 + iconWidth / 2
            local x = startX + (positionInRow - 1) * (iconWidth + spacing)
            
            -- Calculate vertical position
            -- Main row (row 1) is ALWAYS at y=0 (container center) - this locks it in place
            -- Other rows are positioned relative to the main row
            local y
            if row == 1 then
                -- Main row: always at container center (y=0) - NEVER moves
                y = 0
            elseif growDirection == "up" then
                -- Rows grow upward: row 2 above main row (+rowSpacing), row 3 above that (+2*rowSpacing), etc.
                y = (row - 1) * rowSpacing
            else
                -- Rows grow downward: row 2 below main row (-rowSpacing), row 3 below that (-2*rowSpacing), etc.
                y = -(row - 1) * rowSpacing
            end
            
            icon:SetPoint("CENTER", container, "CENTER", x, y)
        end
        
        -- Set viewer size to encompass all rows for proper edit mode anchor alignment
        -- Main row is at y=0 (center), and other rows are positioned relative to it
        -- Calculate total height needed: (numRows-1) rows of spacing + icon height
        local totalHeight = (numRows - 1) * rowSpacing + iconHeight
        
        -- Set viewer size to match icon layout dimensions
        -- IMPORTANT: We resize the viewer itself (not viewerFrame) so edit mode anchors align
        -- But we need to ensure the center stays fixed to prevent icons from shifting
        if not InCombatLockdown() then
            -- Store current position before resizing
            local point, relativeTo, relativePoint, xOfs, yOfs = viewer:GetPoint(1)
            local currentHeight = viewer:GetHeight() or iconHeight
            local currentWidth = viewer:GetWidth() or maxRowWidth
            
            -- Calculate height difference
            local heightDiff = totalHeight - currentHeight
            
            -- Resize the viewer
            viewer:SetSize(maxRowWidth, totalHeight)
            
            -- Reposition to maintain center if height changed
            -- This prevents the viewer from shifting when we add rows
            if point and relativeTo and heightDiff ~= 0 then
                if relativePoint == "TOP" then
                    -- Anchored at top: when height increases, move down to keep center aligned
                    viewer:SetPoint(point, relativeTo, relativePoint, xOfs or 0, (yOfs or 0) - (heightDiff / 2))
                elseif relativePoint == "BOTTOM" then
                    -- Anchored at bottom: when height increases, move up to keep center aligned
                    viewer:SetPoint(point, relativeTo, relativePoint, xOfs or 0, (yOfs or 0) + (heightDiff / 2))
                elseif relativePoint == "CENTER" then
                    -- Center anchor: should maintain position, but explicitly set it
                    viewer:SetPoint(point, relativeTo, relativePoint, xOfs or 0, yOfs or 0)
                else
                    -- For other anchor points, try to maintain center by adjusting offset
                    -- Calculate center offset adjustment
                    local centerAdjust = heightDiff / 2
                    if relativePoint and (relativePoint:find("TOP") or relativePoint == "TOPLEFT" or relativePoint == "TOPRIGHT") then
                        viewer:SetPoint(point, relativeTo, relativePoint, xOfs or 0, (yOfs or 0) - centerAdjust)
                    elseif relativePoint and (relativePoint:find("BOTTOM") or relativePoint == "BOTTOMLEFT" or relativePoint == "BOTTOMRIGHT") then
                        viewer:SetPoint(point, relativeTo, relativePoint, xOfs or 0, (yOfs or 0) + centerAdjust)
                    end
                end
            end
            
            -- Also store height for reference
            viewer.__cdmIconHeight = totalHeight
        end
    end
end

function NephUI:RescanViewer(viewer)
    if not viewer or not viewer.GetName then return end
    local name     = viewer:GetName()
    local settings = self.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    local container = viewer.viewerFrame or viewer
    local icons = {}
    local changed = false
    local inCombat = InCombatLockdown()
    
    -- For BuffIconCooldownViewer, collect ALL icons (including hidden ones) for skinning
    -- But don't force-show them - respect Blizzard's show/hide state
    local collectAllIcons = (name == "BuffIconCooldownViewer")

    for _, child in ipairs({ container:GetChildren() }) do
        if IsCooldownIconFrame(child) then
            -- For BuffIconCooldownViewer, collect all icons (shown or hidden) for skinning
            -- For other viewers, only collect shown icons
            -- IMPORTANT: Don't force-show icons here - let Blizzard control visibility
            if collectAllIcons or child:IsShown() then
                table.insert(icons, child)
                
                -- Only skin icons, don't force-show them
                -- Blizzard will show/hide icons based on Edit Mode and settings

                if not child.__cdmSkinned then
                -- Mark as pending to avoid multiple attempts
                if not child.__cdmSkinPending then
                    child.__cdmSkinPending = true
                    
                    if inCombat then
                        -- Defer skinning until out of combat
                        if not self.__cdmPendingIcons then
                            self.__cdmPendingIcons = {}
                        end
                        self.__cdmPendingIcons[child] = { icon = child, settings = settings, viewer = viewer }
                        
                        -- Ensure we have an event frame for combat end
                        if not self.__cdmIconSkinEventFrame then
                            local eventFrame = CreateFrame("Frame")
                            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                            eventFrame:SetScript("OnEvent", function(self)
                                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                                NephUI:ProcessPendingIcons()
                            end)
                            self.__cdmIconSkinEventFrame = eventFrame
                        end
                        self.__cdmIconSkinEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                    else
                        -- Not in combat, try to skin immediately
                        local success = pcall(self.SkinIcon, self, child, settings)
                        if success then
                            child.__cdmSkinPending = nil
                        end
                    end
                    changed = true
                end
                end
            end
        end
    end

    local count = #icons
    
    -- BuffIconCooldownViewer: check count changes and overlaps
    if name == "BuffIconCooldownViewer" then
        if count ~= viewer.__cdmIconCount then
            viewer.__cdmIconCount = count
            changed = true
        end
        
        -- Check for overlapping icons
        if count > 1 and not changed then
            for i = 1, count - 1 do
                local icon1 = icons[i]
                local icon2 = icons[i + 1]
                if icon1 and icon2 then
                    local x1 = icon1:GetCenter()
                    local x2 = icon2:GetCenter()
                    if x1 and x2 then
                        -- Calculate icon width from iconSize and aspectRatio (crop slider)
                        local iconSize = settings.iconSize or 32
                        local aspectRatioValue = 1.0
                        if settings.aspectRatioCrop then
                            aspectRatioValue = settings.aspectRatioCrop
                        elseif settings.aspectRatio then
                            local aspectW, aspectH = settings.aspectRatio:match("^(%d+%.?%d*):(%d+%.?%d*)$")
                            if aspectW and aspectH then
                                aspectRatioValue = tonumber(aspectW) / tonumber(aspectH)
                            end
                        end
                        local iconWidth = iconSize
                        if aspectRatioValue > 1.0 then
                            iconWidth = iconSize
                        elseif aspectRatioValue < 1.0 then
                            iconWidth = iconSize * aspectRatioValue
                        end
                        local expectedSpacing = iconWidth + settings.spacing
                        local actualSpacing = math.abs(x2 - x1)
                        if math.abs(actualSpacing - expectedSpacing) > 1 then
                            changed = true
                            break
                        end
                    end
                end
            end
        end
    else
        if count ~= viewer.__cdmIconCount then
            viewer.__cdmIconCount = count
            changed = true
        end
    end

    if changed then
        -- Re-apply layout when the viewer's icon set changes
        self:ApplyViewerLayout(viewer)

        -- Keep resource bars in sync with the viewer width immediately
        if self.UpdatePowerBar then
            self:UpdatePowerBar()
        end
        if self.UpdateSecondaryPowerBar then
            self:UpdateSecondaryPowerBar()
        end
    end
end

function NephUI:ApplyViewerSkin(viewer)
    if not viewer or not viewer.GetName then return end
    local name     = viewer:GetName()
    local settings = self.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    -- Apply layout first to set container sizes, then skin to handle textures
    -- This ensures container sizes are set correctly before texture manipulation
    self:ApplyViewerLayout(viewer)
    self:SkinAllIconsInViewer(viewer)
    -- Apply layout again after skinning to ensure container sizes persist
    self:ApplyViewerLayout(viewer)
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
    self:UpdateCastBarLayout()
    
    -- Try to process any pending icons if not in combat
    if not InCombatLockdown() then
        self:ProcessPendingIcons()
    end
end

function NephUI:ProcessPendingIcons()
    if not self.__cdmPendingIcons then return end
    if InCombatLockdown() then return end
    
    local processed = {}
    for icon, data in pairs(self.__cdmPendingIcons) do
        if icon and icon:IsShown() and not icon.__cdmSkinned then
            local success = pcall(self.SkinIcon, self, icon, data.settings)
            if success then
                icon.__cdmSkinPending = nil
                processed[icon] = true
            end
        elseif not icon or not icon:IsShown() then
            -- Icon no longer exists or is hidden, remove from pending
            processed[icon] = true
        end
    end
    
    -- Remove processed icons from pending list
    for icon in pairs(processed) do
        self.__cdmPendingIcons[icon] = nil
    end
    
    -- If no more pending icons, clear the table
    if not next(self.__cdmPendingIcons) then
        self.__cdmPendingIcons = nil
    end
end

function NephUI:HookViewers()
    for _, name in ipairs(self.viewers) do
        local viewer = _G[name]
        if viewer and not viewer.__cdmHooked then
            viewer.__cdmHooked = true

            viewer:HookScript("OnShow", function(f)
                self:ApplyViewerSkin(f)
            end)

            viewer:HookScript("OnSizeChanged", function(f)
                self:ApplyViewerLayout(f)
            end)

            -- Different update rates for different viewers
            local updateInterval = 0.01
            if name == "BuffIconCooldownViewer" then
                updateInterval = 0.05
            end

            viewer:HookScript("OnUpdate", function(f, elapsed)
                f.__cdmElapsed = (f.__cdmElapsed or 0) + elapsed
                if f.__cdmElapsed > updateInterval then
                    f.__cdmElapsed = 0
                    if f:IsShown() then
                        self:RescanViewer(f)
                        -- Also try to process pending icons if not in combat
                        if not InCombatLockdown() then
                            self:ProcessPendingIcons()
                        end
                    end
                end
            end)

            self:ApplyViewerSkin(viewer)
        end
    end
end

function NephUI:ForceRefreshBuffIcons()
    local viewer = _G["BuffIconCooldownViewer"]
    if viewer and viewer:IsShown() then
        viewer.__cdmIconCount = nil
        self:RescanViewer(viewer)
        -- Process any pending icons if not in combat
        if not InCombatLockdown() then
            self:ProcessPendingIcons()
        end
        print("|cff00ff00[NephUI] Force refreshed BuffIconCooldownViewer|r")
    end
end

-- Auto-load and skin all BuffIconCooldownViewer icons on login (replaces auto-opening settings)
-- After skinning, hides the viewer so it's not visible all the time
function NephUI:AutoLoadBuffIcons(retryCount)
    retryCount = retryCount or 0
    local maxRetries = 5  -- Maximum number of retry attempts
    
    local viewer = _G["BuffIconCooldownViewer"]
    if not viewer then
        -- Viewer doesn't exist yet, retry with delays (up to max retries)
        if retryCount < maxRetries then
            C_Timer.After(1.0, function() self:AutoLoadBuffIcons(retryCount + 1) end)
            C_Timer.After(2.0, function() self:AutoLoadBuffIcons(retryCount + 1) end)
            C_Timer.After(3.0, function() self:AutoLoadBuffIcons(retryCount + 1) end)
        end
        return
    end
    
    -- Mark that we're in initial loading phase (only during this function)
    viewer.__nephuiInitialLoading = true
    
    -- Ensure viewer is shown (Blizzard may hide it initially)
    local wasHidden = not viewer:IsShown()
    if wasHidden then
        viewer:Show()
    end
    
    local settings = self.db.profile.viewers["BuffIconCooldownViewer"]
    if not settings or not settings.enabled then
        -- Hide viewer if we showed it
        if wasHidden then
            viewer:Hide()
        end
        viewer.__nephuiInitialLoading = nil
        return
    end
    
    -- Collect ALL icons (including hidden ones)
    local function collectAllIcons(container)
        local icons = {}
        if not container or not container.GetNumChildren then return icons end
        
        local n = container:GetNumChildren() or 0
        for i = 1, n do
            local child = select(i, container:GetChildren())
            if child and IsCooldownIconFrame(child) then
                table.insert(icons, child)
            elseif child and child.GetNumChildren then
                -- Check nested children
                local m = child:GetNumChildren() or 0
                for j = 1, m do
                    local grandchild = select(j, child:GetChildren())
                    if grandchild and IsCooldownIconFrame(grandchild) then
                        table.insert(icons, grandchild)
                    end
                end
            end
        end
        return icons
    end
    
    local container = viewer.viewerFrame or viewer
    local icons = collectAllIcons(container)
    
    -- Force-show and skin all icons (only during initial load)
    local skinnedCount = 0
    local pendingCount = 0
    for _, icon in ipairs(icons) do
        -- Force-show the icon only during initial loading phase
        -- After this, Blizzard will control visibility
        if not icon:IsShown() then
            icon:Show()
        end
        
        -- Skin the icon if not already skinned
        if not icon.__cdmSkinned and not InCombatLockdown() then
            local success = pcall(self.SkinIcon, self, icon, settings)
            if success then
                skinnedCount = skinnedCount + 1
            end
        elseif not icon.__cdmSkinned then
            -- Mark as pending for later
            if not icon.__cdmSkinPending then
                icon.__cdmSkinPending = true
                if not self.__cdmPendingIcons then
                    self.__cdmPendingIcons = {}
                end
                self.__cdmPendingIcons[icon] = { icon = icon, settings = settings, viewer = viewer }
                pendingCount = pendingCount + 1
            end
        end
    end
    
    -- Apply layout to organize icons
    if #icons > 0 then
        self:ApplyViewerLayout(viewer)
    end
    
    -- Determine if we should retry or hide the viewer
    local shouldRetry = false
    if #icons == 0 and retryCount < maxRetries then
        -- No icons found yet, retry
        shouldRetry = true
        C_Timer.After(0.5, function() self:AutoLoadBuffIcons(retryCount + 1) end)
        C_Timer.After(1.5, function() self:AutoLoadBuffIcons(retryCount + 1) end)
        C_Timer.After(3.0, function() self:AutoLoadBuffIcons(retryCount + 1) end)
    elseif skinnedCount > 0 and retryCount < maxRetries then
        -- Some icons were skinned, check for more (but limit retries)
        shouldRetry = true
        C_Timer.After(1.0, function() self:AutoLoadBuffIcons(retryCount + 1) end)
    end
    
    -- If we're done (no more retries needed), hide the viewer and clear loading flag
    if not shouldRetry then
        -- Clear the initial loading flag
        viewer.__nephuiInitialLoading = nil
        
        -- Wait a brief moment to ensure skinning is complete, then hide
        C_Timer.After(0.2, function()
            if viewer and viewer:IsShown() then
                viewer:Hide()
            end
        end)
    end
end

function NephUI:RefreshAll()
    for _, name in ipairs(self.viewers) do
        local viewer = _G[name]
        if viewer and viewer:IsShown() then
            self:ApplyViewerSkin(viewer)
        end
    end
    self:UpdatePowerBar()
    self:UpdateSecondaryPowerBar()
    self:UpdateCastBarLayout()
    self:UpdateTargetCastBarLayout()
    self:UpdateFocusCastBarLayout()
    
    -- Refresh custom icons
    if self.db.profile.customIcons and self.db.profile.customIcons.enabled then
        self:CreateCustomIconsTrackerFrame()
        self:CreateTrinketsTrackerFrame()
        if self.UpdateTrinketWeaponTracking then
            self:UpdateTrinketWeaponTracking()
        end
        self:ApplyCustomIconsLayout()
        self:ApplyTrinketsLayout()
    end
end

-- Cast Bar

local function CastBar_OnUpdate(frame, elapsed)
    if not frame.startTime or not frame.endTime then return end

    local now = GetTime()
    if now >= frame.endTime then
        frame.castGUID  = nil
        frame.isChannel = nil
        frame.isEmpowered = nil
        frame.numStages = nil
        if frame.empoweredStages then
            for _, stage in ipairs(frame.empoweredStages) do
                stage:Hide()
            end
        end
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
        return
    end

    local status = frame.status
    if not status then return end

    local duration  = frame.endTime - frame.startTime
    if duration <= 0 then duration = 0.001 end

    local remaining = frame.endTime - now
    local progress

    if frame.isChannel then
        progress = remaining
    else
        progress = now - frame.startTime
    end

    status:SetMinMaxValues(0, duration)
    status:SetValue(progress)

    if frame.timeText then
        -- Get the config for this cast bar
        local cfg
        if frame == NephUI.castBar then
            cfg = NephUI.db.profile.castBar
        elseif frame == NephUI.targetCastBar then
            cfg = NephUI.db.profile.targetCastBar
        elseif frame == NephUI.focusCastBar then
            cfg = NephUI.db.profile.focusCastBar
        end
        
        -- Show/hide time text based on setting
        if cfg and cfg.showTimeText ~= false then
            frame.timeText:Show()
            frame.timeText:SetFormattedText("%.1f", remaining)
        else
            frame.timeText:Hide()
        end
    end
end

function NephUI:GetCastBar()
    if self.castBar then return self.castBar end

    local cfg    = self.db.profile.castBar
    local anchor = _G[cfg.attachTo] or UIParent

    local bar = CreateFrame("Frame", ADDON_NAME .. "CastBar", anchor)
    bar:SetFrameStrata("MEDIUM")

    local height = cfg.height or 10
    bar:SetHeight(height)
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or 18))
    bar:SetWidth(anchor:GetWidth())

    CreateBorder(bar)

    -- Status bar
    bar.status = CreateFrame("StatusBar", nil, bar)
    local tex = self:GetGlobalTexture()
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

    -- Empowered stages storage
    bar.empoweredStages = {}

    self.castBar = bar
    return bar
end

function NephUI:GetTargetCastBar()
    if self.targetCastBar then return self.targetCastBar end

    local cfg    = self.db.profile.targetCastBar
    local anchor = _G[cfg.attachTo] or UIParent

    local bar = CreateFrame("Frame", ADDON_NAME .. "TargetCastBar", anchor)
    bar:SetFrameStrata("MEDIUM")

    local height = cfg.height or 10
    bar:SetHeight(height)
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or -50))
    
    local width = cfg.width or 0
    if width <= 0 then
        width = anchor:GetWidth() or 200
    end
    bar:SetWidth(width)

    CreateBorder(bar)

    -- Status bar
    bar.status = CreateFrame("StatusBar", nil, bar)
    local tex = self:GetGlobalTexture()
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

    self.targetCastBar = bar
    return bar
end

function NephUI:GetFocusCastBar()
    if self.focusCastBar then return self.focusCastBar end

    local cfg    = self.db.profile.focusCastBar
    local anchor = _G[cfg.attachTo] or UIParent

    local bar = CreateFrame("Frame", ADDON_NAME .. "FocusCastBar", anchor)
    bar:SetFrameStrata("MEDIUM")

    local height = cfg.height or 10
    bar:SetHeight(height)
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or -50))
    
    local width = cfg.width or 0
    if width <= 0 then
        width = anchor:GetWidth() or 200
    end
    bar:SetWidth(width)

    CreateBorder(bar)

    -- Status bar
    bar.status = CreateFrame("StatusBar", nil, bar)
    local tex = self:GetGlobalTexture()
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

    self.focusCastBar = bar
    return bar
end

function NephUI:UpdateTargetCastBarLayout()
    local cfg = self.db.profile.targetCastBar
    if not cfg then return end
    
    local bar = self.targetCastBar
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
    
    local height = cfg.height or 18
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or -50))
    bar:SetHeight(height)
    
    local width = cfg.width or 0
    if width <= 0 then
        width = anchor:GetWidth() or 200
    end
    bar:SetWidth(width)
    
    if bar.border then
        bar.border:ClearAllPoints()
        bar.border:SetPoint("TOPLEFT", bar, -1, 1)
        bar.border:SetPoint("BOTTOMRIGHT", bar, 1, -1)
    end
    
    -- Icon: left side
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.icon:SetWidth(height)
    
    bar.status:ClearAllPoints()
    bar.status:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 0, 0)
    bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    
    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar.status)
    
    -- Update background color
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    
    -- Update texture
    local tex = self:GetGlobalTexture()
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
    bar.spellName:SetPoint("LEFT", bar.status, "LEFT", 4, 0)
    
    bar.timeText:ClearAllPoints()
    bar.timeText:SetPoint("RIGHT", bar.status, "RIGHT", -4, 0)
    
    -- Update text size
    local font = self:GetGlobalFont()
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

function NephUI:UpdateFocusCastBarLayout()
    local cfg = self.db.profile.focusCastBar
    if not cfg then return end
    
    local bar = self.focusCastBar
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
    
    local height = cfg.height or 18
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or -50))
    bar:SetHeight(height)
    
    local width = cfg.width or 0
    if width <= 0 then
        width = anchor:GetWidth() or 200
    end
    bar:SetWidth(width)
    
    if bar.border then
        bar.border:ClearAllPoints()
        bar.border:SetPoint("TOPLEFT", bar, -1, 1)
        bar.border:SetPoint("BOTTOMRIGHT", bar, 1, -1)
    end
    
    -- Icon: left side
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.icon:SetWidth(height)
    
    bar.status:ClearAllPoints()
    bar.status:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 0, 0)
    bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    
    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar.status)
    
    -- Update background color
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    
    -- Update texture
    local tex = self:GetGlobalTexture()
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
    bar.spellName:SetPoint("LEFT", bar.status, "LEFT", 4, 0)
    
    bar.timeText:ClearAllPoints()
    bar.timeText:SetPoint("RIGHT", bar.status, "RIGHT", -4, 0)
    
    -- Update text size
    local font = self:GetGlobalFont()
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

function NephUI:UpdateCastBarLayout()
    local cfg = self.db.profile.castBar
    
    -- Set default cast bar alpha to 0
    local defaultCastBar = _G["PlayerCastingBarFrame"] or _G["CastingBarFrame"]
    if defaultCastBar then
        defaultCastBar:SetAlpha(0)
        -- Hook OnShow to keep it at alpha 0 and hide child regions (including "Interrupted" text)
        if not defaultCastBar.__nephuiAlphaHooked then
            defaultCastBar.__nephuiAlphaHooked = true
            
            -- Hide all child regions (including "Interrupted" text)
            local function HideChildRegions(frame)
                if not frame then return end
                
                -- Hide all regions (textures, fontstrings, etc.)
                if frame.GetRegions then
                    for _, region in ipairs({ frame:GetRegions() }) do
                        if region and region.SetAlpha then
                            region:SetAlpha(0)
                        end
                        if region and region.Hide then
                            region:Hide()
                        end
                    end
                end
                
                -- Hide all child frames
                if frame.GetChildren then
                    for _, child in ipairs({ frame:GetChildren() }) do
                        if child then
                            child:SetAlpha(0)
                            if child.Hide then
                                child:Hide()
                            end
                            -- Recursively hide children of children
                            HideChildRegions(child)
                        end
                    end
                end
            end
            
            -- Hide child regions initially
            HideChildRegions(defaultCastBar)
            
            -- Hook OnShow to keep it at alpha 0 and hide children
            defaultCastBar:HookScript("OnShow", function(self)
                self:SetAlpha(0)
                HideChildRegions(self)
            end)
            
            -- Hook OnUpdate to continuously hide any new child regions (like "Interrupted" text)
            defaultCastBar:HookScript("OnUpdate", function(self)
                HideChildRegions(self)
            end)
        end
    end
    
    if not self.castBar then return end

    local bar    = self.castBar
    local anchor = _G[cfg.attachTo] or UIParent
    local height = cfg.height or 10

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, "CENTER", 0, (cfg.offsetY or 18))
    bar:SetHeight(height)

    local width = cfg.width or 0
    if width <= 0 then
        width = (anchor.__cdmIconWidth or anchor:GetWidth())
        local pad = cfg.autoWidthPadding or 5.8
        width = width - (pad * 2)
        if width < 0 then width = 0 end
    end

    bar:SetWidth(width)

    if bar.border then
        bar.border:ClearAllPoints()
        bar.border:SetPoint("TOPLEFT", bar, -1, 1)
        bar.border:SetPoint("BOTTOMRIGHT", bar, 1, -1)
    end

    -- Icon: left side
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.icon:SetWidth(height)

    bar.status:ClearAllPoints()
    bar.status:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 0, 0)
    bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)

    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar.status)

    -- Update background color
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    local tex = self:GetGlobalTexture()
    bar.status:SetStatusBarTexture(tex)

    local sbTex = bar.status:GetStatusBarTexture()
    if sbTex then
        sbTex:SetDrawLayer("BACKGROUND")
    end

    -- Color
    local r, g, b, a

    if cfg.useClassColor then
        r, g, b = GetClassColor()
        a = 1
    elseif cfg.color then
        r, g, b, a = cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4] or 1
    else
        r, g, b, a = 1, 0.7, 0, 1
    end

    bar.status:SetStatusBarColor(r, g, b, a or 1)

    bar.spellName:ClearAllPoints()
    bar.spellName:SetPoint("LEFT", bar.status, "LEFT", 4, 0)

    bar.timeText:ClearAllPoints()
    bar.timeText:SetPoint("RIGHT", bar.status, "RIGHT", -4, 0)

    local font, _, flags = bar.spellName:GetFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)
    
    -- Show/hide time text based on setting
    if cfg.showTimeText ~= false then
        bar.timeText:Show()
    else
        bar.timeText:Hide()
    end

    -- Reinitialize empowered stages if bar is currently showing an empowered cast
    if bar.isEmpowered and bar.numStages and bar.numStages > 0 then
        self:InitializeEmpoweredStages(bar)
    end
end

function NephUI:OnPlayerSpellcastStart(unit, castGUID, spellID)
    local cfg = self.db.profile.castBar
    if not cfg.enabled then
        if self.castBar then self.castBar:Hide() end
        return
    end

    -- UnitCastingInfo can return additional values for empowered casts
    -- name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId, numStages
    local name, _, texture, startTimeMS, endTimeMS, _, _, _, _, numStages = UnitCastingInfo("player")
    if not name or not startTimeMS or not endTimeMS then
        if self.castBar then self.castBar:Hide() end
        return
    end

    local bar = self:GetCastBar()
    self:UpdateCastBarLayout()

    bar.isChannel = false
    bar.castGUID  = castGUID
    
    -- Check if this is an empowered cast (numStages > 0)
    -- Also check using C_UnitAuras API if available
    local isEmpowered = (numStages and numStages > 0) or false
    if not isEmpowered and C_UnitAuras and C_UnitAuras.GetEmpoweredStageInfo then
        local stageInfo = C_UnitAuras.GetEmpoweredStageInfo("player")
        if stageInfo and stageInfo.numStages and stageInfo.numStages > 0 then
            isEmpowered = true
            numStages = stageInfo.numStages
        end
    end
    
    bar.isEmpowered = isEmpowered
    bar.numStages = numStages or 0

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    local font = self:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    local now = GetTime()
    bar.startTime = startTimeMS / 1000
    bar.endTime   = endTimeMS / 1000

    -- Safety: if start time is very old, clamp to now
    if bar.startTime < now - 5 then
        local dur = (endTimeMS - startTimeMS) / 1000
        bar.startTime = now
        bar.endTime   = now + dur
    end

    -- Initialize empowered stages if this is an empowered cast
    if bar.isEmpowered and bar.numStages > 0 then
        -- Delay initialization slightly to ensure bar is properly sized
        C_Timer.After(0.01, function()
            if bar.isEmpowered and bar.numStages > 0 then
                self:InitializeEmpoweredStages(bar)
            end
        end)
    end

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

function NephUI:OnUnitSpellcastStart(_, unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastStart(unit, castGUID, spellID)
    -- Target and focus are now handled via hooks into Blizzard cast bars
    end
end

function NephUI:OnUnitSpellcastStop(_, unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastStop(unit, castGUID, spellID)
    -- Target and focus are now handled via hooks into Blizzard cast bars
    end
end

function NephUI:OnPlayerSpellcastStop(unit, castGUID, spellID)
    if not self.castBar then return end

    if castGUID and self.castBar.castGUID and castGUID ~= self.castBar.castGUID then
        return
    end

    -- Check if player is still channeling - if so, don't hide the cast bar
    -- This handles the case where a spell is attempted during a channel (GCD locked)
    -- and UNIT_SPELLCAST_STOP/FAILED fires, but the channel continues
    if self.castBar.isChannel then
        local name, _, texture, startTimeMS, endTimeMS = UnitChannelInfo("player")
        if name and startTimeMS and endTimeMS then
            -- Still channeling, update the cast bar instead of hiding it
            self.castBar.icon:SetTexture(texture)
            self.castBar.spellName:SetText(name)
            self.castBar.startTime = startTimeMS / 1000
            self.castBar.endTime = endTimeMS / 1000
            return
        end
    end

    self.castBar.castGUID  = nil
    self.castBar.isChannel = nil
    self.castBar.isEmpowered = nil
    self.castBar.numStages = nil
    if self.castBar.empoweredStages then
        for _, stage in ipairs(self.castBar.empoweredStages) do
            stage:Hide()
        end
    end
    self.castBar:Hide()
    self.castBar:SetScript("OnUpdate", nil)
end

-- Hook into Blizzard's target and focus cast bars to avoid secret value issues
function NephUI:HookTargetAndFocusCastBars()
    -- Hook Target cast bar
    local targetSpellbar = _G["TargetFrame"] and _G["TargetFrame"].spellbar
    if targetSpellbar and not targetSpellbar.__nephuiHooked then
        targetSpellbar.__nephuiHooked = true
        
        targetSpellbar:HookScript("OnShow", function(self)
            local cfg = NephUI.db.profile.targetCastBar
            if not cfg or not cfg.enabled then
                if NephUI.targetCastBar then NephUI.targetCastBar:Hide() end
                return
            end
            
            local bar = NephUI:GetTargetCastBar()
            if not bar then return end
            
            NephUI:UpdateTargetCastBarLayout()
            
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
        
        targetSpellbar:HookScript("OnHide", function()
            if NephUI.targetCastBar then
                NephUI.targetCastBar:Hide()
            end
        end)
        
        -- Hook OnUpdate to sync progress and time text
        -- Use simple format without "s" suffix (just use Blizzard's values directly)
        targetSpellbar:HookScript("OnUpdate", function(self, elapsed)
            local cfg = NephUI.db.profile.targetCastBar
            if not cfg or not cfg.enabled then return end
            
            local bar = NephUI.targetCastBar
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
            
            local bar = NephUI:GetFocusCastBar()
            if not bar then return end
            
            NephUI:UpdateFocusCastBarLayout()
            
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

function NephUI:OnUnitSpellcastChannelUpdate(_, unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastChannelUpdate(unit, castGUID, spellID)
    -- Target and focus are now handled via hooks into Blizzard cast bars
    end
end

function NephUI:OnPlayerSpellcastChannelUpdate(unit, castGUID, spellID)
    if not self.castBar then return end
    if self.castBar.castGUID and castGUID and castGUID ~= self.castBar.castGUID then
        return
    end

    local name, _, texture, startTimeMS, endTimeMS = UnitChannelInfo("player")
    if not name or not startTimeMS or not endTimeMS then
        return
    end

    local bar = self.castBar
    bar.isChannel = true
    bar.castGUID  = castGUID

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    bar.startTime = startTimeMS / 1000
    bar.endTime   = endTimeMS / 1000
end

function NephUI:OnUnitSpellcastChannelStart(_, unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastChannelStart(unit, castGUID, spellID)
    -- Target and focus are now handled via hooks into Blizzard cast bars
    end
end

function NephUI:OnPlayerSpellcastChannelStart(unit, castGUID, spellID)

    local cfg = self.db.profile.castBar
    if not cfg.enabled then
        if self.castBar then self.castBar:Hide() end
        return
    end

    local name, _, texture, startTimeMS, endTimeMS = UnitChannelInfo("player")
    if not name or not startTimeMS or not endTimeMS then
        if self.castBar then self.castBar:Hide() end
        return
    end

    local bar = self:GetCastBar()
    self:UpdateCastBarLayout()

    bar.isChannel = true
    bar.castGUID  = castGUID

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    local font = self:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    bar.startTime = startTimeMS / 1000
    bar.endTime   = endTimeMS / 1000

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

function NephUI:ShowTestCastBar()
    local cfg = self.db.profile.castBar
    if not cfg then return end

    if not cfg.enabled then
        if self.castBar then
            self.castBar:Hide()
        end
        return
    end

    local bar = self:GetCastBar()
    if not bar then return end

    self:UpdateCastBarLayout()

    bar.isChannel = false
    bar.castGUID  = nil

    bar.icon:SetTexture(136243) -- question mark icon
    bar.spellName:SetText("Test Cast")

    local font = self:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    local now      = GetTime()
    local duration = 10

    bar.startTime = now
    bar.endTime   = now + duration

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

-- Empowered Cast Functions

function NephUI:InitializeEmpoweredStages(bar)
    if not bar or not bar.isEmpowered or not bar.numStages or bar.numStages <= 0 then
        return
    end

    -- Clean up existing stages
    if bar.empoweredStages then
        for _, stage in ipairs(bar.empoweredStages) do
            if stage then
                stage:Hide()
            end
        end
    else
        bar.empoweredStages = {}
    end

    -- Create stage markers
    local status = bar.status
    if not status then return end

    -- Wait a frame for the bar to be properly sized
    C_Timer.After(0, function()
        local barWidth = status:GetWidth()
        if barWidth <= 0 then 
            -- Try again after a short delay
            C_Timer.After(0.05, function()
                self:InitializeEmpoweredStages(bar)
            end)
            return 
        end

        for i = 1, bar.numStages do
            local stage = bar.empoweredStages[i]
            if not stage then
                stage = status:CreateTexture(nil, "OVERLAY")
                stage:SetColorTexture(1, 1, 1, 0.8)
                stage:SetWidth(2)
                bar.empoweredStages[i] = stage
            end

            local stageHeight = status:GetHeight() or bar:GetHeight() or 10
            stage:SetHeight(stageHeight)

            -- Position stage marker at the appropriate position
            -- Stages are at 1/numStages, 2/numStages, etc.
            local position = (i / bar.numStages) * barWidth
            stage:ClearAllPoints()
            stage:SetPoint("LEFT", status, "LEFT", position - 1, 0)
            stage:SetPoint("TOP", status, "TOP", 0, 0)
            stage:SetPoint("BOTTOM", status, "BOTTOM", 0, 0)
            stage:Show()
        end
    end)
end

function NephUI:OnUnitSpellcastEmpowerStart(event, unit, castGUID, spellID)
    -- Debug: print to verify event is firing
    -- print("EMPOWER_START:", unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastEmpowerStart(unit, castGUID, spellID)
    end
end

function NephUI:OnPlayerSpellcastEmpowerStart(unit, castGUID, spellID)
    local cfg = self.db.profile.castBar
    if not cfg or not cfg.enabled then
        return
    end

    local bar = self:GetCastBar()
    self:UpdateCastBarLayout()

    -- For empowered casts, we need to get info differently
    -- Try UnitCastingInfo first - it should work for empowered casts too
    local name, _, texture, startTimeMS, endTimeMS, _, _, _, _, numStages = UnitCastingInfo("player")
    
    -- If UnitCastingInfo doesn't have the data, try to get spell info from spellID
    if not name or not startTimeMS or not endTimeMS then
        -- Try C_Spell API if spellID is available
        if spellID and C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo then
                if not name then
                    name = spellInfo.name
                end
                if not texture then
                    texture = spellInfo.iconID or 136243
                end
            end
        end
        
        -- Try C_UnitAuras for stage info
        local stageInfo = nil
        if C_UnitAuras and C_UnitAuras.GetEmpoweredStageInfo then
            stageInfo = C_UnitAuras.GetEmpoweredStageInfo("player")
            if stageInfo then
                numStages = stageInfo.numStages or 0
                -- Try to get times from stage info if available
                if stageInfo.startTime and stageInfo.endTime then
                    startTimeMS = stageInfo.startTime * 1000
                    endTimeMS = stageInfo.endTime * 1000
                end
            end
        end
        
        -- If we still don't have essential data, use defaults
        if not name then
            name = "Empowered Cast"
        end
        if not texture then
            texture = 136243
        end
        if not startTimeMS or not endTimeMS then
            local now = GetTime()
            startTimeMS = now * 1000
            -- Default to 3 second empower duration
            endTimeMS = (now + 3) * 1000
        end
    end

    bar.isEmpowered = true
    bar.numStages = numStages or 3  -- Default to 3 stages if not detected
    bar.castGUID = castGUID
    bar.isChannel = false

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    local font = self:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    local now = GetTime()
    bar.startTime = startTimeMS / 1000
    bar.endTime = endTimeMS / 1000

    -- Safety: if start time is very old, clamp to now
    if bar.startTime < now - 5 then
        local dur = (endTimeMS - startTimeMS) / 1000
        bar.startTime = now
        bar.endTime = now + dur
    end

    -- Initialize empowered stages
    if bar.numStages and bar.numStages > 0 then
        -- Delay slightly to ensure bar is sized
        C_Timer.After(0.01, function()
            if bar.isEmpowered and bar.numStages > 0 then
                self:InitializeEmpoweredStages(bar)
            end
        end)
    end

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

function NephUI:OnUnitSpellcastEmpowerUpdate(_, unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastEmpowerUpdate(unit, castGUID, spellID)
    end
end

function NephUI:OnPlayerSpellcastEmpowerUpdate(unit, castGUID, spellID)
    if not self.castBar then return end
    if self.castBar.castGUID and castGUID and castGUID ~= self.castBar.castGUID then
        return
    end

    local bar = self.castBar
    
    -- Update empowered cast info
    local name, _, texture, startTimeMS, endTimeMS, _, _, _, _, numStages = UnitCastingInfo("player")
    
    -- Try C_UnitAuras if UnitCastingInfo doesn't work
    if not name or not startTimeMS or not endTimeMS then
        if C_UnitAuras and C_UnitAuras.GetEmpoweredStageInfo then
            local stageInfo = C_UnitAuras.GetEmpoweredStageInfo("player")
            if stageInfo then
                if stageInfo.startTime and stageInfo.endTime then
                    startTimeMS = stageInfo.startTime * 1000
                    endTimeMS = stageInfo.endTime * 1000
                end
                if stageInfo.numStages then
                    numStages = stageInfo.numStages
                end
            end
        end
    end
    
    if startTimeMS and endTimeMS then
        bar.startTime = startTimeMS / 1000
        bar.endTime = endTimeMS / 1000
    end

    -- Update stages if number changed
    if numStages and numStages ~= bar.numStages then
        bar.numStages = numStages
        self:InitializeEmpoweredStages(bar)
    end
end

function NephUI:OnUnitSpellcastEmpowerStop(_, unit, castGUID, spellID)
    if unit == "player" then
        self:OnPlayerSpellcastEmpowerStop(unit, castGUID, spellID)
    end
end

function NephUI:OnPlayerSpellcastEmpowerStop(unit, castGUID, spellID)
    if not self.castBar then return end

    if castGUID and self.castBar.castGUID and castGUID ~= self.castBar.castGUID then
        return
    end

    -- Check if still casting (empowered cast may transition to regular cast)
    local name, _, texture, startTimeMS, endTimeMS = UnitCastingInfo("player")
    if name and startTimeMS and endTimeMS then
        -- Still casting, update the bar
        self.castBar.icon:SetTexture(texture)
        self.castBar.spellName:SetText(name)
        self.castBar.startTime = startTimeMS / 1000
        self.castBar.endTime = endTimeMS / 1000
        self.castBar.isEmpowered = false
        self.castBar.numStages = 0
        if self.castBar.empoweredStages then
            for _, stage in ipairs(self.castBar.empoweredStages) do
                stage:Hide()
            end
        end
        return
    end

    -- Cast finished, hide the bar
    self.castBar.castGUID = nil
    self.castBar.isChannel = nil
    self.castBar.isEmpowered = nil
    self.castBar.numStages = nil
    if self.castBar.empoweredStages then
        for _, stage in ipairs(self.castBar.empoweredStages) do
            stage:Hide()
        end
    end
    self.castBar:Hide()
    self.castBar:SetScript("OnUpdate", nil)
end

function NephUI:ShowTestTargetCastBar()
    local cfg = self.db.profile.targetCastBar
    if not cfg then return end

    if not cfg.enabled then
        if self.targetCastBar then
            self.targetCastBar:Hide()
        end
        return
    end

    local bar = self:GetTargetCastBar()
    if not bar then return end

    self:UpdateTargetCastBarLayout()

    bar.isChannel = false
    bar.castGUID  = nil
    bar.notInterruptible = false

    bar.icon:SetTexture(136243) -- question mark icon
    bar.spellName:SetText("Test Target Cast")

    local font = self:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    local now      = GetTime()
    local duration = 10

    bar.startTime = now
    bar.endTime   = now + duration

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

function NephUI:ShowTestFocusCastBar()
    local cfg = self.db.profile.focusCastBar
    if not cfg then return end

    if not cfg.enabled then
        if self.focusCastBar then
            self.focusCastBar:Hide()
        end
        return
    end

    local bar = self:GetFocusCastBar()
    if not bar then return end

    self:UpdateFocusCastBarLayout()

    bar.isChannel = false
    bar.castGUID  = nil
    bar.notInterruptible = false

    bar.icon:SetTexture(136243) -- question mark icon
    bar.spellName:SetText("Test Focus Cast")

    local font = self:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    local now      = GetTime()
    local duration = 10

    bar.startTime = now
    bar.endTime   = now + duration

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end
