local _, addon = ...

function addon.IsGamepadUIEnabled()
    if InputUtil and InputUtil.IsGamepadUIEnabled then
        return InputUtil.IsGamepadUIEnabled()
    end
    local main = GamepadMainActionBarFrame
    return main and main:IsShown()
end

function addon.ForEachGamepadActionButton(visit)
    local main = GamepadMainActionBarFrame
    local page = main and main.PageUnit
    if not page or not page.actionBars or not addon.IsGamepadUIEnabled() then return end
    for _, bar in pairs(page.actionBars) do
        for _, button in ipairs(bar.actionButtons or {}) do
            if button.GetGamepadPageUnitSlotID and button:GetGamepadPageUnitSlotID() then
                visit(button, button:GetID())
            end
        end
    end
end

function addon.CreateCrossbar(deps)
    local Readable = deps.Readable
    local flyoutNavigation = deps.flyoutNavigation
    local MacroButton = deps.MacroButton
    local buttonsByKey = deps.buttonsByKey
    local RegisterCopy = deps.RegisterCopy
    local CanUseSlots = deps.CanUseSlots

    local crossbarSlots, crossbarButtons = {}, {}
    local controller, watchedMain

    local beforeClick = [[
        local physical = self:GetAttribute("tbPhysicalButton")
        if not physical then return end
        if down then
            -- Keep both edges on the native binding. Rebinding a key while it
            -- is down can lose its release, especially on a quick tap.
            local flyout = control:GetFrameRef("slot" .. self:GetID())
            if ticks[physical] == "alternate" then
                pending[physical]:CallMethod("ShowAlternateIcon")
            end
            pending[physical], pressed[physical], ticks[physical] = nil, nil, nil
            if not flyout then return end
            -- Capture the slot before a layer change can hide or move it.
            local left, bottom, width, height = self:GetRect()
            local scale = self:GetEffectiveScale()
            local screen = flyout:GetFrameRef("screen")
            local screenScale = screen and screen:GetEffectiveScale()
            local x, y
            if left and bottom and width and height and scale and screenScale and screenScale > 0 then
                local ratio = scale / screenScale
                x, y = (left + width / 2) * ratio, (bottom + height) * ratio
            end
            flyout:SetAttribute("gamepadAnchorX", x)
            flyout:SetAttribute("gamepadAnchorY", y)
            pending[physical], pressed[physical], ticks[physical] = flyout, self, 0
            control:SetAttribute("state-tbhold", nil)
            return false
        end

        local flyout = pending[physical]
        if not flyout then return end
        local elapsed = ticks[physical]
        pending[physical], pressed[physical], ticks[physical] = nil, nil, nil
        if elapsed == "opened" then
            if flyout:GetAttribute("gamepadPressHeld") then
                flyout:SetAttribute("gamepadPressHeld", nil)
                flyout:RunAttribute("bindNavigation")
                flyout:RunAttribute("setChoice", flyout:GetAttribute("choiceIndex"))
            end
            return false
        end

        local keyButton = flyout:GetFrameRef("keyButton")
        local owner = flyout:GetFrameRef("castOwner")
        local gathering = elapsed ~= "alternate" and owner:RunAttribute("resolveGatheringSpell")
        local spell = gathering or keyButton:GetAttribute(elapsed == "alternate" and "spell2" or "spell")
        if elapsed == "alternate" then flyout:CallMethod("ShowAlternateIcon") end
        if not spell then return false end
        if spell == 6495 then
            local sentry = owner:GetFrameRef("sentryStatus")
            local aura = keyButton:GetAttribute("*spell-sentryview")
            if aura and sentry and sentry:GetAttribute("state-sentrycombat") == "peace"
                and sentry:GetAttribute("sentryActive") then
                self:SetAttribute("*spell-TotemButtonsSentryView", aura)
                self:SetAttribute("tbPreviousKeyDown", self:GetAttribute("useOnKeyDown"))
                self:SetAttribute("useOnKeyDown", false)
                return "TotemButtonsSentryView", true
            end
        end
        local unit
        if not gathering then unit = owner:RunAttribute("resolveMouseoverUnit", spell) end
        self:SetAttribute("*spell-TotemButtonsRelease", spell)
        self:SetAttribute("*unit-TotemButtonsRelease", unit)
        self:SetAttribute("tbPreviousKeyDown", self:GetAttribute("useOnKeyDown"))
        self:SetAttribute("useOnKeyDown", false)
        return "TotemButtonsRelease", true
    ]]
    local afterClick = [[
        self:SetAttribute("useOnKeyDown", self:GetAttribute("tbPreviousKeyDown"))
        self:SetAttribute("tbPreviousKeyDown", nil)
        self:SetAttribute("*spell-TotemButtonsRelease", nil)
        self:SetAttribute("*unit-TotemButtonsRelease", nil)
        self:SetAttribute("*spell-TotemButtonsSentryView", nil)
    ]]

    local function ReadCrossbarSlot(button)
        local action = button:GetID()
        local visible = button:IsVisible()
        if Readable(action) and action and Readable(visible) and visible then
            return crossbarSlots[action]
        end
    end

    local function UpdateCrossbarIcon(button, state)
        local art = crossbarButtons[button]
        local previous = art.state
        if previous ~= state then
            art.state = state
            art.alternateSpell = nil
            art.gcdSample = nil
            art.gcd:Clear()
            art.paintedStart, art.paintedDuration, art.paintedRate, art.paintedTimer = nil, nil, nil, nil
            art.showingSpellCooldown = nil
            art.paintingCooldown = true
            art.cooldown:Clear()
            art.paintingCooldown = nil
            art.icon:SetShown(state ~= nil)
            art.cooldown:SetShown(state ~= nil)
            art.gcd:SetShown(state ~= nil)
        end
        if not state then
            deps.RestoreMacroLabel(art)
            return
        end
        deps.HideMacroLabel(art)
        state.crossbarArt = art
        local mask = button.CircleMask and button.CircleMask:IsShown() and button.CircleMask or button.SquareMask
        local changedMask = art.slotMask ~= mask
        if changedMask then
            art.slotMask = mask
            local bounds = mask or button.icon
            art.cooldown:SetAllPoints(bounds)
            local swipe = mask and mask:GetTexture() or ""
            art.cooldown:SetSwipeTexture(swipe)
            art.gcd:SetAllPoints(bounds)
            art.gcd:SetSwipeTexture(swipe)
        end
        local width, height = button:GetSize()
        local x, y = art.icon:GetCenter()
        if not Readable(x) then x = nil end
        if not Readable(y) then y = nil end
        local strata, level = button:GetFrameStrata(), button:GetFrameLevel()
        local changedLayer = art.strata ~= strata or art.level ~= level
        if previous ~= state or changedLayer then
            art.strata, art.level = strata, level
            art.gcd:SetFrameStrata(strata)
            art.gcd:SetFrameLevel(level + 7)
            if state.slot or state.kind == "judgement" then
                deps.RaiseAuraLayerCooldown(art.cooldown, button)
            else
                art.cooldown:SetFrameStrata(strata)
                art.cooldown:SetFrameLevel(level + 1)
            end
        end
        if previous ~= state or changedMask or changedLayer or art.width ~= width or art.height ~= height
            or art.x ~= x or art.y ~= y then
            art.width, art.height, art.x, art.y = width, height, x, y
            deps.UpdateTimer(state)
        end
    end

    local visualRefreshQueued
    local function RefreshCrossbarVisuals()
        -- Snapshot the entire grid before painting. A page change can move a
        -- slot between frames, so detach old owners before updating new ones.
        for button, art in pairs(crossbarButtons) do
            art.nextState = ReadCrossbarSlot(button)
            local previous = art.state
            if previous and previous ~= art.nextState and previous.crossbarArt == art then
                previous.crossbarArt = nil
                deps.UpdateTimedAuraArtwork(previous)
            end
        end
        for button, art in pairs(crossbarButtons) do
            UpdateCrossbarIcon(button, art.nextState)
            art.nextState = nil
        end
        if deps.RefreshStormstrikeGlow then deps.RefreshStormstrikeGlow() end
    end

    local function QueueCrossbarVisuals()
        if visualRefreshQueued then return end
        visualRefreshQueued = true
        C_Timer.After(0, function()
            visualRefreshQueued = false
            RefreshCrossbarVisuals()
        end)
    end

    local function HookCrossbarButtons(main)
        if not controller then
            controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            controller:Execute([[ pending, pressed, ticks = newtable(), newtable(), newtable() ]])
            SecureHandlerSetFrameRef(controller, "navigation", flyoutNavigation)
            SecureHandlerWrapScript(main, "OnHide", controller, [[
                for physical, count in pairs(ticks) do
                    if count == "alternate" then pending[physical]:CallMethod("ShowAlternateIcon") end
                end
                pending, pressed, ticks = newtable(), newtable(), newtable()
                local flyout = control:GetFrameRef("navigation"):GetAttribute("activeFlyout")
                if flyout and flyout:GetAttribute("inputMode") == "gamepad" then flyout:Hide() end
            ]])
            -- The native state driver evaluates periodically. Count its updates
            -- only while a crossbar slot owns a press.
            controller:SetAttribute("_onstate-tbhold", [[
                if not newstate then return end
                local held
                for physical, count in pairs(ticks) do
                    if type(count) == "number" then
                        count = count + 1
                        local flyout = pending[physical]
                        if count < 2 then
                            ticks[physical] = count
                            held = true
                        elseif flyout:GetAttribute("hasChoices") then
                            ticks[physical] = "opened"
                            flyout:RunAttribute("openInputFlyout", "gamepad", pressed[physical], true)
                        else
                            local alternate = flyout:GetFrameRef("keyButton"):GetAttribute("spell2")
                            ticks[physical] = alternate and "alternate" or "tap"
                            if alternate then flyout:CallMethod("ShowAlternateIcon", alternate) end
                        end
                    end
                end
                if held then self:SetAttribute("state-tbhold", nil) end
            ]])
            RegisterStateDriver(controller, "tbhold", "1")
        end
        for _, bar in pairs(main.PageUnit.actionBars) do
            for physical, button in ipairs(bar.actionButtons or {}) do
                local slotID = button.GetGamepadPageUnitSlotID and button:GetGamepadPageUnitSlotID()
                if not crossbarButtons[button] and button.icon and slotID
                    and GamepadActionBarBindingUtil and GamepadActionBarBindingUtil.IsBindablePageUnitSlotID
                    and GamepadActionBarBindingUtil.IsBindablePageUnitSlotID(slotID) then
                    button:RegisterForClicks("AnyDown", "AnyUp")
                    button:SetAttribute("tbPhysicalButton", physical)
                    button:SetAttribute("*type-TotemButtonsRelease", "spell")
                    button:SetAttribute("*type-TotemButtonsSentryView", "cancelaura")
                    SecureHandlerWrapScript(button, "OnClick", controller, beforeClick, afterClick)
                    local nativeIcon = button.icon
                    local layer, sublevel = nativeIcon:GetDrawLayer()
                    local icon = button:CreateTexture(nil, layer, nil, math.min((sublevel or 0) + 1, 7))
                    icon:SetAllPoints(nativeIcon)
                    icon:SetTexCoord(nativeIcon:GetTexCoord())
                    icon:Hide()
                    -- Blizzard toggles the active mask when the bar changes shape.
                    if button.CircleMask then icon:AddMaskTexture(button.CircleMask) end
                    if button.SquareMask then icon:AddMaskTexture(button.SquareMask) end
                    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    cooldown:SetAllPoints(nativeIcon)
                    cooldown:SetDrawEdge(false)
                    cooldown:SetDrawBling(false)
                    cooldown:Hide()
                    local gcd = deps.CreateGlobalCooldown(button)
                    gcd:SetAllPoints(nativeIcon)
                    gcd:Hide()
                    local art = { host = button, icon = icon, cooldown = cooldown, gcd = gcd }
                    crossbarButtons[button] = art
                    cooldown:HookScript("OnCooldownDone", function()
                        if art.state and not art.paintingCooldown then deps.UpdateTimer(art.state) end
                    end)
                    hooksecurefunc(button, "UpdateAction", QueueCrossbarVisuals)
                    hooksecurefunc(button, "SetShapeToCircle", QueueCrossbarVisuals)
                    hooksecurefunc(button, "SetShapeToSquare", QueueCrossbarVisuals)
                    button:HookScript("OnShow", QueueCrossbarVisuals)
                    button:HookScript("OnHide", QueueCrossbarVisuals)
                    button:HookScript("OnSizeChanged", QueueCrossbarVisuals)
                end
            end
        end
    end

    local function RefreshCrossbarSlots()
        local main = GamepadMainActionBarFrame
        local gamepad = C_GamepadUI
        if not main or not main.PageUnit or not main.PageUnit.actionBars or not gamepad then return end
        if watchedMain ~= main then
            watchedMain = main
            local function RefreshAfterModeChange()
                C_Timer.After(0, deps.Refresh)
            end
            main:HookScript("OnShow", RefreshAfterModeChange)
            main:HookScript("OnHide", RefreshAfterModeChange)
        end
        local previous = crossbarSlots
        crossbarSlots = {}
        if addon.IsGamepadUIEnabled() and CanUseSlots() then
            HookCrossbarButtons(main)
            local first = gamepad.GetFirstGamepadActionStorageSlotIndex()
            for action = first or 0, first and first + 999 or -1 do
                if not gamepad.IsValidGamepadActionStorageSlotIndex(action) then break end
                local kind, id = GetActionInfo(action)
                local original = Readable(kind) and kind == "macro" and Readable(id) and id
                    and MacroButton(GetMacroBody(id))
                if original then
                    local key = original.key .. "-gamepad-" .. action
                    local state = buttonsByKey[key]
                    if not state then
                        TotemButtonsDB[key] = TotemButtonsDB[key] or TotemButtonsDB[original.key]
                        state = RegisterCopy(original, key, original.label .. " (crossbar " .. action .. ")")
                        state.crossbarSlot = action
                        function state.flyout:ShowAlternateIcon(spell)
                            local art = state.crossbarArt
                            if not art or art.alternateSpell == spell then return end
                            art.alternateSpell = spell
                            deps.UpdateTimer(state)
                        end
                    end
                    crossbarSlots[action] = state
                    if previous[action] ~= state then
                        SecureHandlerSetFrameRef(controller, "slot" .. action, state.flyout)
                    end
                end
            end
        end
        for action, state in pairs(previous) do
            if not crossbarSlots[action] then
                controller:SetAttribute("frameref-slot" .. action, nil)
                state.flyout:Hide()
            end
        end
        RefreshCrossbarVisuals()
    end
    return RefreshCrossbarSlots
end
