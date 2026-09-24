local UEHelpers = require("UEHelpers")

print("==================================================")
print("[UnlockAllMod] Hans Skin & Achievement Unlocker Loading...")
print("==================================================")

-- Configuration
local AutoUnlockOnStart = true
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
-- SaveGame Direct File Patcher (이중 안전장치)
-- -----------------------------------------------------------------------------
local function PatchSkinsSave()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData then return false end
    local filePath = localAppData .. "\\Hans\\Saved\\SaveGames\\skinslot.sav"

    local file = io.open(filePath, "rb")
    if not file then
        print("[UnlockAllMod] [Info] skinslot.sav not found on disk yet.")
        return false
    end
    local data = file:read("*a")
    file:close()

    local searchTag = "SavedSkins\0"
    local idx = string.find(data, searchTag, 1, true)
    if not idx then
        print("[UnlockAllMod] [Warn] SavedSkins tag not found in skinslot.sav.")
        return false
    end

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
        print(string.format("[UnlockAllMod] [OK] skinslot.sav successfully patched with all %d skins!", NUM_SKINS))
        return true
    end
    return false
end

local function PatchAchievementsSave()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData then return false end
    local filePath = localAppData .. "\\Hans\\Saved\\SaveGames\\achslot.sav"

    local file = io.open(filePath, "rb")
    if not file then
        print("[UnlockAllMod] [Info] achslot.sav not found on disk yet.")
        return false
    end
    local data = file:read("*a")
    file:close()

    local searchTag = "Achievements\0"
    local idx = string.find(data, searchTag, 1, true)
    if not idx then
        print("[UnlockAllMod] [Warn] Achievements tag not found in achslot.sav.")
        return false
    end

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
        print(string.format("[UnlockAllMod] [OK] achslot.sav successfully patched with all %d achievements!", NUM_ACHIEVEMENTS))
        return true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- In-Game Runtime Unlock Logic
-- -----------------------------------------------------------------------------
local function UnlockAllSkins()
    print("\n[UnlockAllMod] ========================================")
    print(string.format("[UnlockAllMod] 모든 %d종 스킨 해금 시작...", NUM_SKINS))

    -- 1. 디스크 세이브 파일 선제적 패치
    PatchSkinsSave()

    -- 2. 런타임 메모리 액터에 함수 호출
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
            print(string.format("[UnlockAllMod] [OK] BP_SkinManager_C에 %d개 스킨 언락 호출 완료!", NUM_SKINS))
        else
            print("[UnlockAllMod] [Info] 현재 레벨에 BP_SkinManager_C 없음 (세이브 파일 패치 완료)")
        end
    end)

    print("[UnlockAllMod] ========================================\n")
end

local function UnlockAllAchievements()
    print("\n[UnlockAllMod] ========================================")
    print(string.format("[UnlockAllMod] 모든 %d종 업적 해금 및 Steam 트리거 시작...", NUM_ACHIEVEMENTS))

    -- 1. 디스크 세이브 파일 선제적 패치
    PatchAchievementsSave()

    -- 2. 런타임 메모리 액터에 함수 호출 (Steam 업적 팝업 트리거)
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
            print(string.format("[UnlockAllMod] [OK] BP_AchievementManager_C에 %d개 업적 언락 & Steam 전송 호출 완료!", NUM_ACHIEVEMENTS))
        else
            print("[UnlockAllMod] [Info] 현재 레벨에 BP_AchievementManager_C 없음 (세이브 파일 패치 완료)")
        end
    end)

    print("[UnlockAllMod] ========================================\n")
end

local function UnlockEverything()
    print("\n[UnlockAllMod] [All-In-One] 모든 스킨 + 모든 업적 전체 해금 실행!")
    UnlockAllSkins()
    UnlockAllAchievements()
end

-- -----------------------------------------------------------------------------
-- Keybinds
-- -----------------------------------------------------------------------------
-- F7 / Num 7: Unlock All Skins
RegisterKeyBind(Key.F7, UnlockAllSkins)
RegisterKeyBind(Key.NUM_SEVEN, UnlockAllSkins)

-- F8 / Num 8: Unlock All Achievements
RegisterKeyBind(Key.F8, UnlockAllAchievements)
RegisterKeyBind(Key.NUM_EIGHT, UnlockAllAchievements)

-- F9 / Num 9: Unlock All Skins & Achievements
RegisterKeyBind(Key.F9, UnlockEverything)
RegisterKeyBind(Key.NUM_NINE, UnlockEverything)

-- -----------------------------------------------------------------------------
-- Auto Unlock on Start
-- -----------------------------------------------------------------------------
if AutoUnlockOnStart then
    ExecuteWithDelay(2000, function()
        UnlockEverything()
    end)
end

print("[UnlockAllMod] Loaded! 단축키:")
print("  - [F7] / [Num 7]: 모든 45종 스킨 해금 (Unlock All 45 Skins)")
print("  - [F8] / [Num 8]: 모든 23종 업적 해금 및 Steam 등록 (Unlock All Achievements & Steam)")
print("  - [F9] / [Num 9]: 스킨 + 업적 올인원 즉시 해금 (Unlock Everything)")
