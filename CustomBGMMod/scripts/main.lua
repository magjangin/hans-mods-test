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

-- -----------------------------------------------------------------------------
-- [DEBUG] Audio Component Inspector & Dumper
-- -----------------------------------------------------------------------------
local function DumpAudioState()
    print("\n==================== [AUDIO DEBUG DUMP] ====================")
    local allAudioComps = FindAllOf("AudioComponent") or {}
    print(string.format("[AudioDebug] Total AudioComponent instances found: %d", #allAudioComps))

    local count = 0
    for i, comp in ipairs(allAudioComps) do
        if comp:IsValid() then
            local isPlaying = false
            pcall(function() isPlaying = comp:IsPlaying() end)

            local soundName = "None"
            pcall(function()
                if comp.Sound and comp.Sound:IsValid() then
                    soundName = comp.Sound:GetFullName()
                end
            end)

            local ownerName = "None"
            pcall(function()
                local owner = comp:GetOwner()
                if owner and owner:IsValid() then
                    ownerName = owner:GetFullName()
                end
            end)

            local compName = comp:GetFullName()
            local vol = comp.VolumeMultiplier or -1.0

            if isPlaying or vol > 0.0 or soundName:lower():match("music") or soundName:lower():match("bgm") then
                count = count + 1
                print(string.format("[AudioDebug] #%d [Playing=%s, Vol=%.2f]", count, tostring(isPlaying), vol))
                print(string.format("             Component : %s", compName))
                print(string.format("             Owner     : %s", ownerName))
                print(string.format("             Sound     : %s", soundName))
            end
        end
    end

    -- Check GameInstance music volume state
    local gi = FindFirstOf("GI_Hans_C")
    if gi and gi:IsValid() then
        print(string.format("[AudioDebug] GameInstance (GI_Hans_C) found: %s", gi:GetFullName()))
    else
        print("[AudioDebug] GameInstance (GI_Hans_C) NOT found yet.")
    end

    print("============================================================\n")
end

-- 5. Mute original game BGM components while custom music is active
local HasAppliedGIMusicMute = false
local MutedComponentMap = {}

local function MuteGameAudio()
    if not HasCustomMusic then return end

    -- 1) GameInstance MusicVolumeChanged(0.0)
    local gi = FindFirstOf("GI_Hans_C")
    if gi and gi:IsValid() then
        pcall(function()
            gi:MusicVolumeChanged(0.0)
            if not HasAppliedGIMusicMute then
                print("[CustomBGMMod] GI_Hans_C:MusicVolumeChanged(0.0) called successfully.")
                HasAppliedGIMusicMute = true
            end
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
            if not MutedComponentMap["BP_Hans_BGM"] then
                print("[CustomBGMMod] Player pawn BackgroundMusic muted & stopped.")
                MutedComponentMap["BP_Hans_BGM"] = true
            end
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
            if not MutedComponentMap["Level_Music"] then
                print("[CustomBGMMod] Level Gameplay_MainElizarV Music muted & stopped.")
                MutedComponentMap["Level_Music"] = true
            end
        end
    end

    -- 4) Scan ALL active AudioComponents matching music/BGM patterns
    local allComps = FindAllOf("AudioComponent") or {}
    for _, comp in ipairs(allComps) do
        if comp:IsValid() then
            local compFullName = comp:GetFullName():lower()
            local soundFullName = ""
            pcall(function()
                if comp.Sound and comp.Sound:IsValid() then
                    soundFullName = comp.Sound:GetFullName():lower()
                end
            end)

            local isMusicComp = compFullName:match("music") or compFullName:match("bgm")
                or soundFullName:match("music") or soundFullName:match("bgm")
                or soundFullName:match("soundtrack") or soundFullName:match("theme")

            if isMusicComp and comp.VolumeMultiplier ~= 0.0 then
                pcall(function()
                    comp:SetVolumeMultiplier(0.0)
                    comp:Stop()
                end)
                if not MutedComponentMap[comp:GetFullName()] then
                    print(string.format("[CustomBGMMod] Auto-muted Music AudioComponent: %s (Sound: %s)", comp:GetFullName(), soundFullName))
                    MutedComponentMap[comp:GetFullName()] = true
                end
            end
        end
    end
end

-- Guardian loop: maintain muting and recheck tracks
LoopAsync(250, function()
    ExecuteInGameThread(function()
        if not HasCustomMusic then
            HasCustomMusic = CheckHasCustomMusic()
            if HasCustomMusic then
                print(string.format("[CustomBGMMod] [Detected] New custom music added to '%s'!", HWA_DIR))
            end
        end

        MuteGameAudio()
    end)
    return false
end)

-- 6. In-Game Keybinds for Custom BGM Control & Debug
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

-- [F12] Audio Diagnostics Dump Key
RegisterKeyBind(Key.F12, function()
    ExecuteInGameThread(DumpAudioState)
end)

print("[CustomBGMMod] Loaded! 단축키:")
print("  - [F10]      : BGM 일시정지 / 재생 토글")
print("  - [F11]      : 다음 곡 재생 (파일이 여러 개일 때)")
print("  - [PageUp]   : 볼륨 10% 증가")
print("  - [PageDown] : 볼륨 10% 감소")
print("  - [F12]      : ★ [디버그] 현재 재생 중인 모든 오디오 컴포넌트 실시간 덤프")
print("  - 커스텀 음악 경로: " .. HWA_DIR)
