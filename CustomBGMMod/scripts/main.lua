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

-- 3. Check if custom music files exist in HWA_DIR
local function CheckHasCustomMusic()
    local pipe = io.popen(string.format('dir /b /a-d "%s\\*.ogg" "%s\\*.mp3" "%s\\*.wav" "%s\\*.flac" 2>nul', HWA_DIR, HWA_DIR, HWA_DIR, HWA_DIR))
    if not pipe then return false end
    local output = pipe:read("*a")
    pipe:close()
    return output and #output:gsub("%s+", "") > 0
end

local HasCustomMusic = CheckHasCustomMusic()

-- 4. Launch background player script
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
    print(string.format("[CustomBGMMod] [Active] 커스텀 음악 감지됨: '%s' (게임 순정 BGM 뮤트 활성화)", HWA_DIR))
else
    print(string.format("[CustomBGMMod] [Notice] '%s' 폴더에 음악이 없습니다. 순정 BGM 유지.", HWA_DIR))
end

-- 5. Audio State Management
local MuteAmbientSFX = false -- [End] 키로 송풍기/바람 환경음도 함께 음소거 가능
local KnownMusicComps = {}
local LastSummaryTime = 0
local LastPlayingSignature = ""

local function ProcessAudio()
    local allComps = FindAllOf("AudioComponent") or {}
    local activeSFX = {}
    local uflemeciCount = 0
    local musicMutedCount = 0

    -- 1) Target GameInstance if available
    local gi = FindFirstOf("GI_Hans_C")
    if gi and gi:IsValid() and HasCustomMusic then
        pcall(function() gi:MusicVolumeChanged(0.0) end)
    end

    -- 2) Scan all AudioComponents
    for _, comp in ipairs(allComps) do
        if comp:IsValid() then
            local compName = comp:GetFullName()
            local soundPath = ""
            pcall(function()
                if comp.Sound and comp.Sound:IsValid() then
                    soundPath = comp.Sound:GetFullName()
                end
            end)

            local compLower = compName:lower()
            local soundLower = soundPath:lower()

            local isMusic = compLower:match("music") or compLower:match("bgm")
                or soundLower:match("music") or soundLower:match("bgm")
                or soundLower:match("soundtrack") or soundLower:match("theme")

            local isAmbient = soundLower:match("uflemeci") or soundLower:match("wind")

            if isMusic and HasCustomMusic then
                -- BGM 음소거 유지
                if comp.VolumeMultiplier ~= 0.0 then
                    pcall(function()
                        comp:SetVolumeMultiplier(0.0)
                        comp:Stop()
                    end)
                end
                musicMutedCount = musicMutedCount + 1
                if not KnownMusicComps[compName] then
                    KnownMusicComps[compName] = true
                    print(string.format("[CustomBGMMod] [BGM 차단] 순정 음악 뮤트 성공: %s (Sound: %s)", compName, soundPath))
                end
            elseif isAmbient then
                if MuteAmbientSFX then
                    pcall(function()
                        comp:SetVolumeMultiplier(0.0)
                        comp:Stop()
                    end)
                end
                local isPlaying = false
                pcall(function() isPlaying = comp:IsPlaying() end)
                if isPlaying then
                    if soundLower:match("uflemeci") then
                        uflemeciCount = uflemeciCount + 1
                    else
                        activeSFX[#activeSFX + 1] = soundPath
                    end
                end
            else
                local isPlaying = false
                pcall(function() isPlaying = comp:IsPlaying() end)
                if isPlaying then
                    activeSFX[#activeSFX + 1] = soundPath
                end
            end
        end
    end

    -- 3) 스팸 없는 실시간 요약 로깅 (상태가 변했거나 10초 경과 시 출력)
    local now = os.clock()
    local signature = string.format("music:%d|uflemeci:%d|sfx:%d|muteAmb:%s", musicMutedCount, uflemeciCount, #activeSFX, tostring(MuteAmbientSFX))
    if signature ~= LastPlayingSignature or (now - LastSummaryTime > 15.0) then
        LastPlayingSignature = signature
        LastSummaryTime = now

        print("\n[CustomBGMMod] ================= [인게임 오디오 실시간 모니터] =================")
        print(string.format("  - 순정 BGM 상태     : %s (뮤트된 BGM 컴포넌트: %d개)", HasCustomMusic and "차단됨 (0.0 Vol)" or "정상 재생 중", musicMutedCount))
        print(string.format("  - 송풍기 기믹(SFX)  : %d개 재생 중 (MuteAmbient=%s) -> [End] 키로 끄기 가능", uflemeciCount, tostring(MuteAmbientSFX)))
        if #activeSFX > 0 then
            print("  - 기타 활성 효과음(SFX):")
            for i = 1, math.min(#activeSFX, 5) do
                print(string.format("      * %s", activeSFX[i]))
            end
            if #activeSFX > 5 then
                print(string.format("      * (외 %d개 효과음)", #activeSFX - 5))
            end
        end
        print("========================================================================\n")
    end
end

-- Guardian loop: 300ms
LoopAsync(300, function()
    ExecuteInGameThread(function()
        if not HasCustomMusic then
            HasCustomMusic = CheckHasCustomMusic()
            if HasCustomMusic then
                print(string.format("[CustomBGMMod] [Detected] 새 커스텀 음악 발견: '%s'", HWA_DIR))
                LaunchBGMPlayer()
            end
        end

        ProcessAudio()
    end)
    return false
end)

-- 6. In-Game Keybinds
RegisterKeyBind(Key.F10, function()
    SendPlayerCommand("toggle")
    print("[CustomBGMMod] Key [F10]: BGM Play/Pause toggled.")
end)

RegisterKeyBind(Key.F11, function()
    SendPlayerCommand("next")
    print("[CustomBGMMod] Key [F11]: 다음 곡으로 건너뛰기.")
end)

RegisterKeyBind(Key.PAGE_UP, function()
    SendPlayerCommand("vol_up")
    print("[CustomBGMMod] Key [PageUp]: 커스텀 BGM 볼륨 +10%.")
end)

RegisterKeyBind(Key.PAGE_DOWN, function()
    SendPlayerCommand("vol_down")
    print("[CustomBGMMod] Key [PageDown]: 커스텀 BGM 볼륨 -10%.")
end)

-- [End] 키: 시끄러운 송풍기(Uflemeci) 및 바람 환경음 원클릭 음소거 토글!
RegisterKeyBind(Key.END, function()
    MuteAmbientSFX = not MuteAmbientSFX
    print(string.format("\n[CustomBGMMod] Key [End]: 송풍기/바람 환경 효과음 음소거 -> %s\n", MuteAmbientSFX and "ON (소음 차단)" or "OFF (원래대로)"))
end)

print("[CustomBGMMod] Loaded! 단축키:")
print("  - [F10]      : BGM 일시정지 / 재생 토글")
print("  - [F11]      : 다음 곡 재생 (파일이 여러 개일 때)")
print("  - [PageUp]   : 커스텀 BGM 볼륨 10% 증가")
print("  - [PageDown] : 커스텀 BGM 볼륨 10% 감소")
print("  - [End]      : ★ 시끄러운 송풍기/바람 환경음(SFX) 원클릭 음소거 토글")
print("  - [자동 모니터] : 오디오 변경 시 요약 박스 자동 로깅 (스팸 0%)")
print("  - 커스텀 음악 경로: " .. HWA_DIR)
