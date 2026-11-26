local _, addon = ...

function addon.StartGatheringReminder()
    local status = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
    addon.gatheringStatus = status

    function addon.RefreshGatheringReminder(repaint)
        if InCombatLockdown() then return end
        local spell
        if TotemButtonsDB and TotemButtonsDB.showGatheringTrackingOnButtons ~= false then
            for index = 1, C_Minimap.GetNumTrackingTypes() do
                local info = C_Minimap.GetTrackingInfo(index)
                if info and (info.spellID == 2383 or info.spellID == 2580) then
                    if info.active then
                        spell = nil
                        break
                    end
                    -- Prefer minerals when both options are available.
                    if not spell or info.spellID == 2580 then spell = info.spellID end
                end
            end
        end
        if status:GetAttribute("spell") ~= spell then
            status:SetAttribute("spell", spell)
            repaint = true
        end
        if repaint then addon.OnGatheringReminderChanged() end
    end

    status:RegisterEvent("PLAYER_ENTERING_WORLD")
    status:RegisterEvent("PLAYER_REGEN_DISABLED")
    status:RegisterEvent("PLAYER_REGEN_ENABLED")
    status:RegisterEvent("SPELLS_CHANGED")
    status:RegisterEvent("MINIMAP_UPDATE_TRACKING")
    status:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            addon.gatheringInCombat = true
            if status:GetAttribute("spell") then addon.OnGatheringReminderChanged() end
        elseif event == "PLAYER_REGEN_ENABLED" then
            addon.gatheringInCombat = false
            addon.RefreshGatheringReminder(status:GetAttribute("spell") ~= nil)
        else
            addon.RefreshGatheringReminder()
        end
    end)
end
