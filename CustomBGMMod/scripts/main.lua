local UEHelpers = require("UEHelpers")

print("==================================================")
print("[CustomBGMMod] Hans Custom BGM Injector Loading...")
print("==================================================")

local HWA_DIR = [[H:\steam\steamapps\common\HANS\hwa]]

-- 1. Ensure target directory exists on game launch
pcall(function()
    os.execute(string.format('if not exist "%s" mkdir "%s"', HWA_DIR, HWA_DIR))
end)

-- 2. Locate mod directory and bgm_player.py
local ModDir = debug.getinfo(1, "S").source:match("^@(.+)[\\/][^\\/]+[\\/][^\\/]+$")
local PlayerScript = ModDir and (ModDir .. "\\bgm_player.py")
local CmdFile = ModDir and (ModDir .. "\\cmd.txt")

local function SendPlayerCommand(cmd)
    if not CmdFile then return end
    pcall(function()
        local f = io.open(CmdFile, "w")
        if f then
            f:write(cmd)
            f:close()
        end
    end)
end

-- 3. Launch background player script
local HasLaunchedPlayer = false
local function LaunchBGMPlayer()
    if HasLaunchedPlayer or not PlayerScript then return end
    HasLaunchedPlayer = true
    pcall(function()
        os.execute('start /b "" pythonw "' .. PlayerScript .. '"')
        print(string.format("[CustomBGMMod] BGM Player process launched. Monitoring: %s", HWA_DIR))
    end)
end

LaunchBGMPlayer()

-- 4. Check if custom music files exist in HWA_DIR
local function CheckHasCustomMusic()
    local pipe = io.popen(string.format('dir /b /a-d "%s\\*.ogg" "%s\\*.mp3" "%s\\*.wav" "%s\\*.flac" 2>nul', HWA_DIR, HWA_DIR, HWA_DIR, HWA_DIR))
    if not pipe then return false end
    local output = pipe:read("*a")
    pipe:close()
    return output and #output:gsub("%s+", "") > 0
end

local HasCustomMusic = CheckHasCustomMusic()
if HasCustomMusic then
    print(string.format("[CustomBGMMod] [Active] Custom music found in '%s'! Original BGM will be muted.", HWA_DIR))
else
    print(string.format("[CustomBGMMod] [Notice] No custom music (.ogg/.mp3) in '%s'. Original BGM retained.", HWA_DIR))
    print("[CustomBGMMod] Put any .ogg or .mp3 in that folder to replace in-game music!")
end

-- 5. Mute original game BGM components while custom music is active
local HasMutedPlayerBGM = false
local HasMutedLevelBGM = false

LoopAsync(500, function()
    ExecuteInGameThread(function()
        -- Periodically re-check if user added files
        if not HasCustomMusic then
            HasCustomMusic = CheckHasCustomMusic()
            if HasCustomMusic then
                print(string.format("[CustomBGMMod] [Detected] New custom music added to '%s'!", HWA_DIR))
            end
        end

        if not HasCustomMusic then return end

        -- 1) Player Pawn BackgroundMusic
        local player = UEHelpers.GetPlayer()
        if player:IsValid() and player.BackgroundMusic and player.BackgroundMusic:IsValid() then
            if player.BackgroundMusic.VolumeMultiplier ~= 0.0 then
                pcall(function()
                    player.BackgroundMusic:SetVolumeMultiplier(0.0)
                    player.BackgroundMusic:Stop()
                end)
                if not HasMutedPlayerBGM then
                    print("[CustomBGMMod] Player BackgroundMusic muted & stopped.")
                    HasMutedPlayerBGM = true
                end
            end
        end

        -- 2) Level Script Actor Music
        local level = FindFirstOf("Gameplay_MainElizarV_C")
        if level and level:IsValid() and level.Music and level.Music:IsValid() then
            if level.Music.VolumeMultiplier ~= 0.0 then
                pcall(function()
                    level.Music:SetVolumeMultiplier(0.0)
                    level.Music:Stop()
                end)
                if not HasMutedLevelBGM then
                    print("[CustomBGMMod] Level Gameplay_MainElizarV Music muted & stopped.")
                    HasMutedLevelBGM = true
                end
            end
        end
    end)
    return false
end)

-- 6. In-Game Keybinds for Custom BGM Control
RegisterKeyBind(Key.F10, function()
    SendPlayerCommand("toggle")
    print("[CustomBGMMod] Key [F10]: BGM Play/Pause toggled.")
end)

RegisterKeyBind(Key.F11, function()
    SendPlayerCommand("next")
    print("[CustomBGMMod] Key [F11]: Skip to next track.")
end)

RegisterKeyBind(Key.PAGE_UP, function()
    SendPlayerCommand("vol_up")
    print("[CustomBGMMod] Key [PageUp]: Volume +10%.")
end)

RegisterKeyBind(Key.PAGE_DOWN, function()
    SendPlayerCommand("vol_down")
    print("[CustomBGMMod] Key [PageDown]: Volume -10%.")
end)

print("[CustomBGMMod] Loaded! 단축키:")
print("  - [F10]      : BGM 일시정지 / 재생 토글")
print("  - [F11]      : 다음 곡 재생 (파일이 여러 개일 때)")
print("  - [PageUp]   : 볼륨 10% 증가")
print("  - [PageDown] : 볼륨 10% 감소")
print("  - 커스텀 음악 경로: " .. HWA_DIR)
