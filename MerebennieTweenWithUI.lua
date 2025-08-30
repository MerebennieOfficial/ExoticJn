
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local function getClosestTarget(maxDistance)
    local closest, dist = nil, maxDistance
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = player.Character.HumanoidRootPart
            local mag = (HumanoidRootPart.Position - targetHRP.Position).Magnitude
            if mag < dist then
                closest, dist = targetHRP, mag
            end
        end
    end
    return closest
end

local function tweenToBack(targetHRP)
    if not targetHRP then return end
    local rootPos = HumanoidRootPart.Position
    local targetPos = targetHRP.Position
    local direction = (rootPos - targetPos).Unit
    local midpoint = targetPos + Vector3.new(-direction.Z, 0, direction.X) * 7
    local goalPos = midpoint - direction * 4

    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = CFrame.new(goalPos, targetPos)})
    tween:Play()
end

local function onActivate()
    local target = getClosestTarget(30)
    if target then
        tweenToBack(target)
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonX then
        onActivate()
    end
end)

-- Merebennie Discord Info Box
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Merebennie_DiscordGui"
ScreenGui.IgnoreGuiInset = true
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = game.CoreGui end

local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.new(0, 200, 0, 92)
InfoFrame.Position = UDim2.new(0.05, 0, 0.12, 0)
InfoFrame.BackgroundColor3 = Color3.fromRGB(240,240,240)
InfoFrame.Active = true
InfoFrame.Parent = ScreenGui

Instance.new("UICorner", InfoFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", InfoFrame).Transparency = 0.35

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 0, 24)
Title.Position = UDim2.new(0, 10, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "Made by Merebennie"
Title.TextColor3 = Color3.fromRGB(30,30,30)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = InfoFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Parent = InfoFrame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() InfoFrame.Visible = false end)

local Desc = Instance.new("TextLabel")
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

local CopyBtn = Instance.new("TextButton")
CopyBtn.Size = UDim2.new(0, 96, 0, 26)
CopyBtn.Position = UDim2.new(0, 10, 1, -34)
CopyBtn.Text = "Copy Link"
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 12
CopyBtn.BackgroundColor3 = Color3.fromRGB(30,136,229)
CopyBtn.TextColor3 = Color3.new(1,1,1)
CopyBtn.Parent = InfoFrame
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 6)
CopyBtn.MouseButton1Click:Connect(function()
    if setclipboard then setclipboard("https://discord.gg/5x4xbPvuSc") elseif toclipboard then toclipboard("https://discord.gg/5x4xbPvuSc") end
end)

do
    local dragging, dragInput, dragStart, startPos
    InfoFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = InfoFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    InfoFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and startPos then
            local delta = input.Position - dragStart
            InfoFrame.Position = UDim2.new(
                startPos.X.Scale,
                math.clamp(startPos.X.Offset + delta.X, 0, workspace.CurrentCamera.ViewportSize.X - InfoFrame.AbsoluteSize.X),
                startPos.Y.Scale,
                math.clamp(startPos.Y.Offset + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - InfoFrame.AbsoluteSize.Y)
            )
        end
    end)
end
