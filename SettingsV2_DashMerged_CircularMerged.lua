-- Settings V2 + Dash Settings + Circular Dash merge
-- Merged: M1 and Dash toggles only trigger when circular spin starts.
-- Sliders:
--  "Dash speed" -> adjusts spin speed (TOTAL_TIME; higher slider => faster)
--  "Dash Degrees" -> adjusts total degrees of spin
--  "Dash gap" -> adjusts orbit radius (studs between you and target)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local Sliders = {}
local currentSliderValues = { ["Dash speed"] = nil, ["Dash Degrees"] = nil, ["Dash gap"] = nil }
local savedSettings = nil
do
    local attr = player:GetAttribute("SettingsV2")
    if type(attr) == "string" then
        pcall(function()
            savedSettings = HttpService:JSONDecode(attr)
            if savedSettings and savedSettings.Sliders then
                for k,v in pairs(savedSettings.Sliders) do
                    local num = tonumber(v)
                    if num then currentSliderValues[k] = math.clamp(math.floor(num), 0, 100) end
                end
            end
        end)
    end
end

local function makeDraggable(frame)
    local dragToggle, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragToggle = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragToggle = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragToggle and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function safeFireCommunicate(argsTable)
    pcall(function()
        local ch = player.Character
        if ch and ch:FindFirstChild("Communicate") then ch.Communicate:FireServer(unpack(argsTable)) end
    end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "SettingsGUI_Only_V2"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6042053626"
clickSound.Volume = 0.7
clickSound.Parent = gui

local function createToggleButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,100,0,35)
    btn.BackgroundColor3 = Color3.fromRGB(245,245,245)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(0,0,0)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,15,0,15)
    circle.Position = UDim2.new(1,-24,0.5,-7)
    circle.BackgroundColor3 = Color3.fromRGB(180,180,180)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
    local toggled = false
    local function updateVisuals()
        circle.BackgroundColor3 = toggled and Color3.fromRGB(0,200,0) or Color3.fromRGB(180,180,180)
        btn.BackgroundColor3 = toggled and Color3.fromRGB(220,220,220) or Color3.fromRGB(245,245,245)
    end
    local function setState(state, runCallback)
        toggled = not not state
        updateVisuals()
        if runCallback and callback then pcall(function() callback(toggled) end) end
    end
    btn.MouseButton1Click:Connect(function()
        pcall(function() clickSound:Play() end)
        setState(not toggled, true)
    end)
    return btn, setState
end

-- Build main settings UI (kept minimal to focus on merge)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0,280,0,270)
mainFrame.Position = UDim2.new(0.5,-140,0.5,-135)
mainFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderColor3 = Color3.fromRGB(0,0,0)
mainFrame.BorderSizePixel = 2
mainFrame.AnchorPoint = Vector2.new(0.5,0.5)
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,12)
TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,280,0,270)}):Play()

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,35)
title.BackgroundColor3 = Color3.fromRGB(235,235,235)
title.Text = "⚙️ Settings V2"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0,12)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0,35,0,35)
minimizeBtn.Position = UDim2.new(1,-40,0,0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(200,200,200)
minimizeBtn.Text = "-"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.Parent = mainFrame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(1,0)

local buttonHolder = Instance.new("Frame")
buttonHolder.Size = UDim2.new(1,-20,0,90)
buttonHolder.Position = UDim2.new(0,10,0,45)
buttonHolder.BackgroundTransparency = 1
buttonHolder.Parent = mainFrame

local UIGrid = Instance.new("UIGridLayout")
UIGrid.CellSize = UDim2.new(0.5,-10,0,35)
UIGrid.CellPadding = UDim2.new(0,10,0,10)
UIGrid.Parent = buttonHolder

local m1Enabled = false
local espEnabled = false

local m1Btn, m1SetState = createToggleButton("M1", function(state)
    m1Enabled = state
end)
m1Btn.Parent = buttonHolder

local espBtn, espSetState = createToggleButton("Dash", function(state)
    espEnabled = state
end)
espBtn.Parent = buttonHolder

local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0,100,0,35)
discordBtn.BackgroundColor3 = Color3.fromRGB(245,245,245)
discordBtn.Text = "Discord"
discordBtn.Parent = buttonHolder
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,8)
discordBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    local success = false
    pcall(function() if setclipboard then setclipboard("https://discord.gg/5x4xbPvuSc"); success = true end)
    if not success then pcall(function() player:SetAttribute("LastDiscordInvite", "https://discord.gg/5x4xbPvuSc") end) end
    local old = discordBtn.Text
    discordBtn.Text = success and "Copied" or "Stored"
    task.delay(0.9, function() pcall(function() discordBtn.Text = old end) end)
end)

-- Dash panel (sliders) creator
local dashGui = nil
local function createDashPanel()
    if dashGui and dashGui.Parent then dashGui:Destroy(); dashGui = nil; return end
    dashGui = Instance.new("ScreenGui"); dashGui.Name = "DashSettingsGui"; dashGui.Parent = player:WaitForChild("PlayerGui")
    local MainFrame = Instance.new("Frame"); MainFrame.Parent = dashGui; MainFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
    MainFrame.BackgroundTransparency = 0.3; MainFrame.Position = UDim2.new(0.5,0,0.5,0); MainFrame.Size = UDim2.new(0,200,0,200)
    MainFrame.AnchorPoint = Vector2.new(0.5,0.5); makeDraggable(MainFrame)
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,14)
    local CloseButton = Instance.new("TextButton"); CloseButton.Parent = MainFrame; CloseButton.BackgroundColor3 = Color3.fromRGB(200,0,0)
    CloseButton.Position = UDim2.new(0.82,0,0.05,0); CloseButton.Size = UDim2.new(0,30,0,30); CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"; CloseButton.TextColor3 = Color3.fromRGB(255,255,255); CloseButton.AutoButtonColor = false
    Instance.new("UICorner", CloseButton).CornerRadius = UDim.new(0,6)
    CloseButton.MouseButton1Click:Connect(function() pcall(function() clickSound:Play() end) if dashGui and dashGui.Parent then dashGui:Destroy(); dashGui = nil end end)

    local TitleLabels = {"Dash speed", "Dash Degrees", "Dash gap"}
    for i, name in ipairs(TitleLabels) do
        local Label = Instance.new("TextLabel"); Label.Parent = MainFrame; Label.BackgroundTransparency = 1
        Label.Text = name; Label.Font = Enum.Font.Gotham; Label.TextColor3 = Color3.fromRGB(120,120,120)
        Label.TextScaled = true; Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Size = UDim2.new(0,90,0,20); Label.Position = UDim2.new(0.05,0,0.18 + (i-1)*0.25,0)

        local SliderFrame = Instance.new("Frame"); SliderFrame.Parent = MainFrame; SliderFrame.BackgroundTransparency = 1
        SliderFrame.Size = UDim2.new(0,65,0,20); SliderFrame.Position = UDim2.new(0.55,5,0.18 + (i-1)*0.25,0)
        local SliderBar = Instance.new("Frame"); SliderBar.Parent = SliderFrame; SliderBar.BackgroundColor3 = Color3.fromRGB(255,255,255)
        SliderBar.BackgroundTransparency = 0.7; SliderBar.Size = UDim2.new(1,0,0,3); SliderBar.Position = UDim2.new(0,0,0.5,-2)
        Instance.new("UICorner", SliderBar).CornerRadius = UDim.new(1,0)
        local SliderButton = Instance.new("TextButton"); SliderButton.Parent = SliderFrame; SliderButton.BackgroundColor3 = Color3.fromRGB(180,180,180)
        SliderButton.Size = UDim2.new(0,14,0,14); SliderButton.Position = UDim2.new(0,-7,0.5,-7); SliderButton.Text = ""; SliderButton.AutoButtonColor = false
        Instance.new("UICorner", SliderButton).CornerRadius = UDim.new(1,0)
        local dragging = false; local value = 0
        local initValue = 0
        if currentSliderValues[name] ~= nil then initValue = math.clamp(currentSliderValues[name],0,100)
        else
            local savedValue = nil
            if savedSettings and savedSettings.Sliders and savedSettings.Sliders[name] then savedValue = tonumber(savedSettings.Sliders[name]) end
            if savedValue and type(savedValue) == "number" then initValue = math.clamp(math.floor(savedValue),0,100) end
        end
        value = initValue; SliderButton.Position = UDim2.new(value/100, -7, 0.5, -7)
        local function update(absX)
            local barSize = SliderBar.AbsoluteSize.X
            local barPos = SliderBar.AbsolutePosition.X
            if barSize == 0 then return end
            local relative = math.clamp((absX - barPos) / barSize, 0, 1)
            SliderButton.Position = UDim2.new(relative, -7, 0.5, -7)
            value = math.floor(relative * 100)
            currentSliderValues[name] = value
        end
        SliderButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true if input.Position then update(input.Position.X) end end end)
        SliderButton.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
        SliderBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true if input.Position then update(input.Position.X) end end end)
        SliderBar.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
        SliderFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true if input.Position then update(input.Position.X) end end end)
        SliderFrame.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then if input.Position then update(input.Position.X) end end end)

        Sliders[name] = function() return value end
    end
end

-- Adjust button to toggle dash panel
local adjustBtn = Instance.new("TextButton")
adjustBtn.Size = UDim2.new(0,110,0,36)
adjustBtn.Position = UDim2.new(0,12,1,-44)
adjustBtn.BackgroundColor3 = Color3.fromRGB(110,110,110)
adjustBtn.Text = "Adjust"
adjustBtn.TextColor3 = Color3.fromRGB(255,255,255)
adjustBtn.Font = Enum.Font.GothamBold
adjustBtn.TextSize = 16
adjustBtn.Parent = mainFrame
Instance.new("UICorner", adjustBtn).CornerRadius = UDim.new(0,12)
adjustBtn.AutoButtonColor = false
adjustBtn.MouseButton1Click:Connect(function() pcall(function() clickSound:Play() end) createDashPanel() end)

-- apply saved toggle states
if savedSettings then
    if savedSettings.Dash ~= nil then if espSetState then espSetState(savedSettings.Dash, true) end espEnabled = savedSettings.Dash end
    if savedSettings.M1 ~= nil then if m1SetState then m1SetState(savedSettings.M1, true) end m1Enabled = savedSettings.M1 end
end

Players.PlayerAdded:Connect(function() end) -- placeholder

-- CIRCULAR DASH LOGIC (adapted)
local LocalPlayer = player
local Camera = workspace.CurrentCamera

math.randomseed(tick() % 65536)

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char) Character = char HRP = char:WaitForChild("HumanoidRootPart") Humanoid = char:FindFirstChildOfClass("Humanoid") end)

local placeId = game.PlaceId
local AnimationSets = {
    [10449761463] = { Left = 10480796021, Right = 10480793962, Straight = 10479335397 },
    [13076380114] = { Left = 101843860692381, Right = 100087324592640, Straight = 110878031211717 },
}
local DefaultSet = AnimationSets[13076380114]
local CurrentSet = AnimationSets[placeId] or DefaultSet
local ANIM_LEFT_ID, ANIM_RIGHT_ID = CurrentSet.Left, CurrentSet.Right
local STRAIGHT_ANIM_ID = CurrentSet.Straight

local MAX_RANGE = 40
local ORBIT_RADIUS_MIN, ORBIT_RADIUS_MAX = 4,5
local TOTAL_TIME_DEFAULT = 0.45
local TOTAL_TIME = TOTAL_TIME_DEFAULT
local COOLDOWN = 2
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
    if autoRotateConn then pcall(function() autoRotateConn:Disconnect() end) autoRotateConn = nil end
    local hum = Character and Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    autoRotateConn = hum:GetPropertyChangedSignal("AutoRotate"):Connect(function()
        if silent then pcall(function() if hum and hum.AutoRotate then hum.AutoRotate = false end end) end
    end)
end
bindAutoRotateWatcher()

local function shortestAngleDelta(target, current)
    local delta = target - current
    while delta > math.pi do delta = delta - 2 * math.pi end
    while delta < -math.pi do delta = delta + 2 * math.pi end
    return delta
end

local function easeOutCubic(t) t = math.clamp(t,0,1) return 1 - (1 - t) ^ 3 end

local function ensureHumanoidAndAnimator()
    if not Character or not Character.Parent then return nil, nil end
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, nil end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator") animator.Name = "Animator" animator.Parent = hum end
    return hum, animator
end

local function playSideAnimation(isLeft)
    pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end end)
    currentAnimTrack = nil
    local hum, animator = ensureHumanoidAndAnimator()
    if not hum or not animator then return end
    local animId = isLeft and ANIM_LEFT_ID or ANIM_RIGHT_ID
    local anim = Instance.new("Animation"); anim.Name = "CircularSideAnim"; anim.AnimationId = "rbxassetid://" .. tostring(animId)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then anim:Destroy() return end
    currentAnimTrack = track; track.Priority = Enum.AnimationPriority.Action; track:Play()
    pcall(function() dashSound:Stop() dashSound:Play() end)
    delay(TOTAL_TIME + 0.15, function() pcall(function() if track and track.IsPlaying then track:Stop() end end) pcall(function() anim:Destroy() end) end)
end

local function getNearestTarget(maxRange)
    maxRange = maxRange or MAX_RANGE
    if not HRP then return nil end
    local myPos = HRP.Position
    local nearest, nearestDist = nil, math.huge
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
    speed = speed or AimSpeed
    pcall(function()
        local camPos = Camera.CFrame.Position
        local camLook = Camera.CFrame.LookVector
        local camTargetDir = (targetPos - camPos)
        local flatCamTarget = Vector3.new(camTargetDir.X, 0, camTargetDir.Z)
        if flatCamTarget.Magnitude < 0.001 then flatCamTarget = Vector3.new(1,0,0) end
        local flatUnit = flatCamTarget.Unit
        local desiredCamLook = Vector3.new(flatUnit.X, camLook.Y, flatUnit.Z)
        local newCamLook = camLook:Lerp(desiredCamLook, speed)
        Camera.CFrame = CFrame.new(camPos, camPos + newCamLook.Unit)
    end)
end

local function getSliderValue(name, default)
    if Sliders and Sliders[name] then
        local ok, val = pcall(function() return Sliders[name]() end)
        if ok and type(val) == "number" then return val end
    end
    if currentSliderValues and currentSliderValues[name] ~= nil then return currentSliderValues[name] end
    return default
end

local AIM_TOTAL_DEGREES = 480

local function applySliderSettings()
    local s = getSliderValue("Dash speed", nil)
    if type(s) == "number" then
        local frac = math.clamp(s / 100, 0, 1)
        local minT, maxT = 0.25, 1.5
        TOTAL_TIME = maxT + (minT - maxT) * frac
    else
        TOTAL_TIME = TOTAL_TIME_DEFAULT
    end
    local d = getSliderValue("Dash Degrees", nil)
    if type(d) == "number" then
        local frac = math.clamp(d / 100, 0, 1)
        local minDeg, maxDeg = 90, 1080
        AIM_TOTAL_DEGREES = minDeg + (maxDeg - minDeg) * frac
    else
        AIM_TOTAL_DEGREES = 480
    end
    local g = getSliderValue("Dash gap", nil)
    if type(g) == "number" then
        local frac = math.clamp(g / 100, 0, 1)
        local minGap, maxGap = 1.0, 20.0
        ORBIT_RADIUS_MIN = minGap
        ORBIT_RADIUS_MAX = minGap + (maxGap - minGap) * frac
    else
        ORBIT_RADIUS_MIN, ORBIT_RADIUS_MAX = 4,5
    end
end

local function dashStraightToTarget(targetHRP)
    local attach = Instance.new("Attachment"); attach.Name = "DashAttach"; attach.Parent = HRP
    local lv = Instance.new("LinearVelocity"); lv.Name = "DashLinearVelocity"; lv.Attachment0 = attach; lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.Parent = HRP
    local straightAnimObj, straightAnimTrack
    if STRAIGHT_ANIM_ID then
        local hum, animator = ensureHumanoidAndAnimator()
        if hum and animator then
            local anim = Instance.new("Animation"); anim.Name = "StraightDashAnim"; anim.AnimationId = "rbxassetid://" .. tostring(STRAIGHT_ANIM_ID)
            local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
            if ok and track then straightAnimObj = anim; straightAnimTrack = track; straightAnimTrack.Priority = Enum.AnimationPriority.Movement
                pcall(function() straightAnimTrack.Looped = true end); pcall(function() straightAnimTrack:Play() end)
            else pcall(function() anim:Destroy() end) end
        end
    end

    -- Trigger M1/Dash communicate only at straight dash start if toggled
    if m1Enabled then
        local args1 = { [1] = { ["Mobile"] = true, ["Goal"] = "LeftClick" } }
        safeFireCommunicate(args1)
        task.delay(0.05, function()
            local args2 = { [1] = { ["Goal"] = "LeftClickRelease", ["Mobile"] = true } }
            safeFireCommunicate(args2)
        end)
    end
    if espEnabled then
        local args = { [1] = { ["Dash"] = Enum.KeyCode.W, ["Key"] = Enum.KeyCode.Q, ["Goal"] = "KeyPress" } }
        safeFireCommunicate(args)
    end

    local reached = false; local alive = true
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not alive then return end
        if not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent then
            alive = false; conn:Disconnect(); pcall(function() lv:Destroy() end); pcall(function() attach:Destroy() end)
            pcall(function() if straightAnimTrack and straightAnimTrack.IsPlaying then straightAnimTrack:Stop() end if straightAnimObj then straightAnimObj:Destroy() end end)
            return
        end
        local targetPos = targetHRP.Position
        local direction = (targetPos - HRP.Position)
        local flat = Vector3.new(direction.X, 0, direction.Z)
        local dist = flat.Magnitude
        if dist <= ORBIT_TRIGGER_DIST then
            reached = true; alive = false; conn:Disconnect(); pcall(function() lv:Destroy() end); pcall(function() attach:Destroy() end)
            pcall(function() if straightAnimTrack and straightAnimTrack.IsPlaying then straightAnimTrack:Stop() end if straightAnimObj then straightAnimObj:Destroy() end end)
            return
        end
        local velocity = (flat.Unit) * STRAIGHT_SPEED
        lv.VectorVelocity = velocity
        pcall(function() if flat.Magnitude > 0.001 then HRP.CFrame = CFrame.new(HRP.Position, HRP.Position + flat.Unit) end end)
        pcall(function() smoothFaceCameraTowards(targetPos, AimSpeed * 0.8) end)
    end)
    repeat task.wait() until reached or not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent
end

local function postSpinCameraAimlock(targetHRP, duration)
    if not targetHRP or not targetHRP.Parent then return end
    duration = duration or POST_CAMERA_AIM_DURATION
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not targetHRP or not targetHRP.Parent then conn:Disconnect() return end
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
        if t >= 1 then conn:Disconnect(); return end
    end)
end

local function smoothCircle480_then_cameraAim(targetModel)
    if busy then return end
    if tick() - lastActivated < COOLDOWN then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end

    applySliderSettings()

    busy = true
    local hum = Character:FindFirstChildOfClass("Humanoid")
    local prevAutoRotate = nil
    if hum then prevAutoRotate = hum.AutoRotate; silent = true; pcall(function() hum.AutoRotate = false end) end
    local function safeRestoreAutoRotate() if hum and prevAutoRotate ~= nil then silent = false; pcall(function() hum.AutoRotate = prevAutoRotate end) end end

    local targetHRP = targetModel.HumanoidRootPart
    local distance = (targetHRP.Position - HRP.Position).Magnitude

    if distance >= STRAIGHT_START_DIST then dashStraightToTarget(targetHRP) end

    if not targetHRP or not targetHRP.Parent or not HRP or not HRP.Parent then safeRestoreAutoRotate(); busy = false; return end

    local initialCenter = targetHRP.Position
    local myPos = HRP.Position
    local orbitRadius = ORBIT_RADIUS_MIN + (math.random() * (ORBIT_RADIUS_MAX - ORBIT_RADIUS_MIN))
    orbitRadius = math.clamp(orbitRadius, MIN_RADIUS, MAX_RADIUS)

    local rightVec = HRP.CFrame.RightVector
    local targetDir = (targetHRP.Position - HRP.Position)
    if targetDir.Magnitude < 0.001 then targetDir = HRP.CFrame.LookVector end
    local dotRight = rightVec:Dot(targetDir.Unit)
    local isLeft = dotRight < 0

    playSideAnimation(isLeft)

    local totalAngle = math.rad(AIM_TOTAL_DEGREES or 480)
    local dir = isLeft and 1 or -1

    local startAngle = math.atan2(myPos.Z - initialCenter.Z, myPos.X - initialCenter.X)
    local startRadius = (Vector3.new(myPos.X,0,myPos.Z) - Vector3.new(initialCenter.X,0,initialCenter.Z)).Magnitude

    local startTime = tick()
    local conn

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
            if spinEnded then busy = false end
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

        local targetPos = (targetHRP and targetHRP.Position) or center
        local targetYaw = math.atan2((targetPos - posNow).Z, (targetPos - posNow).X)
        local currentYaw = math.atan2(HRP.CFrame.LookVector.Z, HRP.CFrame.LookVector.X)
        local deltaYaw = shortestAngleDelta(targetYaw, currentYaw)
        local yawNow = currentYaw + deltaYaw * AimSpeed
        pcall(function() HRP.CFrame = CFrame.new(posNow, posNow + Vector3.new(math.cos(yawNow), 0, math.sin(yawNow))) end)

        if not aimlockTriggered then
            if e >= AIMLOCK_TRIGGER_FRACTION then
                aimlockTriggered = true
                pcall(function() postSpinCameraAimlock(targetHRP, POST_CAMERA_AIM_DURATION) end)
                scheduleAimlockRestore()
            end
        end

        if t >= 1 then
            conn:Disconnect()
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
            if not aimlockTriggered then
                aimlockTriggered = true
                pcall(function() postSpinCameraAimlock(targetHRP, POST_CAMERA_AIM_DURATION) end)
                scheduleAimlockRestore()
            end
            spinEnded = true
            if aimlockEnded then busy = false end
        end
    end)
end

-- create circular UI button
local function createCircularUI()
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
        if not isDragging and not busy and (tick() - lastActivated >= COOLDOWN) then
            local target = getNearestTarget(MAX_RANGE)
            if target then smoothCircle480_then_cameraAim(target) end
        end
        tweenUIScale(1,0.06)
        isPointerDown,isDragging,pointerStartPos,buttonStartPos,trackedInput = false,false,nil,nil,nil
    end)
    button.InputBegan:Connect(function(input) pcall(function() startPointer(input) end) end)
end

createCircularUI()

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or busy then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X)
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonX)
    then
        if tick() - lastActivated < COOLDOWN then return end
        local target = getNearestTarget(MAX_RANGE)
        if target then smoothCircle480_then_cameraAim(target) end
    end
end)

print("[Merged] Circular dash ready. Sliders control speed/degrees/gap. M1/Dash toggles trigger at straight-dash start.")
