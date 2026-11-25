local _, addon = ...

function addon.WithFlyoutModifier(key, modifier)
    local parts = {}
    while true do
        local prefix, rest = key:match("^(%u+)%-(.+)$")
        if prefix ~= "ALT" and prefix ~= "CTRL" and prefix ~= "SHIFT" then break end
        parts[prefix], key = true, rest
    end
    if parts[modifier] or key:match("^PAD") then return end
    parts[modifier] = true
    return (parts.ALT and "ALT-" or "") .. (parts.CTRL and "CTRL-" or "")
        .. (parts.SHIFT and "SHIFT-" or "") .. key
end

local function Unbound(action)
    -- WoW can save an explicitly cleared shortcut as NONE.
    return not action or action == "" or action == "NONE"
end

function addon.CanBindFlyout(savedAction, overrideAction, ownAction)
    return Unbound(savedAction) and (Unbound(overrideAction) or overrideAction == ownAction)
end

function addon.MigrateHoverModifier(db)
    if db.requireHoverModifier == nil then
        db.requireHoverModifier = db.shiftFlyouts == true
    end
    db.shiftFlyouts = nil
end
