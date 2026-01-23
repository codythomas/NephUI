local ADDON_NAME, ns = ...
local NephUI = ns.Addon

function ns.CreatePartyFrameOptions()
    if NephUI and NephUI.PartyFrames and NephUI.PartyFrames.BuildNephUIOptions then
        return NephUI.PartyFrames:BuildNephUIOptions("party", "Party Frames", 45)
    end

    return {
        type = "group",
        name = "Party Frames",
        order = 45,
        args = {
            fallback = {
                type = "description",
                name = "Party frame options are not available yet.",
                order = 1,
            },
        },
    }
end
