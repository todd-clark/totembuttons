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
    if #elements == 0 then
        local message = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        message:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -10)
        message:SetText(className and "No features are available for " .. className .. " characters yet."
            or "No features are available for this class yet.")
        return settingsCategory
    end

    local panel = CreateFrame("Frame", nil, canvas)
    panel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -52)
    panel:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -16, 34)

    local function AddHeading(text, anchor, x, y)
        local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
        heading:SetText(text)
        return heading
    end

    local settingsChecks = {}
    local function AddCheck(key, text, anchor, y, onChanged, indent)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, y)
        local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(text)
        check:SetScript("OnClick", function(self)
            TotemButtonsDB[key] = not not self:GetChecked()
            onChanged()
        end)
        settingsChecks[key] = check
        return check, label
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

    local helpLabels = {}
    local function AddText(text, anchor, gap)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
        helpLabels[#helpLabels + 1] = label
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end

    local buttonsHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    buttonsHeading:SetPoint("TOPLEFT")
    buttonsHeading:SetText("Add to Action Bars")
    local instructions = AddText("Use the same icon again to add another copy.",
        buttonsHeading, -5)
    local buttonRow = CreateFrame("Frame", nil, panel)
    buttonRow:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -9)
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

    local shortcutText
    if isShaman then
        shortcutText = "Right-click to dismiss a totem.\nWith Sentry Totem active, click or use its keybind to switch views out of combat.\nUse the selected modifier with Fire Nova to drop Magma Totem."
    else
        shortcutText = "Pick a seal from the Judgement flyout.\nThe button casts that seal when none is active out of combat, and casts Judgement in combat."
    end
    local shortcuts = AddText(shortcutText, lastButtonRow, -2)

    local modifierDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    modifierDropdown:SetPoint("TOPLEFT", shortcuts, "BOTTOMLEFT", 0, -12)
    modifierDropdown:SetWidth(110)
    local modifierLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    modifierLabel:SetPoint("LEFT", modifierDropdown, "RIGHT", 8, 0)
    modifierLabel:SetText("Modifier key")
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
    local hoverModifierCheck = AddCheck("requireHoverModifier", "Require selected modifier for hover flyouts",
        modifierDropdown, -4, function()
            if InCombatLockdown() or EditModeActive() then return end
            for _, state in ipairs(states) do ApplyFlyoutModifier(state) end
        end)
    local lastFlyoutControl = hoverModifierCheck
    for _, state in ipairs(elements) do
        local kind = state.kind
        local option = flyoutCastOptions[kind]
        if option then
            local label = kind == "aura" and "Cast aura on selection" or "Cast seal on selection"
            lastFlyoutControl = AddCheck(option, label, lastFlyoutControl, 0, function()
                if InCombatLockdown() or EditModeActive() then return end
                for _, buttonState in ipairs(states) do
                    if buttonState.kind == kind then ApplyFlyoutCastOption(buttonState) end
                end
            end)
        end
    end
    local flyoutHelp = AddText(
        "Open a flyout by hovering, using the modifier with the keybind, or holding the gamepad button.\nScroll or point to a spell. Click it, release the modifier, or press the gamepad confirm button to select it.",
        lastFlyoutControl, -5)
    local displayHeading = AddHeading("Appearance", flyoutHelp, 0, -16)
    local grayCheck
    if isShaman then
        local stockBarCheck = AddCheck("hideStockBar", "Hide the default Totem Bar",
            displayHeading, -4, ApplyStockBarVisibility)
        grayCheck = AddCheck("greyInactive", "Gray out inactive totems, imbues, and shields",
            stockBarCheck, 0, RefreshAppearance)
    else
        grayCheck = AddCheck("greyInactive", "Gray out inactive auras, seals, and buffs",
            displayHeading, -4, RefreshAppearance)
    end
    local countdownCheck = AddCheck("showCountdown", "Show countdown numbers", grayCheck, 0, RefreshAppearance)
    local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", countdownCheck, "BOTTOMLEFT", 24, -5)
    sizeLabel:SetText("Countdown size")
    local countdownSize = CreateFrame("Slider", "TotemButtonsCountdownSizeSlider", panel, "OptionsSliderTemplate")
    countdownSize:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    countdownSize:SetSize(130, 18)
    countdownSize:SetMinMaxValues(minCountdownPercent, maxCountdownPercent)
    countdownSize:SetValueStep(1)
    countdownSize:SetObeyStepOnDrag(true)
    countdownSize:SetValue(TotemButtonsDB.countdownPercent)
    local sizeValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeValue:SetPoint("LEFT", countdownSize, "RIGHT", 8, 0)
    sizeValue:SetText(TotemButtonsDB.countdownPercent .. "%")
    countdownSize:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        TotemButtonsDB.countdownPercent = value
        sizeValue:SetText(value .. "%")
        for _, state in ipairs(states) do
            if state.host then UpdateCountdownFont(state, state.host:GetSize()) end
        end
        RefreshTimedAuras()
    end)

    local UpdateRangeOptions
    if isShaman then
        local rangeCheck = AddCheck("showRangeTint", "Tint active totems red when you are missing their buff",
            sizeLabel, -8, RefreshAppearance, -24)
        local nonBuffCheck, nonBuffLabel = AddCheck("includeNonBuffTotems",
            "Include non-buff totems (unavailable in instances)", rangeCheck, 0, RefreshAppearance, 24)
        UpdateRangeOptions = function()
            local enabled = TotemButtonsDB.showRangeTint ~= false
            nonBuffCheck:SetEnabled(enabled)
            nonBuffLabel:SetAlpha(enabled and 1 or 0.5)
        end
        rangeCheck:HookScript("OnClick", UpdateRangeOptions)
        AddCheck("showStormstrikeReset", "Show Stormstrike reset indicator",
            nonBuffCheck, 0, deps.UpdateStormstrikeAlert, -24)
    end

    local function FitContent()
        local width = panel:GetWidth()
        if width <= 8 then return end
        for _, label in ipairs(helpLabels) do label:SetWidth(width - 8) end

    end

    local function UpdateCountdownOptions()
        local enabled = TotemButtonsDB.showCountdown ~= false
        countdownSize:EnableMouse(enabled)
        sizeLabel:SetAlpha(enabled and 1 or 0.5)
        sizeValue:SetAlpha(enabled and 1 or 0.5)
        countdownSize:SetAlpha(enabled and 1 or 0.5)
    end

    countdownCheck:HookScript("OnClick", UpdateCountdownOptions)
    panel:HookScript("OnSizeChanged", FitContent)
    canvas:SetScript("OnShow", function()
        for key, check in pairs(settingsChecks) do
            check:SetChecked(TotemButtonsDB[key] ~= false)
        end
        UpdateCountdownOptions()
        if UpdateRangeOptions then UpdateRangeOptions() end
        FitContent()
    end)
    return settingsCategory
end
