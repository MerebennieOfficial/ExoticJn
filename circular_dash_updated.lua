-- Circular dash script (UPDATED)
-- Features:
--  * Suppress Roblox walking animation only during the straight dash (attempts to stop movement-priority tracks and sets WalkSpeed = 0)
--  * If the player jumps while straight-moving, tween the HumanoidRootPart to the target's X/Z and to either the ground level at that X/Z or the target's Y (whichever is higher).
--  * Restores WalkSpeed and cleans up after the dash.

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
    [10449761463] = { -- The Strongest Battlegrounds
     Left  = 10480796021,
     Right = 10480793962,
    },
    [13076380114] = { -- MOVES Heroes Battlegrounds
     Left  = 101843860692381,
     Right = 100087324592640,
    },
}

local DefaultSet = AnimationSets[13076380114]
local CurrentSet = AnimationSets[placeId] or DefaultSet
local ANIM_LEFT_ID, ANIM_RIGHT_ID = CurrentSet.Left, CurrentSet.Right

-- ===== CONFIG =====
local MAX_RANGE = 40
local ORBIT_RADIUS_MIN, ORBIT_RADIUS_MAX = 4, 5
local TOTAL_TIME, COOLDOWN = 0.45, 2
local MIN_RADIUS, MAX_RADIUS = 1.2, 60
local STRAIGHT_START_DIST, ORBIT_TRIGGER_DIST = 15, 10
local STRAIGHT_SPEED = 120
local AimSpeed = 0.7

local POST_CAMERA_AIM_DURATION = 0.3 -- camera aimlock duration (seconds)
local POST_CAMERA_PREDICT_TIME = 0.4 -- seconds ahead to predict target movement for the post-spin aimlock
local POST_CAMERA_SNAPPINESS = 200     -- larger => snappier initial interpolation (use positive numbers)

-- TRIGGER: now set to 400 degrees (out of 480)
local AIMLOCK_TRIGGER_DEGREES = 400
local AIMLOCK_TRIGGER_FRACTION = AIMLOCK_TRIGGER_DEGREES / 480

local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID = "rbxassetid://72014632956520"

local busy, currentAnimTrack, lastActivated = false, nil, -math.huge

local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2.0
dashSound.Looped = false
dashSound.Parent = workspace

local silent = false
local autoRotateConn = nil

local function bindAutoRotateWatcher()
    if autoRotateConn then
        pcall(function() autoRotateConn:Disconnect() end)
        autoRotateConn = nil
    end
    local hum = Character and Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    autoRotateConn = hum:GetPropertyChangedSignal("AutoRotate"):Connect(function()
        if silent then
            pcall(function() if hum and hum.AutoRotate then hum.AutoRotate = false end end)
        end
    end)
end
bindAutoRotateWatcher()
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:FindFirstChildOfClass("Humanoid")
    task.wait(0.05)
    bindAutoRotateWatcher()
end)

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

local function playSideAnimation(isLeft)
    pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end end)
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
    pcall(function() dashSound:Stop() dashSound:Play() end)
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

-- CAMERA YAW smoothing helper (preserve pitch)
local function smoothFaceCameraTowards(targetPos, speed)
    speed = speed or AimSpeed
    pcall(function()
        local camPos = Camera.CFrame.Position
        local camLook = Camera.CFrame.LookVector
        local camTargetDir = (targetPos - camPos)
        local flatCamTarget = Vector3.new(camTargetDir.X, 0, camTargetDir.Z)
        if flatCamTarget.Magnitude < 0.001 then flatCamTarget = Vector3.new(1,0,0) end
        local flatUnit = flatCamTarget.Unit
        local desiredCamLook = Vector3.new(flatUnit.X, camLook.Y, flatUnit.Z)
        if desiredCamLook.Magnitude < 0.001 then desiredCamLook = Vector3.new(flatUnit.X, camLook.Y, flatUnit.Z + 0.0001) end
        desiredCamLook = desiredCamLook.Unit
        local newCamLook = camLook:Lerp(desiredCamLook, speed)
        if newCamLook.Magnitude < 0.001 then newCamLook = Vector3.new(desiredCamLook.X, camLook.Y, desiredCamLook.Z) end
        Camera.CFrame = CFrame.new(camPos, camPos + newCamLook.Unit)
    end)
end

-- STRAIGHT DASH PHASE (follows target until within ORBIT_TRIGGER_DIST)
-- Modifications:
--  - suppress humanoid walking animation by setting Humanoid.WalkSpeed = 0 during the dash (restored after)
--  - attempt to stop movement-priority animation tracks while dashing, and later allow Humanoid to resume normal behavior
--  - if player jumps while straight-moving, tween HRP to the enemy's X/Z at the higher of (enemy's Y, ground Y at that XZ)
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

    -- suppress walking animation
    local hum = Character and Character:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    local prevWalkSpeed = nil
    local stoppedTracks = {}
    if hum then
        prevWalkSpeed = hum.WalkSpeed
        pcall(function() hum.WalkSpeed = 0 end)
        -- attempt to stop movement-priority tracks (walk/run) so the visual walking anim is suppressed
        if animator then
            pcall(function()
                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                    local ok, pri = pcall(function() return t.Priority end)
                    local name = ""
                    pcall(function() name = t.Name or "" end)
                    local animId = ""
                    pcall(function() if t.Animation then animId = tostring(t.Animation.AnimationId) end end)
                    -- heuristics: stop tracks that are Movement priority or whose name suggests movement
                    if (ok and pri == Enum.AnimationPriority.Movement) or string.find(string.lower(name), "walk") or string.find(string.lower(name), "run") or string.find(animId, "walk") or string.find(animId, "run") then
                        pcall(function() t:Stop() end)
                        table.insert(stoppedTracks, {name = name, animId = animId})
                    end
                end
            end)
        end
    end

    local reached = false
    local alive = true
    local conn
    local jumpConn
    local jumpedHandled = false

    -- helper to cleanup lv and attachment safely
    local function cleanupLV()
        pcall(function() if conn and conn.Connected then conn:Disconnect() end end)
        pcall(function() if jumpConn and jumpConn.Connected then jumpConn:Disconnect() end end)
        pcall(function() lv:Destroy() end)
        pcall(function() attach:Destroy() end)
    end

    -- function to find ground Y at a given X/Z position (raycast downward)
    local function findGroundYAt(xzPosition)
        local origin = Vector3.new(xzPosition.X, xzPosition.Y + 50, xzPosition.Z)
        local direction = Vector3.new(0, -200, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {Character}
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        local result = workspace:Raycast(origin, direction, rayParams)
        if result and result.Position then
            return result.Position.Y
        end
        return nil
    end

    -- handle jump: tween to enemy position at enemy's or ground Y-level, then end the straight dash
    local function onJump()
        if jumpedHandled then return end
        jumpedHandled = true
        alive = false
        -- stop the heartbeat follow first
        pcall(function() if conn and conn.Connected then conn:Disconnect() end end)

        -- destroy the linear velocity so tween can move HRP cleanly
        pcall(function() lv:Destroy() end)
        pcall(function() attach:Destroy() end)

        -- choose destination: enemy's X/Z, choose Y as max(enemy Y, ground at that X/Z)
        local targetPos = targetHRP and targetHRP.Position or HRP.Position
        local groundY = findGroundYAt(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)) or targetPos.Y
        local destY = math.max(targetPos.Y, groundY)
        local dest = Vector3.new(targetPos.X, destY, targetPos.Z)

        -- build orientation: look at the target
        local lookAt = targetPos
        local destCFrame
        pcall(function()
            if (dest - lookAt).Magnitude < 0.001 then
                destCFrame = CFrame.new(dest)
            else
                destCFrame = CFrame.new(dest, lookAt)
            end
        end)

        -- tween HRP to destination smoothly
        local tweenTime = 0.225
        local ok, tw = pcall(function()
            return TweenService:Create(HRP, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = destCFrame})
        end)
        if ok and tw then
            local completedConn
            tw:Play()
            completedConn = tw.Completed:Connect(function()
                pcall(function() if completedConn and completedConn.Connected then completedConn:Disconnect() end end)
                -- restore walk speed
                if hum and prevWalkSpeed ~= nil then
                    pcall(function() hum.WalkSpeed = prevWalkSpeed end)
                end
                reached = true
            end)
        else
            -- if tween creation failed, fallback: teleport and restore
            pcall(function() HRP.CFrame = destCFrame end)
            if hum and prevWalkSpeed ~= nil then
                pcall(function() hum.WalkSpeed = prevWalkSpeed end)
            end
            reached = true
        end
    end

    -- connect jump event (if humanoid present)
    if hum then
        jumpConn = hum.Jumping:Connect(function(active)
            if active then
                pcall(onJump)
            end
        end)
    end

    conn = RunService.Heartbeat:Connect(function()
        if not alive then return end
        if not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent then
            alive = false
            conn:Disconnect()
            pcall(function() lv:Destroy() end)
            pcall(function() attach:Destroy() end)
            -- restore walk speed
            if hum and prevWalkSpeed ~= nil then
                pcall(function() hum.WalkSpeed = prevWalkSpeed end)
            end
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
            -- restore walk speed
            if hum and prevWalkSpeed ~= nil then
                pcall(function() hum.WalkSpeed = prevWalkSpeed end)
            end
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

        -- Smooth camera yaw to face the target while dashing (preserve pitch)
        pcall(function()
            smoothFaceCameraTowards(targetPos, AimSpeed * 0.8) -- slightly gentler during dash
        end)
    end)

    -- wait until reached (either normal or via jump tween)
    repeat task.wait() until reached or not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent

    -- cleanup connections if anything left
    pcall(function() if jumpConn and jumpConn.Connected then jumpConn:Disconnect() end end)
    pcall(function() if conn and conn.Connected then conn:Disconnect() end end)
    -- ensure linear velocity/attachment cleaned
    pcall(function() if lv and lv.Parent then lv:Destroy() end end)
    pcall(function() if attach and attach.Parent then attach:Destroy() end end)
    -- final restore walk speed
    if hum and prevWalkSpeed ~= nil then
        pcall(function() hum.WalkSpeed = prevWalkSpeed end)
    end
end

-- CAMERA-only aimlock for a short duration after spin (UPDATED: SNAPPY + PREDICTION)
local function postSpinCameraAimlock(targetHRP, duration)
    if not targetHRP or not targetHRP.Parent then return end
    duration = duration or POST_CAMERA_AIM_DURATION
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not targetHRP or not targetHRP.Parent then
            conn:Disconnect()
            return
        end
        local now = tick()
        local t = math.clamp((now - startTime) / duration, 0, 1)
        -- Snappy interpolation: emphasizes early convergence for a quick "snap" feel
        local e = 1 - (1 - t) ^ math.max(1, POST_CAMERA_SNAPPINESS)

        -- Predict target position ahead along its velocity (XZ-plane only) to lead the aim
        local targetPos = targetHRP.Position
        local vel = Vector3.new(0,0,0)
        pcall(function() vel = targetHRP:GetVelocity() or targetHRP.Velocity or Vector3.new(0,0,0) end)
        -- Use only horizontal velocity for prediction to keep pitch natural
        local flatVel = Vector3.new(vel.X, 0, vel.Z)
        local predictedPos = targetPos + flatVel * POST_CAMERA_PREDICT_TIME

        -- preserve pitch: smoothly lerp camera's horizontal look vector toward predicted target flat direction
        pcall(function()
            local camPos = Camera.CFrame.Position
            local camLook = Camera.CFrame.LookVector
            local targetDir = (predictedPos - camPos)
            local flat = Vector3.new(targetDir.X, 0, targetDir.Z)
            if flat.Magnitude < 0.001 then flat = Vector3.new(1,0,0) end
            local desiredFlat = flat.Unit
            local desiredCamLook = Vector3.new(desiredFlat.X, camLook.Y, desiredFlat.Z).Unit
            local newCamLook = camLook:Lerp(desiredCamLook, e)
            Camera.CFrame = CFrame.new(camPos, camPos + newCamLook)
        end)

        if t >= 1 then
            conn:Disconnect()
            return
        end
    end)
end

-- MAIN CIRCULAR DASH (unchanged aside from using updated dashStraightToTarget)
local function smoothCircle480_then_cameraAim(targetModel)
    if busy then return end
    if tick() - lastActivated < COOLDOWN then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end

    busy = true

    local hum = Character:FindFirstChildOfClass("Humanoid")
    local prevAutoRotate = nil
    if hum then
        prevAutoRotate = hum.AutoRotate
        silent = true
        pcall(function() hum.AutoRotate = false end)
    end

    local function safeRestoreAutoRotate()
        if hum and prevAutoRotate ~= nil then
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

    -- orbit parameters
    local initialCenter = targetHRP.Position
    local myPos = HRP.Position
    local orbitRadius = ORBIT_RADIUS_MIN + (math.random() * (ORBIT_RADIUS_MAX - ORBIT_RADIUS_MIN))
    orbitRadius = math.clamp(orbitRadius, MIN_RADIUS, MAX_RADIUS)

    -- Determine side automatically (nearest left or right)
    local rightVec = HRP.CFrame.RightVector
    local targetDir = (targetHRP.Position - HRP.Position)
    if targetDir.Magnitude < 0.001 then targetDir = HRP.CFrame.LookVector end
    local dotRight = rightVec:Dot(targetDir.Unit)
    -- if dotRight < 0 => target is to the left (since RightVector dot targetDir negative), choose left
    local isLeft = dotRight < 0

    playSideAnimation(isLeft)

    -- total angle set to 360 + 120 = 480 degrees -> radians:
    local totalAngle = math.rad(480)
    local dir = isLeft and 1 or -1

    local startAngle = math.atan2(myPos.Z - initialCenter.Z, myPos.X - initialCenter.X)
    local startRadius = (Vector3.new(myPos.X,0,myPos.Z) - Vector3.new(initialCenter.X,0,initialCenter.Z)).Magnitude

    local startTime = tick()
    local conn

    -- NEW FLAGS for handling early aimlock at 400°
    local aimlockTriggered = false
    local aimlockRestoreScheduled = false
    local aimlockEnded = false
    local spinEnded = false

    local function scheduleAimlockRestore()
        if aimlockRestoreScheduled then return end
        aimlockRestoreScheduled = true
        task.delay(POST_CAMERA_AIM_DURATION, function()
            aimlockEnded = true
            -- restore AutoRotate only after aimlock window
            safeRestoreAutoRotate()
            lastActivated = tick()
            -- only clear busy once both spin finished and aimlock ended
            if spinEnded then
                busy = false
            end
        end)
    end

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

        -- CHARACTER yaw smoothing (character-only)
        local targetPos = (targetHRP and targetHRP.Position) or center
        local targetYaw = math.atan2((targetPos - posNow).Z, (targetPos - posNow).X)
        local currentYaw = math.atan2(HRP.CFrame.LookVector.Z, HRP.CFrame.LookVector.X)
        local deltaYaw = shortestAngleDelta(targetYaw, currentYaw)
        local yawNow = currentYaw + deltaYaw * AimSpeed
        pcall(function()
            HRP.CFrame = CFrame.new(posNow, posNow + Vector3.new(math.cos(yawNow), 0, math.sin(yawNow)))
        end)

        -- TRIGGER: when eased fraction reaches the AIMLOCK_TRIGGER_FRACTION, start camera aimlock early
        if not aimlockTriggered then
            if e >= AIMLOCK_TRIGGER_FRACTION then
                aimlockTriggered = true
                -- start the camera-only aimlock window immediately
                pcall(function()
                    postSpinCameraAimlock(targetHRP, POST_CAMERA_AIM_DURATION)
                end)
                -- schedule AutoRotate restore and busy-clear only after the aimlock ends (handled in scheduleAimlockRestore)
                scheduleAimlockRestore()
            end
        end

        -- IMPORTANT: DO NOT modify camera during main spin (character-only aimlock)
        -- when spin completes:
        if t >= 1 then
            conn:Disconnect()
            pcall(function()
                if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
                currentAnimTrack = nil
            end)

            -- If aimlock wasn't triggered earlier (i.e. we never hit the threshold),
            -- start it now (this matches prior behavior).
            if not aimlockTriggered then
                aimlockTriggered = true
                pcall(function()
                    postSpinCameraAimlock(targetHRP, POST_CAMERA_AIM_DURATION)
                end)
                scheduleAimlockRestore()
            end

            -- Mark spin ended. busy will be cleared by the scheduled restore if it hasn't ended yet.
            spinEnded = true
            -- If the aimlock already ended (rare if it finished before spin), clear busy now
            if aimlockEnded then
                busy = false
            end
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
    button.Parent = screenGui

    local uiScale = Instance.new("UIScale", button)
    uiScale.Scale = 1

    local pressSound = Instance.new("Sound")
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 1
    pressSound.Parent = button

    button.MouseButton1Click:Connect(function()
        pcall(function() pressSound:Play() end)
        local target = getNearestTarget(MAX_RANGE)
        if target then
            smoothCircle480_then_cameraAim(target)
        end
    end)
end

createUI()
