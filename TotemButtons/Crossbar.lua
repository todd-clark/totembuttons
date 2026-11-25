local _, addon = ...

function addon.CreateCrossbar(deps)
    local Readable = deps.Readable
    local flyoutNavigation = deps.flyoutNavigation
    local MacroButton = deps.MacroButton
    local buttonsByKey = deps.buttonsByKey
    local RegisterCopy = deps.RegisterCopy
    local CanUseSlots = deps.CanUseSlots

    local crossbarSlots, crossbarButtons = {}, {}
    local controller, watchedMain

    local function GamepadUIEnabled(main)
        if InputUtil and InputUtil.IsGamepadUIEnabled then
            return InputUtil.IsGamepadUIEnabled()
        end
        return main:IsShown()
    end
    local beforeClick = [[
        local physical = self:GetAttribute("tbPhysicalButton")
        if not physical then return end
        if down then
            -- Keep both edges on the native binding. Rebinding a key while it
            -- is down can lose its release, especially on a quick tap.
            local flyout = control:GetFrameRef("slot" .. self:GetID())
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
        local spell = keyButton:GetAttribute("spell")
        if not spell then return false end
        local owner = flyout:GetFrameRef("castOwner")
        local unit = owner:RunAttribute("resolveMouseoverUnit", spell)
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
    ]]

    local function UpdateCrossbarIcon(button)
        local action = button:GetID()
        local state = Readable(action) and crossbarSlots[action]
        local spell = state and state.keyButton:GetAttribute("spell")
        local icon = crossbarButtons[button]
        if spell then icon:SetTexture(C_Spell.GetSpellTexture(spell) or 134400) end
        icon:SetShown(not not spell)
    end

    local function RefreshCrossbarIcons(slot)
        for button in pairs(crossbarButtons) do
            if not slot or button:GetID() == slot then UpdateCrossbarIcon(button) end
        end
    end

    local function HookCrossbarButtons(main)
        if not controller then
            controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            controller:Execute([[ pending, pressed, ticks = newtable(), newtable(), newtable() ]])
            SecureHandlerSetFrameRef(controller, "navigation", flyoutNavigation)
            SecureHandlerWrapScript(main, "OnHide", controller, [[
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
                    if count ~= "opened" then
                        count = count + 1
                        local flyout = pending[physical]
                        if count >= 2 and flyout:GetAttribute("hasChoices") then
                            ticks[physical] = "opened"
                            flyout:RunAttribute("openInputFlyout", "gamepad", pressed[physical], true)
                        else
                            ticks[physical] = count
                            held = true
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
                    SecureHandlerWrapScript(button, "OnClick", controller, beforeClick, afterClick)
                    local nativeIcon = button.icon
                    local layer, sublevel = nativeIcon:GetDrawLayer()
                    local icon = button:CreateTexture(nil, layer, nil, math.min((sublevel or 0) + 1, 7))
                    icon:SetAllPoints(nativeIcon)
                    icon:SetTexCoord(nativeIcon:GetTexCoord())
                    -- Blizzard toggles the active mask when the bar changes shape.
                    if button.CircleMask then icon:AddMaskTexture(button.CircleMask) end
                    if button.SquareMask then icon:AddMaskTexture(button.SquareMask) end
                    crossbarButtons[button] = icon
                    hooksecurefunc(button, "UpdateAction", UpdateCrossbarIcon)
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
        if GamepadUIEnabled(main) and CanUseSlots() then
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
                    end
                    crossbarSlots[action] = state
                    if previous[action] ~= state then
                        SecureHandlerSetFrameRef(controller, "slot" .. action, state.flyout)
                    end
                    original.onBar = true
                end
            end
        end
        for action, state in pairs(previous) do
            if not crossbarSlots[action] then
                controller:SetAttribute("frameref-slot" .. action, nil)
                state.flyout:Hide()
            end
        end
        RefreshCrossbarIcons()
    end
    return RefreshCrossbarSlots, RefreshCrossbarIcons
end
