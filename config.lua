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

local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local importBuffer = ""

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

-- Generate dynamic entries for tracked items list
local function GetTrackedItemsEntries()
    local entries = {}
    local db = NephUI.db.profile.customIcons
    
    if db and db.trackedItems then
        for i, itemID in ipairs(db.trackedItems) do
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
                  itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
            
            local displayName = itemName or ("Item " .. itemID)
            local iconTexture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
            
            -- Create entry for this item: Icon - Name - ID - Remove button
            entries["item_" .. itemID] = {
                type = "group",
                name = function()
                    -- Format: Icon - Name - ID
                    local iconStr = "|T" .. iconTexture .. ":16:16:0:0:64:64:4:60:4:60|t"
                    return string.format("%s %s (ID: %d)", iconStr, displayName, itemID)
                end,
                order = 10 + i,  -- Start at order 10, increment by 1
                inline = true,
                args = {
                    itemDisplay = {
                        type = "description",
                        name = function()
                            local iconStr = "|T" .. iconTexture .. ":20:20:0:0:64:64:4:60:4:60|t"
                            return string.format("%s |cffffffff%s|r |cff808080(ID: %d)|r", iconStr, displayName, itemID)
                        end,
                        order = 1,
                        width = "double",
                    },
                    removeButton = {
                        type = "execute",
                        name = "Remove",
                        desc = "Remove this item from tracking",
                        order = 2,
                        width = "half",
                        func = function()
                            if NephUI:RemoveCustomItem(itemID) then
                                local itemName = GetItemInfo(itemID) or displayName
                                print("|cff00ff00[NephUI] Removed " .. itemName .. " from Custom Icons tracker|r")
                                -- RebuildTrackedItemsList is called in RemoveCustomItem, which will refresh the UI
                            else
                                print("|cffff0000[NephUI] Failed to remove item|r")
                            end
                        end,
                    },
                },
            }
        end
    end
    
    return entries
end

-- Helper function to create viewer option groups
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
                desc = "Show/hide this icon viewer",
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
                        min = 16, max = 96, step = 0.1,
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
                            -- Also store as string format for backwards compatibility
                            -- Round to nearest common ratio or use exact value
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
                        disabled = function()
                            return viewerKey ~= "BuffIconCooldownViewer"
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
                -- Try to find the frame by its actual name (CooldownViewerSettings)
                local frame = _G["CooldownViewerSettings"]
                if frame then
                    frame:Show()
                    frame:Raise()
                else
                    -- Use AceConfigDialog to open/create the frame
                    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                    AceConfigDialog:Open(ADDON_NAME)
                    -- Wait a moment for frame to be created, then show it
                    C_Timer.After(0.05, function()
                        local frame = _G["CooldownViewerSettings"] or (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[ADDON_NAME])
                        if frame then
                            frame:Show()
                            frame:Raise()
                        end
                    end)
                end
            end,
        }
    end
    
    return ret
end

-- Anchor points for positioning
local AnchorPoints = {
    ["TOPLEFT"] = "Top Left",
    ["TOP"] = "Top",
    ["TOPRIGHT"] = "Top Right",
    ["LEFT"] = "Left",
    ["CENTER"] = "Center",
    ["RIGHT"] = "Right",
    ["BOTTOMLEFT"] = "Bottom Left",
    ["BOTTOM"] = "Bottom",
    ["BOTTOMRIGHT"] = "Bottom Right",
}

-- Helper to get unit frame DB
local function GetUnitDB(unit)
    local dbUnit = unit
    if unit:match("^boss(%d+)$") then dbUnit = "boss" end
    
    if not NephUI.db.profile.unitFrames then
        NephUI.db.profile.unitFrames = {}
    end
    if not NephUI.db.profile.unitFrames[dbUnit] then
        NephUI.db.profile.unitFrames[dbUnit] = {}
    end
    return NephUI.db.profile.unitFrames[dbUnit]
end

-- Helper to update unit frame
local function UpdateUnitFrame(unit)
    if NephUI.UnitFrames then
        -- Resolve media first in case textures changed
        NephUI.UnitFrames:ResolveMedia()
        
        -- For boss frames, update all boss frames (boss1-boss5)
        if unit == "boss" then
            for i = 1, 5 do
                NephUI.UnitFrames:UpdateUnitFrame("boss" .. i)
            end
        else
            -- Update the specific unit frame
            NephUI.UnitFrames:UpdateUnitFrame(unit)
        end
    end
end

-- Helper to create unit frame options per frame
local function CreateUnitFrameOptions(unit, displayName, order)
    local unitKey = unit:gsub("^%l", string.upper) -- Capitalize first letter
    local hasPowerBar = (unit == "player" or unit == "target" or unit == "focus")
    
    -- Helper to create Colors tab
    local function CreateColorsTab()
        local DB = GetUnitDB(unit)
        if not DB.Frame then DB.Frame = {} end
        
        return {
            type = "group",
            name = "Colors",
            order = 1,
            args = {
                useClassColor = {
                    type = "toggle",
                    name = "Use Class Color",
                    desc = "Color health bar by class color",
                    order = 1,
                    width = "normal",
                    get = function()
                        return DB.Frame.ClassColor or false
                    end,
                    set = function(_, val)
                        DB.Frame.ClassColor = val
                        UpdateUnitFrame(unit)
                    end,
                },
                fgColor = {
                    type = "color",
                    name = "Foreground Color",
                    desc = "Health bar foreground color",
                    order = 2,
                    width = "normal",
                    hasAlpha = true,
                    get = function()
                        local c = DB.Frame.FGColor or {26/255, 26/255, 26/255, 1.0}
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                        DB.Frame.FGColor = {r, g, b, a or 1}
                        UpdateUnitFrame(unit)
                    end,
                },
                useReactionColor = {
                    type = "toggle",
                    name = "Use Reaction Color",
                    desc = "Color health bar by reaction (hostile/neutral/friendly)",
                    order = 3,
                    width = "normal",
                    get = function()
                        return DB.Frame.ReactionColor or false
                    end,
                    set = function(_, val)
                        DB.Frame.ReactionColor = val
                        UpdateUnitFrame(unit)
                    end,
                },
                bgColor = {
                    type = "color",
                    name = "Background Color",
                    desc = "Health bar background color",
                    order = 4,
                    width = "normal",
                    hasAlpha = true,
                    get = function()
                        local c = DB.Frame.BGColor or {128/255, 128/255, 128/255, 1.0}
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                        DB.Frame.BGColor = {r, g, b, a or 1}
                        UpdateUnitFrame(unit)
                    end,
                },
            },
        }
    end
    
    -- Helper to create Frame tab
    local function CreateFrameTab()
        local DB = GetUnitDB(unit)
        if not DB.Frame then DB.Frame = {} end
        
        return {
            type = "group",
            name = "Frame",
            order = 2,
            args = {
                width = {
                    type = "range",
                    name = "Width",
                    desc = "Frame width",
                    order = 1,
                    width = "full",
                    min = 50, max = 1000, step = 1,
                    get = function()
                        return DB.Frame.Width or 244
                    end,
                    set = function(_, val)
                        DB.Frame.Width = val
                        UpdateUnitFrame(unit)
                    end,
                },
                height = {
                    type = "range",
                    name = "Height",
                    desc = "Frame height",
                    order = 2,
                    width = "full",
                    min = 10, max = 500, step = 1,
                    get = function()
                        return DB.Frame.Height or 42
                    end,
                    set = function(_, val)
                        DB.Frame.Height = val
                        UpdateUnitFrame(unit)
                    end,
                },
                anchorToCooldown = {
                    type = "toggle",
                    name = "Anchor to Essential Cooldown Viewer",
                    desc = "Automatically anchor this frame to EssentialCooldownViewer. Only available for Player and Target frames.",
                    order = 3,
                    width = "full",
                    disabled = function()
                        -- Only enable for player and target
                        return unit ~= "player" and unit ~= "target"
                    end,
                    get = function()
                        return DB.Frame.AnchorToCooldown or false
                    end,
                    set = function(_, val)
                        DB.Frame.AnchorToCooldown = val
                        
                        -- Update anchor frame based on toggle
                        if val then
                            DB.Frame.AnchorFrame = "EssentialCooldownViewer"
                        end
                        
                        UpdateUnitFrame(unit)
                        -- Re-hook anchor frames after change
                        if NephUI.UnitFrames then
                            C_Timer.After(0.1, function()
                                NephUI.UnitFrames:HookAnchorFrames()
                            end)
                        end
                    end,
                },
                anchorFrame = {
                    type = "input",
                    name = "Anchor Frame",
                    desc = "Frame name to anchor to (e.g., EssentialCooldownViewer, NephUI_Player, NephUI_Target, UIParent)",
                    order = 4,
                    width = "full",
                    disabled = function()
                        return DB.Frame.AnchorToCooldown or false
                    end,
                    get = function()
                        return DB.Frame.AnchorFrame or "UIParent"
                    end,
                    set = function(_, val)
                        DB.Frame.AnchorFrame = val
                        UpdateUnitFrame(unit)
                        -- Re-hook anchor frames after change
                        if NephUI.UnitFrames then
                            C_Timer.After(0.1, function()
                                NephUI.UnitFrames:HookAnchorFrames()
                            end)
                        end
                    end,
                },
                anchorFrom = {
                    type = "select",
                    name = "Anchor From",
                    desc = "Anchor point on the frame",
                    order = 4,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        return DB.Frame.AnchorFrom or "CENTER"
                    end,
                    set = function(_, val)
                        DB.Frame.AnchorFrom = val
                        UpdateUnitFrame(unit)
                    end,
                },
                anchorTo = {
                    type = "select",
                    name = "Anchor To",
                    desc = "Anchor point on parent",
                    order = 5,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        return DB.Frame.AnchorTo or "CENTER"
                    end,
                    set = function(_, val)
                        DB.Frame.AnchorTo = val
                        UpdateUnitFrame(unit)
                    end,
                },
                offsetX = {
                    type = "range",
                    name = "X Offset",
                    desc = "Horizontal offset from anchor",
                    order = 6,
                    width = "normal",
                    min = -1000, max = 1000, step = 1,
                    get = function()
                        return DB.Frame.OffsetX or 0
                    end,
                    set = function(_, val)
                        DB.Frame.OffsetX = val
                        UpdateUnitFrame(unit)
                    end,
                },
                offsetY = {
                    type = "range",
                    name = "Y Offset",
                    desc = "Vertical offset from anchor",
                    order = 7,
                    width = "normal",
                    min = -1000, max = 1000, step = 1,
                    get = function()
                        return DB.Frame.OffsetY or 0
                    end,
                    set = function(_, val)
                        DB.Frame.OffsetY = val
                        UpdateUnitFrame(unit)
                    end,
                },
            },
        }
    end
    
    -- Helper to create Power Bar tab
    local function CreatePowerBarTab()
        if not hasPowerBar then return nil end
        local DB = GetUnitDB(unit)
        if not DB.PowerBar then DB.PowerBar = {} end
        
        return {
            type = "group",
            name = "Power Bar",
            order = 3,
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enable Power Bar",
                    desc = "Show the power bar (mana/energy/rage)",
                    order = 1,
                    width = "full",
                    get = function()
                        return DB.PowerBar.Enabled ~= false
                    end,
                    set = function(_, val)
                        DB.PowerBar.Enabled = val
                        UpdateUnitFrame(unit)
                    end,
                },
                height = {
                    type = "range",
                    name = "Power Bar Height",
                    desc = "Height of the power bar",
                    order = 2,
                    width = "full",
                    min = 1, max = 100, step = 1,
                    get = function()
                        return DB.PowerBar.Height or 3
                    end,
                    set = function(_, val)
                        DB.PowerBar.Height = val
                        UpdateUnitFrame(unit)
                    end,
                },
                colorByType = {
                    type = "toggle",
                    name = "Color By Power Type",
                    desc = "Use default colors for power type (mana=blue, energy=yellow, etc.)",
                    order = 3,
                    width = "normal",
                    get = function()
                        return DB.PowerBar.ColorByType ~= false
                    end,
                    set = function(_, val)
                        DB.PowerBar.ColorByType = val
                        UpdateUnitFrame(unit)
                    end,
                },
                fgColor = {
                    type = "color",
                    name = "Foreground Color",
                    desc = "Power bar foreground color",
                    order = 4,
                    width = "normal",
                    hasAlpha = true,
                    disabled = function() return DB.PowerBar.ColorByType ~= false end,
                    get = function()
                        local c = DB.PowerBar.FGColor or {8/255, 8/255, 8/255, 0.8}
                        return c[1], c[2], c[3], c[4] or 0.8
                    end,
                    set = function(_, r, g, b, a)
                        DB.PowerBar.FGColor = {r, g, b, a or 0.8}
                        UpdateUnitFrame(unit)
                    end,
                },
                colorBackgroundByType = {
                    type = "toggle",
                    name = "Color Background By Power Type",
                    desc = "Use power type color for background",
                    order = 5,
                    width = "normal",
                    get = function()
                        return DB.PowerBar.ColorBackgroundByType or false
                    end,
                    set = function(_, val)
                        DB.PowerBar.ColorBackgroundByType = val
                        UpdateUnitFrame(unit)
                    end,
                },
                bgColor = {
                    type = "color",
                    name = "Background Color",
                    desc = "Power bar background color",
                    order = 6,
                    width = "normal",
                    hasAlpha = true,
                    get = function()
                        local c = DB.PowerBar.BGColor or {128/255, 128/255, 128/255, 1}
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                        DB.PowerBar.BGColor = {r, g, b, a or 1}
                        UpdateUnitFrame(unit)
                    end,
                },
            },
        }
    end
    
    -- Helper to create Texts tab
    local function CreateTextsTab()
        local DB = GetUnitDB(unit)
        if not DB.Tags then DB.Tags = {} end
        if not DB.Tags.Name then DB.Tags.Name = {} end
        if not DB.Tags.Health then DB.Tags.Health = {} end
        
        return {
            type = "group",
            name = "Texts",
            order = 4,
            args = {
                -- Name Tag
                nameHeader = {
                    type = "header",
                    name = "Name Tag",
                    order = 10,
                },
                nameEnabled = {
                    type = "toggle",
                    name = "Enable Name",
                    desc = "Show unit name",
                    order = 11,
                    width = "full",
                    get = function()
                        return DB.Tags.Name.Enabled ~= false
                    end,
                    set = function(_, val)
                        DB.Tags.Name.Enabled = val
                        UpdateUnitFrame(unit)
                    end,
                },
                nameColorByStatus = {
                    type = "toggle",
                    name = "Color By Status",
                    desc = "Color name by class (player) or reaction (NPC)",
                    order = 12,
                    width = "normal",
                    get = function()
                        return DB.Tags.Name.ColorByStatus or false
                    end,
                    set = function(_, val)
                        DB.Tags.Name.ColorByStatus = val
                        UpdateUnitFrame(unit)
                    end,
                },
                nameColor = {
                    type = "color",
                    name = "Name Color",
                    desc = "Custom name text color",
                    order = 13,
                    width = "normal",
                    hasAlpha = true,
                    get = function()
                        local c = DB.Tags.Name.Color or {1, 1, 1, 1}
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                        DB.Tags.Name.Color = {r, g, b, a or 1}
                        UpdateUnitFrame(unit)
                    end,
                },
                nameAnchorFrom = {
                    type = "select",
                    name = "Name Anchor From",
                    order = 14,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        return DB.Tags.Name.AnchorFrom or "LEFT"
                    end,
                    set = function(_, val)
                        DB.Tags.Name.AnchorFrom = val
                        UpdateUnitFrame(unit)
                    end,
                },
                nameAnchorTo = {
                    type = "select",
                    name = "Name Anchor To",
                    order = 15,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        return DB.Tags.Name.AnchorTo or "LEFT"
                    end,
                    set = function(_, val)
                        DB.Tags.Name.AnchorTo = val
                        UpdateUnitFrame(unit)
                    end,
                },
                nameOffsetX = {
                    type = "range",
                    name = "Name Offset X",
                    order = 16,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        return DB.Tags.Name.OffsetX or 3
                    end,
                    set = function(_, val)
                        DB.Tags.Name.OffsetX = val
                        UpdateUnitFrame(unit)
                    end,
                },
                nameOffsetY = {
                    type = "range",
                    name = "Name Offset Y",
                    order = 17,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        return DB.Tags.Name.OffsetY or 0
                    end,
                    set = function(_, val)
                        DB.Tags.Name.OffsetY = val
                        UpdateUnitFrame(unit)
                    end,
                },
                nameFontSize = {
                    type = "range",
                    name = "Name Font Size",
                    order = 18,
                    width = "full",
                    min = 6, max = 72, step = 1,
                    get = function()
                        return DB.Tags.Name.FontSize or 12
                    end,
                    set = function(_, val)
                        DB.Tags.Name.FontSize = val
                        UpdateUnitFrame(unit)
                    end,
                },
                -- Health Tag
                healthHeader = {
                    type = "header",
                    name = "Health Tag",
                    order = 20,
                },
                healthEnabled = {
                    type = "toggle",
                    name = "Enable Health Tag",
                    desc = "Show health text",
                    order = 21,
                    width = "full",
                    get = function()
                        return DB.Tags.Health.Enabled ~= false
                    end,
                    set = function(_, val)
                        DB.Tags.Health.Enabled = val
                        UpdateUnitFrame(unit)
                    end,
                },
                healthDisplayStyle = {
                    type = "select",
                    name = "Health Display Style",
                    desc = "Choose how health text is displayed",
                    order = 22,
                    width = "normal",
                    values = {
                        both = "Current amount - Percent amount",
                        both_reverse = "Percent amount - Current amount",
                        current = "Current amount ONLY",
                        percent = "Percent amount ONLY",
                    },
                    get = function()
                        local style = DB.Tags.Health.DisplayStyle
                        -- Migrate old DisplayPercent setting
                        if style == nil then
                            if DB.Tags.Health.DisplayPercent then
                                return "both"
                            else
                                return "current"
                            end
                        end
                        return style or "current"
                    end,
                    set = function(_, val)
                        DB.Tags.Health.DisplayStyle = val
                        -- Keep DisplayPercent for backwards compatibility, but it's now controlled by DisplayStyle
                        DB.Tags.Health.DisplayPercent = (val == "both" or val == "both_reverse" or val == "percent")
                        UpdateUnitFrame(unit)
                    end,
                },
                healthColor = {
                    type = "color",
                    name = "Health Color",
                    desc = "Health text color",
                    order = 23,
                    width = "normal",
                    hasAlpha = true,
                    get = function()
                        local c = DB.Tags.Health.Color or {1, 1, 1, 1}
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                        DB.Tags.Health.Color = {r, g, b, a or 1}
                        UpdateUnitFrame(unit)
                    end,
                },
                healthAnchorFrom = {
                    type = "select",
                    name = "Health Anchor From",
                    order = 24,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        return DB.Tags.Health.AnchorFrom or "RIGHT"
                    end,
                    set = function(_, val)
                        DB.Tags.Health.AnchorFrom = val
                        UpdateUnitFrame(unit)
                    end,
                },
                healthAnchorTo = {
                    type = "select",
                    name = "Health Anchor To",
                    order = 25,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        return DB.Tags.Health.AnchorTo or "RIGHT"
                    end,
                    set = function(_, val)
                        DB.Tags.Health.AnchorTo = val
                        UpdateUnitFrame(unit)
                    end,
                },
                healthOffsetX = {
                    type = "range",
                    name = "Health Offset X",
                    order = 26,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        return DB.Tags.Health.OffsetX or -3
                    end,
                    set = function(_, val)
                        DB.Tags.Health.OffsetX = val
                        UpdateUnitFrame(unit)
                    end,
                },
                healthOffsetY = {
                    type = "range",
                    name = "Health Offset Y",
                    order = 27,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        return DB.Tags.Health.OffsetY or 0
                    end,
                    set = function(_, val)
                        DB.Tags.Health.OffsetY = val
                        UpdateUnitFrame(unit)
                    end,
                },
                healthFontSize = {
                    type = "range",
                    name = "Health Font Size",
                    order = 28,
                    width = "full",
                    min = 6, max = 72, step = 1,
                    get = function()
                        return DB.Tags.Health.FontSize or 12
                    end,
                    set = function(_, val)
                        DB.Tags.Health.FontSize = val
                        UpdateUnitFrame(unit)
                    end,
                },
                -- Power Text (for player, target, focus, boss)
                powerHeader = {
                    type = "header",
                    name = "Power Text",
                    order = 30,
                },
                powerEnabled = {
                    type = "toggle",
                    name = "Enable Power Text",
                    desc = "Show power/resource text (mana, energy, etc.)",
                    order = 31,
                    width = "full",
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        return DB.Tags.Power.Enabled ~= false
                    end,
                    set = function(_, val)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.Enabled = val
                        UpdateUnitFrame(unit)
                    end,
                },
                powerColor = {
                    type = "color",
                    name = "Power Color",
                    desc = "Power text color",
                    order = 32,
                    width = "normal",
                    hasAlpha = true,
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        local c = DB.Tags.Power.Color or DB.Tags.Health.Color or {1, 1, 1, 1}
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.Color = {r, g, b, a or 1}
                        UpdateUnitFrame(unit)
                    end,
                },
                powerAnchorFrom = {
                    type = "select",
                    name = "Power Anchor From",
                    order = 33,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        return DB.Tags.Power.AnchorFrom or "BOTTOMRIGHT"
                    end,
                    set = function(_, val)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.AnchorFrom = val
                        UpdateUnitFrame(unit)
                    end,
                },
                powerAnchorTo = {
                    type = "select",
                    name = "Power Anchor To",
                    order = 34,
                    width = "normal",
                    values = AnchorPoints,
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        return DB.Tags.Power.AnchorTo or "BOTTOMRIGHT"
                    end,
                    set = function(_, val)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.AnchorTo = val
                        UpdateUnitFrame(unit)
                    end,
                },
                powerOffsetX = {
                    type = "range",
                    name = "Power Offset X",
                    order = 35,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        return DB.Tags.Power.OffsetX or -4
                    end,
                    set = function(_, val)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.OffsetX = val
                        UpdateUnitFrame(unit)
                    end,
                },
                powerOffsetY = {
                    type = "range",
                    name = "Power Offset Y",
                    order = 36,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        return DB.Tags.Power.OffsetY or 4
                    end,
                    set = function(_, val)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.OffsetY = val
                        UpdateUnitFrame(unit)
                    end,
                },
                powerFontSize = {
                    type = "range",
                    name = "Power Font Size",
                    order = 37,
                    width = "full",
                    min = 6, max = 72, step = 1,
                    get = function()
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        return DB.Tags.Power.FontSize or DB.Tags.Health.FontSize or 12
                    end,
                    set = function(_, val)
                        if not DB.Tags then DB.Tags = {} end
                        if not DB.Tags.Power then DB.Tags.Power = {} end
                        DB.Tags.Power.FontSize = val
                        UpdateUnitFrame(unit)
                    end,
                },
            },
        }
    end
    
    -- Helper to create Auras tab (only for target)
    local function CreateAurasTab()
        local DB = GetUnitDB(unit)
        if not DB.Auras then DB.Auras = {} end
        
        return {
            type = "group",
            name = "Auras",
            order = 4,
            args = {
                header = {
                    type = "header",
                    name = "Target Aura Display Settings",
                    order = 1,
                },
                width = {
                    type = "range",
                    name = "Aura Bar Width",
                    desc = "Width of the aura display area (0 = use frame width)",
                    order = 2,
                    width = "full",
                    min = 0, max = 1000, step = 1,
                    get = function()
                        return DB.Auras.Width or 0
                    end,
                    set = function(_, val)
                        DB.Auras.Width = val
                        UpdateUnitFrame(unit)
                    end,
                },
                height = {
                    type = "range",
                    name = "Aura Bar Height",
                    desc = "Height of each aura icon row (0 = use frame height)",
                    order = 3,
                    width = "full",
                    min = 0, max = 100, step = 1,
                    get = function()
                        return DB.Auras.Height or 18
                    end,
                    set = function(_, val)
                        DB.Auras.Height = val
                        UpdateUnitFrame(unit)
                    end,
                },
                scale = {
                    type = "range",
                    name = "Aura Scale",
                    desc = "Scale multiplier for aura icons",
                    order = 4,
                    width = "full",
                    min = 0.1, max = 3, step = 0.1,
                    get = function()
                        return DB.Auras.Scale or 1
                    end,
                    set = function(_, val)
                        DB.Auras.Scale = val
                        UpdateUnitFrame(unit)
                    end,
                },
                alpha = {
                    type = "range",
                    name = "Aura Alpha",
                    desc = "Transparency of aura icons",
                    order = 5,
                    width = "full",
                    min = 0, max = 1, step = 0.1,
                    get = function()
                        return DB.Auras.Alpha or 1
                    end,
                    set = function(_, val)
                        DB.Auras.Alpha = val
                        UpdateUnitFrame(unit)
                    end,
                },
                rowLimit = {
                    type = "range",
                    name = "Row Limit",
                    desc = "Maximum number of rows to display (0 = unlimited)",
                    order = 6,
                    width = "full",
                    min = 0, max = 10, step = 1,
                    get = function()
                        return DB.Auras.RowLimit or 0
                    end,
                    set = function(_, val)
                        DB.Auras.RowLimit = val
                        UpdateUnitFrame(unit)
                    end,
                },
                offsetX = {
                    type = "range",
                    name = "Aura Offset X",
                    desc = "Horizontal offset from frame",
                    order = 7,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        return DB.Auras.OffsetX or 0
                    end,
                    set = function(_, val)
                        DB.Auras.OffsetX = val
                        UpdateUnitFrame(unit)
                    end,
                },
                offsetY = {
                    type = "range",
                    name = "Aura Offset Y",
                    desc = "Vertical offset from frame top",
                    order = 8,
                    width = "normal",
                    min = -1000, max = 1000, step = 0.1,
                    get = function()
                        return DB.Auras.OffsetY or 2
                    end,
                    set = function(_, val)
                        DB.Auras.OffsetY = val
                        UpdateUnitFrame(unit)
                    end,
                },
                showBuffs = {
                    type = "toggle",
                    name = "Show Buffs",
                    desc = "Display helpful buffs",
                    order = 9,
                    width = "normal",
                    get = function()
                        return DB.Auras.ShowBuffs ~= false
                    end,
                    set = function(_, val)
                        DB.Auras.ShowBuffs = val
                        UpdateUnitFrame(unit)
                    end,
                },
                showDebuffs = {
                    type = "toggle",
                    name = "Show Debuffs",
                    desc = "Display harmful debuffs",
                    order = 10,
                    width = "normal",
                    get = function()
                        return DB.Auras.ShowDebuffs ~= false
                    end,
                    set = function(_, val)
                        DB.Auras.ShowDebuffs = val
                        UpdateUnitFrame(unit)
                    end,
                },
            },
        }
    end
    
    -- Main unit frame group with tabs
    local tabs = {
        Colors = CreateColorsTab(),
        frame = CreateFrameTab(),
        texts = CreateTextsTab(),
    }
    
    if hasPowerBar then
        tabs.powerBar = CreatePowerBarTab()
    end
    
    -- Add Auras tab for target frame
    if unit == "target" then
        tabs.auras = CreateAurasTab()
    end
    
    -- Add enabled toggle at the top
    tabs.enabled = {
        type = "toggle",
        name = "Enable " .. displayName,
        desc = "Show/hide this unit frame",
        order = 0,
        width = "full",
        get = function()
            local DB = GetUnitDB(unit)
            return DB.Enabled ~= false
        end,
        set = function(_, val)
            local DB = GetUnitDB(unit)
            DB.Enabled = val
            UpdateUnitFrame(unit)
        end,
    }
    
    return {
        type = "group",
        name = displayName,
        order = order,
        childGroups = "tab",
        args = tabs,
    }
end

function NephUI:SetupOptions()
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
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
                    header = {
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
                        values = LSM:HashTable("statusbar"),
                        get = function()
                            return self.db.profile.general.globalTexture or "Neph"
                        end,
                        set = function(_, val)
                            self.db.profile.general.globalTexture = val
                            if self.RefreshAll then
                                self:RefreshAll()
                            end
                        end,
                    },
                    
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 19,
                    },
                    
                    -- Global Font
                    globalFont = {
                        type = "select",
                        name = "Global Font",
                        desc = "Font used globally across all UI elements",
                        order = 20,
                        width = "full",
                        values = LSM:HashTable("font"),
                        get = function()
                            return self.db.profile.general.globalFont or "EXPRESSWAY"
                        end,
                        set = function(_, val)
                            self.db.profile.general.globalFont = val
                            if self.RefreshAll then
                                self:RefreshAll()
                            end
                        end,
                    },
                    
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 29,
                    },
                    
                    -- UI Scale Group
                    uiScaleGroup = {
                        type = "group",
                        name = "UI Scale",
                        inline = true,
                        order = 30,
                        args = {
                            uiScale = {
                                type = "range",
                                name = "UI Scale",
                                desc = "Adjust the overall UI scale",
                                order = 1,
                                width = "normal",
                                min = 0.35,
                                max = 1.0,
                                step = 0.01,
                                get = function()
                                    local scale = self.db.profile.general.uiScale
                                    if not scale or scale == 0 then
                                        scale = UIParent:GetScale()
                                        self.db.profile.general.uiScale = scale
                                    end
                                    return scale
                                end,
                                set = function(_, val)
                                    self.db.profile.general.uiScale = val
                                    UIParent:SetScale(val)
                                end,
                            },
                            
                            scale1440p = {
                                type = "execute",
                                name = "Auto Scale for 1440p",
                                desc = "Set UI scale to 0.5333333 for 1440p resolution",
                                order = 2,
                                width = "normal",
                                func = function()
                                    local scale = 0.5333333
                                    self.db.profile.general.uiScale = scale
                                    UIParent:SetScale(scale)
                                end,
                            },
                            
                            scale1080p = {
                                type = "execute",
                                name = "Auto Scale for 1080p",
                                desc = "Set UI scale to 0.7111111 for 1080p resolution",
                                order = 3,
                                width = "normal",
                                func = function()
                                    local scale = 0.7111111
                                    self.db.profile.general.uiScale = scale
                                    UIParent:SetScale(scale)
                                end,
                            },
                        },
                    },
                },
            },
            
            -- ICON VIEWERS TAB
            viewers = {
                type = "group",
                name = "Icon Viewers",
                order = 1,
                childGroups = "tab",
                args = {
                    essential = CreateViewerOptions("EssentialCooldownViewer", "Essential Cooldowns", 1),
                    utility = CreateViewerOptions("UtilityCooldownViewer", "Utility Cooldowns", 2),
                    buff = CreateViewerOptions("BuffIconCooldownViewer", "Buff Icons", 3),
                },
            },
            
            -- RESOURCE BARS TAB
            resourceBars = {
                type = "group",
                name = "Resource Bars",
                order = 2,
                childGroups = "tab",
                args = {
                    -- Primary Power Bar Tab
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
                                get = function() return self.db.profile.powerBar.enabled end,
                                set = function(_, val)
                                    self.db.profile.powerBar.enabled = val
                                    self:UpdatePowerBar()
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            
                            -- POSITION GROUP
                            positionGroup = {
                                type = "group",
                                name = "Position & Size",
                                inline = true,
                                order = 10,
                                args = {
                                    attachTo = {
                                        type = "select",
                                        name = "Attach To",
                                        desc = "Which icon viewer to attach this bar to",
                                        order = 1,
                                        width = "full",
                                        values = GetViewerOptions(),
                                        get = function() return self.db.profile.powerBar.attachTo end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.attachTo = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    height = {
                                        type = "range",
                                        name = "Height",
                                        order = 2,
                                        width = "normal",
                                        min = 2, max = 30, step = 0.1,
                                        get = function() return self.db.profile.powerBar.height end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.height = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    width = {
                                        type = "range",
                                        name = "Width",
                                        desc = "0 = automatic width based on icons",
                                        order = 3,
                                        width = "normal",
                                        min = 0, max = 500, step = 0.1,
                                        get = function() return self.db.profile.powerBar.width end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.width = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    offsetY = {
                                        type = "range",
                                        name = "Vertical Offset",
                                        desc = "Distance from the icon viewer",
                                        order = 4,
                                        width = "full",
                                        min = -500, max = 500, step = 0.1,
                                        get = function() return self.db.profile.powerBar.offsetY end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.offsetY = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                },
                            },
                            
                            -- APPEARANCE GROUP
                            appearanceGroup = {
                                type = "group",
                                name = "Appearance",
                                inline = true,
                                order = 20,
                                args = {
                                    texture = {
                                        type = "select",
                                        name = "Bar Texture",
                                        order = 1,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function() return self.db.profile.powerBar.texture end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.texture = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    useClassColor = {
                                        type = "toggle",
                                        name = "Use Class Color",
                                        desc = "Use your class color instead of custom color",
                                        order = 2,
                                        width = "normal",
                                        get = function() return self.db.profile.powerBar.useClassColor end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.useClassColor = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    barColor = {
                                        type = "color",
                                        name = "Custom Color",
                                        desc = "Used when class color is disabled",
                                        order = 3,
                                        width = "normal",
                                        hasAlpha = true,
                                        disabled = function() return self.db.profile.powerBar.useClassColor end,
                                        get = function()
                                            local c = self.db.profile.powerBar.color
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 1, 1, 1, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.powerBar.color = { r, g, b, a }
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    bgColor = {
                                        type = "color",
                                        name = "Background Color",
                                        desc = "Color of the bar background",
                                        order = 4,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.powerBar.bgColor
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 0.15, 0.15, 0.15, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.powerBar.bgColor = { r, g, b, a }
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                },
                            },
                            
                            -- DISPLAY OPTIONS GROUP
                            displayGroup = {
                                type = "group",
                                name = "Display Options",
                                inline = true,
                                order = 30,
                                args = {
                                    showText = {
                                        type = "toggle",
                                        name = "Show Resource Number",
                                        desc = "Display current resource amount as text",
                                        order = 1,
                                        width = "normal",
                                        get = function() return self.db.profile.powerBar.showText end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.showText = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    showManaAsPercent = {
                                        type = "toggle",
                                        name = "Show Mana as Percent",
                                        desc = "Display mana as percentage instead of raw value",
                                        order = 2,
                                        width = "normal",
                                        get = function() return self.db.profile.powerBar.showManaAsPercent end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.showManaAsPercent = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    showTicks = {
                                        type = "toggle",
                                        name = "Show Ticks",
                                        desc = "Show segment markers for combo points, chi, etc.",
                                        order = 3,
                                        width = "normal",
                                        get = function() return self.db.profile.powerBar.showTicks end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.showTicks = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    textSize = {
                                        type = "range",
                                        name = "Text Size",
                                        order = 4,
                                        width = "normal",
                                        min = 6, max = 24, step = 1,
                                        get = function() return self.db.profile.powerBar.textSize end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.textSize = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    textX = {
                                        type = "range",
                                        name = "Text Horizontal Offset",
                                        order = 5,
                                        width = "normal",
                                        min = -50, max = 50, step = 1,
                                        get = function() return self.db.profile.powerBar.textX end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.textX = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                    textY = {
                                        type = "range",
                                        name = "Text Vertical Offset",
                                        order = 6,
                                        width = "normal",
                                        min = -50, max = 50, step = 1,
                                        get = function() return self.db.profile.powerBar.textY end,
                                        set = function(_, val)
                                            self.db.profile.powerBar.textY = val
                                            self:UpdatePowerBar()
                                        end,
                                    },
                                },
                            },
                        },
                    },
                    -- Secondary Power Bar Tab
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
                                get = function() return self.db.profile.secondaryPowerBar.enabled end,
                                set = function(_, val)
                                    self.db.profile.secondaryPowerBar.enabled = val
                                    self:UpdateSecondaryPowerBar()
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            
                            -- POSITION GROUP
                            positionGroup = {
                                type = "group",
                                name = "Position & Size",
                                inline = true,
                                order = 10,
                                args = {
                                    attachTo = {
                                        type = "select",
                                        name = "Attach To",
                                        desc = "Which icon viewer to attach this bar to",
                                        order = 1,
                                        width = "full",
                                        values = GetViewerOptions(),
                                        get = function() return self.db.profile.secondaryPowerBar.attachTo end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.attachTo = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    height = {
                                        type = "range",
                                        name = "Height",
                                        order = 2,
                                        width = "normal",
                                        min = 2, max = 30, step = 0.1,
                                        get = function() return self.db.profile.secondaryPowerBar.height end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.height = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    width = {
                                        type = "range",
                                        name = "Width",
                                        desc = "0 = automatic width based on icons",
                                        order = 3,
                                        width = "normal",
                                        min = 0, max = 500, step = 0.1,
                                        get = function() return self.db.profile.secondaryPowerBar.width end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.width = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    offsetY = {
                                        type = "range",
                                        name = "Vertical Offset",
                                        desc = "Distance from the icon viewer",
                                        order = 4,
                                        width = "full",
                                        min = -500, max = 500, step = 0.1,
                                        get = function() return self.db.profile.secondaryPowerBar.offsetY end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.offsetY = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                },
                            },
                            
                            -- APPEARANCE GROUP
                            appearanceGroup = {
                                type = "group",
                                name = "Appearance",
                                inline = true,
                                order = 20,
                                args = {
                                    texture = {
                                        type = "select",
                                        name = "Bar Texture",
                                        order = 1,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function() return self.db.profile.secondaryPowerBar.texture end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.texture = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    useClassColor = {
                                        type = "toggle",
                                        name = "Use Class Color",
                                        desc = "Use your class color instead of resource color",
                                        order = 2,
                                        width = "normal",
                                        get = function() return self.db.profile.secondaryPowerBar.useClassColor end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.useClassColor = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    barColor = {
                                        type = "color",
                                        name = "Custom Color",
                                        desc = "Used when class color is disabled",
                                        order = 3,
                                        width = "normal",
                                        hasAlpha = true,
                                        disabled = function() return self.db.profile.secondaryPowerBar.useClassColor end,
                                        get = function()
                                            local c = self.db.profile.secondaryPowerBar.color
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 1, 1, 1, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.secondaryPowerBar.color = { r, g, b, a }
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    bgColor = {
                                        type = "color",
                                        name = "Background Color",
                                        desc = "Color of the bar background",
                                        order = 4,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.secondaryPowerBar.bgColor
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 0.15, 0.15, 0.15, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.secondaryPowerBar.bgColor = { r, g, b, a }
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                },
                            },
                            
                            -- DISPLAY OPTIONS GROUP
                            displayGroup = {
                                type = "group",
                                name = "Display Options",
                                inline = true,
                                order = 30,
                                args = {
                                    showText = {
                                        type = "toggle",
                                        name = "Show Resource Number",
                                        desc = "Display current resource amount as text",
                                        order = 1,
                                        width = "normal",
                                        get = function() return self.db.profile.secondaryPowerBar.showText end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.showText = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    showTicks = {
                                        type = "toggle",
                                        name = "Show Ticks",
                                        desc = "Show segment markers between resources",
                                        order = 2,
                                        width = "normal",
                                        get = function() return self.db.profile.secondaryPowerBar.showTicks end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.showTicks = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    textSize = {
                                        type = "range",
                                        name = "Text Size",
                                        order = 4,
                                        width = "normal",
                                        min = 6, max = 24, step = 1,
                                        get = function() return self.db.profile.secondaryPowerBar.textSize end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.textSize = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    textX = {
                                        type = "range",
                                        name = "Text Horizontal Offset",
                                        order = 5,
                                        width = "normal",
                                        min = -50, max = 50, step = 1,
                                        get = function() return self.db.profile.secondaryPowerBar.textX end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.textX = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    textY = {
                                        type = "range",
                                        name = "Text Vertical Offset",
                                        order = 6,
                                        width = "normal",
                                        min = -50, max = 50, step = 1,
                                        get = function() return self.db.profile.secondaryPowerBar.textY end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.textY = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                },
                            },
                            
                            -- RUNE TIMER OPTIONS GROUP
                            runeTimerGroup = {
                                type = "group",
                                name = "Rune Timer Options",
                                inline = true,
                                order = 40,
                                args = {
                                    showFragmentedPowerBarText = {
                                        type = "toggle",
                                        name = "Show Rune Timers",
                                        desc = "Show cooldown timers on individual runes (Death Knight only)",
                                        order = 1,
                                        width = "normal",
                                        get = function() return self.db.profile.secondaryPowerBar.showFragmentedPowerBarText end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.showFragmentedPowerBarText = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    runeTimerTextSize = {
                                        type = "range",
                                        name = "Rune Timer Text Size",
                                        desc = "Font size for the rune timer text",
                                        order = 2,
                                        width = "normal",
                                        min = 6, max = 24, step = 1,
                                        get = function() return self.db.profile.secondaryPowerBar.runeTimerTextSize end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.runeTimerTextSize = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    runeTimerTextX = {
                                        type = "range",
                                        name = "Rune Timer Text X Position",
                                        desc = "Horizontal offset for the rune timer text",
                                        order = 3,
                                        width = "normal",
                                        min = -50, max = 50, step = 1,
                                        get = function() return self.db.profile.secondaryPowerBar.runeTimerTextX end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.runeTimerTextX = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                    runeTimerTextY = {
                                        type = "range",
                                        name = "Rune Timer Text Y Position",
                                        desc = "Vertical offset for the rune timer text",
                                        order = 4,
                                        width = "normal",
                                        min = -50, max = 50, step = 1,
                                        get = function() return self.db.profile.secondaryPowerBar.runeTimerTextY end,
                                        set = function(_, val)
                                            self.db.profile.secondaryPowerBar.runeTimerTextY = val
                                            self:UpdateSecondaryPowerBar()
                                        end,
                                    },
                                },
                            },
                        },
                    },
                },
            },
            
            -- CAST BARS TAB
            castBars = {
                type = "group",
                name = "Cast Bars",
                order = 4,
                childGroups = "tab",
                args = {
                    -- Player Cast Bar Tab
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
                                get = function() return self.db.profile.castBar.enabled end,
                                set = function(_, val)
                                    self.db.profile.castBar.enabled = val
                                    self:UpdateCastBarLayout()
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            testCast = {
                                type  = "execute",
                                name  = "Test Cast Bar",
                                desc  = "Show a fake cast so you can preview and tweak the bar without casting.",
                                order = 4,
                                func  = function()
                                    self:ShowTestCastBar()
                                end,
                            },  
                            -- POSITION GROUP
                            positionGroup = {
                                type = "group",
                                name = "Position & Size",
                                inline = true,
                                order = 10,
                                args = {
                                    attachTo = {
                                        type = "select",
                                        name = "Attach To",
                                        desc = "Which icon viewer to attach this bar to",
                                        order = 1,
                                        width = "full",
                                        values = GetViewerOptions(),
                                        get = function() return self.db.profile.castBar.attachTo end,
                                        set = function(_, val)
                                            self.db.profile.castBar.attachTo = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    height = {
                                        type = "range",
                                        name = "Height",
                                        order = 2,
                                        width = "normal",
                                        min = 6, max = 40, step = 0.1,
                                        get = function() return self.db.profile.castBar.height end,
                                        set = function(_, val)
                                            self.db.profile.castBar.height = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    width = {
                                        type = "range",
                                        name = "Width",
                                        desc = "0 = automatic width based on icons",
                                        order = 3,
                                        width = "normal",
                                        min = 0, max = 500, step = 0.1,
                                        get = function() return self.db.profile.castBar.width end,
                                        set = function(_, val)
                                            self.db.profile.castBar.width = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    offsetY = {
                                        type = "range",
                                        name = "Vertical Offset",
                                        desc = "Distance from the icon viewer",
                                        order = 4,
                                        width = "full",
                                        min = -500, max = 500, step = 0.1,
                                        get = function() return self.db.profile.castBar.offsetY end,
                                        set = function(_, val)
                                            self.db.profile.castBar.offsetY = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                },
                            },
                            -- APPEARANCE GROUP
                            appearanceGroup = {
                                type = "group",
                                name = "Appearance",
                                inline = true,
                                order = 20,
                                args = {
                                    texture = {
                                        type = "select",
                                        name = "Bar Texture",
                                        order = 1,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function() return self.db.profile.castBar.texture end,
                                        set = function(_, val)
                                            self.db.profile.castBar.texture = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    useClassColor = {
                                        type = "toggle",
                                        name = "Use Class Color",
                                        desc = "Use your class color instead of custom color",
                                        order = 2,
                                        width = "normal",
                                        get = function() return self.db.profile.castBar.useClassColor end,
                                        set = function(_, val)
                                            self.db.profile.castBar.useClassColor = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    barColor = {
                                        type = "color",
                                        name = "Custom Color",
                                        desc = "Used when class color is disabled",
                                        order = 3,
                                        width = "normal",
                                        hasAlpha = true,
                                        disabled = function() return self.db.profile.castBar.useClassColor end,
                                        get = function()
                                            local c = self.db.profile.castBar.color
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 1, 0.7, 0, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.castBar.color = { r, g, b, a }
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    bgColor = {
                                        type = "color",
                                        name = "Background Color",
                                        desc = "Color of the bar background",
                                        order = 4,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.castBar.bgColor
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 0.1, 0.1, 0.1, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.castBar.bgColor = { r, g, b, a }
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    textSize = {
                                        type = "range",
                                        name = "Text Size",
                                        order = 4,
                                        width = "normal",
                                        min = 6, max = 20, step = 1,
                                        get = function() return self.db.profile.castBar.textSize end,
                                        set = function(_, val)
                                            self.db.profile.castBar.textSize = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                    showTimeText = {
                                        type = "toggle",
                                        name = "Show Time Text",
                                        desc = "Show the remaining cast time on the cast bar",
                                        order = 5,
                                        width = "normal",
                                        get = function() return self.db.profile.castBar.showTimeText ~= false end,
                                        set = function(_, val)
                                            self.db.profile.castBar.showTimeText = val
                                            self:UpdateCastBarLayout()
                                        end,
                                    },
                                },
                            },
                        },
                    },
                    -- Target Cast Bar Tab
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
                                get = function() return self.db.profile.targetCastBar.enabled end,
                                set = function(_, val)
                                    self.db.profile.targetCastBar.enabled = val
                                    self:UpdateTargetCastBarLayout()
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            testCast = {
                                type  = "execute",
                                name  = "Test Target Cast Bar",
                                desc  = "Show a fake cast so you can preview and tweak the bar without a target casting. Unit Must Be active to test.",
                                order = 4,
                                func  = function()
                                    self:ShowTestTargetCastBar()
                                end,
                            },
                            -- POSITION GROUP
                            positionGroup = {
                                type = "group",
                                name = "Position & Size",
                                inline = true,
                                order = 10,
                                args = {
                                    attachTo = {
                                        type = "select",
                                        name = "Attach To",
                                        desc = "Which frame to attach this bar to",
                                        order = 1,
                                        width = "full",
                                        values = function()
                                            local opts = {}
                                            -- Add unit frame options if enabled
                                            if self.db.profile.unitFrames and self.db.profile.unitFrames.enabled then
                                                opts["NephUI_Target"] = "Target Frame (Custom)"
                                            end
                                            -- Add viewer options
                                            local viewerOpts = GetViewerOptions()
                                            for k, v in pairs(viewerOpts) do
                                                opts[k] = v
                                            end
                                            -- Add default frame as fallback
                                            opts["TargetFrame"] = "Default Target Frame"
                                            opts["UIParent"] = "Screen Center"
                                            return opts
                                        end,
                                        get = function() return self.db.profile.targetCastBar.attachTo end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.attachTo = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    height = {
                                        type = "range",
                                        name = "Height",
                                        order = 2,
                                        width = "normal",
                                        min = 6, max = 40, step = 0.1,
                                        get = function() return self.db.profile.targetCastBar.height end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.height = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    width = {
                                        type = "range",
                                        name = "Width",
                                        desc = "0 = automatic width based on anchor",
                                        order = 3,
                                        width = "normal",
                                        min = 0, max = 500, step = 0.1,
                                        get = function() return self.db.profile.targetCastBar.width end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.width = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    offsetY = {
                                        type = "range",
                                        name = "Vertical Offset",
                                        desc = "Distance from the anchor frame",
                                        order = 4,
                                        width = "full",
                                        min = -500, max = 500, step = 0.1,
                                        get = function() return self.db.profile.targetCastBar.offsetY end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.offsetY = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                },
                            },
                            -- APPEARANCE GROUP
                            appearanceGroup = {
                                type = "group",
                                name = "Appearance",
                                inline = true,
                                order = 20,
                                args = {
                                    texture = {
                                        type = "select",
                                        name = "Bar Texture",
                                        order = 1,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function() return self.db.profile.targetCastBar.texture end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.texture = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    barColor = {
                                        type = "color",
                                        name = "Custom Color",
                                        desc = "Color of the cast bar",
                                        order = 2,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.targetCastBar.color
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 1, 0, 0, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.targetCastBar.color = { r, g, b, a }
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    bgColor = {
                                        type = "color",
                                        name = "Background Color",
                                        desc = "Color of the bar background",
                                        order = 3,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.targetCastBar.bgColor
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 0.1, 0.1, 0.1, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.targetCastBar.bgColor = { r, g, b, a }
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    textSize = {
                                        type = "range",
                                        name = "Text Size",
                                        order = 5,
                                        width = "normal",
                                        min = 6, max = 20, step = 1,
                                        get = function() return self.db.profile.targetCastBar.textSize end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.textSize = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                    showTimeText = {
                                        type = "toggle",
                                        name = "Show Time Text",
                                        desc = "Show the remaining cast time on the cast bar",
                                        order = 6,
                                        width = "normal",
                                        get = function() return self.db.profile.targetCastBar.showTimeText ~= false end,
                                        set = function(_, val)
                                            self.db.profile.targetCastBar.showTimeText = val
                                            self:UpdateTargetCastBarLayout()
                                        end,
                                    },
                                },
                            },
                        },
                    },
                    -- Focus Cast Bar Tab
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
                                get = function() return self.db.profile.focusCastBar.enabled end,
                                set = function(_, val)
                                    self.db.profile.focusCastBar.enabled = val
                                    self:UpdateFocusCastBarLayout()
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            testCast = {
                                type  = "execute",
                                name  = "Test Focus Cast Bar",
                                desc  = "Show a fake cast so you can preview and tweak the bar without a focus casting. Unit Must Be active to test.",
                                order = 4,
                                func  = function()
                                    self:ShowTestFocusCastBar()
                                end,
                            },
                            -- POSITION GROUP
                            positionGroup = {
                                type = "group",
                                name = "Position & Size",
                                inline = true,
                                order = 10,
                                args = {
                                    attachTo = {
                                        type = "select",
                                        name = "Attach To",
                                        desc = "Which frame to attach this bar to",
                                        order = 1,
                                        width = "full",
                                        values = function()
                                            local opts = {}
                                            -- Add unit frame options if enabled
                                            if self.db.profile.unitFrames and self.db.profile.unitFrames.enabled then
                                                opts["NephUI_Focus"] = "Focus Frame (Custom)"
                                            end
                                            -- Add viewer options
                                            local viewerOpts = GetViewerOptions()
                                            for k, v in pairs(viewerOpts) do
                                                opts[k] = v
                                            end
                                            -- Add default frame as fallback
                                            opts["FocusFrame"] = "Default Focus Frame"
                                            opts["UIParent"] = "Screen Center"
                                            return opts
                                        end,
                                        get = function() return self.db.profile.focusCastBar.attachTo end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.attachTo = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    height = {
                                        type = "range",
                                        name = "Height",
                                        order = 2,
                                        width = "normal",
                                        min = 6, max = 40, step = 0.1,
                                        get = function() return self.db.profile.focusCastBar.height end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.height = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    width = {
                                        type = "range",
                                        name = "Width",
                                        desc = "0 = automatic width based on anchor",
                                        order = 3,
                                        width = "normal",
                                        min = 0, max = 500, step = 0.1,
                                        get = function() return self.db.profile.focusCastBar.width end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.width = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    offsetY = {
                                        type = "range",
                                        name = "Vertical Offset",
                                        desc = "Distance from the anchor frame",
                                        order = 4,
                                        width = "full",
                                        min = -500, max = 500, step = 0.1,
                                        get = function() return self.db.profile.focusCastBar.offsetY end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.offsetY = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                },
                            },
                            -- APPEARANCE GROUP
                            appearanceGroup = {
                                type = "group",
                                name = "Appearance",
                                inline = true,
                                order = 20,
                                args = {
                                    texture = {
                                        type = "select",
                                        name = "Bar Texture",
                                        order = 1,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function() return self.db.profile.focusCastBar.texture end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.texture = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    barColor = {
                                        type = "color",
                                        name = "Custom Color",
                                        desc = "Color of the cast bar",
                                        order = 2,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.focusCastBar.color
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 1, 0, 0, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.focusCastBar.color = { r, g, b, a }
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    bgColor = {
                                        type = "color",
                                        name = "Background Color",
                                        desc = "Color of the bar background",
                                        order = 3,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local c = self.db.profile.focusCastBar.bgColor
                                            if c then
                                                return c[1], c[2], c[3], c[4] or 1
                                            end
                                            return 0.1, 0.1, 0.1, 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            self.db.profile.focusCastBar.bgColor = { r, g, b, a }
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    textSize = {
                                        type = "range",
                                        name = "Text Size",
                                        order = 5,
                                        width = "normal",
                                        min = 6, max = 20, step = 1,
                                        get = function() return self.db.profile.focusCastBar.textSize end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.textSize = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                    showTimeText = {
                                        type = "toggle",
                                        name = "Show Time Text",
                                        desc = "Show the remaining cast time on the cast bar",
                                        order = 6,
                                        width = "normal",
                                        get = function() return self.db.profile.focusCastBar.showTimeText ~= false end,
                                        set = function(_, val)
                                            self.db.profile.focusCastBar.showTimeText = val
                                            self:UpdateFocusCastBarLayout()
                                        end,
                                    },
                                },
                            },
                        },
                    },
                },
            },
            
            -- CUSTOM ICONS TAB
            customIcons = {
                type = "group",
                name = "Custom Icons",
                order = 3,
                childGroups = "tab",
                args = {
                    -- Items Tab
                    general = {
                        type = "group",
                        name = "Items",
                        order = 1,
                        args = {
                            header = {
                                type = "header",
                                name = "Custom Icons Settings",
                                order = 1,
                            },
                            enabled = {
                                type = "toggle",
                                name = "Enable Custom Icons",
                                desc = "Show/hide the custom icons tracker",
                                width = "full",
                                order = 2,
                                get = function() return NephUI.db.profile.customIcons.enabled end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.enabled = val
                                    if val then
                                        NephUI:CreateCustomIconsTrackerFrame()
                                        NephUI:CreateTrinketsTrackerFrame()
                                    else
                                        if NephUI.customIconsTrackerFrame then
                                            NephUI.customIconsTrackerFrame:Hide()
                                        end
                                        if NephUI.trinketsTrackerFrame then
                                            NephUI.trinketsTrackerFrame:Hide()
                                        end
                                    end
                                    NephUI:RefreshAll()
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            
                            -- ITEMS CUSTOMIZATION GROUP
                            itemsCustomization = {
                                type = "group",
                                name = "Items Customization",
                                inline = true,
                                order = 10,
                                args = {
                                    iconSize = {
                                        type = "range",
                                        name = "Icon Size",
                                        desc = "Base size of each icon in pixels (longest dimension)",
                                        order = 1,
                                        width = "full",
                                        min = 16, max = 96, step = 0.1,
                                        get = function() return NephUI.db.profile.customIcons.items.iconSize or 40 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.iconSize = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    aspectRatio = {
                                        type = "range",
                                        name = "Aspect Ratio (Width:Height)",
                                        desc = "Control the icon aspect ratio. 1.0 = square, >1.0 = wider, <1.0 = taller",
                                        order = 2,
                                        width = "full",
                                        min = 0.5, max = 2.5, step = 0.01,
                                        get = function() return NephUI.db.profile.customIcons.items.aspectRatioCrop or 1.0 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.aspectRatioCrop = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    spacing = {
                                        type = "range",
                                        name = "Spacing",
                                        desc = "Space between icons (negative values overlap)",
                                        order = 3,
                                        width = "full",
                                        min = -20, max = 20, step = 0.1,
                                        get = function() return NephUI.db.profile.customIcons.items.spacing or -9 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.spacing = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    rowLimit = {
                                        type = "range",
                                        name = "Icons Per Row",
                                        desc = "Maximum icons per row (0 = unlimited, single row)",
                                        order = 4,
                                        width = "full",
                                        min = 0, max = 20, step = 1,
                                        get = function() return NephUI.db.profile.customIcons.items.rowLimit or 0 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.rowLimit = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    growthDirection = {
                                        type = "select",
                                        name = "Growth Direction",
                                        desc = "How icons grow from the first icon. Centered = centered layout, Left/Right = grow from first icon",
                                        order = 5,
                                        width = "full",
                                        values = {
                                            Centered = "Centered",
                                            Left = "Left",
                                            Right = "Right",
                                        },
                                        get = function() return NephUI.db.profile.customIcons.items.growthDirection or "Centered" end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.growthDirection = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    borderSize = {
                                        type = "range",
                                        name = "Border Size",
                                        desc = "Size of the border around icons (0 = no border)",
                                        order = 6,
                                        width = "full",
                                        min = 0, max = 5, step = 0.1,
                                        get = function() return NephUI.db.profile.customIcons.items.borderSize or 1 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.borderSize = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    borderColor = {
                                        type = "color",
                                        name = "Border Color",
                                        desc = "Color of the border around icons",
                                        order = 7,
                                        width = "full",
                                        hasAlpha = true,
                                        get = function()
                                            local c = NephUI.db.profile.customIcons.items.borderColor or { 0, 0, 0, 1 }
                                            return c[1], c[2], c[3], c[4] or 1
                                        end,
                                        set = function(_, r, g, b, a)
                                            NephUI.db.profile.customIcons.items.borderColor = { r, g, b, a or 1 }
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    anchorFrame = {
                                        type = "input",
                                        name = "Anchor Frame",
                                        desc = "Name of the frame to anchor items to (leave empty for default position)",
                                        order = 8,
                                        width = "full",
                                        get = function() return NephUI.db.profile.customIcons.items.anchorFrame or "" end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.anchorFrame = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    offsetX = {
                                        type = "range",
                                        name = "Offset X",
                                        desc = "Horizontal offset from anchor frame",
                                        order = 9,
                                        width = "normal",
                                        min = -1000, max = 1000, step = 0.1,
                                        get = function() return NephUI.db.profile.customIcons.items.offsetX or 0 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.offsetX = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                    offsetY = {
                                        type = "range",
                                        name = "Offset Y",
                                        desc = "Vertical offset from anchor frame",
                                        order = 10,
                                        width = "normal",
                                        min = -1000, max = 1000, step = 0.1,
                                        get = function() return NephUI.db.profile.customIcons.items.offsetY or 0 end,
                                        set = function(_, val)
                                            NephUI.db.profile.customIcons.items.offsetY = val
                                            NephUI:ApplyCustomIconsLayout()
                                        end,
                                    },
                                },
                            },
                            
                            spacer2 = {
                                type = "description",
                                name = " ",
                                order = 20,
                            },
                            
                            -- TRACKED ITEMS GROUP
                            trackedItemsGroup = {
                                type = "group",
                                name = "Tracked Items",
                                inline = true,
                                order = 30,
                                args = {
                            dragDropHeader = {
                                type = "description",
                                name = "|cff00ff00Drag and drop an item here to add it to tracking|r",
                                order = 1,
                                width = "full",
                            },
                            dragDropArea = {
                                type = "description",
                                name = "|cff808080Drop an item from your inventory or character sheet anywhere in this section|r",
                                order = 2,
                                width = "full",
                                fontSize = "medium",
                            },
                            itemListHeader = {
                                type = "description",
                                name = function()
                                    local db = NephUI.db.profile.customIcons
                                    if not db.trackedItems or #db.trackedItems == 0 then
                                        return "|cff808080No items tracked. Drag and drop items above to add them.|r"
                                    end
                                    return "|cff00ff00Tracked Items:|r"
                                end,
                                order = 3,
                                width = "full",
                            },
                        },
                    },
                },
            },
            
            -- Trinkets Tab
            trinkets = {
                type = "group",
                name = "Trinkets",
                order = 2,
                args = {
                    header = {
                        type = "header",
                        name = "Trinket & Weapon Tracking",
                        order = 1,
                    },
                    -- TRINKETS CUSTOMIZATION GROUP
                    trinketsCustomization = {
                        type = "group",
                        name = "Trinkets Customization",
                        inline = true,
                        order = 5,
                        args = {
                            iconSize = {
                                type = "range",
                                name = "Icon Size",
                                desc = "Base size of each icon in pixels (longest dimension)",
                                order = 1,
                                width = "full",
                                min = 16, max = 96, step = 0.1,
                                get = function() return NephUI.db.profile.customIcons.trinkets.iconSize or 40 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.iconSize = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            aspectRatio = {
                                type = "range",
                                name = "Aspect Ratio (Width:Height)",
                                desc = "Control the icon aspect ratio. 1.0 = square, >1.0 = wider, <1.0 = taller",
                                order = 2,
                                width = "full",
                                min = 0.5, max = 2.5, step = 0.01,
                                get = function() return NephUI.db.profile.customIcons.trinkets.aspectRatioCrop or 1.0 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.aspectRatioCrop = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            spacing = {
                                type = "range",
                                name = "Spacing",
                                desc = "Space between icons (negative values overlap)",
                                order = 3,
                                width = "full",
                                min = -20, max = 20, step = 0.1,
                                get = function() return NephUI.db.profile.customIcons.trinkets.spacing or -9 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.spacing = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            rowLimit = {
                                type = "range",
                                name = "Icons Per Row",
                                desc = "Maximum icons per row (0 = unlimited, single row)",
                                order = 4,
                                width = "full",
                                min = 0, max = 20, step = 1,
                                get = function() return NephUI.db.profile.customIcons.trinkets.rowLimit or 0 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.rowLimit = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            growthDirection = {
                                type = "select",
                                name = "Growth Direction",
                                desc = "How icons grow from the first icon. Centered = centered layout, Left/Right = grow from first icon",
                                order = 5,
                                width = "full",
                                values = {
                                    Centered = "Centered",
                                    Left = "Left",
                                    Right = "Right",
                                },
                                get = function() return NephUI.db.profile.customIcons.trinkets.growthDirection or "Centered" end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.growthDirection = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            borderSize = {
                                type = "range",
                                name = "Border Size",
                                desc = "Size of the border around icons (0 = no border)",
                                order = 6,
                                width = "full",
                                min = 0, max = 5, step = 0.1,
                                get = function() return NephUI.db.profile.customIcons.trinkets.borderSize or 1 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.borderSize = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            borderColor = {
                                type = "color",
                                name = "Border Color",
                                desc = "Color of the border around icons",
                                order = 7,
                                width = "full",
                                hasAlpha = true,
                                get = function()
                                    local c = NephUI.db.profile.customIcons.trinkets.borderColor or { 0, 0, 0, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set = function(_, r, g, b, a)
                                    NephUI.db.profile.customIcons.trinkets.borderColor = { r, g, b, a or 1 }
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            anchorFrame = {
                                type = "input",
                                name = "Anchor Frame",
                                desc = "Name of the frame to anchor trinkets to (leave empty for default position)",
                                order = 8,
                                width = "full",
                                get = function() return NephUI.db.profile.customIcons.trinkets.anchorFrame or "" end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.anchorFrame = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            offsetX = {
                                type = "range",
                                name = "Offset X",
                                desc = "Horizontal offset from anchor frame",
                                order = 9,
                                width = "normal",
                                min = -1000, max = 1000, step = 0.1,
                                get = function() return NephUI.db.profile.customIcons.trinkets.offsetX or 0 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.offsetX = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                            offsetY = {
                                type = "range",
                                name = "Offset Y",
                                desc = "Vertical offset from anchor frame",
                                order = 10,
                                width = "normal",
                                min = -1000, max = 1000, step = 0.1,
                                get = function() return NephUI.db.profile.customIcons.trinkets.offsetY or 0 end,
                                set = function(_, val)
                                    NephUI.db.profile.customIcons.trinkets.offsetY = val
                                    NephUI:ApplyTrinketsLayout()
                                end,
                            },
                        },
                    },
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 11,
                    },
                    trinket1 = {
                        type = "toggle",
                        name = "Track Trinket Slot 1",
                        desc = "Track cooldowns for the item in trinket slot 1",
                        width = "full",
                        order = 12,
                        get = function() return NephUI.db.profile.customIcons.trinkets.trinket1 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.trinket1 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshAll()
                        end,
                    },
                    trinket2 = {
                        type = "toggle",
                        name = "Track Trinket Slot 2",
                        desc = "Track cooldowns for the item in trinket slot 2",
                        width = "full",
                        order = 13,
                        get = function() return NephUI.db.profile.customIcons.trinkets.trinket2 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.trinket2 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshAll()
                        end,
                    },
                    weapon1 = {
                        type = "toggle",
                        name = "Track Weapon Slot 1",
                        desc = "Track cooldowns for the item in weapon slot 1 (main hand)",
                        width = "full",
                        order = 14,
                        get = function() return NephUI.db.profile.customIcons.trinkets.weapon1 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.weapon1 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshAll()
                        end,
                    },
                    weapon2 = {
                        type = "toggle",
                        name = "Track Weapon Slot 2",
                        desc = "Track cooldowns for the item in weapon slot 2 (off hand)",
                        width = "full",
                        order = 15,
                        get = function() return NephUI.db.profile.customIcons.trinkets.weapon2 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.weapon2 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshAll()
                        end,
                    },
                },
            },
        },
    },
    
            -- UNIT FRAMES TAB
            unitFrames = {
                type = "group",
                name = "Unit Frames",
                order = 5,
                childGroups = "tab",
                args = {
                    -- General Settings Tab
                    general = {
                        type = "group",
                        name = "General",
                        order = 1,
                        args = {
                            header = {
                                type = "header",
                                name = "General Unit Frame Settings",
                                order = 1,
                            },
                            enabled = {
                                type = "toggle",
                                name = "Enable Unit Frame Customization",
                                desc = "Enable custom unit frames (hides default Blizzard frames)",
                                width = "full",
                                order = 2,
                                get = function()
                                    if not self.db.profile.unitFrames then
                                        self.db.profile.unitFrames = {}
                                    end
                                    return self.db.profile.unitFrames.enabled or false
                                end,
                                set = function(_, val)
                                    if not self.db.profile.unitFrames then
                                        self.db.profile.unitFrames = {}
                                    end
                                    self.db.profile.unitFrames.enabled = val
                                    if self.UnitFrames then
                                        if val then
                                            self.UnitFrames:Initialize()
                                        else
                                            -- Hide all frames when disabled
                                            for unit in pairs({player = true, target = true, targettarget = true, pet = true, focus = true}) do
                                                local frameName = "NephUI_" .. unit:gsub("^%l", string.upper):gsub("targettarget", "TargetTarget")
                                                local frame = _G[frameName]
                                                if frame then frame:Hide() end
                                            end
                                        end
                                    end
                                end,
                            },
                            spacer1 = {
                                type = "description",
                                name = " ",
                                order = 3,
                            },
                            showAnchorsLabel = {
                                type = "description",
                                name = "Unit Frame Anchors:",
                                order = 4,
                            },
                            enableAnchors = {
                                type = "execute",
                                name = "Enable Anchors",
                                desc = "Show draggable anchors for unit frames (works independently of Edit Mode)",
                                width = "normal",
                                order = 5,
                                func = function()
                                    local db = self.db.profile.unitFrames
                                    if not db.General then db.General = {} end
                                    db.General.ShowEditModeAnchors = true
                                    if self.UnitFrames then
                                        self.UnitFrames:UpdateEditModeAnchors()
                                    end
                                end,
                            },
                            disableAnchors = {
                                type = "execute",
                                name = "Disable Anchors",
                                desc = "Hide draggable anchors for unit frames",
                                width = "normal",
                                order = 6,
                                func = function()
                                    local db = self.db.profile.unitFrames
                                    if not db.General then db.General = {} end
                                    db.General.ShowEditModeAnchors = false
                                    if self.UnitFrames then
                                        self.UnitFrames:UpdateEditModeAnchors()
                                    end
                                end,
                            },
                            spacer2 = {
                                type = "description",
                                name = " ",
                                order = 7,
                            },
                            
                            -- TEXTURES GROUP
                            texturesGroup = {
                                type = "group",
                                name = "Textures",
                                inline = true,
                                order = 10,
                                args = {
                                    foregroundTexture = {
                                        type = "select",
                                        name = "Foreground Texture",
                                        desc = "Texture applied globally to all health bars",
                                        order = 1,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General then return "Blizzard Raid Bar" end
                                            return db.General.ForegroundTexture or "Blizzard Raid Bar"
                                        end,
                                        set = function(_, val)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            db.General.ForegroundTexture = val
                                            if self.UnitFrames then
                                                self.UnitFrames:ResolveMedia()
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    backgroundTexture = {
                                        type = "select",
                                        name = "Background Texture",
                                        desc = "Texture applied globally to all health bar backgrounds",
                                        order = 2,
                                        width = "full",
                                        values = LSM:HashTable("statusbar"),
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General then return "Solid" end
                                            return db.General.BackgroundTexture or "Solid"
                                        end,
                                        set = function(_, val)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            db.General.BackgroundTexture = val
                                            if self.UnitFrames then
                                                self.UnitFrames:ResolveMedia()
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                },
                            },
                            
                            -- FONTS GROUP
                            fontsGroup = {
                                type = "group",
                                name = "Fonts",
                                inline = true,
                                order = 20,
                                args = {
                                    font = {
                                        type = "select",
                                        name = "Font",
                                        desc = "Font used for all unit frame text (uses Global Font from General tab)",
                                        order = 1,
                                        width = "normal",
                                        values = LSM:HashTable("font"),
                                        get = function()
                                            return self.db.profile.general.globalFont or "Friz Quadrata TT"
                                        end,
                                        set = function(_, val)
                                            self.db.profile.general.globalFont = val
                                            if self.RefreshAll then
                                                self:RefreshAll()
                                            end
                                        end,
                                    },
                                    fontFlag = {
                                        type = "select",
                                        name = "Font Flags",
                                        desc = "Font outline style",
                                        order = 2,
                                        width = "normal",
                                        values = {
                                            ["OUTLINE"] = "Outline",
                                            ["THICKOUTLINE"] = "Thick Outline",
                                            ["MONOCHROME"] = "Monochrome",
                                            ["NONE"] = "None",
                                        },
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General then return "OUTLINE" end
                                            return db.General.FontFlag or "OUTLINE"
                                        end,
                                        set = function(_, val)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            db.General.FontFlag = val
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                },
                            },
                            
                            -- FONT SHADOWS GROUP
                            fontShadowsGroup = {
                                type = "group",
                                name = "Font Shadows",
                                inline = true,
                                order = 30,
                                args = {
                                    shadowOffsetX = {
                                        type = "range",
                                        name = "Shadow X Offset",
                                        order = 1,
                                        width = "normal",
                                        min = -10, max = 10, step = 1,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.FontShadows then return 0 end
                                            return db.General.FontShadows.OffsetX or 0
                                        end,
                                        set = function(_, val)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.FontShadows then db.General.FontShadows = {} end
                                            db.General.FontShadows.OffsetX = val
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    shadowOffsetY = {
                                        type = "range",
                                        name = "Shadow Y Offset",
                                        order = 2,
                                        width = "normal",
                                        min = -10, max = 10, step = 1,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.FontShadows then return 0 end
                                            return db.General.FontShadows.OffsetY or 0
                                        end,
                                        set = function(_, val)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.FontShadows then db.General.FontShadows = {} end
                                            db.General.FontShadows.OffsetY = val
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    shadowColor = {
                                        type = "color",
                                        name = "Shadow Color",
                                        order = 3,
                                        width = "normal",
                                        hasAlpha = true,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.FontShadows then return 0, 0, 0, 0 end
                                            local c = db.General.FontShadows.Color or {0, 0, 0, 0}
                                            return c[1], c[2], c[3], c[4] or 0
                                        end,
                                        set = function(_, r, g, b, a)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.FontShadows then db.General.FontShadows = {} end
                                            db.General.FontShadows.Color = {r, g, b, a or 0}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                },
                            },
                            
                            -- CUSTOM Colors GROUP
                            customColorsGroup = {
                                type = "group",
                                name = "Custom Colors",
                                inline = true,
                                order = 40,
                                args = {
                                    powerColorsHeader = {
                                        type = "header",
                                        name = "Power Colors",
                                        order = 10,
                                    },
                                    manaColor = {
                                        type = "color",
                                        name = "Mana",
                                        order = 11,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Power then
                                                return 0, 0, 1
                                            end
                                            local c = db.General.CustomColors.Power[0] or {0, 0, 1}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Power then db.General.CustomColors.Power = {} end
                                            db.General.CustomColors.Power[0] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    rageColor = {
                                        type = "color",
                                        name = "Rage",
                                        order = 12,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Power then
                                                return 1, 0, 0
                                            end
                                            local c = db.General.CustomColors.Power[1] or {1, 0, 0}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Power then db.General.CustomColors.Power = {} end
                                            db.General.CustomColors.Power[1] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    energyColor = {
                                        type = "color",
                                        name = "Energy",
                                        order = 13,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Power then
                                                return 1, 1, 0
                                            end
                                            local c = db.General.CustomColors.Power[3] or {1, 1, 0}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Power then db.General.CustomColors.Power = {} end
                                            db.General.CustomColors.Power[3] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    runicPowerColor = {
                                        type = "color",
                                        name = "Runic Power",
                                        order = 14,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Power then
                                                return 0, 0.82, 1
                                            end
                                            local c = db.General.CustomColors.Power[6] or {0, 0.82, 1}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Power then db.General.CustomColors.Power = {} end
                                            db.General.CustomColors.Power[6] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    reactionColorsHeader = {
                                        type = "header",
                                        name = "Reaction Colors",
                                        order = 20,
                                    },
                                    hostileColor = {
                                        type = "color",
                                        name = "Hostile",
                                        order = 21,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Reaction then
                                                return 204/255, 64/255, 64/255
                                            end
                                            local c = db.General.CustomColors.Reaction[2] or {204/255, 64/255, 64/255}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Reaction then db.General.CustomColors.Reaction = {} end
                                            db.General.CustomColors.Reaction[2] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    neutralColor = {
                                        type = "color",
                                        name = "Neutral",
                                        order = 22,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Reaction then
                                                return 204/255, 204/255, 64/255
                                            end
                                            local c = db.General.CustomColors.Reaction[4] or {204/255, 204/255, 64/255}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Reaction then db.General.CustomColors.Reaction = {} end
                                            db.General.CustomColors.Reaction[4] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                    friendlyColor = {
                                        type = "color",
                                        name = "Friendly",
                                        order = 23,
                                        width = "normal",
                                        hasAlpha = false,
                                        get = function()
                                            local db = self.db.profile.unitFrames
                                            if not db or not db.General or not db.General.CustomColors or not db.General.CustomColors.Reaction then
                                                return 64/255, 204/255, 64/255
                                            end
                                            local c = db.General.CustomColors.Reaction[5] or {64/255, 204/255, 64/255}
                                            return c[1], c[2], c[3]
                                        end,
                                        set = function(_, r, g, b)
                                            local db = self.db.profile.unitFrames
                                            if not db.General then db.General = {} end
                                            if not db.General.CustomColors then db.General.CustomColors = {} end
                                            if not db.General.CustomColors.Reaction then db.General.CustomColors.Reaction = {} end
                                            db.General.CustomColors.Reaction[5] = {r, g, b}
                                            if self.UnitFrames then
                                                self.UnitFrames:RefreshFrames()
                                            end
                                        end,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Per-frame tabs
                    playerFrame = CreateUnitFrameOptions("player", "Player", 10),
                    targetFrame = CreateUnitFrameOptions("target", "Target", 20),
                    targettargetFrame = CreateUnitFrameOptions("targettarget", "Target of Target", 30),
                    petFrame = CreateUnitFrameOptions("pet", "Pet", 40),
                    focusFrame = CreateUnitFrameOptions("focus", "Focus", 50),
                    bossFrame = CreateUnitFrameOptions("boss", "Boss", 60),
                },
            },
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
    end

    -- IMPORT / EXPORT TAB
    options.args.importExport = {
        type  = "group",
        name  = "Import / Export",
        order = 99,
        args  = {
            desc = {
                type  = "description",
                order = 1,
                name  = "Export your current profile as text to share, or paste a string to import.",
            },

            spacer1 = {
                type  = "description",
                order = 2,
                name  = "",
            },

            export = {
                type      = "input",
                name      = "Export Current Profile",
                order     = 10,
                width     = "full",
                multiline = true,
                get       = function()
                    return NephUI:ExportProfileToString()
                end,
                set       = function() end,
            },

            spacer2 = {
                type  = "description",
                order = 19,
                name  = " ",
            },

            import = {
                type      = "input",
                name      = "Import Profile String",
                order     = 20,
                width     = "full",
                multiline = true,
                get       = function()
                    return importBuffer
                end,
                set       = function(_, val)
                    importBuffer = val or ""
                end,
            },

            importButton = {
                type  = "execute",
                name  = "Import",
                order = 30,
                func  = function()
                    local importString = importBuffer
                    
                    -- If buffer is empty, try to get text directly from the widget
                    if not importString or importString == "" then
                        local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                        local openFrame = AceConfigDialog.OpenFrames[ADDON_NAME]
                        if openFrame then
                            local function FindImportWidget(parent, depth)
                                depth = depth or 0
                                if depth > 15 then return nil end
                                
                                -- Check if this is a multiline EditBox widget
                                if type(parent) == "table" and parent.type == "MultiLineEditBox" and parent.editBox then
                                    local label = parent.label and parent.label:GetText() or ""
                                    if string.find(label:lower(), "import") then
                                        return parent.editBox:GetText() or ""
                                    end
                                end
                                
                                -- Check children
                                if type(parent) == "table" and parent.children then
                                    for _, widget in pairs(parent.children) do
                                        local text = FindImportWidget(widget, depth + 1)
                                        if text then return text end
                                    end
                                end
                                
                                -- Check frame
                                if type(parent) == "table" and parent.frame then
                                    local text = FindImportWidget(parent.frame, depth + 1)
                                    if text then return text end
                                end
                                
                                -- Check WoW frames
                                if type(parent) == "userdata" and parent.GetChildren then
                                    local children = {parent:GetChildren()}
                                    for _, child in ipairs(children) do
                                        local text = FindImportWidget(child, depth + 1)
                                        if text then return text end
                                    end
                                end
                                
                                return nil
                            end
                            
                            importString = FindImportWidget(openFrame, 0) or importBuffer
                        end
                    end
                    
                    -- Trim whitespace
                    if importString then
                        importString = importString:gsub("^%s+", ""):gsub("%s+$", "")
                    end
                    
                    if not importString or importString == "" then
                        print("|cffff0000NephUI: Import failed: No data found. Please paste your import string in the Import Profile String field.|r")
                        return
                    end
                    
                    local ok, err = NephUI:ImportProfileFromString(importString)
                    if ok then
                        print("|cff00ff00NephUI: Profile imported. Please reload your UI.|r")
                        -- Clear the import buffer after successful import
                        importBuffer = ""
                    else
                        print("|cffff0000NephUI: Import failed: " .. (err or "Unknown error") .. "|r")
                    end
                end,
            },
            spacer3 = {
                type  = "description",
                order = 31,
                name  = "|cff00ff00PRESSING THE IMPORT BUTTON WILL OVERWRITE YOUR CURRENT PROFILE|r",
            },
        },
    }

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
            -- Try to find the frame by its actual name (CooldownViewerSettings)
            local frame = _G["CooldownViewerSettings"]
            if frame then
                frame:Show()
                frame:Raise()
            else
                -- Use AceConfigDialog to open/create the frame
                local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                AceConfigDialog:Open(ADDON_NAME)
                -- Wait a moment for frame to be created, then show it
                C_Timer.After(0.05, function()
                    local frame = _G["CooldownViewerSettings"] or (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[ADDON_NAME])
                    if frame then
                        frame:Show()
                        frame:Raise()
                    end
                end)
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
        order = 104,
    }
    
    options.args.discordButton = {
        type = "input",
        name = "Discord Support",
        desc = "Discord link - Select and copy (Ctrl+A) -> (Ctrl+C)",
        order = 105,
        get = function()
            return "https://discord.gg/Mc2StWHKya"
        end,
        set = function() end, -- Empty set function to prevent changes
    }
    
    -- Get version from addon metadata
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"
    
    options.args.versionDisplay = {
        type = "description",
        name = "\n|cff00ff00Version: " .. version .. "|r",
        fontSize = "medium",
        order = 106,
    }

    AceConfig:RegisterOptionsTable(ADDON_NAME, options)
    AceConfigDialog:AddToBlizOptions(ADDON_NAME, "NephUI")
    
    -- Set default window size (width, height)
    AceConfigDialog:SetDefaultSize(ADDON_NAME, 900, 700)
    
    -- Setup UI scale protection for config panel
    NephUI:SetupConfigPanelScaleProtection()
    
    -- Store reference to trackedItemsGroup for dynamic updates
    -- Note: trackedItemsGroup is inside the "Items" tab (general), not directly under customIcons
    NephUI._trackedItemsGroup = options.args.customIcons.args.general.args.trackedItemsGroup
    
    -- Initial build of tracked items list
    if NephUI.RebuildTrackedItemsList then
        NephUI:RebuildTrackedItemsList()
    end
    
    -- Setup drag-and-drop frame for custom icons
    C_Timer.After(0.5, function()
        NephUI:SetupCustomIconsDragDrop()
    end)
end

-- Setup UI scale protection for config panel so it never changes size with UI scale
function NephUI:SetupConfigPanelScaleProtection()
    -- Hook UIParent:SetScale to update config panel scale whenever UI scale changes
    if not NephUI._UIParentSetScaleHooked then
        local originalSetScale = UIParent.SetScale
        UIParent.SetScale = function(self, scale)
            originalSetScale(self, scale)
            -- Update config panel scale if it's open
            NephUI:UpdateConfigPanelScaleProtection()
        end
        NephUI._UIParentSetScaleHooked = true
    end
end

-- Apply scale protection to a config panel frame
function NephUI:ApplyConfigPanelScaleProtection(frame)
    if not frame then return end
    
    local uiScale = UIParent:GetScale()
    if uiScale and uiScale > 0 then
        -- Set the frame's scale to the inverse of UIParent's scale, then scale to 70% size
        -- This makes the effective scale = uiScale * (0.7/uiScale) = 0.7
        local inverseScale = 0.6 / uiScale
        frame:SetScale(inverseScale)
    end
end

-- Update scale protection for all open config panels
function NephUI:UpdateConfigPanelScaleProtection()
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if not AceConfigDialog then return end
    
    local openFrame = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[ADDON_NAME]
    if openFrame and openFrame.frame then
        NephUI:ApplyConfigPanelScaleProtection(openFrame.frame)
    end
    
    -- Also update the global reference if it exists
    local configFrame = _G["NephUI_ConfigFrame"]
    if configFrame then
        NephUI:ApplyConfigPanelScaleProtection(configFrame)
    end
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
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    if not AceConfigDialog then return end
    
    -- Create a drag-and-drop frame that overlays the description area
    if not self.customIconsDragDropFrame then
        local dragFrame = CreateFrame("Button", "NephUI_CustomIconsDragDrop", UIParent, "BackdropTemplate")
        dragFrame:SetFrameStrata("FULLSCREEN_DIALOG")  -- Higher than DIALOG to be above GUI
        dragFrame:SetFrameLevel(10000)  -- Very high frame level to ensure it's on top
        dragFrame:EnableMouse(true)
        dragFrame:RegisterForDrag("LeftButton")
        dragFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        dragFrame:SetMovable(false)
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
            local openFrame = AceConfigDialog.OpenFrames[ADDON_NAME]
            if not openFrame or not openFrame:IsShown() then
                dragFrame:Hide()
                return
            end
            
            -- Check if there's an item on the cursor
            local cursorType, id = GetCursorInfo()
            if cursorType == "item" and id then
                -- Item is on cursor, show drop area over entire GUI
                local container = openFrame.frame
                if container then
                    dragFrame:SetParent(container)
                    dragFrame:ClearAllPoints()
                    dragFrame:SetAllPoints(container)
                    -- Ensure frame is on top after parenting
                    dragFrame:SetFrameStrata("FULLSCREEN_DIALOG")
                    dragFrame:SetFrameLevel(10000)
                    dragFrame:Show()
                else
                    dragFrame:Hide()
                end
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
        
        -- Hook into AceConfigDialog to update position and name frames
        if AceConfigDialog.Open then
            local originalOpen = AceConfigDialog.Open
            AceConfigDialog.Open = function(self, appName, ...)
                local result = originalOpen(self, appName, ...)
                if appName == ADDON_NAME then
                    -- Rebuild tracked items list when config opens (only once)
                    C_Timer.After(0.2, function()
                        if NephUI.RebuildTrackedItemsList then
                            NephUI:RebuildTrackedItemsList()
                        end
                    end)
                    
                    -- Store frame references with names for easier debugging and apply scale protection
                    C_Timer.After(0.1, function()
                        local openFrame = AceConfigDialog.OpenFrames[ADDON_NAME]
                        if openFrame and openFrame.frame then
                            local frame = openFrame.frame
                            -- Store named references
                            if not _G["NephUI_ConfigFrame"] then
                                _G["NephUI_ConfigFrame"] = frame
                            end
                            
                            -- Apply scale protection to keep config panel at constant size
                            NephUI:ApplyConfigPanelScaleProtection(frame)
                            
                            -- Hook OnShow to reapply scale protection whenever the frame is shown
                            local originalOnShow = frame:GetScript("OnShow")
                            frame:SetScript("OnShow", function(self)
                                if originalOnShow then
                                    originalOnShow(self)
                                end
                                -- Reapply scale protection when shown to ensure it's always correct
                                NephUI:ApplyConfigPanelScaleProtection(self)
                            end)
                            
                            -- Hook OnHide to disable unit frame anchors when config panel closes
                            local originalOnHide = frame:GetScript("OnHide")
                            frame:SetScript("OnHide", function(self)
                                if originalOnHide then
                                    originalOnHide(self)
                                end
                                -- Disable unit frame anchors when config panel closes
                                NephUI:DisableUnitFrameAnchorsOnConfigClose()
                            end)
                            
                            -- Try to find and name child frames by storing references
                            local function StoreFrameReferences(parent, depth)
                                depth = depth or 0
                                if depth > 5 then return end
                                
                                local children = {parent:GetChildren()}
                                for i, child in ipairs(children) do
                                    if child:IsObjectType("ScrollFrame") and not _G["NephUI_ConfigScrollFrame"] then
                                        _G["NephUI_ConfigScrollFrame"] = child
                                    elseif child:IsObjectType("Frame") and not _G["NephUI_ConfigContentFrame_" .. i] then
                                        _G["NephUI_ConfigContentFrame_" .. i] = child
                                    end
                                    StoreFrameReferences(child, depth + 1)
                                end
                            end
                            StoreFrameReferences(frame, 0)
                        end
                    end)
                    
                    -- Initial update
                    UpdateDragDropFrame()
                end
                
                -- Add support links to bottom status bar and make EditBoxes read-only
                C_Timer.After(0.4, function()
                    local openFrame = AceConfigDialog.OpenFrames[ADDON_NAME]
                    if openFrame then
                        -- Find the status text - check both widget and frame
                        local statusText = nil
                        local windowFrame = openFrame.frame
                        
                        -- Try widget first (AceGUI widget structure)
                        if openFrame.statustext then
                            statusText = openFrame.statustext
                        -- Try frame next
                        elseif windowFrame and windowFrame.statustext then
                            statusText = windowFrame.statustext
                        end
                        
                        -- If still not found, search for it
                        if not statusText and windowFrame then
                            local function FindStatusText(parent, depth)
                                depth = depth or 0
                                if depth > 5 then return nil end
                                if not parent or type(parent) ~= "userdata" then return nil end
                                
                                -- Check if this is the status text (FontString near bottom)
                                if parent:IsObjectType("FontString") then
                                    local point, relativeTo, relativePoint = parent:GetPoint()
                                    if point and (string.find(point:lower() or "", "bottom") or string.find(point:lower() or "", "left")) then
                                        return parent
                                    end
                                end
                                
                                local children = {parent:GetChildren()}
                                for _, child in ipairs(children) do
                                    local found = FindStatusText(child, depth + 1)
                                    if found then return found end
                                end
                                return nil
                            end
                            statusText = FindStatusText(windowFrame, 0)
                        end
                        
                        -- If we still don't have status text, find statusbg and create text on it
                        if not statusText and windowFrame then
                            local statusBg = nil
                            if windowFrame.statusbg then
                                statusBg = windowFrame.statusbg
                            elseif openFrame.statusbg then
                                statusBg = openFrame.statusbg
                            else
                                -- Search for status background frame (button near bottom left)
                                local function FindStatusBg(parent, depth)
                                    depth = depth or 0
                                    if depth > 5 then return nil end
                                    if not parent or type(parent) ~= "userdata" then return nil end
                                    
                                    if parent:IsObjectType("Button") or parent:IsObjectType("Frame") then
                                        local point, relativeTo, relativePoint = parent:GetPoint()
                                        if point and string.find(point:lower() or "", "bottom") then
                                            local height = parent:GetHeight()
                                            if height and height > 20 and height < 30 then
                                                return parent
                                            end
                                        end
                                    end
                                    
                                    local children = {parent:GetChildren()}
                                    for _, child in ipairs(children) do
                                        local found = FindStatusBg(child, depth + 1)
                                        if found then return found end
                                    end
                                    return nil
                                end
                                statusBg = FindStatusBg(windowFrame, 0)
                            end
                            
                            if statusBg then
                                -- Create status text on the status background
                                statusText = statusBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                statusText:SetPoint("LEFT", statusBg, "LEFT", 10, 0)
                                statusText:SetPoint("RIGHT", statusBg, "RIGHT", -10, 0)
                                statusText:SetJustifyH("LEFT")
                            end
                        end
                        
                        -- Set the support links text
                        if statusText then
                            local supportText = "|cffffd700Support the development:|r |cff00ff00https://www.patreon.com/c/Nephuhlim|r |cff00ff00https://buymeacoffee.com/neph|r"
                            statusText:SetText(supportText)
                        end
                        
                        -- Support links configuration for EditBoxes (Discord link)
                        local supportLinks = {
                            {pattern = "discord%.gg", text = "https://discord.gg/Mc2StWHKya"},
                        }
                        
                        -- Find and make support link EditBoxes read-only
                        local function FindEditBox(parent, depth)
                            depth = depth or 0
                            if depth > 10 then return nil end
                            
                            -- Handle AceGUI widgets (tables) vs WoW Frames
                            local frame = parent
                            if type(parent) == "table" and parent.frame and type(parent.frame) == "userdata" then
                                -- This is an AceGUI widget, get the actual frame
                                frame = parent.frame
                                -- Also check if this widget has an editbox property directly (AceGUI EditBox)
                                if parent.editbox and parent.type == "EditBox" then
                                    local text = parent.editbox:GetText()
                                    for _, linkInfo in ipairs(supportLinks) do
                                        if text and text:find(linkInfo.pattern) then
                                            local originalText = linkInfo.text
                                            parent.editbox:SetScript("OnTextChanged", function(self, userInput)
                                                if userInput and self:GetText() ~= originalText then
                                                    C_Timer.After(0, function()
                                                        self:SetText(originalText)
                                                        self:HighlightText()
                                                    end)
                                                end
                                            end)
                                            parent.editbox:SetScript("OnEditFocusGained", function(self)
                                                self:HighlightText()
                                            end)
                                            return parent.editbox
                                        end
                                    end
                                end
                            end
                            
                            -- Only proceed if we have a valid Frame object
                            if not frame or type(frame) ~= "userdata" or not frame.GetChildren then
                                return nil
                            end
                            
                            local children = {frame:GetChildren()}
                            for _, child in ipairs(children) do
                                if child:IsObjectType("EditBox") then
                                    -- Check if this is a support link EditBox
                                    local text = child:GetText()
                                    for _, linkInfo in ipairs(supportLinks) do
                                        if text and text:find(linkInfo.pattern) then
                                            -- Make it read-only by preventing text changes
                                            local originalText = linkInfo.text
                                            child:SetScript("OnTextChanged", function(self, userInput)
                                                if userInput and self:GetText() ~= originalText then
                                                    -- Reset to original text if user tries to change it
                                                    C_Timer.After(0, function()
                                                        self:SetText(originalText)
                                                        self:HighlightText()
                                                    end)
                                                end
                                            end)
                                            -- Auto-select all text on focus for easy copying
                                            child:SetScript("OnEditFocusGained", function(self)
                                                self:HighlightText()
                                            end)
                                            return child
                                        end
                                    end
                                end
                                local found = FindEditBox(child, depth + 1)
                                if found then return found end
                            end
                            
                            -- Also check widgets if parent has children table (AceGUI widgets)
                            if type(parent) == "table" and parent.children then
                                for _, widget in pairs(parent.children) do
                                    local found = FindEditBox(widget, depth + 1)
                                    if found then return found end
                                end
                            end
                            
                            return nil
                        end
                        -- Call recursively to find all support link EditBoxes
                        local function FindAllEditBoxes(parent, depth)
                            depth = depth or 0
                            if depth > 10 then return end
                            FindEditBox(parent, depth)
                            if type(parent) == "table" and parent.frame and type(parent.frame) == "userdata" then
                                FindAllEditBoxes(parent.frame, depth + 1)
                                if parent.children then
                                    for _, widget in pairs(parent.children) do
                                        FindAllEditBoxes(widget, depth + 1)
                                    end
                                end
                            elseif type(parent) == "userdata" and parent.GetChildren then
                                local children = {parent:GetChildren()}
                                for _, child in ipairs(children) do
                                    FindAllEditBoxes(child, depth + 1)
                                end
                            end
                        end
                        FindAllEditBoxes(openFrame, 0)
                    end
                end)
                
                return result
            end
        end
        
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
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
        if AceConfigRegistry then
            local app = AceConfigRegistry:GetOptionsTable(ADDON_NAME)
            if app then
                local options = app("dialog", "AceConfigDialog-3.0")
                if options and options.args and options.args.customIcons and 
                   options.args.customIcons.args and options.args.customIcons.args.general and
                   options.args.customIcons.args.general.args and options.args.customIcons.args.general.args.trackedItemsGroup then
                    self._trackedItemsGroup = options.args.customIcons.args.general.args.trackedItemsGroup
                end
            end
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
    
    -- Notify AceConfig to refresh
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange(ADDON_NAME)
    end
end


