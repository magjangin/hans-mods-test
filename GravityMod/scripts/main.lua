local UEHelpers = require("UEHelpers")

print("==================================================")
print("[GravityMod] Hans Gravity Controller Mod Loading...")
print("==================================================")

-- How gravity reaches the player in UE:
--   CharacterMovement:GetGravityZ() = WorldSettings:GetGravityZ() * GravityScale
-- AWorldSettings::GetGravityZ() re-derives WorldGravityZ from GlobalGravityZ (when bGlobalGravitySet)
-- or the project DefaultGravityZ on each call in standalone, so writing WorldGravityZ alone does not
-- stick. The mode multiplier is applied once, through GlobalGravityZ, and GravityScale is left to the game.

-- Captured original physics parameters from the game
local HasCapturedOriginals = false
local OriginalWorldGravityZ = nil
local OriginalGlobalGravityZ = 0.0
local OriginalGlobalGravitySet = false
local OriginalGravityScale = 1.0

-- Current mod state
local CurrentGravityScale = 1.0 -- multiplier relative to the original world gravity
local CurrentModeName = "Normal"
local ForceMaintainGravity = false
local DriftReported = false

---@return UCharacterMovementComponent|nil
local function GetPlayerMovement(player)
    if player:IsValid() and player.CharacterMovement and player.CharacterMovement:IsValid() then
        return player.CharacterMovement
    end
    return nil
end

--- Capture original untouched physics parameters from the game
---@return boolean true if successfully captured
local function CaptureOriginalsOnce()
    if HasCapturedOriginals then return true end

    local worldSettings = UEHelpers.GetWorldSettings()
    local player = UEHelpers.GetPlayer()
    local movement = GetPlayerMovement(player)

    if worldSettings:IsValid() and movement then
        -- WorldGravityZ is a transient cache; it can still be 0 if nothing has queried gravity yet
        OriginalWorldGravityZ = (worldSettings.WorldGravityZ ~= 0.0) and worldSettings.WorldGravityZ or -980.0
        OriginalGlobalGravityZ = worldSettings.GlobalGravityZ
        OriginalGlobalGravitySet = worldSettings.bGlobalGravitySet or false
        OriginalGravityScale = movement.GravityScale
        HasCapturedOriginals = true

        print("\n[GravityMod] ========================================")
        print("[GravityMod] [Original Physics Captured Successfully]")
        print(string.format("[GravityMod]   WorldGravityZ:     %.1f", OriginalWorldGravityZ))
        print(string.format("[GravityMod]   GlobalGravityZ:    %.1f (bGlobalGravitySet=%s)", OriginalGlobalGravityZ, tostring(OriginalGlobalGravitySet)))
        print(string.format("[GravityMod]   GravityScale:      %.2f", OriginalGravityScale))
        print(string.format("[GravityMod]   Effective gravity: %.1f", movement:GetGravityZ()))
        print(string.format("[GravityMod]   JumpZVelocity:     %.1f", movement.JumpZVelocity))
        print("[GravityMod] ========================================\n")
        return true
    end
    return false
end

local function SetWorldGravity(worldSettings, globalGravityZ, globalGravitySet, worldGravityZ)
    worldSettings.GlobalGravityZ = globalGravityZ
    worldSettings.bGlobalGravitySet = globalGravitySet
    worldSettings.WorldGravityZ = worldGravityZ
end

--- Print the gravity the player's CharacterMovement actually uses right now
local function ReportEffectiveGravity(tag)
    local player = UEHelpers.GetPlayer()
    local movement = GetPlayerMovement(player)
    if not movement then
        print(string.format("[GravityMod] [%s] Player pawn not found.", tag))
        return
    end

    local effective = movement:GetGravityZ()
    local originalEffective = (OriginalWorldGravityZ or -980.0) * OriginalGravityScale
    local ratio = (originalEffective ~= 0.0) and (effective / originalEffective) or 0.0
    print(string.format("[GravityMod] [%s] %s -> Effective gravity: %.1f (%.3fx of original %.1f, expected %.3fx)",
        tag, CurrentModeName, effective, ratio, originalEffective, ForceMaintainGravity and CurrentGravityScale or 1.0))
end

local function VerifyAfterDelay()
    ExecuteWithDelay(500, function()
        ExecuteInGameThread(function() ReportEffectiveGravity("Verify") end)
    end)
end

--- Completely restore all physics parameters to the captured original values
local function RestoreOriginals()
    CurrentGravityScale = 1.0
    CurrentModeName = "원래 상태 (Original 1.0x)"
    ForceMaintainGravity = false

    ExecuteInGameThread(function()
        CaptureOriginalsOnce()

        print("\n[GravityMod] ========================================")
        print("[GravityMod] [Restoring to Original Game Defaults]")

        local worldSettings = UEHelpers.GetWorldSettings()
        if worldSettings:IsValid() and OriginalWorldGravityZ ~= nil then
            SetWorldGravity(worldSettings, OriginalGlobalGravityZ, OriginalGlobalGravitySet, OriginalWorldGravityZ)
            print(string.format("[GravityMod] [OK] GlobalGravityZ=%.1f, bGlobalGravitySet=%s, WorldGravityZ=%.1f restored",
                OriginalGlobalGravityZ, tostring(OriginalGlobalGravitySet), OriginalWorldGravityZ))
        else
            print("[GravityMod] [Warn] WorldSettings not found during restore.")
        end

        print("[GravityMod] ========================================\n")
    end)
    VerifyAfterDelay()
end

--- Apply gravity as a multiple of the original world gravity
---@param scale number Multiplier relative to original gravity (0.0 to 1.0)
---@param modeName string Mode description
local function ApplyGravity(scale, modeName)
    CurrentGravityScale = scale
    CurrentModeName = modeName
    ForceMaintainGravity = true
    DriftReported = false

    ExecuteInGameThread(function()
        CaptureOriginalsOnce()

        local targetGravityZ = (OriginalWorldGravityZ or -980.0) * scale

        print("\n[GravityMod] ========================================")
        print(string.format("[GravityMod] Mode: [%s]", modeName))
        print(string.format("[GravityMod] Scale: %.2fx | GlobalGravityZ: %.1f | GravityScale kept at game value",
            scale, targetGravityZ))

        local worldSettings = UEHelpers.GetWorldSettings()
        if worldSettings:IsValid() then
            SetWorldGravity(worldSettings, targetGravityZ, true, targetGravityZ)
        else
            print("[GravityMod] [Warn] WorldSettings not found.")
        end

        -- Zero gravity: cancel vertical speed so the player floats instead of drifting down forever
        if scale == 0.0 then
            local player = UEHelpers.GetPlayer()
            if player:IsValid() and player.LaunchCharacter then
                player:LaunchCharacter({X = 0, Y = 0, Z = 0}, false, true)
            end
        end

        print("[GravityMod] ========================================\n")
    end)
    VerifyAfterDelay()
end

--- Upward float impulse for Floating mode
local function TriggerFloatUp()
    ExecuteInGameThread(function()
        local player = UEHelpers.GetPlayer()
        if player:IsValid() and player.LaunchCharacter then
            player:LaunchCharacter({X = 0, Y = 0, Z = 750}, false, true)
            print("[GravityMod] [Float] Launching character upward into float state!\n")
        end
    end)
end

-- Capture originals once the player spawns, and keep the selected gravity applied
-- (a level change spawns a fresh WorldSettings with default gravity)
LoopAsync(250, function()
    ExecuteInGameThread(function()
        if not HasCapturedOriginals then
            CaptureOriginalsOnce()
        end
        if not ForceMaintainGravity or not HasCapturedOriginals then return end

        local worldSettings = UEHelpers.GetWorldSettings()
        if not worldSettings:IsValid() then return end

        local targetGravityZ = OriginalWorldGravityZ * CurrentGravityScale
        if not worldSettings.bGlobalGravitySet or math.abs(worldSettings.GlobalGravityZ - targetGravityZ) > 0.01 then
            if not DriftReported then
                print(string.format("[GravityMod] [Maintain] Gravity was reset (GlobalGravityZ=%.1f, bGlobalGravitySet=%s). Re-applying %.1f",
                    worldSettings.GlobalGravityZ, tostring(worldSettings.bGlobalGravitySet), targetGravityZ))
                DriftReported = true
            end
            SetWorldGravity(worldSettings, targetGravityZ, true, targetGravityZ)
        end
    end)
    return false
end)

-- Keybindings
-- F1 / Num 1: Restore Original Values
RegisterKeyBind(Key.F1, RestoreOriginals)
RegisterKeyBind(Key.NUM_ONE, RestoreOriginals)

-- F2 / Num 2: Low Gravity (0.25x)
RegisterKeyBind(Key.F2, function() ApplyGravity(0.25, "저중력 (Low 0.25x)") end)
RegisterKeyBind(Key.NUM_TWO, function() ApplyGravity(0.25, "저중력 (Low 0.25x)") end)

-- F3 / Num 3: Moon Gravity (0.08x)
RegisterKeyBind(Key.F3, function() ApplyGravity(0.08, "달 중력 (Moon 0.08x)") end)
RegisterKeyBind(Key.NUM_THREE, function() ApplyGravity(0.08, "달 중력 (Moon 0.08x)") end)

-- F4 / Num 4: Zero Gravity (0.0x)
RegisterKeyBind(Key.F4, function() ApplyGravity(0.0, "무중력 (Zero 0.0x)") end)
RegisterKeyBind(Key.NUM_FOUR, function() ApplyGravity(0.0, "무중력 (Zero 0.0x)") end)

-- F5 / Num 5: Float / Lift Up
RegisterKeyBind(Key.F5, function()
    ApplyGravity(0.05, "공중 부유 (Floating 0.05x)")
    TriggerFloatUp()
end)
RegisterKeyBind(Key.NUM_FIVE, function()
    ApplyGravity(0.05, "공중 부유 (Floating 0.05x)")
    TriggerFloatUp()
end)

-- Up Arrow: Upward thrust in Zero Gravity
RegisterKeyBind(Key.UP_ARROW, function()
    if ForceMaintainGravity and CurrentGravityScale <= 0.1 then
        ExecuteInGameThread(function()
            local player = UEHelpers.GetPlayer()
            if player:IsValid() and player.LaunchCharacter then
                player:LaunchCharacter({X = 0, Y = 0, Z = 400}, false, false)
            end
        end)
    end
end)

-- F6: Print Current Status
RegisterKeyBind(Key.F6, function()
    ExecuteInGameThread(function()
        local worldSettings = UEHelpers.GetWorldSettings()
        local player = UEHelpers.GetPlayer()
        print("\n[GravityMod] Current Status:")
        print(string.format("  Mode: %s (ForceMaintain: %s)", CurrentModeName, tostring(ForceMaintainGravity)))
        if worldSettings:IsValid() then
            print(string.format("  WorldSettings.WorldGravityZ:  %.1f", worldSettings.WorldGravityZ))
            print(string.format("  WorldSettings.GlobalGravityZ: %.1f (bGlobalGravitySet=%s)",
                worldSettings.GlobalGravityZ, tostring(worldSettings.bGlobalGravitySet)))
        end
        local movement = GetPlayerMovement(player)
        if movement then
            print(string.format("  CharacterMovement.GravityScale:  %.2f", movement.GravityScale))
            print(string.format("  CharacterMovement.GetGravityZ(): %.1f  <- actual gravity on the player", movement:GetGravityZ()))
            print(string.format("  CharacterMovement.JumpZVelocity: %.1f", movement.JumpZVelocity))
        end
        print("======================================\n")
    end)
end)

print("[GravityMod] Loaded! 단축키:")
print("  - [F1] / [Num 1]: 원래 값으로 완전 복구 (Restore Original Defaults)")
print("  - [F2] / [Num 2]: 저중력 (0.25x)")
print("  - [F3] / [Num 3]: 달 중력 (0.08x)")
print("  - [F4] / [Num 4]: 완전 무중력 (0.0x)")
print("  - [F5] / [Num 5]: 공중 부유 (Lift & Float, 0.05x)")
print("  - [F6]        : 현재 중력/물리 파라미터 상태 콘솔 출력")
