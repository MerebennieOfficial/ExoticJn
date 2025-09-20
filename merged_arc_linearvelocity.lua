
-- Modified script: replaced movement with AssemblyLinearVelocity-based motion and aimlock replaced per user request.
-- Changes made:
-- 1) Use velocity-based movement (AssemblyLinearVelocity) instead of setting HRP.CFrame directly during arc.
-- 2) Replace aimlock logic with provided tween snippet that makes the character look at the target.
-- 3) Fixed floating issue by lowering final Y offset from +1.5 to +0.5.
-- 4) Changed on-land gap (BEHIND_DISTANCE / FRONT_DISTANCE) from 4 to 3.
-- 5) Kept UI tweens untouched (per user request: only these changes applied).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Character = player.Character or player.CharacterAdded:Wait()
local HRP = Character:FindFirstChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
player.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

local MAX_RANGE = 40
local ARC_APPROACH_RADIUS = 11
local BEHIND_DISTANCE = 3 -- changed from 4 to 3
local FRONT_DISTANCE = 3  -- changed from 4 to 3
local TOTAL_TIME = 0.3
local SPEED_SETTING = 1.0

local function getEffectiveTotalTime()
    if SPEED_SETTING <= 0.05 then SPEED_SETTING = 0.05 end
    return TOTAL_TIME / SPEED_SETTING
end
local MIN_RADIUS = 1.2
local MAX_RADIUS = 14
local ANIM_LEFT_ID = 10480796021
local ANIM_RIGHT_ID = 10480793962
local PRESS_SFX_ID = 10480793962 
local DASH_SFX_ID = "rbxassetid://72014632956520"

local busy = false
local currentAnimTrack = nil

local espEnabled = false
local m1Enabled = false     
local dashEnabled = false    
local targetNearMode = false 
local selectedPlayer = nil

local function getCommunicate()
    local char = player.Character or player.CharacterAdded:Wait()
    if char then
        return char:FindFirstChild("Communicate")
    end
    return nil
end

local function safeSend(args)
    pcall(function()
        local comm = getCommunicate()
        if comm and type(comm.FireServer) == "function" then
            comm:FireServer(unpack(args))
        end
    end)
end

local function sendDash()
    local args = {
        [1] = {
            ["Dash"] = Enum.KeyCode.W,
            ["Key"] = Enum.KeyCode.Q,
            ["Goal"] = "KeyPress"
        }
    }
    safeSend(args)
end

local function sendM1()
    local args1 = {
        [1] = {
            ["Mobile"] = true,
            ["Goal"] = "LeftClick"
        }
    }
    local args2 = {
        [1] = {
            ["Goal"] = "LeftClickRelease",
            ["Mobile"] = true
        }
    }
    pcall(function()
        local comm = getCommunicate()
        if comm and type(comm.FireServer) == "function" then
            comm:FireServer(unpack(args1))
            wait(0.06)
            comm:FireServer(unpack(args2))
        end
    end)
end

local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2.0
dashSound.Looped = false
dashSound.Parent = Workspace

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

local function playSideAnimation(isLeft, duration)
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
    anim.AnimationId = "rbxassetid://"..tostring(animId)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then anim:Destroy() return end
    currentAnimTrack = track
    track.Priority = Enum.AnimationPriority.Action
    track:Play()
    pcall(function()
        if dashSound and dashSound.Parent then dashSound:Stop() dashSound:Play() end
    end)
    delay((duration or TOTAL_TIME) + 0.15, function()
        if track and track.IsPlaying then pcall(function() track:Stop() end) end
        pcall(function() anim:Destroy() end)
    end)
end

local function getNearestTarget(maxRange)
    maxRange = maxRange or MAX_RANGE
    if not HRP then return nil end
    local myPos = HRP.Position
    local nearest, nearestDist = nil, math.huge
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") then
            local hum = pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos = pl.Character.HumanoidRootPart.Position
                local d = (pos - myPos).Magnitude
                if d < nearestDist and d <= maxRange then nearestDist, nearest = d, pl.Character end
            end
        end
    end
    for _, obj in pairs(Workspace:GetDescendants()) do
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

local function smoothArcToTarget(targetModel)
    if busy then return false end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return false end
    if not HRP then return false end

    busy = true

    local targetHRP = targetModel.HumanoidRootPart
    local center = targetHRP.Position
    local myPos = HRP.Position
    local lookVec = targetHRP.CFrame.LookVector
    local toMe = myPos - center
    local forwardDot = lookVec:Dot(toMe)
    local finalPos
    if forwardDot > 0 then
        finalPos = center - lookVec * BEHIND_DISTANCE
    else
        finalPos = center + lookVec * FRONT_DISTANCE
    end
    -- reduced Y offset to avoid floating above ground
    finalPos = Vector3.new(finalPos.X, center.Y + 0.5, finalPos.Z)

    local startRadius = (Vector3.new(myPos.X,0,myPos.Z) - Vector3.new(center.X,0,center.Z)).Magnitude
    local midRadius = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius = (Vector3.new(finalPos.X,0,finalPos.Z) - Vector3.new(center.X,0,center.Z)).Magnitude
    local startAngle = math.atan2(myPos.Z - center.Z, myPos.X - center.X)
    local endAngle = math.atan2(finalPos.Z - center.Z, finalPos.X - center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)
    local isLeft = (deltaAngle > 0)

    local effectiveTime = getEffectiveTotalTime()
    pcall(function() playSideAnimation(isLeft, effectiveTime) end)

    local cam = Workspace.CurrentCamera
    local startCamLook = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0,0,1)
    local startPitch = math.asin(math.clamp(startCamLook.Y, -0.999, 0.999))
    local humanoid = nil
    local oldAutoRotate = nil
    pcall(function() humanoid = Character and Character:FindFirstChildOfClass("Humanoid") end)
    if humanoid then
        pcall(function() oldAutoRotate = humanoid.AutoRotate end)
        pcall(function() humanoid.AutoRotate = false end)
    end

    local startHRPLook = HRP and HRP.CFrame and HRP.CFrame.LookVector or Vector3.new(1,0,0)
    local startHRPYaw = math.atan2(startHRPLook.Z, startHRPLook.X)
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not targetHRP or not targetHRP.Parent then
            if humanoid and oldAutoRotate ~= nil then pcall(function() humanoid.AutoRotate = oldAutoRotate end) end
            if conn and conn.Connected then conn:Disconnect() end
            -- stop motion
            pcall(function() HRP.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
            busy = false
            return
        end
        local now = tick()
        local t = math.clamp((now - startTime) / effectiveTime, 0, 1)
        local e = easeOutCubic(t)
        local midT = 0.5
        local radiusNow
        if t <= midT then
            local e1 = easeOutCubic(t / midT)
            radiusNow = startRadius + (midRadius - startRadius) * e1
        else
            local e2 = easeOutCubic((t - midT) / (1 - midT))
            radiusNow = midRadius + (endRadius - midRadius) * e2
        end
        radiusNow = math.clamp(radiusNow, MIN_RADIUS, MAX_RADIUS)
        local angleNow = startAngle + deltaAngle * e
        local x = center.X + radiusNow * math.cos(angleNow)
        local z = center.Z + radiusNow * math.sin(angleNow)
        local y = myPos.Y + (finalPos.Y - myPos.Y) * e
        local posNow = Vector3.new(x, y, z)

        -- compute desired velocity to reach posNow this frame
        local desiredVel = Vector3.new(0,0,0)
        if dt and dt > 0 then
            desiredVel = (posNow - HRP.Position) / dt
        end
        pcall(function() HRP.AssemblyLinearVelocity = desiredVel end)

        -- Aimlock replacement per user request: make character look at the target
        pcall(function()
            local targetPos = targetHRP.Position
            local lookCF = CFrame.new(HRP.Position, targetPos)
            local tween = TweenService:Create(HRP, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
                CFrame = lookCF
            })
            tween:Play()
        end)

        if cam and cam.CFrame and targetHRP and targetHRP.Parent then
            local camPos = cam.CFrame.Position
            local toTargetFromCam = targetHRP.Position - camPos
            if toTargetFromCam.Magnitude < 0.001 then toTargetFromCam = Vector3.new(lookVec.X, 0, lookVec.Z) end
            local desiredCamYaw = math.atan2(toTargetFromCam.Z, toTargetFromCam.X)
            local cosP = math.cos(startPitch)
            local camLookNow = Vector3.new(math.cos(desiredCamYaw)*cosP, math.sin(startPitch), math.sin(desiredCamYaw)*cosP)
            pcall(function() cam.CFrame = CFrame.new(camPos, camPos + camLookNow) end)
        end

        if t >= 1 then
            if conn and conn.Connected then conn:Disconnect() end
            -- move to final pos and stop velocity
            pcall(function()
                HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new((HRP.CFrame.LookVector.X or 1), 0, (HRP.CFrame.LookVector.Z or 0)))
            end)
            pcall(function() HRP.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
            if humanoid and oldAutoRotate ~= nil then pcall(function() humanoid.AutoRotate = oldAutoRotate end) end
            busy = false
        end
    end)

    return true
end

local gui = Instance.new("ScreenGui")
gui.Name = "SettingsGUI_Merged"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")


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
title.Text = "⚙️ Settings"
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

local espFolder = Instance.new("Folder", gui)
espFolder.Name = "ESPFolder"

-- helper: update ESP (only for target)
local function clearESP()
    for _, v in ipairs(espFolder:GetChildren()) do v:Destroy() end
end

local function createTargetESP(model)
    clearESP()
    if not model or not model.Parent then return end
    local adornee = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not adornee then return end

    local bgui = Instance.new("BillboardGui")
    bgui.Size = UDim2.new(0, 120, 0, 40)
    bgui.Adornee = adornee
    bgui.AlwaysOnTop = true
    bgui.Parent = espFolder
    bgui.StudsOffset = Vector3.new(0, 4, 0)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.2 -- 20% transparent (user requested)
    frame.BorderSizePixel = 0
    frame.Parent = bgui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = (model.Name or "Target")
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 16
    nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextScaled = false
    nameLabel.Parent = bgui
end

-- create toggle button helper
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
    btn.MouseButton1Click:Connect(function()
        clickSound:Play()
        toggled = not toggled
        TweenService:Create(circle, TweenInfo.new(0.16), {
            BackgroundColor3 = toggled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(180, 180, 180)
        }):Play()

        btn:TweenSize(UDim2.new(0, 95, 0, 30), "Out", "Quad", 0.09, true, function()
            btn:TweenSize(UDim2.new(0, 100, 0, 35), "Out", "Quad", 0.09)
        end)

        if callback then callback(toggled) end
    end)

    return btn
end

-- place buttons
local targetNearBtn = createToggleButton("Target Near", function(state)
    targetNearMode = state
    if state then
        selectedPlayer = nil
        -- update esp to nearest immediately if esp enabled
        if espEnabled and HRP then
            local near = getNearestTarget(MAX_RANGE)
            if near then createTargetESP(near) end
        else
            clearESP()
        end
    else
        -- turning off target near doesn't auto-select previous player
        clearESP()
    end
end)
targetNearBtn.Parent = buttonHolder

local m1Btn = createToggleButton("M1", function(state)
    m1Enabled = state
end)
m1Btn.Parent = buttonHolder

local dashBtn = createToggleButton("Dash", function(state)
    dashEnabled = state
end)
dashBtn.Parent = buttonHolder

local espBtn = createToggleButton("ESP", function(state)
    espEnabled = state
    if not espEnabled then
        clearESP()
    else
        -- create esp for current selection or nearest
        local targetModel = nil
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            targetModel = selectedPlayer.Character
        elseif targetNearMode then
            targetModel = getNearestTarget(MAX_RANGE)
        end
        if targetModel then
            createTargetESP(targetModel)
        end
    end
end)
espBtn.Parent = buttonHolder

-- PLAYER LIST ----------------------------------------------------------
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
        if plr ~= player then
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
                clickSound:Play()
                for _, b in ipairs(playerList:GetChildren()) do
                    if b:IsA("TextButton") then
                        b.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
                    end
                end
                btn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
                selectedPlayer = plr
                targetNearMode = false
                -- update esp to this selected player if esp on
                if espEnabled and plr.Character then
                    createTargetESP(plr.Character)
                end
                print("Selected player:", plr.Name)
            end)
        end
    end
end
refreshPlayers()

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 90, 0, 28)
refreshBtn.Position = UDim2.new(1, -100, 1, -35)
refreshBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 14
refreshBtn.Parent = mainFrame
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 8)

refreshBtn.MouseButton1Click:Connect(function()
    clickSound:Play()
    refreshPlayers()
end)

-- ADJUST BUTTON (small button near Refresh) --------------------------------
local adjustBtn = Instance.new("TextButton")
adjustBtn.Size = UDim2.new(0, 80, 0, 28)
adjustBtn.Position = UDim2.new(0, 10, 1, -35) -- left-bottom of mainFrame
adjustBtn.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
adjustBtn.Text = "Adjust"
adjustBtn.TextColor3 = Color3.fromRGB(255,255,255)
adjustBtn.Font = Enum.Font.GothamBold
adjustBtn.TextSize = 14
adjustBtn.Parent = mainFrame
Instance.new("UICorner", adjustBtn).CornerRadius = UDim.new(0, 8)

-- Mini extra settings menu (created once, toggle visibility)
local extraFrame = nil
local function createExtraFrame()
    if extraFrame and extraFrame.Parent then return end

    extraFrame = Instance.new("Frame")
    extraFrame.Name = "AdjustMiniMenu"
    extraFrame.Size = UDim2.new(0, 260, 0, 120)
    -- default position near center of screen; draggable
    extraFrame.Position = UDim2.new(0.5, -130, 0.5, -60)
    extraFrame.BackgroundColor3 = Color3.fromRGB(245,245,245)
    extraFrame.BorderSizePixel = 2
    extraFrame.Parent = gui
    Instance.new("UICorner", extraFrame).CornerRadius = UDim.new(0, 12)

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 8)
    header.BackgroundTransparency = 1
    header.Text = "Adjust Settings"
    header.Font = Enum.Font.GothamBold
    header.TextSize = 18
    header.TextColor3 = Color3.fromRGB(25,25,25)
    header.Parent = extraFrame

    -- Studs row (adjusts ARC_APPROACH_RADIUS)
    local studsLabel = Instance.new("TextLabel")
    studsLabel.Size = UDim2.new(0, 70, 0, 28)
    studsLabel.Position = UDim2.new(0, 12, 0, 46)
    studsLabel.BackgroundTransparency = 1
    studsLabel.Text = "Studs"
    studsLabel.Font = Enum.Font.Gotham
    studsLabel.TextSize = 16
    studsLabel.TextColor3 = Color3.fromRGB(25,25,25)
    studsLabel.TextXAlignment = Enum.TextXAlignment.Left
    studsLabel.Parent = extraFrame

    local studsValue = Instance.new("TextLabel")
    studsValue.Size = UDim2.new(0, 50, 0, 28)
    studsValue.Position = UDim2.new(0, 110, 0, 46)
    studsValue.BackgroundTransparency = 1
    studsValue.Text = tostring(ARC_APPROACH_RADIUS)
    studsValue.Font = Enum.Font.GothamBold
    studsValue.TextSize = 16
    studsValue.TextColor3 = Color3.fromRGB(25,25,25)
    studsValue.Parent = extraFrame
    studsValue.TextXAlignment = Enum.TextXAlignment.Center

    local studsMinus = Instance.new("TextButton")
    studsMinus.Size = UDim2.new(0, 32, 0, 32)
    studsMinus.Position = UDim2.new(0, 170, 0, 44)
    studsMinus.BackgroundColor3 = Color3.fromRGB(200,80,80)
    studsMinus.Text = "-"
    studsMinus.Font = Enum.Font.GothamBold
    studsMinus.TextSize = 20
    studsMinus.TextColor3 = Color3.fromRGB(255,255,255)
    studsMinus.Parent = extraFrame
    Instance.new("UICorner", studsMinus).CornerRadius = UDim.new(0,8)

    local studsPlus = Instance.new("TextButton")
    studsPlus.Size = UDim2.new(0, 32, 0, 32)
    studsPlus.Position = UDim2.new(0, 210, 0, 44)
    studsPlus.BackgroundColor3 = Color3.fromRGB(80,200,100)
    studsPlus.Text = "+"
    studsPlus.Font = Enum.Font.GothamBold
    studsPlus.TextSize = 20
    studsPlus.TextColor3 = Color3.fromRGB(255,255,255)
    studsPlus.Parent = extraFrame
    Instance.new("UICorner", studsPlus).CornerRadius = UDim.new(0,8)

    -- Speed row (adjusts SPEED_SETTING that changes tween time)
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Size = UDim2.new(0, 70, 0, 28)
    speedLabel.Position = UDim2.new(0, 12, 0, 82)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Speed"
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextSize = 16
    speedLabel.TextColor3 = Color3.fromRGB(25,25,25)
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = extraFrame

    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(0, 50, 0, 28)
    speedValue.Position = UDim2.new(0, 110, 0, 82)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = string.format("%.1f", SPEED_SETTING)
    speedValue.Font = Enum.Font.GothamBold
    speedValue.TextSize = 16
    speedValue.TextColor3 = Color3.fromRGB(25,25,25)
    speedValue.Parent = extraFrame
    speedValue.TextXAlignment = Enum.TextXAlignment.Center

    local speedMinus = Instance.new("TextButton")
    speedMinus.Size = UDim2.new(0, 32, 0, 32)
    speedMinus.Position = UDim2.new(0, 170, 0, 80)
    speedMinus.BackgroundColor3 = Color3.fromRGB(200,80,80)
    speedMinus.Text = "-"
    speedMinus.Font = Enum.Font.GothamBold
    speedMinus.TextSize = 20
    speedMinus.TextColor3 = Color3.fromRGB(255,255,255)
    speedMinus.Parent = extraFrame
    Instance.new("UICorner", speedMinus).CornerRadius = UDim.new(0,8)

    local speedPlus = Instance.new("TextButton")
    speedPlus.Size = UDim2.new(0, 32, 0, 32)
    speedPlus.Position = UDim2.new(0, 210, 0, 80)
    speedPlus.BackgroundColor3 = Color3.fromRGB(80,200,100)
    speedPlus.Text = "+"
    speedPlus.Font = Enum.Font.GothamBold
    speedPlus.TextSize = 20
    speedPlus.TextColor3 = Color3.fromRGB(255,255,255)
    speedPlus.Parent = extraFrame
    Instance.new("UICorner", speedPlus).CornerRadius = UDim.new(0,8)

    -- Button logic
    studsMinus.MouseButton1Click:Connect(function()
        -- decrease ARC_APPROACH_RADIUS by 1, min 0.5
        ARC_APPROACH_RADIUS = math.max(0.5, ARC_APPROACH_RADIUS - 1)
        studsValue.Text = tostring(ARC_APPROACH_RADIUS)
    end)

    studsPlus.MouseButton1Click:Connect(function()
        -- increase ARC_APPROACH_RADIUS by 1, max 40
        ARC_APPROACH_RADIUS = math.min(40, ARC_APPROACH_RADIUS + 1)
        studsValue.Text = tostring(ARC_APPROACH_RADIUS)
    end)

    speedMinus.MouseButton1Click:Connect(function()
        -- decrease SPEED_SETTING by 0.1, clamp to 0.4 minimum
        SPEED_SETTING = math.max(0.1, math.floor((SPEED_SETTING - 0.1) * 10 + 0.5) / 10)
        SPEED_SETTING = math.max(0.1, SPEED_SETTING)
        speedValue.Text = string.format("%.1f", SPEED_SETTING)
    end)

    speedPlus.MouseButton1Click:Connect(function()
        -- increase SPEED_SETTING by 0.1, clamp to 3.0 maximum
        SPEED_SETTING = math.min(5.0, math.floor((SPEED_SETTING + 0.1) * 10 + 0.5) / 10)
        speedValue.Text = string.format("%.1f", SPEED_SETTING)
    end)

    -- Make the extraFrame draggable
    makeDraggable(extraFrame)

    -- small close button (top-right)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -26, 0, 6)
    closeBtn.Text = "x"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
    closeBtn.Parent = extraFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        if extraFrame and extraFrame.Parent then
            extraFrame:Destroy()
            extraFrame = nil
        end
    end)
end

adjustBtn.MouseButton1Click:Connect(function()
    clickSound:Play()
    if not extraFrame or not extraFrame.Parent then
        createExtraFrame()
    else
        -- toggle visibility / destroy
        extraFrame:Destroy()
        extraFrame = nil
    end
end)



-- MINIMIZE / OPEN ANIMS ------------------------------------------------
local miniFrame = Instance.new("TextButton")
miniFrame.Size = UDim2.new(0, 100, 0, 45)
miniFrame.Position = UDim2.new(0.5, -50, 0.5, -22)
miniFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
miniFrame.Text = "Settings"
miniFrame.TextColor3 = Color3.fromRGB(0,0,0)
miniFrame.Font = Enum.Font.GothamBold
miniFrame.TextSize = 16
miniFrame.Visible = false
miniFrame.Parent = gui
miniFrame.BorderSizePixel = 2
miniFrame.BorderColor3 = Color3.fromRGB(0,0,0)
Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(0, 10)

local function pressAnim(button, cb)
    button.MouseButton1Click:Connect(function()
        button:TweenSize(button.Size - UDim2.new(0,5,0,5), "Out", "Quad", 0.08, true, function()
            button:TweenSize(button.Size + UDim2.new(0,5,0,5), "Out", "Quad", 0.08)
            if cb then cb() end
        end)
    end)
end

pressAnim(minimizeBtn, function()
    clickSound:Play()
    -- close animation then show mini
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    {Size = UDim2.new(0, 0, 0, 0)})
    tween:Play()
    tween.Completed:Wait()
    mainFrame.Visible = false
    miniFrame.Visible = true
end)

pressAnim(miniFrame, function()
    clickSound:Play()
    miniFrame.Visible = false
    mainFrame.Visible = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Size = UDim2.new(0, 280, 0, 270)}):Play()
end)

-- Draggable
makeDraggable(mainFrame)
makeDraggable(miniFrame)

-- Finish UI
print("Settings GUI loaded.")

local function createDashButton()
    local screenGui = gui -- use same gui
    local button = Instance.new("ImageButton")
    button.Name = "DashButton_Merged"
    button.Size = UDim2.new(0,110,0,110)
    button.Position = UDim2.new(0.5, -55, 0.8, -55) -- centered bottom by default
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://99317918824094"
    button.Parent = screenGui
    button.Active = true

    local uiScale = Instance.new("UIScale", button)
    uiScale.Scale = 1

    local pressSFX = Instance.new("Sound")
    pressSFX.Name = "PressSFX"
    pressSFX.SoundId = PRESS_SFX_ID
    pressSFX.Volume = 0.9
    pressSFX.Looped = false
    pressSFX.Parent = button

    -- Draggable / tap behavior with scale tween & drag threshold
    local isPointerDown, isDragging, pointerStartPos, buttonStartPos, trackedInput = false, false, nil, nil, nil
    local dragThreshold = 8

    local function tweenUIScale(toScale, time)
        time = time or 0.06
        local ok, tw = pcall(function() return TweenService:Create(uiScale, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = toScale}) end)
        if ok and tw then tw:Play() end
    end

    local function startPointer(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPointerDown = true
            isDragging = false
            pointerStartPos = input.Position
            buttonStartPos = button.Position
            trackedInput = input
            tweenUIScale(0.92, 0.06)
            pcall(function() pressSFX:Play() end)
        end
    end

    local function updatePointer(input)
        if not isPointerDown or not pointerStartPos or input ~= trackedInput then return end
        local delta = input.Position - pointerStartPos
        if not isDragging and delta.Magnitude >= dragThreshold then
            isDragging = true
            tweenUIScale(1, 0.06)
        end
        if isDragging then
            local screenW, screenH = Workspace.CurrentCamera.ViewportSize.X, Workspace.CurrentCamera.ViewportSize.Y
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
            -- Determine target based on selection/targetNearMode
            local targetModel = nil
            if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                targetModel = selectedPlayer.Character
            elseif targetNearMode then
                targetModel = getNearestTarget(MAX_RANGE)
            else
                -- fallback: nearest
                targetModel = getNearestTarget(MAX_RANGE)
            end

            if targetModel then
                local started = false
                local ok, err = pcall(function() started = smoothArcToTarget(targetModel) end)
                if ok and started then
                    pcall(function() pressSFX:Play() end)
                    -- Added 0.1 second delay before M1 activates (only change)
                    if m1Enabled then
                        delay(0.1, function() pcall(sendM1) end)
                    end
                    if dashEnabled then pcall(sendDash) end
                end
            end
        end
        tweenUIScale(1, 0.06)
        isPointerDown, isDragging, pointerStartPos, buttonStartPos, trackedInput = false, false, nil, nil, nil
    end)

    button.InputBegan:Connect(function(input) pcall(function() startPointer(input) end) end)

    return button
end

local dashButton = createDashButton()

-- Keyboard and gamepad bindings (X and DPadUp)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if busy then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X)
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.DPadUp) then
        -- Determine target
        local targetModel = nil
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            targetModel = selectedPlayer.Character
        elseif targetNearMode then
            targetModel = getNearestTarget(MAX_RANGE)
        else
            targetModel = getNearestTarget(MAX_RANGE)
        end

        if targetModel then
            local started = false
            local ok, err = pcall(function() started = smoothArcToTarget(targetModel) end)
            if ok and started then
                -- Added 0.1 second delay before M1 activates (only change)
                if m1Enabled then
                    delay(0.1, function() pcall(sendM1) end)
                end
                if dashEnabled then pcall(sendDash) end
            end
        end
    end
end)

-- Ensure player list updates when players join/leave
Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)

-- ESP heartbeat: if esp enabled and target selection changes dynamically (e.g., nearest), update
RunService.Heartbeat:Connect(function()
    if not espEnabled then return end
    local targetModel = nil
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        targetModel = selectedPlayer.Character
    elseif targetNearMode then
        targetModel = getNearestTarget(MAX_RANGE)
    end
    if targetModel then
        createTargetESP(targetModel)
    else
        clearESP()
    end
end)

print("[Merged] Circular linear-velocity + Settings updated and ready.")
