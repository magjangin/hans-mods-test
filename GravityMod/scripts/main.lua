local UEHelpers = require("UEHelpers")

print("==================================================")
print("[GravityMod] Hans Gravity Controller Mod Loading...")
print("==================================================")

-- How gravity reaches the player in UE:
--   CharacterMovement:GetGravityZ() = WorldSettings:GetGravityZ() * GravityScale
-- AWorldSettings::GetGravityZ() re-derives WorldGravityZ from GlobalGravityZ (when bGlobalGravitySet)
-- or the project DefaultGravityZ on each call in standalone, so writing WorldGravityZ alone does not
-- stick. The mode multiplier is applied once, through GlobalGravityZ, and GravityScale is left to the game.

local DEFAULT_GRAVITY_Z = -980.0

-- scale: multiplier relative to the original world gravity
-- launchZ: vertical velocity forced on the player right after switching (nil = keep current velocity)
local GravityModes = {
    { keys = { Key.F2, Key.NUM_TWO },   keyLabel = "[F2] / [Num 2]", scale = 0.25, name = "저중력 (Low 0.25x)" },
    { keys = { Key.F3, Key.NUM_THREE }, keyLabel = "[F3] / [Num 3]", scale = 0.08, name = "달 중력 (Moon 0.08x)" },
    -- Zero gravity: cancel vertical speed so the player floats instead of drifting down forever
    { keys = { Key.F4, Key.NUM_FOUR },  keyLabel = "[F4] / [Num 4]", scale = 0.0,  name = "무중력 (Zero 0.0x)", launchZ = 0 },
    -- Floating: lift the player up, then drift down slowly
    { keys = { Key.F5, Key.NUM_FIVE },  keyLabel = "[F5] / [Num 5]", scale = 0.05, name = "공중 부유 (Floating 0.05x)", launchZ = 750 },
}

local THRUST_Z = 400          -- Up Arrow impulse in (near) zero gravity
local THRUST_MAX_SCALE = 0.1  -- Up Arrow only works at or below this gravity scale

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

local function OriginalGravityZ()
    return OriginalWorldGravityZ or DEFAULT_GRAVITY_Z
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
        OriginalWorldGravityZ = (worldSettings.WorldGravityZ ~= 0.0) and worldSettings.WorldGravityZ or DEFAULT_GRAVITY_Z
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

--- Set the player's vertical velocity (adds to it when overrideZ is false). Game thread only.
local function LaunchPlayerUp(z, overrideZ)
    local player = UEHelpers.GetPlayer()
    if player:IsValid() and player.LaunchCharacter then
        player:LaunchCharacter({X = 0, Y = 0, Z = z}, false, overrideZ)
        return true
    end
    return false
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
    local originalEffective = OriginalGravityZ() * OriginalGravityScale
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
local function ApplyGravity(mode)
    CurrentGravityScale = mode.scale
    CurrentModeName = mode.name
    ForceMaintainGravity = true
    DriftReported = false

    ExecuteInGameThread(function()
        CaptureOriginalsOnce()

        local targetGravityZ = OriginalGravityZ() * mode.scale

        print("\n[GravityMod] ========================================")
        print(string.format("[GravityMod] Mode: [%s]", mode.name))
        print(string.format("[GravityMod] Scale: %.2fx | GlobalGravityZ: %.1f | GravityScale kept at game value",
            mode.scale, targetGravityZ))

        local worldSettings = UEHelpers.GetWorldSettings()
        if worldSettings:IsValid() then
            SetWorldGravity(worldSettings, targetGravityZ, true, targetGravityZ)
        else
            print("[GravityMod] [Warn] WorldSettings not found.")
        end

        if mode.launchZ and LaunchPlayerUp(mode.launchZ, true) then
            print(string.format("[GravityMod] [Launch] Vertical velocity set to %.0f", mode.launchZ))
        end

        print("[GravityMod] ========================================\n")
    end)
    VerifyAfterDelay()
end

local function PrintStatus()
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
local function BindKeys(keys, callback)
    for _, key in ipairs(keys) do
        RegisterKeyBind(key, callback)
    end
end

BindKeys({ Key.F1, Key.NUM_ONE }, RestoreOriginals)

for _, mode in ipairs(GravityModes) do
    BindKeys(mode.keys, function() ApplyGravity(mode) end)
end

-- Up Arrow: Upward thrust in (near) zero gravity
RegisterKeyBind(Key.UP_ARROW, function()
    if ForceMaintainGravity and CurrentGravityScale <= THRUST_MAX_SCALE then
        ExecuteInGameThread(function() LaunchPlayerUp(THRUST_Z, false) end)
    end
end)

RegisterKeyBind(Key.F6, function()
    ExecuteInGameThread(PrintStatus)
end)

print("[GravityMod] Loaded! 단축키:")
print("  - [F1] / [Num 1]: 원래 값으로 완전 복구 (Restore Original Defaults)")
for _, mode in ipairs(GravityModes) do
    print(string.format("  - %s: %s", mode.keyLabel, mode.name))
end
print("  - [F6]        : 현재 중력/물리 파라미터 상태 콘솔 출력")
