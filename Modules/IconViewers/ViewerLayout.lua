local ADDON_NAME, ns = ...
local NephUI = ns.Addon

local IconViewers = NephUI.IconViewers
if not IconViewers then
    error("NephUI: IconViewers module not initialized! Load IconViewers.lua first.")
end

local ceil = math.ceil
local abs = math.abs

local DIRECTION_RULES = {
    CENTERED_HORIZONTAL = { type = "HORIZONTAL", defaultSecondary = "DOWN", allowed = { UP = true, DOWN = true } },
    LEFT                = { type = "HORIZONTAL", defaultSecondary = "DOWN", allowed = { UP = true, DOWN = true } },
    RIGHT               = { type = "HORIZONTAL", defaultSecondary = "DOWN", allowed = { UP = true, DOWN = true } },
    UP                  = { type = "VERTICAL",   defaultSecondary = "RIGHT", allowed = { LEFT = true, RIGHT = true } },
    DOWN                = { type = "VERTICAL",   defaultSecondary = "RIGHT", allowed = { LEFT = true, RIGHT = true } },
    STATIC              = { type = "STATIC" },
}

IconViewers.__cdmTrackedViewers = IconViewers.__cdmTrackedViewers or {}
local trackedViewers = IconViewers.__cdmTrackedViewers

local function ResetTrackedViewerAnchors()
    if not trackedViewers then return end

    for viewer in pairs(trackedViewers) do
        if viewer and viewer.GetName then
            viewer.__cdmAnchorShiftX = 0
            viewer.__cdmAnchorShiftY = 0
            IconViewers:ApplyViewerLayout(viewer)
        else
            trackedViewers[viewer] = nil
        end
    end
end

local function EnsureEditModeHooks()
    if IconViewers.__cdmEditHooksInstalled then return end

    if not EditModeManagerFrame then
        if IsLoggedIn and IsLoggedIn() then
            if not IconViewers.__cdmEditHookTimer then
                IconViewers.__cdmEditHookTimer = true
                C_Timer.After(0.25, function()
                    IconViewers.__cdmEditHookTimer = nil
                    EnsureEditModeHooks()
                end)
            end
        elseif not IconViewers.__cdmEditHookListener then
            local listener = CreateFrame("Frame")
            listener:RegisterEvent("PLAYER_LOGIN")
            listener:SetScript("OnEvent", function(self)
                if EditModeManagerFrame then
                    EnsureEditModeHooks()
                    self:UnregisterAllEvents()
                    self:SetScript("OnEvent", nil)
                end
            end)
            IconViewers.__cdmEditHookListener = listener
        end
        return
    end

    IconViewers.__cdmEditHooksInstalled = true
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", ResetTrackedViewerAnchors)
end

local function TrackViewer(viewer)
    if not viewer then return end
    trackedViewers[viewer] = true
    EnsureEditModeHooks()
end

local function IsCooldownIconFrame(frame)
    return frame and (frame.icon or frame.Icon) and frame.Cooldown
end

local function NormalizeDirectionToken(token)
    if not token or token == "" then
        return nil
    end

    local aliases = {
        CENTEREDHORIZONTAL = "CENTERED_HORIZONTAL",
        CENTERHORIZONTAL   = "CENTERED_HORIZONTAL",
        CENTERED           = "CENTERED_HORIZONTAL",
        CENTER             = "CENTERED_HORIZONTAL",
        CENTRED            = "CENTERED_HORIZONTAL",
        CENTRE             = "CENTERED_HORIZONTAL",
    }

    local cleaned = token:gsub("[%s%-_]+", ""):upper()
    return aliases[cleaned] or cleaned
end

local function ClampRowLimit(value)
    if not value or value <= 0 then
        return 0
    end
    return math.floor(value + 0.0001)
end

local function ResolveDirections(viewerName, settings)
    local primary = NormalizeDirectionToken(settings.primaryDirection)
    local secondary = NormalizeDirectionToken(settings.secondaryDirection)

    local legacyDirection = settings.growthDirection
    if not primary and legacyDirection then
        if legacyDirection == "Static" or legacyDirection == "STATIC" then
            primary = "STATIC"
        elseif legacyDirection:match("^Centered Horizontal and") then
            primary = "CENTERED_HORIZONTAL"
            local token = legacyDirection:match("and%s+(.+)$")
            secondary = NormalizeDirectionToken(token)
        elseif legacyDirection == "Centered Horizontal" then
            primary = "CENTERED_HORIZONTAL"
        else
            local p = legacyDirection:match("^(%w+)")
            primary = NormalizeDirectionToken(p)
            local s = legacyDirection:match("and%s+(.+)$")
            secondary = NormalizeDirectionToken(s)
        end
    end

    if not primary and viewerName == "BuffIconCooldownViewer" and settings.rowGrowDirection then
        primary = "CENTERED_HORIZONTAL"
        if type(settings.rowGrowDirection) == "string" and settings.rowGrowDirection:lower() == "up" then
            secondary = "UP"
        else
            secondary = "DOWN"
        end
    end

    primary = primary or "CENTERED_HORIZONTAL"
    local rule = DIRECTION_RULES[primary]
    if not rule then
        primary = "CENTERED_HORIZONTAL"
        rule = DIRECTION_RULES[primary]
    end

    local rowLimit = ClampRowLimit(settings.rowLimit or 0)

    if rule.type ~= "STATIC" and rowLimit > 0 then
        if not secondary or not rule.allowed[secondary] then
            secondary = rule.defaultSecondary
        end
    else
        secondary = nil
    end

    return primary, secondary, rowLimit, rule.type
end

local function ComputeIconDimensions(settings)
    local iconSize = (settings.iconSize or 32) + 0.1
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
    local iconHeight = iconSize

    if aspectRatioValue and aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            iconHeight = iconSize / aspectRatioValue
        elseif aspectRatioValue < 1.0 then
            iconWidth = iconSize * aspectRatioValue
        end
    end

    return iconWidth, iconHeight
end

local function ComputeSpacing(settings)
    local spacing = settings.spacing or 4
    return spacing - 10
end

local function BuildDirectionKey(primary, secondary, rowLimit)
    return string.format("%s_%s_%d", primary or "CENTERED_HORIZONTAL", secondary or "NONE", rowLimit or 0)
end

local function BuildAppearanceKey(iconWidth, iconHeight, spacing)
    return string.format("%.3f:%.3f:%.3f", iconWidth or 0, iconHeight or 0, spacing or 0)
end

local function PrepareIconOrder(viewerName, icons)
    if viewerName == "BuffIconCooldownViewer" then
        for index, icon in ipairs(icons) do
            if not icon.layoutIndex and not icon:GetID() then
                icon.__cdmCreationOrder = icon.__cdmCreationOrder or index
            end
        end
    end

    table.sort(icons, function(a, b)
        local la = a.layoutIndex or a:GetID() or a.__cdmCreationOrder or 0
        local lb = b.layoutIndex or b:GetID() or b.__cdmCreationOrder or 0
        if la == lb then
            return (a.__cdmCreationOrder or 0) < (b.__cdmCreationOrder or 0)
        end
        return la < lb
    end)
end

local function LayoutHorizontal(icons, container, primary, secondary, iconWidth, iconHeight, spacing, rowLimit)
    local count = #icons
    if count == 0 then return 0, 0, 0 end

    local iconsPerRow = rowLimit > 0 and math.max(1, rowLimit) or count
    local numRows = ceil(count / iconsPerRow)
    local horizontalSpacing = iconWidth + spacing
    local verticalSpacing = iconHeight + spacing
    local rowDirection = (secondary == "UP") and 1 or -1

    local rowMeta = {}
    local maxRowWidth = 0
    for row = 1, numRows do
        local rowStart = (row - 1) * iconsPerRow + 1
        local rowEnd = math.min(row * iconsPerRow, count)
        local rowCount = rowEnd - rowStart + 1
        local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
        if rowWidth < iconWidth then
            rowWidth = iconWidth
        end
        if rowWidth > maxRowWidth then
            maxRowWidth = rowWidth
        end
        rowMeta[row] = { startIndex = rowStart, count = rowCount, width = rowWidth }
    end

    local totalHeight = (numRows - 1) * verticalSpacing + iconHeight
    local anchorY
    if rowDirection == -1 then
        anchorY = (totalHeight / 2) - (iconHeight / 2)
    else
        anchorY = -(totalHeight / 2) + (iconHeight / 2)
    end

    local leftEdge = -(maxRowWidth / 2) + (iconWidth / 2)
    local rightEdge = (maxRowWidth / 2) - (iconWidth / 2)

    for row = 1, numRows do
        local meta = rowMeta[row]
        local rowOffset = anchorY + (row - 1) * verticalSpacing * rowDirection
        local baseX
        if primary == "CENTERED_HORIZONTAL" then
            baseX = -meta.width / 2 + iconWidth / 2
        elseif primary == "RIGHT" then
            baseX = leftEdge
        else -- LEFT
            baseX = rightEdge
        end

        for position = 0, meta.count - 1 do
            local icon = icons[meta.startIndex + position]
            local x
            if primary == "LEFT" then
                x = baseX - position * horizontalSpacing
            else
                x = baseX + position * horizontalSpacing
            end

            icon:SetPoint("CENTER", container, "CENTER", x, rowOffset)
        end
    end

    return maxRowWidth, totalHeight, anchorY
end

local function LayoutVertical(icons, container, primary, secondary, iconWidth, iconHeight, spacing, rowLimit)
    local count = #icons
    if count == 0 then return 0, 0, 0 end

    local iconsPerColumn = rowLimit > 0 and math.max(1, rowLimit) or count
    local numColumns = ceil(count / iconsPerColumn)
    local horizontalSpacing = iconWidth + spacing
    local verticalSpacing = iconHeight + spacing
    local columnDirection = (secondary == "LEFT") and -1 or 1
    local verticalDirection = (primary == "UP") and 1 or -1

    local columnMeta = {}
    local maxColumnCount = 0
    for column = 1, numColumns do
        local columnStart = (column - 1) * iconsPerColumn + 1
        local columnEnd = math.min(column * iconsPerColumn, count)
        local columnCount = columnEnd - columnStart + 1
        if columnCount > maxColumnCount then
            maxColumnCount = columnCount
        end
        columnMeta[column] = { startIndex = columnStart, count = columnCount }
    end

    local totalWidth = (numColumns - 1) * horizontalSpacing + iconWidth
    local totalHeight = (maxColumnCount - 1) * verticalSpacing + iconHeight

    local anchorX
    if columnDirection == 1 then
        anchorX = -(totalWidth / 2) + (iconWidth / 2)
    else
        anchorX = (totalWidth / 2) - (iconWidth / 2)
    end

    local anchorY
    if verticalDirection == -1 then
        anchorY = (totalHeight / 2) - (iconHeight / 2)
    else
        anchorY = -(totalHeight / 2) + (iconHeight / 2)
    end

    for column = 1, numColumns do
        local meta = columnMeta[column]
        local x = anchorX + (column - 1) * horizontalSpacing * columnDirection

        for position = 0, meta.count - 1 do
            local icon = icons[meta.startIndex + position]
            local y = anchorY + position * verticalSpacing * verticalDirection
            icon:SetPoint("CENTER", container, "CENTER", x, y)
        end
    end

    return totalWidth, totalHeight, anchorX
end

local function AdjustViewerAnchor(viewer, shiftX, shiftY)
    shiftX = shiftX or 0
    shiftY = shiftY or 0

    local prevX = viewer.__cdmAnchorShiftX or 0
    local prevY = viewer.__cdmAnchorShiftY or 0
    local deltaX = shiftX - prevX
    local deltaY = shiftY - prevY

    if deltaX == 0 and deltaY == 0 then return end
    if InCombatLockdown() then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = viewer:GetPoint(1)
    if not point then return end

    viewer:ClearAllPoints()
    viewer:SetPoint(point, relativeTo, relativePoint, (xOfs or 0) - deltaX, (yOfs or 0) - deltaY)
    viewer.__cdmAnchorShiftX = shiftX
    viewer.__cdmAnchorShiftY = shiftY
end

function IconViewers:ApplyViewerLayout(viewer)
    if not viewer or not viewer.GetName then return end

    local name = viewer:GetName()
    local settings = NephUI.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    TrackViewer(viewer)

    local container = viewer.viewerFrame or viewer
    local icons = {}

    for _, child in ipairs({ container:GetChildren() }) do
        if IsCooldownIconFrame(child) and child:IsShown() then
            table.insert(icons, child)
        end
    end

    local count = #icons
    if count == 0 then return end

    if viewer.__cdmLayoutRunning then
        return
    end
    viewer.__cdmLayoutRunning = true
    local function finishLayout()
        viewer.__cdmLayoutRunning = nil
    end

    PrepareIconOrder(name, icons)

    local iconWidth, iconHeight = ComputeIconDimensions(settings)
    local spacing = ComputeSpacing(settings)
    local primary, secondary, rowLimit, layoutType = ResolveDirections(name, settings)
    local directionKey = BuildDirectionKey(primary, secondary, rowLimit)
    local appearanceKey = BuildAppearanceKey(iconWidth, iconHeight, spacing)

    if name == "BuffIconCooldownViewer" and primary == "STATIC" then
        for _, icon in ipairs(icons) do
            icon:SetWidth(iconWidth)
            icon:SetHeight(iconHeight)
            icon:SetSize(iconWidth, iconHeight)
        end
        viewer.__cdmLastGrowthDirection = directionKey
        viewer.__cdmLastAppearanceKey = appearanceKey
        AdjustViewerAnchor(viewer, 0, 0)
        finishLayout()
        return
    end

    for _, icon in ipairs(icons) do
        icon:ClearAllPoints()
        icon:SetWidth(iconWidth)
        icon:SetHeight(iconHeight)
        icon:SetSize(iconWidth, iconHeight)
    end

    local totalWidth, totalHeight, anchorShift
    if layoutType == "VERTICAL" then
        totalWidth, totalHeight, anchorShift = LayoutVertical(icons, container, primary, secondary, iconWidth, iconHeight, spacing, rowLimit)
    else
        totalWidth, totalHeight, anchorShift = LayoutHorizontal(icons, container, primary, secondary, iconWidth, iconHeight, spacing, rowLimit)
    end

    viewer.__cdmIconWidth = totalWidth
    viewer.__cdmIconHeight = totalHeight
    viewer.__cdmLastGrowthDirection = directionKey
    viewer.__cdmLastAppearanceKey = appearanceKey

    if not InCombatLockdown() then
        viewer.__cdmLayoutSuppressed = (viewer.__cdmLayoutSuppressed or 0) + 1
        viewer:SetSize(totalWidth, totalHeight)
        viewer.__cdmLayoutSuppressed = viewer.__cdmLayoutSuppressed - 1
        if viewer.__cdmLayoutSuppressed <= 0 then
            viewer.__cdmLayoutSuppressed = nil
        end
    end

    if layoutType == "VERTICAL" then
        AdjustViewerAnchor(viewer, anchorShift, 0)
    else
        AdjustViewerAnchor(viewer, 0, anchorShift)
    end

    finishLayout()
end

function IconViewers:RescanViewer(viewer)
    if not viewer or not viewer.GetName then return end

    local name = viewer:GetName()
    local settings = NephUI.db.profile.viewers[name]
    if not settings or not settings.enabled then return end

    TrackViewer(viewer)

    local container = viewer.viewerFrame or viewer
    local icons = {}
    local changed = false
    local inCombat = InCombatLockdown()
    local collectAllIcons = (name == "BuffIconCooldownViewer")

    for _, child in ipairs({ container:GetChildren() }) do
        if IsCooldownIconFrame(child) then
            if collectAllIcons or child:IsShown() then
                table.insert(icons, child)

                if not child.__cdmSkinned and not child.__cdmSkinPending then
                    child.__cdmSkinPending = true

                    if inCombat then
                        NephUI.__cdmPendingIcons = NephUI.__cdmPendingIcons or {}
                        NephUI.__cdmPendingIcons[child] = { icon = child, settings = settings, viewer = viewer }

                        if not NephUI.__cdmIconSkinEventFrame then
                            local eventFrame = CreateFrame("Frame")
                            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                            eventFrame:SetScript("OnEvent", function(self)
                                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                                if IconViewers.ProcessPendingIcons then
                                    IconViewers:ProcessPendingIcons()
                                end
                            end)
                            NephUI.__cdmIconSkinEventFrame = eventFrame
                        end
                        NephUI.__cdmIconSkinEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                    else
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

    PrepareIconOrder(name, icons)
    local count = #icons

    local iconWidth, iconHeight = ComputeIconDimensions(settings)
    local spacing = ComputeSpacing(settings)
    local primary, secondary, rowLimit = ResolveDirections(name, settings)
    local directionKey = BuildDirectionKey(primary, secondary, rowLimit)
    local appearanceKey = BuildAppearanceKey(iconWidth, iconHeight, spacing)

    if viewer.__cdmLastGrowthDirection ~= directionKey then
        viewer.__cdmLastGrowthDirection = directionKey
        changed = true
    end

    if viewer.__cdmLastAppearanceKey ~= appearanceKey then
        viewer.__cdmLastAppearanceKey = appearanceKey
        changed = true
    end

    if viewer.__cdmIconCount ~= count then
        viewer.__cdmIconCount = count
        changed = true
    end

    if name == "BuffIconCooldownViewer" and not changed and count > 1 then
        local expectedSpacing = iconWidth + spacing - 1
        for i = 1, count - 1 do
            local iconA = icons[i]
            local iconB = icons[i + 1]
            if iconA and iconB then
                local x1 = iconA:GetCenter()
                local x2 = iconB:GetCenter()
                if x1 and x2 then
                    local actualSpacing = abs(x2 - x1)
                    if abs(actualSpacing - expectedSpacing) > 1 then
                        changed = true
                        break
                    end
                end
            end
        end
    end

    if changed then
        self:ApplyViewerLayout(viewer)

        if NephUI.ResourceBars and NephUI.ResourceBars.UpdatePowerBar then
            NephUI.ResourceBars:UpdatePowerBar()
        end
        if NephUI.ResourceBars and NephUI.ResourceBars.UpdateSecondaryPowerBar then
            NephUI.ResourceBars:UpdateSecondaryPowerBar()
        end
    end
end

NephUI.ApplyViewerLayout = function(self, viewer) return IconViewers:ApplyViewerLayout(viewer) end
NephUI.RescanViewer = function(self, viewer) return IconViewers:RescanViewer(viewer) end
