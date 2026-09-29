local UEHelpers = require("UEHelpers")

print("==================================================")
print("[CustomBGMMod] Hans Custom BGM Injector Loading...")
print("==================================================")

local HWA_DIR = [[H:\steam\steamapps\common\HANS\hwa]]
local SETTINGS_INI = os.getenv("LOCALAPPDATA") .. "\\Hans\\Saved\\Config\\Windows\\Settings.ini"

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

-- 3. Check if custom music files exist in HWA_DIR
local function CheckHasCustomMusic()
    local pipe = io.popen(string.format('dir /b /a-d "%s\\*.ogg" "%s\\*.mp3" "%s\\*.wav" "%s\\*.flac" 2>nul', HWA_DIR, HWA_DIR, HWA_DIR, HWA_DIR))
    if not pipe then return false end
    local output = pipe:read("*a")
    pipe:close()
    return output and #output:gsub("%s+", "") > 0
end

local HasCustomMusic = CheckHasCustomMusic()

-- 4. Pre-patch Settings.ini (GameAudio.MusicVolume=0) so game loads menu with 0 music volume
local function PatchSettingsIniMusicVolumeZero()
    if not HasCustomMusic then return end
    local file = io.open(SETTINGS_INI, "r")
    if not file then return end
    local content = file:read("*a")
    file:close()

    local updated, count = content:gsub("GameAudio%.MusicVolume%s*=%s*[%d%.]+", "GameAudio.MusicVolume=0")
    if count > 0 and updated ~= content then
        local outFile = io.open(SETTINGS_INI, "w")
        if outFile then
            outFile:write(updated)
            outFile:close()
            print("[CustomBGMMod] Settings.ini GameAudio.MusicVolume -> 0 (선제 음소거 패치 완료)")
        end
    end
end

PatchSettingsIniMusicVolumeZero()

-- 5. Launch background player script
local HasLaunchedPlayer = false
local function LaunchBGMPlayer()
    if HasLaunchedPlayer or not PlayerScript or not HasCustomMusic then return end
    HasLaunchedPlayer = true
    pcall(function()
        os.execute('start /b "" pythonw "' .. PlayerScript .. '"')
        print(string.format("[CustomBGMMod] BGM Player process launched. Monitoring: %s", HWA_DIR))
    end)
end

LaunchBGMPlayer()

if HasCustomMusic then
    print(string.format("[CustomBGMMod] [Active] Custom music found in '%s'! Game music will be muted.", HWA_DIR))
else
    print(string.format("[CustomBGMMod] [Notice] No custom music in '%s'. Original BGM retained.", HWA_DIR))
end

-- 6. Hook AutoSettings to force GameAudio.MusicVolume to "0" at runtime
pcall(function()
    RegisterHook("/Script/AutoSettings.SettingsManager:ApplySettingStatic", function(_, settingParam)
        if not HasCustomMusic then return end
        local setting = settingParam:get()
        local key = setting.Key:ToString():lower()
        if key == "gameaudio.musicvolume" then
            if setting.Value:ToString() ~= "0" then
                setting.Value = "0"
                print("[CustomBGMMod] AutoSettings GameAudio.MusicVolume forced to 0.")
            end
        end
    end)
end)

-- 7. Smart Deduplicated Audio Monitor (키 입력 없이 자동 디버그, 스팸 0%)
local ReportedAudioMap = {}
local HasReportedSummary = false

local function InspectAndMuteAudio()
    if not HasCustomMusic then return end

    -- 1) GameInstance MusicVolumeChanged(0.0)
    local gi = FindFirstOf("GI_Hans_C")
    if gi and gi:IsValid() then
        pcall(function()
            gi:MusicVolumeChanged(0.0)
        end)
    end

    -- 2) Target Known Actors: BP_Hans.BackgroundMusic
    local player = UEHelpers.GetPlayer()
    if player:IsValid() and player.BackgroundMusic and player.BackgroundMusic:IsValid() then
        if player.BackgroundMusic.VolumeMultiplier ~= 0.0 then
            pcall(function()
                player.BackgroundMusic:SetVolumeMultiplier(0.0)
                player.BackgroundMusic:Stop()
            end)
        end
    end

    -- 3) Target Known Actors: Gameplay_MainElizarV.Music
    local level = FindFirstOf("Gameplay_MainElizarV_C")
    if level and level:IsValid() and level.Music and level.Music:IsValid() then
        if level.Music.VolumeMultiplier ~= 0.0 then
            pcall(function()
                level.Music:SetVolumeMultiplier(0.0)
                level.Music:Stop()
            end)
        end
    end

    -- 4) Scan all active AudioComponents and log new ones automatically (스팸 방지)
    local allComps = FindAllOf("AudioComponent") or {}
    for _, comp in ipairs(allComps) do
        if comp:IsValid() then
            local compKey = comp:GetFullName()
            local soundFullName = ""
            pcall(function()
                if comp.Sound and comp.Sound:IsValid() then
                    soundFullName = comp.Sound:GetFullName()
                end
            end)

            local compLower = compKey:lower()
            local soundLower = soundFullName:lower()

            local isMusic = compLower:match("music") or compLower:match("bgm")
                or soundLower:match("music") or soundLower:match("bgm")
                or soundLower:match("soundtrack") or soundLower:match("theme")

            if isMusic then
                -- 뮤트 적용
                if comp.VolumeMultiplier ~= 0.0 then
                    pcall(function()
                        comp:SetVolumeMultiplier(0.0)
                        comp:Stop()
                    end)
                end

                -- 스팸 없이 1회만 자동 디버그 출력
                if not ReportedAudioMap[compKey] then
                    ReportedAudioMap[compKey] = true
                    print(string.format("[CustomBGMMod] [AutoDebug] 게임 음악 뮤트 완료: %s | Sound: %s", compKey, soundFullName))
                end
            else
                -- SFX 등 일반 사운드 컴포넌트는 최초 1회만 조용히 디버그 기록
                if not ReportedAudioMap[compKey] then
                    ReportedAudioMap[compKey] = true
                    local vol = comp.VolumeMultiplier or 1.0
                    local isPlaying = false
                    pcall(function() isPlaying = comp:IsPlaying() end)
                    if isPlaying then
                        print(string.format("[CustomBGMMod] [AutoDebug] 효과음(SFX) 재생 감지: %s (Vol=%.2f)", soundFullName ~= "" and soundFullName or compKey, vol))
                    end
                end
            end
        end
    end
end

-- Guardian loop: 250ms periodic check
LoopAsync(250, function()
    ExecuteInGameThread(function()
        if not HasCustomMusic then
            HasCustomMusic = CheckHasCustomMusic()
            if HasCustomMusic then
                print(string.format("[CustomBGMMod] [Detected] New custom music added to '%s'!", HWA_DIR))
                LaunchBGMPlayer()
            end
        end

        InspectAndMuteAudio()
    end)
    return false
end)

-- 8. In-Game Keybinds for Custom BGM Control (F12 제거 완료)
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
print("  - [자동 디버그]: 키 입력 없이 새 오디오 감지 시 1회만 자동 요약 출력")
print("  - 커스텀 음악 경로: " .. HWA_DIR)
