local addonName, addon = ...

function addon.BuildSettings(deps)
    local className = deps.className
    local isShaman = deps.isShaman
    local elements = deps.elements
    local states = deps.states
    local UsesTimedAura = deps.UsesTimedAura
    local UpdateTimedAura = deps.UpdateTimedAura
    local PaintSelection = deps.PaintSelection
    local flyoutModifiers = deps.flyoutModifiers
    local KeyboardFlyoutModifier = deps.KeyboardFlyoutModifier
    local EditModeActive = deps.EditModeActive
    local SyncSlotKeys = deps.SyncSlotKeys
    local ApplyFlyoutModifier = deps.ApplyFlyoutModifier
    local ApplyStockBarVisibility = deps.ApplyStockBarVisibility
    local minCountdownPercent = deps.minCountdownPercent
    local maxCountdownPercent = deps.maxCountdownPercent
    local UpdateCountdownFont = deps.UpdateCountdownFont
    local RefreshTimedAuras = deps.RefreshTimedAuras
    local PaintButton = deps.PaintButton
    local judgementSpell = deps.judgementSpell
    local PickUpButton = deps.PickUpButton
    local WatchDragRelease = deps.WatchDragRelease
    local flyoutCastOptions = deps.flyoutCastOptions

    local canvas = CreateFrame("Frame")
    local logo = canvas:CreateTexture(nil, "ARTWORK")
    logo:SetSize(28, 28)
    logo:SetPoint("TOPLEFT", 16, -12)
    logo:SetTexture(C_AddOns.GetAddOnMetadata(addonName, "IconTexture"))
    local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("Totem Buttons")

    local classLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    classLabel:SetPoint("TOPRIGHT", -16, -18)
    classLabel:SetText(className)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[deps.class]
    if classColor then classLabel:SetTextColor(classColor.r, classColor.g, classColor.b) end

    local version = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMRIGHT", -16, 12)
    version:SetText("v" .. C_AddOns.GetAddOnMetadata(addonName, "Version"))

    local settingsCategory = Settings.RegisterCanvasLayoutCategory(canvas, "Totem Buttons")
    Settings.RegisterAddOnCategory(settingsCategory)
    local panel = CreateFrame("Frame", nil, canvas)
    panel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -52)
    panel:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -16, 34)

    local function AddHeading(text, anchor, x, y)
        local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
        heading:SetText(text)
        return heading
    end

    local function AddTooltip(control, title, detail)
        control:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            GameTooltip:AddLine(detail, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        control:HookScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    end

    local settingsChecks = {}
    local function AddCheck(key, text, detail, anchor, y, onChanged, indent)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, y)
        local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(text)
        check:SetHitRectInsets(0, -label:GetStringWidth() - 4, 0, 0)
        AddTooltip(check, text, detail)
        check:SetChecked(TotemButtonsDB[key] ~= false)
        check:SetScript("OnClick", function(self)
            TotemButtonsDB[key] = not not self:GetChecked()
            onChanged()
        end)
        settingsChecks[key] = check
        return check, label
    end

    if #elements == 0 then
        return settingsCategory
    end

    local function RefreshAppearance()
        for _, state in ipairs(states) do
            if UsesTimedAura(state) then
                UpdateTimedAura(state)
            else
                PaintSelection(state)
            end
        end
    end

    local buttonsHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    buttonsHeading:SetPoint("TOPLEFT")
    buttonsHeading:SetText("Add to Action Bars")
    local buttonRow = CreateFrame("Frame", nil, panel)
    buttonRow:SetPoint("TOPLEFT", buttonsHeading, "BOTTOMLEFT", 0, -9)

    local buttonDetails = {
        air = "Right-click to dismiss a totem. While Sentry Totem is active, use the button out of combat to switch views.",
        nova = "Use the modifier and click or press the keybind to drop Magma Totem. On gamepad, hold the button until its icon changes, then release.",
        stormstrike = "Starts autoattack against your target and casts Stormstrike.",
        battleshout = "Casts your highest known rank and shows the remaining duration of Battle Shout.",
        judgement = "Choose a seal in the flyout. Out of combat, the button applies that seal if needed. With the chosen seal active or in combat, it casts Judgement.",
    }
    buttonRow:SetSize(1, 55)

    local function AddButton(state, row, column)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(36, 36)
        button:SetPoint("TOPLEFT", row, "TOPLEFT", 8 + (column - 1) * 76, 0)
        local spell = state.kind == "judgement" and judgementSpell or state.spells[1]
        PaintButton(button, C_Spell.GetSpellTexture(spell))
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function()
            if GetCursorInfo() then return end
            PickUpButton(state, IsShiftKeyDown())
            WatchDragRelease()
        end)
        button:SetScript("OnClick", function() PickUpButton(state, IsShiftKeyDown()) end)
        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOP", button, "BOTTOM", 0, -4)
        label:SetText(state.label)
        local detail = buttonDetails[state.kind or state.key]
        if not detail and state.slot then detail = "Right-click to dismiss an active totem." end
        local placement = "Click or drag to add to a bar. Use the icon again to add another copy."
        AddTooltip(button, state.label, detail and (placement .. "\n\n" .. detail) or placement)
    end

    local lastButtonRow = buttonRow
    for index, state in ipairs(elements) do
        if index == 5 then
            lastButtonRow = CreateFrame("Frame", nil, panel)
            lastButtonRow:SetPoint("TOPLEFT", buttonRow, "BOTTOMLEFT", 0, -4)
            lastButtonRow:SetSize(1, 55)
        end
        AddButton(state, lastButtonRow, (index - 1) % 4 + 1)
    end

    local appearanceAnchor = lastButtonRow
    if #elements > 1 or #elements[1].spells > 1 then
        local modifierDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
        modifierDropdown:SetPoint("TOPLEFT", lastButtonRow, "BOTTOMLEFT", 0, -8)
        modifierDropdown:SetWidth(110)
        local modifierLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        modifierLabel:SetPoint("LEFT", modifierDropdown, "RIGHT", 8, 0)
        modifierLabel:SetText("Modifier key")
        AddTooltip(modifierDropdown, "Modifier key",
            "Hold this key with a button's keybind to open its flyout. Scroll to a choice and release the modifier to select it. On gamepad, hold the button to open the flyout.")
        modifierDropdown:SetupMenu(function(_, root)
            for _, modifier in ipairs(flyoutModifiers) do
                local label = modifier:sub(1, 1) .. modifier:sub(2):lower()
                root:CreateRadio(label, function(value) return KeyboardFlyoutModifier() == value end,
                    function(value)
                        TotemButtonsDB.keyboardFlyoutModifier = value
                        if InCombatLockdown() or EditModeActive() then return end
                        for _, state in ipairs(states) do
                            if state.host then SyncSlotKeys(state, true) end
                            ApplyFlyoutModifier(state)
                        end
                    end, modifier)
            end
        end)
        local hoverModifierCheck = AddCheck("requireHoverModifier", "Modifier for hover",
            "Hold the selected modifier while pointing at a button to open its flyout.",
            modifierDropdown, -4, function()
                if InCombatLockdown() or EditModeActive() then return end
                for _, state in ipairs(states) do ApplyFlyoutModifier(state) end
            end)
        appearanceAnchor = hoverModifierCheck
        for _, state in ipairs(elements) do
            local kind = state.kind
            local option = flyoutCastOptions[kind]
            if option then
                local label = kind == "aura" and "Cast aura on select" or "Cast seal on select"
                local detail = kind == "aura" and "Cast the aura when you choose it in the Auras flyout."
                    or "Cast the seal when you choose it in the Seals flyout. The Judgement flyout picks a seal for later."
                appearanceAnchor = AddCheck(option, label, detail, appearanceAnchor, 0, function()
                    if InCombatLockdown() or EditModeActive() then return end
                    for _, buttonState in ipairs(states) do
                        if buttonState.kind == kind then ApplyFlyoutCastOption(buttonState) end
                    end
                end)
            end
        end
    end
    local displayHeading = AddHeading("Appearance", appearanceAnchor, 0, -12)
    local grayAnchor, grayGap = displayHeading, -4
    if isShaman then
        grayAnchor = AddCheck("hideStockBar", "Hide Blizzard Totem Bar",
            "Hides Blizzard's Totem Bar while Totem Buttons is enabled.",
            displayHeading, -4, ApplyStockBarVisibility)
        grayGap = 0
    end
    local grayDetail = "Grays out inactive buffs."
    if isShaman then
        grayDetail = "Grays out inactive totems, imbues, and shields."
    elseif deps.class == "PALADIN" then
        grayDetail = "Grays out inactive auras, seals, and buffs, and Judgement when you have no active seal."
    end
    local grayCheck = AddCheck("greyInactive", "Gray out inactive", grayDetail, grayAnchor, grayGap, RefreshAppearance)
    local countdownCheck = AddCheck("showCountdown", "Countdown numbers",
        "Shows numbers for remaining effect durations and cooldowns.", grayCheck, 0, RefreshAppearance)
    local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", countdownCheck, "BOTTOMLEFT", 24, -5)
    sizeLabel:SetText("Countdown size")
    local countdownSize = CreateFrame("Slider", "TotemButtonsCountdownSizeSlider", panel, "OptionsSliderTemplate")
    countdownSize:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    countdownSize:SetSize(130, 18)
    countdownSize:SetMinMaxValues(minCountdownPercent, maxCountdownPercent)
    countdownSize:SetValueStep(1)
    countdownSize:SetObeyStepOnDrag(true)
    AddTooltip(countdownSize, "Countdown size", "Changes the size of the countdown numbers.")
    countdownSize:SetValue(TotemButtonsDB.countdownPercent)
    local sizeValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeValue:SetPoint("LEFT", countdownSize, "RIGHT", 8, 0)
    sizeValue:SetText(TotemButtonsDB.countdownPercent .. "%")
    countdownSize:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        TotemButtonsDB.countdownPercent = value
        sizeValue:SetText(value .. "%")
        for _, state in ipairs(states) do
            local art = state.crossbarArt or state
            if art.host then UpdateCountdownFont(art, art.host:GetSize()) end
        end
        RefreshTimedAuras()
    end)

    local UpdateRangeOptions
    local reminderAnchor = sizeLabel
    if isShaman then
        local rangeCheck = AddCheck("showRangeTint", "Totem range tint",
            "Tints an active totem red when you're missing its buff.",
            sizeLabel, -8, RefreshAppearance, -24)
        local nonBuffCheck, nonBuffLabel = AddCheck("includeNonBuffTotems",
            "Include non-buff totems", "Also checks distance to totems that don't grant a buff. This check is unavailable in instances.", rangeCheck, 0, RefreshAppearance, 24)
        UpdateRangeOptions = function()
            local enabled = TotemButtonsDB.showRangeTint ~= false
            nonBuffCheck:SetEnabled(enabled)
            nonBuffLabel:SetAlpha(enabled and 1 or 0.5)
        end
        rangeCheck:HookScript("OnClick", UpdateRangeOptions)
        reminderAnchor = nonBuffCheck
    end
    AddCheck("showGatheringTrackingOnButtons", "Gathering tracking",
        "Out of combat, shows Find Herbs or Find Minerals on your buttons when neither tracker is active.",
        reminderAnchor, -4, addon.RefreshGatheringReminder, -24)

    local function UpdateCountdownOptions()
        local enabled = TotemButtonsDB.showCountdown ~= false
        countdownSize:EnableMouse(enabled)
        sizeLabel:SetAlpha(enabled and 1 or 0.5)
        sizeValue:SetAlpha(enabled and 1 or 0.5)
        countdownSize:SetAlpha(enabled and 1 or 0.5)
    end

    countdownCheck:HookScript("OnClick", UpdateCountdownOptions)
    canvas:SetScript("OnShow", function()
        for key, check in pairs(settingsChecks) do
            check:SetChecked(TotemButtonsDB[key] ~= false)
        end
        UpdateCountdownOptions()
        if UpdateRangeOptions then UpdateRangeOptions() end
    end)
    return settingsCategory
end
