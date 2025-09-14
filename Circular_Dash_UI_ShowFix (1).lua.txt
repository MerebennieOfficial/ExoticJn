-- Circular Dash UI — Fixes: parent fallback, visible fallback for button & ads, clamping, robust for mobile & PC
-- This version tries CoreGui first, then PlayerGui. Ensures button is visible even if image fails.
-- Also clamps both dash button and ads frame to viewport and prints debug info (visible in executor output).

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

-- CONFIG (tuned)
local MAX_RANGE = 80
local ARC_APPROACH_RADIUS = 8
local BEHIND_DISTANCE = 4
local TOTAL_TIME = 0.22
local MIN_RADIUS = 1.2
local MAX_RADIUS = 18

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
    pcall(function() dashSound:Stop() dashSound:Play() end)
    delay(TOTAL_TIME + 0.15, function() pcall(function() if track and track.IsPlaying then track:Stop() end end) pcall(function() anim:Destroy() end) end)
end

local function getAimPart(target)
    if not target then return nil end
    if target:FindFirstChild("Head") and target.Head:IsA("BasePart") then return target.Head end
    if target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart:IsA("BasePart") then return target.HumanoidRootPart end
    if target.PrimaryPart and target.PrimaryPart:IsA("BasePart") then return target.PrimaryPart end
    for _, v in pairs(target:GetChildren()) do if v:IsA("BasePart") then return v end end
    return nil
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
            if not Players:GetPlayerFromCharacter(obj) then
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

-- Aimlock: yaw-only
local function startAimlock(targetModel, dur)
    if not targetModel then return end
    local aimPart = getAimPart(targetModel)
    if not aimPart then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end
    dur = dur or TOTAL_TIME
    local startLook = cam.CFrame.LookVector
    local startPitch = math.asin(math.clamp(startLook.Y, -0.999, 0.999))
    local startYaw = math.atan2(startLook.Z, startLook.X)
    local startTime = tick()
    aimlockConn = RunService.Heartbeat:Connect(function()
        local t = math.clamp((tick() - startTime) / dur, 0, 1)
        local e = easeOutCubic(t)
        local camPos = cam.CFrame.Position
        local tgtPos = aimPart.Position
        local desiredYaw = math.atan2(tgtPos.Z - camPos.Z, tgtPos.X - camPos.X)
        local yawNow = startYaw + shortestAngleDelta(desiredYaw, startYaw) * e
        local cosP = math.cos(startPitch)
        local lookNow = Vector3.new(math.cos(yawNow) * cosP, math.sin(startPitch), math.sin(yawNow) * cosP)
        pcall(function() cam.CFrame = CFrame.new(camPos, camPos + lookNow) end)
        if t >= 1 then if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end end
    end)
end

-- Smooth arc
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

    pcall(function() startAimlock(targetModel, TOTAL_TIME) end)
    pcall(function() playSideAnimation(isLeft) end)

    local startY = myPos.Y
    local endY = finalPos.Y
    local startTime = tick()
    local conn
    local desiredYaw = math.atan2(lookVec.Z, lookVec.X)

    conn = RunService.Heartbeat:Connect(function()
        local t = math.clamp((tick() - startTime) / TOTAL_TIME, 0, 1)
        local e = easeOutCubic(t)

        local midT = 0.5
        local radiusNow
        if t <= midT then radiusNow = startRadius + (midRadius - startRadius) * easeOutCubic(t / midT)
        else radiusNow = midRadius + (endRadius - midRadius) * easeOutCubic((t - midT) / (1 - midT)) end
        radiusNow = math.clamp(radiusNow, MIN_RADIUS, MAX_RADIUS)

        local angleNow = startAngle + deltaAngle * e
        local x = center.X + radiusNow * math.cos(angleNow)
        local z = center.Z + radiusNow * math.sin(angleNow)
        local y = startY + (endY - startY) * e
        local posNow = Vector3.new(x, y, z)

        local hrpLook = Vector3.new(math.cos(desiredYaw), 0, math.sin(desiredYaw))
        pcall(function() HRP.CFrame = CFrame.new(posNow, posNow + hrpLook) end)

        if t >= 1 then conn:Disconnect() pcall(function() HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(lookVec.X, 0, lookVec.Z)) end) pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end) busy = false end
    end)
end

-- UI helper: choose a parent (CoreGui preferred, fallback to PlayerGui)
local function chooseGuiParent()
    local root = nil
    local success, err = pcall(function()
        root = game:GetService("CoreGui")
        -- test parenting: create temporary ScreenGui then destroy
        local tmp = Instance.new("ScreenGui")
        tmp.Name = "___tmpGuiCheck"
        tmp.ResetOnSpawn = false
        tmp.Parent = root
        tmp:Destroy()
    end)
    if success and root then
        return root, "CoreGui"
    else
        local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
        return pg, "PlayerGui"
    end
end

-- MAIN UI CREATION (polished)
local function createUI()
    -- cleanup
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild("CircularDashUI_Main") if old then old:Destroy() end end)
    local parent, parentName = chooseGuiParent()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CircularDashUI_Main"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = parent

    print("[CircularDashUI] Parent chosen:", parentName)

    -- small wait for viewport initialization
    task.wait(0.06)

    -- CONTAINER for dash button (so we can guarantee a visible background)
    local btnContainer = Instance.new("Frame", screenGui)
    btnContainer.Size = UDim2.new(0, 110, 0, 110)
    btnContainer.Position = UDim2.new(0.5, -55, 0.8, -55)
    btnContainer.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    btnContainer.BorderSizePixel = 0
    btnContainer.ZIndex = 2
    btnContainer.Name = "DashContainer"
    local btnCorner = Instance.new("UICorner", btnContainer) btnCorner.CornerRadius = UDim.new(0, 16)

    local button = Instance.new("ImageButton", btnContainer)
    button.Name = "DashButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.Position = UDim2.new(0, 0, 0, 0)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://99317918824094"
    button.AutoButtonColor = false
    button.ZIndex = 3

    local uiScale = Instance.new("UIScale", btnContainer)
    uiScale.Scale = 1

    local pressSound = Instance.new("Sound", btnContainer)
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 0.9

    -- clamp helper
    local function clampButtonToViewport()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vs = cam.ViewportSize
        local abs = btnContainer.AbsoluteSize
        local currentPos = btnContainer.Position
        local px = math.clamp(currentPos.X.Offset, 0, math.max(0, vs.X - abs.X))
        local py = math.clamp(currentPos.Y.Offset, 0, math.max(0, vs.Y - abs.Y))
        btnContainer.Position = UDim2.new(0, px, 0, py)
    end

    -- tap animation
    local function playTapAnim()
        pcall(function()
            TweenService:Create(uiScale, TweenInfo.new(0.06, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 0.88}):Play()
            task.delay(0.06, function() TweenService:Create(uiScale, TweenInfo.new(0.14, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Scale = 1.0}):Play() end)
        end)
    end

    -- track only touches that begin on the button (by tracking container InputBegan)
    local trackedInput = nil
    local isDragging = false
    local pointerStart = nil
    local containerStart = nil
    local dragThreshold = 12

    btnContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            trackedInput = input
            isDragging = false
            pointerStart = input.Position
            containerStart = btnContainer.Position
            playTapAnim()
            pcall(function() pressSound:Play() end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not trackedInput then return end
        if input ~= trackedInput then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - pointerStart
        if not isDragging and delta.Magnitude >= dragThreshold then isDragging = true end
        if isDragging then
            local cam = workspace.CurrentCamera
            local newX = containerStart.X.Offset + delta.X
            local newY = containerStart.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, cam.ViewportSize.X - btnContainer.AbsoluteSize.X)
            newY = math.clamp(newY, 0, cam.ViewportSize.Y - btnContainer.AbsoluteSize.Y)
            btnContainer.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not trackedInput then return end
        if input ~= trackedInput then return end
        if not isDragging then
            -- activate dash
            local target = getNearestTarget(MAX_RANGE)
            if not target then
                pcall(function() button.ImageTransparency = 0.5 end)
                task.delay(0.45, function() pcall(function() button.ImageTransparency = 0 end) end)
            else
                pcall(function() button.ImageTransparency = 0.5 end)
                smoothArcToBack(target)
                spawn(function() while busy do RunService.Heartbeat:Wait() end pcall(function() button.ImageTransparency = 0 end) end)
            end
        else
            clampButtonToViewport()
        end
        trackedInput = nil
        isDragging = false
        pointerStart = nil
        containerStart = nil
        pcall(function() TweenService:Create(uiScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
    end)

    -- KEYBINDS (PC & controller)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
            local target = getNearestTarget(MAX_RANGE) if target then smoothArcToBack(target) end
        end
        if (input.UserInputType == Enum.UserInputType.Gamepad1 or input.UserInputType == Enum.UserInputType.Gamepad2) and (input.KeyCode == Enum.KeyCode.ButtonX or input.KeyCode == Enum.KeyCode.ButtonSquare) then
            local target = getNearestTarget(MAX_RANGE) if target then smoothArcToBack(target) end
        end
    end)

    -- clamp on viewport size change
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() clampButtonToViewport() end)
    end

    -- ADS (white with black outline, draggable, compact)
    local adsFrame = Instance.new("Frame", screenGui)
    adsFrame.Name = "MerebennieAdBox"
    adsFrame.Size = UDim2.new(0, 260, 0, 44)
    adsFrame.Position = UDim2.new(0.02, 0, 0.06, 0)
    adsFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    adsFrame.BorderSizePixel = 0

    local adsCorner = Instance.new("UICorner", adsFrame)
    adsCorner.CornerRadius = UDim.new(0, 10)
    local adsStroke = Instance.new("UIStroke", adsFrame)
    adsStroke.Color = Color3.fromRGB(0, 0, 0)
    adsStroke.Thickness = 2

    local titleBar = Instance.new("Frame", adsFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundTransparency = 1

    local titleLabel = Instance.new("TextLabel", titleBar)
    titleLabel.Text = "Made by Merebennie"
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local controlsFrame = Instance.new("Frame", titleBar)
    controlsFrame.Size = UDim2.new(0.4, -8, 1, 0)
    controlsFrame.Position = UDim2.new(0.6, 0, 0, 0)
    controlsFrame.BackgroundTransparency = 1

    local collapseBtn = Instance.new("TextButton", controlsFrame)
    collapseBtn.Size = UDim2.new(0, 28, 0, 28)
    collapseBtn.Position = UDim2.new(1, -36, 0.5, -14)
    collapseBtn.Text = "+"
    collapseBtn.Font = Enum.Font.SourceSansBold
    collapseBtn.TextSize = 18
    collapseBtn.BackgroundColor3 = Color3.fromRGB(240,240,240)
    collapseBtn.TextColor3 = Color3.fromRGB(0,0,0)
    local collapseCorner = Instance.new("UICorner", collapseBtn) collapseCorner.CornerRadius = UDim.new(0,8)
    local collapseStroke = Instance.new("UIStroke", collapseBtn) collapseStroke.Color = Color3.fromRGB(0,0,0) collapseStroke.Thickness = 1

    local closeBtn = Instance.new("TextButton", controlsFrame)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -70, 0.5, -14)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 16
    closeBtn.BackgroundColor3 = Color3.fromRGB(220,60,60)
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    local closeCorner = Instance.new("UICorner", closeBtn) closeCorner.CornerRadius = UDim.new(0,12)
    local closeStroke = Instance.new("UIStroke", closeBtn) closeStroke.Color = Color3.fromRGB(0,0,0) closeStroke.Thickness = 1

    local expanded = Instance.new("Frame", adsFrame)
    expanded.Size = UDim2.new(1, 0, 0, 88)
    expanded.Position = UDim2.new(0, 0, 0, 44)
    expanded.BackgroundTransparency = 1
    expanded.Visible = false

    local descLabel = Instance.new("TextLabel", expanded)
    descLabel.Text = "This is Merebennie ads. Join our Discord for more scripts!"
    descLabel.Font = Enum.Font.SourceSans
    descLabel.TextSize = 13
    descLabel.TextColor3 = Color3.fromRGB(30,30,30)
    descLabel.BackgroundTransparency = 1
    descLabel.Size = UDim2.new(1, -16, 0, 40)
    descLabel.Position = UDim2.new(0, 8, 0, 6)
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left

    local copyBtn = Instance.new("TextButton", expanded)
    copyBtn.Text = "Copy Link"
    copyBtn.Font = Enum.Font.SourceSansBold
    copyBtn.TextSize = 14
    copyBtn.Size = UDim2.new(0, 120, 0, 30)
    copyBtn.Position = UDim2.new(0, 8, 0, 48)
    copyBtn.BackgroundColor3 = Color3.fromRGB(240,240,240)
    copyBtn.TextColor3 = Color3.fromRGB(0,0,0)
    local copyCorner = Instance.new("UICorner", copyBtn) copyCorner.CornerRadius = UDim.new(0,8)
    local copyStroke = Instance.new("UIStroke", copyBtn) copyStroke.Color = Color3.fromRGB(0,0,0) copyStroke.Thickness = 1

    local feedback = Instance.new("TextLabel", expanded)
    feedback.Text = ""
    feedback.Font = Enum.Font.SourceSans
    feedback.TextSize = 12
    feedback.TextColor3 = Color3.fromRGB(80,80,80)
    feedback.BackgroundTransparency = 1
    feedback.Position = UDim2.new(0, 132, 0, 52)
    feedback.Size = UDim2.new(0, 110, 0, 18)
    feedback.TextXAlignment = Enum.TextXAlignment.Left

    -- collapse logic
    local isExpanded = false
    local function setExpanded(state)
        isExpanded = state
        if isExpanded then
            adsFrame:TweenSize(UDim2.new(0, 280, 0, 132), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
            expanded.Visible = true
            collapseBtn.Text = "-"
        else
            expanded.Visible = false
            adsFrame:TweenSize(UDim2.new(0, 260, 0, 44), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
            collapseBtn.Text = "+"
        end
    end
    setExpanded(false)

    -- copy behavior
    copyBtn.MouseButton1Click:Connect(function()
        local ok = false
        local success, err = pcall(function()
            if setclipboard then setclipboard(DISCORD_LINK)
            elseif syn and syn.set_clipboard then syn.set_clipboard(DISCORD_LINK)
            elseif set_clipboard then set_clipboard(DISCORD_LINK)
            else error(\"no clipboard\") end
        end)
        if success then ok = true end
        if ok then feedback.Text = \"Copied!\" feedback.TextColor3 = Color3.fromRGB(40,160,40) task.delay(1.6, function() if feedback and feedback.Parent then feedback.Text = \"\" end end)
        else feedback.Text = \"Unable to auto-copy\" feedback.TextColor3 = Color3.fromRGB(160,40,40) copyBtn.Text = DISCORD_LINK task.delay(3, function() if copyBtn and copyBtn.Parent then copyBtn.Text = \"Copy Link\" end if feedback and feedback.Parent then feedback.Text = \"\" end end) end
    end)

    closeBtn.MouseButton1Click:Connect(function() pcall(function() screenGui:Destroy() end) end)

    -- drag for ads by titleBar
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
        if not adStart or not adPosStart then return end
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

    -- clamp initial positions
    pcall(function() clampButtonToViewport() end)
    pcall(function() local cam = workspace.CurrentCamera if cam then local vs = cam.ViewportSize local ax = math.clamp(adsFrame.Position.X.Offset, 0, math.max(0, vs.X - adsFrame.AbsoluteSize.X)) local ay = math.clamp(adsFrame.Position.Y.Offset, 0, math.max(0, vs.Y - adsFrame.AbsoluteSize.Y)) adsFrame.Position = UDim2.new(0, ax, 0, ay) end end)
end

createUI()
print(\"[CircularDashUI] Improved show-fix active. If UI still doesn't appear, try running from PlayerGui instead of CoreGui in your executor.\")