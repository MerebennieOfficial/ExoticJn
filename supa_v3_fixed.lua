
-- Supa Tech V3 — Optimized for PC executors (reduces FPS/stutter by avoiding per-frame CFrame updates)
-- Changes: uses LinearVelocity + Attachment to move the HumanoidRootPart during the "lay down" phase.
-- Fallback: if LinearVelocity isn't available, it falls back to a less-frequent Heartbeat mover.
-- Saved/Restored humanoid state as before. UI and cooldown behavior preserved.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character, Humanoid, HumanoidRootPart

local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.3
local enabled = true
local uiOnCooldown = false
local COOLDOWN_DURATION = 4

local DISCORD_LINK = "https://discord.gg/RsxcaHhRqb"

-- Optimized nearest-target search: iterate children (faster than GetDescendants for large worlds)
local function getNearestTarget(maxDist)
    maxDist = maxDist or 20
    local nearest, dist = nil, maxDist
    if not HumanoidRootPart then return nil end
    for _, obj in pairs(workspace:GetChildren()) do
        if obj ~= Character and obj:IsA("Model") then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp then
                local ok, mag = pcall(function()
                    return (HumanoidRootPart.Position - hrp.Position).Magnitude
                end)
                if ok and mag and mag < dist then
                    dist = mag
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

local function fireQ()
    pcall(function()
        local args = {
            [1] = {
                ["Dash"] = Enum.KeyCode.W,
                ["Key"] = Enum.KeyCode.Q,
                ["Goal"] = "KeyPress"
            }
        }
        if Character and Character:FindFirstChild("Communicate") then
            Character.Communicate:FireServer(unpack(args))
        end
    end)

    -- safe getnilinstances usage (if it exists)
    local function getNil(name, class)
        if typeof(getnilinstances) ~= "function" then return nil end
        for _, v in pairs(getnilinstances()) do
            if v.ClassName == class and v.Name == name then
                return v
            end
        end
    end

    pcall(function()
        local args2 = {
            [1] = {
                ["Goal"] = "delete bv",
                ["BV"] = getNil("moveme", "BodyVelocity")
            }
        }
        if Character and Character:FindFirstChild("Communicate") then
            Character.Communicate:FireServer(unpack(args2))
        end
    end)
end

local function stickDash()
    if not (Character and Humanoid and HumanoidRootPart) then return end

    local target = getNearestTarget(20)
    if not target then return end
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- Save humanoid state
    local saved = {}
    pcall(function()
        saved.WalkSpeed = Humanoid.WalkSpeed
        saved.JumpPower = Humanoid.JumpPower
        saved.PlatformStand = Humanoid.PlatformStand
        if Humanoid:GetAttribute("AutoRotate") == nil then
            pcall(function() saved.AutoRotate = Humanoid.AutoRotate end)
        else
            saved.AutoRotate = Humanoid.AutoRotate
        end
    end)

    local antiConn

    local function startImmobilize()
        if not Humanoid or not HumanoidRootPart or not Character then return end
        pcall(function()
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            Humanoid.PlatformStand = true
            pcall(function() Humanoid.AutoRotate = false end)
            HumanoidRootPart.Velocity = Vector3.new(0,0,0)
            HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
        end)
        -- Clean up common movers (reduce chance of conflicting forces)
        for _, v in pairs(Character:GetDescendants()) do
            local class = v.ClassName
            if class == "BodyVelocity" or class == "BodyPosition" or class == "BodyGyro" or class == "VectorForce" or class == "AlignPosition" or class == "AlignOrientation" or class == "LinearVelocity" or class == "AngularVelocity" then
                pcall(function() v:Destroy() end)
            end
        end
        antiConn = RunService.Heartbeat:Connect(function()
            if HumanoidRootPart then
                -- keep velocities zeroed to avoid tiny physics drift
                pcall(function()
                    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                    HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
                end)
            end
            if Humanoid and Humanoid.WalkSpeed then
                pcall(function() Humanoid.WalkSpeed = 0 end)
            end
        end)
    end

    local function stopImmobilize()
        if antiConn and antiConn.Disconnect then
            pcall(function() antiConn:Disconnect() end)
        end
        pcall(function()
            if Humanoid then
                Humanoid.WalkSpeed = saved.WalkSpeed or 16
                Humanoid.JumpPower = saved.JumpPower or 50
                Humanoid.PlatformStand = saved.PlatformStand or false
                if saved.AutoRotate ~= nil then pcall(function() Humanoid.AutoRotate = saved.AutoRotate end) end
            end
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
        end)
    end

    startImmobilize()
    pcall(fireQ) -- Fire Q first
    task.wait(0.18) -- small wait before laying down

    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)

    -- compute desired final CFrame (slightly behind the target, with 60 deg tilt)
    local desiredPos = targetHRP.Position - (targetHRP.CFrame.LookVector * 0.3)
    local desiredCFrame = CFrame.new(desiredPos) * CFrame.Angles(math.rad(60), 0, 0)

    local layDuration = 0.18
    local startPos = HumanoidRootPart.Position

    local movedWithLinearVelocity = false
    -- Try to use LinearVelocity for a smooth movement (lower CPU than per-frame CFrame)
    pcall(function()
        if typeof(Instance.new("LinearVelocity")) == "Instance" then
            -- Create a short-lived attachment and LinearVelocity
            local att = Instance.new("Attachment")
            att.Name = "supa_move_att"
            att.Parent = HumanoidRootPart

            local lv = Instance.new("LinearVelocity")
            lv.Name = "supa_move_lv"
            lv.Attachment0 = att
            lv.RelativeTo = Enum.ActuatorRelativeTo.World
            lv.MaxForce = math.huge
            local velocity = (desiredPos - startPos) / layDuration
            lv.VectorVelocity = velocity
            lv.Parent = HumanoidRootPart

            movedWithLinearVelocity = true
            -- wait for the duration then snap final orientation/position and cleanup
            task.wait(layDuration)
            pcall(function()
                -- set final CFrame (safe pcall)
                if HumanoidRootPart then
                    HumanoidRootPart.CFrame = desiredCFrame
                end
            end)
            pcall(function() if lv then lv:Destroy() end end)
            pcall(function() if att then att:Destroy() end end)
        end
    end)

    -- Fallback: if LinearVelocity wasn't available, do a single reduced-frequency mover
    if not movedWithLinearVelocity then
        local startTime = tick()
        local lastUpdate = startTime
        -- move via less-frequent updates (every Heartbeat but with minimal work)
        local conn
        conn = RunService.Heartbeat:Connect(function()
            local now = tick()
            if not HumanoidRootPart then
                if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
                return
            end
            local elapsed = now - startTime
            if elapsed >= layDuration then
                pcall(function()
                    HumanoidRootPart.CFrame = desiredCFrame
                end)
                if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
                return
            end
            -- Only update position at a lower rate (every ~0.03s) to reduce overhead
            if now - lastUpdate >= 0.03 then
                lastUpdate = now
                local alpha = math.clamp(elapsed / layDuration, 0, 1)
                local newPos = startPos:Lerp(desiredPos, alpha)
                pcall(function() HumanoidRootPart.CFrame = CFrame.new(newPos) * CFrame.Angles(math.rad(60), 0, 0) end)
            end
        end)
        -- wait until movement completes
        repeat task.wait(0.01) until tick() - startTime >= layDuration
    end

    -- get up and restore
    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    pcall(stopImmobilize)
end

-- UI creation (kept largely the same, except minor performance-safe tweaks)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Merebennie_StickDashGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.Parent = playerGui

local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
Button.Size = UDim2.new(0, 140, 0, 25)
Button.Position = UDim2.new(0.4, 0, 0.8, 0)
Button.Text = "Supa Tech V2: On"
Button.Font = Enum.Font.GothamBold
Button.TextScaled = true
Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.TextStrokeTransparency = 1
Button.AutoButtonColor = false
Button.ZIndex = 9999
Button.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = Button

local ButtonClickSound = Instance.new("Sound")
ButtonClickSound.Name = "ButtonClickSound"
ButtonClickSound.SoundId = "rbxassetid://6042053626"
ButtonClickSound.Volume = 1
ButtonClickSound.Looped = false
ButtonClickSound.Parent = Button

Button.MouseButton1Click:Connect(function()
    pcall(function() ButtonClickSound:Play() end)
    -- smaller and faster tween for click feedback
    local ok, _ = pcall(function()
        Button:TweenSize(UDim2.new(0,136,0,23),"Out","Quad",0.05,true)
        task.wait(0.05)
        Button:TweenSize(UDim2.new(0,140,0,25),"Out","Quad",0.05,true)
    end)
end)

local dragging, dragInput, dragStart, startPos
Button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Button.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
Button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging and startPos then
        local delta = input.Position - dragStart
        Button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- toggle enabled
Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        Button.Text = "Supa Tech V2: On"
        Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Button.TextColor3 = Color3.fromRGB(255,255,255)
    else
        Button.Text = "Supa Tech V2: Off"
        Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Button.TextColor3 = Color3.fromRGB(255,255,255)
    end
end)

-- Credit frame (shows once then destroys)
local CreditFrame = Instance.new("Frame")
CreditFrame.Name = "CreditFrame"
CreditFrame.Size = UDim2.new(0, 200, 0, 100)
CreditFrame.Position = UDim2.new(1, 0, 0.1, 0)
CreditFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CreditFrame.ZIndex = 9999
CreditFrame.Parent = ScreenGui

local creditCorner = Instance.new("UICorner")
creditCorner.CornerRadius = UDim.new(0, 8)
creditCorner.Parent = CreditFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0.3, 0)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Made by Merebennie on YouTube"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled = true
TitleLabel.TextStrokeTransparency = 1
TitleLabel.Parent = CreditFrame

local DescLabel = Instance.new("TextLabel")
DescLabel.Size = UDim2.new(1, 0, 0.3, 0)
DescLabel.Position = UDim2.new(0, 0, 0.3, 0)
DescLabel.BackgroundTransparency = 1
DescLabel.Text = DISCORD_LINK
DescLabel.Font = Enum.Font.GothamBold
DescLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DescLabel.TextScaled = true
DescLabel.TextStrokeTransparency = 1
DescLabel.Parent = CreditFrame

local CopyButton = Instance.new("TextButton")
CopyButton.Size = UDim2.new(1, 0, 0.4, 0)
CopyButton.Position = UDim2.new(0, 0, 0.6, 0)
CopyButton.BackgroundTransparency = 1
CopyButton.Text = "Click me to copy"
CopyButton.Font = Enum.Font.GothamBold
CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyButton.TextScaled = true
CopyButton.TextStrokeTransparency = 1
CopyButton.Parent = CreditFrame

CopyButton.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(DISCORD_LINK)
    end
    CopyButton.Text = "Copied Thanks!"
end)

local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local slideIn = TweenService:Create(CreditFrame, tweenInfo, {Position = UDim2.new(1, -200, 0.1, 0)})
slideIn:Play()

task.delay(4, function()
    local slideOut = TweenService:Create(CreditFrame, tweenInfo, {Position = UDim2.new(1, 0, 0.1, 0)})
    slideOut:Play()
    slideOut.Completed:Connect(function()
        CreditFrame:Destroy()
    end)
end)

local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Name = "CooldownLabel"
CooldownLabel.Size = UDim2.new(0, 120, 0, 30)
CooldownLabel.Position = UDim2.new(0, 10, 1, 0)
CooldownLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CooldownLabel.BackgroundTransparency = 0.35
CooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CooldownLabel.Text = "Cooldown: 4"
CooldownLabel.Font = Enum.Font.GothamBold
CooldownLabel.TextScaled = true
CooldownLabel.TextStrokeTransparency = 1
CooldownLabel.Visible = false
CooldownLabel.ZIndex = 9999
CooldownLabel.Parent = ScreenGui

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 8)
cooldownCorner.Parent = CooldownLabel

local connections = {}
local function clearConns()
    for _,c in pairs(connections) do if c and c.Disconnect then pcall(function() c:Disconnect() end) end end
    connections = {}
end

local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick()-lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        uiOnCooldown = true
        task.spawn(function() pcall(stickDash) end)

        -- Start cooldown UI with pop up
        local hiddenPos = UDim2.new(0, 10, 1, 0)
        local visiblePos = UDim2.new(0, 10, 1, -40)
        CooldownLabel.Position = hiddenPos
        CooldownLabel.Visible = true
        local popUpTween = TweenService:Create(CooldownLabel, tweenInfo, {Position = visiblePos})
        popUpTween:Play()

        -- Countdown and hide
        task.spawn(function()
            for i = COOLDOWN_DURATION, 1, -1 do
                CooldownLabel.Text = "Cooldown: " .. i
                task.wait(1)
            end
            uiOnCooldown = false
            -- Pop down and hide
            local popDownTween = TweenService:Create(CooldownLabel, tweenInfo, {Position = hiddenPos})
            popDownTween:Play()
            popDownTween.Completed:Wait()
            CooldownLabel.Visible = false
        end)
    end
end

local function onAnim(track)
    local anim = track and track.Animation
    if anim then
        local idStr = tostring(anim.AnimationId or "")
        if string.find(idStr, "10503381238", 1, true) then
            task.delay(0.3, tryTrigger)
            return
        end
        if string.find(idStr, "13379003796", 1, true) then
            task.delay(0.3, tryTrigger)
            return
        end
    end
end

local function setupChar(char)
    clearConns()
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")

    local ok, conn = pcall(function()
        return Humanoid.AnimationPlayed:Connect(onAnim)
    end)
    if ok and conn then table.insert(connections, conn) end

    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local ok2, conn2 = pcall(function()
            return animator.AnimationPlayed:Connect(onAnim)
        end)
        if ok2 and conn2 then table.insert(connections, conn2) end
    end
end

LocalPlayer.CharacterAdded:Connect(setupChar)
if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
