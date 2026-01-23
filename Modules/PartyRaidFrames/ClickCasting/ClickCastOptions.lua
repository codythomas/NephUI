--[[
    NephUI Unit Frames - Click Cast Options
    Configuration interface for click casting
]]

local ADDON_NAME, ns = ...
local NephUI = ns.Addon
NephUI.PartyFrames = NephUI.PartyFrames or {}
local UnitFrames = NephUI.PartyFrames

-- ============================================================================
-- CLICK CAST OPTIONS TABLE
-- ============================================================================

--[[
    Build click cast options for NephUI config
    @return table - AceConfig options table
]]
function UnitFrames:BuildClickCastOptions()
    return {
        type = "group",
        name = "Click Casting",
        order = 47,
        args = {
            description = {
                type = "description",
                name = "Configure mouse button bindings for casting spells on unit frames.",
                order = 1,
            },
            enabledHeader = {
                type = "header",
                name = "General",
                order = 2,
            },
            clickCastEnabled = {
                type = "toggle",
                name = "Enable Click Casting",
                desc = "Enable built-in click casting functionality",
                order = 3,
                width = "full",
                get = function() return self:GetDB().clickCastEnabled end,
                set = function(_, val)
                    self:GetDB().clickCastEnabled = val
                    if val then
                        self:UpdateAllClickCastFrames()
                    else
                        for frame in pairs(self.ClickCastFrames) do
                            self:ClearClickCastFromFrame(frame)
                        end
                    end
                end,
            },
            useClique = {
                type = "toggle",
                name = "Use Clique (if installed)",
                desc = "Let Clique handle click casting instead of built-in system",
                order = 4,
                width = "full",
                get = function() return self:GetDB().useClique end,
                set = function(_, val)
                    self:GetDB().useClique = val
                    if val then
                        self:RegisterWithClique()
                    end
                end,
            },
            bindingsHeader = {
                type = "header",
                name = "Bindings",
                order = 10,
            },
            bindingsDesc = {
                type = "description",
                name = "Current bindings:",
                order = 11,
            },
            bindingsList = {
                type = "description",
                name = function()
                    local bindings = {}
                    for key, binding in pairs(self.ClickCastBindings or {}) do
                        local mod = binding.modifier ~= "" and (binding.modifier .. " + ") or ""
                        local btn = binding.button:gsub("Button", "")
                        table.insert(bindings, "  " .. mod .. btn .. " = " .. binding.spell)
                    end
                    if #bindings == 0 then
                        return "  (No bindings configured)"
                    end
                    return table.concat(bindings, "\n")
                end,
                order = 12,
            },
            newBindingHeader = {
                type = "header",
                name = "Add Binding",
                order = 20,
            },
            newButton = {
                type = "select",
                name = "Mouse Button",
                order = 21,
                values = {
                    LeftButton = "Left Button",
                    RightButton = "Right Button",
                    MiddleButton = "Middle Button",
                    Button4 = "Button 4",
                    Button5 = "Button 5",
                },
                get = function() return self.tempBinding and self.tempBinding.button or "LeftButton" end,
                set = function(_, val)
                    self.tempBinding = self.tempBinding or {}
                    self.tempBinding.button = val
                end,
            },
            newModifier = {
                type = "select",
                name = "Modifier",
                order = 22,
                values = {
                    [""] = "None",
                    shift = "Shift",
                    ctrl = "Ctrl",
                    alt = "Alt",
                    ["shift-ctrl"] = "Shift + Ctrl",
                    ["shift-alt"] = "Shift + Alt",
                    ["ctrl-alt"] = "Ctrl + Alt",
                },
                get = function() return self.tempBinding and self.tempBinding.modifier or "" end,
                set = function(_, val)
                    self.tempBinding = self.tempBinding or {}
                    self.tempBinding.modifier = val
                end,
            },
            newSpell = {
                type = "input",
                name = "Spell Name",
                desc = "Enter the spell name to cast",
                order = 23,
                width = "double",
                get = function() return self.tempBinding and self.tempBinding.spell or "" end,
                set = function(_, val)
                    self.tempBinding = self.tempBinding or {}
                    self.tempBinding.spell = val
                end,
            },
            addBinding = {
                type = "execute",
                name = "Add Binding",
                order = 24,
                func = function()
                    if self.tempBinding and self.tempBinding.button and self.tempBinding.spell and self.tempBinding.spell ~= "" then
                        self:SetClickCastBinding(
                            self.tempBinding.button,
                            self.tempBinding.modifier or "",
                            self.tempBinding.spell,
                            false
                        )
                        self.tempBinding = nil
                    end
                end,
            },
            clearAllBindings = {
                type = "execute",
                name = "Clear All Bindings",
                order = 25,
                confirm = true,
                confirmText = "Are you sure you want to clear all click cast bindings?",
                func = function()
                    self:ClearAllClickCastBindings()
                end,
            },
            presetsHeader = {
                type = "header",
                name = "Presets",
                order = 30,
            },
            loadHealerDefaults = {
                type = "execute",
                name = "Load Healer Defaults",
                desc = "Load default click cast bindings for your class (healer spec)",
                order = 31,
                func = function()
                    self:SetupHealerDefaults()
                end,
            },
        },
    }
end

--[[
    Create click cast options for NephUI config system
    @return table - AceConfig options table
]]
function ns.CreateClickCastOptions()
    if UnitFrames and UnitFrames.BuildClickCastOptions then
        return UnitFrames:BuildClickCastOptions()
    end
    
    return {
        type = "group",
        name = "Click Casting",
        order = 47,
        args = {
            fallback = {
                type = "description",
                name = "Click casting options are not available yet.",
                order = 1,
            },
        },
    }
end
