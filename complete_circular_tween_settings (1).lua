--// Merebennie: COMPLETE Circular Tween + Settings (Delta Mobile Compatible)
-- Full script (Lua) — drop into Delta executor (LocalScript style)
-- Features: Settings UI (width increased), Land Studs + Dash speed adjusters, Dash button, smooth arc tween, ESP, M1/Dash toggles.

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Player / Character refs
local player = Players.LocalPlayer or Players:GetPlayers()[1]
if not player then
    error("Player not found. Ensure script runs as local script in client / Delta executor.")
end

local Character = player.Character or player.CharacterAdded:Wait()
local HRP = Character:FindFirstChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
player.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChildOfClass("Humanoid")
end)

-- === Config defaults ===
local MAX_RANGE = 40
local ARC_APPROACH_RADIUS = 11
local LAND_STUDS = 5           -- adjustable
local TOTAL_TIME = 0.30        -- adjustable (seconds) = "Dash speed"
local MIN_RADIUS = 1.2
local MAX_RADIUS = 14
local ANIM_LEFT_ID = 10480796021
local ANIM_RIGHT_ID = 10480793962
local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID = "rbxassetid://72014632956520"

-- state
local busy = false
local currentAnimTrack = nil

-- toggles & selection
local espEnabled = false
local m1Enabled = false
local dashEnabled = false
local targetNearMode = false
local selectedPlayer = nil

-- Helpers: safe pcall wrapper
local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        warn("SafeCall error:", res)
    end
    return ok, res
end

-- Communicate helper (some games use this pattern)
local function getCommunicate()
    local char = player.Character or player.CharacterAdded:Wait()
    if char then return char:FindFirstChild("Communicate") end
    return nil
end

local function safeSend(args)
    pcall(function()
        local comm = getCommunicate()
        if comm and typeof(comm.FireServer) == "function" then
            comm:FireServer(unpack(args))
        end
    end)
end

local function sendDash()
    -- this is a best-effort mobile Dash send; many games vary - adapt to your game's remote
    pcall(function()
        local comm = getCommunicate()
        if comm and typeof(comm.FireServer) == "function" then
            local args = {
                [1] = {
                    ["Dash"] = Enum.KeyCode.W,
                    ["Key"] = Enum.KeyCode.Q,
                    ["Goal"] = "KeyPress"
                }
            }
            comm:FireServer(unpack(args))
        end
    end)
end

local function sendM1()
    pcall(function()
        local comm = getCommunicate()
        if comm and typeof(comm.FireServer) == "function" then
            local press = {
                [1] = {
                    ["Mobile"] = true,
                    ["Goal"] = "LeftClick"
                }
            }
            local release = {
                [1] = {
                    ["Goal"] = "LeftClickRelease",
                    ["Mobile"] = true
                }
            }
            comm:FireServer(unpack(press))
            wait(0.06)
            comm:FireServer(unpack(release))
        end
    end)
end

-- Audio (UI)
local function makeSound(parent, id, volume)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume or 1
    s.Parent = parent
    return s
end

-- Animation helpers
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
    safeCall(function()
        if currentAnimTrack and currentAnimTrack.IsPlaying then
            pcall(function() currentAnimTrack:Stop() end)
            currentAnimTrack = nil
        end
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
        delay(TOTAL_TIME + 0.15, function()
            if track and track.IsPlaying then pcall(function() track:Stop() end) end
            pcall(function() anim:Destroy() end)
        end)
    end)
end

-- math helpers
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

-- Get nearest target (players + NPCs)
local function getNearestTarget(maxRange)
    maxRange = maxRange or MAX_RANGE
    if not HRP then return nil end
    local myPos = HRP.Position
    local nearest, nearestDist = nil, math.huge
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChildOfClass("Humanoid") then
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
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

-- Smooth circular arc to target (main movement)
local function smoothArcToTarget(targetModel)
    if busy then return false end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return false end
    if not HRP then return false end

    busy = true
    local startedOk = false

    safeCall(function()
        local targetHRP = targetModel.HumanoidRootPart
        local center = targetHRP.Position
        local myPos = HRP.Position
        local lookVec = targetHRP.CFrame.LookVector
        local toMe = myPos - center
        local forwardDot = lookVec:Dot(toMe)
        local finalPos
        if forwardDot > 0 then
            finalPos = center - lookVec * LAND_STUDS
        else
            finalPos = center + lookVec * LAND_STUDS
        end
        finalPos = Vector3.new(finalPos.X, center.Y + 1.5, finalPos.Z)

        local startRadius = (Vector3.new(myPos.X,0,myPos.Z) - Vector3.new(center.X,0,center.Z)).Magnitude
        local midRadius = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
        local endRadius = (Vector3.new(finalPos.X,0,finalPos.Z) - Vector3.new(center.X,0,center.Z)).Magnitude
        local startAngle = math.atan2(myPos.Z - center.Z, myPos.X - center.X)
        local endAngle = math.atan2(finalPos.Z - center.Z, finalPos.X - center.X)
        local deltaAngle = shortestAngleDelta(endAngle, startAngle)
        local isLeft = (deltaAngle > 0)

        pcall(function() playSideAnimation(isLeft) end)

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
        conn = RunService.Heartbeat:Connect(function()
            if not targetHRP or not targetHRP.Parent then
                if humanoid and oldAutoRotate ~= nil then pcall(function() humanoid.AutoRotate = oldAutoRotate end) end
                if conn and conn.Connected then conn:Disconnect() end
                busy = false
                return
            end
            local now = tick()
            local t = math.clamp((now - startTime) / TOTAL_TIME, 0, 1)
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
            local toTargetFromHRP = targetHRP.Position - posNow
            if toTargetFromHRP.Magnitude < 0.001 then toTargetFromHRP = Vector3.new(lookVec.X, 0, lookVec.Z) end
            local currentDesiredHRPYaw = math.atan2(toTargetFromHRP.Z, toTargetFromHRP.X)
            local deltaHRPYaw = shortestAngleDelta(currentDesiredHRPYaw, startHRPYaw)
            local hrpYawNow = startHRPYaw + deltaHRPYaw * e
            local hrpLook = Vector3.new(math.cos(hrpYawNow), 0, math.sin(hrpYawNow))
            pcall(function() HRP.CFrame = CFrame.new(posNow, posNow + hrpLook) end)

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
                local finalToTarget = targetHRP.Position - finalPos
                if finalToTarget.Magnitude < 0.001 then finalToTarget = Vector3.new(lookVec.X, 0, lookVec.Z) end
                local finalYaw = math.atan2(finalToTarget.Z, finalToTarget.X)
                pcall(function() HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(math.cos(finalYaw), 0, math.sin(finalYaw))) end)
                pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack = nil end)
                if humanoid and oldAutoRotate ~= nil then pcall(function() humanoid.AutoRotate = oldAutoRotate end) end
                busy = false
            end
        end)
    end)

    return true
end

-- ============= UI (robust creation & visibility safe) =============
-- Create ScreenGui early and parent to PlayerGui
local gui
safeCall(function()
    gui = Instance.new("ScreenGui")
    gui.Name = "Merebennie_SettingsGUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1000
    gui.Parent = player:WaitForChild("PlayerGui")
end)
if not gui then error("Failed to create ScreenGui.") end

-- Debug label
local dbg = Instance.new("TextLabel")
dbg.Size = UDim2.new(0,220,0,26)
dbg.Position = UDim2.new(0,6,0,6)
dbg.BackgroundTransparency = 0.4
dbg.Text = "Settings GUI loaded"
dbg.TextSize = 14
dbg.TextColor3 = Color3.new(1,1,1)
dbg.BackgroundColor3 = Color3.fromRGB(0,0,0)
dbg.Visible = false
dbg.Parent = gui

-- Click sound
local clickSound = makeSound(gui, "rbxassetid://6042053626", 0.85)

-- Draggable helper
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Main frame (increased width only)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 360, 0, 270)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -135)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(245,245,245)
mainFrame.BackgroundTransparency = 0.08
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚙️ Settings"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(25,25,25)
title.Parent = mainFrame

-- Show/hide fallback button
local showBtn = Instance.new("TextButton")
showBtn.Name = "ShowSettingsBtn"
showBtn.Size = UDim2.new(0, 110, 0, 36)
showBtn.Position = UDim2.new(0, 8, 0, 8)
showBtn.BackgroundColor3 = Color3.fromRGB(200,200,200)
showBtn.TextColor3 = Color3.new(0,0,0)
showBtn.Text = "Show Settings"
showBtn.Font = Enum.Font.Gotham
showBtn.TextSize = 14
showBtn.Parent = gui
Instance.new("UICorner", showBtn).CornerRadius = UDim.new(0, 8)
showBtn.MouseButton1Click:Connect(function()
    clickSound:Play()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Buttons container (toggles)
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

-- ESP folder
local espFolder = Instance.new("Folder", gui)
espFolder.Name = "ESPFolder"

local function clearESP()
    for _, v in ipairs(espFolder:GetChildren()) do v:Destroy() end
end

local function createTargetESP(model)
    clearESP()
    if not model or not model.Parent then return end
    local adornee = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not adornee then return end
    local bgui = Instance.new("BillboardGui")
    bgui.Size = UDim2.new(0, 140, 0, 40)
    bgui.Adornee = adornee
    bgui.AlwaysOnTop = true
    bgui.Parent = espFolder
    bgui.StudsOffset = Vector3.new(0, 2.2, 0)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0
    frame.Parent = bgui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -6, 1, 0)
    name.Position = UDim2.new(0,3,0,0)
    name.BackgroundTransparency = 1
    name.Text = model.Name or "Target"
    name.Font = Enum.Font.GothamBold
    name.TextSize = 14
    name.TextColor3 = Color3.fromRGB(255,255,255)
    name.Parent = bgui
end

-- Toggle button maker
local function createToggleButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(235,235,235)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(25,25,25)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 15, 0, 15)
    circle.Position = UDim2.new(1, -24, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(180,180,180)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local toggled = false
    btn.MouseButton1Click:Connect(function()
        clickSound:Play()
        toggled = not toggled
        TweenService:Create(circle, TweenInfo.new(0.14), {BackgroundColor3 = toggled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(180,180,180)}):Play()
        if callback then callback(toggled) end
    end)
    return btn
end

-- Buttons: Target Near, M1, Dash, ESP
local targetNearBtn = createToggleButton("Target Near", function(state)
    targetNearMode = state
    if state then
        selectedPlayer = nil
        if espEnabled and HRP then
            local near = getNearestTarget(MAX_RANGE)
            if near then createTargetESP(near) end
        else
            clearESP()
        end
    else
        clearESP()
    end
end)
targetNearBtn.Parent = buttonHolder

local m1Btn = createToggleButton("M1", function(state) m1Enabled = state end)
m1Btn.Parent = buttonHolder

local dashBtn = createToggleButton("Dash", function(state) dashEnabled = state end)
dashBtn.Parent = buttonHolder

local espBtn = createToggleButton("ESP", function(state)
    espEnabled = state
    if not espEnabled then clearESP() else
        local targetModel = nil
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            targetModel = selectedPlayer.Character
        elseif targetNearMode then
            targetModel = getNearestTarget(MAX_RANGE)
        end
        if targetModel then createTargetESP(targetModel) end
    end
end)
espBtn.Parent = buttonHolder

-- Player list
local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, -20, 0, 68)
playerList.Position = UDim2.new(0, 10, 0, 145)
playerList.BackgroundColor3 = Color3.fromRGB(230,230,230)
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
            btn.Size = UDim2.new(1, -6, 0, 22)
            btn.BackgroundColor3 = Color3.fromRGB(245,245,245)
            btn.TextColor3 = Color3.fromRGB(25,25,25)
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.Text = "   " .. plr.Name
            btn.Parent = playerList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

            btn.MouseButton1Click:Connect(function()
                clickSound:Play()
                for _, b in ipairs(playerList:GetChildren()) do
                    if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(245,245,245) end
                end
                btn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
                selectedPlayer = plr
                targetNearMode = false
                if espEnabled and plr.Character then createTargetESP(plr.Character) end
            end)
        end
    end
end
refreshPlayers()
Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)

-- Adjust controls for Land Studs & Dash speed (below player list)
local adjustFrame = Instance.new("Frame")
adjustFrame.Size = UDim2.new(1, -20, 0, 44)
adjustFrame.Position = UDim2.new(0, 10, 0, 214)
adjustFrame.BackgroundTransparency = 1
adjustFrame.Parent = mainFrame

local leftPanel = Instance.new("Frame", adjustFrame)
leftPanel.Size = UDim2.new(0.48, 0, 1, 0)
leftPanel.BackgroundTransparency = 1
local rightPanel = Instance.new("Frame", adjustFrame)
rightPanel.Size = UDim2.new(0.48, 0, 1, 0)
rightPanel.Position = UDim2.new(0.52, 0, 0, 0)
rightPanel.BackgroundTransparency = 1

local function createAdjustControls(panel, labelText, initialValue, minVal, maxVal, step, formatFn, onChanged)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(25,25,25)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = panel

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 26, 0, 26)
    minus.Position = UDim2.new(0.66, 0, 0.5, -13)
    minus.Text = "-"
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 18
    minus.Parent = panel
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 26, 0, 26)
    plus.Position = UDim2.new(0.92, 0, 0.5, -13)
    plus.Text = "+"
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 18
    plus.Parent = panel
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.74, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextColor3 = Color3.fromRGB(25,25,25)
    valueLabel.Text = formatFn(initialValue)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Center
    valueLabel.Parent = panel

    local current = initialValue
    local function update(v)
        current = math.clamp(v, minVal, maxVal)
        valueLabel.Text = formatFn(current)
        if onChanged then pcall(function() onChanged(current) end) end
    end

    minus.MouseButton1Click:Connect(function()
        clickSound:Play()
        update(current - step)
    end)
    plus.MouseButton1Click:Connect(function()
        clickSound:Play()
        update(current + step)
    end)

    return {
        get = function() return current end,
        set = function(v) update(v) end
    }
end

local landControl = createAdjustControls(leftPanel, "Land Studs", LAND_STUDS, 1, 30, 1, function(v) return tostring(math.floor(v)) end,
    function(v)
        LAND_STUDS = math.floor(v)
        mainFrame:SetAttribute("LAND_STUDS", LAND_STUDS)
    end)

local dashControl = createAdjustControls(rightPanel, "Dash speed (s)", TOTAL_TIME, 0.05, 1.5, 0.05, function(v) return string.format("%.2f", v) end,
    function(v)
        TOTAL_TIME = v
        mainFrame:SetAttribute("TOTAL_TIME", TOTAL_TIME)
    end)

-- Set initial attributes
mainFrame:SetAttribute("LAND_STUDS", LAND_STUDS)
mainFrame:SetAttribute("TOTAL_TIME", TOTAL_TIME)

-- Refresh button
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 86, 0, 28)
refreshBtn.Position = UDim2.new(1, -100, 1, -36)
refreshBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 14
refreshBtn.Parent = mainFrame
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0,8)
refreshBtn.MouseButton1Click:Connect(function()
    clickSound:Play()
    refreshPlayers()
end)

-- Minimize / restore (same as Show)
local miniBtn = Instance.new("TextButton")
miniBtn.Size = UDim2.new(0, 34, 0, 34)
miniBtn.Position = UDim2.new(1, -44, 0, 4)
miniBtn.BackgroundColor3 = Color3.fromRGB(220,220,220)
miniBtn.Text = "-"
miniBtn.Font = Enum.Font.GothamBold
miniBtn.TextSize = 18
miniBtn.TextColor3 = Color3.fromRGB(20,20,20)
miniBtn.Parent = mainFrame
Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 9)
miniBtn.MouseButton1Click:Connect(function()
    clickSound:Play()
    mainFrame.Visible = false
    showBtn.Visible = true
end)
-- Clicking showBtn restores
showBtn.Visible = true
showBtn.MouseButton1Click:Connect(function()
    clickSound:Play()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Make draggable
makeDraggable(mainFrame)
makeDraggable(showBtn)

-- Dash Button (mobile-friendly)
local function createDashButton()
    local btn = Instance.new("ImageButton")
    btn.Name = "DashButton"
    btn.Size = UDim2.new(0, 110, 0, 110)
    btn.Position = UDim2.new(0.5, -55, 0.82, -55)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundTransparency = 0
    btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
    btn.BorderSizePixel = 0
    btn.Image = "" -- avoid external asset problems
    btn.Parent = gui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = "DASH"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 20
    label.TextColor3 = Color3.new(1,1,1)
    label.Parent = btn

    local uiScale = Instance.new("UIScale", btn)
    uiScale.Scale = 1

    local pressSFX = makeSound(btn, PRESS_SFX_ID, 0.9)
    local dashSFX = makeSound(Workspace, DASH_SFX_ID, 1.4)

    -- pointer handling (tap vs drag)
    local isPointerDown, isDragging, pointerStartPos, startPos, trackedInput = false, false, nil, nil, nil
    local dragThreshold = 8

    local function tweenScale(to, t)
        t = t or 0.06
        pcall(function() TweenService:Create(uiScale, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = to}):Play() end)
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPointerDown = true
            isDragging = false
            pointerStartPos = input.Position
            startPos = btn.Position
            trackedInput = input
            tweenScale(0.92, 0.06)
            pcall(function() pressSFX:Play() end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not isPointerDown then return end
        if input ~= trackedInput then return end
        local delta = input.Position - pointerStartPos
        if not isDragging and delta.Magnitude >= dragThreshold then
            isDragging = true
            tweenScale(1, 0.06)
        end
        if isDragging then
            local screenW, screenH = Workspace.CurrentCamera.ViewportSize.X, Workspace.CurrentCamera.ViewportSize.Y
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, screenW - btn.AbsoluteSize.X)
            newY = math.clamp(newY, 0, screenH - btn.AbsoluteSize.Y)
            btn.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input ~= trackedInput or not isPointerDown then return end
        if not isDragging and not busy then
            -- choose target
            local targetModel = nil
            if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                targetModel = selectedPlayer.Character
            elseif targetNearMode then
                targetModel = getNearestTarget(MAX_RANGE)
            else
                targetModel = getNearestTarget(MAX_RANGE)
            end

            if targetModel then
                local ok, started = pcall(function() return smoothArcToTarget(targetModel) end)
                if ok and started then
                    pcall(function() pressSFX:Play() end)
                    pcall(function() dashSFX:Play() end)
                    if m1Enabled then safeCall(sendM1) end
                    if dashEnabled then safeCall(sendDash) end
                end
            else
                dbg.Visible = true
                dbg.Text = "No target found."
                delay(1.2, function() dbg.Visible = false end)
            end
        end
        tweenScale(1, 0.06)
        isPointerDown, isDragging, pointerStartPos, startPos, trackedInput = false, false, nil, nil, nil
    end)

    return btn
end

local dashButton = createDashButton()

-- Keyboard / gamepad binding for X / DPadUp
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if busy then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X)
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.DPadUp) then
        local targetModel = nil
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            targetModel = selectedPlayer.Character
        elseif targetNearMode then
            targetModel = getNearestTarget(MAX_RANGE)
        else
            targetModel = getNearestTarget(MAX_RANGE)
        end
        if targetModel then
            local ok, started = pcall(function() return smoothArcToTarget(targetModel) end)
            if ok and started then
                if m1Enabled then safeCall(sendM1) end
                if dashEnabled then safeCall(sendDash) end
            end
        end
    end
end)

-- Keep ESP up-to-date
RunService.Heartbeat:Connect(function()
    if not espEnabled then return end
    local targetModel = nil
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        targetModel = selectedPlayer.Character
    elseif targetNearMode then
        targetModel = getNearestTarget(MAX_RANGE)
    end
    if targetModel then createTargetESP(targetModel) else clearESP() end
end)

print("[Merebennie] COMPLETE script loaded. LAND_STUDS="..tostring(LAND_STUDS).." TOTAL_TIME="..tostring(TOTAL_TIME))
