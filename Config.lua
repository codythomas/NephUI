local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

local ViewerOptions = ns.CreateViewerOptions
local ResourceBarOptions = ns.CreateResourceBarOptions
local CastBarOptions = ns.CreateCastBarOptions
local CustomIconOptions = ns.CreateCustomIconOptions
local UnitFrameOptions = ns.CreateUnitFrameOptionsGroup
local ProfileOptions = ns.CreateProfileOptions
local ChatOptions = ns.CreateChatOptions
local MinimapOptions = ns.CreateMinimapOptions
local ActionBarOptions = ns.CreateActionBarOptions
local BuffDebuffFramesOptions = ns.CreateBuffDebuffFramesOptions
local GetTrackedItemsEntries = ns.GetTrackedItemsEntries

local function GetViewerOptions()
    return {
        ["EssentialCooldownViewer"] = "Essential Cooldowns",
        ["UtilityCooldownViewer"] = "Utility Cooldowns",
        ["BuffIconCooldownViewer"] = "Buff Icons",
    }
end

local AceDBOptions = LibStub("AceDBOptions-3.0", true)

local function GetChargeAnchorOptions()
    return {
        TOPLEFT     = "Top Left",
        TOP         = "Top",
        TOPRIGHT    = "Top Right",
        LEFT        = "Left",
        MIDDLE      = "Middle",
        RIGHT       = "Right",
        BOTTOMLEFT  = "Bottom Left",
        BOTTOM      = "Bottom",
        BOTTOMRIGHT = "Bottom Right",
    }
end

local function CreateViewerOptions(viewerKey, displayName, order)
    local ret = {
        type = "group",
        name = displayName,
        order = order,
        args = {
            header = {
                type = "header",
                name = displayName .. " Settings",
                order = 1,
            },
            enabled = {
                type = "toggle",
                name = "Enable",
                desc = "Show/hide this Cooldown Manager",
                width = "full",
                order = 2,
                get = function() return NephUI.db.profile.viewers[viewerKey].enabled end,
                set = function(_, val)
                    NephUI.db.profile.viewers[viewerKey].enabled = val
                    NephUI:RefreshAll()
                end,
            },
            spacer1 = {
                type = "description",
                name = " ",
                order = 3,
            },
            
            -- ICON LAYOUT GROUP
            layoutGroup = {
                type = "group",
                name = "Icon Layout",
                inline = true,
                order = 10,
                args = {
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        desc = "Base size of each icon in pixels (longest dimension)",
                        order = 1,
                        width = "full",
                        min = 16, max = 96, step = 1,
                        get = function() return NephUI.db.profile.viewers[viewerKey].iconSize end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].iconSize = val
                            NephUI:RefreshAll()
                        end,
                    },
                    aspectRatio = {
                        type = "range",
                        name = "Aspect Ratio (Width:Height)",
                        desc = "Control the icon aspect ratio. 1.0 = square, >1.0 = wider, <1.0 = taller. Examples: 1.0=1:1, 1.78=16:9, 0.56=9:16",
                        order = 2,
                        width = "full",
                        min = 0.5, max = 2.5, step = 0.01,
                        get = function() 
                            local profile = NephUI.db.profile.viewers[viewerKey]
                            -- Convert aspect ratio string to number, or use stored crop value
                            if profile.aspectRatioCrop then
                                return profile.aspectRatioCrop
                            elseif profile.aspectRatio then
                                -- Convert "16:9" format to 1.78
                                local w, h = profile.aspectRatio:match("^(%d+):(%d+)$")
                                if w and h then
                                    return tonumber(w) / tonumber(h)
                                end
                            end
                            return 1.0 -- Default to square
                        end,
                        set = function(_, val)
                            local profile = NephUI.db.profile.viewers[viewerKey]
                            profile.aspectRatioCrop = val
                            local rounded = math.floor(val * 100 + 0.5) / 100
                            profile.aspectRatio = string.format("%.2f:1", rounded)
                            NephUI:RefreshAll()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = "Spacing",
                        desc = "Space between icons (negative = overlap)",
                        order = 4,
                        width = "full",
                        min = -20, max = 20, step = 1,
                        get = function() return NephUI.db.profile.viewers[viewerKey].spacing end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].spacing = val
                            NephUI:RefreshAll()
                        end,
                    },
                    zoom = {
                        type = "range",
                        name = "Icon Zoom",
                        desc = "Crops the edges of icons (higher = more zoom)",
                        order = 5,
                        width = "full",
                        min = 0, max = 0.2, step = 0.01,
                        get = function() return NephUI.db.profile.viewers[viewerKey].zoom end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].zoom = val
                            NephUI:RefreshAll()
                        end,
                    },
                    rowLimit = {
                        type = "range",
                        name = "Icons Per Row",
                        desc = "Maximum icons per row (0 = unlimited, single row). When exceeded, creates new rows that grow from the center.",
                        order = 6,
                        width = "full",
                        min = 0, max = 20, step = 1,
                        get = function() return NephUI.db.profile.viewers[viewerKey].rowLimit or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].rowLimit = val
                            NephUI:RefreshAll()
                        end,
                    },
                    rowGrowDirection = {
                        type = "select",
                        name = "Row Growth Direction",
                        desc = "Direction that rows grow when Icons Per Row is exceeded (only applies to BuffIconCooldownViewer)",
                        order = 7,
                        width = "full",
                        values = {
                            ["up"] = "Up",
                            ["down"] = "Down",
                        },
                        get = function()
                            return NephUI.db.profile.viewers[viewerKey].rowGrowDirection or "down"
                        end,
                        set = function(_, val)
                            if viewerKey == "BuffIconCooldownViewer" then
                                NephUI.db.profile.viewers[viewerKey].rowGrowDirection = val
                                NephUI:RefreshAll()
                            end
                        end,
                    },
                },
            },
            
            -- BORDER GROUP
            borderGroup = {
                type = "group",
                name = "Borders",
                inline = true,
                order = 20,
                args = {
                    borderSize = {
                        type = "range",
                        name = "Border Size",
                        desc = "Border thickness (0 = no border)",
                        order = 1,
                        width = "full",
                        min = 0, max = 5, step = 1,
                        get = function() return NephUI.db.profile.viewers[viewerKey].borderSize end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].borderSize = val
                            NephUI:RefreshAll()
                        end,
                    },
                },
            },
            
            -- TEXT GROUP
            textGroup = {
                type = "group",
                name = "Charge / Stack Text",
                inline = true,
                order = 30,
                args = {
                    countTextSize = {
                        type = "range",
                        name = "Text Size",
                        desc = "Font size for charge/stack numbers",
                        order = 1,
                        width = "full",
                        min = 6, max = 32, step = 1,
                        get = function() return NephUI.db.profile.viewers[viewerKey].countTextSize or 16 end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].countTextSize = val
                            NephUI:RefreshAll()
                        end,
                    },
                    chargeTextAnchor = {
                        type = "select",
                        name = "Text Position",
                        desc = "Where to anchor the charge/stack text",
                        order = 2,
                        width = "full",
                        values = GetChargeAnchorOptions(),
                        get = function()
                            return NephUI.db.profile.viewers[viewerKey].chargeTextAnchor or "BOTTOMRIGHT"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].chargeTextAnchor = val
                            NephUI:RefreshAll()
                        end,
                    },
                    countTextOffsetX = {
                        type = "range",
                        name = "Horizontal Offset",
                        desc = "Fine-tune text position horizontally",
                        order = 3,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function()
                            return NephUI.db.profile.viewers[viewerKey].countTextOffsetX or 0
                        end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].countTextOffsetX = val
                            NephUI:RefreshAll()
                        end,
                    },
                    countTextOffsetY = {
                        type = "range",
                        name = "Vertical Offset",
                        desc = "Fine-tune text position vertically",
                        order = 4,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function()
                            return NephUI.db.profile.viewers[viewerKey].countTextOffsetY or 0
                        end,
                        set = function(_, val)
                            NephUI.db.profile.viewers[viewerKey].countTextOffsetY = val
                            NephUI:RefreshAll()
                        end,
                    },
                },
            },
        },
    }
    
    -- Add button to open config panel for BuffIconCooldownViewer (at the top)
    if viewerKey == "BuffIconCooldownViewer" then
        -- Insert at the top by using order 1.5 (between header and enabled)
        ret.args.previewBuffIcons = {
            type = "execute",
            name = "Preview Buff Icons",
            desc = "Open the full NephUI configuration panel",
            order = 1.5,
            width = "full",
            func = function()
                -- Open the custom GUI instead
                if NephUI and NephUI.OpenConfigGUI then
                    NephUI:OpenConfigGUI()
                end
            end,
        }
    end
    
    return ViewerOptions(viewerKey, displayName, order)
end

function NephUI:SetupOptions()
    local AceConfig = LibStub("AceConfig-3.0")
    local LibDualSpec = LibStub("LibDualSpec-1.0", true)

    local profileOptions
    if AceDBOptions and self.db then
        profileOptions = AceDBOptions:GetOptionsTable(self.db)
        -- Enhance profile options with LibDualSpec if available
        if LibDualSpec then
            LibDualSpec:EnhanceOptions(profileOptions, self.db)
        end
    end

    local options = {
        type = "group",
        name = "NephUI",
        args = {
            -- GENERAL TAB
            general = {
                type = "group",
                name = "General",
                order = 0,
                args = {
                    -- General Settings Header
                    generalHeader = {
                        type = "header",
                        name = "General Settings",
                        order = 1,
                    },
                    
                    -- Global Texture
                    globalTexture = {
                        type = "select",
                        name = "Global Texture",
                        desc = "Texture used globally across all UI elements",
                        order = 10,
                        width = "full",
                        values = function()
                            local hashTable = LSM:HashTable("statusbar")
                            local names = {}
                            for name, _ in pairs(hashTable) do
                                names[name] = name
                            end
                            return names
                        end,
                        get = function()
                            return NephUI.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.general.globalTexture = val
                            if NephUI.RefreshAll then
                                NephUI:RefreshAll()
                            end
                        end,
                    },
                    
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 19,
                    },
                    
                    -- Apply Global Font to Blizzard UI
                    applyGlobalFontToBlizzard = {
                        type = "toggle",
                        name = "Apply Global Font to Blizzard UI",
                        desc = "When enabled, the global font will also change Blizzard's default UI fonts (tooltips, quest tracker, chat, etc.). When disabled, only NephUI elements will use the global font.",
                        order = 19.5,
                        width = "full",
                        get = function()
                            return NephUI.db.profile.general.applyGlobalFontToBlizzard or false
                        end,
                        set = function(_, val)
                            NephUI.db.profile.general.applyGlobalFontToBlizzard = val
                            -- Reset hook flags so hooks can be recreated if needed
                            if NephUI._questFontHooked then
                                NephUI._questFontHooked = nil
                            end
                            if NephUI._tooltipFontHooked then
                                NephUI._tooltipFontHooked = nil
                            end
                            if NephUI._chatFontHooked then
                                NephUI._chatFontHooked = nil
                            end
                            if NephUI.ApplyGlobalFont then
                                NephUI:ApplyGlobalFont()
                            end
                        end,
                    },
                    
                    -- Global Font
                    globalFont = {
                        type = "select",
                        name = "Global Font",
                        desc = "Font used globally across all NephUI elements (viewers, auras, cast bars, etc.). Use the toggle above to also apply to Blizzard's UI.",
                        order = 20,
                        width = "full",
                        values = function()
                            local hashTable = LSM:HashTable("font")
                            local names = {}
                            for name, _ in pairs(hashTable) do
                                names[name] = name
                            end
                            return names
                        end,
                        get = function()
                            return NephUI.db.profile.general.globalFont or "Expressway"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.general.globalFont = val
                            if NephUI.ApplyGlobalFont then
                                NephUI:ApplyGlobalFont()
                            end
                            if NephUI.RefreshAll then
                                NephUI:RefreshAll()
                            end
                        end,
                    },
                    
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 29,
                    },
                    
                    -- UI Scale Header
                    uiScaleHeader = {
                        type = "header",
                        name = "UI Scale Settings",
                        order = 30,
                    },
                    
                    -- Use UI Scale Toggle
                    useUiScale = {
                        type = "toggle",
                        name = "Use UI Scale",
                        desc = "Enable or disable UI scaling",
                        order = 40,
                        width = "full",
                        get = function()
                            local cvarValue = GetCVar("useUiScale")
                            return cvarValue == "1" or cvarValue == "true"
                        end,
                        set = function(_, val)
                            SetCVar("useUiScale", val and "1" or "0")
                        end,
                    },
                    
                    spacer3 = {
                        type = "description",
                        name = " ",
                        order = 41,
                    },
                    
                    -- UI Scale Input
                    uiScale = {
                        type = "input",
                        name = "UI Scale",
                        desc = "Enter a UI scale value (0.33 to 1.0)",
                        order = 50,
                        width = "full",
                        get = function()
                            -- If we have a saved value, show that (user has manually set it)
                            local savedScale = NephUI.db.profile.general.uiScale
                            if savedScale and type(savedScale) == "number" then
                                return string.format("%.8f", savedScale)
                            end
                            
                            -- Otherwise, read current scale from CVar (don't save it)
                            local cvarValue = GetCVar("uiscale")
                            if cvarValue then
                                local scale = tonumber(cvarValue)
                                if scale then
                                    return string.format("%.8f", scale)
                                end
                            end
                            
                            -- Fallback: get from UIParent if CVar not available
                            local currentScale = UIParent:GetScale()
                            if currentScale then
                                return string.format("%.8f", currentScale)
                            end
                            
                            -- Last resort: default to 1.0 (but don't save it)
                            return "1.00000000"
                        end,
                        set = function(_, val)
                            -- Store the value temporarily (don't apply yet)
                            -- This allows the confirm button to read what the user typed
                            local numValue = tonumber(val)
                            if numValue then
                                -- Clamp to valid range (0.33 to 1.0)
                                numValue = math.max(0.33, math.min(1.0, numValue))
                                NephUI.db.profile.general.uiScale = numValue
                                -- Note: We don't apply it here - only when Confirm is clicked
                            end
                        end,
                    },
                    
                    -- Confirm UI Scale Button
                    confirmUIScale = {
                        type = "execute",
                        name = "Confirm UI Scale",
                        desc = "Apply the UI scale value from the input box above",
                        order = 51,
                        width = "full",
                        func = function()
                            -- Get the value from the database (which is updated as user types)
                            local savedScale = NephUI.db.profile.general.uiScale
                            
                            -- If no saved value, read current CVar value
                            if not savedScale or type(savedScale) ~= "number" then
                                local cvarValue = GetCVar("uiscale")
                                if cvarValue then
                                    savedScale = tonumber(cvarValue)
                                end
                            end
                            
                            if savedScale and type(savedScale) == "number" then
                                -- Clamp to valid range
                                savedScale = math.max(0.33, math.min(1.0, savedScale))
                                -- Save the value (this is the user's choice, so we save it)
                                NephUI.db.profile.general.uiScale = savedScale
                                -- Apply the scale
                                if NephUI.AutoUIScale and NephUI.AutoUIScale.SetUIScale then
                                    NephUI.AutoUIScale:SetUIScale(savedScale)
                                    print("|cff00ff00[NephUI] UI Scale set to " .. string.format("%.8f", savedScale) .. "|r")
                                end
                                -- Refresh config to update the input field
                                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                                if AceConfigRegistry then
                                    AceConfigRegistry:NotifyChange(ADDON_NAME)
                                end
                                -- Refresh custom GUI if open
                                local configFrame = _G["NephUI_ConfigFrame"]
                                if configFrame and configFrame:IsShown() and configFrame.FullRefresh then
                                    configFrame:FullRefresh()
                                end
                            else
                                print("|cffff0000[NephUI] Invalid UI scale value. Please enter a number between 0.33 and 1.0|r")
                            end
                        end,
                    },
                    
                    spacer4 = {
                        type = "description",
                        name = " ",
                        order = 52,
                    },
                    
                    -- Preset Buttons
                    preset1080p = {
                        type = "execute",
                        name = "Set for 1080p (0.711111)",
                        desc = "Automatically set UI scale to 0.711111 for 1080p displays",
                        order = 60,
                        width = "full",
                        func = function()
                            local scale1080p = 0.711111
                            NephUI.db.profile.general.uiScale = scale1080p
                            -- Apply the scale
                            if NephUI.AutoUIScale and NephUI.AutoUIScale.SetUIScale then
                                NephUI.AutoUIScale:SetUIScale(scale1080p)
                                print("|cff00ff00[NephUI] UI Scale set to 0.711111 for 1080p|r")
                            end
                            -- Refresh config to update the input field
                            local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                            if AceConfigRegistry then
                                AceConfigRegistry:NotifyChange(ADDON_NAME)
                            end
                            -- Refresh custom GUI if open
                            local configFrame = _G["NephUI_ConfigFrame"]
                            if configFrame and configFrame:IsShown() and configFrame.FullRefresh then
                                configFrame:FullRefresh()
                            end
                        end,
                    },
                    
                    preset1440p = {
                        type = "execute",
                        name = "Set for 1440p (0.53333333)",
                        desc = "Automatically set UI scale to 0.53333333 for 1440p displays",
                        order = 61,
                        width = "full",
                        func = function()
                            local scale1440p = 0.53333333
                            NephUI.db.profile.general.uiScale = scale1440p
                            -- Apply the scale
                            if NephUI.AutoUIScale and NephUI.AutoUIScale.SetUIScale then
                                NephUI.AutoUIScale:SetUIScale(scale1440p)
                                print("|cff00ff00[NephUI] UI Scale set to 0.53333333 for 1440p|r")
                            end
                            -- Refresh config to update the input field
                            local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                            if AceConfigRegistry then
                                AceConfigRegistry:NotifyChange(ADDON_NAME)
                            end
                            -- Refresh custom GUI if open
                            local configFrame = _G["NephUI_ConfigFrame"]
                            if configFrame and configFrame:IsShown() and configFrame.FullRefresh then
                                configFrame:FullRefresh()
                            end
                        end,
                    },
                },
            },
            
            -- MINIMAP TAB (moved from General sub-tab)
            minimap = MinimapOptions(),
            
            -- CHAT TAB (moved from General sub-tab)
            chat = ChatOptions(),
            
            -- ACTION BARS TAB
            actionBars = ActionBarOptions(),
            
            -- BUFF/DEBUFF FRAMES TAB
            buffDebuffFrames = BuffDebuffFramesOptions(),
            
            -- Cooldown Manager TAB
            viewers = {
                type = "group",
                name = "Cooldown Manager",
                order = 3,
                childGroups = "tab",
                args = {
                    general = {
                        type = "group",
                        name = "General",
                        order = 0,
                        args = {
                            header = {
                                type = "header",
                                name = "Cooldown Manager Settings",
                                order = 1,
                            },
                            -- Proc Glow Section
                            procGlowHeader = {
                                type = "header",
                                name = "Proc Glow Customization",
                                order = 10,
                            },
                            procGlowEnabled = {
                                type = "toggle",
                                name = "Enable Proc Glow Customization",
                                desc = "Customize the spell activation overlay and proc glow effects using LibCustomGlow",
                                width = "full",
                                order = 11,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return procGlow and procGlow.enabled or false
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.enabled = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            procGlowSpacer1 = {
                                type = "description",
                                name = " ",
                                order = 12,
                            },
                            -- Glow Type
                            glowType = {
                                type = "select",
                                name = "Glow Type",
                                desc = "Choose the type of glow effect",
                                order = 20,
                                width = "full",
                                values = function()
                                    local result = {}
                                    if NephUI.ProcGlow and NephUI.ProcGlow.LibCustomGlowTypes then
                                        for _, glowType in ipairs(NephUI.ProcGlow.LibCustomGlowTypes) do
                                            result[glowType] = glowType
                                        end
                                    end
                                    return result
                                end,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return (procGlow and procGlow.glowType) or "Pixel Glow"
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.glowType = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            loopColor = {
                                type = "color",
                                name = "Glow Color",
                                desc = "Color for the glow effect",
                                order = 21,
                                width = "normal",
                                hasAlpha = true,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    local color = (procGlow and procGlow.loopColor) or {0.95, 0.95, 0.32, 1}
                                    return color[1], color[2], color[3], color[4] or 1
                                end,
                                set = function(_, r, g, b, a)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.loopColor = {r, g, b, a or 1}
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            procGlowSpacer2 = {
                                type = "description",
                                name = " ",
                                order = 22,
                            },
                            -- Custom Glow Options
                            lcgHeader = {
                                type = "header",
                                name = "Custom Glow Options",
                                order = 30,
                            },
                            lcgLines = {
                                type = "range",
                                name = "Lines",
                                desc = "Number of lines for Pixel Glow and Autocast Shine",
                                order = 31,
                                width = "normal",
                                min = 1,
                                max = 30,
                                step = 1,
                                disabled = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return not (procGlow and procGlow.glowType and procGlow.glowType ~= "Action Button Glow" and procGlow.glowType ~= "Proc Glow")
                                end,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return procGlow and procGlow.lcgLines or 14
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.lcgLines = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            lcgFrequency = {
                                type = "range",
                                name = "Frequency",
                                desc = "Animation frequency/speed",
                                order = 32,
                                width = "normal",
                                min = 0.1,
                                max = 2.0,
                                step = 0.05,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return procGlow and procGlow.lcgFrequency or 0.25
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.lcgFrequency = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            lcgThickness = {
                                type = "range",
                                name = "Thickness",
                                desc = "Line thickness for Pixel Glow",
                                order = 33,
                                width = "normal",
                                min = 1,
                                max = 10,
                                step = 1,
                                disabled = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return not (procGlow and procGlow.glowType == "Pixel Glow")
                                end,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return procGlow and procGlow.lcgThickness or 2
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.lcgThickness = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            lcgXOffset = {
                                type = "range",
                                name = "X Offset",
                                desc = "Horizontal offset (positive = expand outward, negative = shrink inward). Automatically accounts for viewer padding.",
                                order = 34,
                                width = "normal",
                                min = -20,
                                max = 20,
                                step = 1,
                                disabled = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return not (procGlow and procGlow.glowType and procGlow.glowType ~= "Action Button Glow")
                                end,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return procGlow and procGlow.lcgXOffset or -7
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.lcgXOffset = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                            lcgYOffset = {
                                type = "range",
                                name = "Y Offset",
                                desc = "Vertical offset (positive = expand outward, negative = shrink inward). Automatically accounts for viewer padding.",
                                order = 35,
                                width = "normal",
                                min = -20,
                                max = 20,
                                step = 1,
                                disabled = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return not (procGlow and procGlow.glowType and procGlow.glowType ~= "Action Button Glow")
                                end,
                                get = function()
                                    local procGlow = NephUI.db.profile.viewers.general.procGlow
                                    return procGlow and procGlow.lcgYOffset or -7
                                end,
                                set = function(_, val)
                                    if not NephUI.db.profile.viewers.general.procGlow then
                                        NephUI.db.profile.viewers.general.procGlow = {}
                                    end
                                    NephUI.db.profile.viewers.general.procGlow.lcgYOffset = val
                                    if NephUI.ProcGlow and NephUI.ProcGlow.RefreshAll then
                                        NephUI.ProcGlow:RefreshAll()
                                    end
                                end,
                            },
                        },
                    },
                    essential = CreateViewerOptions("EssentialCooldownViewer", "Essential", 1),
                    utility = CreateViewerOptions("UtilityCooldownViewer", "Utility", 2),
                    buff = CreateViewerOptions("BuffIconCooldownViewer", "Buffs", 3),
                },
            },
            
            -- RESOURCE BARS TAB
            resourceBars = ResourceBarOptions(),
            
            -- CAST BARS TAB
            castBars = CastBarOptions(),
            
            -- CUSTOM ICONS TAB
            customIcons = CustomIconOptions(),
            
            -- UNIT FRAMES TAB
            unitFrames = UnitFrameOptions(),
            
            -- IMPORT / EXPORT TAB
            importExport = ProfileOptions(),
        },
    }
    
    if profileOptions then
        -- Copy all properties from profileOptions first
        options.args.profiles = {}
        for k, v in pairs(profileOptions) do
            options.args.profiles[k] = v
        end
        -- Override name and order
        options.args.profiles.name = "Profiles"
        options.args.profiles.order = 98
        
        -- Merge LibDualSpec plugin options into args so they appear in the custom GUI
        if LibDualSpec and profileOptions.plugins and profileOptions.plugins["LibDualSpec-1.0"] then
            local dualSpecOptions = profileOptions.plugins["LibDualSpec-1.0"]
            if not options.args.profiles.args then
                options.args.profiles.args = {}
            end
            -- Merge all dual spec options into the args
            for key, option in pairs(dualSpecOptions) do
                options.args.profiles.args[key] = option
            end
        end
        
        -- Fix the "new" profile input field to not create profiles on every keystroke
        -- Store the profile name in a buffer and only create when button is clicked
        local profileBuffers = {
            new = "",
            copyFrom = "",
            delete = "",
        }
        local handler = options.args.profiles.handler
        
        if options.args.profiles.args and options.args.profiles.args.new then
            local originalSet = options.args.profiles.args.new.set
            
            -- Override the set function to just store the value instead of creating profile
            options.args.profiles.args.new.set = function(info, value)
                profileBuffers.new = value or ""
            end
            -- Change get to return empty string (don't show buffer)
            options.args.profiles.args.new.get = function()
                return ""
            end
            
            -- Add a "Create Profile" button after the new input field
            options.args.profiles.args.createProfile = {
                type = "execute",
                name = "Create Profile",
                desc = "Create a new profile with the name entered above",
                order = 31,
                func = function(info)
                    if not profileBuffers.new or profileBuffers.new == "" then
                        print("|cffff0000NephUI: Please enter a profile name.|r")
                        return
                    end
                    -- Trim whitespace
                    profileBuffers.new = profileBuffers.new:gsub("^%s+", ""):gsub("%s+$", "")
                    if profileBuffers.new == "" then
                        print("|cffff0000NephUI: Please enter a valid profile name.|r")
                        return
                    end
                    
                    -- Directly call SetProfile on the database - this will create the profile if it doesn't exist
                    if NephUI and NephUI.db then
                        local profileName = profileBuffers.new
                        local success, err = pcall(function()
                            -- SetProfile will create the profile if it doesn't exist (lazy creation)
                            NephUI.db:SetProfile(profileName)
                            -- Access the profile to trigger its creation if it's new
                            local _ = NephUI.db.profile
                        end)
                        if success then
                            -- Verify the profile was created by checking if it's in the profiles list
                            local profiles = NephUI.db:GetProfiles()
                            local profileExists = false
                            for _, p in ipairs(profiles) do
                                if p == profileName then
                                    profileExists = true
                                    break
                                end
                            end
                            if profileExists then
                                print("|cff00ff00NephUI: Profile '" .. profileName .. "' created successfully. Please reload your UI.|r")
                            else
                                print("|cffff0000NephUI: Profile creation may have failed. Please reload your UI and check if the profile exists.|r")
                            end
                        else
                            print("|cffff0000NephUI: Failed to create profile: " .. (err or "Unknown error") .. "|r")
                        end
                    else
                        -- Fallback to handler method if database not directly available
                        if originalSet then
                            if type(originalSet) == "string" then
                                -- It's a method name, call it on the handler
                                local handlerToUse = handler or info.handler
                                if handlerToUse and handlerToUse[originalSet] then
                                    handlerToUse[originalSet](handlerToUse, info, profileBuffers.new)
                                    print("|cff00ff00NephUI: Profile '" .. profileBuffers.new .. "' created successfully. Please reload your UI.|r")
                                else
                                    print("|cffff0000NephUI: Failed to create profile: Handler not available.|r")
                                end
                            elseif type(originalSet) == "function" then
                                originalSet(info, profileBuffers.new)
                                print("|cff00ff00NephUI: Profile '" .. profileBuffers.new .. "' created successfully. Please reload your UI.|r")
                            end
                        else
                            print("|cffff0000NephUI: Failed to create profile: No profile creation method available.|r")
                        end
                    end
                    
                    -- Clear the buffer
                    profileBuffers.new = ""
                    -- Clear the input field by refreshing
                    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                    if AceConfigRegistry then
                        AceConfigRegistry:NotifyChange(ADDON_NAME)
                    end
                end,
            }
        end
        
        -- Fix the "copyfrom" dropdown to require confirmation button
        if options.args.profiles.args and options.args.profiles.args.copyfrom then
            local originalCopySet = options.args.profiles.args.copyfrom.set
            local originalCopyGet = options.args.profiles.args.copyfrom.get
            
            -- Override the set function to just store the selection
            options.args.profiles.args.copyfrom.set = function(info, value)
                profileBuffers.copyFrom = value or ""
                -- Refresh the config UI immediately so the button shows up
                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                if AceConfigRegistry then
                    AceConfigRegistry:NotifyChange(ADDON_NAME)
                end
            end
            -- Override get to show the selected value from buffer
            options.args.profiles.args.copyfrom.get = function(info)
                if profileBuffers.copyFrom and profileBuffers.copyFrom ~= "" then
                    return profileBuffers.copyFrom
                end
                -- If no buffer, try original get or return nil
                if originalCopyGet then
                    if type(originalCopyGet) == "function" then
                        return originalCopyGet(info)
                    elseif type(originalCopyGet) == "string" then
                        local handlerToUse = handler or info.handler
                        if handlerToUse and handlerToUse[originalCopyGet] then
                            return handlerToUse[originalCopyGet](handlerToUse, info)
                        end
                    end
                end
                return nil
            end
            
            -- Add a "Copy Profile" button after the copyfrom dropdown
            options.args.profiles.args.copyProfile = {
                type = "execute",
                name = "Copy Profile",
                desc = "Copy settings from the selected profile to the current profile",
                order = 61,
                func = function(info)
                    if not profileBuffers.copyFrom or profileBuffers.copyFrom == "" then
                        print("|cffff0000NephUI: Please select a profile to copy from.|r")
                        return
                    end
                    -- Call the original CopyProfile function
                    if originalCopySet then
                        if type(originalCopySet) == "string" then
                            local handlerToUse = handler or info.handler
                            if handlerToUse and handlerToUse[originalCopySet] then
                                handlerToUse[originalCopySet](handlerToUse, info, profileBuffers.copyFrom)
                            end
                        elseif type(originalCopySet) == "function" then
                            originalCopySet(info, profileBuffers.copyFrom)
                        end
                    end
                    -- Clear the buffer
                    profileBuffers.copyFrom = ""
                    -- Refresh the config
                    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                    if AceConfigRegistry then
                        AceConfigRegistry:NotifyChange(ADDON_NAME)
                    end
                    print("|cff00ff00NephUI: Profile copied successfully.|r")
                end,
            }
        end
        
        -- Fix the "delete" dropdown to require confirmation button
        if options.args.profiles.args and options.args.profiles.args.delete then
            local originalDeleteSet = options.args.profiles.args.delete.set
            local originalDeleteGet = options.args.profiles.args.delete.get
            
            -- Override the set function to just store the selection
            options.args.profiles.args.delete.set = function(info, value)
                profileBuffers.delete = value or ""
                -- Refresh the config UI immediately so the button shows up
                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                if AceConfigRegistry then
                    AceConfigRegistry:NotifyChange(ADDON_NAME)
                end
            end
            -- Override get to show the selected value from buffer
            options.args.profiles.args.delete.get = function(info)
                if profileBuffers.delete and profileBuffers.delete ~= "" then
                    return profileBuffers.delete
                end
                -- If no buffer, try original get or return nil
                if originalDeleteGet then
                    if type(originalDeleteGet) == "function" then
                        return originalDeleteGet(info)
                    elseif type(originalDeleteGet) == "string" then
                        local handlerToUse = handler or info.handler
                        if handlerToUse and handlerToUse[originalDeleteGet] then
                            return handlerToUse[originalDeleteGet](handlerToUse, info)
                        end
                    end
                end
                return nil
            end
            
            -- Remove the confirm property since we're using a button instead
            options.args.profiles.args.delete.confirm = false
            
            -- Add a "Delete Profile" button after the delete dropdown
            options.args.profiles.args.deleteProfile = {
                type = "execute",
                name = "Delete Profile",
                desc = "Permanently delete the selected profile. This cannot be undone!",
                order = 81,
                func = function(info)
                    if not profileBuffers.delete or profileBuffers.delete == "" then
                        print("|cffff0000NephUI: Please select a profile to delete.|r")
                        return
                    end
                    -- Show confirmation dialog
                    local dialogData = {
                        profileName = profileBuffers.delete,
                        handler = handler or info.handler,
                        originalDeleteSet = originalDeleteSet,
                        info = info,
                        profileBuffers = profileBuffers,
                    }
                    StaticPopup_Show("NEPHUI_DELETE_PROFILE", profileBuffers.delete, nil, dialogData)
                end,
            }
        end
        
        -- Register the delete confirmation popup
        if not StaticPopupDialogs["NEPHUI_DELETE_PROFILE"] then
            StaticPopupDialogs["NEPHUI_DELETE_PROFILE"] = {
                text = "Are you sure you want to delete the profile '%s'? This cannot be undone!",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function(self, data)
                    if data and data.originalDeleteSet then
                        if type(data.originalDeleteSet) == "string" then
                            local handlerToUse = data.handler
                            if handlerToUse and handlerToUse[data.originalDeleteSet] then
                                handlerToUse[data.originalDeleteSet](handlerToUse, data.info, data.profileName)
                            end
                        elseif type(data.originalDeleteSet) == "function" then
                            data.originalDeleteSet(data.info, data.profileName)
                        end
                    end
                    -- Clear the buffer
                    if data and data.profileBuffers then
                        data.profileBuffers.delete = ""
                    end
                    -- Refresh the config
                    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
                    if AceConfigRegistry then
                        AceConfigRegistry:NotifyChange(ADDON_NAME)
                    end
                    print("|cff00ff00NephUI: Profile deleted successfully.|r")
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
        end
        
        if options.args.profiles.args and options.args.profiles.args.reset then
            local originalResetFunc = options.args.profiles.args.reset.func
            options.args.profiles.args.reset.func = function(info)
                local handlerToUse = handler or info.handler
                if handlerToUse and handlerToUse.Reset then
                    handlerToUse:Reset()
                    print("|cff00ff00NephUI: Profile reset to defaults. Please reload your UI.|r")
                elseif originalResetFunc then
                    -- Fallback to original func if handler method doesn't exist
                    if type(originalResetFunc) == "string" then
                        if handlerToUse and handlerToUse[originalResetFunc] then
                            handlerToUse[originalResetFunc](handlerToUse)
                            print("|cff00ff00NephUI: Profile reset to defaults. Please reload your UI.|r")
                        end
                    elseif type(originalResetFunc) == "function" then
                        originalResetFunc(info)
                        print("|cff00ff00NephUI: Profile reset to defaults. Please reload your UI.|r")
                    end
                else
                    -- Last resort: call ResetProfile directly on the database
                    if NephUI and NephUI.db then
                        NephUI.db:ResetProfile()
                        print("|cff00ff00NephUI: Profile reset to defaults. Please reload your UI.|r")
                    end
                end
            end
        end
    end

    -- QUICK ACCESS BUTTONS
    options.args.openEditMode = {
        type = "execute",
        name = "Open Edit Mode",
        desc = "Open WoW's Edit Mode to reposition UI elements",
        order = 100,
        func = function()
            DEFAULT_CHAT_FRAME.editBox:SetText("/editmode")
            ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
        end,
    }

    options.args.openConfig = {
        type = "execute",
        name = "Open Advanced Cooldown Manager Panel",
        desc = "Open Advanced Cooldown Manager Panel",
        order = 101,
        func = function()
            -- Try to find and open the CooldownViewerSettings frame
            local frame = _G["CooldownViewerSettings"]
            if frame then
                frame:Show()
                frame:Raise()
            else
                -- Fallback: Open the custom GUI and navigate to the Cooldown Manager tab
                if NephUI and NephUI.OpenConfigGUI then
                    NephUI:OpenConfigGUI(nil, "viewers")
                end
            end
        end,
    }

    options.args.enableUnitFrameAnchors = {
        type = "execute",
        name = "Enable Unit Frame Anchors",
        desc = "Show draggable anchors for unit frames (works independently of Edit Mode)",
        order = 102,
        func = function()
            local db = NephUI.db.profile.unitFrames
            if not db then
                db = {}
                NephUI.db.profile.unitFrames = db
            end
            if not db.General then db.General = {} end
            db.General.ShowEditModeAnchors = true
            if NephUI.UnitFrames then
                NephUI.UnitFrames:UpdateEditModeAnchors()
                print("|cff00ff00[NephUI] Unit frame anchors enabled|r")
            else
                print("|cffff0000[NephUI] Unit frames not initialized|r")
            end
        end,
    }

    options.args.disableUnitFrameAnchors = {
        type = "execute",
        name = "Disable Unit Frame Anchors",
        desc = "Hide draggable anchors for unit frames",
        order = 103,
        func = function()
            local db = NephUI.db.profile.unitFrames
            if not db then
                db = {}
                NephUI.db.profile.unitFrames = db
            end
            if not db.General then db.General = {} end
            db.General.ShowEditModeAnchors = false
            if NephUI.UnitFrames then
                NephUI.UnitFrames:UpdateEditModeAnchors()
                print("|cff00ff00[NephUI] Unit frame anchors disabled|r")
            else
                print("|cffff0000[NephUI] Unit frames not initialized|r")
            end
        end,
    }

    -- Version display and Discord link button
    options.args.versionSpacer = {
        type = "description",
        name = " ",
        order = 200,
    }

    options.args.version = {
        type = "description",
        name = function()
            return "|cff00ff00NephUI v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown") .. "|r"
        end,
        order = 201,
    }

    options.args.discord = {
        type = "input",
        name = "Discord",
        desc = "Join our Discord server for support and updates",
        order = 202,
        width = "full",
        get = function()
            return "https://discord.gg/Mc2StWHKya"
        end,
        set = function() end,
    }

    -- Register options with AceConfig (for compatibility - still needed for option table structure)
    AceConfig:RegisterOptionsTable(ADDON_NAME, options)
    
    -- Store options for custom GUI
    self.configOptions = options
    
    -- Setup drag and drop for custom icons
    self:SetupCustomIconsDragDrop()
end

-- Disable unit frame anchors when config panel closes
function NephUI:DisableUnitFrameAnchorsOnConfigClose()
    local db = self.db.profile.unitFrames
    if not db then return end
    if not db.General then db.General = {} end
    
    -- Only disable if anchors are currently enabled
    if db.General.ShowEditModeAnchors then
        db.General.ShowEditModeAnchors = false
        if self.UnitFrames then
            self.UnitFrames:UpdateEditModeAnchors()
        end
    end
end

-- Setup drag-and-drop frame for custom icons tab
function NephUI:SetupCustomIconsDragDrop()
    -- No longer using AceConfigDialog - using custom GUI instead
    
    -- Create a drag-and-drop frame that overlays the description area
    if not self.customIconsDragDropFrame then
        local dragFrame = CreateFrame("Button", "NephUI_CustomIconsDragDrop", UIParent, "BackdropTemplate")
        dragFrame:SetFrameStrata("FULLSCREEN_DIALOG")  -- Higher than DIALOG to be above GUI
        dragFrame:SetFrameLevel(10000)  -- Very high frame level to ensure it's on top
        dragFrame:EnableMouse(true)
        dragFrame:EnableMouseWheel(false)
        dragFrame:RegisterForDrag("LeftButton")
        dragFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        dragFrame:SetMovable(false)
        dragFrame:SetClampedToScreen(false)
        dragFrame:SetToplevel(false)  -- Don't be toplevel so it can be parented
        dragFrame:Hide()
        
        -- Add a subtle backdrop to show the drop area (optional, can be removed if too intrusive)
        dragFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        dragFrame:SetBackdropColor(0, 1, 0, 0.05) -- Very subtle green tint
        dragFrame:SetBackdropBorderColor(0, 1, 0, 0.3) -- Subtle green border
        
        -- Track the last item ID we processed to avoid duplicates
        local lastProcessedItemID = nil
        
        -- Function to handle item drops
        local function HandleItemDrop()
            local cursorType, id = GetCursorInfo()
            
            if cursorType == "item" and id and type(id) == "number" then
                local itemID = id
                
                -- Don't process the same item multiple times
                if itemID == lastProcessedItemID then
                    return
                end
                
                lastProcessedItemID = itemID
                
                if NephUI:AddCustomItem(itemID) then
                    local itemName = GetItemInfo(itemID)
                    print("|cff00ff00[NephUI] Added " .. (itemName or ("Item " .. itemID)) .. " to Custom Icons tracker|r")
                    ClearCursor()
                    -- Reset after a short delay to allow re-adding if needed
                    C_Timer.After(1.0, function()
                        lastProcessedItemID = nil
                    end)
                else
                    print("|cffff0000[NephUI] Failed to add item or item already tracked|r")
                    ClearCursor()
                end
            end
        end
        
        -- Automatically add item when mouse enters drop area with item on cursor
        dragFrame:SetScript("OnEnter", function(self)
            -- Check if there's an item on the cursor when entering
            local cursorType, id = GetCursorInfo()
            if cursorType == "item" and id and type(id) == "number" then
                -- Only process if it's not the same item we just processed
                if id ~= lastProcessedItemID then
                    HandleItemDrop()
                end
            end
        end)
        
        dragFrame:SetScript("OnLeave", function(self)
            -- Reset when leaving so we can add the same item again if needed
            lastProcessedItemID = nil
        end)
        
        -- Also handle traditional drag and drop (for compatibility)
        dragFrame:SetScript("OnReceiveDrag", function(self, ...)
            HandleItemDrop()
        end)
        
        -- Function to update drag frame position - covers entire GUI when item is on cursor
        local function UpdateDragDropFrame()
            -- Use custom GUI frame instead of AceConfigDialog
            local configFrame = _G["NephUI_ConfigFrame"]
            if not configFrame or not configFrame:IsVisible() then
                dragFrame:Hide()
                return
            end
            
            -- Check if there's an item on the cursor
            local cursorType, id = GetCursorInfo()
            if cursorType == "item" and id then
                -- Item is on cursor, show drop area over entire GUI
                -- Parent to config frame and cover entire frame
                dragFrame:SetParent(configFrame)
                dragFrame:ClearAllPoints()
                dragFrame:SetAllPoints(configFrame)
                -- Ensure frame is on top after parenting
                dragFrame:SetFrameStrata("FULLSCREEN_DIALOG")
                dragFrame:SetFrameLevel(10000)
                dragFrame:EnableMouse(true)
                dragFrame:Show()
            else
                -- No item on cursor, hide drop area
                dragFrame:Hide()
            end
        end
        
        -- Monitor cursor for items and update drop area visibility
        local cursorCheckFrame = CreateFrame("Frame", "NephUI_CursorCheck", UIParent)
        local checkCount = 0
        cursorCheckFrame:SetScript("OnUpdate", function(self, elapsed)
            checkCount = checkCount + 1
            -- Check every 0.1 seconds
            if checkCount >= 10 then
                checkCount = 0
                UpdateDragDropFrame()
            end
        end)
        
        -- Hook into custom GUI frame when it's shown
        -- Hook the OpenConfigGUI function to set up drag drop when config opens
        if NephUI.OpenConfigGUI then
            local originalOpenConfigGUI = NephUI.OpenConfigGUI
            NephUI.OpenConfigGUI = function(self, options)
                local result = originalOpenConfigGUI(self, options)
                
                -- Rebuild tracked items list when config opens
                C_Timer.After(0.2, function()
                    if NephUI.RebuildTrackedItemsList then
                        NephUI:RebuildTrackedItemsList()
                    end
                end)
                
                -- Initial update of drag frame
                C_Timer.After(0.1, function()
                    UpdateDragDropFrame()
                end)
                
                return result
            end
        end
        
        -- Also hook OnShow on the config frame if it exists
        local frameWatcher = CreateFrame("Frame")
        frameWatcher:SetScript("OnUpdate", function(self, elapsed)
            local configFrame = _G["NephUI_ConfigFrame"]
            if configFrame and configFrame:IsVisible() and not configFrame._dragDropHooked then
                configFrame._dragDropHooked = true
                local originalOnShow = configFrame:GetScript("OnShow")
                configFrame:SetScript("OnShow", function(self)
                    if originalOnShow then
                        originalOnShow(self)
                    end
                    -- Update drag frame when config is shown
                    C_Timer.After(0.1, function()
                        UpdateDragDropFrame()
                    end)
                end)
                
                local originalOnHide = configFrame:GetScript("OnHide")
                configFrame:SetScript("OnHide", function(self)
                    if originalOnHide then
                        originalOnHide(self)
                    end
                    -- Hide drag frame when config is hidden
                    dragFrame:Hide()
                    -- Disable unit frame anchors when config panel closes
                    NephUI:DisableUnitFrameAnchorsOnConfigClose()
                end)
            elseif (not configFrame or not configFrame:IsVisible()) and frameWatcher._wasVisible then
                frameWatcher._wasVisible = false
                if configFrame then
                    configFrame._dragDropHooked = nil
                end
            elseif configFrame and configFrame:IsVisible() then
                frameWatcher._wasVisible = true
            end
        end)
        
        
        -- Initial update
        UpdateDragDropFrame()
        
        self.customIconsDragDropFrame = dragFrame
    end
end

-- Function to rebuild tracked items list in config
-- Debounce mechanism to prevent rapid rebuilds
local lastRebuildTime = 0
local REBUILD_DEBOUNCE = 0.5  -- Minimum time between rebuilds (in seconds)

function NephUI:RebuildTrackedItemsList()
    -- Debounce: prevent rapid rebuilds
    local currentTime = GetTime()
    if currentTime - lastRebuildTime < REBUILD_DEBOUNCE then
        return
    end
    lastRebuildTime = currentTime
    
    if not self._trackedItemsGroup then 
        -- Try to get the reference again if it's not set
        -- Get options from stored configOptions
        if self.configOptions and self.configOptions.args and 
           self.configOptions.args.customIcons and 
           self.configOptions.args.customIcons.args and 
           self.configOptions.args.customIcons.args.general and
           self.configOptions.args.customIcons.args.general.args and 
           self.configOptions.args.customIcons.args.general.args.trackedItemsGroup then
            self._trackedItemsGroup = self.configOptions.args.customIcons.args.general.args.trackedItemsGroup
        end
        if not self._trackedItemsGroup then
            return
        end
    end
    
    -- Clear existing item entries (but keep the static ones like dragDropHeader, itemListHeader, etc.)
    for key in pairs(self._trackedItemsGroup.args) do
        if key:match("^item_") then
            self._trackedItemsGroup.args[key] = nil
        end
    end
    
    -- Add current tracked items
    local itemEntries = GetTrackedItemsEntries()
    for key, entry in pairs(itemEntries) do
        self._trackedItemsGroup.args[key] = entry
    end
    
    -- Update the frame's configOptions if it exists (ensure it has the same reference)
    local configFrame = _G["NephUI_ConfigFrame"]
    if configFrame and configFrame:IsShown() then
        -- Ensure the frame's configOptions points to the same table
        if not configFrame.configOptions or configFrame.configOptions ~= self.configOptions then
            configFrame.configOptions = self.configOptions
        end
        
        -- Also update the trackedItemsGroup reference in the frame's configOptions
        if configFrame.configOptions and configFrame.configOptions.args and 
           configFrame.configOptions.args.customIcons and 
           configFrame.configOptions.args.customIcons.args and 
           configFrame.configOptions.args.customIcons.args.general and
           configFrame.configOptions.args.customIcons.args.general.args and 
           configFrame.configOptions.args.customIcons.args.general.args.trackedItemsGroup then
            -- This should already be the same reference, but ensure it's updated
            configFrame.configOptions.args.customIcons.args.general.args.trackedItemsGroup = self._trackedItemsGroup
        end
        
        -- Refresh the GUI
        if configFrame.FullRefresh then
            configFrame:FullRefresh()
        end
    end
    
    -- Notify AceConfig to refresh (for backwards compatibility)
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange(ADDON_NAME)
    end
end

