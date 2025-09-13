
-- Smooth Circular Tween to Back + YAW-ONLY Aimlock + Side Animations
-- Executor-friendly, mobile + PC + Controller compatible
-- Circular dash: approaches at ~8 studs then lands 4 studs behind target
-- Aimlock only changes yaw, preserves pitch

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace

-- DEBUGGING safeSetParent: tries multiple parent targets and reports which one worked.
local function safeSetParent(gui)
    local tried = {}
    local function tryAssign(parent)
        if not parent then return false end
        local ok, err = pcall(function() gui.Parent = parent end)
        if ok and gui.Parent == parent then
            return true
        end
        return false
    end

    -- Candidate getters in order of preference for many executors
    local candidates = {}

    -- try gethui() if available (commonly works with many executors)
    if type(gethui) == "function" then
        local ok, g = pcall(function() return gethui() end)
        if ok and g then table.insert(candidates, g) end
    end

    -- try get_hidden_gui()
    if type(get_hidden_gui) == "function" then
        local ok, g = pcall(function() return get_hidden_gui() end)
        if ok and g then table.insert(candidates, g) end
    end

    -- try CoreGui
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then table.insert(candidates, core) end

    -- try PlayerGui (if LocalPlayer exists)
    if LocalPlayer then
        local okPg, pg = pcall(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
        if okPg and pg then table.insert(candidates, pg) end
    end

    -- last attempt: set Parent to CoreGui even if earlier failed
    if okCore and core then table.insert(candidates, core) end

    -- try each candidate
    for _, cand in ipairs(candidates) do
        local success = false
        pcall(function() success = tryAssign(cand) end)
        if success then
            -- ensure gui properties for visibility
            pcall(function()
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.DisplayOrder = 9999
                gui.Enabled = true
            end)
            return cand -- return the parent used
        end
    end

    -- if nothing worked, return nil
    return nil
end


-- Robust GUI parenting helper: tries CoreGui, gethui, get_hidden_gui, then PlayerGui
local function safeSetParent(gui)
    local success = false
    pcall(function() gui.Parent = game:GetService("CoreGui") success = (gui.Parent ~= nil) end)
    if success then return end
    if type(gethui) == "function" then
        pcall(function() gui.Parent = gethui() success = (gui.Parent ~= nil) end)
        if success then return end
    end
    if type(get_hidden_gui) == "function" then
        pcall(function() gui.Parent = get_hidden_gui() success = (gui.Parent ~= nil) end)
        if success then return end
    end
    if LocalPlayer then
        pcall(function() gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 2) success = (gui.Parent ~= nil) end)
        if success then return end
    end
    -- final fallback
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
end


-- REBIND ON RESPAWN
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

-- CONFIG
local MAX_RANGE            = 80
local ARC_APPROACH_RADIUS  =   = 13
local BEHIND_DISTANCE      = 4
local TOTAL_TIME           = 0.22
local AIMLOCK_TIME         = TOTAL_TIME
local MIN_RADIUS           = 1.2
local MAX_RADIUS           = 14

-- Activation requirement per your request:
local ACTIVATION_RANGE = 35 -- changed earlier

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

-- M1 after tween feature flag (UI toggle) -- default ON per request
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

-- helper: safely remove current highlight
local function clearHighlight()
    if currentHighlight then
        pcall(function() currentHighlight:Destroy() end)
        currentHighlight = nil
    end
end

-- helper: update ESP based on selected target and mini visibility
-- Behavior: if a player is explicitly selected (selectedPlayer) -> ESP that player.
-- Otherwise show nearest player when settings are minimized.
local function updateESP(settingsVisible)
    clearHighlight()
    if not espEnabled then return end
    -- only show ESP when settings are minimized (i.e., not visible)
    if settingsVisible then return end

    local targetModel = nil
    -- priority: explicit selection overrides nearest
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        targetModel = selectedPlayer.Character
    else
        local t, d = getNearestTarget(ACTIVATION_RANGE)
        if t then targetModel = t end
    end

    if targetModel and targetModel:IsA("Model") and targetModel:FindFirstChild("Humanoid") and targetModel:FindFirstChild("HumanoidRootPart") then
        local ok, highlight = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "DashAssistTargetHighlight"
            h.Adornee = targetModel
            h.Parent = workspace
            -- red-only highlight per request
            h.FillColor = Color3.fromRGB(255, 40, 40)
            h.OutlineColor = Color3.fromRGB(255, 40, 40)
            h.FillTransparency = 0.8
            h.OutlineTransparency = 0
            return h
        end)
        if ok and highlight then
            currentHighlight = highlight
        end
    end
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
    local lookVec = targetHRP.CFrame.LookVector
    local finalPos = center - lookVec * BEHIND_DISTANCE
    finalPos = Vector3.new(finalPos.X, center.Y + 1.5, finalPos.Z)
    local startRadius = (Vector3.new(myPos.X,0,myPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local midRadius   = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius   = (Vector3.new(finalPos.X,0,finalPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local startAngle = math.atan2(myPos.Z-center.Z, myPos.X-center.X)
    local endAngle   = math.atan2(finalPos.Z-center.Z, finalPos.X-center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)
    local isLeft = (deltaAngle > 0)
    pcall(function() playSideAnimation(isLeft) end)

    -- schedule M1 based on configured delay — we schedule on activation detection (start of tween)
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
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
            busy = false
        end
    end)
end

-- Create a separate Dash activation button (NOT inside settings)
local function createDashButton()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("DashButtonGui") if old then old:Destroy() end end)
    local gui = Instance.new("ScreenGui")
    gui.Name = "DashButtonGui"
    gui.ResetOnSpawn = false
    safeSetParent(gui)

    local button = Instance.new("ImageButton")
    button.Name = "DashControlButton"
    button.Size = UDim2.new(0,110,0,110)
    button.Position = UDim2.new(0.5,-55,0.82,-55)
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

    -- drag for the dash button itself so it won't move with settings
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
            -- activation uses settings selection or nearest within range
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

-- UI (settings) - fixed layout so Delay box and M1 button don't collide; ESP button placed under M1 button and styled like M1
local function createSettingsUI()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("Dash Assist Settings") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Dash Assist Settings"
    screenGui.ResetOnSpawn = false
    safeSetParent(screenGui)

    -- Main container (movable) - slightly larger to fit all controls
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0,240,0,260) -- increased height to fit rearranged controls
    mainFrame.Position = UDim2.new(0.02,0,0.55,0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18,18,20)
    mainFrame.BackgroundTransparency = 0
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    mainFrame.AnchorPoint = Vector2.new(0,0)
    mainFrame.ClipsDescendants = true

    -- Subtle stroke for crisp separation
    local uiStroke = Instance.new("UIStroke", mainFrame)
    uiStroke.Thickness = 1
    uiStroke.Transparency = 0.78
    uiStroke.Color = Color3.fromRGB(70,70,80)

    -- Rounded corners (soft edges)
    local uiCorner = Instance.new("UICorner", mainFrame)
    uiCorner.CornerRadius = UDim.new(0,6)

    -- Top bar (drag)
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1,0,0,32)
    topBar.Position = UDim2.new(0,0,0,0)
    topBar.BackgroundTransparency = 1
    topBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.7,0,1,0)
    title.Position = UDim2.new(0,12,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Dash Assist Settings"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.Arcade
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    -- Minimize button (top-right) - soft edges
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "Minimize"
    minimizeBtn.Size = UDim2.new(0,30,0,24)
    minimizeBtn.Position = UDim2.new(1,-38,0,4)
    minimizeBtn.Text = "-"
    minimizeBtn.Font = Enum.Font.Arcade
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = topBar
    local minCorner = Instance.new("UICorner", minimizeBtn)
    minCorner.CornerRadius = UDim.new(0,6)

    -- Close / Minimize small button (shown when minimized)
    local miniButton = Instance.new("TextButton")
    miniButton.Name = "MiniOpen"
    miniButton.Size = UDim2.new(0,40,0,40)

    -- position from saved data if available
    local savedX = dataFolder:FindFirstChild("miniX")
    local savedY = dataFolder:FindFirstChild("miniY")
    if savedX and savedY then
        miniButton.Position = UDim2.new(0, savedX.Value, 0, savedY.Value)
    else
        miniButton.Position = UDim2.new(0.02,0,0.55,0)
    end

    miniButton.Text = ">"
    miniButton.Visible = false
    miniButton.BackgroundColor3 = Color3.fromRGB(24,24,26)
    miniButton.TextColor3 = Color3.new(1,1,1)
    miniButton.Parent = screenGui
    miniButton.ZIndex = 50
    local miniCorner = Instance.new("UICorner", miniButton)
    miniCorner.CornerRadius = UDim.new(0,6)
    local miniStroke = Instance.new("UIStroke", miniButton)
    miniStroke.Thickness = 1
    miniStroke.Transparency = 0.8
    miniStroke.Color = Color3.fromRGB(70,70,80)

    -- Player list label
    local playersLabel = Instance.new("TextLabel")
    playersLabel.Name = "PlayersLabel"
    playersLabel.Size = UDim2.new(1,-16,0,20)
    playersLabel.Position = UDim2.new(0,12,0,40)
    playersLabel.BackgroundTransparency = 1
    playersLabel.Text = "Target Player:"
    playersLabel.Font = Enum.Font.Arcade
    playersLabel.TextSize = 12
    playersLabel.TextColor3 = Color3.fromRGB(200,200,200)
    playersLabel.TextXAlignment = Enum.TextXAlignment.Left
    playersLabel.Parent = mainFrame

    -- ScrollingFrame for players
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "PlayerList"
    scroll.Size = UDim2.new(1,-24,0,80)
    scroll.Position = UDim2.new(0,12,0,48)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 6
    scroll.Parent = mainFrame
    local uiLayout = Instance.new("UIListLayout", scroll)
    uiLayout.Padding = UDim.new(0,6)
    uiLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Find nearest toggle
    local findNearestBtn = Instance.new("TextButton")
    findNearestBtn.Name = "FindNearest"
    findNearestBtn.Size = UDim2.new(0.48,-12,0,34)
    findNearestBtn.Position = UDim2.new(0,12,0,132)
    findNearestBtn.Text = "Find nearest: ON"
    findNearestBtn.Font = Enum.Font.Arcade
    findNearestBtn.TextSize = 12
    findNearestBtn.BackgroundColor3 = Color3.fromRGB(42,42,48)
    findNearestBtn.TextColor3 = Color3.new(1,1,1)
    findNearestBtn.Parent = mainFrame
    findNearestBtn.AutoButtonColor = true
    local findNearestCorner = Instance.new("UICorner", findNearestBtn)
    findNearestCorner.CornerRadius = UDim.new(0,6)
    local findNearestStroke = Instance.new("UIStroke", findNearestBtn)
    findNearestStroke.Thickness = 1
    findNearestStroke.Transparency = 0.8
    findNearestStroke.Color = Color3.fromRGB(70,70,80)

    -- M1 after tween toggle (label changed to M1: On/Off) — default ON
    local m1Btn = Instance.new("TextButton")
    m1Btn.Name = "M1After"
    m1Btn.Size = UDim2.new(0.48,-12,0,34)
    m1Btn.Position = UDim2.new(0.52,2,0,132)
    m1Btn.Text = "M1: On"
    m1Btn.Font = Enum.Font.Arcade
    m1Btn.TextSize = 12
    m1Btn.BackgroundColor3 = Color3.fromRGB(42,42,48)
    m1Btn.TextColor3 = Color3.new(1,1,1)
    m1Btn.Parent = mainFrame
    m1Btn.AutoButtonColor = true
    local m1Corner = Instance.new("UICorner", m1Btn)
    m1Corner.CornerRadius = UDim.new(0,6)
    local m1Stroke = Instance.new("UIStroke", m1Btn)
    m1Stroke.Thickness = 1
    m1Stroke.Transparency = 0.8
    m1Stroke.Color = Color3.fromRGB(70,70,80)

    -- ESP toggle (made same style as M1 button, placed below M1)
    local espBtn = Instance.new("TextButton")
    espBtn.Name = "EspToggle"
    espBtn.Size = UDim2.new(0.48,-12,0,34)
    espBtn.Position = UDim2.new(0.52,2,0,168) -- below M1 button
    espBtn.Text = "Esp: Off"
    espBtn.Font = Enum.Font.Arcade
    espBtn.TextSize = 12
    espBtn.BackgroundColor3 = Color3.fromRGB(42,42,48)
    espBtn.TextColor3 = Color3.new(1,1,1)
    espBtn.Parent = mainFrame
    espBtn.AutoButtonColor = true
    local espCorner = Instance.new("UICorner", espBtn)
    espCorner.CornerRadius = UDim.new(0,6)
    local espStroke = Instance.new("UIStroke", espBtn)
    espStroke.Thickness = 1
    espStroke.Transparency = 0.8
    espStroke.Color = Color3.fromRGB(70,70,80)

    -- M1 delay label + input (moved below ESP)
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Name = "DelayLabel"
    delayLabel.Size = UDim2.new(0.5, -16, 0, 20)
    delayLabel.Position = UDim2.new(0,12,0,200)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Text = "M1 Delay (s):"
    delayLabel.Font = Enum.Font.Arcade
    delayLabel.TextSize = 12
    delayLabel.TextColor3 = Color3.fromRGB(200,200,200)
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = mainFrame

    local delayBox = Instance.new("TextBox")
    delayBox.Name = "DelayBox"
    delayBox.Size = UDim2.new(0.28, -12, 0, 26)
    delayBox.Position = UDim2.new(0.5, 2, 0, 196)
    delayBox.Text = tostring(m1DelayValue)
    delayBox.Font = Enum.Font.Arcade
    delayBox.TextSize = 12
    delayBox.ClearTextOnFocus = false
    delayBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    delayBox.TextColor3 = Color3.new(1,1,1)
    delayBox.Parent = mainFrame
    local dbCorner = Instance.new("UICorner", delayBox)
    dbCorner.CornerRadius = UDim.new(0,6)

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = mainFrame

    
    -- Dragging mainFrame (fixed: use AbsolutePosition so vertical movement works on mobile)
    local dragging = false
    local dragInput, dragStartPos, startAbsPos

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStartPos = input.Position
            startAbsPos = Vector2.new(mainFrame.AbsolutePosition.X, mainFrame.AbsolutePosition.Y)

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
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
        if input ~= dragInput or not dragging or not dragStartPos or not startAbsPos then return end
        local delta = input.Position - dragStartPos
        local newX = startAbsPos.X + delta.X
        local newY = startAbsPos.Y + delta.Y

        local screenW = workspace.CurrentCamera.ViewportSize.X
        local screenH = workspace.CurrentCamera.ViewportSize.Y

        local frameW = mainFrame.AbsoluteSize.X
        local frameH = mainFrame.AbsoluteSize.Y

        newX = math.clamp(newX, 0, math.max(0, screenW - frameW))
        newY = math.clamp(newY, 0, math.max(0, screenH - frameH))

        mainFrame.Position = UDim2.new(0, math.floor(newX), 0, math.floor(newY))
    end)
-- Minimize behavior (minimizes settings to a 40x40 button; dash button unaffected)
    local isMiniDragging = false
    minimizeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        miniButton.Visible = true
        -- move miniButton to same place mainFrame was for UX
        miniButton.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
        -- save position
        local vX = dataFolder:FindFirstChild("miniX")
        local vY = dataFolder:FindFirstChild("miniY")
        if not vX then vX = Instance.new("NumberValue", dataFolder) vX.Name = "miniX" end
        if not vY then vY = Instance.new("NumberValue", dataFolder) vY.Name = "miniY" end
        vX.Value = miniButton.AbsolutePosition.X
        vY.Value = miniButton.AbsolutePosition.Y
        -- update ESP visibility when minimized
        updateESP(false)
    end)
    miniButton.MouseButton1Click:Connect(function()
        -- if it was a click (not drag), open settings
        if not isMiniDragging then
            mainFrame.Visible = true
            miniButton.Visible = false
            -- clear highlight when settings open
            clearHighlight()
        end
    end)

    -- Make the minimized miniButton draggable (so user can move the 40x40 button)
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
                -- save position persistently
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
        -- reset states; click handling already in MouseButton1Click with check
        isMiniPointerDown = false
        trackedMiniInput = nil
        -- small delay to ensure click detection works
        wait(0.03)
        isMiniDragging = false
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
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.Font = Enum.Font.Arcade
                btn.TextSize = 11
                btn.Text = pl.Name
                btn.Parent = scroll
                btn.AutoButtonColor = true
                local bcorner = Instance.new("UICorner", btn)
                bcorner.CornerRadius = UDim.new(0,5)
                local bstroke = Instance.new("UIStroke", btn)
                bstroke.Thickness = 1
                bstroke.Transparency = 0.8
                bstroke.Color = Color3.fromRGB(70,70,80)
                btn.MouseButton1Click:Connect(function()
                    selectedPlayer = pl
                    -- indicate selection visually
                    for _, c in pairs(scroll:GetChildren()) do
                        if c:IsA("TextButton") then
                            c.BackgroundColor3 = Color3.fromRGB(40,40,40)
                        end
                    end
                    btn.BackgroundColor3 = Color3.fromRGB(80,120,200)
                    findNearestEnabled = false
                    findNearestBtn.Text = "Find nearest: OFF"
                end)
            end
        end
        -- update canvas size
        local total = 0
        for _, c in pairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then total = total + c.Size.Y.Offset + 6 end
        end
        scroll.CanvasSize = UDim2.new(0,0,0,math.max(0,total))
    end

    -- initial fill + update on join/leave
    refreshPlayerList()
    Players.PlayerAdded:Connect(function() refreshPlayerList() end)
    Players.PlayerRemoving:Connect(function()
        if selectedPlayer and selectedPlayer.Parent == nil then selectedPlayer = nil end
        refreshPlayerList()
    end)

    -- find nearest toggle
    findNearestBtn.MouseButton1Click:Connect(function()
        findNearestEnabled = not findNearestEnabled
        findNearestBtn.Text = "Find nearest: " .. (findNearestEnabled and "ON" or "OFF")
        if findNearestEnabled then
            -- clear selection visuals
            for _, c in pairs(scroll:GetChildren()) do
                if c:IsA("TextButton") then
                    c.BackgroundColor3 = Color3.fromRGB(40,40,40)
                end
            end
            selectedPlayer = nil
        end
    end)

    -- m1 after toggle (label changed)
    m1Btn.MouseButton1Click:Connect(function()
        m1AfterTween = not m1AfterTween
        m1Btn.Text = "M1: " .. (m1AfterTween and "On" or "Off")
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

    -- ESP toggle
    espBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espBtn.Text = "Esp: " .. (espEnabled and "On" or "Off")
        if espEnabled then
            -- when turning ESP on default to nearest target (per request)
            selectedPlayer = nil
            findNearestEnabled = true
            findNearestBtn.Text = "Find nearest: ON"
            if not mainFrame.Visible then
                updateESP(false)
            end
        else
            clearHighlight()
        end
    end)
end

-- INIT UIs
createDashButton()
createSettingsUI()

-- Live ESP updater: when settings visibility changes or players move, update highlight
RunService.Heartbeat:Connect(function()
    local settingsGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Dash Assist Settings")
    if settingsGui then
        local main = settingsGui:FindFirstChild("MainFrame")
        if main then
            local visible = main.Visible
            -- update ESP only when minimized (visible == false) and espEnabled true
            if not visible and espEnabled then
                -- refresh highlight target each tick to follow moving players
                clearHighlight()
                updateESP(false)
            else
                clearHighlight()
            end
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
        if chosenCharacter then smoothArcToBack(chosenCharacter) end
    end
end)

print("[Dash Assist Settings] Ready - Dash button (separate) + X keybind + Gamepad DPadUp active. Activation requires a player within " .. ACTIVATION_RANGE .. " studs.")

-- === Discord notification UI (Merebennie) ===
local DISCORD_LINK = "https://discord.gg/RsxcaHhRqb"

-- === GUI container ===
local DiscordGui = Instance.new("ScreenGui")
DiscordGui.Name = "Merebennie_DiscordUI"
DiscordGui.ResetOnSpawn = false
DiscordGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
DiscordGui.IgnoreGuiInset = true
DiscordGui.DisplayOrder = 10000
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
safeSetParent(DiscordGui)

-- Button click sound
local ButtonClickSound = Instance.new("Sound")
ButtonClickSound.Name = "ButtonClickSound"
ButtonClickSound.SoundId = "rbxassetid://6042053626"
ButtonClickSound.Volume = 1
ButtonClickSound.Looped = false
ButtonClickSound.Parent = DiscordGui

-- === Smooth sliding notification ===
local function showNotif()
    -- remove previous if exists
    pcall(function()
        local old = DiscordGui:FindFirstChild("MerebennieNotification")
        if old then old:Destroy() end
    end)

    local notif = Instance.new("Frame")
    notif.Name = "MerebennieNotification"
    notif.Size = UDim2.new(0, 320, 0, 72)
    local centerPos = UDim2.new(0.5, -160, 0.5, -36)
    local offscreenPos = UDim2.new(0.5, -160, 0, -140)
    notif.Position = offscreenPos
    notif.AnchorPoint = Vector2.new(0.5, 0.5)
    notif.BackgroundColor3 = Color3.fromRGB(22,22,22)
    notif.BackgroundTransparency = 1
    notif.ZIndex = 10005
    notif.Parent = DiscordGui

    local corner = Instance.new("UICorner", notif)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", notif)
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(10,10,10)
    stroke.Transparency = 0.7

    local title = Instance.new("TextLabel", notif)
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.ArcadeBold
    title.Text = "Made by Merebennie"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextScaled = true
    title.TextTransparency = 1
    title.ZIndex = 10006

    local body = Instance.new("TextLabel", notif)
    body.Name = "Body"
    body.Size = UDim2.new(1, -20, 0, 40)
    body.Position = UDim2.new(0, 10, 0, 28)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Arcade
    body.Text = "Discord: "..DISCORD_LINK.."\nThis script is made by Merebennie on YouTube. Join our discord for more scripts"
    body.TextColor3 = Color3.fromRGB(255,255,255)
    body.TextWrapped = true
    body.TextScaled = false
    body.TextSize = 14
    body.TextTransparency = 1
    body.ZIndex = 10006
    body.Active = true

    -- Tweens
    local inTweenInfo = TweenInfo.new(0.48, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local outTweenInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    local inTween = TweenService:Create(notif, inTweenInfo, {Position = centerPos, BackgroundTransparency = 0, Size = UDim2.new(0, 320, 0, 72)})
    local outTween = TweenService:Create(notif, outTweenInfo, {Position = offscreenPos, BackgroundTransparency = 1, Size = UDim2.new(0, 240, 0, 44)})

    local titleTween = TweenService:Create(title, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
    local bodyTween = TweenService:Create(body, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})

    -- Play animations
    inTween:Play()
    task.delay(0.06, function() titleTween:Play() end)
    task.delay(0.12, function() bodyTween:Play() end)

    -- Click-to-copy
    local originalBody = body.Text
    local clicked = false
    body.InputBegan:Connect(function(input)
        if clicked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            clicked = true
            local ok = false
            pcall(function()
                if setclipboard then
                    setclipboard(DISCORD_LINK)
                    ok = true
                end
            end)
            if ok then
                body.Text = "Copied!"
            else
                body.Text = "Copy this link: "..DISCORD_LINK
            end
            -- play click sound
            pcall(function() ButtonClickSound:Play() end)
            task.delay(1.5, function()
                if body and body.Parent then body.Text = originalBody end
                clicked = false
            end)
        end
    end)

    -- Auto-dismiss after 4s
    task.delay(4, function()
        if outTween then
            outTween:Play()
            outTween.Completed:Wait()
        end
        pcall(function() notif:Destroy() end)
    end)
end

-- Show notification once
pcall(function() showNotif() end)


-- DEBUG: show big on-screen message telling which parent was used (or if none)
pcall(function()
    -- find any ScreenGui we created
    local gui = nil
    local tryNames = {"Dash Assist Settings", "DashButtonGui", "Merebennie_DiscordUI", "DashButtonGui"}
    for _, name in ipairs(tryNames) do
        local g = game:GetService("CoreGui"):FindFirstChild(name)
        if g then gui = g break end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            g = LocalPlayer.PlayerGui:FindFirstChild(name)
            if g then gui = g break end
        end
        if type(gethui) == "function" then
            local ok, hidden = pcall(function() return gethui() end)
            if ok and hidden then
                g = hidden:FindFirstChild(name)
                if g then gui = g break end
            end
        end
    end

    local parentUsed = "none"
    if gui and gui.Parent then
        parentUsed = tostring(gui.Parent.ClassName or gui.Parent.Name or "Parent")
    else
        for _, sg in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if sg:IsA("ScreenGui") and (sg.Name:match("Dash") or sg.Name:match("Dash Assist")) then
                parentUsed = "CoreGui"
                gui = sg
                break
            end
        end
    end

    local dbgGui = Instance.new("ScreenGui")
    dbgGui.Name = "DashAssist_DebugOverlay"
    dbgGui.ResetOnSpawn = false
    dbgGui.IgnoreGuiInset = true
    dbgGui.DisplayOrder = 99999
    -- attempt to parent debug GUI
    local ok = pcall(function() dbgGui.Parent = (gethui and gethui() or game:GetService("CoreGui")) end)

    local frame = Instance.new("Frame", dbgGui)
    frame.AnchorPoint = Vector2.new(0.5,0.5)
    frame.Position = UDim2.new(0.5, 0, 0.12, 0)
    frame.Size = UDim2.new(0, 520, 0, 44)
    frame.BackgroundTransparency = 0.35
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BorderSizePixel = 0

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.TextScaled = false
    label.Text = "Dash UI parent: " .. tostring(parentUsed)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 20
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextStrokeTransparency = 0.6
    label.TextWrapped = true
end)
