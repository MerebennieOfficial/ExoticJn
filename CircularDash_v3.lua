
-- CircularDash v3 — 540° (360 + 180) orbit, yaw-only aim smoothing, AutoRotate guard + aimlock control
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace
local Camera = workspace.CurrentCamera

math.randomseed(tick() % 65536)

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:FindFirstChildOfClass("Humanoid")
end)

-- ===== GAME-SPECIFIC ANIMATION SETUP =====
local placeId = game.PlaceId
local AnimationSets = {
    [10449761463] = { -- The Strongest Battlegrounds (Game A)
     Left  = 10480796021,
     Right = 10480793962,
    },
    [13076380114] = { -- MOVES Heroes Battlegrounds (Game B)
     Left  = 101843860692381,
     Right = 100087324592640,
    },
}

local DefaultSet = AnimationSets[13076380114] -- fallback to Game B set
local CurrentSet = AnimationSets[placeId] or DefaultSet

local ANIM_LEFT_ID  = CurrentSet.Left
local ANIM_RIGHT_ID = CurrentSet.Right

-- ===== CONFIG (kept fast settings) =====
local MAX_RANGE            = 40
local ORBIT_RADIUS_MIN     = 4
local ORBIT_RADIUS_MAX     = 5
local TOTAL_TIME           = 0.45  -- orbit duration (faster spin)
local COOLDOWN             = 2
local MIN_RADIUS           = 1.2
local MAX_RADIUS           = 60

local STRAIGHT_START_DIST  = 15
local ORBIT_TRIGGER_DIST   = 10
local STRAIGHT_SPEED       = 150 -- studs/sec

-- Aim smoothing (applies to both character yaw & camera yaw while aimlockActive)
local AimSpeed = 0.7 -- snappier

local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID  = "rbxassetid://72014632956520"

-- Extra values you specified for the alternate aimlock helper
local speedN = 0.3
local duration = 0.3

local busy = false
local currentAnimTrack = nil
local lastActivated = -math.huge

local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2.0
dashSound.Looped = false
dashSound.Parent = workspace

-- HELPERS
local function shortestAngleDelta(target, current)
    local delta = target - current
    while delta > math.pi do delta = delta - 2 * math.pi end
    while delta < -math.pi do delta = delta + 2 * math.pi end
    return delta
end

local function easeOutCubic(t)
    t = math.clamp(t, 0, 1)
    return 1 - (1 - t) ^ 3
end

local function ensureHumanoidAndAnimator()
    if not Character or not Character.Parent then return nil, nil end
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, nil end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Name = "Animator"
        animator.Parent = hum
    end
    return hum, animator
end

-- Plays the chosen side animation (uses current game set)
local function playSideAnimation(isLeft)
    pcall(function()
        if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
    end)
    currentAnimTrack = nil
    local hum, animator = ensureHumanoidAndAnimator()
    if not hum or not animator then return end
    local animId = isLeft and ANIM_LEFT_ID or ANIM_RIGHT_ID
    local anim = Instance.new("Animation")
    anim.Name = "CircularSideAnim"
    anim.AnimationId = "rbxassetid://" .. tostring(animId)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then anim:Destroy() return end
    currentAnimTrack = track
    track.Priority = Enum.AnimationPriority.Action
    track:Play()
    pcall(function()
        if dashSound and dashSound.Parent then dashSound:Stop() dashSound:Play() end
    end)
    delay(TOTAL_TIME + 0.15, function()
        pcall(function() if track and track.IsPlaying then track:Stop() end end)
        pcall(function() anim:Destroy() end)
    end)
end

local function getNearestTarget(maxRange)
    maxRange = maxRange or MAX_RANGE
    local nearest, nearestDist = nil, math.huge
    if not HRP then return nil end
    local myPos = HRP.Position
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") then
            local hum = pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos = pl.Character.HumanoidRootPart.Position
                local d = (pos - myPos).Magnitude
                if d < nearestDist and d <= maxRange then nearestDist, nearest = d, pl.Character end
            end
        end
    end
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            local owner = Players:GetPlayerFromCharacter(obj)
            if not owner then
                local hum = obj:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local pos = obj.HumanoidRootPart.Position
                    local d = (pos - myPos).Magnitude
                    if d < nearestDist and d <= maxRange then nearestDist, nearest = d, obj end
                end
            end
        end
    end
    return nearest, nearestDist
end

-- STRAIGHT DASH PHASE (follows target until within ORBIT_TRIGGER_DIST)
local function dashStraightToTarget(targetHRP)
    local attach = Instance.new("Attachment")
    attach.Name = "DashAttach"
    attach.Parent = HRP

    local lv = Instance.new("LinearVelocity")
    lv.Name = "DashLinearVelocity"
    lv.Attachment0 = attach
    lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = HRP

    local reached = false
    local alive = true
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not alive then return end
        if not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent then
            alive = false
            conn:Disconnect()
            pcall(function() lv:Destroy() end)
            pcall(function() attach:Destroy() end)
            return
        end
        local targetPos = targetHRP.Position
        local direction = (targetPos - HRP.Position)
        local flat = Vector3.new(direction.X, 0, direction.Z)
        local dist = flat.Magnitude
        if dist <= ORBIT_TRIGGER_DIST then
            reached = true
            alive = false
            conn:Disconnect()
            pcall(function() lv:Destroy() end)
            pcall(function() attach:Destroy() end)
            return
        end
        -- follow the moving target
        local velocity = (flat.Unit) * STRAIGHT_SPEED
        lv.VectorVelocity = velocity

        -- Face direction while dashing (yaw only)
        pcall(function()
            if flat.Magnitude > 0.001 then
                HRP.CFrame = CFrame.new(HRP.Position, HRP.Position + flat.Unit)
            end
        end)
    end)

    repeat task.wait() until reached or not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent
end

-- Provided aimlock function (adapted to be used smoothly inside orbit loop)
local function aimlockInstant(bruh)
    -- original behavior (instant) left intact in case needed elsewhere
    local dummy = game.Workspace.Live and game.Workspace.Live:FindFirstChild("Weakest Dummy")
    local cam = workspace.CurrentCamera
    if not cam then return end
    if bruh ~= nil and bruh == dummy then
        local vv = Vector3.new(
            bruh.HumanoidRootPart.CFrame.Position.X,
            cam.CFrame.Position.Y,
            bruh.HumanoidRootPart.CFrame.Position.Z
        )
        cam.CFrame = CFrame.new(cam.CFrame.Position, vv)
    elseif bruh ~= nil and bruh ~= dummy then
        local vv = Vector3.new(
            bruh.Character.HumanoidRootPart.CFrame.Position.X,
            cam.CFrame.Position.Y,
            bruh.Character.HumanoidRootPart.CFrame.Position.Z
        )
        cam.CFrame = CFrame.new(cam.CFrame.Position, vv)
    end
end

-- MAIN CIRCULAR DASH
local function smoothCircle540(targetModel)
    if busy then return end
    if tick() - lastActivated < COOLDOWN then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end

    busy = true

    -- IMMEDIATELY disable AutoRotate (first thing) and set up property guard
    local hum = Character:FindFirstChildOfClass("Humanoid")
    local prevAutoRotate = nil
    if hum then
        prevAutoRotate = hum.AutoRotate
        pcall(function() hum.AutoRotate = false end)
    end

    -- property-change guard to force AutoRotate off while silent == true
    local silent = true
    local autorotateConn = nil
    if hum then
        autorotateConn = hum:GetPropertyChangedSignal("AutoRotate"):Connect(function()
            if silent == true then
                if hum.AutoRotate == true then
                    -- re-disable immediately
                    pcall(function() hum.AutoRotate = false end)
                end
            end
        end)
    end

    -- Ensure we restore AutoRotate and cleanup
    local function safeRestoreAutoRotate()
        if autorotateConn then
            pcall(function() autorotateConn:Disconnect() end)
            autorotateConn = nil
        end
        if hum and prevAutoRotate ~= nil then
            -- disable the guard first so we can restore
            silent = false
            pcall(function() hum.AutoRotate = prevAutoRotate end)
        end
    end

    local targetHRP = targetModel.HumanoidRootPart
    local distance = (targetHRP.Position - HRP.Position).Magnitude

    -- FIRST: Straight dash if far away (AutoRotate is already disabled)
    if distance >= STRAIGHT_START_DIST then
        dashStraightToTarget(targetHRP)
    end

    -- If target disappeared, abort safely and restore AutoRotate
    if not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent then
        safeRestoreAutoRotate()
        busy = false
        return
    end

    -- orbit parameters (start from current positions)
    local initialCenter = targetHRP.Position
    local myPos = HRP.Position
    local lookVec = targetHRP.CFrame.LookVector

    local orbitRadius = ORBIT_RADIUS_MIN + (math.random() * (ORBIT_RADIUS_MAX - ORBIT_RADIUS_MIN))
    orbitRadius = math.clamp(orbitRadius, MIN_RADIUS, MAX_RADIUS)

    local startRadius = (Vector3.new(myPos.X, 0, myPos.Z) - Vector3.new(initialCenter.X, 0, initialCenter.Z)).Magnitude
    local startAngle = math.atan2(myPos.Z - initialCenter.Z, myPos.X - initialCenter.X)

    local desiredYaw = math.atan2(lookVec.Z, lookVec.X)
    local angleToDesired = shortestAngleDelta(desiredYaw, startAngle)
    local dir = angleToDesired >= 0 and 1 or -1

    local totalAngle = 3 * math.pi -- 540 degrees
    local isLeft = (dir > 0)

    -- Play side animation from the set chosen by PlaceId
    pcall(function() playSideAnimation(isLeft) end)

    -- ORBIT: perform circular motion while smoothing yaw to face target (character + camera)
    local startTime = tick()
    local conn
    local aimlockActive = true
    local restoredAutoRotate = false

    conn = RunService.Heartbeat:Connect(function()
        local now = tick()
        local t = math.clamp((now - startTime) / TOTAL_TIME, 0, 1)
        local e = easeOutCubic(t)
        local rT = math.clamp(t * 1.5, 0, 1)
        local radiusNow = startRadius + (orbitRadius - startRadius) * easeOutCubic(rT)
        radiusNow = math.clamp(radiusNow, MIN_RADIUS, MAX_RADIUS)
        local angleNow = startAngle + dir * totalAngle * easeOutCubic(t)

        local center = targetHRP.Position
        local centerY = center.Y
        local x = center.X + radiusNow * math.cos(angleNow)
        local z = center.Z + radiusNow * math.sin(angleNow)
        local posNow = Vector3.new(x, centerY, z)

        -- degrees covered so far (absolute)
        local degreesCovered = math.deg(math.abs(angleNow - startAngle))

        -- STOP aimlock at 520 degrees
        if degreesCovered >= 520 and aimlockActive then
            aimlockActive = false
            -- when aimlock stops, we simply stop forcing camera yaw — character may continue to be positioned
        end

        -- RESTORE AutoRotate at 530 degrees (but only once)
        if degreesCovered >= 530 and not restoredAutoRotate then
            restoredAutoRotate = true
            -- turn off guard before restoring so autorotate can actually be set
            silent = false
            pcall(function()
                if hum and prevAutoRotate ~= nil then hum.AutoRotate = prevAutoRotate end
            end)
            -- we can disconnect the autorotateConn now
            if autorotateConn then pcall(function() autorotateConn:Disconnect() end) autorotateConn = nil end
        end

        -- CHARACTER yaw smoothing (only while aimlockActive)
        pcall(function()
            if aimlockActive then
                local targetPos = targetHRP.Position
                local targetYaw = math.atan2((targetPos - posNow).Z, (targetPos - posNow).X)
                local currentYaw = math.atan2(HRP.CFrame.LookVector.Z, HRP.CFrame.LookVector.X)
                local deltaYaw = shortestAngleDelta(targetYaw, currentYaw)
                local yawNow = currentYaw + deltaYaw * AimSpeed -- smooth step toward target yaw
                HRP.CFrame = CFrame.new(posNow, posNow + Vector3.new(math.cos(yawNow), 0, math.sin(yawNow)))
            else
                -- still set position but don't force yaw (allow autorotate or other systems to control yaw)
                HRP.CFrame = CFrame.new(posNow, posNow + HRP.CFrame.LookVector)
            end
        end)

        -- CAMERA: yaw-only smoothing, preserve pitch (only while aimlockActive)
        pcall(function()
            if aimlockActive then
                local camPos = Camera.CFrame.Position
                local camLook = Camera.CFrame.LookVector
                local camTargetDir = (targetHRP.Position - camPos)
                local flatCamTarget = Vector3.new(camTargetDir.X, 0, camTargetDir.Z)
                if flatCamTarget.Magnitude < 0.001 then flatCamTarget = Vector3.new(1,0,0) end
                local flatUnit = flatCamTarget.Unit
                -- preserve camera pitch (Y component of look vector) and lerp horizontally
                local desiredCamLook = Vector3.new(flatUnit.X, camLook.Y, flatUnit.Z)
                if desiredCamLook.Magnitude < 0.001 then desiredCamLook = Vector3.new(flatUnit.X, camLook.Y, flatUnit.Z + 0.0001) end
                desiredCamLook = desiredCamLook.Unit
                -- use AimSpeed to smooth
                local newCamLook = camLook:Lerp(desiredCamLook, AimSpeed)
                if newCamLook.Magnitude < 0.001 then newCamLook = Vector3.new(desiredCamLook.X, camLook.Y, desiredCamLook.Z) end
                Camera.CFrame = CFrame.new(camPos, camPos + newCamLook.Unit)
            else
                -- aimlock stopped, do not force camera orientation anymore
            end
        end)

        if t >= 1 then
            conn:Disconnect()
            pcall(function()
                if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
                currentAnimTrack = nil
            end)

            -- final safety: ensure AutoRotate restored if not already
            if not restoredAutoRotate then
                safeRestoreAutoRotate()
            else
                -- already restored at 530°, so clean up autorotateConn if still present
                if autorotateConn then pcall(function() autorotateConn:Disconnect() end) autorotateConn = nil end
            end

            lastActivated = tick()
            busy = false
        end
    end)
end

-- UI CREATION (unchanged)
local function createUI()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("CircularTweenUI") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CircularTweenUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local button = Instance.new("ImageButton")
    button.Name = "DashButton"
    button.Size = UDim2.new(0,110,0,110)
    button.Position = UDim2.new(0.5,-55,0.8,-55)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://99317918824094"
    button.Active = true
    button.Parent = screenGui

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = button

    local pressSound = Instance.new("Sound")
    pressSound.Name = "PressSFX"
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 0.9
    pressSound.Looped = false
    pressSound.Parent = button

    local isPointerDown, isDragging, pointerStartPos, buttonStartPos, trackedInput = false,false,nil,nil,nil
    local dragThreshold = 8

    local function tweenUIScale(toScale,time)
        time = time or 0.06
        local ok, tw = pcall(function() return TweenService:Create(uiScale, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=toScale}) end)
        if ok and tw then tw:Play() end
    end

    local function startPointer(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPointerDown = true
            isDragging = false
            pointerStartPos = input.Position
            buttonStartPos = button.Position
            trackedInput = input
            tweenUIScale(0.92,0.06)
            pcall(function() pressSound:Play() end)
        end
    end

    local function updatePointer(input)
        if not isPointerDown or not pointerStartPos or input ~= trackedInput then return end
        local delta = input.Position - pointerStartPos
        if not isDragging and delta.Magnitude >= dragThreshold then
            isDragging = true
            tweenUIScale(1,0.06)
        end
        if isDragging then
            local screenW, screenH = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y
            local newX = buttonStartPos.X.Offset + delta.X
            local newY = buttonStartPos.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, screenW - button.AbsoluteSize.X)
            newY = math.clamp(newY, 0, screenH - button.AbsoluteSize.Y)
            button.Position = UDim2.new(0, newX, 0, newY)
        end
    end

    UserInputService.InputChanged:Connect(function(input) pcall(function() updatePointer(input) end) end)
    UserInputService.InputEnded:Connect(function(input)
        if input ~= trackedInput or not isPointerDown then return end
        if not isDragging and not busy and (tick() - lastActivated >= COOLDOWN) then
            local target = getNearestTarget(MAX_RANGE)
            if target then smoothCircle540(target) end
        end
        tweenUIScale(1,0.06)
        isPointerDown,isDragging,pointerStartPos,buttonStartPos,trackedInput = false,false,nil,nil,nil
    end)

    button.InputBegan:Connect(function(input) pcall(function() startPointer(input) end) end)
end

createUI()

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or busy then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X)
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonX)
    then
        if tick() - lastActivated < COOLDOWN then return end
        local target = getNearestTarget(MAX_RANGE)
        if target then smoothCircle540(target) end
    end
end)

print("[CircularTweenUI] Ready — PlaceId:", placeId, "Using AnimIDs:", ANIM_LEFT_ID, ANIM_RIGHT_ID, "540° spin & 520/530° aim/autorotate behavior.")
