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
    print(string.format("[CustomBGMMod] [Active] 커스텀 음악 감지됨: '%s'", HWA_DIR))
    print("[CustomBGMMod] [Zero-Sound] 게임 순정의 모든 사운드(BGM + SFX)를 전자동으로 100% 완전 음소거합니다.")
else
    print(string.format("[CustomBGMMod] [Notice] '%s' 폴더에 음악이 없습니다. 게임 순정 사운드 정상 출력.", HWA_DIR))
end

-- 5. Complete In-Game Sound Muter (BGM + All SFX)
local ReportedMuteCount = -1

local function SilenceAllGameAudio()
    if not HasCustomMusic then return end

    -- 1) GameInstance Level Mute (Master, Music, SFX 전부 0.0)
    local gi = FindFirstOf("GI_Hans_C")
    if gi and gi:IsValid() then
        pcall(function() gi:MasterVolumeChanged(0.0) end)
        pcall(function() gi:MusicVolumeChanged(0.0) end)
        pcall(function() gi:SFXVolumeChanged(0.0) end)
    end

    -- 2) World Level Mute: 모든 AudioComponent를 0.0 볼륨 및 Stop 처리
    local allComps = FindAllOf("AudioComponent") or {}
    local mutedCount = 0

    for _, comp in ipairs(allComps) do
        if comp:IsValid() then
            if comp.VolumeMultiplier ~= 0.0 then
                pcall(function()
                    comp:SetVolumeMultiplier(0.0)
                    comp:Stop()
                end)
            end
            mutedCount = mutedCount + 1
        end
    end

    if mutedCount ~= ReportedMuteCount then
        ReportedMuteCount = mutedCount
        print(string.format("[CustomBGMMod] [AutoMute] 게임 내 모든 사운드 컴포넌트 %d개 완전 침묵 유지 중 (순수 커스텀 BGM 전용)", mutedCount))
    end
end

-- Guardian loop: 250ms periodic check (키 입력 없이 전자동 동작)
LoopAsync(250, function()
    ExecuteInGameThread(function()
        if not HasCustomMusic then
            HasCustomMusic = CheckHasCustomMusic()
            if HasCustomMusic then
                print(string.format("[CustomBGMMod] [Detected] 새 커스텀 음악 발견: '%s'", HWA_DIR))
                LaunchBGMPlayer()
            end
        end

        SilenceAllGameAudio()
    end)
    return false
end)

print("[CustomBGMMod] Loaded! (키 입력 불필요, 커스텀 BGM 감지 시 게임 내 모든 소리 자동 차단 모드)")
