local UEHelpers = require("UEHelpers")

print("==================================================")
print("[UnlockAllMod] Hans Skin & Achievement Auto-Unlocker Loading...")
print("==================================================")

local NUM_SKINS = 45        -- E_Skins::Type 0..44 (45 skins)
local NUM_ACHIEVEMENTS = 23 -- EAchievements::Type 0..22 (23 achievements)

-- Helper: Pack 32-bit little-endian integer to 4 bytes
local function PackI32(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

-- Helper: Pack 64-bit little-endian integer to 8 bytes
local function PackI64(n)
    return PackI32(n) .. "\0\0\0\0"
end

-- -----------------------------------------------------------------------------
-- SaveGame Direct File Patcher
-- -----------------------------------------------------------------------------
local function PatchSkinsSave()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData then return false end
    local filePath = localAppData .. "\\Hans\\Saved\\SaveGames\\skinslot.sav"

    local file = io.open(filePath, "rb")
    if not file then return false end
    local data = file:read("*a")
    file:close()

    local searchTag = "SavedSkins\0"
    local idx = string.find(data, searchTag, 1, true)
    if not idx then return false end

    local prefix = string.sub(data, 1, idx - 1)

    local entries = {}
    for i = 0, NUM_SKINS - 1 do
        local name = "E_Skins::NewEnumerator" .. tostring(i) .. "\0"
        table.insert(entries, PackI32(#name) .. name .. "\1")
    end
    local entriesData = table.concat(entries)
    local payload = PackI32(0) .. PackI32(NUM_SKINS) .. entriesData

    local propName = "SavedSkins\0"
    local propType = PackI32(12) .. "MapProperty\0"
    local propSize = PackI64(#payload)
    local keyType = PackI32(13) .. "ByteProperty\0"
    local valType = PackI32(13) .. "BoolProperty\0"
    local tag = "\0"
    local trailer = PackI32(5) .. "None\0\0\0\0\0"

    local newContent = prefix .. propName .. propType .. propSize .. keyType .. valType .. tag .. payload .. trailer

    local outFile = io.open(filePath, "wb")
    if outFile then
        outFile:write(newContent)
        outFile:close()
        return true
    end
    return false
end

local function PatchAchievementsSave()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData then return false end
    local filePath = localAppData .. "\\Hans\\Saved\\SaveGames\\achslot.sav"

    local file = io.open(filePath, "rb")
    if not file then return false end
    local data = file:read("*a")
    file:close()

    local searchTag = "Achievements\0"
    local idx = string.find(data, searchTag, 1, true)
    if not idx then return false end

    local prefix = string.sub(data, 1, idx - 1)

    local entries = {}
    for i = 0, NUM_ACHIEVEMENTS - 1 do
        local name = "EAchievements::NewEnumerator" .. tostring(i) .. "\0"
        table.insert(entries, PackI32(#name) .. name .. "\1")
    end
    local entriesData = table.concat(entries)
    local payload = PackI32(0) .. PackI32(NUM_ACHIEVEMENTS) .. entriesData

    local propName = "Achievements\0"
    local propType = PackI32(12) .. "MapProperty\0"
    local propSize = PackI64(#payload)
    local keyType = PackI32(13) .. "ByteProperty\0"
    local valType = PackI32(13) .. "BoolProperty\0"
    local tag = "\0"
    local trailer = PackI32(5) .. "None\0\0\0\0\0"

    local newContent = prefix .. propName .. propType .. propSize .. keyType .. valType .. tag .. payload .. trailer

    local outFile = io.open(filePath, "wb")
    if outFile then
        outFile:write(newContent)
        outFile:close()
        return true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- Steamworks Direct API Bridge
-- -----------------------------------------------------------------------------
local function TriggerSteamAchievementsDirectly()
    local scriptDir = os.getenv("HANS_MODS_DIR") or "H:\\ue4ss mod test\\hans mods test"
    local pythonScript = scriptDir .. "\\unlock_steam_achievements.py"
    pcall(function()
        os.execute('start /b "" python "' .. pythonScript .. '"')
    end)
end

-- -----------------------------------------------------------------------------
-- In-Game Runtime Unlock Logic (정밀 1회 실행)
-- -----------------------------------------------------------------------------
local HasUnlockedSkins = false
local HasUnlockedAchievements = false

local function UnlockAllSkinsInternal(isManual)
    PatchSkinsSave()

    ExecuteInGameThread(function()
        local sm = FindFirstOf("BP_SkinManager_C")
        if sm and sm:IsValid() then
            for i = 0, NUM_SKINS - 1 do
                pcall(function() sm:UnlockASkin(i) end)
            end
            HasUnlockedSkins = true
            print(string.format("[UnlockAllMod] [%s] 45종 모든 스킨 해금 완료!", isManual and "수동" or "자동"))
        end
    end)
end

local function UnlockAllAchievementsInternal(isManual)
    -- Steam API 직접 동기화
    TriggerSteamAchievementsDirectly()

    ExecuteInGameThread(function()
        local am = FindFirstOf("BP_AchievementManager_C")
        if am and am:IsValid() then
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
            local statMgr = FindFirstOf("BP_StatManager_C")
            if statMgr and statMgr:IsValid() then
                statMgr.StatJump = 5000
                statMgr.StatHans = 200
                statMgr.StatChest = 45
                statMgr.StatRestart = 100
                statMgr.StatTrashcan = 10
                statMgr.StatMaxZ = 100000.0
                for s = 0, 10 do
                    pcall(function() statMgr:CheckForAchievements(s) end)
                end
            end

            HasUnlockedAchievements = true
            PatchAchievementsSave()
            print(string.format("[UnlockAllMod] [%s] 23종 모든 업적 및 Steam 연동 완료!", isManual and "수동" or "자동"))
        end
    end)
end

local function UnlockEverything(isManual)
    UnlockAllSkinsInternal(isManual)
    UnlockAllAchievementsInternal(isManual)
end

-- -----------------------------------------------------------------------------
-- 백그라운드 가디언 루프 (스팸 완전 제거 및 1회 완료 시 자동 종료)
-- -----------------------------------------------------------------------------
-- 1. 모드 로드 시 디스크 세이브 선제적 패치
PatchSkinsSave()
PatchAchievementsSave()

LoopAsync(1000, function()
    -- 둘 다 완료되었으면 루프 완전 종료 (스팸 100% 방지)
    if HasUnlockedSkins and HasUnlockedAchievements then
        print("[UnlockAllMod] [완료] 모든 스킨 및 업적 해금 처리가 성공적으로 완료되었습니다. (감시 루프 종료)")
        return true -- 루프 종료
    end

    ExecuteInGameThread(function()
        if not HasUnlockedSkins then
            local sm = FindFirstOf("BP_SkinManager_C")
            if sm and sm:IsValid() then
                UnlockAllSkinsInternal(false)
            end
        end

        if not HasUnlockedAchievements then
            local am = FindFirstOf("BP_AchievementManager_C")
            if am and am:IsValid() then
                UnlockAllAchievementsInternal(false)
            end
        end
    end)

    return false -- 미완료 항목이 있으면 1초 후 다시 1회 체크
end)

-- -----------------------------------------------------------------------------
-- 비상 수동 단축키 (필요 시 직접 재호출 가능)
-- -----------------------------------------------------------------------------
RegisterKeyBind(Key.F7, function() UnlockAllSkinsInternal(true) end)
RegisterKeyBind(Key.NUM_SEVEN, function() UnlockAllSkinsInternal(true) end)

RegisterKeyBind(Key.F8, function() UnlockAllAchievementsInternal(true) end)
RegisterKeyBind(Key.NUM_EIGHT, function() UnlockAllAchievementsInternal(true) end)

RegisterKeyBind(Key.F9, function() UnlockEverything(true) end)
RegisterKeyBind(Key.NUM_NINE, function() UnlockEverything(true) end)

print("[UnlockAllMod] 로드 완료 (로그 스팸 방지 및 Steam 연동 최적화 적용)")
