--// Merebennie Custom Stick Dash (Delta Mobile Compatible)
-- UI tweak: Blue button; functional lockout during 7.2s cooldown
-- Extra: Compact movable Info Box ("Made by Merebennie", copy invite, close "X")
-- Modified: TRIGGER_COOLDOWN set to 0.35

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Protect / parent UI appropriately for various executors (Delta, Synapse, etc.)
local function protectAndParent(gui)
    gui.ResetOnSpawn = false
    if type(syn) == "table" and syn.protect_gui then
        pcall(function() syn.protect_gui(gui) end)
        if gethui then
            gui.Parent = gethui()
            return
        end
    end
    if gethui then
        gui.Parent = gethui()
    else
        local ok, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui") end)
        if ok and pg then
            gui.Parent = pg
        else
            gui.Parent = game:GetService("CoreGui")
        end
    end
end

-- runtime vars that will be updated on respawn
local Character, Humanoid, HumanoidRootPart

-- original quick debounce kept (adjusted)
local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.35 -- changed to 0.35

-- UI / feature controls
local enabled = true -- UI On/Off (default ON)
local uiOnCooldown = false
local COOLDOWN_DURATION = 7.2 -- unchanged visual/functional cooldown

-- immobilization extension after script completes (in seconds)
local IMMOB_EXTRA_AFTER = 0.3

-- === Utility: find nearest player or npc (unchanged) ===
local function getNearestTarget()
    local nearest, dist = nil, math.huge
    if not (HumanoidRootPart) then return nil end
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= Character then
            local ok, mag = pcall(function()
                return (HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
            end)
            if ok and mag and mag < dist then
                dist = mag
                nearest = v
            end
        end
    end
    return nearest
end

-- === FireServer Q logic (kept; just adds +0.1s before Q) ===
local function fireQ()
    -- Added per request: extra 0.1s before activating Q
    task.delay(0.1, function()
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
    end)

    -- your getNil logic (executor-specific)
    local function getNil(name, class)
        if type(getnilinstances) ~= "function" then return nil end
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

-- === Main stick dash (modified: immobilize while active + extra 0.3s) ===
local function stickDash()
    if not (Character and Humanoid and HumanoidRootPart) then return end

    local target = getNearestTarget()
    if not target then return end

    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- save movement state so we can restore later
    local saved = {}
    pcall(function()
        saved.WalkSpeed = Humanoid.WalkSpeed
        saved.JumpPower = Humanoid.JumpPower
        saved.PlatformStand = Humanoid.PlatformStand
        -- some games use AutoRotate; save/restore if present
        if Humanoid:GetAttribute("AutoRotate") == nil then
            -- Humanoid.AutoRotate may not be available in all contexts; wrap safely
            pcall(function() saved.AutoRotate = Humanoid.AutoRotate end)
        else
            saved.AutoRotate = Humanoid.AutoRotate
        end
    end)

    -- remove common body movers to reduce being pushed by skills, then zero velocity each frame
    local antiConn
    local function startImmobilize()
        if not Humanoid or not HumanoidRootPart or not Character then return end
        pcall(function()
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            Humanoid.PlatformStand = true
            pcall(function() Humanoid.AutoRotate = false end)
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
        end)

        -- destroy common mover objects that may be applied by scripts/skills
        for _, v in pairs(Character:GetDescendants()) do
            local class = v.ClassName
            if class == "BodyVelocity" or class == "BodyPosition" or class == "BodyGyro" or class == "VectorForce" or class == "AlignPosition" or class == "AlignOrientation" or class == "LinearVelocity" or class == "AngularVelocity" then
                pcall(function() v:Destroy() end)
            end
        end

        -- heartbeat zeroing to resist forces applied while immobilized
        antiConn = RunService.Heartbeat:Connect(function()
            if HumanoidRootPart then
                pcall(function()
                    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                    HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
                end)
            end
            -- ensure WalkSpeed stays zero in case something resets it
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
                pcall(function()
                    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                    HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
                end)
            end
        end)
    end

    -- start immobilize right away (only while this stickDash is active)
    startImmobilize()

    -- put humanoid into physics state so animation/tweening behaves as before
    pcall(function()
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end)
    HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(85), 0, 0)

    local startTime = tick()
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= 0.7 then
            connection:Disconnect()
            return
        end
        local success, newCFrame = pcall(function()
            return CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(85), 0, 0)
        end)
        if success and newCFrame then
            HumanoidRootPart.CFrame = newCFrame
        end
    end)

    -- fire Q immediately
    pcall(fireQ)

    -- laydown after 0.3s delay
    task.delay(0.3, function()
        pcall(function()
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end)
    end)

    -- stop immobilizing after the movement window (0.7s) + extra requested 0.3s
    local totalImmobilize = 0.7 + IMMOB_EXTRA_AFTER
    task.delay(totalImmobilize, function()
        pcall(stopImmobilize)
    end)
end

-- === GUI creation (executor-friendly root) ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Merebennie_StickDashGui"
ScreenGui.IgnoreGuiInset = true
protectAndParent(ScreenGui)

-- === Main toggle button (60x30, smooth edges) — BLUE ===
local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
Button.Size = UDim2.new(0, 60, 0, 30)
Button.Position = UDim2.new(0.4, 0, 0.8, 0)
Button.Text = "On"
Button.Font = Enum.Font.GothamBold
Button.TextSize = 14
Button.BackgroundColor3 = Color3.fromRGB(30, 136, 229) -- blue when ON
Button.TextColor3 = Color3.new(1,1,1)
Button.Parent = ScreenGui
Button.ZIndex = 9999
Button.Active = true

local btnCorner = Instance.new("UICorner", Button)
btnCorner.CornerRadius = UDim.new(0, 8)

local btnStroke = Instance.new("UIStroke", Button)
btnStroke.Thickness = 1
btnStroke.Transparency = 0.35

-- Draggable for Button (works with mouse + touch)
do
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
end

-- Toggle On/Off (no logic/timing changes; just gating)
Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        Button.Text = "On"
        Button.BackgroundColor3 = Color3.fromRGB(30, 136, 229) -- blue ON
    else
        Button.Text = "Off"
        Button.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- OFF gray
    end
end)

-- === Cooldown bubble (bottom-left) ===
local CooldownFrame = Instance.new("Frame")
CooldownFrame.Name = "MerckCooldown"
CooldownFrame.Size = UDim2.new(0, 120, 0, 28)
CooldownFrame.Position = UDim2.new(0, 8, 1, -40)
CooldownFrame.AnchorPoint = Vector2.new(0, 0)
CooldownFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
CooldownFrame.BackgroundTransparency = 0.45
CooldownFrame.Visible = false
CooldownFrame.Parent = ScreenGui
CooldownFrame.ZIndex = 9998
CooldownFrame.Active = true

local cdCorner = Instance.new("UICorner", CooldownFrame)
cdCorner.CornerRadius = UDim.new(0, 12)

local cdStroke = Instance.new("UIStroke", CooldownFrame)
cdStroke.Thickness = 1
cdStroke.Transparency = 0.35

local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Name = "CooldownText"
CooldownLabel.Size = UDim2.new(1, -8, 1, 0)
CooldownLabel.Position = UDim2.new(0, 8, 0, 0)
CooldownLabel.BackgroundTransparency = 1
CooldownLabel.Text = "Merck V2 : 0.0s"
CooldownLabel.TextColor3 = Color3.new(0,0,0)
CooldownLabel.Font = Enum.Font.GothamBold
CooldownLabel.TextSize = 14
CooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
CooldownLabel.Parent = CooldownFrame
CooldownLabel.ZIndex = 9999

-- cartoony pulse tween for cooldown bubble
local pulseInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local pulseTween = TweenService:Create(CooldownFrame, pulseInfo, {BackgroundTransparency = 0.35})
local pulseActive = false

local function startUICooldown(duration)
    if uiOnCooldown then return end
    uiOnCooldown = true
    CooldownFrame.Visible = true
    if not pulseActive then
        pulseActive = true
        pcall(function() pulseTween:Play() end)
    end

    local startTime = tick()
    local remaining = duration
    while remaining > 0 do
        remaining = duration - (tick() - startTime)
        if remaining < 0 then remaining = 0 end
        CooldownLabel.Text = string.format("Merck V2 : %.1fs", remaining)
        task.wait(0.1)
    end

    uiOnCooldown = false
    CooldownFrame.Visible = false
    pcall(function() pulseTween:Cancel() end)
    pulseActive = false
end

-- === Compact Info Box (small: title + desc + copy + close) ===
local InfoFrame = Instance.new("Frame")
InfoFrame.Name = "MerebennieInfoBox"
InfoFrame.Size = UDim2.new(0, 200, 0, 92) -- compact size
InfoFrame.Position = UDim2.new(0.05, 0, 0.12, 0)
InfoFrame.BackgroundColor3 = Color3.fromRGB(240,240,240)
InfoFrame.Parent = ScreenGui
InfoFrame.ZIndex = 10000
InfoFrame.Active = true

local infoCorner = Instance.new("UICorner", InfoFrame)
infoCorner.CornerRadius = UDim.new(0, 10)
local infoStroke = Instance.new("UIStroke", InfoFrame)
infoStroke.Transparency = 0.35

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "InfoTitle"
Title.Size = UDim2.new(1, -40, 0, 24)
Title.Position = UDim2.new(0, 10, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "Made by Merebennie"
Title.TextColor3 = Color3.fromRGB(30,30,30)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = InfoFrame
Title.ZIndex = 10001

-- Close button (small X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "InfoClose"
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Parent = InfoFrame
CloseBtn.ZIndex = 10002
local closeCorner = Instance.new("UICorner", CloseBtn)
closeCorner.CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function()
    InfoFrame.Visible = false
end)

-- Description (small)
local Desc = Instance.new("TextLabel")
Desc.Name = "InfoDesc"
Desc.Size = UDim2.new(1, -20, 0, 34)
Desc.Position = UDim2.new(0, 10, 0, 32)
Desc.BackgroundTransparency = 1
Desc.TextWrapped = true
Desc.Text = "Join our discord for more Scripts!\nhttps://discord.gg/5x4xbPvuSc"
Desc.TextColor3 = Color3.fromRGB(40,40,40)
Desc.Font = Enum.Font.Gotham
Desc.TextSize = 12
Desc.TextXAlignment = Enum.TextXAlignment.Left
Desc.TextYAlignment = Enum.TextYAlignment.Top
Desc.Parent = InfoFrame
Desc.ZIndex = 10001

-- Copy Button (small)
local CopyBtn = Instance.new("TextButton")
CopyBtn.Name = "InfoCopy"
CopyBtn.Size = UDim2.new(0, 96, 0, 26)
CopyBtn.Position = UDim2.new(0, 10, 1, -34)
CopyBtn.Text = "Copy Link"
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 12
CopyBtn.BackgroundColor3 = Color3.fromRGB(30,136,229)
CopyBtn.TextColor3 = Color3.new(1,1,1)
CopyBtn.Parent = InfoFrame
CopyBtn.ZIndex = 10001
local copyCorner = Instance.new("UICorner", CopyBtn)
copyCorner.CornerRadius = UDim.new(0, 6)
CopyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard("https://discord.gg/5x4xbPvuSc")
        elseif toclipboard then -- some executors provide alternative
            toclipboard("https://discord.gg/5x4xbPvuSc")
        end
    end)
end)

-- Make InfoFrame draggable for both PC & mobile (manual drag to ensure compatibility)
do
    local dragging, dragInput, dragStart, startPos
    InfoFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = InfoFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    InfoFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and startPos then
            local delta = input.Position - dragStart
            InfoFrame.Position = UDim2.new(
                startPos.X.Scale,
                math.clamp(startPos.X.Offset + delta.X, 0, math.max(0, workspace.CurrentCamera.ViewportSize.X - InfoFrame.AbsoluteSize.X)),
                startPos.Y.Scale,
                math.clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, workspace.CurrentCamera.ViewportSize.Y - InfoFrame.AbsoluteSize.Y))
            )
        end
    end)
end

-- === Character setup & animation detection (now blocks during cooldown) ===
local connections = {}

local function clearCharacterConnections()
    for _, conn in pairs(connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    connections = {}
end

local function tryTrigger()
    -- Block if OFF or currently on the 7.2s cooldown
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        task.spawn(function() pcall(stickDash) end)
        task.spawn(function() startUICooldown(COOLDOWN_DURATION) end)
    end
end

local function onAnimationPlayed(track)
    if not track then return end
    local anim = track.Animation
    if not anim then return end
    local animId = tostring(anim.AnimationId or "")
    if string.find(animId, "10503381238", 1, true) then
        tryTrigger()
    end
end

local function setupCharacter(char)
    clearCharacterConnections()

    Character = char
    Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart", 5)
    if not Humanoid or not HumanoidRootPart then return end

    local ok, conn = pcall(function()
        return Humanoid.AnimationPlayed:Connect(onAnimationPlayed)
    end)
    if ok and conn then table.insert(connections, conn) end

    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local success, animConn = pcall(function()
            return animator.AnimationPlayed:Connect(onAnimationPlayed)
        end)
        if success and animConn then table.insert(connections, animConn) end
    end

    local descConn = Character.DescendantAdded:Connect(function(desc)
        if desc:IsA("Animation") then
            local aid = tostring(desc.AnimationId or "")
            if string.find(aid, "10503381238", 1, true) then
                tryTrigger()
            end
        end
    end)
    table.insert(connections, descConn)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    pcall(setupCharacter, char)
end)

if LocalPlayer.Character then
    pcall(setupCharacter, LocalPlayer.Character)
end

-- End of script
