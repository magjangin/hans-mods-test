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

-- Helper: Pack 64-bit little-endian integer to 8 bytes (lower 32-bit used)
local function PackI64(n)
    return PackI32(n) .. "\0\0\0\0"
end

-- -----------------------------------------------------------------------------
-- SaveGame Direct File Patcher (디스크 세이브 파일 즉각 주입)
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

    -- Build entries for 45 skins
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
        print(string.format("[UnlockAllMod] [디스크] skinslot.sav에 %d개 모든 스킨 자동 주입 완료!", NUM_SKINS))
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

    -- Build entries for 23 achievements
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
        print(string.format("[UnlockAllMod] [디스크] achslot.sav에 %d개 모든 업적 자동 주입 완료!", NUM_ACHIEVEMENTS))
        return true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- In-Game Runtime Unlock Functions
-- -----------------------------------------------------------------------------
local function UnlockAllSkins(isAuto)
    PatchSkinsSave()

    ExecuteInGameThread(function()
        local skinManagers = FindAllOf("BP_SkinManager_C")
        if skinManagers and #skinManagers > 0 then
            for _, sm in ipairs(skinManagers) do
                if sm:IsValid() then
                    for i = 0, NUM_SKINS - 1 do
                        pcall(function() sm:UnlockASkin(i) end)
                    end
                end
            end
            local prefix = isAuto and "[UnlockAllMod] [자동완료]" or "[UnlockAllMod] [수동완료]"
            print(string.format("%s BP_SkinManager_C에 %d개 스킨 언락 호출 완료!", prefix, NUM_SKINS))
        end
    end)
end

local function UnlockAllAchievements(isAuto)
    PatchAchievementsSave()

    ExecuteInGameThread(function()
        local achManagers = FindAllOf("BP_AchievementManager_C")
        if achManagers and #achManagers > 0 then
            for _, am in ipairs(achManagers) do
                if am:IsValid() then
                    for i = 0, NUM_ACHIEVEMENTS - 1 do
                        pcall(function() am:UnlockAchievement(i) end)
                    end
                end
            end
            local prefix = isAuto and "[UnlockAllMod] [자동완료]" or "[UnlockAllMod] [수동완료]"
            print(string.format("%s BP_AchievementManager_C에 %d개 업적 언락 & Steam 전송 완료!", prefix, NUM_ACHIEVEMENTS))
        end
    end)
end

local function UnlockEverything(isAuto)
    UnlockAllSkins(isAuto)
    UnlockAllAchievements(isAuto)
end

-- -----------------------------------------------------------------------------
-- 전자동 백그라운드 가디언 루프 (키 입력 불필요)
-- 게임 실행 시 및 레벨/메뉴 진입 시 매니저 액터를 자동 감지하여 즉시 해금
-- -----------------------------------------------------------------------------
-- 1. 모드 로드 즉시 세이브 파일 1차 선제적 패치
PatchSkinsSave()
PatchAchievementsSave()

local LastUnlockedSkinManager = nil
local LastUnlockedAchManager = nil

LoopAsync(500, function()
    ExecuteInGameThread(function()
        -- 스킨 매니저 자동 감지 및 즉시 해금
        local sm = FindFirstOf("BP_SkinManager_C")
        if sm and sm:IsValid() and sm ~= LastUnlockedSkinManager then
            LastUnlockedSkinManager = sm
            for i = 0, NUM_SKINS - 1 do
                pcall(function() sm:UnlockASkin(i) end)
            end
            print(string.format("[UnlockAllMod] [자동 감지] BP_SkinManager_C 스폰 감지 -> %d개 모든 스킨 자동 해금 완료!", NUM_SKINS))
        end

        -- 업적 매니저 자동 감지 및 즉시 해금 (Steam 도전과제 연동)
        local am = FindFirstOf("BP_AchievementManager_C")
        if am and am:IsValid() and am ~= LastUnlockedAchManager then
            LastUnlockedAchManager = am
            for i = 0, NUM_ACHIEVEMENTS - 1 do
                pcall(function() am:UnlockAchievement(i) end)
            end
            print(string.format("[UnlockAllMod] [자동 감지] BP_AchievementManager_C 스폰 감지 -> %d개 모든 업적 자동 해금 및 Steam 전송 완료!", NUM_ACHIEVEMENTS))
        end
    end)
    return false -- 백그라운드 루프 지속 유지
end)

-- -----------------------------------------------------------------------------
-- 수동 비상 단축키 (필요 시 직접 누를 수도 있음)
-- -----------------------------------------------------------------------------
RegisterKeyBind(Key.F7, function() UnlockAllSkins(false) end)
RegisterKeyBind(Key.NUM_SEVEN, function() UnlockAllSkins(false) end)

RegisterKeyBind(Key.F8, function() UnlockAllAchievements(false) end)
RegisterKeyBind(Key.NUM_EIGHT, function() UnlockAllAchievements(false) end)

RegisterKeyBind(Key.F9, function() UnlockEverything(false) end)
RegisterKeyBind(Key.NUM_NINE, function() UnlockEverything(false) end)

print("[UnlockAllMod] 준비 완료: 키 입력 없이 게임 실행 시 모든 스킨 및 업적이 전자동으로 즉시 해금됩니다.")
