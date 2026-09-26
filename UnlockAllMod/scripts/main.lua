print("==================================================")
print("[UnlockAllMod] Hans Skin & Achievement Auto-Unlocker Loading...")
print("==================================================")

local NUM_SKINS = 45        -- E_Skins::Type 0..44 (45 skins)
local NUM_ACHIEVEMENTS = 23 -- EAchievements::Type 0..22 (23 achievements)

local SKIN_SAVE = {
    fileName = "skinslot.sav",
    propertyName = "SavedSkins",
    enumPrefix = "E_Skins::NewEnumerator",
    count = NUM_SKINS,
}
local ACHIEVEMENT_SAVE = {
    fileName = "achslot.sav",
    propertyName = "Achievements",
    enumPrefix = "EAchievements::NewEnumerator",
    count = NUM_ACHIEVEMENTS,
}

-- -----------------------------------------------------------------------------
-- SaveGame Direct File Patcher
-- -----------------------------------------------------------------------------
-- GVAS FString: int32 length (including the null terminator), bytes, null terminator
local FSTRING = "<s4"
-- Map tag after the property name: type, size, array index, key type, value type, has-guid flag
local MAP_TAG = "<s4 i4 i4 s4 s4 B"

local function FString(s)
    return string.pack(FSTRING, s .. "\0")
end

--- Rewrite a TMap<Enum, bool> property so that every enumerator is true.
--- Properties stored after the map (e.g. SelectedMesh in skinslot.sav) are kept.
---@return boolean true if the file was rewritten
local function PatchBoolMapSave(save)
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData then return false end
    local filePath = localAppData .. "\\Hans\\Saved\\SaveGames\\" .. save.fileName

    local file = io.open(filePath, "rb")
    if not file then return false end
    local data = file:read("*a")
    file:close()

    -- The int32 length before the name stays in the prefix; everything from the name on is rewritten
    local nameStart = data:find(save.propertyName .. "\0", 1, true)
    if not nameStart then return false end

    local ok, _, oldSize, _, _, _, hasGuid, valueStart =
        pcall(string.unpack, MAP_TAG, data, nameStart + #save.propertyName + 1)
    if not ok then return false end
    if hasGuid ~= 0 then valueStart = valueStart + 16 end
    local rest = data:sub(valueStart + oldSize)

    local entries = {}
    for i = 0, save.count - 1 do
        entries[#entries + 1] = FString(save.enumPrefix .. i) .. "\1"
    end
    -- NumKeysToRemove, NumEntries, entries
    local value = string.pack("<i4 i4", 0, save.count) .. table.concat(entries)
    local tag = FString("MapProperty") .. string.pack("<i4 i4", #value, 0)
        .. FString("ByteProperty") .. FString("BoolProperty") .. "\0"

    local newData = data:sub(1, nameStart - 1) .. save.propertyName .. "\0" .. tag .. value .. rest
    if newData == data then return true end -- already fully unlocked

    local outFile = io.open(filePath, "wb")
    if not outFile then return false end
    outFile:write(newData)
    outFile:close()
    return true
end

-- -----------------------------------------------------------------------------
-- Steamworks Direct API Bridge
-- -----------------------------------------------------------------------------
-- This mod's folder, taken from the path UE4SS loaded this script from
-- ("@...\Mods\UnlockAllMod\Scripts\main.lua"; UE4SS capitalises "Scripts")
local ModDir = debug.getinfo(1, "S").source:match("^@(.+)[\\/][^\\/]+[\\/][^\\/]+$")
local SteamScript = ModDir and (ModDir .. "\\unlock_steam_achievements.py")

local function TriggerSteamAchievementsDirectly()
    if not SteamScript then return end
    pcall(function()
        os.execute('start /b "" python "' .. SteamScript .. '"')
    end)
end

-- -----------------------------------------------------------------------------
-- In-Game Runtime Unlock Logic (정밀 1회 실행)
-- -----------------------------------------------------------------------------
local HasUnlockedSkins = false
local HasUnlockedAchievements = false

local function FindManager(className)
    local manager = FindFirstOf(className)
    if manager and manager:IsValid() then return manager end
    return nil
end

local function SourceLabel(isManual)
    return isManual and "수동" or "자동"
end

-- The *OnGameThread functions must run on the game thread; they set the Has* flags synchronously
-- so a guardian tick queued behind a stalled game thread sees them and does not unlock twice.
local function UnlockAllSkinsOnGameThread(isManual)
    PatchBoolMapSave(SKIN_SAVE)

    local sm = FindManager("BP_SkinManager_C")
    if not sm then return end

    for i = 0, NUM_SKINS - 1 do
        pcall(function() sm:UnlockASkin(i) end)
    end
    HasUnlockedSkins = true
    print(string.format("[UnlockAllMod] [%s] 45종 모든 스킨 해금 완료!", SourceLabel(isManual)))
end

-- Lowest stat values that satisfy every stat-based achievement
local ACHIEVEMENT_STAT_TARGETS = {
    StatJump = 5000,
    StatHans = 200,
    StatChest = 45,
    StatRestart = 100,
    StatTrashcan = 10,
    StatMaxZ = 100000.0,
}

local function MaxOutStats()
    local statMgr = FindManager("BP_StatManager_C")
    if not statMgr then return end

    -- Only raise stats: the game saves them, so lowering a real value would lose the player's progress
    for stat, target in pairs(ACHIEVEMENT_STAT_TARGETS) do
        local current = tonumber(statMgr[stat]) or 0
        if current < target then
            statMgr[stat] = target
        end
    end
    for s = 0, 10 do
        pcall(function() statMgr:CheckForAchievements(s) end)
    end
end

local function UnlockAllAchievementsOnGameThread(isManual)
    -- Steam API 직접 동기화
    TriggerSteamAchievementsDirectly()

    local am = FindManager("BP_AchievementManager_C")
    if not am then return end

    -- 메모리 캐시 비우기 (이미 True로 캐싱되어 스킵되는 현상 방지)
    if am.Achievements and am.Achievements.Empty then
        pcall(function() am.Achievements:Empty() end)
    end
    if am.SaveAchs and am.SaveAchs:IsValid() and am.SaveAchs.Achievements and am.SaveAchs.Achievements.Empty then
        pcall(function() am.SaveAchs.Achievements:Empty() end)
    end

    -- 인게임 업적 UFunction 호출 및 BP_Achievement_C 스폰
    for i = 0, NUM_ACHIEVEMENTS - 1 do
        pcall(function() am:UnlockAchievement(i) end)
    end

    -- 인게임 스탯 매니저 수치 극대화 트리거
    MaxOutStats()

    HasUnlockedAchievements = true
    PatchBoolMapSave(ACHIEVEMENT_SAVE)
    print(string.format("[UnlockAllMod] [%s] 23종 모든 업적 및 Steam 연동 완료!", SourceLabel(isManual)))
end

local function UnlockAllSkins(isManual)
    ExecuteInGameThread(function() UnlockAllSkinsOnGameThread(isManual) end)
end

local function UnlockAllAchievements(isManual)
    ExecuteInGameThread(function() UnlockAllAchievementsOnGameThread(isManual) end)
end

local function UnlockEverything(isManual)
    UnlockAllSkins(isManual)
    UnlockAllAchievements(isManual)
end

-- -----------------------------------------------------------------------------
-- 백그라운드 가디언 루프 (스팸 완전 제거 및 1회 완료 시 자동 종료)
-- -----------------------------------------------------------------------------
-- 1. 모드 로드 시 디스크 세이브 선제적 패치
PatchBoolMapSave(SKIN_SAVE)
PatchBoolMapSave(ACHIEVEMENT_SAVE)

LoopAsync(1000, function()
    -- 둘 다 완료되었으면 루프 완전 종료 (스팸 100% 방지)
    if HasUnlockedSkins and HasUnlockedAchievements then
        print("[UnlockAllMod] [완료] 모든 스킨 및 업적 해금 처리가 성공적으로 완료되었습니다. (감시 루프 종료)")
        return true -- 루프 종료
    end

    ExecuteInGameThread(function()
        if not HasUnlockedSkins and FindManager("BP_SkinManager_C") then
            UnlockAllSkinsOnGameThread(false)
        end
        if not HasUnlockedAchievements and FindManager("BP_AchievementManager_C") then
            UnlockAllAchievementsOnGameThread(false)
        end
    end)

    return false -- 미완료 항목이 있으면 1초 후 다시 1회 체크
end)

-- -----------------------------------------------------------------------------
-- 비상 수동 단축키 (필요 시 직접 재호출 가능)
-- -----------------------------------------------------------------------------
local function BindKeys(keys, callback)
    for _, key in ipairs(keys) do
        RegisterKeyBind(key, callback)
    end
end

BindKeys({ Key.F7, Key.NUM_SEVEN }, function() UnlockAllSkins(true) end)
BindKeys({ Key.F8, Key.NUM_EIGHT }, function() UnlockAllAchievements(true) end)
BindKeys({ Key.F9, Key.NUM_NINE }, function() UnlockEverything(true) end)

print(string.format("[UnlockAllMod] Steam 연동 스크립트: %s", SteamScript or "(모드 경로를 찾지 못해 건너뜀)"))
print("[UnlockAllMod] 로드 완료 (로그 스팸 방지 및 Steam 연동 최적화 적용)")
