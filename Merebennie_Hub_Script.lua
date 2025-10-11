--// Merebennie Hub // Delta Mobile Compatible

-- Load Rayfield Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Merebennie Hub",
    LoadingTitle = "Merebennie Hub",
    LoadingSubtitle = "Optimized for Delta Mobile",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MerebennieHub"
    }
})

local MainTab = Window:CreateTab("Main Features")

-- Faster Dash + Better Hitbox Accuracy
MainTab:CreateButton({
    Name = "Faster Dash + Better Hitbox Accuracy",
    Callback = function()
        pcall(function() setfflag("S2PhysicsSenderRate", "15000") end)
        task.wait(0.1)
        pcall(function() setfflag("PhysicsSenderMaxBandwidthBps", "20000") end)
    end,
})

-- Disable Shakes (Works after Death/Respawn)
MainTab:CreateButton({
    Name = "Disable Shakes",
    Callback = function()
        local function disableShake()
            local lp = game.Players.LocalPlayer
            if not lp.Character then lp.CharacterAdded:Wait() end
            local scriptObj = lp.Character:WaitForChild("CharacterHandler", 5)
            if scriptObj then
                local client = scriptObj:WaitForChild("Client", 5)
                if client then
                    local env = getsenv(client)
                    if env and env.shared and env.shared.addshake then
                        hookfunction(env.shared.addshake, function() return nil end)
                    end
                end
            end
        end
        disableShake()
        game.Players.LocalPlayer.CharacterAdded:Connect(disableShake)
    end,
})

-- FPS Booster + Better Lighting
MainTab:CreateButton({
    Name = "FPS Booster + Better Lighting",
    Callback = function()
        loadstring(game:HttpGet("https://pastebin.com/raw/MerebennieFPSBooster"))()
    end,
})

-- Slower Physics
MainTab:CreateButton({
    Name = "Slower Physics",
    Callback = function()
        pcall(function() setfflag("PhysicsImprovedCyclicExecutiveThrottleThresholdTenth", "-999999999") end)
        task.wait(0.1)
    end,
})

Rayfield:Notify({
    Title = "Merebennie Hub Loaded",
    Content = "All features are now ready to use!",
    Duration = 6
})
