-- Full Circular Dash UI — Fixed mobile touch bugs + movable compact ad (collapse/expand)
-- Features:
--  • Smooth circular tween -> lands behind target
--  • Synced yaw-only aimlock
--  • Side animations + dash SFX
--  • Mobile-friendly dash button (only moves when you start dragging the button)
--  • Ads box: compact, draggable by title, collapsible, copy-link with fallback, round close
--  • PC/controller keybind (X) still supported

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace

-- REBIND ON RESPAWN
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
end)

-- CONFIG
local MAX_RANGE = 80
local ARC_APPROACH_RADIUS = 6
local BEHIND_DISTANCE = 4
local TOTAL_TIME = 0.22
local MIN_RADIUS = 1.2
local MAX_RADIUS = 14

-- ANIMS / SFX
local ANIM_LEFT_ID = 10480793962
local ANIM_RIGHT_ID = 10480796021
local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID  = "rbxassetid://72014632956520"
local DISCORD_LINK = "https://discord.gg/eJjXhEbmUD"

-- STATE
local busy = false
local aimlockConn = nil
local currentAnimTrack = nil

-- DASH SFX
local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2.0
dashSound.Looped = false
dashSound.Parent = workspace

-- HELPERS
local function shortestAngleDelta(target, current)
    local delta = target - current
    while delta > math.pi do delta = delta - 2*math.pi end
    while delta < -math.pi do delta = delta + 2*math.pi end
    return delta
end

local function easeOutCubic(t)
    t = math.clamp(t, 0, 1)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function ensureHumanoidAndAnimator()
    if not Character or not Character.Parent then return nil, nil end
    local hum = Character:FindFirstChildOfClass("Humanoid") or Character:FindFirstChild("Humanoid")
    if not hum then return nil, nil end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Name = "Animator"
        animator.Parent = hum
    end
    return hum, animator
end

-- play side animation + dash sfx
local function playSideAnimation(isLeft)
    pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
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
        dashSound:Stop()
        dashSound:Play()
    end)
    delay(TOTAL_TIME + 0.15, function()
        pcall(function() if track and track.IsPlaying then track:Stop() end end)
        pcall(function() anim:Destroy() end)
    end)
end

local function getAimPart(target)
    if not target then return nil end
    if target:FindFirstChild("Head") and target.Head:IsA("BasePart") then return target.Head end
    if target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart:IsA("BasePart") then return target.HumanoidRootPart end
    if target.PrimaryPart and target.PrimaryPart:IsA("BasePart") then return target.PrimaryPart end
    for _,v in pairs(target:GetChildren()) do if v:IsA("BasePart") then return v end end
    return nil
end

local function getNearestTarget(maxRange)
    maxRange = maxRange or MAX_RANGE
    local nearest, nearestDist = nil, math.huge
    if not HRP then return nil end
    local myPos = HRP.Position
    -- players
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") then
            local hum = pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos = pl.Character.HumanoidRootPart.Position
                local d = (pos - myPos).Magnitude
                if d < nearestDist and d <= maxRange then
                    nearestDist, nearest = d, pl.Character
                end
            end
        end
    end
    -- NPCs
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            local owner = Players:GetPlayerFromCharacter(obj)
            if not owner then
                local hum = obj:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local pos = obj.HumanoidRootPart.Position
                    local d = (pos - myPos).Magnitude
                    if d < nearestDist and d <= maxRange then
                        nearestDist, nearest = d, obj
                    end
                end
            end
        end
    end
    return nearest, nearestDist
end

-- SYNCED AIMLOCK (yaw only)
local function startAimlock(targetModel, dur)
    if not targetModel then return end
    local aimPart = getAimPart(targetModel)
    if not aimPart then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end
    dur = dur or TOTAL_TIME
    local startTime = tick()
    local startLook = cam.CFrame.LookVector
    local startPitch = math.asin(math.clamp(startLook.Y, -0.999, 0.999))
    local startYaw = math.atan2(startLook.Z, startLook.X)
    aimlockConn = RunService.Heartbeat:Connect(function()
        local t = math.clamp((tick() - startTime) / dur, 0, 1)
        local e = easeOutCubic(t)
        local camPos = cam.CFrame.Position
        local tgtPos = aimPart.Position
        local desiredYaw = math.atan2(tgtPos.Z - camPos.Z, tgtPos.X - camPos.X)
        local yawNow = startYaw + shortestAngleDelta(desiredYaw, startYaw) * e
        local cosP = math.cos(startPitch)
        pcall(function()
            cam.CFrame = CFrame.new(camPos, camPos + Vector3.new(math.cos(yawNow) * cosP, math.sin(startPitch), math.sin(yawNow) * cosP))
        end)
        if t >= 1 then
            if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end
        end
    end)
end

-- SMOOTH ARC TWEEN
local function smoothArcToBack(targetModel)
    if busy then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end
    busy = true
    if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end

    local targetHRP = targetModel.HumanoidRootPart
    local center = targetHRP.Position
    local myPos = HRP.Position
    local lookVec = targetHRP.CFrame.LookVector
    local finalPos = center - lookVec * BEHIND_DISTANCE
    finalPos = Vector3.new(finalPos.X, center.Y + 1.5, finalPos.Z)

    local startRadius = (Vector3.new(myPos.X, 0, myPos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
    local midRadius = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius = (Vector3.new(finalPos.X, 0, finalPos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude

    local startAngle = math.atan2(myPos.Z - center.Z, myPos.X - center.X)
    local endAngle = math.atan2(finalPos.Z - center.Z, finalPos.X - center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)
    local isLeft = (deltaAngle > 0)

    -- aimlock + side anim
    pcall(function() startAimlock(targetModel, TOTAL_TIME) end)
    pcall(function() playSideAnimation(isLeft) end)

    local startY = myPos.Y
    local endY = finalPos.Y
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local t = math.clamp((tick() - startTime) / TOTAL_TIME, 0, 1)
        local e = easeOutCubic(t)

        -- two-phase radius interpolation
        local midT = 0.5
        local radiusNow
        if t <= midT then
            radiusNow = startRadius + (midRadius - startRadius) * easeOutCubic(t / midT)
        else
            radiusNow = midRadius + (endRadius - midRadius) * easeOutCubic((t - midT) / (1 - midT))
        end
        radiusNow = math.clamp(radiusNow, MIN_RADIUS, MAX_RADIUS)

        local angleNow = startAngle + deltaAngle * e
        local x = center.X + radiusNow * math.cos(angleNow)
        local z = center.Z + radiusNow * math.sin(angleNow)
        local y = startY + (endY - startY) * e

        local posNow = Vector3.new(x, y, z)

        pcall(function()
            HRP.CFrame = CFrame.new(posNow, Vector3.new(center.X, posNow.Y, center.Z))
        end)

        if t >= 1 then
            conn:Disconnect()
            pcall(function() HRP.CFrame = CFrame.new(finalPos, finalPos + lookVec) end)
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
            busy = false
        end
    end)
end

-- UI CREATION (fixed touch handling + movable compact ads)
local function createUI()
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild("CircularTweenUI") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CircularTweenUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = game:GetService("CoreGui")

    -- tiny wait to help mobile executors initialize UI properly
    task.wait(0.03)

    -- DASH BUTTON (input tracked only when pressed on the button)
    local button = Instance.new("ImageButton")
    button.Name = "DashButton"
    button.Size = UDim2.new(0, 110, 0, 110)
    button.Position = UDim2.new(0.5, -55, 0.8, -55)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://99317918824094"
    button.Active = true
    button.Parent = screenGui

    local uiScale = Instance.new("UIScale", button)
    uiScale.Scale = 1
    local pressSound = Instance.new("Sound", button)
    pressSound.Name = "PressSFX"
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 0.9
    pressSound.Looped = false

    -- track only inputs that began on the button (prevents global touches from moving it)
    local trackedInput = nil
    local isDragging = false
    local pointerStartPos = nil
    local buttonStartPos = nil
    local dragThreshold = 12

    local function tweenUIScale(toScale, time)
        time = time or 0.06
        pcall(function()
            TweenService:Create(uiScale, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = toScale}):Play()
        end)
    end

    -- when input begins on the button
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            trackedInput = input
            isDragging = false
            pointerStartPos = input.Position
            buttonStartPos = button.Position
            tweenUIScale(0.92)
            pcall(function() pressSound:Play() end)
        end
    end)

    -- update pointer only for the tracked input
    UserInputService.InputChanged:Connect(function(input)
        if not trackedInput then return end
        if input ~= trackedInput then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - pointerStartPos
        if not isDragging and delta.Magnitude >= dragThreshold then
            isDragging = true
            tweenUIScale(1)
        end
        if isDragging then
            local cam = workspace.CurrentCamera
            local newX = buttonStartPos.X.Offset + delta.X
            local newY = buttonStartPos.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, cam.ViewportSize.X - button.AbsoluteSize.X)
            newY = math.clamp(newY, 0, cam.ViewportSize.Y - button.AbsoluteSize.Y)
            button.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    -- only end/activate for the tracked input
    UserInputService.InputEnded:Connect(function(input)
        if not trackedInput then return end
        if input ~= trackedInput then return end
        -- if wasn't a drag -> activate; if drag -> just drop
        if not isDragging then
            -- activate dash
            local target = getNearestTarget(MAX_RANGE)
            if not target then
                pcall(function() button.ImageTransparency = 0.5 end)
                task.delay(0.5, function() pcall(function() button.ImageTransparency = 0 end) end)
            else
                pcall(function() button.ImageTransparency = 0.5 end)
                smoothArcToBack(target)
                -- restore when done
                spawn(function() while busy do RunService.Heartbeat:Wait() end pcall(function() button.ImageTransparency = 0 end) end)
            end
        end
        -- reset tracking
        trackedInput = nil
        isDragging = false
        pointerStartPos = nil
        buttonStartPos = nil
        tweenUIScale(1)
    end)

    -- KEYBINDS (PC/Controller)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
            local target = getNearestTarget(MAX_RANGE)
            if target then smoothArcToBack(target) end
        end
        if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonX then
            local target = getNearestTarget(MAX_RANGE)
            if target then smoothArcToBack(target) end
        end
    end)

    -- ADS BOX (compact + draggable title + collapse/expand)
    local adsFrame = Instance.new("Frame")
    adsFrame.Name = "MerebennieAdBox"
    adsFrame.Size = UDim2.new(0, 220, 0, 44) -- start compact (title-only)
    adsFrame.Position = UDim2.new(0.02, 0, 0.1, 0)
    adsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    adsFrame.BorderSizePixel = 0
    adsFrame.Parent = screenGui

    local adsCorner = Instance.new("UICorner", adsFrame)
    adsCorner.CornerRadius = UDim.new(0, 10)

    -- title bar (also drag handle)
    local titleBar = Instance.new("Frame", adsFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 1

    local titleLabel = Instance.new("TextLabel", titleBar)
    titleLabel.Text = "Made by Merebennie"
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local collapseBtn = Instance.new("TextButton", titleBar)
    collapseBtn.Size = UDim2.new(0, 28, 0, 28)
    collapseBtn.Position = UDim2.new(1, -36, 0.5, -14)
    collapseBtn.AnchorPoint = Vector2.new(0, 0)
    collapseBtn.Text = "+"
    collapseBtn.Font = Enum.Font.SourceSansBold
    collapseBtn.TextSize = 18
    collapseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    local collapseCorner = Instance.new("UICorner", collapseBtn)
    collapseCorner.CornerRadius = UDim.new(0, 8)

    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -70, 0.5, -14)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 18
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 14)

    -- expanded contents (initially hidden)
    local expanded = Instance.new("Frame", adsFrame)
    expanded.Size = UDim2.new(1, 0, 0, 76)
    expanded.Position = UDim2.new(0, 0, 0, 44)
    expanded.BackgroundTransparency = 1
    expanded.Visible = false
    expanded.ClipsDescendants = true

    local desc = Instance.new("TextLabel", expanded)
    desc.Text = "This is Merebennie ads. Join our discord for more scripts!"
    desc.Font = Enum.Font.SourceSans
    desc.TextSize = 13
    desc.TextColor3 = Color3.fromRGB(220, 220, 220)
    desc.BackgroundTransparency = 1
    desc.Size = UDim2.new(1, -16, 0, 40)
    desc.Position = UDim2.new(0, 8, 0, 4)
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left

    local copyBtn = Instance.new("TextButton", expanded)
    copyBtn.Text = "Copy Link"
    copyBtn.Font = Enum.Font.SourceSansBold
    copyBtn.TextSize = 14
    copyBtn.Size = UDim2.new(0, 110, 0, 28)
    copyBtn.Position = UDim2.new(0, 8, 0, 46)
    copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    local copyCorner = Instance.new("UICorner", copyBtn)
    copyCorner.CornerRadius = UDim.new(0, 8)

    local feedback = Instance.new("TextLabel", expanded)
    feedback.Text = ""
    feedback.Font = Enum.Font.SourceSans
    feedback.TextSize = 12
    feedback.TextColor3 = Color3.fromRGB(160, 160, 160)
    feedback.BackgroundTransparency = 1
    feedback.Position = UDim2.new(0, 126, 0, 48)
    feedback.Size = UDim2.new(0, 86, 0, 20)
    feedback.TextXAlignment = Enum.TextXAlignment.Left

    -- collapse/expand toggle
    local isExpanded = false
    local function setExpanded(state)
        isExpanded = state
        if isExpanded then
            adsFrame:TweenSize(UDim2.new(0, 260, 0, 132), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
            expanded.Visible = true
            collapseBtn.Text = "-"
        else
            expanded.Visible = false
            adsFrame:TweenSize(UDim2.new(0, 220, 0, 44), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
            collapseBtn.Text = "+"
        end
    end
    setExpanded(false)

    -- copy button behaviour with fallback
    copyBtn.MouseButton1Click:Connect(function()
        local ok = false
        local success, err = pcall(function()
            if setclipboard then
                setclipboard(DISCORD_LINK)
            elseif syn and syn.set_clipboard then
                syn.set_clipboard(DISCORD_LINK)
            elseif set_clipboard then
                set_clipboard(DISCORD_LINK)
            else
                error("no clipboard")
            end
        end)
        if success then ok = true end
        if ok then
            feedback.Text = "Copied!"
            feedback.TextColor3 = Color3.fromRGB(120, 255, 140)
            task.delay(1.6, function() if feedback and feedback.Parent then feedback.Text = "" end end)
        else
            feedback.Text = "Unable to auto-copy"
            feedback.TextColor3 = Color3.fromRGB(255, 160, 120)
            copyBtn.Text = DISCORD_LINK
            task.delay(3, function() if copyBtn and copyBtn.Parent then copyBtn.Text = "Copy Link" end if feedback and feedback.Parent then feedback.Text = "" end end)
        end
    end)

    -- close button
    closeBtn.MouseButton1Click:Connect(function() pcall(function() screenGui:Destroy() end) end)

    -- titleBar dragging (so ads move separately and don't interfere with dash)
    local adTracked = nil
    local adDragging = false
    local adStart = nil
    local adPosStart = nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            adTracked = inp
            adDragging = false
            adStart = inp.Position
            adPosStart = adsFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not adTracked then return end
        if inp ~= adTracked then return end
        local delta = inp.Position - adStart
        if not adDragging and delta.Magnitude >= 8 then adDragging = true end
        if adDragging then
            local cam = workspace.CurrentCamera
            local newX = adPosStart.X.Offset + delta.X
            local newY = adPosStart.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, cam.ViewportSize.X - adsFrame.AbsoluteSize.X)
            newY = math.clamp(newY, 0, cam.ViewportSize.Y - adsFrame.AbsoluteSize.Y)
            adsFrame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if adTracked and inp == adTracked then adTracked = nil adDragging = false adStart = nil adPosStart = nil end
    end)

    -- collapse button toggles
    collapseBtn.MouseButton1Click:Connect(function() setExpanded(not isExpanded) end)
end

createUI()
print("[CircularDashUI] Ready — fixed touch behavior. Dash button only moves when you drag it; ads are draggable and compact.")