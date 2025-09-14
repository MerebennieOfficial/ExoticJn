
--// Merebennie DashAssist v9.2 (Delta Mobile Compatible)
--// Improvements:
--  * ESP follows target properly (players & NPCs)
--  * Final facing always looks AT the target (fix front/back facing issue)
--  * Tween front->back and back->front both enable aimlock equally
--  * UI layout fixed to avoid collisions; mini button draggable & persistent
--  * Reused Highlight instance for performance
--  * Aimlock active during tween + for AIMLOCK_TIME after completion

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace

-- Safe GUI parenting helper
local function safeSetParent(gui)
    local parentUsed = nil
    local function tryParent(p)
        if not p then return false end
        local ok = pcall(function() gui.Parent = p end)
        if ok and gui.Parent == p then parentUsed = p; return true end
        return false
    end
    if type(gethui) == "function" then
        local ok, g = pcall(function() return gethui() end)
        if ok and g then if tryParent(g) then return g end end
    end
    if type(get_hidden_gui) == "function" then
        local ok, g = pcall(function() return get_hidden_gui() end)
        if ok and g then if tryParent(g) then return g end end
    end
    local cg = nil
    pcall(function() cg = game:GetService("CoreGui") end)
    if cg and tryParent(cg) then return cg end
    if LocalPlayer then
        local pg = nil
        pcall(function() pg = LocalPlayer:FindFirstChild("PlayerGui") end)
        if pg and tryParent(pg) then return pg end
    end
    if cg then tryParent(cg) end
    return parentUsed
end

-- REBIND ON RESPAWN
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

-- CONFIG
local MAX_RANGE            = 80
local ARC_APPROACH_RADIUS  = 8
local BEHIND_DISTANCE      = 4
local TOTAL_TIME           = 0.22
local AIMLOCK_TIME         = 0.5 -- seconds after tween to keep aimlock
local MIN_RADIUS           = 1.2
local MAX_RADIUS           = 14
local ACTIVATION_RANGE     = 35

-- ANIMATIONS / SFX
local ANIM_LEFT_ID  = 10480796021
local ANIM_RIGHT_ID = 10480793962
local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID  = "rbxassetid://72014632956520"

-- STATE
local busy = false
local aimlockConn = nil
local currentAnimTrack = nil
local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2.0
dashSound.Looped = false
dashSound.Parent = workspace

-- M1 after tween feature flag (UI toggle)
local m1AfterTween = true
local m1DelayValue = 0.1 -- default delay (seconds) after tween activation

-- UI selection / find-nearest toggle
local findNearestEnabled = true
local selectedPlayer = nil

-- ESP
local espEnabled = false
local currentHighlight = nil

-- Persisted data folder (for saving miniButton position)
local dataFolder = LocalPlayer:FindFirstChild("DashAssistSettingsData")
if not dataFolder then
    dataFolder = Instance.new("Folder")
    dataFolder.Name = "DashAssistSettingsData"
    dataFolder.Parent = LocalPlayer
end

-- helpers
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
    if not hum then hum = Character:FindFirstChild("Humanoid") end
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
    pcall(function()
        if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
        currentAnimTrack = nil
    end)
    local hum, animator = ensureHumanoidAndAnimator()
    if not hum or not animator then return end
    local animId = isLeft and ANIM_LEFT_ID or ANIM_RIGHT_ID
    if not animId then return end
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
        if track and track.IsPlaying then pcall(function() track:Stop() end) end
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
    -- NPCs and workspace models
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

-- ESP helper: create or update highlight (reuse for perf)
local function clearHighlight()
    if currentHighlight then
        pcall(function() currentHighlight:Destroy() end)
        currentHighlight = nil
    end
end

local function ensureHighlightFor(targetModel)
    if not targetModel or not targetModel:IsA("Model") then
        clearHighlight()
        return
    end
    if currentHighlight and currentHighlight.Parent and currentHighlight.Adornee ~= targetModel then
        currentHighlight.Adornee = targetModel
        return
    end
    if currentHighlight and currentHighlight.Parent == nil then
        currentHighlight = nil
    end
    if not currentHighlight then
        local ok, h = pcall(function()
            local hh = Instance.new("Highlight")
            hh.Name = "DashAssistTargetHighlight"
            hh.Parent = workspace
            hh.FillColor = Color3.fromRGB(255, 40, 40)
            hh.OutlineColor = Color3.fromRGB(255, 40, 40)
            hh.FillTransparency = 0.8
            hh.OutlineTransparency = 0
            return hh
        end)
        if ok and h then currentHighlight = h end
    end
    if currentHighlight then
        pcall(function() currentHighlight.Adornee = targetModel end)
    end
end

local function updateESP(settingsVisible)
    if not espEnabled then
        clearHighlight()
        return
    end
    if settingsVisible then
        clearHighlight()
        return
    end
    local targetModel = nil
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        targetModel = selectedPlayer.Character
    else
        local t, d = getNearestTarget(ACTIVATION_RANGE)
        if t then targetModel = t end
    end
    if targetModel and targetModel:IsA("Model") and targetModel:FindFirstChild("Humanoid") and targetModel:FindFirstChild("HumanoidRootPart") then
        ensureHighlightFor(targetModel)
    else
        clearHighlight()
    end
end

-- Decide final position and final look vector (so final facing is always towards the target center)
local function computeFinalPosAndLook(targetHRP, myPos)
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
    local finalLook = (center - finalPos)
    finalLook = Vector3.new(finalLook.X, 0, finalLook.Z)
    if finalLook.Magnitude == 0 then
        finalLook = Vector3.new(-lookVec.X, 0, -lookVec.Z)
    else
        finalLook = finalLook.Unit
    end
    return finalPos, finalLook
end

-- Aimlock utility: while enabled, force the camera to look at target position
local aimlockEnabled = false
local aimlockTargetPos = nil
local aimlockConnection = nil
local function startAimlockFor(targetCFrame)
    aimlockEnabled = true
    aimlockTargetPos = targetCFrame.Position
    if aimlockConnection and aimlockConnection.Connected then aimlockConnection:Disconnect() aimlockConnection = nil end
    aimlockConnection = RunService.Heartbeat:Connect(function()
        if not aimlockEnabled then return end
        local cam = workspace.CurrentCamera
        if cam and cam.CFrame and aimlockTargetPos then
            local camPos = cam.CFrame.Position
            local dir = (aimlockTargetPos - camPos)
            if dir.Magnitude > 0 then
                local look = CFrame.new(camPos, Vector3.new(aimlockTargetPos.X, camPos.Y + (aimlockTargetPos.Y - camPos.Y)*0.2, aimlockTargetPos.Z))
                pcall(function() cam.CFrame = look end)
            end
        end
    end)
end
local function stopAimlock()
    aimlockEnabled = false
    aimlockTargetPos = nil
    if aimlockConnection and aimlockConnection.Connected then aimlockConnection:Disconnect() aimlockConnection = nil end
end

local function smoothArcToBack(targetModel)
    if busy then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end
    busy = true
    if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end

    local targetHRP = targetModel.HumanoidRootPart
    local center = targetHRP.Position
    local myPos = HRP.Position

    local finalPos, finalLook = computeFinalPosAndLook(targetHRP, myPos)

    local startRadius = (Vector3.new(myPos.X,0,myPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local midRadius   = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius   = (Vector3.new(finalPos.X,0,finalPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local startAngle = math.atan2(myPos.Z-center.Z, myPos.X-center.X)
    local endAngle   = math.atan2(finalPos.Z-center.Z, finalPos.X-center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)
    local isLeft = (deltaAngle > 0)
    pcall(function() playSideAnimation(isLeft) end)

    -- start aimlock at tween start so both front->back and back->front get same behavior
    startAimlockFor(targetHRP.CFrame)

    -- schedule M1 based on configured delay — schedule at start of tween
    if m1AfterTween then
        local scheduledDelay = tonumber(m1DelayValue) or 0.1
        delay(scheduledDelay, function()
            pcall(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Communicate") and char.Communicate.FireServer then
                    local args1 = {
                        [1] = {
                            ["Mobile"] = true,
                            ["Goal"] = "LeftClick"
                        }
                    }
                    char.Communicate:FireServer(unpack(args1))
                    local args2 = {
                        [1] = {
                            ["Goal"] = "LeftClickRelease",
                            ["Mobile"] = true
                        }
                    }
                    char.Communicate:FireServer(unpack(args2))
                end
            end)
        end)
    end

    local cam = workspace.CurrentCamera
    local startLook = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0,0,1)
    local startPitch = math.asin(math.clamp(startLook.Y, -0.999, 0.999))
    local startYaw   = math.atan2(startLook.Z, startLook.X)
    local desiredYaw = math.atan2(finalLook.Z, finalLook.X)

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
        local hrpLook = Vector3.new(math.cos(yawNow),0,math.sin(yawNow))
        pcall(function() HRP.CFrame = CFrame.new(posNow, posNow + hrpLook) end)
        if cam and cam.CFrame then
            local lookNow = Vector3.new(math.cos(yawNow)*cosP, math.sin(pitchNow), math.sin(yawNow)*cosP)
            pcall(function() cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + lookNow) end)
        end
        if t >= 1 then
            conn:Disconnect()
            pcall(function() HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(finalLook.X, 0, finalLook.Z)) end)
            -- Keep aimlock for AIMLOCK_TIME after tween finishes
            delay(AIMLOCK_TIME, function()
                stopAimlock()
            end)
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
            busy = false
        end
    end)
end

-- Create dash button
local function createDashButton()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("DashButtonGui") if old then old:Destroy() end end)
    local gui = Instance.new("ScreenGui")
    gui.Name = "DashButtonGui"
    gui.ResetOnSpawn = false
    safeSetParent(gui)

    local button = Instance.new("ImageButton")
    button.Name = "DashControlButton"
    button.Size = UDim2.new(0,96,0,96)
    button.Position = UDim2.new(0.5,-48,0.82,-48)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://99317918824094"
    button.Active = true
    button.Parent = gui

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = button

    local pressSound = Instance.new("Sound")
    pressSound.Name = "PressSFX"
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 0.9
    pressSound.Looped = false
    pressSound.Parent = button

    -- drag for the dash button itself
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
            newX = math.clamp(newX,0,screenW - button.AbsoluteSize.X)
            newY = math.clamp(newY,0,screenH - button.AbsoluteSize.Y)
            button.Position = UDim2.new(0,newX,0,newY)
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
            if chosenCharacter then smoothArcToBack(chosenCharacter) end
        end
        tweenUIScale(1,0.06)
        isPointerDown,isDragging,pointerStartPos,buttonStartPos,trackedInput = false,false,nil,nil,nil
    end)

    button.InputBegan:Connect(function(input) pcall(function() startPointer(input) end) end)
end

-- Compact Settings UI
local function createSettingsUI()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("Dash Assist Settings") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Dash Assist Settings"
    screenGui.ResetOnSpawn = false
    safeSetParent(screenGui)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0,300,0,270)
    mainFrame.Position = UDim2.new(0.02,0,0.55,0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20,20,22)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    mainFrame.ClipsDescendants = true

    local uiStroke = Instance.new("UIStroke", mainFrame)
    uiStroke.Thickness = 1
    uiStroke.Transparency = 0.78
    uiStroke.Color = Color3.fromRGB(60,60,70)

    local uiCorner = Instance.new("UICorner", mainFrame)
    uiCorner.CornerRadius = UDim.new(0,10)

    -- Top bar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1,0,0,34)
    topBar.Position = UDim2.new(0,0,0,0)
    topBar.BackgroundTransparency = 1
    topBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.7,0,1,0)
    title.Position = UDim2.new(0,12,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Dash Assist"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "Minimize"
    minimizeBtn.Size = UDim2.new(0,30,0,24)
    minimizeBtn.Position = UDim2.new(1,-36,0,6)
    minimizeBtn.Text = "-"
    minimizeBtn.Font = Enum.Font.Gotham
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = topBar
    local minCorner = Instance.new("UICorner", minimizeBtn)
    minCorner.CornerRadius = UDim.new(0,6)

    -- Mini button for minimized state
    local miniButton = Instance.new("TextButton")
    miniButton.Name = "MiniOpen"
    miniButton.Size = UDim2.new(0,40,0,40)
    local savedX = dataFolder:FindFirstChild("miniX")
    local savedY = dataFolder:FindFirstChild("miniY")
    if savedX and savedY then
        miniButton.Position = UDim2.new(0, savedX.Value, 0, savedY.Value)
    else
        miniButton.Position = UDim2.new(0.02,0,0.55,0)
    end
    miniButton.Text = ">"
    miniButton.Visible = false
    miniButton.BackgroundColor3 = Color3.fromRGB(28,28,30)
    miniButton.TextColor3 = Color3.new(1,1,1)
    miniButton.Parent = screenGui
    local miniCorner = Instance.new("UICorner", miniButton)
    miniCorner.CornerRadius = UDim.new(0,8)
    local miniStroke = Instance.new("UIStroke", miniButton)
    miniStroke.Thickness = 1
    miniStroke.Transparency = 0.8
    miniStroke.Color = Color3.fromRGB(60,60,70)

    -- Player label and scrolling list (compact)
    local playersLabel = Instance.new("TextLabel")
    playersLabel.Name = "PlayersLabel"
    playersLabel.Size = UDim2.new(1,-16,0,18)
    playersLabel.Position = UDim2.new(0,10,0,44)
    playersLabel.BackgroundTransparency = 1
    playersLabel.Text = "Target:"
    playersLabel.Font = Enum.Font.Gotham
    playersLabel.TextSize = 12
    playersLabel.TextColor3 = Color3.fromRGB(200,200,200)
    playersLabel.TextXAlignment = Enum.TextXAlignment.Left
    playersLabel.Parent = mainFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "PlayerList"
    scroll.Size = UDim2.new(1,-20,0,90)
    scroll.Position = UDim2.new(0,10,0,66)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 6
    scroll.Parent = mainFrame
    local uiLayout = Instance.new("UIListLayout", scroll)
    uiLayout.Padding = UDim.new(0,6)
    uiLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Find nearest (compact) with dot indicator
    local findNearestBtn = Instance.new("Frame")
    findNearestBtn.Name = "FindNearest"
    findNearestBtn.Size = UDim2.new(0.62,0,0,30)
    findNearestBtn.Position = UDim2.new(0,10,0,168)
    findNearestBtn.BackgroundColor3 = Color3.fromRGB(36,36,40)
    findNearestBtn.Parent = mainFrame
    local fnCorner = Instance.new("UICorner", findNearestBtn)
    fnCorner.CornerRadius = UDim.new(0,6)
    local fnStroke = Instance.new("UIStroke", findNearestBtn)
    fnStroke.Thickness = 1
    fnStroke.Transparency = 0.78
    fnStroke.Color = Color3.fromRGB(60,60,70)

    local fnLabel = Instance.new("TextLabel")
    fnLabel.Size = UDim2.new(1,-28,1,0)
    fnLabel.Position = UDim2.new(0,8,0,0)
    fnLabel.BackgroundTransparency = 1
    fnLabel.Text = "Find nearest"
    fnLabel.Font = Enum.Font.Gotham
    fnLabel.TextSize = 12
    fnLabel.TextColor3 = Color3.fromRGB(220,220,220)
    fnLabel.Parent = findNearestBtn

    local fnDot = Instance.new("Frame")
    fnDot.Name = "Dot"
    fnDot.Size = UDim2.new(0,12,0,12)
    fnDot.Position = UDim2.new(1,-18,0.5,-6)
    fnDot.BackgroundTransparency = 1
    fnDot.Parent = findNearestBtn
    local fnDotCorner = Instance.new("UICorner", fnDot)
    fnDotCorner.CornerRadius = UDim.new(0,6)

    -- M1 toggle compact with dot
    local m1Btn = Instance.new("Frame")
    m1Btn.Name = "M1After"
    m1Btn.Size = UDim2.new(0.34,0,0,30)
    m1Btn.Position = UDim2.new(0.66,8,0,168)
    m1Btn.BackgroundColor3 = Color3.fromRGB(36,36,40)
    m1Btn.Parent = mainFrame
    local m1Corner = Instance.new("UICorner", m1Btn)
    m1Corner.CornerRadius = UDim.new(0,6)
    local m1Stroke = Instance.new("UIStroke", m1Btn)
    m1Stroke.Thickness = 1
    m1Stroke.Transparency = 0.78
    m1Stroke.Color = Color3.fromRGB(60,60,70)

    local m1Label = Instance.new("TextLabel")
    m1Label.Size = UDim2.new(1,-28,1,0)
    m1Label.Position = UDim2.new(0,8,0,0)
    m1Label.BackgroundTransparency = 1
    m1Label.Text = "M1"
    m1Label.Font = Enum.Font.Gotham
    m1Label.TextSize = 12
    m1Label.TextColor3 = Color3.fromRGB(220,220,220)
    m1Label.Parent = m1Btn

    local m1Dot = Instance.new("Frame")
    m1Dot.Name = "Dot"
    m1Dot.Size = UDim2.new(0,12,0,12)
    m1Dot.Position = UDim2.new(1,-18,0.5,-6)
    m1Dot.BackgroundTransparency = 1
    m1Dot.Parent = m1Btn
    local m1DotCorner = Instance.new("UICorner", m1Dot)
    m1DotCorner.CornerRadius = UDim.new(0,6)

    -- Delay textbox placed to the right, but spaced to avoid collision
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Name = "DelayLabel"
    delayLabel.Size = UDim2.new(0.5,0,0,16)
    delayLabel.Position = UDim2.new(0,10,0,210)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Text = "M1 Delay (s)"
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 11
    delayLabel.TextColor3 = Color3.fromRGB(200,200,200)
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = mainFrame

    local delayBox = Instance.new("TextBox")
    delayBox.Name = "DelayBox"
    delayBox.Size = UDim2.new(0,72,0,22)
    delayBox.Position = UDim2.new(0.5,6,0,204)
    delayBox.Text = tostring(m1DelayValue)
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 12
    delayBox.ClearTextOnFocus = false
    delayBox.BackgroundColor3 = Color3.fromRGB(34,34,36)
    delayBox.TextColor3 = Color3.new(1,1,1)
    delayBox.Parent = mainFrame
    local dbCorner = Instance.new("UICorner", delayBox)
    dbCorner.CornerRadius = UDim.new(0,6)

    -- ESP toggle (dot) placed next to Delay for compactness
    local espBtn = Instance.new("Frame")
    espBtn.Name = "EspToggle"
    espBtn.Size = UDim2.new(0.34,0,0,30)
    espBtn.Position = UDim2.new(0.66,8,0,204)
    espBtn.BackgroundColor3 = Color3.fromRGB(36,36,40)
    espBtn.Parent = mainFrame
    local espCorner = Instance.new("UICorner", espBtn)
    espCorner.CornerRadius = UDim.new(0,6)
    local espStroke = Instance.new("UIStroke", espBtn)
    espStroke.Thickness = 1
    espStroke.Transparency = 0.78
    espStroke.Color = Color3.fromRGB(60,60,70)

    local espLabel = Instance.new("TextLabel")
    espLabel.Size = UDim2.new(1,-28,1,0)
    espLabel.Position = UDim2.new(0,8,0,0)
    espLabel.BackgroundTransparency = 1
    espLabel.Text = "ESP"
    espLabel.Font = Enum.Font.Gotham
    espLabel.TextSize = 12
    espLabel.TextColor3 = Color3.fromRGB(220,220,220)
    espLabel.Parent = espBtn

    local espDot = Instance.new("Frame")
    espDot.Name = "Dot"
    espDot.Size = UDim2.new(0,12,0,12)
    espDot.Position = UDim2.new(1,-18,0.5,-6)
    espDot.BackgroundTransparency = 1
    espDot.Parent = espBtn
    local espDotCorner = Instance.new("UICorner", espDot)
    espDotCorner.CornerRadius = UDim.new(0,6)

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = mainFrame

    -- Dragging mainFrame
    local dragging = false
    local dragInput, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
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
            newX = math.clamp(newX,0, screenW - mainFrame.AbsoluteSize.X)
            newY = math.clamp(newY,0, screenH - mainFrame.AbsoluteSize.Y)
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    -- Minimize behavior
    minimizeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        miniButton.Visible = true
        miniButton.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
        local vX = dataFolder:FindFirstChild("miniX")
        local vY = dataFolder:FindFirstChild("miniY")
        if not vX then vX = Instance.new("NumberValue", dataFolder) vX.Name = "miniX" end
        if not vY then vY = Instance.new("NumberValue", dataFolder) vY.Name = "miniY" end
        vX.Value = miniButton.AbsolutePosition.X
        vY.Value = miniButton.AbsolutePosition.Y
        updateESP(false)
    end)
    miniButton.MouseButton1Click:Connect(function()
        mainFrame.Visible = true
        miniButton.Visible = false
        clearHighlight()
    end)

    -- Make miniButton draggable (save position)
    local isMiniPointerDown, isMiniDragging, miniPointerStartPos, miniButtonStartPos, trackedMiniInput = false,false,nil,nil,nil
    local miniDragThreshold = 6

    miniButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isMiniPointerDown = true
            isMiniDragging = false
            miniPointerStartPos = input.Position
            miniButtonStartPos = miniButton.Position
            trackedMiniInput = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isMiniPointerDown = false
                    isMiniDragging = false
                    trackedMiniInput = nil
                end
            end)
        end
    end)
    miniButton.InputChanged:Connect(function(input)
        if not isMiniPointerDown or not miniPointerStartPos or input ~= trackedMiniInput then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - miniPointerStartPos
            if not isMiniDragging and delta.Magnitude >= miniDragThreshold then
                isMiniDragging = true
            end
            if isMiniDragging then
                local screenW, screenH = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y
                local newX = miniButtonStartPos.X.Offset + delta.X
                local newY = miniButtonStartPos.Y.Offset + delta.Y
                newX = math.clamp(newX,0, screenW - miniButton.AbsoluteSize.X)
                newY = math.clamp(newY,0, screenH - miniButton.AbsoluteSize.Y)
                miniButton.Position = UDim2.new(0, newX, 0, newY)
                local vX = dataFolder:FindFirstChild("miniX")
                local vY = dataFolder:FindFirstChild("miniY")
                if not vX then vX = Instance.new("NumberValue", dataFolder) vX.Name = "miniX" end
                if not vY then vY = Instance.new("NumberValue", dataFolder) vY.Name = "miniY" end
                vX.Value = miniButton.AbsolutePosition.X
                vY.Value = miniButton.AbsolutePosition.Y
            end
        end
    end)
    miniButton.InputEnded:Connect(function(input)
        if input ~= trackedMiniInput then return end
        isMiniPointerDown = false
        trackedMiniInput = nil
        wait(0.03)
        isMiniDragging = false
    end)

    -- Player list refresh
    local function refreshPlayerList()
        for _, child in pairs(scroll:GetChildren()) do
            if not child:IsA("UIListLayout") then child:Destroy() end
        end
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local btn = Instance.new("TextButton")
                btn.Name = pl.Name .. "_btn"
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.BackgroundColor3 = Color3.fromRGB(34,34,36)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.Text = pl.Name
                btn.Parent = scroll
                btn.AutoButtonColor = true
                local bcorner = Instance.new("UICorner", btn)
                bcorner.CornerRadius = UDim.new(0,6)
                local bstroke = Instance.new("UIStroke", btn)
                bstroke.Thickness = 1
                bstroke.Transparency = 0.78
                bstroke.Color = Color3.fromRGB(60,60,70)
                btn.MouseButton1Click:Connect(function()
                    selectedPlayer = pl
                    for _, c in pairs(scroll:GetChildren()) do
                        if c:IsA("TextButton") then
                            c.BackgroundColor3 = Color3.fromRGB(34,34,36)
                        end
                    end
                    btn.BackgroundColor3 = Color3.fromRGB(80,120,200)
                    findNearestEnabled = false
                    fnDot.BackgroundTransparency = 1
                    fnDot.BackgroundColor3 = Color3.new(1,1,1)
                end)
            end
        end
        local total = 0
        for _, c in pairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then total = total + c.Size.Y.Offset + 6 end
        end
        scroll.CanvasSize = UDim2.new(0,0,0,math.max(0,total))
    end

    refreshPlayerList()
    Players.PlayerAdded:Connect(function() refreshPlayerList() end)
    Players.PlayerRemoving:Connect(function()
        if selectedPlayer and selectedPlayer.Parent == nil then selectedPlayer = nil end
        refreshPlayerList()
    end)

    -- find nearest toggle behavior (click toggles; dot shows state)
    local function setFindDot(on)
        if on then
            fnDot.BackgroundTransparency = 0
            fnDot.BackgroundColor3 = Color3.new(1,1,1)
        else
            fnDot.BackgroundTransparency = 1
        end
    end
    setFindDot(findNearestEnabled)

    findNearestBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            findNearestEnabled = not findNearestEnabled
            setFindDot(findNearestEnabled)
            if findNearestEnabled then
                selectedPlayer = nil
            end
        end
    end)

    -- m1 toggle with dot
    local function setM1Dot(on)
        if on then
            m1Dot.BackgroundTransparency = 0
            m1Dot.BackgroundColor3 = Color3.new(1,1,1)
        else
            m1Dot.BackgroundTransparency = 1
        end
    end
    setM1Dot(m1AfterTween)

    m1Btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            m1AfterTween = not m1AfterTween
            setM1Dot(m1AfterTween)
        end
    end)

    -- delay box handling
    delayBox.FocusLost:Connect(function(enterPressed)
        local num = tonumber(delayBox.Text)
        if num and num >= 0 then
            m1DelayValue = num
            delayBox.Text = tostring(m1DelayValue)
        else
            delayBox.Text = tostring(m1DelayValue)
        end
    end)

    -- esp toggle with dot
    local function setEspDot(on)
        if on then
            espDot.BackgroundTransparency = 0
            espDot.BackgroundColor3 = Color3.new(1,1,1)
        else
            espDot.BackgroundTransparency = 1
        end
    end
    setEspDot(espEnabled)

    espBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            espEnabled = not espEnabled
            setEspDot(espEnabled)
            if espEnabled then
                selectedPlayer = nil
                findNearestEnabled = true
                setFindDot(true)
                if not mainFrame.Visible then updateESP(false) end
            else
                clearHighlight()
            end
        end
    end)
end

-- INIT
createDashButton()
createSettingsUI()

-- Live ESP updater (lightweight)
RunService.Heartbeat:Connect(function()
    local settingsGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Dash Assist Settings")
    local mainVisible = false
    if settingsGui then
        local main = settingsGui:FindFirstChild("MainFrame")
        if main then mainVisible = main.Visible end
    end
    if espEnabled then
        updateESP(not mainVisible)
    else
        clearHighlight()
    end
end)

-- KEYBINDS
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or busy then return end
    local activated = false
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X) then
        activated = true
    elseif (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonX) then
        activated = true
    elseif (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.DPadUp) then
        activated = true
    end

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
        if chosenCharacter then smoothArcToBack(chosenCharacter) end
    end
end)

print("[DashAssist v9.2] Ready. Compact settings UI loaded. Activation requires a target within " .. ACTIVATION_RANGE .. " studs.")
