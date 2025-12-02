local ADDON_NAME, ns = ...
local NephUI = ns.Addon

local function GetTrackedItemsEntries()
    local entries = {}
    local db = NephUI.db.profile.customIcons
    
    if db and db.trackedItems then
        for i, itemID in ipairs(db.trackedItems) do
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
                  itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
            
            local displayName = itemName or ("Item " .. itemID)
            local iconTexture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
            
            entries["item_" .. itemID] = {
                type = "group",
                name = function()
                    local iconStr = "|T" .. iconTexture .. ":16:16:0:0:64:64:4:60:4:60|t"
                    return string.format("%s %s (ID: %d)", iconStr, displayName, itemID)
                end,
                order = 10 + i,
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

local function CreateCustomIconOptions()
    return {
        type = "group",
        name = "Custom Icons",
        order = 6,
        childGroups = "tab",
        args = {
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
                            NephUI:RefreshCustomIcons()
                        end,
                    },
                    itemsCustomizationHeader = {
                        type = "header",
                        name = "Items Customization",
                        order = 10,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        desc = "Base size of each icon in pixels (longest dimension)",
                        order = 11,
                        width = "full",
                        min = 16, max = 96, step = 1,
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
                        order = 12,
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
                        order = 13,
                        width = "normal",
                        min = -20, max = 20, step = 1,
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
                        order = 14,
                        width = "normal",
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
                        order = 15,
                        width = "normal",
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
                        order = 16,
                        width = "normal",
                        min = 0, max = 5, step = 1,
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
                        order = 17,
                        width = "normal",
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
                        order = 18,
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
                        order = 19,
                        width = "normal",
                        min = -1000, max = 1000, step = 1,
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
                        order = 20,
                        width = "normal",
                        min = -1000, max = 1000, step = 1,
                        get = function() return NephUI.db.profile.customIcons.items.offsetY or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.items.offsetY = val
                            NephUI:ApplyCustomIconsLayout()
                        end,
                    },
                    hideUnusableItems = {
                        type = "toggle",
                        name = "Hide Unusable Items",
                        desc = "Hide items that are not currently usable",
                        order = 21,
                        width = "full",
                        get = function() return NephUI.db.profile.customIcons.items.hideUnusableItems or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.items.hideUnusableItems = val
                            NephUI:ApplyCustomIconsLayout()
                        end,
                    },
                    
                    countTextHeader = {
                        type = "header",
                        name = "Item Count Text",
                        order = 22,
                    },
                    countTextSize = {
                        type = "range",
                        name = "Count Text Size",
                        desc = "Font size of the item count text",
                        order = 23,
                        width = "full",
                        min = 8, max = 32, step = 1,
                        get = function() return NephUI.db.profile.customIcons.countTextSize or 16 end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.countTextSize = val
                            if NephUI.CustomIcons and NephUI.CustomIcons.UpdateCountTextStyling then
                                NephUI.CustomIcons:UpdateCountTextStyling()
                            end
                            NephUI:ApplyCustomIconsLayout()
                        end,
                    },
                    countTextX = {
                        type = "range",
                        name = "Count Text X Position",
                        desc = "Horizontal offset of the count text from bottom-right corner",
                        order = 24,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.customIcons.countTextX or -2 end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.countTextX = val
                            if NephUI.CustomIcons and NephUI.CustomIcons.UpdateCountTextStyling then
                                NephUI.CustomIcons:UpdateCountTextStyling()
                            end
                            NephUI:ApplyCustomIconsLayout()
                        end,
                    },
                    countTextY = {
                        type = "range",
                        name = "Count Text Y Position",
                        desc = "Vertical offset of the count text from bottom-right corner",
                        order = 25,
                        width = "normal",
                        min = -50, max = 50, step = 1,
                        get = function() return NephUI.db.profile.customIcons.countTextY or 2 end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.countTextY = val
                            if NephUI.CustomIcons and NephUI.CustomIcons.UpdateCountTextStyling then
                                NephUI.CustomIcons:UpdateCountTextStyling()
                            end
                            NephUI:ApplyCustomIconsLayout()
                        end,
                    },
                    
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 26,
                    },
                    
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
                    
                    trinketsCustomizationHeader = {
                        type = "header",
                        name = "Trinkets Customization",
                        order = 10,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        desc = "Base size of each icon in pixels (longest dimension)",
                        order = 11,
                        width = "full",
                        min = 16, max = 96, step = 1,
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
                        order = 12,
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
                        order = 13,
                        width = "normal",
                        min = -20, max = 20, step = 1,
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
                        order = 14,
                        width = "normal",
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
                        order = 15,
                        width = "normal",
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
                        order = 16,
                        width = "normal",
                        min = 0, max = 5, step = 1,
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
                        order = 17,
                        width = "normal",
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
                        order = 18,
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
                        order = 19,
                        width = "normal",
                        min = -1000, max = 1000, step = 1,
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
                        order = 20,
                        width = "normal",
                        min = -1000, max = 1000, step = 1,
                        get = function() return NephUI.db.profile.customIcons.trinkets.offsetY or 0 end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.offsetY = val
                            NephUI:ApplyTrinketsLayout()
                        end,
                    },
                    hideUnusableItems = {
                        type = "toggle",
                        name = "Hide Unusable Items",
                        desc = "Hide items that are not currently usable",
                        order = 21,
                        width = "full",
                        get = function() return NephUI.db.profile.customIcons.trinkets.hideUnusableItems or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.hideUnusableItems = val
                            NephUI:ApplyTrinketsLayout()
                        end,
                    },
                    
                    trackingHeader = {
                        type = "header",
                        name = "Tracking Options",
                        order = 30,
                    },
                    trinket1 = {
                        type = "toggle",
                        name = "Track Trinket Slot 1",
                        desc = "Track cooldowns for the item in trinket slot 1",
                        width = "full",
                        order = 31,
                        get = function() return NephUI.db.profile.customIcons.trinkets.trinket1 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.trinket1 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshCustomIcons()
                        end,
                    },
                    trinket2 = {
                        type = "toggle",
                        name = "Track Trinket Slot 2",
                        desc = "Track cooldowns for the item in trinket slot 2",
                        width = "full",
                        order = 32,
                        get = function() return NephUI.db.profile.customIcons.trinkets.trinket2 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.trinket2 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshCustomIcons()
                        end,
                    },
                    weapon1 = {
                        type = "toggle",
                        name = "Track Weapon Slot 1",
                        desc = "Track cooldowns for the item in weapon slot 1 (main hand)",
                        width = "full",
                        order = 33,
                        get = function() return NephUI.db.profile.customIcons.trinkets.weapon1 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.weapon1 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshCustomIcons()
                        end,
                    },
                    weapon2 = {
                        type = "toggle",
                        name = "Track Weapon Slot 2",
                        desc = "Track cooldowns for the item in weapon slot 2 (off hand)",
                        width = "full",
                        order = 34,
                        get = function() return NephUI.db.profile.customIcons.trinkets.weapon2 or false end,
                        set = function(_, val)
                            NephUI.db.profile.customIcons.trinkets.weapon2 = val
                            if NephUI.UpdateTrinketWeaponTracking then
                                NephUI:UpdateTrinketWeaponTracking()
                            end
                            NephUI:RefreshCustomIcons()
                        end,
                    },
                },
            },
        },
    }
end
ns.CreateCustomIconOptions = CreateCustomIconOptions
ns.GetTrackedItemsEntries = GetTrackedItemsEntries


