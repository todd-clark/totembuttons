local _, addon = ...

function addon.CreateStormstrikeAlert(deps)
    local barPrefixes = deps.barPrefixes
    local stockBars = deps.stockBars
    local HostAction = deps.HostAction
    local Readable = deps.Readable
    local CreateButtonHighlight = deps.CreateButtonHighlight
    local GetTalentRank = deps.GetTalentRank

    local stormstrike = 17364
    local glows = setmetatable({}, { __mode = "k" })
    local cooldownEnd, castWindowEnd, previewTimer, resetTimer, lastAlert
    local resetReady = false
    local cooldownRead, earlyResets, overlayEvents, avoidanceResets = "no cooldown event", 0, 0, 0

    local function Enabled()
        return not TotemButtonsDB or TotemButtonsDB.showStormstrikeReset ~= false
    end

    local function HideResetGlow()
        for _, glow in pairs(glows) do glow:Hide() end
    end

    local function ClearResetGlow()
        resetReady = false
        if resetTimer then
            resetTimer:Cancel()
            resetTimer = nil
        end
        HideResetGlow()
    end

    local function UpdateStormstrikeAlert()
        if Enabled() then return end
        cooldownEnd, castWindowEnd, lastAlert = nil, nil, nil
        if previewTimer then
            previewTimer:Cancel()
            previewTimer = nil
        end
        ClearResetGlow()
    end

    local function PaintResetGlow()
        local visible = {}
        local shown = 0
        local function PaintButton(button, action)
            if not button:IsVisible() or not Readable(action) or type(action) ~= "number" or action <= 0 then return end
            local kind, id = GetActionInfo(action)
            if not Readable(kind) or not Readable(id) then return end
            local isStormstrike = kind == "spell" and id == stormstrike
            if kind == "macro" and id then
                local spell = GetMacroSpell(id)
                isStormstrike = Readable(spell) and spell == stormstrike
            end
            if not isStormstrike then return end
            local glow = glows[button]
            if not glow then
                glow = CreateButtonHighlight(button, true)
                glows[button] = glow
            end
            glow:Show()
            visible[button] = true
            shown = shown + 1
        end
        for _, prefix in ipairs(barPrefixes) do
            local count = stockBars[prefix] and 12 or 180
            for index = 1, count do
                local button = _G[prefix .. index]
                if button and button:IsVisible() then PaintButton(button, HostAction(button)) end
            end
        end
        addon.ForEachGamepadActionButton(PaintButton)
        for button, glow in pairs(glows) do
            if not visible[button] then glow:Hide() end
        end
        return shown
    end

    local function ShowResetGlow()
        local now = GetTime()
        if resetReady and lastAlert and now - lastAlert < 0.25 then return end
        lastAlert = now
        resetReady = true
        if resetTimer then resetTimer:Cancel() end
        resetTimer = C_Timer.NewTimer(5, function()
            resetTimer = nil
            ClearResetGlow()
        end)
        PaintResetGlow()
    end

    local function StormstrikeRemaining(now)
        -- Exclude the global cooldown so a reset can still be detected during it.
        local timer = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(stormstrike, true)
        if timer and timer.GetRemainingDuration then
            local remaining = timer:GetRemainingDuration()
            if Readable(remaining) and type(remaining) == "number" then return remaining end
        end

        local info = C_Spell.GetSpellCooldown(stormstrike)
        if not Readable(info) or not info or not Readable(info.isOnGCD) or info.isOnGCD then return end
        local start, duration, rate = info.startTime, info.duration, info.modRate
        if not (Readable(start) and Readable(duration) and Readable(rate)) or not start or not duration then return end
        if duration == 0 then return 0 end
        if start > 0 then return math.max(0, start + duration / (rate and rate > 0 and rate or 1) - now) end
    end

    local function TestStormstrikeGlow()
        if not Enabled() then
            print("Stormstrike reset indicator is disabled in Totem Buttons settings.")
            return
        end
        local shown = PaintResetGlow()
        if previewTimer then previewTimer:Cancel() end
        previewTimer = C_Timer.NewTimer(3, function()
            previewTimer = nil
            if resetReady then PaintResetGlow() else HideResetGlow() end
        end)
        print("Stormstrike glow: " .. shown .. " matching visible buttons"
            .. " | last cooldown event: " .. cooldownRead
            .. " | early resets: " .. earlyResets .. " | proc overlay events: " .. overlayEvents
            .. " | dodge/parry resets: " .. avoidanceResets
            .. " | Improved Stormstrike: " .. GetTalentRank() .. "/2")
    end

    local function CheckStormstrikeCooldown()
        if not Enabled() then return end
        local now = GetTime()
        local remaining = StormstrikeRemaining(now)
        cooldownRead = remaining and (remaining > 0 and "on cooldown" or "ready") or "unavailable"
        if not remaining then return end
        if remaining > 0 then
            cooldownEnd = now + remaining
            -- Prefer the measured end to the cast estimate once available.
            castWindowEnd = nil
        elseif cooldownEnd then
            local resetEarly = cooldownEnd > now + 0.15
            cooldownEnd, castWindowEnd = nil, nil
            if resetEarly then
                earlyResets = earlyResets + 1
                ShowResetGlow()
            end
        end
    end

    local resetEvents = CreateFrame("Frame")
    resetEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    resetEvents:RegisterUnitEvent("UNIT_COMBAT", "player")
    resetEvents:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    resetEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    resetEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    resetEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    resetEvents:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    resetEvents:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    resetEvents:SetScript("OnEvent", function(_, event, first, second, third)
        if not Enabled() then return end
        if event == "SPELL_UPDATE_COOLDOWN" then
            CheckStormstrikeCooldown()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if Readable(third) and third == stormstrike then
                ClearResetGlow()
                local base = GetSpellBaseCooldown and GetSpellBaseCooldown(stormstrike)
                local seconds = Readable(base) and type(base) == "number" and base > 0 and base / 1000 or 8
                castWindowEnd = GetTime() + seconds
                C_Timer.After(0, CheckStormstrikeCooldown)
            end
        elseif event == "UNIT_COMBAT" then
            if GetTalentRank() < 2 or not Readable(second) then return end
            if second ~= "DODGE" and second ~= "PARRY" then return end
            local expectedEnd = cooldownEnd or castWindowEnd
            if expectedEnd and expectedEnd > GetTime() + 0.15 then
                cooldownEnd, castWindowEnd = nil, nil
                avoidanceResets = avoidanceResets + 1
                ShowResetGlow()
            end
        elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
            if Readable(first) and first == stormstrike then
                cooldownEnd, castWindowEnd = nil, nil
                overlayEvents = overlayEvents + 1
                ShowResetGlow()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            cooldownEnd, castWindowEnd = nil, nil
            ClearResetGlow()
        elseif event == "PLAYER_REGEN_ENABLED" then
            cooldownEnd, castWindowEnd = nil, nil
        elseif resetReady then
            PaintResetGlow()
        else
            HideResetGlow()
        end
    end)
    local function RefreshStormstrikeGlow()
        if resetReady and Enabled() then PaintResetGlow() end
    end

    return TestStormstrikeGlow, UpdateStormstrikeAlert, RefreshStormstrikeGlow
end
