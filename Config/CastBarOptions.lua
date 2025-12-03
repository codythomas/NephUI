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

local function CreateCastBarOptions()
    return {
        type = "group",
        name = "Cast Bars",
        order = 5,
        childGroups = "tab",
        args = {
            player = {
                type = "group",
                name = "Player",
                order = 1,
                args = {
                    header = {
                        type = "header",
                        name = "Player Cast Bar Settings",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable Cast Bar",
                        desc = "Show a bar when casting or channeling spells",
                        width = "full",
                        order = 2,
                        get = function() return NephUI.db.profile.castBar.enabled end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.enabled = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    testCast = {
                        type  = "execute",
                        name  = "Test Cast Bar",
                        desc  = "Show a fake cast so you can preview and tweak the bar without casting.",
                        order = 3,
                        func  = function()
                            NephUI:ShowTestCastBar()
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
                            if NephUI.db.profile.unitFrames and NephUI.db.profile.unitFrames.enabled then
                                opts["NephUI_Player"] = "Player Frame (Custom)"
                            end
                            local viewerOpts = GetViewerOptions()
                            for k, v in pairs(viewerOpts) do
                                opts[k] = v
                            end
                            opts["UIParent"] = "Screen Center"
                            return opts
                        end,
                        get = function() return NephUI.db.profile.castBar.attachTo end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.attachTo = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    anchorPoint = {
                        type = "select",
                        name = "Anchor Point",
                        desc = "Which point of the attached frame to anchor to (moves with frame when it resizes)",
                        order = 12,
                        width = "full",
                        values = {
                            ["CENTER"] = "Center",
                            ["BOTTOM"] = "Bottom",
                            ["TOP"] = "Top",
                        },
                        get = function() return NephUI.db.profile.castBar.anchorPoint or "CENTER" end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.anchorPoint = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    height = {
                        type = "range",
                        name = "Height",
                        order = 12,
                        width = "normal",
                        min = 6,
                        max = 80,
                        step = 1,
                        get = function() return NephUI.db.profile.castBar.height end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.height = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        desc = "0 = automatic width based on icons",
                        order = 13,
                        width = "normal",
                        min = 0,
                        max = 1000,
                        step = 1,
                        get = function() return NephUI.db.profile.castBar.width end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.width = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    offsetY = {
                        type = "range",
                        name = "Vertical Offset",
                        desc = "Distance from the icon viewer",
                        order = 14,
                        width = "full",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function() return NephUI.db.profile.castBar.offsetY end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.offsetY = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    offsetX = {
                        type = "range",
                        name = "Horizontal Offset",
                        desc = "Horizontal distance from the anchor point",
                        order = 15,
                        width = "full",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function() return NephUI.db.profile.castBar.offsetX or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.offsetX = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },

                    appearanceHeader = {
                        type = "header",
                        name = "Appearance",
                        order = 20,
                    },
                    texture = {
                        type = "select",
                        name = "Texture",
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
                            local override = NephUI.db.profile.castBar.texture
                            if override and override ~= "" then
                                return override
                            end
                            -- Return global texture name when override is nil
                            return NephUI.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.texture = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    useClassColor = {
                        type = "toggle",
                        name = "Use Class Color",
                        desc = "Use your class color instead of custom color",
                        order = 22,
                        width = "normal",
                        get = function() return NephUI.db.profile.castBar.useClassColor end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.useClassColor = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    barColor = {
                        type = "color",
                        name = "Custom Color",
                        desc = "Used when class color is disabled",
                        order = 23,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.castBar.color
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 1, 0.7, 0, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.castBar.color = { r, g, b, a }
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    bgColor = {
                        type = "color",
                        name = "Background Color",
                        desc = "Color of the bar background",
                        order = 24,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.castBar.bgColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0.1, 0.1, 0.1, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.castBar.bgColor = { r, g, b, a }
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text Size",
                        order = 25,
                        width = "normal",
                        min = 6,
                        max = 20,
                        step = 1,
                        get = function() return NephUI.db.profile.castBar.textSize end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.textSize = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                    showTimeText = {
                        type = "toggle",
                        name = "Show Time Text",
                        desc = "Show the remaining cast time on the cast bar",
                        order = 26,
                        width = "normal",
                        get = function() return NephUI.db.profile.castBar.showTimeText ~= false end,
                        set = function(_, val)
                            NephUI.db.profile.castBar.showTimeText = val
                            NephUI:UpdateCastBarLayout()
                        end,
                    },
                },
            },
            target = {
                type = "group",
                name = "Target",
                order = 2,
                args = {
                    header = {
                        type = "header",
                        name = "Target Cast Bar Settings",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable Target Cast Bar",
                        desc = "Show a bar when your target is casting or channeling spells",
                        width = "full",
                        order = 2,
                        get = function() return NephUI.db.profile.targetCastBar.enabled end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.enabled = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    testCast = {
                        type  = "execute",
                        name  = "Test Target Cast Bar",
                        desc  =
                        "Show a fake cast so you can preview and tweak the bar without a target casting. Unit Must Be active to test.",
                        order = 3,
                        func  = function()
                            NephUI:ShowTestTargetCastBar()
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
                            if NephUI.db.profile.unitFrames and NephUI.db.profile.unitFrames.enabled then
                                opts["NephUI_Target"] = "Target Frame (Custom)"
                            end
                            local viewerOpts = GetViewerOptions()
                            for k, v in pairs(viewerOpts) do
                                opts[k] = v
                            end
                            opts["TargetFrame"] = "Default Target Frame"
                            opts["UIParent"] = "Screen Center"
                            return opts
                        end,
                        get = function() return NephUI.db.profile.targetCastBar.attachTo end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.attachTo = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    anchorPoint = {
                        type = "select",
                        name = "Anchor Point",
                        desc = "Which point of the attached frame to anchor to (moves with frame when it resizes)",
                        order = 12,
                        width = "full",
                        values = {
                            ["CENTER"] = "Center",
                            ["BOTTOM"] = "Bottom",
                            ["TOP"] = "Top",
                        },
                        get = function() return NephUI.db.profile.targetCastBar.anchorPoint or "CENTER" end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.anchorPoint = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    height = {
                        type = "range",
                        name = "Height",
                        order = 12,
                        width = "normal",
                        min = 6,
                        max = 80,
                        step = 1,
                        get = function() return NephUI.db.profile.targetCastBar.height end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.height = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        desc = "0 = automatic width based on anchor",
                        order = 13,
                        width = "normal",
                        min = 0,
                        max = 1000,
                        step = 1,
                        get = function() return NephUI.db.profile.targetCastBar.width end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.width = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    offsetY = {
                        type = "range",
                        name = "Vertical Offset",
                        desc = "Distance from the anchor frame",
                        order = 14,
                        width = "full",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function() return NephUI.db.profile.targetCastBar.offsetY end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.offsetY = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    offsetX = {
                        type = "range",
                        name = "Horizontal Offset",
                        desc = "Horizontal distance from the anchor point",
                        order = 15,
                        width = "full",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function() return NephUI.db.profile.targetCastBar.offsetX or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.offsetX = val
                            NephUI:UpdateTargetCastBarLayout()
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
                            local override = NephUI.db.profile.targetCastBar.texture
                            if override and override ~= "" then
                                return override
                            end
                            -- Return global texture name when override is nil
                            return NephUI.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.texture = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    barColor = {
                        type = "color",
                        name = "Custom Color",
                        desc = "Color of the cast bar",
                        order = 22,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.targetCastBar.color
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 1, 0, 0, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.targetCastBar.color = { r, g, b, a }
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    bgColor = {
                        type = "color",
                        name = "Background Color",
                        desc = "Color of the bar background",
                        order = 23,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.targetCastBar.bgColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0.1, 0.1, 0.1, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.targetCastBar.bgColor = { r, g, b, a }
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text Size",
                        order = 24,
                        width = "normal",
                        min = 6,
                        max = 20,
                        step = 1,
                        get = function() return NephUI.db.profile.targetCastBar.textSize end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.textSize = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                    showTimeText = {
                        type = "toggle",
                        name = "Show Time Text",
                        desc = "Show the remaining cast time on the cast bar",
                        order = 25,
                        width = "normal",
                        get = function() return NephUI.db.profile.targetCastBar.showTimeText ~= false end,
                        set = function(_, val)
                            NephUI.db.profile.targetCastBar.showTimeText = val
                            NephUI:UpdateTargetCastBarLayout()
                        end,
                    },
                },
            },
            focus = {
                type = "group",
                name = "Focus",
                order = 3,
                args = {
                    header = {
                        type = "header",
                        name = "Focus Cast Bar Settings",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable Focus Cast Bar",
                        desc = "Show a bar when your focus is casting or channeling spells",
                        width = "full",
                        order = 2,
                        get = function() return NephUI.db.profile.focusCastBar.enabled end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.enabled = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    testCast = {
                        type  = "execute",
                        name  = "Test Focus Cast Bar",
                        desc  =
                        "Show a fake cast so you can preview and tweak the bar without a focus casting. Unit Must Be active to test.",
                        order = 3,
                        func  = function()
                            NephUI:ShowTestFocusCastBar()
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
                            if NephUI.db.profile.unitFrames and NephUI.db.profile.unitFrames.enabled then
                                opts["NephUI_Focus"] = "Focus Frame (Custom)"
                            end
                            local viewerOpts = GetViewerOptions()
                            for k, v in pairs(viewerOpts) do
                                opts[k] = v
                            end
                            opts["FocusFrame"] = "Default Focus Frame"
                            opts["UIParent"] = "Screen Center"
                            return opts
                        end,
                        get = function() return NephUI.db.profile.focusCastBar.attachTo end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.attachTo = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    anchorPoint = {
                        type = "select",
                        name = "Anchor Point",
                        desc = "Which point of the attached frame to anchor to (moves with frame when it resizes)",
                        order = 12,
                        width = "full",
                        values = {
                            ["CENTER"] = "Center",
                            ["BOTTOM"] = "Bottom",
                            ["TOP"] = "Top",
                        },
                        get = function() return NephUI.db.profile.focusCastBar.anchorPoint or "CENTER" end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.anchorPoint = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    height = {
                        type = "range",
                        name = "Height",
                        order = 12,
                        width = "normal",
                        min = 6,
                        max = 80,
                        step = 1,
                        get = function() return NephUI.db.profile.focusCastBar.height end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.height = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        desc = "0 = automatic width based on anchor",
                        order = 13,
                        width = "normal",
                        min = 0,
                        max = 1000,
                        step = 1,
                        get = function() return NephUI.db.profile.focusCastBar.width end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.width = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    offsetY = {
                        type = "range",
                        name = "Vertical Offset",
                        desc = "Distance from the anchor frame",
                        order = 14,
                        width = "full",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function() return NephUI.db.profile.focusCastBar.offsetY end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.offsetY = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    offsetX = {
                        type = "range",
                        name = "Horizontal Offset",
                        desc = "Horizontal distance from the anchor point",
                        order = 15,
                        width = "full",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function() return NephUI.db.profile.focusCastBar.offsetX or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.offsetX = val
                            NephUI:UpdateFocusCastBarLayout()
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
                            local override = NephUI.db.profile.focusCastBar.texture
                            if override and override ~= "" then
                                return override
                            end
                            -- Return global texture name when override is nil
                            return NephUI.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.texture = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    barColor = {
                        type = "color",
                        name = "Custom Color",
                        desc = "Color of the cast bar",
                        order = 22,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.focusCastBar.color
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 1, 0, 0, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.focusCastBar.color = { r, g, b, a }
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    bgColor = {
                        type = "color",
                        name = "Background Color",
                        desc = "Color of the bar background",
                        order = 23,
                        width = "normal",
                        hasAlpha = true,
                        get = function()
                            local c = NephUI.db.profile.focusCastBar.bgColor
                            if c then
                                return c[1], c[2], c[3], c[4] or 1
                            end
                            return 0.1, 0.1, 0.1, 1
                        end,
                        set = function(_, r, g, b, a)
                            NephUI.db.profile.focusCastBar.bgColor = { r, g, b, a }
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    textSize = {
                        type = "range",
                        name = "Text Size",
                        order = 24,
                        width = "normal",
                        min = 6,
                        max = 20,
                        step = 1,
                        get = function() return NephUI.db.profile.focusCastBar.textSize end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.textSize = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                    showTimeText = {
                        type = "toggle",
                        name = "Show Time Text",
                        desc = "Show the remaining cast time on the cast bar",
                        order = 25,
                        width = "normal",
                        get = function() return NephUI.db.profile.focusCastBar.showTimeText ~= false end,
                        set = function(_, val)
                            NephUI.db.profile.focusCastBar.showTimeText = val
                            NephUI:UpdateFocusCastBarLayout()
                        end,
                    },
                },
            },
        },
    }
end

ns.CreateCastBarOptions = CreateCastBarOptions
