local function read(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local folder = "TotemButtons/"
local toc = read(folder .. "TotemButtons.toc")
local version = assert(toc:match("## Version: ([%d.]+)"))
assert(read("CHANGELOG.md"):find("## " .. version .. "\n", 1, true), "Missing release notes")
local sources = {}
local main
for filename in toc:gmatch("[^\r\n]+") do
    if filename:match("^%w+%.lua$") then
        assert(not main, "Entry point must load after its modules")
        local path = folder .. filename
        sources[#sources + 1] = { path = path, chunk = assert(loadfile(path)) }
        local source = read(path)
        -- Texture paths may also use long strings. Only compile the remaining code snippets.
        source = source:gsub("SetTexture%(%[%[.-%]%]%)", "")
        for snippet in source:gmatch("%[%[(.-)%]%]") do
            assert(loadstring(snippet, path .. " (secure snippet)"))
        end
        if filename == "TotemButtons.lua" then main = source end
    end
end
assert(main and #sources == 5, "Incomplete addon load list")

local addon = {}
for index = 1, #sources - 1 do sources[index].chunk("TotemButtons", addon) end
assert(addon.BuildSettings and addon.CreateCrossbar and addon.CreateStormstrikeAlert)
assert(addon.WithFlyoutModifier("ALT-1", "CTRL") == "ALT-CTRL-1")
assert(addon.WithFlyoutModifier("CTRL-1", "CTRL") == nil)
assert(addon.WithFlyoutModifier("PAD1", "SHIFT") == nil)
assert(addon.WithFlyoutModifier("-", "SHIFT") == "SHIFT--")
assert(addon.CanBindFlyout("NONE", "", "ours"))
assert(addon.CanBindFlyout("", "ours", "ours"))
assert(not addon.CanBindFlyout("ACTIONBUTTON1", "", "ours"))
assert(not addon.CanBindFlyout("", "another addon", "ours"))

local old = { shiftFlyouts = true }
addon.MigrateHoverModifier(old)
assert(old.requireHoverModifier == true and old.shiftFlyouts == nil)
local explicit = { requireHoverModifier = false, shiftFlyouts = true }
addon.MigrateHoverModifier(explicit)
assert(explicit.requireHoverModifier == false and explicit.shiftFlyouts == nil)

local selectSource = assert(main:match('SetAttribute%("selectSpell", %[%[(.-)%]%]'))
local function fakeFrame()
    return {
        GetAttribute = function(self, key) return self[key] end,
        SetAttribute = function(self, key, value) self[key] = value end,
        GetFrameRef = function(self, key) return self[key] end,
    }
end
local flyout = fakeFrame()
flyout.button, flyout.keyButton = fakeFrame(), fakeFrame()
local selectSpell = assert(loadstring(selectSource))
setfenv(selectSpell, { self = flyout })
selectSpell(3599)
assert(flyout.button.spell1 == 3599 and flyout.keyButton.spell == 3599)
selectSpell(nil)
assert(flyout.button.spell1 == 3599 and flyout.keyButton.spell == 3599)
flyout.isJudgementPicker = true
selectSpell(20154)
assert(flyout.selectedSeal == 20154 and flyout.button.spell1 == 3599)
print("Totem Buttons checks passed")
