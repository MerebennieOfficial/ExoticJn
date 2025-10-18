
local LocalPlayer = game.Players.LocalPlayer
local noClip = false
local uis = game:GetService("UserInputService")
local Players = game.Players
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local q = true
local distanceM1 = 7.5
local distance = 30
local range = 3
local lolll = true
local smoothness = 0.4
local silent = nil
local reach = 5
local ScreenGui = Instance.new("ScreenGui")
local ImageButton = Instance.new("ImageButton")
local UICorner = Instance.new("UICorner")
local speedN = 0.3
local duration = 0.3
local a = true
local m = true
local checkPlayer = nil
local target = nil
local mouse = player:GetMouse()
local f = true
local lastmagnitude = math.huge
local dummy = game.Workspace.Live:FindFirstChild("Weakest Dummy")
local toogle = false
local u = game:GetService("UserInputService")
local c = workspace.CurrentCamera
local P = game:GetService("Players")
local U = game:GetService("UserInputService")
local C = workspace.CurrentCamera

local ui = game:GetService("UserInputService")
local gui = game:GetService("StarterGui")

-- store original AutoRotate so we can restore it reliably
local prevAutoRotate = nil

-- safe helper to get the current humanoid
local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- enable "silent aim" state and turn off autorotate but remember previous state
local function setSilentAimOn()
    local h = getHumanoid()
    if not h then return end
    prevAutoRotate = h.AutoRotate
    h.AutoRotate = false
    silent = true
end

-- restore autorotate to previous value (or true if unknown) and clear silent flag
local function restoreAutoRotate()
    silent = false
    local h = getHumanoid()
    if h then
        if prevAutoRotate == nil then
            h.AutoRotate = true
        else
            h.AutoRotate = prevAutoRotate
        end
    end
    prevAutoRotate = nil
end

-- guard: while silent==true, prevent AutoRotate from being turned back on by other code
local function onHumanoidAutoRotateChanged()
    local h = getHumanoid()
    if h and silent == true then
        if h.AutoRotate == true then
            h.AutoRotate = false
        end
    end
end

-- initial connect and reconnect on respawn
local function connectAutoRotateGuard()
    local h = getHumanoid()
    if h then
        h:GetPropertyChangedSignal("AutoRotate"):Connect(onHumanoidAutoRotateChanged)
    end
end

connectAutoRotateGuard()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    connectAutoRotateGuard()
end)

if ui.TouchEnabled and not (ui.KeyboardEnabled and ui.GamepadEnabled and gui:IsTenFootInterface()) then

	ScreenGui.Parent = game.CoreGui
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	ImageButton.Parent = ScreenGui
	ImageButton.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	ImageButton.BackgroundTransparency = 0.300
	ImageButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
	ImageButton.BorderSizePixel = 0
	ImageButton.Position = UDim2.new(0.15976575, 0, 0.0619156398, 0)
	ImageButton.Size = UDim2.new(0.0889796019, 0, 0.16869919, 0)
	ImageButton.Image = "rbxassetid://18274894738"

	UICorner.CornerRadius = UDim.new(0, 50)
	UICorner.Parent = ImageButton
end

local speed = TweenInfo.new(
	speedN, 
	Enum.EasingStyle.Quad, 
	Enum.EasingDirection.Out 
)

local function addHighlight(character)
	if not character then return end
	local highlight = Instance.new("Highlight")
	highlight.Parent = character
	highlight.OutlineColor = Color3.fromRGB(0, 100, 0)
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end
local function removeHighlight(character)
	for _,i in ipairs(character:GetDescendants()) do
		if i:IsA("Highlight") then
			i:Destroy()
		end
	end
end

local function silentAim(nah, dumb)

	local humm = game.Players.LocalPlayer.Character.HumanoidRootPart
	if nah ~= nil and nah == dummy then
		local get = nah:FindFirstChild("Right Arm")
		local directionMM = get.CFrame.Position - humm.CFrame.Position
		local newDirection = CFrame.fromAxisAngle(Vector3.new(0, dumb, 0), math.rad(140)) * directionMM
		local ddirect = get.CFrame.Position + newDirection
		local n = Vector3.new(ddirect.X, humm.CFrame.Position.Y, ddirect.Z)
		local finalCF = CFrame.new(humm.CFrame.Position, n)
		humm.CFrame = humm.CFrame:Lerp(finalCF, smoothness)
	elseif nah ~= nil and nah ~= dummy then
		local get = nah.Character:FindFirstChild("Right Arm")
		local directionMM = get.CFrame.Position - humm.CFrame.Position
		local newDirection = CFrame.fromAxisAngle(Vector3.new(0, dumb, 0), math.rad(140)) * directionMM
		local ddirect = get.CFrame.Position + newDirection
		local n = Vector3.new(ddirect.X, humm.CFrame.Position.Y, ddirect.Z)
		local finalCF = CFrame.new(humm.CFrame.Position, n)
		humm.CFrame = humm.CFrame:Lerp(finalCF, smoothness)
	end
end

local function aimlock(bruh)
	dummy = game.Workspace.Live:FindFirstChild("Weakest Dummy")

	local cam = workspace.CurrentCamera
	if bruh ~= nil and bruh == dummy then
		local vv =  Vector3.new(bruh.HumanoidRootPart.CFrame.Position.X, cam.CFrame.Position.Y, bruh.HumanoidRootPart.CFrame.Position.Z )
		cam.CFrame = CFrame.new(cam.CFrame.Position, vv)
	elseif bruh ~= nil and bruh ~= dummy then
		local vv =  Vector3.new(bruh.Character.HumanoidRootPart.CFrame.Position.X, cam.CFrame.Position.Y, bruh.Character.HumanoidRootPart.CFrame.Position.Z )
		cam.CFrame = CFrame.new(cam.CFrame.Position, vv)
	end
end

local function getdiddy(pos)
	dummy = game.Workspace.Live:FindFirstChild("Weakest Dummy")
	local ray = C:ScreenPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {P.LocalPlayer.Character}
	params.FilterType = Enum.RaycastFilterType.Blacklist

	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local plr = P:GetPlayerFromCharacter(model)

		if plr then 
			toogle = not toogle
			if toogle then
				target = plr
				addHighlight(target.Character)
			end

		elseif model and model:FindFirstChild("HumanoidRootPart") and not P:GetPlayerFromCharacter(model) then
			toogle = not toogle
			if toogle then
				target = dummy
				addHighlight(target)
			end
		end
	end
end

U.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.UserInputType == Enum.UserInputType.Touch then
		for _,i in pairs(game.Players:GetChildren()) do
			if i ~= game.Players.LocalPlayer then
				checkPlayer = i
			end
		end
		if checkPlayer or game.Workspace.Live:FindFirstChild("Weakest Dummy") then
			getdiddy(i.Position)
			if toogle == false then
				dummy = game.Workspace.Live:FindFirstChild("Weakest Dummy")

				if target == dummy then
					removeHighlight(target)
					target = nil
				elseif target == nil then
					target=nil
				else
					removeHighlight(target.Character)
					target = nil
				end
			end
		end
	end
end)

function GetTarget()
	ui = game:GetService("UserInputService")
	gui = game:GetService("StarterGui")

	if ui.KeyboardEnabled then
		dummy = game.Workspace.Live:FindFirstChild("Weakest Dummy")
		local dummyP = dummy.HumanoidRootPart.CFrame.Position
		local mousepos = mouse.Hit.p
		for i,v in pairs(game.Players:GetPlayers()) do
			if v ~= player then
				if v.Character then
					local charpos = v.Character.HumanoidRootPart.CFrame.Position

					if (charpos - mousepos).Magnitude < lastmagnitude then
						lastmagnitude = (charpos - mousepos).Magnitude
						target = v
					end
				end
			end
		end
		if (dummyP - mousepos).Magnitude < lastmagnitude then
			target = dummy
			addHighlight(target)
		else
			addHighlight(target.Character)
		end
	end
end

local function simulateLeftClickMobile()
	local Communicate = Players.LocalPlayer.Character.Communicate
	Communicate:FireServer({["Mobile"] = true,["Goal"] = "LeftClick"})
	Communicate:FireServer({["Mobile"] = true,["Goal"] = "LeftClickRelease"})
end

local function pressQA()
	if q == true then
		q = false
		local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local h = c:WaitForChild("Humanoid")
		local a = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)

		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://10480796021"
		a:LoadAnimation(anim):Play()
	end
end
local function pressQD()
	if q == true then
		q = false
		local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local h = c:WaitForChild("Humanoid")
		local a = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)

		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://10480793962"
		a:LoadAnimation(anim):Play()
	end
end

task.spawn(function()
	while true do
		task.wait()
		if toogle then
			dummy = game.Workspace.Live:FindFirstChild("Weakest Dummy")
			if target == dummy then
				if target.Humanoid.Health == 0 then
					toogle = false
					removeHighlight(target)
					target = nil
				end
			elseif target ~= nil then
				if target.Character.Humanoid.Health == 0 then
					toogle = false
					removeHighlight(target.Character)
					target = nil
				end
			end
		end
	end
end)

local inp = uis.InputBegan:Connect(function(input,istyping)
	if istyping then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.V  then
			for _,i in pairs(game.Players:GetChildren()) do
				if i ~= game.Players.LocalPlayer then
					checkPlayer = i
				end
			end
			if checkPlayer or game.Workspace.Live:FindFirstChild("Weakest Dummy") then
				toogle = not toogle
				if toogle then
					lastmagnitude = math.huge
					GetTarget()
				else
					if target == dummy then
						removeHighlight(target)
						target = nil
					else
						removeHighlight(target.Character)
						target = nil
					end
				end
			end
		end
		if toogle and target then
			if input.KeyCode == Enum.KeyCode.C then
				local p = game.Players.LocalPlayer.Character.HumanoidRootPart

				if p.Position.Y <= 442 and (target.Character.HumanoidRootPart.Position.Y <= 448 or target.HumanoidRootPart.Position.Y <= 448) then

					if target ~= nil and target == dummy then

						p = game.Players.LocalPlayer.Character.HumanoidRootPart

						if (target.HumanoidRootPart.CFrame.Position - p.CFrame.Position).Magnitude <= distance and f == true then

							f = false
							noClip = false
							m = true
							a = true
							while noClip == false do

								task.wait()

								task.delay(duration, function()
									-- restore state when the action times out
									restoreAutoRotate()
									m = false
									noClip = true
									q = true

									task.spawn(function()
										local ran
										ran = game:GetService("RunService").Stepped:Connect(function()
											aimlock(target)
											task.delay(0.5,function()
												ran:Disconnect()
											end)
										end)
									end)

									task.wait(2)
									f = true
								end)

								local direction = (target.HumanoidRootPart.Position - p.Position).Unit

								local forward = target.HumanoidRootPart.CFrame.LookVector

								local des = target.HumanoidRootPart.Position + (target.HumanoidRootPart.CFrame.RightVector * range)
								local des100 = target.HumanoidRootPart.Position + (-target.HumanoidRootPart.CFrame.RightVector * range)
								local des1 = (des - p.Position).Unit
								local des70 = (des100 - p.Position).Unit
								local des1C = (des - p.Position).Unit
								local des70C = (des100 - p.Position).Unit

								if (des - p.CFrame.Position).Magnitude < (des100 - p.CFrame.Position).Magnitude then
									if forward:Dot(direction) < 0 then
										silent = true
										pressQA()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.HumanoidRootPart.Position + (target.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.HumanoidRootPart.Position + (-target.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, -1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)

									elseif forward:Dot(direction) > 0 then
										silent = true
										pressQD()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.HumanoidRootPart.Position + (target.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.HumanoidRootPart.Position + (-target.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, 1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)
									end
								else
									if forward:Dot(direction) < 0 then
										silent = true
										pressQD()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.HumanoidRootPart.Position + (target.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.HumanoidRootPart.Position + (-target.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, 1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)

									elseif forward:Dot(direction) > 0 then
										silent = true
										pressQA()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.HumanoidRootPart.Position + (target.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.HumanoidRootPart.Position + (-target.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, -1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)
									end
								end

								while m do

									task.wait()
									if target ~= nil and target == dummy then
										task.spawn(function()

											while m do
												task.wait()
												if des1:Dot(des1C) < 0 or des70:Dot(des70C) < 0 then
													des70 = -((des100 - p.Position).Unit)
													des1 = -((des - p.Position).Unit)
												else
													task.wait()
													des70 = (des100 - p.Position).Unit
													des1 = (des - p.Position).Unit
												end
											end
										end)

										p = game.Players.LocalPlayer.Character.HumanoidRootPart
										local ps = nil

										des = target.HumanoidRootPart.Position + (target.HumanoidRootPart.CFrame.RightVector * range)
										des100 = target.HumanoidRootPart.Position + (-target.HumanoidRootPart.CFrame.RightVector * range)

										local des2 = des + (des1 * reach)
										local des50 = des100 + (des70 * reach)
										local fDes2 = Vector3.new(des50.X, p.Position.Y, des50.Z)
										local fDes = Vector3.new(des2.X, p.Position.Y, des2.Z)
										if (des - p.CFrame.Position).Magnitude < (des100 - p.CFrame.Position).Magnitude then
											ps = {}
											ps.CFrame = CFrame.new(fDes)
										else
											ps = {}
											ps.CFrame = CFrame.new(fDes2)
										end

										local tween = TweenService:Create(p, speed, ps)
										task.delay(duration,function()
											m = false
										end)

										if (p.Position - target.HumanoidRootPart.Position).Magnitude <= distanceM1 and a == true then
											a = false
											simulateLeftClickMobile()
										end
										task.spawn(function()
											tween:Play()
										end)
									end
								end
							end
						end
					elseif target ~= nil and target ~= dummy then
						p = game.Players.LocalPlayer.Character.HumanoidRootPart

						if (target.Character.HumanoidRootPart.CFrame.Position - p.CFrame.Position).Magnitude <= distance and f == true then

							f = false
							noClip = false
							m = true
							a = true
							while noClip == false do

								task.wait()

								task.delay(duration, function()
									-- restore state when the action times out
									restoreAutoRotate()
									m = false
									noClip = true
									q = true

									task.spawn(function()
										local ran
										ran = game:GetService("RunService").Stepped:Connect(function()
											aimlock(target)
											task.delay(0.5,function()
												ran:Disconnect()
											end)
										end)
									end)

									task.wait(2)
									f = true
								end)

								local direction = (target.Character.HumanoidRootPart.Position - p.Position).Unit

								local forward = target.Character.HumanoidRootPart.CFrame.LookVector

								local des = target.Character.HumanoidRootPart.Position + (target.Character.HumanoidRootPart.CFrame.RightVector * range)
								local des100 = target.Character.HumanoidRootPart.Position + (-target.Character.HumanoidRootPart.CFrame.RightVector * range)
								local des1 = (des - p.Position).Unit
								local des70 = (des100 - p.Position).Unit
								local des1C = (des - p.Position).Unit
								local des70C = (des100 - p.Position).Unit

								if (des - p.CFrame.Position).Magnitude < (des100 - p.CFrame.Position).Magnitude then
									if forward:Dot(direction) < 0 then
										silent = true
										pressQA()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.Character.HumanoidRootPart.Position + (target.Character.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.Character.HumanoidRootPart.Position + (-target.Character.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, -1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)

									elseif forward:Dot(direction) > 0 then
										silent = true
										pressQD()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.Character.HumanoidRootPart.Position + (target.Character.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.Character.HumanoidRootPart.Position + (-target.Character.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, 1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)
									end
								else
									if forward:Dot(direction) < 0 then
										silent = true
										pressQD()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.Character.HumanoidRootPart.Position + (target.Character.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.Character.HumanoidRootPart.Position + (-target.Character.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, 1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)

									elseif forward:Dot(direction) > 0 then
										silent = true
										pressQA()
										setSilentAimOn()
										local run
										task.spawn(function()

											run = game:GetService("RunService").Stepped:Connect(function()
												p = game.Players.LocalPlayer.Character.HumanoidRootPart
												des = target.Character.HumanoidRootPart.Position + (target.Character.HumanoidRootPart.CFrame.RightVector * range)
												des100 = target.Character.HumanoidRootPart.Position + (-target.Character.HumanoidRootPart.CFrame.RightVector * range)
												silentAim(target, -1)

												if m == false then
													run:Disconnect()
												end
											end)
										end)
									end
								end

								while m do

									task.wait()
									if target ~= nil and target ~= dummy then
										task.spawn(function()

											while m do
												task.wait()
												if des1:Dot(des1C) < 0 or des70:Dot(des70C) < 0 then
													des70 = -((des100 - p.Position).Unit)
													des1 = -((des - p.Position).Unit)
												else
													task.wait()
													des70 = (des100 - p.Position).Unit
													des1 = (des - p.Position).Unit
												end
											end
										end)

										p = game.Players.LocalPlayer.Character.HumanoidRootPart
										local ps = nil

										des = target.Character.HumanoidRootPart.Position + (target.Character.HumanoidRootPart.CFrame.RightVector * range)
										des100 = target.Character.HumanoidRootPart.Position + (-target.Character.HumanoidRootPart.CFrame.RightVector * range)

										local des2 = des + (des1 * reach)
										local des50 = des100 + (des70 * reach)
										local fDes2 = Vector3.new(des50.X, p.Position.Y, des50.Z)
										local fDes = Vector3.new(des2.X, p.Position.Y, des2.Z)
										if (des - p.CFrame.Position).Magnitude < (des100 - p.CFrame.Position).Magnitude then
											ps = {}
											ps.CFrame = CFrame.new(fDes)
										else
											ps = {}
											ps.CFrame = CFrame.new(fDes2)
										end

										local tween = TweenService:Create(p, speed, ps)
										task.delay(duration,function()
											m = false
										end)

										if (p.Position - target.Character.HumanoidRootPart.Position).Magnitude <= distanceM1 and a == true then
											a = false
											simulateLeftClickMobile()
										end
										task.spawn(function()
											tween:Play()
										end)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)
