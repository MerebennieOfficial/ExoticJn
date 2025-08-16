-- LocalScript in StarterPlayerScripts
-- Mobile Aimlock with UI toggle, indicator, settings, draggable UIs, and tilt adjustment

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")

-- =========================================
-- CONFIG (default values)
-- =========================================
local aimlockEnabled = false
local lockedTarget = nil
local aimPartName = "Head" -- changeable in settings
local maxDistance = 100 -- studs
local predictionTime = 0.1 -- seconds ahead
local tiltOffset = 0 -- studs up/down

-- =========================================
-- FUNCTIONS
-- =========================================
local function makeDraggable(frame)
	local dragging = false
	local dragInput, dragStart, startPos

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function getNearestTarget()
	local nearest = nil
	local shortestDistance = maxDistance

	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(aimPartName) then
			local part = player.Character[aimPartName]
			local distance = (part.Position - Camera.CFrame.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearest = part
			end
		end
	end
	return nearest
end

local function validateTarget(targetPart)
	if not targetPart then return false end
	local char = targetPart.Parent
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	return true
end

local function toggleAimlock()
	aimlockEnabled = not aimlockEnabled
	if aimlockEnabled then
		lockedTarget = getNearestTarget()
		if not lockedTarget then
			aimlockEnabled = false
			return
		end
		Indicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	else
		lockedTarget = nil
		Indicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	end
end

-- =========================================
-- UI CREATION
-- =========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Indicator
Indicator = Instance.new("Frame")
Indicator.Size = UDim2.new(0, 60, 0, 60)
Indicator.Position = UDim2.new(0.05, 0, 0.1, 0)
Indicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
Indicator.BorderSizePixel = 0
Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
Indicator.Parent = ScreenGui
Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)
makeDraggable(Indicator)

-- Toggle Button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 60, 0, 60)
ToggleButton.Position = UDim2.new(0.1, 0, 0.3, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
ToggleButton.Text = "Aim"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Parent = ScreenGui
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0)
makeDraggable(ToggleButton)

-- Settings Button
local SettingsButton = Instance.new("TextButton")
SettingsButton.Size = UDim2.new(0, 60, 0, 60)
SettingsButton.Position = UDim2.new(0.2, 0, 0.3, 0)
SettingsButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
SettingsButton.Text = "⚙"
SettingsButton.TextScaled = true
SettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SettingsButton.Parent = ScreenGui
Instance.new("UICorner", SettingsButton).CornerRadius = UDim.new(1, 0)
makeDraggable(SettingsButton)

-- Settings Panel
local SettingsFrame = Instance.new("Frame")
SettingsFrame.Size = UDim2.new(0, 200, 0, 200)
SettingsFrame.Position = UDim2.new(0.5, -100, 0.5, -100)
SettingsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
SettingsFrame.Visible = false
SettingsFrame.Parent = ScreenGui
Instance.new("UICorner", SettingsFrame).CornerRadius = UDim.new(0, 8)
makeDraggable(SettingsFrame)

local function makeSettingLabel(parent, text, posY)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 30)
	lbl.Position = UDim2.new(0, 5, 0, posY)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

local function makeSettingBox(parent, defaultText, posY, onFocusLost)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -10, 0, 30)
	box.Position = UDim2.new(0, 5, 0, posY)
	box.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	box.Text = tostring(defaultText)
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.ClearTextOnFocus = false
	box.Parent = parent
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
	box.FocusLost:Connect(function()
		onFocusLost(box.Text)
	end)
	return box
end

makeSettingLabel(SettingsFrame, "Prediction Time", 5)
makeSettingBox(SettingsFrame, predictionTime, 35, function(val)
	local num = tonumber(val)
	if num then predictionTime = num end
end)

makeSettingLabel(SettingsFrame, "Max Distance", 70)
makeSettingBox(SettingsFrame, maxDistance, 100, function(val)
	local num = tonumber(val)
	if num then maxDistance = num end
end)

makeSettingLabel(SettingsFrame, "Target Part", 135)
makeSettingBox(SettingsFrame, aimPartName, 165, function(val)
	if val ~= "" then aimPartName = val end
end)

makeSettingLabel(SettingsFrame, "Tilt Offset", 200)
makeSettingBox(SettingsFrame, tiltOffset, 230, function(val)
	local num = tonumber(val)
	if num then tiltOffset = num end
end)

SettingsButton.MouseButton1Click:Connect(function()
	SettingsFrame.Visible = not SettingsFrame.Visible
end)

ToggleButton.MouseButton1Click:Connect(toggleAimlock)

-- =========================================
-- AIMLOCK LOOP
-- =========================================
RunService.RenderStepped:Connect(function()
	if aimlockEnabled then
		if not validateTarget(lockedTarget) then
			lockedTarget = getNearestTarget()
			if not lockedTarget then
				aimlockEnabled = false
				Indicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
				return
			end
		end

		if lockedTarget then
			local predictedPos = (lockedTarget.Position + Vector3.new(0, tiltOffset, 0)) + (lockedTarget.Velocity * predictionTime)
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
		end
	end
end)
