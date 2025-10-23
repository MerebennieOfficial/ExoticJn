
-- Merged: Circular Dash + Settings V2 (with Dash controls and Discord copy)
-- Single standalone LocalScript combining the circular/spin dash behavior and the Settings UI.
-- Changes:
--  * M1 and Dash toggles no longer fire remote immediately when toggled; they act as flags.
--  * When a circular spin actually starts, if the toggles are enabled the script will fire the corresponding payloads.
--  * The three Dash sliders influence the spin: Dash speed -> spin duration, Dash Degrees -> total spin degrees, Dash gap -> orbit radius.
--  * Discord button copies the provided invite (uses setclipboard when available, otherwise stores attribute).
-- NOTE: Keep this script as a LocalScript in StarterPlayerScripts or a similar client-side context.

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local workspace = workspace

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

math.randomseed(tick() % 65536)

-- Character refs (auto-update on respawn)
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:FindFirstChildOfClass("Humanoid")
end)

-- Animation sets (same as original)
local placeId = game.PlaceId
local AnimationSets = {
    [10449761463] = { -- The Strongest Battlegrounds
        Left  = 10480796021,
        Right = 10480793962,
        Straight = 10479335397,
    },
    [13076380114] = { -- MOVES Heroes Battlegrounds
        Left  = 101843860692381,
        Right = 100087324592640,
        Straight = 110878031211717,
    },
}
local DefaultSet = AnimationSets[13076380114]
local CurrentSet = AnimationSets[placeId] or DefaultSet
local ANIM_LEFT_ID, ANIM_RIGHT_ID = CurrentSet.Left, CurrentSet.Right
local STRAIGHT_ANIM_ID = CurrentSet.Straight

-- Default dash parameters (these will be overridden by sliders when available)
local MAX_RANGE = 40
local ORBIT_RADIUS_MIN, ORBIT_RADIUS_MAX = 4, 5
local MIN_RADIUS, MAX_RADIUS = 1.2, 60
local STRAIGHT_START_DIST, ORBIT_TRIGGER_DIST = 15, 10
local STRAIGHT_SPEED = 120
local AimSpeed = 0.7
local POST_CAMERA_AIM_DURATION = 0.7
local POST_CAMERA_PREDICT_TIME = 0.5
local POST_CAMERA_SNAPPINESS = 200
local AIMLOCK_TRIGGER_DEGREES = 390
local AIMLOCK_TRIGGER_FRACTION = AIMLOCK_TRIGGER_DEGREES / 480

local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID = "rbxassetid://72014632956520"

-- Busy/flags
local busy, currentAnimTrack, lastActivated = false, nil, -math.huge

-- Sound
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

-- Utility functions
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
    delay( (TOTAL_TIME or 0.45) + 0.15, function()
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

local function smoothFaceCameraTowards(targetPos, speed)
    speed = speed or 0.7
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

-- STRAIGHT DASH PHASE (unchanged behavior)
local function dashStraightToTarget(targetHRP, straightSpeed)
    straightSpeed = straightSpeed or STRAIGHT_SPEED
    local attach = Instance.new("Attachment")
    attach.Name = "DashAttach"
    attach.Parent = HRP

    local lv = Instance.new("LinearVelocity")
    lv.Name = "DashLinearVelocity"
    lv.Attachment0 = attach
    lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = HRP

    local straightAnimObj, straightAnimTrack
    if STRAIGHT_ANIM_ID then
        local hum, animator = ensureHumanoidAndAnimator()
        if hum and animator then
            local anim = Instance.new("Animation")
            anim.Name = "StraightDashAnim"
            anim.AnimationId = "rbxassetid://" .. tostring(STRAIGHT_ANIM_ID)
            local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
            if ok and track then
                straightAnimObj = anim
                straightAnimTrack = track
                straightAnimTrack.Priority = Enum.AnimationPriority.Movement
                pcall(function() straightAnimTrack.Looped = true end)
                pcall(function() straightAnimTrack:Play() end)
            else
                pcall(function() anim:Destroy() end)
            end
        end
    end

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
            pcall(function()
                if straightAnimTrack and straightAnimTrack.IsPlaying then straightAnimTrack:Stop() end
                if straightAnimObj then straightAnimObj:Destroy() end
            end)
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
            pcall(function()
                if straightAnimTrack and straightAnimTrack.IsPlaying then straightAnimTrack:Stop() end
                if straightAnimObj then straightAnimObj:Destroy() end
            end)
            return
        end
        local velocity = (flat.Unit) * straightSpeed
        lv.VectorVelocity = velocity
        pcall(function()
            if flat.Magnitude > 0.001 then
                HRP.CFrame = CFrame.new(HRP.Position, HRP.Position + flat.Unit)
            end
        end)
        pcall(function()
            smoothFaceCameraTowards(targetPos, 0.7 * 0.8)
        end)
    end)

    repeat task.wait() until reached or not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent
end

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
        local e = 1 - (1 - t) ^ math.max(1, POST_CAMERA_SNAPPINESS)
        local targetPos = targetHRP.Position
        local vel = Vector3.new(0,0,0)
        pcall(function() vel = targetHRP:GetVelocity() or targetHRP.Velocity or Vector3.new(0,0,0) end)
        local flatVel = Vector3.new(vel.X, 0, vel.Z)
        local predictedPos = targetPos + flatVel * POST_CAMERA_PREDICT_TIME
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

-- ---------- Settings GUI side variables & helpers ----------
-- These are taken/adapted from the SettingsV2 file and integrated.

-- Dashboard slider storage (persist in-memory across panel open/close)
local Sliders = {}
local currentSliderValues = {
    ["Dash speed"] = nil,
    ["Dash Degrees"] = nil,
    ["Dash gap"] = nil,
}

-- Load saved settings from Player attribute if present
local savedSettings = nil
do
    local attr = LocalPlayer:GetAttribute("SettingsV2")
    if type(attr) == "string" then
        pcall(function()
            savedSettings = HttpService:JSONDecode(attr)
            if savedSettings and savedSettings.Sliders then
                for k,v in pairs(savedSettings.Sliders) do
                    local num = tonumber(v)
                    if num then
                        currentSliderValues[k] = math.clamp(math.floor(num), 0, 100)
                    end
                end
            end
        end)
    end
end

-- Safe remote fire helper (keeps original behavior if the user's environment has a Communicate remote)
local function safeFireCommunicate(argsTable)
    pcall(function()
        local ch = LocalPlayer.Character
        if ch and ch:FindFirstChild("Communicate") then
            ch.Communicate:FireServer(unpack(argsTable))
        end
    end)
end

-- Toggle flags (these are set by settings GUI toggles; they no longer auto-fire when changed)
local m1Enabled = false
local espEnabled = false
local selectedPlayer = nil

-- Create UI for Settings (merged)
local gui = Instance.new("ScreenGui")
gui.Name = "SettingsGUI_Only_V2_Merged"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6042053626"
clickSound.Volume = 0.7
clickSound.Parent = gui

local function makeDraggable(frame)
    local dragToggle, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragToggle = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragToggle and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                        startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function createToggleButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 15, 0, 15)
    circle.Position = UDim2.new(1, -24, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local toggled = false

    local function updateVisuals()
        circle.BackgroundColor3 = toggled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(180, 180, 180)
        btn.BackgroundColor3 = toggled and Color3.fromRGB(220,220,220) or Color3.fromRGB(245,245,245)
    end

    local function setState(state, runCallback)
        toggled = not not state
        updateVisuals()
        if runCallback and callback then
            pcall(function() callback(toggled) end)
        end
    end

    btn.MouseButton1Click:Connect(function()
        pcall(function() clickSound:Play() end)
        setState(not toggled, true)
    end)

    return btn, setState
end

-- MAIN SETTINGS FRAME (looks like original V2)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 280, 0, 270)
mainFrame.Position = UDim2.new(0.5, -140, 0.5, -135)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderSizePixel = 2
mainFrame.AnchorPoint = Vector2.new(0.5,0.5)
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
mainFrame.Visible = true
mainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
{Size = UDim2.new(0, 280, 0, 270)}):Play()

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
title.BackgroundTransparency = 0
title.Text = "⚙️ Settings V2"
title.TextColor3 = Color3.fromRGB(0, 0, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 35, 0, 35)
minimizeBtn.Position = UDim2.new(1, -40, 0, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Text = "-"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextColor3 = Color3.fromRGB(0,0,0)
minimizeBtn.TextSize = 20
minimizeBtn.Parent = mainFrame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(1, 0)
minimizeBtn.AutoButtonColor = false

local buttonHolder = Instance.new("Frame")
buttonHolder.Size = UDim2.new(1, -20, 0, 90)
buttonHolder.Position = UDim2.new(0, 10, 0, 45)
buttonHolder.BackgroundTransparency = 1
buttonHolder.Parent = mainFrame

local UIGrid = Instance.new("UIGridLayout")
UIGrid.CellSize = UDim2.new(0.5, -10, 0, 35)
UIGrid.CellPadding = UDim2.new(0, 10, 0, 10)
UIGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIGrid.VerticalAlignment = Enum.VerticalAlignment.Top
UIGrid.Parent = buttonHolder

-- Create toggles but do NOT fire remote immediately; they only set flags
local m1Btn, m1SetState = createToggleButton("M1", function(state)
    m1Enabled = state
end)
m1Btn.Parent = buttonHolder

local espBtn, espSetState = createToggleButton("Dash", function(state)
    espEnabled = state
end)
espBtn.Parent = buttonHolder

-- Discord button (replaces Save)
local discordInviteUrl = "https://discord.gg/5x4xbPvuSc"
local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0, 100, 0, 35)
discordBtn.BackgroundColor3 = Color3.fromRGB(245,245,245)
discordBtn.Text = "Discord"
discordBtn.TextColor3 = Color3.fromRGB(0,0,0)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = 14
discordBtn.AutoButtonColor = false
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,8)
discordBtn.Parent = buttonHolder

discordBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    local success = false
    pcall(function()
        if setclipboard then
            setclipboard(discordInviteUrl)
            success = true
        end
    end)
    if not success then
        pcall(function() LocalPlayer:SetAttribute("LastDiscordInvite", discordInviteUrl) end)
    end
    local oldText = discordBtn.Text
    discordBtn.Text = success and "Copied" or "Stored"
    task.delay(0.9, function()
        pcall(function() discordBtn.Text = oldText end)
    end)
end)

-- PLAYER LIST
local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, -20, 0, 70)
playerList.Position = UDim2.new(0, 10, 0, 145)
playerList.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
playerList.ScrollBarThickness = 4
playerList.Parent = mainFrame
Instance.new("UICorner", playerList).CornerRadius = UDim.new(0, 8)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = playerList
UIListLayout.Padding = UDim.new(0, 2)

local function refreshPlayers()
    for _, child in ipairs(playerList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -5, 0, 22)
            btn.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
            btn.TextColor3 = Color3.fromRGB(0,0,0)
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.Text = "   " .. plr.Name
            btn.Parent = playerList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

            btn.MouseButton1Click:Connect(function()
                pcall(function() clickSound:Play() end)
                for _, b in ipairs(playerList:GetChildren()) do
                    if b:IsA("TextButton") then
                        b.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
                    end
                end
                btn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
                selectedPlayer = plr
            end)
        end
    end
end
refreshPlayers()

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 110, 0, 36)
refreshBtn.Position = UDim2.new(1, -122, 1, -44)
refreshBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 16
refreshBtn.Parent = mainFrame
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 12)
refreshBtn.AutoButtonColor = false

local adjustBtn = Instance.new("TextButton")
adjustBtn.Size = UDim2.new(0, 110, 0, 36)
adjustBtn.Position = UDim2.new(0, 12, 1, -44)
adjustBtn.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
adjustBtn.Text = "Adjust"
adjustBtn.TextColor3 = Color3.fromRGB(255,255,255)
adjustBtn.Font = Enum.Font.GothamBold
adjustBtn.TextSize = 16
adjustBtn.Parent = mainFrame
Instance.new("UICorner", adjustBtn).CornerRadius = UDim.new(0, 12)
adjustBtn.AutoButtonColor = false

refreshBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    refreshPlayers()
end)

-- mini frame and minimize behavior
local miniFrame = Instance.new("TextButton")
miniFrame.Size = UDim2.new(0, 60, 0, 35)
miniFrame.Position = UDim2.new(0.5, -30, 0.5, -17)
miniFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
miniFrame.Text = "Settings"
miniFrame.TextColor3 = Color3.fromRGB(0,0,0)
miniFrame.Font = Enum.Font.GothamBold
miniFrame.TextSize = 14
miniFrame.Visible = false
miniFrame.Parent = gui
miniFrame.BorderSizePixel = 2
miniFrame.BorderColor3 = Color3.fromRGB(0,0,0)
Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(0, 10)
miniFrame.AutoButtonColor = false

local function pressAnim(button, cb)
    button.MouseButton1Click:Connect(function()
        button:TweenSize(button.Size - UDim2.new(0,5,0,5), "Out", "Quad", 0.08, true, function()
            button:TweenSize(button.Size + UDim2.new(0,5,0,5), "Out", "Quad", 0.08)
            if cb then cb() end
        end)
    end)
end

pressAnim(minimizeBtn, function()
    pcall(function() clickSound:Play() end)
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    {Size = UDim2.new(0, 0, 0, 0)})
    tween:Play()
    tween.Completed:Wait()
    mainFrame.Visible = false
    miniFrame.Visible = true
end)

pressAnim(miniFrame, function()
    pcall(function() clickSound:Play() end)
    miniFrame.Visible = false
    mainFrame.Visible = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Size = UDim2.new(0, 280, 0, 270)}):Play()
end)

makeDraggable(mainFrame)
makeDraggable(miniFrame)

-- DASH SETTINGS PANEL (centered small panel, re-created on toggle)
local dashGui
local function createDashPanel()
    if dashGui and dashGui.Parent then
        dashGui:Destroy()
        dashGui = nil
        return
    end

    dashGui = Instance.new("ScreenGui")
    dashGui.Name = "DashSettingsGui_Merged"
    dashGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    dashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainFrame = Instance.new("Frame")
    MainFrame.Parent = dashGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.Size = UDim2.new(0, 220, 0, 220)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Active = true
    makeDraggable(MainFrame)

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 14)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Parent = MainFrame
    UIStroke.Color = Color3.fromRGB(255, 255, 255)
    UIStroke.Thickness = 1
    UIStroke.Transparency = 0.5

    local CloseButton = Instance.new("TextButton")
    local CloseCorner = Instance.new("UICorner")
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    CloseButton.Position = UDim2.new(0.82, 0, 0.05, 0)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextScaled = true
    CloseButton.AutoButtonColor = false
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        pcall(function() clickSound:Play() end)
        if dashGui and dashGui.Parent then
            dashGui:Destroy()
            dashGui = nil
        end
    end)

    -- Sliders
    local TitleLabels = {"Dash speed", "Dash Degrees", "Dash gap"}
    for i, name in ipairs(TitleLabels) do
        local Label = Instance.new("TextLabel")
        local SliderFrame = Instance.new("Frame")
        local SliderBar = Instance.new("Frame")
        local SliderButton = Instance.new("TextButton")
        local SliderBarCorner = Instance.new("UICorner")

        Label.Parent = MainFrame
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.Font = Enum.Font.Gotham
        Label.TextColor3 = Color3.fromRGB(120,120,120)
        Label.TextScaled = true
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Size = UDim2.new(0, 110, 0, 20)
        Label.Position = UDim2.new(0.06, 0, 0.18 + (i - 1) * 0.24, 0)

        SliderFrame.Parent = MainFrame
        SliderFrame.BackgroundTransparency = 1
        SliderFrame.Size = UDim2.new(0, 90, 0, 20)
        SliderFrame.Position = UDim2.new(0.57, 5, 0.18 + (i - 1) * 0.24, 0)

        SliderBar.Parent = SliderFrame
        SliderBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderBar.BackgroundTransparency = 0.7
        SliderBar.Size = UDim2.new(1, 0, 0, 3)
        SliderBar.Position = UDim2.new(0, 0, 0.5, -2)
        SliderBarCorner.CornerRadius = UDim.new(1, 0)
        SliderBarCorner.Parent = SliderBar

        SliderButton.Parent = SliderFrame
        SliderButton.BackgroundColor3 = Color3.fromRGB(180,180,180)
        SliderButton.Size = UDim2.new(0, 14, 0, 14)
        SliderButton.Position = UDim2.new(0, -7, 0.5, -7)
        SliderButton.Text = ""
        SliderButton.AutoButtonColor = false
        SliderButton.ZIndex = 2
        local ButtonCorner = Instance.new("UICorner", SliderButton)
        ButtonCorner.CornerRadius = UDim.new(1, 0)

        local dragging = false
        local value = 0

        -- Defaults mapping so that sliders aren't zero when first opened:
        -- We'll set reasonable defaults if currentSliderValues doesn't already contain a value.
        local initValue = 0
        if currentSliderValues[name] ~= nil then
            initValue = math.clamp(currentSliderValues[name], 0, 100)
        else
            -- provide default sensible values:
            if name == "Dash speed" then
                initValue = 84 -- maps to ~TOTAL_TIME = 0.45 (fast)
            elseif name == "Dash Degrees" then
                -- default to 480 degrees -> compute percent in 180..720 mapping
                initValue = math.floor((480 - 180) / (720 - 180) * 100)
            elseif name == "Dash gap" then
                initValue = 50
            end
        end
        value = initValue
        SliderButton.Position = UDim2.new(value / 100, -7, 0.5, -7)
        currentSliderValues[name] = value

        local function update(absX)
            local barSize = SliderBar.AbsoluteSize.X
            local barPos = SliderBar.AbsolutePosition.X
            if barSize == 0 then return end
            local relative = math.clamp((absX - barPos) / barSize, 0, 1)
            SliderButton.Position = UDim2.new(relative, -7, 0.5, -7)
            value = math.floor(relative * 100)
            currentSliderValues[name] = value
        end

        SliderButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                if input.Position then update(input.Position.X) end
            end
        end)
        SliderButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        SliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                if input.Position then update(input.Position.X) end
            end
        end)
        SliderBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        SliderFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                if input.Position then update(input.Position.X) end
            end
        end)
        SliderFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                if input.Position then update(input.Position.X) end
            end
        end)

        Sliders[name] = function() return value end
    end
end

adjustBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    createDashPanel()
end)

if savedSettings then
    if savedSettings.Dash ~= nil then
        if espSetState then espSetState(savedSettings.Dash, true) end
        espEnabled = savedSettings.Dash
    end
    if savedSettings.M1 ~= nil then
        if m1SetState then m1SetState(savedSettings.M1, true) end
        m1Enabled = savedSettings.M1
    end
end

Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)

-- ---------- Circular dash UI (circular button) ----------
local function createCircularButtonUI()
    pcall(function() local old = LocalPlayer.PlayerGui:FindFirstChild("CircularTweenUI") if old then old:Destroy() end end)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CircularTweenUI_Merged"
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

    local pressSound = Instance.new("Sound", button)
    pressSound.SoundId = PRESS_SFX_ID
    pressSound.Volume = 0.9

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
        if not isDragging and delta.Magnitude >= dragThreshold then isDragging = true tweenUIScale(1,0.06) end
        if isDragging then
            local screenW, screenH = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y
            local newX = math.clamp(buttonStartPos.X.Offset + delta.X, 0, screenW - button.AbsoluteSize.X)
            local newY = math.clamp(buttonStartPos.Y.Offset + delta.Y, 0, screenH - button.AbsoluteSize.Y)
            button.Position = UDim2.new(0, newX, 0, newY)
        end
    end

    UserInputService.InputChanged:Connect(function(input) pcall(function() updatePointer(input) end) end)
    UserInputService.InputEnded:Connect(function(input)
        if input ~= trackedInput or not isPointerDown then return end
        if not isDragging and (tick() - lastActivated >= 2) then
            local target = getNearestTarget(MAX_RANGE)
            if target then smoothCircle480_then_cameraAim(target) end
        end
        tweenUIScale(1,0.06)
        isPointerDown,isDragging,pointerStartPos,buttonStartPos,trackedInput = false,false,nil,nil,nil
    end)
    button.InputBegan:Connect(function(input) pcall(function() startPointer(input) end) end)
end

-- Connect keyboard/gamepad X to trigger (preserve original behavior)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or busy then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X)
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonX)
    then
        if tick() - lastActivated < 2 then return end
        local target = getNearestTarget(MAX_RANGE)
        if target then smoothCircle480_then_cameraAim(target) end
    end
end)

-- ---------- Integration: read slider values and apply to spin when starting ----------
-- Helper functions to map slider percent -> real parameters.
local function sliderToTotalTime(percent)
    -- percent: 0..100 -> maps slow (1.5s) to fast (0.25s)
    local p = math.clamp(percent or 84, 0, 100) / 100
    return 1.5 + (0.25 - 1.5) * p
end
local function sliderToDegrees(percent)
    -- percent: 0..100 -> 180..720 degrees
    local p = math.clamp(percent or 56, 0, 100) / 100
    return 180 + (720 - 180) * p
end
local function sliderToOrbitRadius(percent)
    -- percent: 0..100 -> 2..8 studs
    local p = math.clamp(percent or 50, 0, 100) / 100
    return 2 + (8 - 2) * p
end

-- Overridable defaults used by the spin function; will be set per-spin
local DEFAULT_TOTAL_TIME = 0.45
local DEFAULT_TOTAL_ANGLE_RAD = math.rad(480)

-- The merged main circular dash function (reads slider values and checks toggles)
function smoothCircle480_then_cameraAim(targetModel)
    -- prevent re-entrancy and cooldowns (cooldown reused from original)
    local COOLDOWN = 2
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

    -- Read slider values (most recent)
    local speedPercent = currentSliderValues["Dash speed"] or (savedSettings and savedSettings.Sliders and tonumber(savedSettings.Sliders["Dash speed"]) or 84)
    local degreesPercent = currentSliderValues["Dash Degrees"] or (savedSettings and savedSettings.Sliders and tonumber(savedSettings.Sliders["Dash Degrees"]) or math.floor((480-180)/(720-180)*100))
    local gapPercent = currentSliderValues["Dash gap"] or (savedSettings and savedSettings.Sliders and tonumber(savedSettings.Sliders["Dash gap"]) or 50)

    local TOTAL_TIME = sliderToTotalTime(speedPercent)
    local totalDeg = sliderToDegrees(degreesPercent) -- degrees
    local totalAngle = math.rad(totalDeg)
    local orbitRadius = math.clamp(sliderToOrbitRadius(gapPercent), MIN_RADIUS, MAX_RADIUS)

    -- Straight dash (if far)
    local targetHRP = targetModel.HumanoidRootPart
    local distance = (targetHRP.Position - HRP.Position).Magnitude
    if distance >= STRAIGHT_START_DIST then
        -- Use STRAIGHT_SPEED as before for straight dash; could be tied to slider if desired.
        dashStraightToTarget(targetHRP, STRAIGHT_SPEED)
    end

    if not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent then
        safeRestoreAutoRotate()
        busy = false
        return
    end

    -- Determine side
    local initialCenter = targetHRP.Position
    local myPos = HRP.Position
    local rightVec = HRP.CFrame.RightVector
    local targetDir = (targetHRP.Position - HRP.Position)
    if targetDir.Magnitude < 0.001 then targetDir = HRP.CFrame.LookVector end
    local dotRight = rightVec:Dot(targetDir.Unit)
    local isLeft = dotRight < 0

    -- play side animation
    playSideAnimation(isLeft)

    local dir = isLeft and 1 or -1
    local startAngle = math.atan2(myPos.Z - initialCenter.Z, myPos.X - initialCenter.X)
    local startRadius = (Vector3.new(myPos.X,0,myPos.Z) - Vector3.new(initialCenter.X,0,initialCenter.Z)).Magnitude
    startRadius = math.clamp(startRadius, MIN_RADIUS, MAX_RADIUS)

    local startTime = tick()
    local conn

    -- Aimlock flags as before
    local aimlockTriggered = false
    local aimlockRestoreScheduled = false
    local aimlockEnded = false
    local spinEnded = false

    local function scheduleAimlockRestore()
        if aimlockRestoreScheduled then return end
        aimlockRestoreScheduled = true
        task.delay(POST_CAMERA_AIM_DURATION, function()
            aimlockEnded = true
            safeRestoreAutoRotate()
            lastActivated = tick()
            if spinEnded then
                busy = false
            end
        end)
    end

    -- Fire M1 or Dash remote events at the start of the spin if toggles are enabled
    if m1Enabled then
        -- emulate LeftClick + release shortly after
        local args1 = {
            [1] = {
                ["Mobile"] = true,
                ["Goal"] = "LeftClick"
            }
        }
        safeFireCommunicate(args1)
        task.delay(0.05, function()
            local args2 = {
                [1] = {
                    ["Goal"] = "LeftClickRelease",
                    ["Mobile"] = true
                }
            }
            safeFireCommunicate(args2)
        end)
    end
    if espEnabled then
        local args = {
            [1] = {
                ["Dash"] = Enum.KeyCode.W,
                ["Key"] = Enum.KeyCode.Q,
                ["Goal"] = "KeyPress"
            }
        }
        safeFireCommunicate(args)
    end

    -- Main spin loop (adjusted to use TOTAL_TIME, totalAngle, orbitRadius)
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

        -- Character yaw smoothing (character-only)
        local targetPos = (targetHRP and targetHRP.Position) or center
        local targetYaw = math.atan2((targetPos - posNow).Z, (targetPos - posNow).X)
        local currentYaw = math.atan2(HRP.CFrame.LookVector.Z, HRP.CFrame.LookVector.X)
        local deltaYaw = shortestAngleDelta(targetYaw, currentYaw)
        local yawNow = currentYaw + deltaYaw * AimSpeed
        pcall(function()
            HRP.CFrame = CFrame.new(posNow, posNow + Vector3.new(math.cos(yawNow), 0, math.sin(yawNow)))
        end)

        if not aimlockTriggered then
            if e >= AIMLOCK_TRIGGER_FRACTION then
                aimlockTriggered = true
                pcall(function()
                    postSpinCameraAimlock(targetHRP, POST_CAMERA_AIM_DURATION)
                end)
                scheduleAimlockRestore()
            end
        end

        if t >= 1 then
            conn:Disconnect()
            pcall(function()
                if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
                currentAnimTrack = nil
            end)
            if not aimlockTriggered then
                aimlockTriggered = true
                pcall(function()
                    postSpinCameraAimlock(targetHRP, POST_CAMERA_AIM_DURATION)
                end)
                scheduleAimlockRestore()
            end
            spinEnded = true
            if aimlockEnded then
                busy = false
            end
        end
    end)
end

-- Setup UI and print ready
createCircularButtonUI()
print("[Merged] Ready — Settings + Circular Dash merged into one script.")
