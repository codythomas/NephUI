local ADDON_NAME, ns = ...
local NephUI = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

local function GetViewerOptions()
    return {
        ["EssentialCooldownViewer"] = "Essential Cooldowns",
        ["UtilityCooldownViewer"] = "Utility Cooldowns",
        ["BuffIconCooldownViewer"] = "Buff Icons",
    }
end

local function CreateResourceBarOptions()
    return {
        type = "group",
        name = "Resource Bars",
        order = 4,
        childGroups = "tab",
        args = {
            primary = {
                type = "group",
                name = "Primary",
                order = 1,
                args = {
                    header = {
                        type = "header",
                        name = "Primary Power Bar Settings",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable Primary Power Bar",
                        desc = "Show your main resource (mana, energy, rage, etc.)",
                        width = "full",
                        order = 2,
                        get = function() return NephUI.db.profile.powerBar.enabled end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.enabled = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    positionHeader = {
                        type = "header",
                        name = "Position & Size",
                        order = 10,
                    },
                    attachTo = {
                        type = "select",
                        name = "Attach To",
                        desc = "Which frame to attach this bar to",
                        order = 11,
                        width = "full",
                        values = function()
                            local opts = {}
                            opts["UIParent"] = "Screen (UIParent)"
                            if NephUI.db.profile.unitFrames and NephUI.db.profile.unitFrames.enabled then
                                opts["NephUI_Player"] = "Player Frame (Custom)"
                            end
                            opts["PlayerFrame"] = "Default Player Frame"
                            local viewerOpts = GetViewerOptions()
                            for k, v in pairs(viewerOpts) do
                                opts[k] = v
                            end
                            return opts
                        end,
                        get = function() return NephUI.db.profile.powerBar.attachTo end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.attachTo = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    anchorPoint = {
                        type = "select",
                        name = "Anchor Point",
                        desc = "Which point on the anchor frame to attach to",
                        order = 11.1,
                        width = "normal",
                        values = {
                            TOP = "Top",
                            CENTER = "Center",
                            BOTTOM = "Bottom",
                        },
                        get = function() return NephUI.db.profile.powerBar.anchorPoint or "CENTER" end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.anchorPoint = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    height = {
                        type = "range",
                        name = "Height",
                        order = 12,
                        width = "normal",
                        min = 2, max = 30, step = 1,
                        get = function() return NephUI.db.profile.powerBar.height end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.height = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        desc = "0 = automatic width based on icons",
                        order = 13,
                        width = "normal",
                        min = 0, max = 500, step = 1,
                        get = function() return NephUI.db.profile.powerBar.width end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.width = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    offsetY = {
                        type = "range",
                        name = "Vertical Offset",
                        desc = "Distance from the icon viewer",
                        order = 14,
                        width = "full",
                        min = -500, max = 500, step = 1,
                        get = function() return NephUI.db.profile.powerBar.offsetY end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.offsetY = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    offsetX = {
                        type = "range",
                        name = "Horizontal Offset",
                        desc = "Horizontal distance from the anchor point",
                        order = 15,
                        width = "full",
                        min = -500, max = 500, step = 1,
                        get = function() return NephUI.db.profile.powerBar.offsetX or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.offsetX = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    
                    appearanceHeader = {
                        type = "header",
                        name = "Appearance",
                        order = 20,
                    },
                    texture = {
                        type = "select",
                        name = "Bar Texture",
                        order = 21,
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
                            local override = NephUI.db.profile.powerBar.texture
                            if override and override ~= "" then
                                return override
                            end
                            -- Return global texture name when override is nil
                            return NephUI.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.texture = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    borderSize = {
                        type = "range",
                        name = "Border Size",
                        desc = "Size of the border around the resource bar",
                        order = 22,
                        width = "normal",
                        min = 0, max = 5, step = 1,
                        get = function() return NephUI.db.profile.powerBar.borderSize end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.borderSize = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = "Border Color",
                        desc = "Color of the border around the resource bar",
                        order = 23,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.powerBar.borderColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0, 0, 0, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.powerBar.borderColor = { r, g, b, a }
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    
                    colorsHeader = {
                        type = "header",
                        name = "Colors",
                        order = 25,
                    },
                    useClassColor = {
                        type = "toggle",
                        name = "Use Class Color",
                        desc = "Use your class color instead of custom color",
                        order = 26,
                        width = "normal",
                        get = function() return NephUI.db.profile.powerBar.useClassColor end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.useClassColor = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    barColor = {
                        type = "color",
                        name = "Custom Color",
                        desc = "Used when class color is disabled",
                        order = 27,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.powerBar.color
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 1, 1, 1, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.powerBar.color = { r, g, b, a }
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    bgColor = {
                        type = "color",
                        name = "Background Color",
                        desc = "Color of the bar background",
                        order = 28,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.powerBar.bgColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0.15, 0.15, 0.15, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.powerBar.bgColor = { r, g, b, a }
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    
                    displayHeader = {
                        type = "header",
                        name = "Display Options",
                        order = 30,
                    },
                    showText = {
                        type = "toggle",
                        name = "Show Resource Number",
                        desc = "Display current resource amount as text",
                        order = 31,
                        width = "normal",
                        get = function() return NephUI.db.profile.powerBar.showText end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.showText = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    showManaAsPercent = {
                        type = "toggle",
                        name = "Show Mana as Percent",
                        desc = "Display mana as percentage instead of raw value",
                        order = 32,
                        width = "normal",
                        get = function() return NephUI.db.profile.powerBar.showManaAsPercent end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.showManaAsPercent = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    showTicks = {
                        type = "toggle",
                        name = "Show Ticks",
                        desc = "Show segment markers for combo points, chi, etc.",
                        order = 33,
                        width = "normal",
                        get = function() return NephUI.db.profile.powerBar.showTicks end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.showTicks = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    hideWhenMana = {
                        type = "toggle",
                        name = "Hide Bar When Mana",
                        desc = "Hide the resource bar completely when current power is mana (prevents errors during druid shapeshifting)",
                        order = 33.5,
                        width = "normal",
                        get = function() return NephUI.db.profile.powerBar.hideWhenMana end,
                        set = function(_, val)
                            if InCombatLockdown() then
                                return
                            end
                            NephUI.db.profile.powerBar.hideWhenMana = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    hideBarShowText = {
                        type = "toggle",
                        name = "Hide Bar, Show Text Only",
                        desc = "Hide the resource bar visual but keep the text visible",
                        order = 33.6,
                        width = "normal",
                        get = function() return NephUI.db.profile.powerBar.hideBarShowText end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.hideBarShowText = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text Size",
                        order = 34,
                        width = "normal",
                        min = 6, max = 24, step = 1,
                        get = function() return NephUI.db.profile.powerBar.textSize end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.textSize = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    textX = {
                        type = "range",
                        name = "Text Horizontal Offset",
                        order = 35,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.powerBar.textX end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.textX = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                    textY = {
                        type = "range",
                        name = "Text Vertical Offset",
                        order = 36,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.powerBar.textY end,
                        set = function(_, val)
                            NephUI.db.profile.powerBar.textY = val
                            NephUI:UpdatePowerBar()
                        end,
                    },
                },
            },
            secondary = {
                type = "group",
                name = "Secondary",
                order = 2,
                args = {
                    header = {
                        type = "header",
                        name = "Secondary Power Bar Settings",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable Secondary Power Bar",
                        desc = "Show your secondary resource (combo points, chi, runes, etc.)",
                        width = "full",
                        order = 2,
                        get = function() return NephUI.db.profile.secondaryPowerBar.enabled end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.enabled = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    positionHeader = {
                        type = "header",
                        name = "Position & Size",
                        order = 10,
                    },
                    attachTo = {
                        type = "select",
                        name = "Attach To",
                        desc = "Which frame to attach this bar to",
                        order = 11,
                        width = "full",
                        values = function()
                            local opts = {}
                            opts["UIParent"] = "Screen (UIParent)"
                            if NephUI.db.profile.unitFrames and NephUI.db.profile.unitFrames.enabled then
                                opts["NephUI_Player"] = "Player Frame (Custom)"
                            end
                            opts["PlayerFrame"] = "Default Player Frame"
                            local viewerOpts = GetViewerOptions()
                            for k, v in pairs(viewerOpts) do
                                opts[k] = v
                            end
                            return opts
                        end,
                        get = function() return NephUI.db.profile.secondaryPowerBar.attachTo end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.attachTo = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    anchorPoint = {
                        type = "select",
                        name = "Anchor Point",
                        desc = "Which point on the anchor frame to attach to",
                        order = 11.1,
                        width = "normal",
                        values = {
                            TOP = "Top",
                            CENTER = "Center",
                            BOTTOM = "Bottom",
                        },
                        get = function() return NephUI.db.profile.secondaryPowerBar.anchorPoint or "CENTER" end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.anchorPoint = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    height = {
                        type = "range",
                        name = "Height",
                        order = 12,
                        width = "normal",
                        min = 2, max = 30, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.height end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.height = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        desc = "0 = automatic width based on icons",
                        order = 13,
                        width = "normal",
                        min = 0, max = 500, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.width end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.width = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    offsetY = {
                        type = "range",
                        name = "Vertical Offset",
                        desc = "Distance from the icon viewer",
                        order = 14,
                        width = "full",
                        min = -500, max = 500, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.offsetY end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.offsetY = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    offsetX = {
                        type = "range",
                        name = "Horizontal Offset",
                        desc = "Horizontal distance from the anchor point",
                        order = 15,
                        width = "full",
                        min = -500, max = 500, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.offsetX or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.offsetX = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    
                    appearanceHeader = {
                        type = "header",
                        name = "Appearance",
                        order = 20,
                    },
                    texture = {
                        type = "select",
                        name = "Bar Texture",
                        order = 21,
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
                            local override = NephUI.db.profile.secondaryPowerBar.texture
                            if override and override ~= "" then
                                return override
                            end
                            -- Return global texture name when override is nil
                            return NephUI.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.texture = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    borderSize = {
                        type = "range",
                        name = "Border Size",
                        desc = "Size of the border around the resource bar",
                        order = 22,
                        width = "normal",
                        min = 0, max = 5, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.borderSize end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.borderSize = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = "Border Color",
                        desc = "Color of the border around the resource bar",
                        order = 23,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.secondaryPowerBar.borderColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0, 0, 0, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.secondaryPowerBar.borderColor = { r, g, b, a }
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    
                    colorsHeader = {
                        type = "header",
                        name = "Colors",
                        order = 25,
                    },
                    useClassColor = {
                        type = "toggle",
                        name = "Use Class Color",
                        desc = "Use your class color instead of resource color",
                        order = 26,
                        width = "normal",
                        get = function() return NephUI.db.profile.secondaryPowerBar.useClassColor end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.useClassColor = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    barColor = {
                        type = "color",
                        name = "Custom Color",
                        desc = "Used when class color is disabled",
                        order = 27,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.secondaryPowerBar.color
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 1, 1, 1, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.secondaryPowerBar.color = { r, g, b, a }
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    bgColor = {
                        type = "color",
                        name = "Background Color",
                        desc = "Color of the bar background",
                        order = 28,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.secondaryPowerBar.bgColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0.15, 0.15, 0.15, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.secondaryPowerBar.bgColor = { r, g, b, a }
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    
                    displayHeader = {
                        type = "header",
                        name = "Display Options",
                        order = 30,
                    },
                    showText = {
                        type = "toggle",
                        name = "Show Resource Number",
                        desc = "Display current resource amount as text",
                        order = 31,
                        width = "normal",
                        get = function() return NephUI.db.profile.secondaryPowerBar.showText end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.showText = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    showTicks = {
                        type = "toggle",
                        name = "Show Ticks",
                        desc = "Show segment markers between resources",
                        order = 32,
                        width = "normal",
                        get = function() return NephUI.db.profile.secondaryPowerBar.showTicks end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.showTicks = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    hideBarShowText = {
                        type = "toggle",
                        name = "Hide Bar, Show Text Only",
                        desc = "Hide the resource bar visual but keep the text visible",
                        order = 32.5,
                        width = "normal",
                        get = function() return NephUI.db.profile.secondaryPowerBar.hideBarShowText end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.hideBarShowText = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text Size",
                        order = 33,
                        width = "normal",
                        min = 6, max = 24, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.textSize end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.textSize = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    textX = {
                        type = "range",
                        name = "Text Horizontal Offset",
                        order = 34,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.textX end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.textX = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    textY = {
                        type = "range",
                        name = "Text Vertical Offset",
                        order = 35,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.textY end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.textY = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    
                    runeTimerHeader = {
                        type = "header",
                        name = "Rune Timer Options",
                        order = 40,
                    },
                    showFragmentedPowerBarText = {
                        type = "toggle",
                        name = "Show Rune Timers",
                        desc = "Show cooldown timers on individual runes (Death Knight only)",
                        order = 41,
                        width = "normal",
                        get = function() return NephUI.db.profile.secondaryPowerBar.showFragmentedPowerBarText end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.showFragmentedPowerBarText = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    runeTimerTextSize = {
                        type = "range",
                        name = "Rune Timer Text Size",
                        desc = "Font size for the rune timer text",
                        order = 42,
                        width = "normal",
                        min = 6, max = 24, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.runeTimerTextSize end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.runeTimerTextSize = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    runeTimerTextX = {
                        type = "range",
                        name = "Rune Timer Text X Position",
                        desc = "Horizontal offset for the rune timer text",
                        order = 43,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.runeTimerTextX end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.runeTimerTextX = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                    runeTimerTextY = {
                        type = "range",
                        name = "Rune Timer Text Y Position",
                        desc = "Vertical offset for the rune timer text",
                        order = 44,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.secondaryPowerBar.runeTimerTextY end,
                        set = function(_, val)
                            NephUI.db.profile.secondaryPowerBar.runeTimerTextY = val
                            NephUI:UpdateSecondaryPowerBar()
                        end,
                    },
                },
            },
        },
    }
end

ns.CreateResourceBarOptions = CreateResourceBarOptions

