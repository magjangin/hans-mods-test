-- HANS forgets the window mode chosen in the options menu.
--
-- The options menu (AutoSettings plugin) saves the choice to Settings.ini as r.setres=<W>x<H><mode>
-- (w = windowed, wf = borderless fullscreen, f = fullscreen). But every time the main menu opens,
-- WBP_MainMenuUI builds "<viewport W>x<viewport H>" .. "f" and applies it as r.setres through
-- AutoSettings.SettingsManager:ApplySettingStatic, forcing fullscreen regardless of the saved value.
--
-- This mod recognises that forced call and swaps its value for the saved one.

print("[WindowModeFix] Loaded\n")

local SettingsIni = os.getenv("LOCALAPPDATA") .. "\\Hans\\Saved\\Config\\Windows\\Settings.ini"

-- The main menu converts the viewport size with Conv_Vector2dToString right before the forced
-- r.setres call; only an ApplySettingStatic that follows it closely is treated as the forced one.
local MarkerWindowSec = 0.5
local LastVectorToStringAt = -math.huge

---@return string|nil saved r.setres value, e.g. "1280x720w"
local function ReadSavedSetRes()
    local file = io.open(SettingsIni, "r")
    if not file then return nil end
    local value = nil
    for line in file:lines() do
        local v = line:lower():match("^%s*r%.setres%s*=%s*(%d+x%d+[wf]*)%s*$")
        if v then value = v end
    end
    file:close()
    return value
end

RegisterHook("/Script/Engine.KismetStringLibrary:Conv_Vector2dToString", function()
    LastVectorToStringAt = os.clock()
end)

RegisterHook("/Script/AutoSettings.SettingsManager:ApplySettingStatic", function(_, settingParam)
    local setting = settingParam:get()
    if setting.Key:ToString():lower() ~= "r.setres" then return end

    local value = setting.Value:ToString()
    local isForced = value:match("^%d+x%d+f$") and (os.clock() - LastVectorToStringAt) < MarkerWindowSec
    LastVectorToStringAt = -math.huge
    if not isForced then return end

    local saved = ReadSavedSetRes()
    if not saved or saved == value then return end

    setting.Value = saved
    print(string.format("[WindowModeFix] Main menu forced r.setres=%s, applying saved %s instead\n", value, setting.Value:ToString()))
end)
