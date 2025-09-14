
-- CircularTweenUI with ESP (highlights target in red)
-- Dash Assist with Front/Back automatic selection, yaw-only aimlock, animations, sounds, mobile+PC+controller support
-- This version keeps the original settings UI but removes the activation button from it.
-- A separate draggable Dash button GUI is created. Front/Back selection is automatic.

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
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

-- CONFIG (updated)
local MAX_RANGE            = 80
local ARC_APPROACH_RADIUS  = 15   -- changed 8 -> 15
local OFFSET_DISTANCE      = 4    -- behind/front offset in studs
local TOTAL_TIME           = 0.22
local AIMLOCK_TIME         = TOTAL_TIME
local MIN_RADIUS           = 1.2
local MAX_RADIUS           = 14

-- Activation requirement per your request:
local ACTIVATION_RANGE = 35 -- changed 20 -> 35

-- ANIMATIONS
local ANIM_LEFT_ID  = 10480796021
local ANIM_RIGHT_ID = 10480793962

-- SFX
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
local m1AfterTween = false
local m1Delay = 0.1 -- default, editable via UI

-- UI selection / find-nearest toggle
local findNearestEnabled = true
local selectedPlayer = nil

-- Direction mode: "Back" or "Front" (kept for UI, but activation uses automatic choice when mode=nil)
local directionMode = "Back"

-- ESP state
local currentHighlight = nil
local lastESPTarget = nil

-- HELPERS
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

-- Injected: helper to get Character from a Player value safely
local function getCharacterFromPlayer(pl)
    if not pl then return nil end
    if typeof(pl) == "Instance" and pl:IsA("Model") then return pl end -- already a character
    if typeof(pl) == "Instance" and pl:IsA("Player") then return pl.Character end
    return nil
end

-- ESP: highlight helper functions
local function clearESP()
    if currentHighlight then
        pcall(function() currentHighlight:Destroy() end)
        currentHighlight = nil
        lastESPTarget = nil
    end
end

local function applyESPToModel(model)
    if not model or not model.Parent then clearESP() return end
    if lastESPTarget == model then return end
    clearESP()
    local ok, highlight = pcall(function() return Instance.new("Highlight") end)
    if not ok or not highlight then return end
    highlight.Name = "DashAssist_Highlight"
    highlight.Adornee = model
    highlight.Parent = workspace
    -- make fill invisible, outline red
    pcall(function()
        highlight.FillTransparency = 1
        highlight.OutlineTransparency = 0
        highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
        -- fallback property names for older api
        if highlight.OutlineColor3 then highlight.OutlineColor3 = Color3.fromRGB(255,60,60) end
        if highlight.FillColor3 then highlight.FillColor3 = Color3.fromRGB(0,0,0) end
    end)
    currentHighlight = highlight
    lastESPTarget = model
end

-- Decide which character to ESP: if user selected a player -> that one; else nearest within ACTIVATION_RANGE
local function getESPChosenCharacter()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character.Parent then
        return selectedPlayer.Character
    end
    if findNearestEnabled then
        local target, dist = getNearestTarget(ACTIVATION_RANGE)
        if target and dist and dist <= ACTIVATION_RANGE then return target end
    end
    return nil
end

-- Choose Front/Back automatically based on whether you're in front of the target (dot>0 -> Back, else Front)
local function chooseDirectionAuto(targetHRP)
    if not HRP or not targetHRP then return "Back" end
    local myPos = HRP.Position
    local targetPos = targetHRP.Position
    local rel = Vector3.new(myPos.X - targetPos.X, 0, myPos.Z - targetPos.Z)
    local forward = Vector3.new(targetHRP.CFrame.LookVector.X, 0, targetHRP.CFrame.LookVector.Z)
    local dot = rel:Dot(forward)
    if dot > 0 then
        return "Back"
    else
        return "Front"
    end
end

-- Unified smooth arc function supporting Front/Back direction. If mode is nil -> auto choose.
local function smoothArcTo(targetModel, mode)
    if busy then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end
    busy = true
    if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn = nil end
    local targetHRP = targetModel.HumanoidRootPart
    local center = targetHRP.Position
    local myPos = HRP.Position
    local lookVec = targetHRP.CFrame.LookVector

    -- automatic mode if nil
    if not mode then
        mode = chooseDirectionAuto(targetHRP)
    end

    -- choose final position based on mode
    local finalPos
    if mode == "Back" then
        finalPos = center - lookVec * OFFSET_DISTANCE
    else
        finalPos = center + lookVec * OFFSET_DISTANCE
    end
    finalPos = Vector3.new(finalPos.X, center.Y + 1.5, finalPos.Z)

    -- radii and angles
    local startRadius = (Vector3.new(myPos.X,0,myPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local midRadius   = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius   = (Vector3.new(finalPos.X,0,finalPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local startAngle = math.atan2(myPos.Z-center.Z, myPos.X-center.X)
    local endAngle   = math.atan2(finalPos.Z-center.Z, finalPos.X-center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)
    local isLeft = (deltaAngle > 0)
    pcall(function() playSideAnimation(isLeft) end)

    -- camera aim start/destination (yaw-only)
    local cam = workspace.CurrentCamera
    local startLook = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0,0,1)
    local startPitch = math.asin(math.clamp(startLook.Y, -0.999, 0.999))
    local startYaw   = math.atan2(startLook.Z, startLook.X)
    local desiredYaw
    if mode == "Back" then
        desiredYaw = math.atan2(lookVec.Z, lookVec.X)
    else
        -- For front mode, aim toward the target's position from our position
        desiredYaw = math.atan2((targetHRP.Position - HRP.Position).Z, (targetHRP.Position - HRP.Position).X)
    end

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

        -- yaw interpolation (only yaw changes)
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
            pcall(function()
                local finalLookVec = (mode == "Back") and Vector3.new(lookVec.X,0,lookVec.Z) or (targetHRP.Position - finalPos)
                finalLookVec = Vector3.new(finalLookVec.X, 0, finalLookVec.Z).Unit
                HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(finalLookVec.X,0,finalLookVec.Z))
            end)
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)

            -- After tween: optionally send M1-like Mobile left click events with editable delay
            if m1AfterTween then
                delay(m1Delay or 0.1, function()
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

            busy = false
        end
    end)
end

-- UI (settings) - same look/behavior as file but without the activation dash button
local function createUI()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("CircularTweenUI") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CircularTweenUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Main container (movable)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0,320,0,300)
    mainFrame.Position = UDim2.new(0.02,0,0.55,0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    mainFrame.BackgroundTransparency = 0
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    mainFrame.AnchorPoint = Vector2.new(0,0)
    mainFrame.ClipsDescendants = true

    local uiCorner = Instance.new("UICorner", mainFrame)
    uiCorner.CornerRadius = UDim.new(0,14)

    -- Top bar (drag)
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1,0,0,36)
    topBar.Position = UDim2.new(0,0,0,0)
    topBar.BackgroundTransparency = 1
    topBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.7,0,1,0)
    title.Position = UDim2.new(0,18,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Dash Assist"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    -- Minimize button (top-right)
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "Minimize"
    minimizeBtn.Size = UDim2.new(0,36,0,28)
    minimizeBtn.Position = UDim2.new(1,-44,0,6)
    minimizeBtn.Text = "◀"
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
    minimizeBtn.TextColor3 = Color3.new(1,1,1)
    minimizeBtn.Parent = topBar
    local minCorner = Instance.new("UICorner", minimizeBtn)
    minCorner.CornerRadius = UDim.new(0,10)

    -- Close / Minimize small button (shown when minimized)
    local miniButton = Instance.new("TextButton")
    miniButton.Name = "MiniOpen"
    miniButton.Size = UDim2.new(0,44,0,44)
    miniButton.Position = UDim2.new(0.02,0,0.6,0) -- same spot as mainFrame initially
    miniButton.Text = ">"
    miniButton.Visible = false
    miniButton.BackgroundColor3 = Color3.fromRGB(18,18,18)
    miniButton.TextColor3 = Color3.new(1,1,1)
    miniButton.Parent = screenGui
    miniButton.ZIndex = 50
    local miniCorner = Instance.new("UICorner", miniButton)
    miniCorner.CornerRadius = UDim.new(0,10)

    -- Player list label
    local playersLabel = Instance.new("TextLabel")
    playersLabel.Name = "PlayersLabel"
    playersLabel.Size = UDim2.new(1,-28,0,22)
    playersLabel.Position = UDim2.new(0,14,0,46)
    playersLabel.BackgroundTransparency = 1
    playersLabel.Text = "Target:"
    playersLabel.Font = Enum.Font.Gotham
    playersLabel.TextSize = 14
    playersLabel.TextColor3 = Color3.fromRGB(200,200,200)
    playersLabel.TextXAlignment = Enum.TextXAlignment.Left
    playersLabel.Parent = mainFrame

    -- ScrollingFrame for players
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "PlayerList"
    scroll.Size = UDim2.new(1,-28,0,120)
    scroll.Position = UDim2.new(0,14,0,74)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 6
    scroll.Parent = mainFrame
    local uiLayout = Instance.new("UIListLayout", scroll)
    uiLayout.Padding = UDim.new(0,8)
    uiLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Find nearest toggle
    local findNearestBtn = Instance.new("TextButton")
    findNearestBtn.Name = "FindNearest"
    findNearestBtn.Size = UDim2.new(0.48,-12,0,36)
    findNearestBtn.Position = UDim2.new(0,14,0,202)
    findNearestBtn.Text = "Find nearest"
    findNearestBtn.Font = Enum.Font.GothamBold
    findNearestBtn.TextSize = 14
    findNearestBtn.BackgroundColor3 = Color3.fromRGB(34,34,34)
    findNearestBtn.TextColor3 = Color3.new(1,1,1)
    findNearestBtn.Parent = mainFrame
    local fnCorner = Instance.new("UICorner", findNearestBtn)
    fnCorner.CornerRadius = UDim.new(0,10)

    local findNearestDot = Instance.new("Frame", findNearestBtn)
    findNearestDot.Name = "Dot"
    findNearestDot.Size = UDim2.new(0,18,0,18)
    findNearestDot.Position = UDim2.new(1,-28,0.5,-9)
    findNearestDot.BackgroundColor3 = Color3.fromRGB(240,240,240)
    findNearestDot.BorderSizePixel = 0
    local dotCorner = Instance.new("UICorner", findNearestDot)
    dotCorner.CornerRadius = UDim.new(1,0)

    -- M1 toggle + Delay textbox
    local m1Btn = Instance.new("TextButton")
    m1Btn.Name = "M1After"
    m1Btn.Size = UDim2.new(0.34,0,0,36)
    m1Btn.Position = UDim2.new(0.52,6,0,202)
    m1Btn.Text = "M1"
    m1Btn.Font = Enum.Font.GothamBold
    m1Btn.TextSize = 14
    m1Btn.BackgroundColor3 = Color3.fromRGB(34,34,34)
    m1Btn.TextColor3 = Color3.new(1,1,1)
    m1Btn.Parent = mainFrame
    local m1Corner = Instance.new("UICorner", m1Btn)
    m1Corner.CornerRadius = UDim.new(0,10)

    local m1Dot = Instance.new("Frame", m1Btn)
    m1Dot.Name = "Dot"
    m1Dot.Size = UDim2.new(0,18,0,18)
    m1Dot.Position = UDim2.new(1,-28,0.5,-9)
    m1Dot.BackgroundColor3 = Color3.fromRGB(240,240,240)
    m1Dot.BorderSizePixel = 0
    local m1DotCorner = Instance.new("UICorner", m1Dot)
    m1DotCorner.CornerRadius = UDim.new(1,0)

    -- M1 Delay label + textbox
    local m1Label = Instance.new("TextLabel")
    m1Label.Name = "M1Label"
    m1Label.Size = UDim2.new(0.3,0,0,22)
    m1Label.Position = UDim2.new(0,14,0,248)
    m1Label.BackgroundTransparency = 1
    m1Label.Text = "M1 Delay (s)"
    m1Label.Font = Enum.Font.Gotham
    m1Label.TextSize = 13
    m1Label.TextColor3 = Color3.fromRGB(180,180,180)
    m1Label.TextXAlignment = Enum.TextXAlignment.Left
    m1Label.Parent = mainFrame

    local m1Box = Instance.new("TextBox")
    m1Box.Name = "M1Box"
    m1Box.Size = UDim2.new(0.2,0,0,26)
    m1Box.Position = UDim2.new(0.35,0,0,246)
    m1Box.BackgroundColor3 = Color3.fromRGB(34,34,34)
    m1Box.TextColor3 = Color3.new(1,1,1)
    m1Box.Font = Enum.Font.Gotham
    m1Box.TextSize = 14
    m1Box.Text = tostring(m1Delay)
    m1Box.ClearTextOnFocus = false
    m1Box.Parent = mainFrame
    local m1BoxCorner = Instance.new("UICorner", m1Box)
    m1BoxCorner.CornerRadius = UDim.new(0,8)

    -- Direction segmented control (Back / Front) - kept visually but automatic selection is used during activation
    local dirLabel = Instance.new("TextLabel")
    dirLabel.Name = "DirLabel"
    dirLabel.Size = UDim2.new(0.2,0,0,22)
    dirLabel.Position = UDim2.new(0.6,0,0,246)
    dirLabel.BackgroundTransparency = 1
    dirLabel.Text = "Dir"
    dirLabel.Font = Enum.Font.Gotham
    dirLabel.TextSize = 13
    dirLabel.TextColor3 = Color3.fromRGB(180,180,180)
    dirLabel.TextXAlignment = Enum.TextXAlignment.Left
    dirLabel.Parent = mainFrame

    local dirBack = Instance.new("TextButton")
    dirBack.Name = "DirBack"
    dirBack.Size = UDim2.new(0,64,0,26)
    dirBack.Position = UDim2.new(0.75,0,0,244)
    dirBack.Text = "Back"
    dirBack.Font = Enum.Font.GothamBold
    dirBack.TextSize = 13
    dirBack.BackgroundColor3 = Color3.fromRGB(60,60,60)
    dirBack.TextColor3 = Color3.new(1,1,1)
    dirBack.Parent = mainFrame
    local dirBackCorner = Instance.new("UICorner", dirBack)
    dirBackCorner.CornerRadius = UDim.new(0,8)

    local dirFront = dirBack:Clone()
    dirFront.Name = "DirFront"
    dirFront.Text = "Front"
    dirFront.Position = UDim2.new(0.9,0,0,244)
    dirFront.Parent = mainFrame

    -- Note: activation button intentionally removed from settings UI here (separate button provided below)

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
    end)
    miniButton.MouseButton1Click:Connect(function()
        mainFrame.Visible = true
        miniButton.Visible = false
    end)

    -- Player list refresh function
    local function refreshPlayerList()
        for _, child in pairs(scroll:GetChildren()) do
            if not child:IsA("UIListLayout") then child:Destroy() end
        end
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local btn = Instance.new("TextButton")
                btn.Name = pl.Name .. "_btn"
                btn.Size = UDim2.new(1, 0, 0, 36)
                btn.BackgroundColor3 = Color3.fromRGB(34,34,34)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 14
                btn.Text = pl.Name
                btn.Parent = scroll
                btn.AutoButtonColor = true
                local btnCorner = Instance.new("UICorner", btn)
                btnCorner.CornerRadius = UDim.new(0,10)
                btn.MouseButton1Click:Connect(function()
                    selectedPlayer = pl
                    -- indicate selection visually
                    for _, c in pairs(scroll:GetChildren()) do
                        if c:IsA("TextButton") then
                            c.BackgroundColor3 = Color3.fromRGB(34,34,34)
                        end
                    end
                    btn.BackgroundColor3 = Color3.fromRGB(70,110,190)
                    findNearestEnabled = false
                    findNearestDot.Visible = false
                end)
            end
        end
        -- update canvas size
        local total = 0
        for _, c in pairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then total = total + c.Size.Y.Offset + uiLayout.Padding.Offset end
        end
        scroll.CanvasSize = UDim2.new(0,0,0,math.max(0,total))
    end

    -- initial fill + update on join/leave
    refreshPlayerList()
    Players.PlayerAdded:Connect(function() refreshPlayerList() end)
    Players.PlayerRemoving:Connect(function(pl)
        if selectedPlayer and selectedPlayer == pl then selectedPlayer = nil end
        refreshPlayerList()
    end)

    -- find nearest toggle
    findNearestBtn.MouseButton1Click:Connect(function()
        findNearestEnabled = not findNearestEnabled
        findNearestDot.Visible = findNearestEnabled
        if findNearestEnabled then
            -- clear selection visuals
            for _, c in pairs(scroll:GetChildren()) do
                if c:IsA("TextButton") then
                    c.BackgroundColor3 = Color3.fromRGB(34,34,34)
                end
            end
            selectedPlayer = nil
        end
    end)
    findNearestDot.Visible = findNearestEnabled

    -- m1 after toggle
    m1Btn.MouseButton1Click:Connect(function()
        m1AfterTween = not m1AfterTween
        m1Dot.Visible = m1AfterTween
    end)
    m1Dot.Visible = m1AfterTween

    -- M1 box editing (validate numeric)
    m1Box.FocusLost:Connect(function(enterPressed)
        local v = tonumber(m1Box.Text)
        if v and v >= 0 then
            m1Delay = v
            m1Box.Text = tostring(m1Delay)
        else
            m1Box.Text = tostring(m1Delay)
        end
    end)

    -- Direction buttons visual toggles (kept but not required for automatic behavior)
    local function updateDirVisuals()
        if directionMode == "Back" then
            dirBack.BackgroundColor3 = Color3.fromRGB(70,110,190)
            dirFront.BackgroundColor3 = Color3.fromRGB(60,60,60)
        else
            dirFront.BackgroundColor3 = Color3.fromRGB(70,110,190)
            dirBack.BackgroundColor3 = Color3.fromRGB(60,60,60)
        end
    end
    dirBack.MouseButton1Click:Connect(function()
        directionMode = "Back"
        updateDirVisuals()
    end)
    dirFront.MouseButton1Click:Connect(function()
        directionMode = "Front"
        updateDirVisuals()
    end)
    updateDirVisuals()

    -- Expose helper to allow immediate ESP update when selection changes
    return {
        UpdateESP = function()
            local target = getESPChosenCharacter()
            if target then
                applyESPToModel(target)
            else
                clearESP()
            end
        end,
        ClearESP = clearESP
    }
end

-- Separate floating dash button (outside settings)
local function createDashButton()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("DashButtonGui") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DashButtonGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local btn = Instance.new("ImageButton")
    btn.Name = "DashBtn"
    btn.Size = UDim2.new(0,60,0,60)
    btn.Position = UDim2.new(0.85,0,0.8,0)
    btn.AnchorPoint = Vector2.new(0.5,0.5)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
    btn.Image = ""
    btn.Parent = screenGui
    local c = Instance.new("UICorner", btn) c.CornerRadius = UDim.new(1,0)

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1,1,0,0)
    icon.Position = UDim2.new(0,0,0,0)
    icon.BackgroundTransparency = 1
    icon.Text = "Dash"
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 14
    icon.TextColor3 = Color3.new(1,1,1)
    icon.Parent = btn

    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    local function updateDrag(input)
        local delta = input.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        local screenW, screenH = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y
        newX = math.clamp(newX, 0, screenW - btn.AbsoluteSize.X)
        newY = math.clamp(newY, 0, screenH - btn.AbsoluteSize.Y)
        btn.Position = UDim2.new(0, newX, 0, newY)
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    btn.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and input == dragInput then updateDrag(input) end end)

    -- Activation on click/tap: automatic front/back selection used
    btn.MouseButton1Click:Connect(function()
        if busy then return end
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
        if chosenCharacter then
            smoothArcTo(chosenCharacter, nil) -- nil to auto choose front/back
        end
    end)

    return btn
end

-- INIT
local uiHelpers = createUI()
createDashButton()

-- ESP updater (throttled)
local lastESPUpdate = 0
RunService.Heartbeat:Connect(function(dt)
    lastESPUpdate = lastESPUpdate + dt
    if lastESPUpdate >= 0.12 then
        lastESPUpdate = 0
        local target = nil
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character.Parent then
            target = selectedPlayer.Character
        elseif findNearestEnabled then
            local t, d = getNearestTarget(ACTIVATION_RANGE)
            if t and d and d <= ACTIVATION_RANGE then target = t end
        end
        if target then
            applyESPToModel(target)
        else
            clearESP()
        end
    end
end)

-- KEYBINDS: PC + Controller "X" (keyboard X kept) + Controller DPadUp as requested
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
        -- Only works if there's a player within ACTIVATION_RANGE (nearest one)
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
        if chosenCharacter then smoothArcTo(chosenCharacter, nil) end -- nil => automatic front/back
    end
end)

print("[CircularTweenUI] Ready - Dash button separate from settings. Front/Back is automatic. Activation range: " .. ACTIVATION_RANGE .. " studs. Arc approach radius: " .. ARC_APPROACH_RADIUS .. " studs.")
