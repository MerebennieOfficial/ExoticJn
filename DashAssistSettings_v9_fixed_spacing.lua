
-- DashAssistSettings_v9_fixed_spacing.lua
-- Updated to match the original DashAssistSettings_v8 layout/spacing, but with:
--  * M1 Delay textbox below "Find nearest" control
--  * Alternating front/back dash logic (if you're behind the target go to front, if in front go to back)
--  * Dot-style ON/OFF indicators (white when ON, transparent when OFF)
--  * Kept mobile compatibility helpers and original behaviors
--  * Fixes: spacing between buttons so they no longer stick together (pixel-based layout)

-- LANGUAGE: Lua (Delta mobile compatible)
-- NOTE: Drop this file into Delta executor or run as a loadstring. Designed to be mobile-friendly.

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace

-- Safe GUI parenting helper
local function safeSetParent(gui)
    local success = false
    pcall(function() gui.Parent = gethui() success = gui.Parent ~= nil end)
    if success then return end
    pcall(function() gui.Parent = get_hidden_gui() success = gui.Parent ~= nil end)
    if success then return end
    pcall(function() gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui") end)
end

-- REBIND ON RESPAWN
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
end)

-- CONFIG / SFX / STATE
local ARC_APPROACH_RADIUS  = 8
local BEHIND_DISTANCE      = 4
local TOTAL_TIME           = 0.22
local MIN_RADIUS           = 1.2
local MAX_RADIUS           = 14
local ACTIVATION_RANGE     = 35

local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID  = "rbxassetid://72014632956520"

local busy = false
local currentAnimTrack = nil
local dashSound = Instance.new("Sound")
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2
dashSound.Looped = false
dashSound.Parent = workspace

-- M1 after tween
local m1AfterTween = true
local m1DelayValue = 0.1

local findNearestEnabled = true
local selectedPlayer = nil
local espEnabled = false
local currentHighlight = nil

-- persisted data
local dataFolder = LocalPlayer:FindFirstChild("DashAssistSettingsData")
if not dataFolder then
    dataFolder = Instance.new("Folder", LocalPlayer)
    dataFolder.Name = "DashAssistSettingsData"
end

local function shortestAngleDelta(target, current)
    local delta = target - current
    while delta > math.pi do delta = delta - 2*math.pi end
    while delta < -math.pi do delta = delta + 2*math.pi end
    return delta
end

local function easeOutCubic(t)
    t = math.clamp(t, 0, 1)
    return 1 - (1 - t)^3
end

local function ensureHumanoidAndAnimator()
    if not Character or not Character.Parent then return nil, nil end
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, nil end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    return hum, animator
end

local function playSideAnimation(isLeft)
    pcall(function()
        if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
        currentAnimTrack = nil
    end)
    local hum, animator = ensureHumanoidAndAnimator()
    if not hum or not animator then return end
    local animId = isLeft and 10480796021 or 10480793962
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(animId)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        currentAnimTrack = track
        track.Priority = Enum.AnimationPriority.Action
        track:Play()
        pcall(function() dashSound:Stop() dashSound:Play() end)
        delay(TOTAL_TIME + 0.15, function()
            pcall(function() if track and track.IsPlaying then track:Stop() end anim:Destroy() end)
        end)
    else
        pcall(function() anim:Destroy() end)
    end
end

local function getNearestTarget(maxRange)
    maxRange = maxRange or 80
    local nearest, nearestDist = nil, math.huge
    if not HRP then return nil end
    local myPos = HRP.Position
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local pos = pl.Character.HumanoidRootPart.Position
                local d = (pos - myPos).Magnitude
                if d < nearestDist and d <= maxRange then nearestDist, nearest = d, pl.Character end
            end
        end
    end
    return nearest, nearestDist
end

local function clearHighlight()
    if currentHighlight then
        pcall(function() currentHighlight:Destroy() end)
        currentHighlight = nil
    end
end

local function updateESP(settingsVisible)
    clearHighlight()
    if not espEnabled then return end
    if settingsVisible then return end
    local targetModel = nil
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        targetModel = selectedPlayer.Character
    else
        local t, d = getNearestTarget(ACTIVATION_RANGE)
        if t then targetModel = t end
    end
    if targetModel and targetModel:FindFirstChild("HumanoidRootPart") then
        local ok, h = pcall(function()
            local highlight = Instance.new("Highlight")
            highlight.Adornee = targetModel
            highlight.Parent = workspace
            highlight.FillColor = Color3.fromRGB(255,40,40)
            highlight.OutlineColor = Color3.fromRGB(255,40,40)
            highlight.FillTransparency = 0.8
            highlight.OutlineTransparency = 0
            return highlight
        end)
        if ok then currentHighlight = h end
    end
end

-- New: compute alternating front/back position
local function computeFinalPosAlternating(targetHRP, myPos)
    local center = targetHRP.Position
    local lookVec = targetHRP.CFrame.LookVector
    local toMe = (myPos - center)
    local finalPos
    if toMe:Dot(lookVec) > 0 then
        finalPos = center - lookVec * BEHIND_DISTANCE
    else
        finalPos = center + lookVec * BEHIND_DISTANCE
    end
    finalPos = Vector3.new(finalPos.X, center.Y + 1.5, finalPos.Z)
    return finalPos
end

local function smoothArcToTarget(targetModel)
    if busy then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end
    busy = true
    local targetHRP = targetModel.HumanoidRootPart
    local center = targetHRP.Position
    local myPos = HRP.Position
    local lookVec = targetHRP.CFrame.LookVector
    local finalPos = computeFinalPosAlternating(targetHRP, myPos)

    local startRadius = (Vector3.new(myPos.X,0,myPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local midRadius   = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius   = (Vector3.new(finalPos.X,0,finalPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local startAngle = math.atan2(myPos.Z-center.Z, myPos.X-center.X)
    local endAngle   = math.atan2(finalPos.Z-center.Z, finalPos.X-center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)
    local isLeft = (deltaAngle > 0)
    pcall(function() playSideAnimation(isLeft) end)

    if m1AfterTween then
        local scheduledDelay = tonumber(m1DelayValue) or 0.1
        delay(scheduledDelay, function()
            pcall(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Communicate") and char.Communicate.FireServer then
                    local args1 = {[1] = {["Mobile"] = true, ["Goal"] = "LeftClick"}}
                    local args2 = {[1] = {["Goal"] = "LeftClickRelease", ["Mobile"] = true}}
                    char.Communicate:FireServer(unpack(args1))
                    char.Communicate:FireServer(unpack(args2))
                end
            end)
        end)
    end

    local cam = workspace.CurrentCamera
    local startLook = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0,0,1)
    local startPitch = math.asin(math.clamp(startLook.Y, -0.999, 0.999))
    local startYaw   = math.atan2(startLook.Z, startLook.X)
    local desiredYaw = math.atan2(lookVec.Z, lookVec.X)
    local startY = myPos.Y
    local endY = finalPos.Y
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local now = tick()
        local t = math.clamp((now - startTime)/TOTAL_TIME, 0, 1)
        local e = easeOutCubic(t)
        local midT = 0.5
        local radiusNow
        if t <= midT then
            local e1 = easeOutCubic(t/midT)
            radiusNow = startRadius + (midRadius - startRadius)*e1
        else
            local e2 = easeOutCubic((t-midT)/(1-midT))
            radiusNow = midRadius + (endRadius - midRadius)*e2
        end
        radiusNow = math.clamp(radiusNow, MIN_RADIUS, MAX_RADIUS)
        local angleNow = startAngle + deltaAngle*e
        local x = center.X + radiusNow*math.cos(angleNow)
        local z = center.Z + radiusNow*math.sin(angleNow)
        local y = startY + (endY-startY)*e
        local posNow = Vector3.new(x,y,z)
        local deltaYaw = shortestAngleDelta(desiredYaw, startYaw)
        local yawNow = startYaw + deltaYaw*e
        local pitchNow = startPitch
        local cosP = math.cos(pitchNow)
        local lookNow = Vector3.new(math.cos(yawNow)*cosP, math.sin(pitchNow), math.sin(yawNow)*cosP)
        local hrpLook = Vector3.new(math.cos(yawNow),0,math.sin(yawNow))
        pcall(function() HRP.CFrame = CFrame.new(posNow, posNow + hrpLook) end)
        pcall(function() if cam and cam.CFrame then cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + lookNow) end end)
        if t >= 1 then
            conn:Disconnect()
            pcall(function() HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(lookVec.X,0,lookVec.Z)) end)
            busy = false
        end
    end)
end

-- Create dash button (separate)
local function createDashButton()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("DashButtonGui"); if old then old:Destroy() end end)
    local gui = Instance.new("ScreenGui")
    gui.Name = "DashButtonGui"
    gui.ResetOnSpawn = false
    safeSetParent(gui)

    local button = Instance.new("ImageButton")
    button.Name = "DashControlButton"
    button.Size = UDim2.new(0,110,0,110)
    button.Position = UDim2.new(0.5,-55,0.82,-55)
    button.BackgroundTransparency = 1
    button.Image = "rbxassetid://99317918824094"
    button.Parent = gui

    local uiScale = Instance.new("UIScale", button)
    uiScale.Scale = 1

    local pressSound = Instance.new("Sound", button)
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 0.9
    pressSound.Looped = false

    -- drag code
    local isPointerDown, isDragging, pointerStartPos, buttonStartPos, trackedInput = false,false,nil,nil,nil
    local dragThreshold = 8
    local function startPointer(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPointerDown = true
            isDragging = false
            pointerStartPos = input.Position
            buttonStartPos = button.Position
            trackedInput = input
            pcall(function() pressSound:Play() end)
        end
    end
    local function updatePointer(input)
        if not isPointerDown or input ~= trackedInput then return end
        local delta = input.Position - pointerStartPos
        if not isDragging and delta.Magnitude >= dragThreshold then isDragging = true end
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
        if not isDragging and not busy then
            local chosenCharacter = nil
            if findNearestEnabled then
                local target, dist = getNearestTarget(ACTIVATION_RANGE)
                if target and dist and dist <= ACTIVATION_RANGE then chosenCharacter = target end
            else
                if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (selectedPlayer.Character.HumanoidRootPart.Position - HRP.Position).Magnitude
                    if d <= ACTIVATION_RANGE then chosenCharacter = selectedPlayer.Character end
                end
            end
            if chosenCharacter then smoothArcToTarget(chosenCharacter) end
        end
        isPointerDown, isDragging, pointerStartPos, buttonStartPos, trackedInput = false,false,nil,nil,nil
    end)

    button.InputBegan:Connect(startPointer)
end

-- Settings UI (layout based on v8 spacing; pixel positions used to avoid overlapping)
local function createSettingsUI()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("Dash Assist Settings"); if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Dash Assist Settings"
    screenGui.ResetOnSpawn = false
    safeSetParent(screenGui)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0,320,0,300)
    mainFrame.Position = UDim2.new(0.63,0,0.12,0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(22,22,24)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local uiStroke = Instance.new("UIStroke", mainFrame)
    uiStroke.Thickness = 1
    uiStroke.Transparency = 0.78
    uiStroke.Color = Color3.fromRGB(60,60,70)

    local uiCorner = Instance.new("UICorner", mainFrame)
    uiCorner.CornerRadius = UDim.new(0,12)

    -- Title bar
    local topBar = Instance.new("Frame", mainFrame)
    topBar.Size = UDim2.new(1,0,0,34)
    topBar.Position = UDim2.new(0,0,0,0)
    topBar.BackgroundTransparency = 1

    local title = Instance.new("TextLabel", topBar)
    title.Text = "Dash Assist"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0,12,0,6)
    title.Size = UDim2.new(0.7,0,1,0)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local minimizeBtn = Instance.new("TextButton", topBar)
    minimizeBtn.Text = "-"
    minimizeBtn.Size = UDim2.new(0,34,0,28)
    minimizeBtn.Position = UDim2.new(1,-42,0,3)
    minimizeBtn.Font = Enum.Font.Gotham
    minimizeBtn.TextSize = 18
    local minCorner = Instance.new("UICorner", minimizeBtn)
    minCorner.CornerRadius = UDim.new(0,8)

    -- Mini button when minimized
    local miniButton = Instance.new("TextButton", screenGui)
    miniButton.Size = UDim2.new(0,40,0,40)
    local savedX = dataFolder:FindFirstChild("miniX")
    local savedY = dataFolder:FindFirstChild("miniY")
    if savedX and savedY then
        miniButton.Position = UDim2.new(0, savedX.Value, 0, savedY.Value)
    else
        miniButton.Position = UDim2.new(0.63,0,0.12,0)
    end
    miniButton.Text = ">"
    miniButton.Visible = false
    miniButton.BackgroundColor3 = Color3.fromRGB(24,24,26)
    local miniCorner = Instance.new("UICorner", miniButton)
    miniCorner.CornerRadius = UDim.new(0,8)

    -- Players label + list
    local playersLabel = Instance.new("TextLabel", mainFrame)
    playersLabel.Position = UDim2.new(0,12,0,44)
    playersLabel.Size = UDim2.new(1,-24,0,18)
    playersLabel.BackgroundTransparency = 1
    playersLabel.Text = "Target:"
    playersLabel.Font = Enum.Font.Gotham
    playersLabel.TextSize = 13
    playersLabel.TextColor3 = Color3.fromRGB(200,200,200)
    playersLabel.TextXAlignment = Enum.TextXAlignment.Left

    local scroll = Instance.new("ScrollingFrame", mainFrame)
    scroll.Position = UDim2.new(0,12,0,68)
    scroll.Size = UDim2.new(1,-24,0,100)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    local uiLayout = Instance.new("UIListLayout", scroll)
    uiLayout.Padding = UDim.new(0,6)
    uiLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Find nearest (left) and M1 (right) with dot indicators (spaced)
    local fnX = 12
    local fnY = 180
    local fnW = 150
    local fnH = 36
    local gap = 12
    local m1W = 130

    local findNearestBtn = Instance.new("Frame", mainFrame)
    findNearestBtn.Position = UDim2.new(0, fnX, 0, fnY)
    findNearestBtn.Size = UDim2.new(0, fnW, 0, fnH)
    findNearestBtn.BackgroundColor3 = Color3.fromRGB(40,40,44)
    local fnCorner = Instance.new("UICorner", findNearestBtn)
    fnCorner.CornerRadius = UDim.new(0,8)
    local fnStroke = Instance.new("UIStroke", findNearestBtn)
    fnStroke.Color = Color3.fromRGB(70,70,80)
    fnStroke.Transparency = 0.8
    local fnLabel = Instance.new("TextLabel", findNearestBtn)
    fnLabel.Size = UDim2.new(1,-36,1,0)
    fnLabel.Position = UDim2.new(0,12,0,0)
    fnLabel.BackgroundTransparency = 1
    fnLabel.Text = "Find nearest"
    fnLabel.TextColor3 = Color3.fromRGB(230,230,230)
    fnLabel.Font = Enum.Font.Gotham
    fnLabel.TextSize = 14
    -- dot
    local fnDot = Instance.new("Frame", findNearestBtn)
    fnDot.Size = UDim2.new(0,14,0,14)
    fnDot.Position = UDim2.new(1,-20,0.5,-7)
    fnDot.BackgroundTransparency = 1
    local fnDotCorner = Instance.new("UICorner", fnDot)
    fnDotCorner.CornerRadius = UDim.new(0,8)

    local m1Btn = Instance.new("Frame", mainFrame)
    m1Btn.Position = UDim2.new(0, fnX + fnW + gap, 0, fnY)
    m1Btn.Size = UDim2.new(0, m1W, 0, fnH)
    m1Btn.BackgroundColor3 = Color3.fromRGB(40,40,44)
    local m1Corner = Instance.new("UICorner", m1Btn)
    m1Corner.CornerRadius = UDim.new(0,8)
    local m1Stroke = Instance.new("UIStroke", m1Btn)
    m1Stroke.Color = Color3.fromRGB(70,70,80)
    m1Stroke.Transparency = 0.8
    local m1Label = Instance.new("TextLabel", m1Btn)
    m1Label.Size = UDim2.new(1,-36,1,0)
    m1Label.Position = UDim2.new(0,12,0,0)
    m1Label.BackgroundTransparency = 1
    m1Label.Text = "M1"
    m1Label.TextColor3 = Color3.fromRGB(230,230,230)
    m1Label.Font = Enum.Font.Gotham
    m1Label.TextSize = 14
    local m1Dot = Instance.new("Frame", m1Btn)
    m1Dot.Size = UDim2.new(0,14,0,14)
    m1Dot.Position = UDim2.new(1,-20,0.5,-7)
    m1Dot.BackgroundTransparency = 1
    local m1DotCorner = Instance.new("UICorner", m1Dot)
    m1DotCorner.CornerRadius = UDim.new(0,8)

    -- Delay label + box placed BELOW the findNearest (clear spacing)
    local delayLabel = Instance.new("TextLabel", mainFrame)
    delayLabel.Position = UDim2.new(0,12,0,230)
    delayLabel.Size = UDim2.new(0,140,0,18)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Text = "M1 Delay (s)"
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 12
    delayLabel.TextColor3 = Color3.fromRGB(200,200,200)
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left

    local delayBox = Instance.new("TextBox", mainFrame)
    delayBox.Position = UDim2.new(0,12+150,0,226)
    delayBox.Size = UDim2.new(0,80,0,24)
    delayBox.Text = tostring(m1DelayValue)
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 14
    delayBox.ClearTextOnFocus = false
    delayBox.BackgroundColor3 = Color3.fromRGB(36,36,38)
    delayBox.TextColor3 = Color3.new(1,1,1)
    local dbCorner = Instance.new("UICorner", delayBox)
    dbCorner.CornerRadius = UDim.new(0,6)

    -- ESP toggle (right side under M1)
    local espBtn = Instance.new("Frame", mainFrame)
    espBtn.Position = UDim2.new(0, fnX + fnW + gap, 0, fnY + 48)
    espBtn.Size = UDim2.new(0, m1W, 0, fnH)
    espBtn.BackgroundColor3 = Color3.fromRGB(40,40,44)
    local espCorner = Instance.new("UICorner", espBtn)
    espCorner.CornerRadius = UDim.new(0,8)
    local espStroke = Instance.new("UIStroke", espBtn)
    espStroke.Color = Color3.fromRGB(70,70,80)
    espStroke.Transparency = 0.8
    local espLabel = Instance.new("TextLabel", espBtn)
    espLabel.Size = UDim2.new(1,-36,1,0)
    espLabel.Position = UDim2.new(0,12,0,0)
    espLabel.BackgroundTransparency = 1
    espLabel.Text = "ESP"
    espLabel.Font = Enum.Font.Gotham
    espLabel.TextSize = 14
    espLabel.TextColor3 = Color3.fromRGB(230,230,230)
    local espDot = Instance.new("Frame", espBtn)
    espDot.Size = UDim2.new(0,14,0,14)
    espDot.Position = UDim2.new(1,-20,0.5,-7)
    espDot.BackgroundTransparency = 1
    local espDotCorner = Instance.new("UICorner", espDot)
    espDotCorner.CornerRadius = UDim.new(0,8)

    -- Dragging mainFrame (topBar)
    local dragging = false
    local dragInput, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local screenW, screenH = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, screenW - mainFrame.AbsoluteSize.X)
            newY = math.clamp(newY, 0, screenH - mainFrame.AbsoluteSize.Y)
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    -- minimize behavior
    minimizeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        miniButton.Visible = true
        miniButton.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
        local vX = dataFolder:FindFirstChild("miniX") or Instance.new("NumberValue", dataFolder)
        vX.Name = "miniX"; vX.Value = miniButton.AbsolutePosition.X
        local vY = dataFolder:FindFirstChild("miniY") or Instance.new("NumberValue", dataFolder)
        vY.Name = "miniY"; vY.Value = miniButton.AbsolutePosition.Y
        updateESP(false)
    end)
    miniButton.MouseButton1Click:Connect(function() mainFrame.Visible = true; miniButton.Visible = false; clearHighlight() end)

    -- mini button drag saving omitted for brevity (same as earlier implementations)

    -- refresh player list
    local function refreshPlayerList()
        for _, c in pairs(scroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local btn = Instance.new("TextButton", scroll)
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.BackgroundColor3 = Color3.fromRGB(38,38,40)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.Text = pl.Name
                local bcorner = Instance.new("UICorner", btn)
                bcorner.CornerRadius = UDim.new(0,6)
                btn.MouseButton1Click:Connect(function()
                    selectedPlayer = pl
                    for _, c in pairs(scroll:GetChildren()) do if c:IsA("TextButton") then c.BackgroundColor3 = Color3.fromRGB(38,38,40) end end
                    btn.BackgroundColor3 = Color3.fromRGB(80,120,200)
                    findNearestEnabled = false
                    -- update dot visuals
                    fnDot.BackgroundTransparency = 1
                end)
            end
        end
        local total = 0
        for _, c in pairs(scroll:GetChildren()) do if c:IsA("TextButton") then total = total + c.Size.Y.Offset + 6 end end
        scroll.CanvasSize = UDim2.new(0,0,0,math.max(0,total))
    end

    refreshPlayerList()
    Players.PlayerAdded:Connect(refreshPlayerList)
    Players.PlayerRemoving:Connect(function() if selectedPlayer and selectedPlayer.Parent == nil then selectedPlayer = nil end; refreshPlayerList() end)

    -- toggle behaviors with dot visuals
    local function setDot(frame, on)
        if on then
            frame.BackgroundTransparency = 0
            frame.BackgroundColor3 = Color3.new(1,1,1)
        else
            frame.BackgroundTransparency = 1
        end
    end
    setDot(fnDot, findNearestEnabled)
    setDot(m1Dot, m1AfterTween)
    setDot(espDot, espEnabled)

    findNearestBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            findNearestEnabled = not findNearestEnabled
            if findNearestEnabled then selectedPlayer = nil end
            setDot(fnDot, findNearestEnabled)
        end
    end)
    m1Btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            m1AfterTween = not m1AfterTween
            setDot(m1Dot, m1AfterTween)
        end
    end)
    espBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            espEnabled = not espEnabled
            setDot(espDot, espEnabled)
            if espEnabled then selectedPlayer = nil; findNearestEnabled = true; setDot(fnDot, true); updateESP(false) else clearHighlight() end
        end
    end)

    delayBox.FocusLost:Connect(function()
        local num = tonumber(delayBox.Text)
        if num and num >= 0 then m1DelayValue = num; delayBox.Text = tostring(m1DelayValue)
        else delayBox.Text = tostring(m1DelayValue) end
    end)
end

-- INIT
createDashButton()
createSettingsUI()

-- Live ESP updater
RunService.Heartbeat:Connect(function()
    local settingsGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Dash Assist Settings")
    local visible = true
    if settingsGui and settingsGui:FindFirstChild("MainFrame") then visible = settingsGui.MainFrame.Visible end
    if not visible and espEnabled then
        clearHighlight()
        updateESP(false)
    else
        clearHighlight()
    end
end)

-- Keybind
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or busy then return end
    local activated = false
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then activated = true end
    if activated then
        local chosenCharacter = nil
        if findNearestEnabled then
            local target, dist = getNearestTarget(ACTIVATION_RANGE)
            if target and dist and dist <= ACTIVATION_RANGE then chosenCharacter = target end
        else
            if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local d = (selectedPlayer.Character.HumanoidRootPart.Position - HRP.Position).Magnitude
                if d <= ACTIVATION_RANGE then chosenCharacter = selectedPlayer.Character end
            end
        end
        if chosenCharacter then smoothArcToTarget(chosenCharacter) end
    end
end)

print("[DashAssist v9 fixed spacing] Ready.")
