local ADDON_NAME, ns = ...
local NephUI = ns.Addon

function ns.CreateRaidFrameOptions()
    if NephUI and NephUI.PartyFrames and NephUI.PartyFrames.BuildNephUIOptions then
        return NephUI.PartyFrames:BuildNephUIOptions("raid", "Raid Frames", 46)
    end

    return {
        type = "group",
        name = "Raid Frames",
        order = 46,
        args = {
            fallback = {
                type = "description",
                name = "Raid frame options are not available yet.",
                order = 1,
            },
        },
    }
end
