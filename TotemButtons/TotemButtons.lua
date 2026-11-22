local addonName = ...
local className, class = UnitClass("player")
local isShaman = class == "SHAMAN"
local isPaladin = class == "PALADIN"

-- WoW's totem timer slots are fire, earth, water, and air.
local elements = isShaman and {
    { key = "fire", label = "Fire", spells = {3599, 8190, 8227, 8181} },
    { key = "earth", label = "Earth", spells = {8071, 8075, 8143, 2484, 5730} },
    { key = "water", label = "Water", spells = {5394, 5675, 8166, 8170, 8184, 16190} },
    { key = "air", label = "Air", spells = {8512, 8835, 8177, 10595, 15107, 6495} },
    { key = "imbues", label = "Imbues", spells = {8017, 8024, 8033, 8232}, kind = "imbue" },
    { key = "shields", label = "Shields", spells = {324, 408510}, kind = "shield" },
    { key = "nova", label = "Fire Nova", spells = {408341}, kind = "nova" },
} or isPaladin and {
    { key = "auras", label = "Auras", spells = {465, 7294, 19746, 19876, 19888, 19891, 20218}, kind = "aura" },
    { key = "seals", label = "Seals", spells = {20154, 21082, 1311649, 20375, 20164, 20165, 20166, 407798}, kind = "seal" },
    { key = "buffs", label = "Buffs", kind = "buff",
        spells = {19740, 19742, 20217, 19977, 1038, 25780, 1044, 1022, 25782, 25894, 25898, 25890, 25895} },
} or {}

local function UsesTimedAura(state)
    return state.kind == "shield" or state.kind == "seal" or state.kind == "buff"
end

local flyoutCastOptions = { aura = "autoCastAura", seal = "autoCastSeal" }

-- Rank-specific main-hand enchant IDs are a fallback when the icon is unavailable.
local imbueEnchantFamilies = {
    [29] = 8017, [6] = 8017, [1] = 8017, [503] = 8017, [1663] = 8017, [683] = 8017, [1664] = 8017,
    [5] = 8024, [4] = 8024, [3] = 8024, [523] = 8024, [1665] = 8024, [1666] = 8024,
    [2] = 8033, [12] = 8033, [524] = 8033, [1667] = 8033, [1668] = 8033,
    [283] = 8232, [284] = 8232, [525] = 8232, [1669] = 8232,
}
local states, hosts, elementsByKey, buttonsByKey = {}, {}, {}, {}
local recentTotemCasts, learnedTotemDurations = {}, {}
local recentImbueCast
local mainHandSlot = INVSLOT_MAINHAND or 16
local unlocked = false
local defaultCountdownPercent, minCountdownPercent, maxCountdownPercent = 42, 20, 80
local countdownFonts = {}

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function PaintAuraManaTint(art, lowMana)
    if art.lowMana == lowMana then return end
    local shade = lowMana and 0.5 or 1
    if pcall(art.icon.SetVertexColor, art.icon, shade, shade, 1) then
        art.lowMana = lowMana
    end
end

local function EditModeActive()
    local manager = EditModeManagerFrame
    return manager and (manager.IsEditModeActive and manager:IsEditModeActive() or manager:IsShown())
end

local function UpdateCountdownFont(state, width, height)
    if EditModeActive() then return end
    local cooldown = state.cooldown
    if not cooldown.SetCountdownFont or width <= 0 or height <= 0 then return end

    -- The overlay inherits its host's scale, so size text in local units.
    local size = math.max(1, math.floor(math.min(width, height) * TotemButtonsDB.countdownPercent / 100 + 0.5))
    if state.countdownFontSize == size then return end
    local fontName = countdownFonts[size]
    if not fontName then
        fontName = "TotemButtonsCountdownFont" .. size
        CreateFont(fontName):SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        countdownFonts[size] = fontName
    end
    cooldown:SetCountdownFont(fontName)
    state.countdownFontSize = size
end

local shieldAuraSize = 32
local timedAuraRanks = {
    [324] = { 324, 325, 905, 945, 8134, 10431, 10432 },
    [408510] = { 408510 },
    [20154] = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293 },
    [21082] = { 21082, 20162, 20305, 20306, 20307, 20308 },
    [1311649] = { 1311649, 1311656, 20163, 20419, 20421, 20422, 20423 },
    [20375] = { 20375, 20915, 20918, 20919, 20920 },
    [20164] = { 20164 },
    [20165] = { 20165, 20347, 20348, 20349 },
    [20166] = { 20166, 20356, 20357 },
    [407798] = { 407798 },
    [19740] = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 },
    [19742] = { 19742, 19850, 19852, 19853, 19854, 25290 },
    [19977] = { 19977, 19978, 19979 },
    [1022] = { 1022, 5599, 10278 },
    [25782] = { 25782, 25916 },
    [25894] = { 25894, 25918 },
}

local function MatchTimedAuraLayerOpacity(layerHost, state)
    local alpha = 0
    if state.host and state.button:IsVisible() then
        local parentAlpha = UIParent:GetEffectiveAlpha()
        if parentAlpha > 0 then
            alpha = math.min(1, state.host:GetEffectiveAlpha() / parentAlpha)
        end
    end
    if layerHost:GetAlpha() ~= alpha then layerHost:SetAlpha(alpha) end
end

local function CreateTimedAuraLayer(state, baseSpell)
    -- Keep native aura frames off the secure action bar's parent and anchor chain.
    local host = CreateFrame("Frame", nil, UIParent)
    host:Hide()
    host:SetSize(shieldAuraSize, shieldAuraSize)
    host:EnableMouse(false)
    -- The separate host does not inherit fades from the slot or its bar.
    host:SetScript("OnUpdate", function(self) MatchTimedAuraLayerOpacity(self, state) end)
    local container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
    container:SetPoint("CENTER", host, "CENTER")
    container:SetSize(shieldAuraSize, shieldAuraSize)
    local setAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    if setAnchor then setAnchor(container, "CENTER") end

    local layer = { host = host, container = container, buttons = {} }
    local include = {}
    include[baseSpell] = true
    for _, spell in ipairs(timedAuraRanks[baseSpell] or {}) do include[spell] = true end
    local name = C_Spell.GetSpellName(baseSpell)
    local selected = state.button:GetAttribute("spell1")
    if selected and C_Spell.GetSpellName(selected) == name then include[selected] = true end
    layer.spells = include
    container:AddAuraGroup("shield", "HELPFUL", {
        candidateFilters = { includeSpellIDs = include },
        maxFrameCount = 1,
        layout = { anchorPoint = "CENTER", padding = { 0, 0, 0, 0 } },
        initializeFrame = function(button)
            local width, height = layer.width or shieldAuraSize, layer.height or shieldAuraSize
            button:SetSize(width, height)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("CENTER", button, "CENTER")
            icon:SetSize(width, height)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetTexture(C_Spell.GetSpellTexture(baseSpell))
            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cooldown:SetAllPoints(icon)
            cooldown:SetReverse(true)
            cooldown:SetDrawEdge(false)
            cooldown:SetDrawBling(false)
            -- The aura button drives visibility. Draw the spell artwork ourselves.
            cooldown:SetDrawSwipe(state.kind ~= "shield")
            button:SetDurationCooldown(cooldown)
            button:SetMouseClickEnabled(false)
            button:SetMouseMotionEnabled(false)
            layer.buttons[#layer.buttons + 1] = { button = button, cooldown = cooldown, icon = icon }
        end,
    })
    container:SetUnit("player")
    container:UpdateAllAuras()
    return layer
end

local function UpdateTimedAuraArtwork(state)
    local host, button = state.host, state.button
    local selected = button:GetAttribute("spell1")
    local name = selected and C_Spell.GetSpellName(selected)
    local canUpdateLayout = not InCombatLockdown()
    local assist = UnitCanAssist("player", "player")
    local visible = host and not EditModeActive() and button:IsVisible() and Readable(assist) and assist == true
    if visible and name and canUpdateLayout then
        if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
        if C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            state.nativeAuraLayers = state.nativeAuraLayers or {}
            for index, baseSpell in ipairs(state.spells) do
                local choice = state.choices[index]
                local spellName = C_Spell.GetSpellName(baseSpell)
                if spellName and choice and choice.spellID and not state.nativeAuraLayers[spellName] then
                    state.nativeAuraLayers[spellName] = CreateTimedAuraLayer(state, baseSpell)
                end
            end
        end
    end
    if not state.nativeAuraLayers then return false end

    for spellName, layer in pairs(state.nativeAuraLayers) do
        local show = visible and spellName == name
        if show and canUpdateLayout then
            local x, y = state.icon:GetCenter()
            local width, height = state.icon:GetSize()
            if x and y and width > 0 and height > 0 then
                -- Match the gray artwork. Its mask is positioned independently.
                local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
                width, height = width * ratio, height * ratio
                local centerX, centerY = x * ratio, y * ratio
                local strata, level = button:GetFrameStrata(), button:GetFrameLevel() + 1
                local resized = layer.width ~= width or layer.height ~= height
                if layer.x ~= centerX or layer.y ~= centerY or resized
                    or layer.strata ~= strata or layer.level ~= level then
                    layer.host:SetSize(width, height)
                    layer.host:ClearAllPoints()
                    layer.host:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                    layer.host:SetFrameStrata(strata)
                    layer.host:SetFrameLevel(level)
                    layer.x, layer.y = centerX, centerY
                    layer.width, layer.height = width, height
                    layer.strata, layer.level = strata, level
                end
                if selected and not layer.spells[selected] and layer.container.SetAuraGroupCandidateFilters then
                    layer.spells[selected] = true
                    layer.container:SetAuraGroupCandidateFilters("shield", { includeSpellIDs = layer.spells })
                end
                local slotMask = state.slotMask
                local texture = C_Spell.GetSpellTexture(selected)
                for _, auraButton in ipairs(layer.buttons) do
                    if resized then
                        auraButton.button:SetSize(width, height)
                        auraButton.icon:SetSize(width, height)
                    end
                    if auraButton.mask ~= slotMask then
                        if auraButton.mask then auraButton.icon:RemoveMaskTexture(auraButton.mask) end
                        if slotMask and not pcall(auraButton.icon.AddMaskTexture, auraButton.icon, slotMask) then
                            slotMask = nil
                        end
                        auraButton.mask = slotMask
                    end
                    if resized or auraButton.artRevision ~= state.auraArtRevision then
                        auraButton.icon:SetTexCoord(state.icon:GetTexCoord())
                        auraButton.artRevision = state.auraArtRevision
                    end
                    if texture and auraButton.texture ~= texture then
                        auraButton.icon:SetTexture(texture)
                        auraButton.texture = texture
                    end
                    PaintAuraManaTint(auraButton, state.lowMana == true)
                    UpdateCountdownFont(auraButton, button:GetWidth() * ratio, button:GetHeight() * ratio)
                    local hideNumbers = TotemButtonsDB.showCountdown == false
                    if auraButton.hideNumbers ~= hideNumbers then
                        auraButton.cooldown:SetHideCountdownNumbers(hideNumbers)
                        auraButton.hideNumbers = hideNumbers
                    end
                end
            end
        end
        if show and layer.width then
            MatchTimedAuraLayerOpacity(layer.host, state)
            layer.host:Show()
        else
            layer.host:Hide()
        end
    end
    return state.nativeAuraLayers[name] ~= nil
end

local function ActiveEffect(state, name)
    if not name then return end
    local effect = state.shields and state.shields[name] or state.effect
    if UsesTimedAura(state) then return effect end
    if effect and effect.name == name and not effect.expired
        and (not effect.start or effect.start + effect.duration > GetTime()) then
        return effect
    end
end

-- Each summon maps to the player aura IDs for all ranks of its persistent buff.
-- A persistent aura can deliver periodic heals or mana. Totems without a
-- player aura use the position check where available.
local totemAuraSpells = {
    [8227] = { 8230, 8250, 10521, 15036 },  -- Flametongue
    [8181] = { 8182, 10476, 10477 },  -- Frost Resistance
    [8071] = { 8072, 8156, 8157, 10403, 10404, 10405 },  -- Stoneskin
    [8075] = { 8076, 8162, 8163, 10441, 25362 },  -- Strength of Earth
    [8184] = { 8185, 10534, 10535 },  -- Fire Resistance
    [5394] = { 5672, 6371, 6372, 10460, 10461 },  -- Healing Stream
    [5675] = { 5677, 10491, 10493, 10494, 24853 },  -- Mana Spring
    [16190] = { 16191, 17355, 17360, 1325257 },  -- Mana Tide
    [8177] = { 8178 },  -- Grounding
    [8512] = { 8515, 10609, 10612 },  -- Windfury (area aura, before the proc)
    [8835] = { 8836, 10626, 25360 },  -- Grace of Air
    [10595] = { 10596, 10598, 10599 },  -- Nature Resistance
    [15107] = { 15108, 15109, 15110 },  -- Windwall
}
local totemAuraIDsByName = {}

local function ReadTotemBuff(name)
    local ids = totemAuraIDsByName[name]
    local lookup = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not (ids and lookup) then return end

    local isSecret = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
    local unknown = false
    for _, id in ipairs(ids) do
        local ok, aura = pcall(lookup, id)
        if not ok or not Readable(aura) then
            unknown = true
        elseif aura then
            return true
        elseif isSecret then
            local checked, secret = pcall(isSecret, id)
            if not checked or not Readable(secret) or secret then unknown = true end
        end
    end
    if not unknown then return false end
end

local function UpdateLowMana(state, spell)
    local lowMana = false
    if spell and C_Spell.IsSpellUsable then
        local _, insufficientPower = C_Spell.IsSpellUsable(spell)
        lowMana = Readable(insufficientPower) and insufficientPower == true
    end
    if state.lowMana == lowMana then return false end
    state.lowMana = lowMana
    if state.nativeAuraLayers then
        for _, layer in pairs(state.nativeAuraLayers) do
            for _, art in ipairs(layer.buttons) do PaintAuraManaTint(art, lowMana) end
        end
    end
    return true
end

local function PaintButtonTint(state, effect, buffReads)
    local tint = false
    if TotemButtonsDB.showRangeTint ~= false and effect then
        local name = effect.name
        local buff
        if buffReads then buff = buffReads[name] end
        if buff == nil and totemAuraIDsByName[name] then
            buff = ReadTotemBuff(name)
            if buffReads then buffReads[name] = buff == nil and "unknown" or buff end
        end
        if buff == false then
            tint = true
        else
            tint = not totemAuraIDsByName[effect.name] and TotemButtonsDB.includeNonBuffTotems == true
                and effect.rangeKnown and effect.outOfRange
        end
    end
    local color = tint and "range" or (state.lowMana and "mana" or "normal")
    if state.buttonTint == color then return end
    if color == "range" then
        state.icon:SetVertexColor(1, 0.25, 0.25)
    elseif color == "mana" then
        state.icon:SetVertexColor(0.5, 0.5, 1)
    else
        state.icon:SetVertexColor(1, 1, 1)
    end
    state.buttonTint = color
end

local function ReadSpellCooldown(spell, cooldown)
    local info = C_Spell.GetSpellCooldown(spell)
    local realCooldown = Readable(info) and info and Readable(info.isOnGCD)
        and info.isOnGCD == false
    if realCooldown then
        local start, duration, rate = info.startTime, info.duration, info.modRate
        if Readable(start) and Readable(duration) and Readable(rate)
            and start and duration and start > 0 and duration > 0 and start + duration > GetTime() then
            return start, duration, rate
        end
    end
    if not (C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject) then return end
    local timer = C_Spell.GetSpellCooldownDuration(spell, true)
    if timer then
        if timer.IsActive then
            local active = timer:IsActive()
            if not Readable(active) or active then return nil, nil, nil, timer end
        elseif timer.IsZero then
            local zero = timer:IsZero()
            if not Readable(zero) or zero == false then return nil, nil, nil, timer end
        end
    end
end

local function FireTotemStatus()
    local haveTotem, _, start, duration = GetTotemInfo(1)
    if Readable(haveTotem) and haveTotem == false then
        return false, "fire slot empty"
    end
    if Readable(start) and Readable(duration) and type(start) == "number" and type(duration) == "number" then
        return duration > 0 and start + duration > GetTime(), "fire slot timer"
    end

    if not InCombatLockdown() and Readable(haveTotem) then
        return haveTotem == true, "fire slot"
    end

    -- In combat a restricted slot may return a duration object without a
    -- confirmed fire totem. Require an observed summon or readable identity.
    local fire = elements[1]
    local effect = fire.effect
    if not effect or not ActiveEffect(fire, effect.name) then
        return false, "no confirmed fire totem"
    end
    local timer = GetTotemDuration and GetTotemDuration(1)
    if Readable(timer) and timer and timer.IsActive then
        local active = timer:IsActive()
        if Readable(active) and active ~= nil then return active, "live fire totem timer" end
    end
    return true, "tracked fire totem"
end

local function PaintFireNovaTint(icon)
    local active = FireTotemStatus()
    if icon.SetDesaturation then
        icon:SetDesaturation(active and 0 or 1)
    else
        icon:SetDesaturated(not active)
    end
end

local function PaladinAuraActive(name)
    if not name then return false end
    -- The personal aura bar reports which aura this Paladin has selected.
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        local count = GetNumShapeshiftForms()
        if Readable(count) and count then
            for index = 1, count do
                local _, active, _, spell = GetShapeshiftFormInfo(index)
                if Readable(spell) and spell and C_Spell.GetSpellName(spell) == name and Readable(active) then
                    return active == true
                end
            end
        end
    end
    local lookup = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not lookup then return false end
    local ok, aura = pcall(lookup, "player", name, "HELPFUL|PLAYER")
    return ok and Readable(aura) and aura ~= nil
end

local function PaintSelection(state)
    if EditModeActive() then return end
    local selected = state.button:GetAttribute("spell1")
    local name = selected and C_Spell.GetSpellName(selected)
    local texture = selected and C_Spell.GetSpellTexture(selected)
    local effect = ActiveEffect(state, name)
    state.icon:SetTexture(texture or 134400)
    state.buttonTint = nil
    UpdateLowMana(state, selected)
    PaintButtonTint(state, effect)
    if state.kind == "nova" then
        PaintFireNovaTint(state.icon)
    elseif state.kind == "aura" then
        state.icon:SetDesaturated(TotemButtonsDB.greyInactive ~= false and not PaladinAuraActive(name))
    else
        state.icon:SetDesaturated(not effect and TotemButtonsDB.greyInactive ~= false)
    end
    if selected then TotemButtonsDB[state.key] = selected end

    local cooldown = state.cooldown
    local hideNumbers = TotemButtonsDB.showCountdown == false
    cooldown.noCooldownCount = hideNumbers
    cooldown:SetHideCountdownNumbers(hideNumbers)

    local start, duration, rate, timer
    if effect then
        start, duration, timer = effect.start, effect.duration, effect.timer
    elseif selected and (state.slot or state.kind == "nova") then
        start, duration, rate, timer = ReadSpellCooldown(selected, cooldown)
    end
    local showingSpellCooldown = not effect and (start ~= nil or timer ~= nil)
    state.displayedEffect = effect
    if start == state.paintedStart and duration == state.paintedDuration
        and rate == state.paintedRate and timer == state.paintedTimer
        and showingSpellCooldown == state.showingSpellCooldown then return end
    state.paintedStart, state.paintedDuration, state.paintedRate, state.paintedTimer = start, duration, rate, timer
    state.showingSpellCooldown = showingSpellCooldown
    state.paintingCooldown = true
    cooldown:SetReverse(not showingSpellCooldown)
    if timer and cooldown.SetCooldownFromDurationObject then
        cooldown:SetCooldownFromDurationObject(timer)
    elseif start then
        cooldown:SetCooldown(start, duration, rate or 1)
    else
        cooldown:Clear()
    end
    state.paintingCooldown = false
end

local function FindEffectName(state, spellID, totemName, icon)
    local idName = Readable(spellID) and spellID and C_Spell.GetSpellName(spellID)
    local npcName = Readable(totemName) and totemName
    if npcName and npcName ~= "" then npcName = npcName:gsub(" [IVX]+$", "") end
    local iconMatch, ambiguous
    for index, id in ipairs(state.spells) do
        local name = C_Spell.GetSpellName(id)
        if name and (name == idName or name == npcName) then return name end
        local choice = state.choices[index]
        if name and Readable(icon) and icon and icon ~= 0
            and (icon == C_Spell.GetSpellTexture(id)
                or (choice.spellID and icon == C_Spell.GetSpellTexture(choice.spellID))) then
            if iconMatch and iconMatch ~= name then ambiguous = true end
            iconMatch = name
        end
    end
    if not ambiguous then return iconMatch end
end

-- WoW exposes the player's position, so use the summon point as an estimate.
local totemRangeYards = {
    [5730] = 8, -- Stoneclaw
    [8190] = 8, -- Magma
    [2484] = 10, -- Earthbind
    [3599] = 20, -- Searing
    [8227] = 30, -- Flametongue
    [8181] = 30, -- Frost Resistance
    [8071] = 30, -- Stoneskin
    [8075] = 30, -- Strength of Earth
    [8143] = 30, -- Tremor
    [5394] = 30, -- Healing Stream
    [5675] = 30, -- Mana Spring
    [8166] = 30, -- Poison Cleansing
    [8170] = 30, -- Disease Cleansing
    [8184] = 30, -- Fire Resistance
    [16190] = 30, -- Mana Tide
    [8177] = 30, -- Grounding (the redirect effect, spell 8178)
    [8512] = 30, -- Windfury
    [8835] = 30, -- Grace of Air
    [10595] = 30, -- Nature Resistance
    [15107] = 30, -- Windwall
}

local earthbindName
local earthbindRangeSquared = 10 * 10
local function ReadEarthsGraspRank()
    if not C_Traits then return 0 end
    local configID
    local spec = C_SpecializationInfo
    if spec and spec.GetActiveSpecGroup and spec.GetCombatConfigIDForSpecGroup then
        local group = spec.GetActiveSpecGroup()
        if group then configID = spec.GetCombatConfigIDForSpecGroup(group) end
    end
    if not configID and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        configID = C_ClassTalents.GetActiveConfigID()
    end
    local config = configID and C_Traits.GetConfigInfo(configID)
    if not config or not config.treeIDs then return end
    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            if node and node.activeRank and node.activeRank > 0 then
                for _, entryID in ipairs(node.entryIDs or {}) do
                    local entry = C_Traits.GetEntryInfo(configID, entryID)
                    local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                    local spellID = definition and definition.spellID
                    if spellID == 16043 or spellID == 16130 then -- Earth's Grasp
                        return math.min(node.activeRank, 2)
                    end
                end
            end
        end
    end
    return 0
end

local function RefreshTotemTalents()
    earthbindName = C_Spell.GetSpellName(2484)
    local rank = ReadEarthsGraspRank()
    if rank then
        local yards = totemRangeYards[2484] + rank
        earthbindRangeSquared = yards * yards
    end
end

local function TotemRangeSquared(name)
    for spellID, yards in pairs(totemRangeYards) do
        if name == C_Spell.GetSpellName(spellID) then return yards * yards end
    end
    -- Sentry grants vision without a documented player effect radius.
end

local function ReadUnitPosition()
    if not UnitPosition then return end
    local ok, x, y, _, instance = pcall(UnitPosition, "player")
    if ok and Readable(x) and Readable(y) and Readable(instance) and x and y and instance then
        return { x = x, y = y, instance = instance }
    end
end

local function ReadMapPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition
        and C_Map.GetWorldPosFromMapPos) then return end
    local ok, position = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        if not Readable(map) or not map then return end
        local point = C_Map.GetPlayerMapPosition(map, "player")
        if not Readable(point) or not point then return end
        local mapX, mapY = point:GetXY()
        if not Readable(mapX) or not Readable(mapY) or (mapX == 0 and mapY == 0) then return end
        local instance, world = C_Map.GetWorldPosFromMapPos(map, point)
        if not Readable(instance) or not instance or not Readable(world) or not world then return end
        local x, y = world:GetXY()
        if Readable(x) and Readable(y) and x and y then return { x = x, y = y, instance = instance } end
    end)
    if ok then return position end
end

local function CaptureTotemOrigin(name)
    if totemAuraIDsByName[name] or IsInInstance() then return end
    local rangeSquared = TotemRangeSquared(name)
    if not rangeSquared then return end
    local unit, map = ReadUnitPosition(), ReadMapPosition()
    if unit or map then return { unit = unit, map = map, rangeSquared = rangeSquared } end
end

local function UpdateTotemRanges()
    local checkDistance = TotemButtonsDB.showRangeTint ~= false and TotemButtonsDB.includeNonBuffTotems == true
        and not IsInInstance()
    local unit, map
    local buffReads = {}
    for _, state in ipairs(states) do
        if state.kind == "nova" and state.host and state.button:IsVisible() then
            PaintFireNovaTint(state.icon)
        end
        local effect = state.slot and state.effect
        if effect then
            local origin = effect.origin
            local wasKnown = effect.rangeKnown
            local outOfRange = false
            effect.rangeKnown = false
            if checkDistance and origin and not totemAuraIDsByName[effect.name] and ActiveEffect(state, effect.name) then
                local from, current = origin.unit
                if from then
                    if unit == nil then unit = ReadUnitPosition() or false end
                    current = unit
                end
                if (not current or current.instance ~= from.instance) and origin.map then
                    if map == nil then map = ReadMapPosition() or false end
                    from, current = origin.map, map
                end
                if current and current.instance == from.instance then
                    local dx, dy = current.x - from.x, current.y - from.y
                    effect.rangeKnown = true
                    local rangeSquared = effect.name == earthbindName and earthbindRangeSquared or origin.rangeSquared
                    outOfRange = dx * dx + dy * dy > rangeSquared
                elseif not current then
                    -- A missing position sample does not establish that the player moved back in range.
                    outOfRange = effect.outOfRange
                end
            end
            if outOfRange ~= effect.outOfRange or wasKnown ~= effect.rangeKnown or totemAuraIDsByName[effect.name] then
                effect.outOfRange = outOfRange
                local selected = state.button:GetAttribute("spell1")
                local name = selected and C_Spell.GetSpellName(selected)
                PaintButtonTint(state, ActiveEffect(state, name), buffReads)
            end
        end
    end
end

local function RelocateTotems()
    recentTotemCasts = {}
    local unit, map
    if not IsInInstance() then unit, map = ReadUnitPosition(), ReadMapPosition() end
    local time = GetTime()
    for _, state in ipairs(states) do
        local effect = state.slot and state.effect
        if effect and ActiveEffect(state, effect.name) then
            local rangeSquared = not totemAuraIDsByName[effect.name] and TotemRangeSquared(effect.name)
            effect.origin = nil
            if rangeSquared and (unit or map) then
                effect.origin = { unit = unit, map = map, rangeSquared = rangeSquared }
            end
            effect.relocatedAt = time
            effect.outOfRange = false
            effect.rangeKnown = effect.origin ~= nil
            PaintSelection(state)
        end
    end
end

local function UpdateTotem(state, summoned)
    local have, totemName, start, duration, icon, _, spellID = GetTotemInfo(state.slot)
    local effect = state.effect
    local time = GetTime()
    if Readable(have) and have == false then
        state.effect = nil
        PaintSelection(state)
        return
    end

    local name = FindEffectName(state, spellID, totemName, icon)
    local recent = recentTotemCasts[state.slot]
    if recent and time - recent.time > 2 then recent = nil end
    local relocated = effect and effect.relocatedAt
    local relocationUpdate = relocated and time - relocated <= 0.5 and (not recent or recent.time <= relocated)
    if relocationUpdate then
        -- A slot update after Totemic Call reports a move of the existing totem.
        summoned = false
        recent = nil
        name = name or effect.name
    end
    if Readable(start) and Readable(duration) and type(start) == "number" and type(duration) == "number" then
        if not name and recent and math.abs(start - recent.time) <= 2 then name = recent.name end
        local sameSummon = effect and (effect.start == start or relocationUpdate
            or (effect.castTime and (not recent or recent.time == effect.castTime)
                and math.abs(start - effect.castTime) <= 2)
            or (not summoned and not effect.expired and not effect.start and not effect.castTime))
        if not name and sameSummon then name = effect.name end
        if name and duration > 0 and start + duration > time then
            local previous = effect
            effect = { name = name, start = start, duration = duration }
            if recent and recent.name == name and math.abs(start - recent.time) <= 2 then
                effect.castTime = recent.time
            end
            learnedTotemDurations[name] = duration
            if sameSummon and previous.name == name then
                -- Refresh can replace restricted timing with an exact start after combat.
                -- Keep the summon position and range state for the same totem.
                effect.origin = previous.origin
                effect.outOfRange = previous.outOfRange
                effect.rangeKnown = previous.rangeKnown
                effect.relocatedAt = previous.relocatedAt
            end
            if not effect.origin and summoned and math.abs(time - start) <= 2 then
                if recent and recent.name == name then effect.origin = recent.origin end
                if not effect.origin then effect.origin = CaptureTotemOrigin(name) end
            end
        else
            effect = nil
        end
    else
        -- A successful player cast identifies the spell when the slot reports
        -- only restricted values. The Cooldown widget can still render its timer.
        name = name or (recent and recent.name) or (not summoned and effect and effect.name)
        local cast = recent and recent.name == name and recent or nil
        local timer = GetTotemDuration and GetTotemDuration(state.slot)
        local zero
        if timer and timer.IsZero then zero = timer:IsZero() end
        if Readable(zero) and zero then
            effect = nil
        elseif name and timer and (not effect or effect.expired or effect.name ~= name
            or (cast and effect.castTime ~= cast.time)) then
            local origin = cast and cast.origin
            if cast and not origin then
                origin = CaptureTotemOrigin(name)
                cast.origin = origin
            end
            effect = { name = name, timer = timer, origin = origin, castTime = cast and cast.time }
        elseif cast and not timer and learnedTotemDurations[name] and (not effect or effect.castTime ~= cast.time) then
            if not cast.origin then cast.origin = CaptureTotemOrigin(name) end
            effect = {
                name = name, start = cast.time, duration = learnedTotemDurations[name], origin = cast.origin,
                castTime = cast.time,
            }
        elseif (summoned and not name) or (Readable(have) and have == nil and not timer) then
            effect = nil
        end
    end
    state.effect = effect
    PaintSelection(state)
end

local function ReadMainHandImbue()
    local read = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
    if not read then return end
    local info = read(mainHandSlot)
    if not Readable(info) then return nil, false end
    if not info then return nil, true end
    local id, left = info.enchantID, info.remainingTimeMs
    if not Readable(id) or not Readable(left) then return nil, false end
    local family = id and imbueEnchantFamilies[id]
    local name = family and C_Spell.GetSpellName(family)
    if name and left and left > 0 then
        return { name = name, start = GetTime() + left / 1000 - 3600, duration = 3600 }, true
    end
    -- An unrecognized enchant could be an oil or a new imbue rank.
    return nil, false
end

local function UpdateImbue(state)
    local enchants = C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)
    local effect
    local restricted = not Readable(enchants)
    if not restricted then
        for _, enchant in ipairs(enchants or {}) do
            if not Readable(enchant) or not Readable(enchant.enchantType) then
                restricted = true
            elseif enchant.enchantType == Enum.ItemEnchantType.Imbue then
                local left, applied = enchant.timeLeft, enchant.hasEnchant
                if not Readable(applied) or (applied and not Readable(left)) then
                    restricted = true
                elseif applied and type(left) == "number" and left > 0 then
                    local enchantID = enchant.enchantID
                    local name = FindEffectName(state, nil, nil, enchant.enchantIconID)
                    if not name and Readable(enchantID) and enchantID then
                        local familyID = imbueEnchantFamilies[enchantID]
                        if familyID then name = C_Spell.GetSpellName(familyID) end
                    end
                    if name then
                        local duration = 3600
                        effect = { name = name, start = GetTime() + left / 1000 - duration, duration = duration }
                    else
                        restricted = not Readable(enchantID) or not Readable(enchant.enchantIconID)
                    end
                end
                break
            end
        end
    end
    if not effect and (restricted or InCombatLockdown()) then
        local confirmed
        effect, confirmed = ReadMainHandImbue()
        if not effect then
            local recent = recentImbueCast
            if recent and GetTime() - recent.time <= 2 then
                effect = { name = recent.name, start = recent.time, duration = 3600 }
            elseif not confirmed then
                effect = state.effect
            end
        end
    end
    state.effect = effect
    PaintSelection(state)
end

local function ReadShieldAPI(read, ...)
    if not read then return nil, false end
    local ok, value = pcall(read, ...)
    if ok then return value, true end
    return nil, false
end

local function ShieldEffectFromAura(name, aura, instance)
    local id = aura.auraInstanceID
    if Readable(id) and id then instance = id end
    local effect = { name = name, instance = instance }
    local expiration, duration = aura.expirationTime, aura.duration
    if Readable(expiration) and Readable(duration)
        and type(duration) == "number" and duration > 0 and type(expiration) == "number" then
        effect.start, effect.duration = expiration - duration, duration
    elseif instance and C_UnitAuras.GetAuraDuration then
        effect.timer = ReadShieldAPI(C_UnitAuras.GetAuraDuration, "player", instance)
    end
    return effect
end

local function ShieldAuraMatches(aura, name)
    if not Readable(aura) or not aura then return false end
    local spell = aura.spellId
    if Readable(spell) and spell and C_Spell.GetSpellName(spell) == name then return true end
    return Readable(aura.name) and aura.name == name
end

local function HasAuraInstance(ids, instance)
    if not instance or not Readable(ids) or not ids then return false end
    for _, id in ipairs(ids) do
        if Readable(id) and id == instance then return true end
    end
    return false
end

local function ReadShieldEffect(name, spellID, instance, updateInfo)
    local api = C_UnitAuras
    local removed = updateInfo and updateInfo.removedAuraInstanceIDs
    local added = updateInfo and updateInfo.addedAuras

    local function FromLiveAura(aura, instance)
        if not Readable(aura) or not aura then return end
        local id = aura.auraInstanceID
        if HasAuraInstance(removed, Readable(id) and id or instance) then return end
        return ShieldEffectFromAura(name, aura, instance)
    end

    if Readable(added) and added then
        for _, aura in ipairs(added) do
            if ShieldAuraMatches(aura, name) then
                local effect = FromLiveAura(aura)
                if effect then return effect, "aura added" end
            end
        end
    end

    local aura = ReadShieldAPI(api.GetAuraDataBySpellName, "player", name, "HELPFUL")
    local effect = FromLiveAura(aura)
    if effect then return effect, "buff name" end
    aura = ReadShieldAPI(api.GetPlayerAuraBySpellID, spellID)
    effect = FromLiveAura(aura)
    if effect then return effect, "spell ID" end

    local ids = ReadShieldAPI(api.GetUnitAuraInstanceIDs, "player", "HELPFUL")
    if instance and not HasAuraInstance(removed, instance) then
        local aura = ReadShieldAPI(api.GetAuraDataByAuraInstanceID, "player", instance)
        effect = FromLiveAura(aura, instance)
        if effect then return effect, "live aura instance" end
        if HasAuraInstance(ids, instance) then
            return ShieldEffectFromAura(name, {}, instance), "active buff list"
        end
    end

    local auras = ReadShieldAPI(api.GetUnitAuras, "player", "HELPFUL")
    if Readable(auras) and auras then
        for _, aura in ipairs(auras) do
            if ShieldAuraMatches(aura, name) then
                effect = FromLiveAura(aura)
                if effect then return effect, "player buffs" end
            end
        end
    end
    if Readable(ids) and ids then
        for _, id in ipairs(ids) do
            if Readable(id) then
                local aura = ReadShieldAPI(api.GetAuraDataByAuraInstanceID, "player", id)
                if ShieldAuraMatches(aura, name) then
                    effect = FromLiveAura(aura, id)
                    if effect then return effect, "player buff instances" end
                end
            end
        end
    end

    if api.GetAuraDataByIndex then
        for index = 1, 255 do
            local aura, checked = ReadShieldAPI(api.GetAuraDataByIndex, "player", index, "HELPFUL")
            if not checked or (Readable(aura) and not aura) then break end
            if ShieldAuraMatches(aura, name) then
                effect = FromLiveAura(aura)
                if effect then return effect, "player buff slot" end
            end
        end
    end
    return nil, "buff unavailable"
end

local function UpdateTimedAura(state, updateInfo)
    state.shields = state.shields or {}
    if UpdateTimedAuraArtwork(state) then
        wipe(state.shields)
        state.shieldSource = "native aura display"
        PaintSelection(state)
        return
    end
    if not C_UnitAuras then return end
    local selected = state.button:GetAttribute("spell1")
    local name = selected and C_Spell.GetSpellName(selected)
    local effect, source
    if name then
        if not Readable(updateInfo) then updateInfo = nil end
        if state.trackedShieldName ~= name then state.trackedShieldInstance = nil end
        if updateInfo and HasAuraInstance(updateInfo.removedAuraInstanceIDs, state.trackedShieldInstance) then
            state.trackedShieldInstance = nil
        end
        effect, source = ReadShieldEffect(name, selected, state.trackedShieldInstance, updateInfo)
        state.trackedShieldName = name
        if effect and effect.instance then
            state.trackedShieldInstance = effect.instance
        elseif not effect and not InCombatLockdown() then
            state.trackedShieldInstance = nil
        end
    end
    wipe(state.shields)
    if effect then state.shields[name] = effect end
    state.shieldSource = source
    PaintSelection(state)
end

local function RefreshTimedAuras()
    for _, state in ipairs(states) do
        if UsesTimedAura(state) and state.host then
            UpdateTimedAura(state)
        end
    end
end

local function NotePlayerCast(spellID)
    if not Readable(spellID) or type(spellID) ~= "number" then return end
    if spellID == 437009 then -- Totemic Call
        RelocateTotems()
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    if not name then return end
    for _, element in ipairs(elements) do
        if element.kind ~= "nova" then
            for _, baseID in ipairs(element.spells) do
                if name == C_Spell.GetSpellName(baseID) then
                    local slot, kind = element.slot, element.kind
                    local cast = { name = name, time = GetTime() }
                    if slot then
                        cast.origin = CaptureTotemOrigin(name)
                        recentTotemCasts[slot] = cast
                    elseif kind == "imbue" then
                        recentImbueCast = cast
                    end
                    C_Timer.After(0, function()
                        for _, state in ipairs(states) do
                            if slot and state.slot == slot and recentTotemCasts[slot] == cast then
                                UpdateTotem(state, true)
                            elseif slot == 1 and state.kind == "nova" then
                                PaintSelection(state)
                            elseif kind == "imbue" and state.kind == kind and recentImbueCast == cast then
                                UpdateImbue(state)
                            elseif state.kind == kind and UsesTimedAura(state) then
                                UpdateTimedAura(state)
                            end
                        end
                    end)
                    return
                end
            end
        end
    end
end

local function UpdateTimer(state)
    if state.kind == "imbue" then
        UpdateImbue(state)
    elseif UsesTimedAura(state) then
        UpdateTimedAura(state)
    elseif state.slot then
        UpdateTotem(state)
    else
        PaintSelection(state)
    end
end

local function PaintButton(button, texture, useSlotBorder)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(texture or 134400)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not useSlotBorder then
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
    return icon
end

local stockBars = {
    ActionButton = "ACTIONBUTTON",
    MultiBarBottomLeftButton = "MULTIACTIONBAR1BUTTON",
    MultiBarBottomRightButton = "MULTIACTIONBAR2BUTTON",
    MultiBarRightButton = "MULTIACTIONBAR3BUTTON",
    MultiBarLeftButton = "MULTIACTIONBAR4BUTTON",
    MultiBar5Button = "MULTIACTIONBAR5BUTTON",
    MultiBar6Button = "MULTIACTIONBAR6BUTTON",
    MultiBar7Button = "MULTIACTIONBAR7BUTTON",
}
local barPrefixes = { "EABButton", "BT4Button", "ActionButton", "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton",
    "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

local function HostAction(host)
    local prefix = host:GetName():match("^(%a[%w]-)%d+$")
    if prefix == "BT4Button" and host:GetAttribute("type") ~= "action" then return end
    if stockBars[prefix] and host.CalculateAction then
        return host:CalculateAction("LeftButton")
    end
    return host:GetAttribute("action") or host.action
end

local function HostKeys(host)
    local name = host:GetName()
    local prefix, index = name:match("^(%a[%w]-)(%d+)$")
    local stockBinding = stockBars[prefix]
    local bartender = prefix == "BT4Button"
    local command = host.commandName or host.bindingAction
    if bartender then
        command = host.config and host.config.keyBoundTarget
    elseif stockBinding then
        command = stockBinding .. index
    end
    local keys = {}
    if command then keys = { GetBindingKey(command) } end
    if bartender or stockBinding then
        local click = "CLICK " .. name .. ":" .. (bartender and "Keybind" or "LeftButton")
        for _, key in ipairs({ GetBindingKey(click) }) do
            if key and key ~= "" then keys[#keys + 1] = key end
        end
    end
    return keys, command
end

local function SyncSlotKeys(state, force)
    local keys = HostKeys(state.host)
    local visible = state.button:IsVisible()
    local name = state.keyButton:GetName()
    local expected = "CLICK " .. name .. ":LeftButton"
    local signature = table.concat(keys, "\n")

    if not force and signature == state.keySignature then
        if not visible then return end
        local missing
        for _, key in ipairs(keys) do
            if GetBindingAction(key, true) ~= expected then
                missing = true
                break
            end
        end
        if not missing then return end
        if state.lastKeyWrite and GetTime() - state.lastKeyWrite < 0.5 then return end
    end

    local owner = state.bindOwner
    state.keySignature = signature
    state.lastKeyWrite = GetTime()
    owner:SetAttribute("keyCount", #keys)
    ClearOverrideBindings(owner)
    for index, key in ipairs(keys) do
        owner:SetAttribute("key" .. index, key)
        if visible then SetOverrideBindingClick(owner, true, key, name, "LeftButton") end
    end
end

local dropWatcher = CreateFrame("Frame")
local pendingDrop

local function HoveredActionButton()
    local foci = GetMouseFoci and GetMouseFoci()
    local frame = foci and foci[1]
    while frame do
        local name = frame:GetName()
        local prefix = name and name:match("^(%a[%w]-)%d+$")
        if stockBars[prefix] or prefix == "EABButton" or prefix == "BT4Button" then
            if frame:IsVisible() and frame:IsMouseOver() then return frame end
            return
        end
        frame = frame.GetParent and frame:GetParent()
    end
end

local function WatchDragRelease()
    local kind, id = GetCursorInfo()
    if kind ~= "macro" or not id then return end
    pendingDrop = { kind = kind, id = id }
    dropWatcher:RegisterEvent("GLOBAL_MOUSE_UP")
end

dropWatcher:SetScript("OnEvent", function(self, _, mouseButton)
    if mouseButton ~= "LeftButton" then return end
    local drag = pendingDrop
    pendingDrop = nil
    self:UnregisterEvent("GLOBAL_MOUSE_UP")
    if not drag or InCombatLockdown() then return end

    local target = HoveredActionButton()
    local action = target and HostAction(target)
    if not action or action <= 0 then return end

    -- Give the standard bars their first chance to handle the release.
    C_Timer.After(0, function()
        if InCombatLockdown() or HostAction(target) ~= action then return end
        local kind, id = GetCursorInfo()
        if kind ~= drag.kind or id ~= drag.id then return end
        local existingKind, existingID = GetActionInfo(action)
        if existingKind == kind and existingID == id then return end
        PlaceAction(action)
    end)
end)

local function HideMacroLabel(state)
    local host = state.host
    if not host or state.macroLabel then return end
    local label = host.Name or _G[host:GetName() .. "Name"]
    if not label then return end
    local alpha = label:GetAlpha()
    if not Readable(alpha) then return end
    state.macroLabel, state.macroLabelAlpha = label, alpha
    label:SetAlpha(0)
end

local function RestoreMacroLabel(state)
    if not state.macroLabel then return end
    state.macroLabel:SetAlpha(state.macroLabelAlpha)
    state.macroLabel, state.macroLabelAlpha = nil, nil
end

-- Hide the bar slot macro texture beneath the spell artwork while the overlay
-- owns that slot, including while its bar is hidden.
local macroIconStates = setmetatable({}, { __mode = "k" })

local function RestoreMacroIcon(state)
    local icon = state.macroIcon
    if not icon then return end
    state.macroIcon = nil
    local entry = macroIconStates[icon]
    if entry.owner == state then
        entry.owner = nil
        icon:SetShown(entry.wantShown)
    end
end

local function SuppressMacroIcon(state)
    local host = state.host
    if not host or not state.button:IsShown() then return end
    local icon = host.icon or host.Icon
    if not icon or state.macroIcon == icon then return end
    RestoreMacroIcon(state)

    local entry = macroIconStates[icon]
    if not entry then
        entry = {}
        macroIconStates[icon] = entry

        local function KeepHidden(region, wantsShown)
            if entry.hiding or not entry.owner or not Readable(wantsShown) then return end
            entry.wantShown = wantsShown and true or false
            if wantsShown then
                entry.hiding = true
                region:Hide()
                entry.hiding = false
            end
        end

        hooksecurefunc(icon, "Show", function(region) KeepHidden(region, true) end)
        hooksecurefunc(icon, "Hide", function(region) KeepHidden(region, false) end)
        hooksecurefunc(icon, "SetShown", KeepHidden)
        host:HookScript("OnShow", function()
            local owner = entry.owner
            if owner and not owner.button:IsShown() then RestoreMacroIcon(owner) end
        end)
    end
    if entry.owner then RestoreMacroIcon(entry.owner) end
    local shown = icon:IsShown()
    if not Readable(shown) then return end

    state.macroIcon = icon
    entry.owner, entry.wantShown = state, shown and true or false
    entry.hiding = true
    icon:Hide()
    entry.hiding = false
end

-- Mouse motion can reach the underlying action button too. Keep its normal
-- tooltip anchor and visibility, but use the selected spell for our active slot.
hooksecurefunc(GameTooltip, "SetAction", function(tooltip)
    local host = tooltip:GetOwner()
    if not Readable(host) or not host or not hosts[host] then return end

    for _, state in ipairs(states) do
        if state.host == host and state.button:IsVisible() and state.button:IsMouseOver() then
            local spell = state.button:GetAttribute("spell1")
            if spell then tooltip:SetSpellByID(spell) end
            return
        end
    end
end)

local function Build(state)
    local button = CreateFrame("Button", "TotemButton_" .. state.key:gsub("-", "_"), UIParent,
        "SecureActionButtonTemplate")
    state.button = button
    -- Cast on release so starting a drag does not cast the selected spell.
    if state.slot then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    else
        button:RegisterForClicks("LeftButtonUp")
    end
    if state.slot then
        button:SetAttribute("type2", "destroytotem")
        button:SetAttribute("totem-slot2", state.slot)
    end
    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForDrag("LeftButton")
    button:SetAttribute("type1", "spell")
    button:Hide()

    -- Key presses go to their own secure button, independent of mouse drag/release.
    local keyButton = CreateFrame("Button", button:GetName() .. "Key", UIParent, "SecureActionButtonTemplate")
    -- WoW chooses the casting edge. Listen on both edges for CLICK bindings
    -- and let the secure template handle ordinary spells using the client setting.
    keyButton:RegisterForClicks("AnyDown", "AnyUp")
    keyButton:SetAttribute("type", "spell")
    keyButton:HookScript("PostClick", function(_, _, down)
        state.keyClicks = (state.keyClicks or 0) + 1
        state.lastKeyEdge = down and "down" or "up"
    end)
    state.keyButton = keyButton

    -- Secure visibility hooks keep the slot's keys routed correctly through
    -- page swaps and visibility changes, including in combat.
    local owner = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    state.bindOwner = owner
    owner:SetAttribute("buttonName", keyButton:GetName())
    local function CurrentAction()
        if InCombatLockdown() or not state.host then return end
        local action = HostAction(state.host)
        if action and action == state.action then return action end
    end
    button:SetScript("OnDragStart", function()
        local action = CurrentAction()
        if action and not GetCursorInfo() then
            PickupAction(action)
            WatchDragRelease()
        end
    end)
    button:SetScript("OnReceiveDrag", function()
        local action = CurrentAction()
        if action and GetCursorInfo() then PlaceAction(action) end
    end)
    SecureHandlerWrapScript(button, "OnShow", owner, [[
        local name = control:GetAttribute("buttonName")
        for index = 1, control:GetAttribute("keyCount") or 0 do
            control:SetBindingClick(true, control:GetAttribute("key" .. index), name, "LeftButton")
        end
    ]])
    SecureHandlerWrapScript(button, "OnHide", owner, [[
        control:ClearBindings()
        local flyout = control:GetFrameRef("flyout")
        if flyout then flyout:Hide() end
    ]])
    state.icon = PaintButton(button, nil, true)
    state.icon:Hide()
    button:HookScript("OnShow", function()
        state.icon:Show()
        SuppressMacroIcon(state)
        HideMacroLabel(state)
    end)
    button:HookScript("OnHide", function()
        state.icon:Hide()
        -- An ancestor hiding fires OnHide even though this button still owns
        -- the slot. Keep the underlying icon hidden until the overlay itself leaves.
        if not button:IsShown() then RestoreMacroIcon(state) end
        RestoreMacroLabel(state)
    end)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    state.cooldown = cooldown
    button:HookScript("OnSizeChanged", function(_, width, height)
        if state.host then UpdateCountdownFont(state, width, height) end
    end)
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetReverse(true)
    cooldown:HookScript("OnCooldownDone", function()
        if state.paintingCooldown then return end
        if UsesTimedAura(state) then
            UpdateTimedAura(state)
            return
        end
        if state.showingSpellCooldown then
            PaintSelection(state)
        elseif state.displayedEffect then
            state.displayedEffect.expired = true
            PaintSelection(state)
        end
    end)
    local function ShowSpellTooltip(self)
        local spell = self:GetAttribute("spell1")
        if not spell then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetSpellByID(spell)
        GameTooltip:Show()
    end
    local function HideSpellTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    button:SetScript("OnEnter", ShowSpellTooltip)
    button:SetScript("OnLeave", HideSpellTooltip)
    button:HookScript("OnHide", HideSpellTooltip)
    if UsesTimedAura(state) then
        button:HookScript("OnHide", function()
            if not state.nativeAuraLayers then return end
            for _, layer in pairs(state.nativeAuraLayers) do layer.host:Hide() end
        end)
        button:HookScript("OnShow", function()
            if state.host then UpdateTimedAura(state) end
        end)
    end
    button:HookScript("OnAttributeChanged", function(self, attribute)
        if attribute ~= "spell1" then return end
        if UsesTimedAura(state) then
            UpdateTimedAura(state)
        else
            PaintSelection(state)
        end
        if GameTooltip:IsOwned(self) then
            HideSpellTooltip(self)
            ShowSpellTooltip(self)
        end
    end)

    local flyout = CreateFrame("Frame", nil, button, "SecureHandlerStateTemplate")
    flyout:SetPoint("BOTTOM", button, "TOP")
    flyout:SetSize(1, 1)
    -- Retain the flyout layer when the anchor is attached to an action bar.
    flyout:SetFrameStrata("TOOLTIP")
    flyout:SetFixedFrameStrata(true)
    flyout:Hide()
    state.flyout, state.choices = flyout, {}
    local function NotifyBarFlyout(shown)
        local host = state.host
        if host and host._eabExternalFlyoutChanged then
            host._eabExternalFlyoutChanged(host, shown)
        end
    end
    flyout:HookScript("OnShow", function() NotifyBarFlyout(true) end)
    flyout:HookScript("OnHide", function() NotifyBarFlyout(false) end)
    SecureHandlerSetFrameRef(flyout, "button", button)
    SecureHandlerSetFrameRef(flyout, "keyButton", keyButton)
    flyout:SetAttribute("showChoices", [[
        if not self:GetAttribute("hasChoices") then return end
        if self:GetAttribute("requireShift") and self:GetAttribute("state-flyoutshift") ~= "held" then return end
        local anchor = self:GetFrameRef("button")
        self:Show()
        self:RegisterAutoHide(0.15)
        self:AddToAutoHide(anchor)
        for _, choice in ipairs(newtable(self:GetChildren())) do
            if choice:IsShown() then self:AddToAutoHide(choice) end
        end
    ]])
    flyout:SetAttribute("hideChoicesOnLeave", [[
        if not self:IsVisible() then return end
        local anchor = self:GetFrameRef("button")
        if not anchor:IsUnderMouse() and not self:IsUnderMouse() then
            self:Hide()
        end
    ]])
    SecureHandlerWrapScript(button, "OnEnter", flyout, [[
        control:SetAttribute("anchorHovered", true)
        control:RunAttribute("showChoices")
    ]])
    SecureHandlerWrapScript(button, "OnLeave", flyout, [[
        control:SetAttribute("anchorHovered", nil)
        control:RunAttribute("hideChoicesOnLeave")
    ]])
    flyout:SetAttribute("_onstate-flyoutshift", [[
        if not self:GetAttribute("requireShift") then return end
        if newstate ~= "held" then
            self:Hide()
        elseif self:GetAttribute("anchorHovered") then
            local anchor = self:GetFrameRef("button")
            if anchor:IsVisible() and anchor:IsUnderMouse() then self:RunAttribute("showChoices") end
        end
    ]])
    SecureHandlerSetFrameRef(owner, "flyout", flyout)
    for index = 1, #state.spells do
        local choice = CreateFrame("Button", nil, flyout, "SecureActionButtonTemplate")
        choice:SetFrameStrata(flyout:GetFrameStrata())
        choice:SetFixedFrameStrata(true)
        choice:SetPoint("BOTTOMLEFT", flyout, "BOTTOMLEFT")
        choice:RegisterForClicks("LeftButtonUp")
        if flyoutCastOptions[state.kind] then choice:SetAttribute("useOnKeyDown", false) end
        choice.icon = PaintButton(choice)
        local rim = choice:CreateTexture(nil, "BACKGROUND")
        rim:SetColorTexture(0.45, 0.45, 0.45, 1)
        rim:SetAllPoints(choice)
        -- A fixed inset keeps the rim thin at every flyout button size.
        choice.icon:ClearAllPoints()
        choice.icon:SetPoint("TOPLEFT", choice, "TOPLEFT", 1, -1)
        choice.icon:SetPoint("BOTTOMRIGHT", choice, "BOTTOMRIGHT", -1, 1)
        choice:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end)
        choice:SetScript("OnLeave", function() GameTooltip:Hide() end)
        SecureHandlerWrapScript(choice, "OnLeave", flyout, [[
            control:RunAttribute("hideChoicesOnLeave")
        ]])
        SecureHandlerWrapScript(choice, "OnClick", flyout, [[
            local spell = self:GetAttribute("totemSpell")
            if button == "LeftButton" and not down and spell then
                control:GetFrameRef("keyButton"):SetAttribute("spell", spell)
                local button = control:GetFrameRef("button")
                button:SetAttribute("spell1", spell)
                control:Hide()
            end
        ]])
        choice:Hide()
        state.choices[index] = choice
    end
end

local function ApplyFlyoutCastOption(state)
    local option = flyoutCastOptions[state.kind]
    if not option then return end
    local actionType = TotemButtonsDB[option] ~= false and "spell" or nil
    for _, choice in ipairs(state.choices) do
        -- The flyout can require Shift to stay open during the left-click.
        choice:SetAttribute("*type1", actionType)
    end
end

local function ApplyFlyoutModifier(state)
    if state.kind == "nova" then return end
    local required = TotemButtonsDB.shiftFlyouts == true
    local flyout = state.flyout
    if (flyout:GetAttribute("requireShift") == true) == required then return end
    flyout:SetAttribute("requireShift", required)
    if required then
        flyout:Hide()
        RegisterStateDriver(flyout, "flyoutshift", "[mod:shift] held; released")
    else
        UnregisterStateDriver(flyout, "flyoutshift")
    end
end

local function RefreshChoices(state, known, knownIDs)
    local selected = TotemButtonsDB[state.key]
    local selectedName = selected and C_Spell.GetSpellName(selected)
    local first, retained
    local size = state.button:GetWidth()
    if size <= 0 then size = 36 end
    size = size * 0.75
    local count = 0
    for index, baseID in ipairs(state.spells) do
        local choice = state.choices[index]
        local name = C_Spell.GetSpellName(baseID)
        local spell = name and known[name]
        local ranks = (state.kind == "seal" or state.kind == "buff") and timedAuraRanks[baseID]
        if ranks and spell then
            for rank = #ranks, 1, -1 do
                if knownIDs[ranks[rank]] then
                    spell = ranks[rank]
                    break
                end
            end
        end
        if flyoutCastOptions[state.kind] then choice:SetAttribute("*spell1", spell or nil) end
        if spell then
            count = count + 1
            first = first or spell
            if selectedName == name then retained = spell end
            choice.spellID = spell
            choice:SetAttribute("totemSpell", spell)
            choice.icon:SetTexture(C_Spell.GetSpellTexture(spell))
            choice:SetSize(size, size)
            choice:ClearAllPoints()
            choice:SetPoint("BOTTOMLEFT", state.flyout, "BOTTOMLEFT", 0, (count - 1) * size)
            choice:Show()
        else
            choice.spellID = nil
            choice:SetAttribute("totemSpell", nil)
            choice:Hide()
        end
    end
    ApplyFlyoutCastOption(state)
    state.flyout:SetSize(size, math.max(1, count) * size)
    state.flyout:SetAttribute("hasChoices", count > 0 and state.kind ~= "nova")
    ApplyFlyoutModifier(state)
    local spell = retained or first
    state.keyButton:SetAttribute("spell", spell)
    state.button:SetAttribute("spell1", spell)
end

local function KnownSpells()
    local known, knownIDs, book = {}, {}, C_SpellBook
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide and (not info.offSpecID or info.offSpecID == 0) then
            for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local itemType, actionID, spellID = book.GetSpellBookItemType(index, bank)
                local id = spellID or actionID
                if itemType == Enum.SpellBookItemType.Spell and id then
                    knownIDs[id] = true
                    local name = C_Spell.GetSpellName(id)
                    if name then known[name] = math.max(known[name] or 0, id) end
                end
            end
        end
    end
    return known, knownIDs
end

local function RegisterButton(state)
    Build(state)
    states[#states + 1] = state
    buttonsByKey[state.key] = state
    return state
end

-- Keep the ownership line stable when changing the macro body in future releases.
local function ButtonMacroBody(key)
    return "/stopmacro\n# TotemButtons:" .. key .. "\n# TB macro format: 1"
end

local function NormalizeMacroBody(body)
    return (body or ""):gsub("\r\n", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
end

local function RegisterCopy(original, key, label)
    return RegisterButton({
        key = key,
        label = label,
        slot = original.slot,
        kind = original.kind,
        spells = original.spells,
        effect = original.effect,
    })
end

local function MacroButton(body)
    local lines = "\n" .. NormalizeMacroBody(body) .. "\n"
    local key = lines:match("\n# TotemButtons:([%a%d%-]+)[ \t]*\n")
        or lines:match("\n# ElementTotemButtons:(%a+)[ \t]*\n")
    if not key then return end
    if buttonsByKey[key] then return buttonsByKey[key] end
    local element, copy = key:match("^(%a+)%-([1-9]%d*)$")
    local original = elementsByKey[element]
    if not original or tonumber(copy) < 2 then return end
    return RegisterCopy(original, key, original.label .. " " .. copy)
end

local function ReadButtonMacros()
    local accountCount, characterCount = GetNumMacros()
    local characterOffset = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local byButton, names, legacyNames = {}, {}, {}

    -- Character macros occupy a separate index range even with empty account slots.
    for group = 1, 2 do
        local offset = group == 1 and characterOffset or 0
        local count = group == 1 and characterCount or accountCount
        for index = offset + 1, offset + count do
            local name, _, body = GetMacroInfo(index)
            if name then names[name:lower()] = true end
            local state = MacroButton(body)
            if state then
                byButton[state.key] = byButton[state.key] or index
                local desired = ButtonMacroBody(state.key)
                if NormalizeMacroBody(body) ~= desired then
                    EditMacro(index, nil, nil, desired)
                end
                local oldLabel = name and name:match("^[Ee][Tt][Bb] (.+)$")
                if oldLabel then
                    legacyNames[#legacyNames + 1] = {
                        index = index, oldName = name, newName = "TB " .. oldLabel, key = state.key,
                    }
                end
            end
        end
    end
    return byButton, names, legacyNames
end

local function ScanButtonMacros()
    local failed = {}
    while true do
        local byButton, names, legacyNames = ReadButtonMacros()
        local rename
        for _, legacy in ipairs(legacyNames) do
            legacy.attempt = legacy.oldName .. "\n" .. legacy.key
            if not failed[legacy.attempt] then
                rename = legacy
                break
            end
        end
        if not rename then return byButton, names end

        local name = rename.newName
        local copy = 1
        while names[name:lower()] do
            local suffix = " " .. copy
            name = rename.newName:sub(1, 16 - #suffix) .. suffix
            copy = copy + 1
        end
        local ok, newIndex = pcall(EditMacro, rename.index, name)
        if not ok or not newIndex or GetMacroInfo(newIndex) ~= name then
            failed[rename.attempt] = true
        end
        -- Renaming can reorder macro indices. Rescan before editing or picking up another macro.
    end
end

-- Draw on the slot's artwork layer, above its icon and below its border.
local function FitSlotArtwork(state, host)
    local icon, cooldown = state.icon, state.cooldown
    local hostIcon = host.icon or host.Icon
    icon:SetParent(host)
    icon:SetDrawLayer("ARTWORK", 1)
    icon:ClearAllPoints()
    icon:SetAllPoints(hostIcon or host)
    local mask
    if hostIcon and hostIcon.GetNumMaskTextures and hostIcon:GetNumMaskTextures() > 0 then
        mask = hostIcon:GetMaskTexture(1)
    end
    if mask then
        icon:SetTexCoord(hostIcon:GetTexCoord())
    else
        -- Crop the spell texture's own rim on square slots.
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if UsesTimedAura(state) then
        state.auraArtRevision = (state.auraArtRevision or 0) + 1
    end
    -- The host icon can extend beyond the slot. Size the timer independently
    -- and give its radial swipe the same silhouette as the host mask.
    cooldown:ClearAllPoints()
    local bounds = mask or host
    local inset = mask and 0 or 1
    cooldown:SetPoint("TOPLEFT", bounds, "TOPLEFT", inset, -inset)
    cooldown:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, inset)
    local countdownText = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if countdownText then
        countdownText:ClearAllPoints()
        countdownText:SetAllPoints(icon)
        countdownText:SetJustifyH("CENTER")
        countdownText:SetJustifyV("MIDDLE")
    end
    local swipeTexture = mask and mask:GetTexture() or ""
    if swipeTexture ~= state.swipeTexture then
        cooldown:SetSwipeTexture(swipeTexture)
        state.swipeTexture = swipeTexture
    end

    if mask == state.slotMask then return end
    for _, region in ipairs({icon, cooldown}) do
        if state.slotMask and region.RemoveMaskTexture then
            region:RemoveMaskTexture(state.slotMask)
        end
        if mask and region.AddMaskTexture then region:AddMaskTexture(mask) end
    end
    state.slotMask = mask
end

local function RefreshSlotArtwork(state, host)
    state.button:SetFrameStrata(host:GetFrameStrata())
    state.button:SetFrameLevel(host:GetFrameLevel() + 5)
    FitSlotArtwork(state, host)
    UpdateCountdownFont(state, host:GetSize())
end

local function Attach(state, host, action)
    local controller = hosts[host]
    if not controller then
        controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        hosts[host] = controller
        local prefix = host:GetName():match("^(%a[%w]-)%d+$")
        controller:SetAttribute("bartender", prefix == "BT4Button")
        if stockBars[prefix] and host:GetAttribute("useparent-actionpage") then
            SecureHandlerWrapScript(host:GetParent(), "OnAttributeChanged", controller, [[
                if name ~= "actionpage" or not control:GetAttribute("slot") then return end
                local overlay = control:GetFrameRef("overlay")
                if not overlay then return end
                if value == control:GetAttribute("page") then
                    overlay:Show()
                else
                    overlay:Hide()
                end
            ]])
        else
            SecureHandlerWrapScript(host, "OnAttributeChanged", controller, [[
                if name ~= "action" and name ~= "actionpage" and name ~= "type" then return end
                local overlay = control:GetFrameRef("overlay")
                if not overlay then return end
                local slot = control:GetAttribute("slot")
                if not slot then return end
                local matches = self:GetAttribute("action") == slot
                if control:GetAttribute("bartender") and self:GetAttribute("type") ~= "action" then
                    matches = false
                end
                if matches then overlay:Show() else overlay:Hide() end
            ]])
        end
    end
    SecureHandlerSetFrameRef(controller, "overlay", state.button)
    controller:SetAttribute("slot", action)
    controller:SetAttribute("page", host:GetParent():GetAttribute("actionpage"))
    state.host, state.action = host, action
    state.button:SetParent(host)
    -- Let the underlying Ellesmere slot receive its normal bar-hover events.
    local name = host:GetName()
    state.button:SetPropagateMouseMotion(name ~= nil and name:match("^EABButton%d+$") ~= nil)
    state.button:ClearAllPoints()
    state.button:SetAllPoints(host)
    RefreshSlotArtwork(state, host)
    state.button:Show()
    SuppressMacroIcon(state)
    -- Apply explicitly after the overlay is visible, even for unchanged keys.
    SyncSlotKeys(state, true)
end

local keyBound
local function BindingModeActive()
    return (QuickKeybindFrame and QuickKeybindFrame:IsShown()) or (keyBound and keyBound:IsShown())
end

local function Detach(state)
    hosts[state.host]:SetAttribute("slot", nil)
    state.button:Hide()
    RestoreMacroIcon(state)
    RestoreMacroLabel(state)
    ClearOverrideBindings(state.bindOwner)
    state.bindOwner:SetAttribute("keyCount", 0)
    state.host, state.action = nil, nil
end

local function Refresh()
    if InCombatLockdown() or EditModeActive() then return end
    ScanButtonMacros()
    for _, state in ipairs(states) do state.onBar = false end

    -- Let Quick Keybind Mode see and bind the actual action-bar button.
    if unlocked or BindingModeActive() then
        for _, state in ipairs(states) do
            if state.host then Detach(state) end
        end
        return
    end

    local candidates = {}
    for _, prefix in ipairs(barPrefixes) do
        local count = stockBars[prefix] and 12 or (prefix == "BT4Button" and 180 or 240)
        for index = 1, count do
            local host = _G[prefix .. index]
            local action = host and HostAction(host)
            if Readable(action) and action and action > 0 then
                local kind, id = GetActionInfo(action)
                local state = Readable(kind) and kind == "macro" and Readable(id) and id
                    and MacroButton(GetMacroBody(id))
                if state then
                    local slots = candidates[state]
                    if not slots then
                        slots = {}
                        candidates[state] = slots
                    end
                    local candidate = slots[action]
                    if not candidate or (host:IsVisible() and not candidate:IsVisible()) then
                        slots[action] = host
                    end
                end
            end
        end
    end

    -- Bars can expose the same action slot through several frames. Only
    -- distinct slots get independent overlays when they share a macro.
    local primarySlots = TotemButtonsDB.primarySlots
    local desired = {}
    for state, slots in pairs(candidates) do
        local primary = primarySlots[state.key]
        if not slots[primary] then
            primary = nil
            for action, host in pairs(slots) do
                local copyKey = state.key .. "-slot-" .. action
                if not TotemButtonsDB[copyKey] then
                    if not primary or (host:IsVisible() and not slots[primary]:IsVisible())
                        or (host:IsVisible() == slots[primary]:IsVisible() and action < primary) then
                        primary = action
                    end
                end
            end
            if primary then primarySlots[state.key] = primary end
        end
        state.onBar = true
        for action, host in pairs(slots) do
            local overlay = state
            if action ~= primary then
                local key = state.key .. "-slot-" .. action
                TotemButtonsDB[key] = TotemButtonsDB[key] or TotemButtonsDB[state.key]
                overlay = buttonsByKey[key] or RegisterCopy(state, key, state.label .. " (slot " .. action .. ")")
            end
            desired[overlay] = { host = host, action = action }
        end
    end

    -- Release all changed slots first, so moving or swapping overlays never
    -- restores a macro icon or clears bindings after its new owner attaches.
    for _, state in ipairs(states) do
        local slot = desired[state]
        if state.host and (not slot or state.host ~= slot.host or state.action ~= slot.action) then
            Detach(state)
        end
    end
    for state, slot in pairs(desired) do
        if state.host then
            hosts[slot.host]:SetAttribute("page", slot.host:GetParent():GetAttribute("actionpage"))
            RefreshSlotArtwork(state, slot.host)
            if not state.button:IsShown() then state.button:Show() end
            SuppressMacroIcon(state)
            SyncSlotKeys(state, false)
        else
            Attach(state, slot.host, slot.action)
        end
    end

    local known, knownIDs = KnownSpells()
    for _, state in ipairs(states) do
        RefreshChoices(state, known, knownIDs)
        UpdateTimer(state)
    end
end

local function PickUpButton(state, newCopy)
    if InCombatLockdown() then
        print("Totem Buttons: place or move buttons out of combat.")
        return
    end
    if GetCursorInfo() then return end
    local byButton, names = ScanButtonMacros()
    local key, name = state.key, "TB " .. state.label
    newCopy = newCopy or state.onBar
    if newCopy then
        local copy = 2
        repeat
            key = state.key .. "-" .. copy
            name = "TB " .. state.label .. " " .. copy
            copy = copy + 1
        until not byButton[key] and not names[name:lower()]
    end
    local index = byButton[key]
    if not index then
        if names[name:lower()] then
            print("Totem Buttons: rename the unrelated macro called " .. name .. " first.")
            return
        end
        local ok, created = pcall(CreateMacro, name, 134400, ButtonMacroBody(key), true)
        if ok and type(created) == "number" and created > 0
            and NormalizeMacroBody(GetMacroBody(created)) == ButtonMacroBody(key) then
            index = created
        else
            local updated = ScanButtonMacros()
            index = updated[key]
        end
        if not index then
            print("Totem Buttons: could not create " .. name .. ". Check for a free character macro slot.")
            return
        end
    end
    if newCopy then
        TotemButtonsDB[key] = TotemButtonsDB[state.key]
    end
    PickupMacro(index)
end

local stockBarAlpha
local stockBarMouse = {}
local function SuppressStockBarMouse(frame)
    if frame:IsMouseEnabled() then
        stockBarMouse[frame] = true
        frame:EnableMouse(false)
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        SuppressStockBarMouse(child)
    end
end

local function ApplyStockBarVisibility()
    if not isShaman or InCombatLockdown() or EditModeActive() then return end
    local bar = MultiCastActionBarFrame
    if not bar then return end
    -- Let Blizzard own the bar's visibility state and cooldown event handlers.
    if TotemButtonsDB.hideStockBar ~= false then
        if stockBarAlpha == nil then stockBarAlpha = bar:GetAlpha() end
        if bar:GetAlpha() ~= 0 then bar:SetAlpha(0) end
        SuppressStockBarMouse(bar)
    elseif stockBarAlpha ~= nil then
        bar:SetAlpha(stockBarAlpha)
        stockBarAlpha = nil
        for frame in pairs(stockBarMouse) do frame:EnableMouse(true) end
        wipe(stockBarMouse)
    end
end

local settingsCategory
local function BuildSettings()
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
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if classColor then classLabel:SetTextColor(classColor.r, classColor.g, classColor.b) end

    local version = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMRIGHT", -16, 12)
    version:SetText("v" .. C_AddOns.GetAddOnMetadata(addonName, "Version"))

    settingsCategory = Settings.RegisterCanvasLayoutCategory(canvas, "Totem Buttons")
    Settings.RegisterAddOnCategory(settingsCategory)
    if #elements == 0 then
        local message = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        message:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -10)
        message:SetText(className and "No features are available for " .. className .. " characters yet."
            or "No features are available for this class yet.")
        return
    end

    local panel = canvas

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

    local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    local function UpdateInstructions()
        local hoverText = TotemButtonsDB.shiftFlyouts
            and "Hold Shift and hover over the button to choose a spell."
            or "Hover over the button to choose a spell."
        instructions:SetText(
            "Drag an icon onto your action bar.\n"
            .. (isShaman and "Click or use the slot keybind to cast. Right-click a totem to dismiss it.\n" or "")
            .. "Pick the same icon again to add a separate button.\n"
            .. hoverText
        )
    end
    local shiftCheck = AddCheck("shiftFlyouts", "Hold Shift to show flyouts", instructions, -5, function()
        UpdateInstructions()
        if InCombatLockdown() or EditModeActive() then return end
        for _, state in ipairs(states) do ApplyFlyoutModifier(state) end
    end)
    instructions:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -8)
    instructions:SetJustifyH("LEFT")
    instructions:SetSpacing(2)

    local displayHeading = AddHeading("Global Options", shiftCheck, 0, -8)
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
    sizeLabel:SetText("Size:")
    local countdownSize = CreateFrame("Slider", "TotemButtonsCountdownSizeSlider", panel, "OptionsSliderTemplate")
    countdownSize:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    countdownSize:SetSize(130, 18)
    countdownSize:SetMinMaxValues(minCountdownPercent, maxCountdownPercent)
    countdownSize:SetValueStep(1)
    countdownSize:SetObeyStepOnDrag(true)
    countdownSize:SetValue(TotemButtonsDB.countdownPercent)
    countdownSize:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        TotemButtonsDB.countdownPercent = value
        for _, state in ipairs(states) do
            if state.host then UpdateCountdownFont(state, state.host:GetSize()) end
        end
        RefreshTimedAuras()
    end)

    local function AddButton(state, heading, column)
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(36, 36)
        button:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 8 + (column - 1) * 76, -7)
        PaintButton(button, C_Spell.GetSpellTexture(state.spells[1]))
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function()
            if GetCursorInfo() then return end
            PickUpButton(state, IsShiftKeyDown())
            WatchDragRelease()
        end)
        button:SetScript("OnClick", function() PickUpButton(state, IsShiftKeyDown()) end)

        if state.kind == "nova" then
            local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            note:SetPoint("LEFT", button, "RIGHT", 12, 0)
            note:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
            note:SetJustifyH("LEFT")
            note:SetText("Grays out when no active fire totem is detected.")
        elseif isShaman then
            local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOP", button, "BOTTOM", 0, -5)
            label:SetText(state.label)
        end
    end

    local UpdateRangeOptions
    if isShaman then
        local totemsHeading = AddHeading("Totems", countdownCheck, 0, -42)
        local rangeCheck = AddCheck("showRangeTint", "Tint active totems red when you are missing their buff",
            totemsHeading, -59, RefreshAppearance)
        local nonBuffCheck, nonBuffLabel = AddCheck("includeNonBuffTotems",
            "Include non-buff totems |cffff4040(does not work in instances)|r",
            rangeCheck, 0, RefreshAppearance, 24)
        UpdateRangeOptions = function()
            local enabled = TotemButtonsDB.showRangeTint ~= false
            nonBuffCheck:SetEnabled(enabled)
            nonBuffLabel:SetAlpha(enabled and 1 or 0.5)
        end
        rangeCheck:HookScript("OnClick", UpdateRangeOptions)
        local utilityHeading = AddHeading("Imbues and shields", nonBuffCheck, -24, -9)
        local novaHeading = AddHeading("Fire Nova", utilityHeading, 0, -65)

        local totemColumn, utilityColumn = 1, 1
        for _, state in ipairs(elements) do
            if state.slot then
                AddButton(state, totemsHeading, totemColumn)
                totemColumn = totemColumn + 1
            elseif state.kind == "nova" then
                AddButton(state, novaHeading, 1)
            else
                AddButton(state, utilityHeading, utilityColumn)
                utilityColumn = utilityColumn + 1
            end
        end
    else
        local heading = countdownCheck
        for index, state in ipairs(elements) do
            local kind = state.kind
            heading = AddHeading(state.label, heading, 0, index == 1 and -42 or -84)
            AddButton(state, heading, 1)
            local option = flyoutCastOptions[kind]
            if option then
                local label = kind == "aura" and "Cast aura on selection" or "Cast seal on selection"
                AddCheck(option, label, heading, -18, function()
                    if InCombatLockdown() or EditModeActive() then return end
                    for _, buttonState in ipairs(states) do
                        if buttonState.kind == kind then ApplyFlyoutCastOption(buttonState) end
                    end
                end, 76)
            end
        end
    end

    local function FitContent(self)
        instructions:SetWidth(math.max(1, self:GetWidth() - 32))
    end
    canvas:HookScript("OnSizeChanged", FitContent)
    canvas:SetScript("OnShow", function(self)
        FitContent(self)
        UpdateInstructions()
        for key, check in pairs(settingsChecks) do
            check:SetChecked(TotemButtonsDB[key] ~= false)
        end
        if UpdateRangeOptions then UpdateRangeOptions() end
    end)
end

local events = CreateFrame("Frame")
local keybindFrame
local function ScheduleRefresh()
    if events.pending then return end
    events.pending = true
    C_Timer.After(0, function()
        events.pending = nil
        ApplyStockBarVisibility()
        Refresh()
    end)
end

local function HookBartenderKeybind()
    if keyBound or not LibStub then return end
    local library = LibStub("LibKeyBound-1.0", true)
    if not library then return end
    keyBound = library
    keyBound.RegisterCallback(events, "LIBKEYBOUND_ENABLED", Refresh)
    keyBound.RegisterCallback(events, "LIBKEYBOUND_DISABLED", ScheduleRefresh)
end

local function HookQuickKeybind()
    local frame = QuickKeybindFrame
    if not frame or frame == keybindFrame then return end
    keybindFrame = frame
    frame:HookScript("OnShow", Refresh)
    frame:HookScript("OnHide", ScheduleRefresh)
end

local function ReconcileSlotKeys(force)
    if InCombatLockdown() or EditModeActive() or unlocked or BindingModeActive() then return end
    for _, state in ipairs(states) do
        if state.host and HostAction(state.host) == state.action then
            SyncSlotKeys(state, force)
        end
    end
end

local keysPending
local function ScheduleSlotKeys()
    if InCombatLockdown() or keysPending then return end
    keysPending = true
    C_Timer.After(0.1, function()
        keysPending = false
        ReconcileSlotKeys(false)
    end)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("UPDATE_MACROS")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
events:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
events:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
events:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
events:RegisterEvent("PLAYER_TOTEM_UPDATE")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("WEAPON_ENCHANT_CHANGED")
events:RegisterEvent("WEAPON_SLOT_CHANGED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
if isPaladin then
    events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    events:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
end
events:SetScript("OnEvent", function(_, event, slot, action, spellID)
    if #elements == 0 then
        if event == "PLAYER_LOGIN" then BuildSettings() end
        return
    end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if slot == addonName and TotemButtonsDB then
            local context = InCombatLockdown() and "combat" or "out of combat"
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then context = context .. ", Edit Mode" end
            if QuickKeybindFrame and QuickKeybindFrame:IsShown() then context = context .. ", Quick Keybind Mode" end
            local report = event .. ": " .. tostring(action) .. " (" .. context .. ")"
            if TotemButtonsDB.lastBlockedAction ~= report then
                print("Totem Buttons: " .. report)
            end
            TotemButtonsDB.lastBlockedAction = report
        end
        return
    end
    if event == "UPDATE_BINDINGS" then
        ScheduleSlotKeys()
        return
    elseif event == "ADDON_LOADED" then
        if slot == "Blizzard_QuickKeybind" then HookQuickKeybind() end
        if TotemButtonsDB and (slot == "Bartender4" or slot == "EllesmereUIActionBars") then
            if slot == "Bartender4" then HookBartenderKeybind() end
            ScheduleRefresh()
        end
        return
    end
    if event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
        if isShaman then C_Timer.After(0, RefreshTotemTalents) else ScheduleRefresh() end
        return
    end
    if event == "PLAYER_LOGIN" then
        if isShaman then RefreshTotemTalents() end
        HookQuickKeybind()
        HookBartenderKeybind()
        TotemButtonsDB = TotemButtonsDB or {}
        TotemButtonsDB.grayFireNova = nil
        TotemButtonsDB.primarySlots = TotemButtonsDB.primarySlots or {}
        TotemButtonsDB.includeNonBuffTotems = TotemButtonsDB.includeNonBuffTotems == true
        TotemButtonsDB.shiftFlyouts = TotemButtonsDB.shiftFlyouts == true
        local countdownPercent = tonumber(TotemButtonsDB.countdownPercent)
        local previousSize = tonumber(TotemButtonsDB.countdownSize)
        if not countdownPercent then
            -- Convert the old fixed size using a 36-unit reference button.
            countdownPercent = previousSize and previousSize * 100 / 36 or defaultCountdownPercent
        end
        TotemButtonsDB.countdownPercent = math.max(minCountdownPercent,
            math.min(maxCountdownPercent, math.floor(countdownPercent + 0.5)))
        TotemButtonsDB.countdownSize = nil
        for summonID, auraID in pairs(totemAuraSpells) do
            local name = C_Spell.GetSpellName(summonID)
            if name then totemAuraIDsByName[name] = auraID end
        end
        for index, state in ipairs(elements) do
            if not state.kind then state.slot = index end
            elementsByKey[state.key] = state
            RegisterButton(state)
        end
        BuildSettings()
        EventRegistry:RegisterCallback("EditMode.Exit", ScheduleRefresh, events)
        C_Timer.NewTicker(0.25, function()
            if isShaman then UpdateTotemRanges() end
            RefreshTimedAuras()
        end)
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if isShaman then RefreshTotemTalents() end
        -- The action bars can finish loading and rebuild their routes after
        -- PLAYER_ENTERING_WORLD, including when the UI is reloaded.
        C_Timer.After(0.25, function() ReconcileSlotKeys(true) end)
        C_Timer.After(1, function() ReconcileSlotKeys(false) end)
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        NotePlayerCast(spellID)
    elseif event == "PLAYER_REGEN_DISABLED" then
        for _, state in ipairs(states) do
            if state.host then UpdateTimer(state) end
        end
    elseif event == "UNIT_POWER_UPDATE" then
        if not Readable(action) or action ~= "MANA" or EditModeActive() then return end
        local buffReads = {}
        for _, state in ipairs(states) do
            if state.host then
                local spell = state.button:GetAttribute("spell1")
                if UpdateLowMana(state, spell) then
                    local name = spell and C_Spell.GetSpellName(spell)
                    PaintButtonTint(state, ActiveEffect(state, name), buffReads)
                end
            end
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        for _, state in ipairs(states) do
            if state.host and (state.slot or state.kind == "nova") then PaintSelection(state) end
        end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        local slotKnown = Readable(slot) and slot ~= nil
        -- Let a successful cast in the same frame identify a summon or relocation.
        C_Timer.After(0, function()
            for _, state in ipairs(states) do
                if state.slot and (not slotKnown or state.slot == slot) then
                    UpdateTotem(state, slotKnown)
                elseif state.kind == "nova" and (not slotKnown or slot == 1) then
                    PaintSelection(state)
                end
            end
        end)
    elseif event == "WEAPON_ENCHANT_CHANGED" or event == "WEAPON_SLOT_CHANGED"
        or event == "UNIT_INVENTORY_CHANGED" or (event == "PLAYER_EQUIPMENT_CHANGED" and slot == mainHandSlot) then
        if event == "PLAYER_EQUIPMENT_CHANGED" then recentImbueCast = nil end
        for _, state in ipairs(states) do
            if state.kind == "imbue" then
                if event == "PLAYER_EQUIPMENT_CHANGED" then state.effect = nil end
                UpdateImbue(state)
            end
        end
    elseif event == "UNIT_AURA" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        for _, state in ipairs(states) do
            if UsesTimedAura(state) then
                UpdateTimedAura(state, action)
            elseif state.kind == "aura" then
                PaintSelection(state)
            end
        end
        if event == "UPDATE_SHAPESHIFT_FORMS" then ScheduleRefresh() end
    else
        ScheduleRefresh()
    end
end)

SLASH_TOTEMBUTTONS1 = "/totembuttons"
SlashCmdList.TOTEMBUTTONS = function(message)
    if #elements == 0 then
        if settingsCategory then Settings.OpenToCategory(settingsCategory:GetID()) end
        return
    end
    local key = message:lower():match("^%s*(%a+)%s*$")
    if key == "blocked" then
        print("Totem Buttons: " .. (TotemButtonsDB.lastBlockedAction
            or "no blocked action recorded."))
        return
    end
    if key == "shieldstatus" then
        for _, state in ipairs(states) do
            if UsesTimedAura(state) and state.host then
                UpdateTimedAura(state)
                local selected = state.button:GetAttribute("spell1")
                local name = selected and C_Spell.GetSpellName(selected)
                if name then
                    local restriction = ReadShieldAPI(C_Secrets and C_Secrets.ShouldSpellAuraBeSecret, selected)
                    local privacy = Readable(restriction) and restriction == true and "restricted" or "not reported restricted"
                    local instance = state.trackedShieldInstance and "known instance" or "no known instance"
                    print("Totem Buttons: " .. name .. " (" .. (state.shieldSource or "buff unavailable")
                        .. ", " .. privacy .. ", " .. instance .. ")")
                end
            end
        end
        return
    end
    if key == "novastatus" and isShaman then
        local active, source = FireTotemStatus()
        print("Totem Buttons Fire Nova: " .. (active and "colored" or "gray") .. " (" .. source .. ")")
        return
    end
    if key == "range" then
        UpdateTotemRanges()
        for _, state in ipairs(states) do
            if state.host and state.slot then
                local effect = state.effect
                local status = "no identified active totem"
                if effect and ActiveEffect(state, effect.name) then
                    local buff = ReadTotemBuff(effect.name)
                    if buff ~= nil then
                        status = buff and "buff active on you" or "buff missing on you"
                    elseif totemAuraIDsByName[effect.name] then
                        status = "buff status unavailable"
                    elseif TotemButtonsDB.showRangeTint == false or not TotemButtonsDB.includeNonBuffTotems then
                        status = "non-buff range check disabled"
                    elseif IsInInstance() then
                        status = "non-buff range unavailable in instances"
                    elseif not effect.origin then
                        status = "summon position unavailable"
                    elseif not effect.rangeKnown then
                        status = "current position unavailable or on a different map"
                    else
                        status = effect.outOfRange and "out of range" or "in range"
                    end
                    status = effect.name .. " (" .. status .. ")"
                end
                print(state.label .. ": " .. status)
            end
        end
        return
    end
    if key == "keys" then
        for _, state in ipairs(states) do
            if state.host then
                local keys, command = HostKeys(state.host)
                local routes = {}
                for _, binding in ipairs(keys) do
                    routes[#routes + 1] = binding .. " → " .. (GetBindingAction(binding, true) or "")
                end
                local spell = state.keyButton:GetAttribute("spell")
                print(state.label .. ": " .. (command or "no slot command")
                    .. " | " .. (#routes > 0 and table.concat(routes, " | ") or "unbound")
                    .. " | spell " .. tostring(spell) .. " | key events " .. (state.keyClicks or 0)
                    .. (state.lastKeyEdge and (" (" .. state.lastKeyEdge .. ")") or ""))
            end
        end
        return
    end
    if InCombatLockdown() then print("Totem Buttons: set up out of combat."); return end
    if key == "rebind" then
        ReconcileSlotKeys(true)
        print("Totem Buttons: refreshed action-bar key routes.")
        return
    end
    if key == "unlock" or key == "lock" then
        unlocked = key == "unlock"
        Refresh()
        print(unlocked and "Totem buttons unlocked. Move or remove their macros, then type /totembuttons lock."
            or "Totem buttons locked.")
        return
    end
    local element = elementsByKey[key]
    if element then
        PickUpButton(element)
        return
    end
    if settingsCategory then Settings.OpenToCategory(settingsCategory:GetID()) end
end
