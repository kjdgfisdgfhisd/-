local HIros = loadstring(game:HttpGet("https://raw.githubusercontent.com/kjdgfisdgfhisd/-/refs/heads/main/HIros%206.0"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

-- ============ СОСТОЯНИЕ ============
local state = {
    -- фарм
    farmRunning = false,
    farmCounter = 0,
    farmLimit = 50,
    selectedHole = nil,
    giveMeThreshold = 10,
    giveMeMethod = "Invoke",
    tpMethod = "Position",
    noclipEnabled = false,
    -- тренировка
    trainRunning = false,
    trainCounter = 0,
    spamRate = 0.1,
    spinSpam = false,
    -- общее
    noclipConn = nil,
    visualObjects = {},
    loops = {},
    itemESPActive = false,
    itemESPRefreshTime = 0,
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ThrowItem = Remotes:WaitForChild("ThrowItem")
local LiftDumbbell = Remotes:WaitForChild("LiftDumbbell")
local DumbbellSpin = Remotes:WaitForChild("DumbbellSpin")
local HoleGiveMe = Remotes:WaitForChild("HoleGiveMe")

local function getChar()
    local char = plr.Character
    return char, char and char:FindFirstChild("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

-- ============ ГАНТЕЛЬ ============
local function getDumbbell()
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        local d = bp:FindFirstChild("Dumbbell")
        if d then return d end
    end
    local char = plr.Character
    if char then
        local d = char:FindFirstChild("Dumbbell")
        if d then return d end
    end
    return nil
end

local function equipDumbbell()
    local _, hum = getChar()
    if not hum then return false end
    local d = getDumbbell()
    if not d then return false end
    if d.Parent == plr.Character then return true end
    pcall(function() hum:EquipTool(d) end)
    task.wait(0.1)
    return d.Parent == plr.Character
end

local function unequipAll()
    local _, hum = getChar()
    if not hum then return end
    pcall(function() hum:UnequipTools() end)
    task.wait(0.1)
end

-- ============ NOCLIP ============
local function setNoclip(on)
    state.noclipEnabled = on
    if on then
        if state.noclipConn then state.noclipConn:Disconnect() end
        state.noclipConn = RunService.Stepped:Connect(function()
            local char = plr.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if state.noclipConn then
            state.noclipConn:Disconnect()
            state.noclipConn = nil
        end
        local char = plr.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

-- ============ ТЕЛЕПОРТ ============
local function teleportTo(pos)
    local _, _, hrp = getChar()
    if not hrp then return false end
    if state.tpMethod == "Position" then
        hrp.Position = pos + Vector3.new(0, 3, 0)
    elseif state.tpMethod == "CFrame" then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    elseif state.tpMethod == "PivotTo" then
        local char = plr.Character
        if char then char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0))) end
    end
    task.wait(0.1)
    return (hrp.Position - pos).Magnitude < 15
end

-- ============ ХОДЬБА ============
local function walkTo(targetPos, timeout)
    local _, hum, hrp = getChar()
    if not hum or not hrp then return false end
    timeout = timeout or 15
    hum:MoveTo(targetPos)
    local start = tick()
    while tick() - start < timeout do
        if not state.farmRunning then return false end
        if not hum or not hrp or hum.Health <= 0 then return false end
        if (hrp.Position - targetPos).Magnitude < 5 then
            hum:MoveTo(hrp.Position)
            return true
        end
        task.wait(0.1)
    end
    hum:MoveTo(hrp.Position)
    return false
end

-- ============ ПОИСК ============
local function collectHoles()
    local holes = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "HoleHitbox" then
            table.insert(holes, v)
        end
    end
    return holes
end

local function findMyBase()
    local _, _, hrp = getChar()
    if not hrp then return nil end
    local bestSpawn, bestDist = nil, math.huge
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("SpawnLocation") and v.Name == "BaseSpawn" then
            local dist = (v.Position - hrp.Position).Magnitude
            if dist < bestDist then bestSpawn, bestDist = v, dist end
        end
    end
    if not bestSpawn then return nil end
    local baseModel = bestSpawn.Parent
    if baseModel then
        local hole = baseModel:FindFirstChild("HoleHitbox")
        if hole then return hole end
    end
    return nil
end

local function findNearestPrompt()
    local _, _, hrp = getChar()
    if not hrp then return nil end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, v in ipairs(si:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            local part = v.Parent
            if part and part:IsA("BasePart") then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist < nearestDist then nearest, nearestDist = v, dist end
            end
        end
    end
    return nearest, nearestDist
end

-- ============ GIVEME ============
local function triggerGiveMe()
    if state.giveMeMethod == "Invoke" or state.giveMeMethod == "Both" then
        local ok = pcall(function() HoleGiveMe:InvokeServer() end)
        print("[WalkFarm] HoleGiveMe:InvokeServer() ->", ok)
        if ok then task.wait(1) return true end
    end
    if state.giveMeMethod == "Click" or state.giveMeMethod == "Both" then
        pcall(function()
            local pg = plr:FindFirstChild("PlayerGui")
            local hud = pg and pg:FindFirstChild("HUD")
            local top = hud and hud:FindFirstChild("TopButtons")
            local holder = top and top:FindFirstChild("GiveMeButtonHolder")
            local plate = holder and holder:FindFirstChild("GiveMePlate")
            local face = plate and plate:FindFirstChild("Face")
            if face then face.MouseButton1Click:Fire() end
        end)
    end
    task.wait(1)
    return true
end

-- ============ ДЕЙСТВИЯ ============
local function grabItem()
    unequipAll()
    task.wait(0.1)
    local prompt, dist = findNearestPrompt()
    if not prompt then return false end
    local part = prompt.Parent
    teleportTo(part.Position)
    task.wait(0.2)
    return pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        elseif prompt.InputHoldBegin then
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.1)
            prompt:InputHoldEnd()
        end
    end)
end

local function aimCameraAt(targetPos)
    local cam = workspace.CurrentCamera
    if cam then cam.CFrame = CFrame.new(cam.CFrame.Position, targetPos) end
end

local function clickCenter()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
    end)
end

local function tryThrow()
    clickCenter()
    pcall(function() ThrowItem:FireServer() end)
end

-- ============ ФАРМ ЦИКЛ ============
local function doFarmCycle()
    if not state.selectedHole then return false end
    if grabItem() then
        task.wait(0.3)
        walkTo(state.selectedHole.Position, 25)
        task.wait(0.3)
        aimCameraAt(state.selectedHole.Position)
        task.wait(0.3)
        tryThrow()
        state.farmCounter = state.farmCounter + 1
        if state.farmCounter % state.giveMeThreshold == 0 then
            triggerGiveMe()
        end
        return true
    end
    return false
end

local function startFarm()
    if state.farmRunning then return end
    state.farmRunning = true
    state.farmCounter = 0
    setNoclip(true)
    task.spawn(function()
        while state.farmRunning and state.farmCounter < state.farmLimit do
            doFarmCycle()
            task.wait(0.3)
        end
        state.farmRunning = false
        setNoclip(false)
    end)
end

local function stopFarm()
    state.farmRunning = false
    setNoclip(false)
end

-- ============ ТРЕНИРОВКА ЦИКЛ ============
local function doTrainCycle()
    if not equipDumbbell() then
        print("[WalkFarm] Гантель не найдена")
        return false
    end
    pcall(function()
        LiftDumbbell:FireServer()
        if state.spinSpam then DumbbellSpin:FireServer() end
    end)
    state.trainCounter = state.trainCounter + 1
    return true
end

local function startTrain()
    if state.trainRunning then return end
    state.trainRunning = true
    state.trainCounter = 0
    task.spawn(function()
        while state.trainRunning do
            doTrainCycle()
            task.wait(state.spamRate)
        end
        -- после остановки возвращаем гантель
        equipDumbbell()
    end)
    print("[WalkFarm] Тренировка запущена")
end

local function stopTrain()
    state.trainRunning = false
    print("[WalkFarm] Тренировка остановлена. Всего:", state.trainCounter)
end

-- ============ ВИЗУАЛЫ ============
local visuals = { holeESP = false, itemESP = false, highlight = false }

local function setHoleESP(on)
    visuals.holeESP = on
    if not on then
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "HoleESP" then obj:Destroy() end
        end
        local new = {}
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name ~= "HoleESP" then table.insert(new, obj) end
        end
        state.visualObjects = new
        return
    end
    for _, hole in ipairs(collectHoles()) do
        if not hole:FindFirstChild("HoleESP") then
            local hl = Instance.new("Highlight")
            hl.Name = "HoleESP"
            hl.FillColor = Color3.fromRGB(138, 43, 226)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.6
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = hole
            table.insert(state.visualObjects, hl)
        end
    end
end

local function setItemESP(on)
    visuals.itemESP = on
    state.itemESPActive = on
    if not on then
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "ItemESP" then obj:Destroy() end
        end
        local new = {}
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name ~= "ItemESP" then table.insert(new, obj) end
        end
        state.visualObjects = new
        return
    end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if si then
        for _, v in ipairs(si:GetChildren()) do
            if v:IsA("Model") and not v:FindFirstChild("ItemESP") then
                local hl = Instance.new("Highlight")
                hl.Name = "ItemESP"
                hl.FillColor = Color3.fromRGB(255, 180, 60)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = v
                table.insert(state.visualObjects, hl)
            end
        end
    end
end

local function setHighlight(on)
    visuals.highlight = on
    if not on then
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "TargetHL" then obj:Destroy() end
        end
        local new = {}
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name ~= "TargetHL" then table.insert(new, obj) end
        end
        state.visualObjects = new
        return
    end
    if not state.selectedHole then return end
    local hl = Instance.new("Highlight")
    hl.Name = "TargetHL"
    hl.FillColor = Color3.fromRGB(255, 80, 80)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = state.selectedHole
    table.insert(state.visualObjects, hl)
end

-- ============ GUI ============
local Window = HIros:CreateWindow({
    Name = "Walk Farm v13",
    Theme = "Purple",
    GlowMode = "rainbow",
})

-- ============ ВКЛАДКА ФАРМ ============
local FarmTab = Window:CreateTab({ Name = "Фарм", Icon = "⚡" })

FarmTab:CreateSection({ Text = "База" })

local holes = collectHoles()
local holeOptions = {}
local holeMap = {}
for i, hole in ipairs(holes) do
    local name = hole:GetFullName()
    table.insert(holeOptions, name)
    holeMap[name] = hole
end
if #holeOptions == 0 then holeOptions = {"(нет дыр)"} end

FarmTab:CreateDropdown({
    Name = "Выбери базу",
    Options = holeOptions,
    CurrentOption = holeOptions[1],
    Callback = function(opt)
        state.selectedHole = holeMap[opt]
        print("[WalkFarm] Выбрана база:", opt)
        if visuals.highlight then setHighlight(false); setHighlight(true) end
    end,
})

FarmTab:CreateButton({
    Name = "🎯 Определить мою базу",
    Callback = function()
        local hole = findMyBase()
        if hole then
            state.selectedHole = hole
            Window:Notify({ Title = "База найдена", Content = hole:GetFullName(), Kind = "success" })
        else
            Window:Notify({ Title = "Ошибка", Content = "База не найдена", Kind = "error" })
        end
    end,
})

FarmTab:CreateSection({ Text = "Настройки фарма" })

FarmTab:CreateSlider({
    Name = "Лимит предметов",
    Min = 1, Max = 500, Increment = 1,
    CurrentValue = 50,
    Callback = function(v) state.farmLimit = v end,
})

FarmTab:CreateSlider({
    Name = "GiveMe после N",
    Min = 1, Max = 50, Increment = 1,
    CurrentValue = 10,
    Callback = function(v) state.giveMeThreshold = v end,
})

FarmTab:CreateDropdown({
    Name = "Способ GiveMe",
    Options = {"Invoke", "Click", "Both"},
    CurrentOption = "Invoke",
    Callback = function(opt) state.giveMeMethod = opt end,
})

FarmTab:CreateDropdown({
    Name = "Способ ТП",
    Options = {"Position", "CFrame", "PivotTo"},
    CurrentOption = "Position",
    Callback = function(opt) state.tpMethod = opt end,
})

FarmTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(v) setNoclip(v) end,
})

FarmTab:CreateSection({ Text = "Управление" })

FarmTab:CreateButton({
    Name = "▶ START ФАРМ",
    Callback = function()
        startFarm()
        Window:Notify({ Title = "Фарм", Content = "Запущен", Kind = "success" })
    end,
})

FarmTab:CreateButton({
    Name = "■ STOP ФАРМ",
    Callback = function()
        stopFarm()
        Window:Notify({ Title = "Фарм", Content = "Остановлен", Kind = "warning" })
    end,
})

FarmTab:CreateButton({
    Name = "⚡ GiveMe вручную",
    Callback = function()
        task.spawn(function()
            triggerGiveMe()
            Window:Notify({ Title = "GiveMe", Content = "Отправлено", Kind = "info" })
        end)
    end,
})

-- ============ ВКЛАДКА ТРЕНИРОВКА ============
local TrainTab = Window:CreateTab({ Name = "Тренировка", Icon = "💪" })

TrainTab:CreateSection({ Text = "Настройки" })

TrainTab:CreateSlider({
    Name = "Задержка между вызовами (сек)",
    Min = 0.01, Max = 1, Increment = 0.01,
    CurrentValue = 0.1,
    Callback = function(v) state.spamRate = v end,
})

TrainTab:CreateToggle({
    Name = "🔄 Спам DumbbellSpin",
    CurrentValue = false,
    Callback = function(v) state.spinSpam = v end,
})

TrainTab:CreateSection({ Text = "Управление" })

TrainTab:CreateButton({
    Name = "▶ START ТРЕНИРОВКА",
    Callback = function()
        startTrain()
        Window:Notify({ Title = "Тренировка", Content = "Запущена", Kind = "success" })
    end,
})

TrainTab:CreateButton({
    Name = "■ STOP ТРЕНИРОВКА",
    Callback = function()
        stopTrain()
        Window:Notify({ Title = "Тренировка", Content = "Остановлена (" .. state.trainCounter .. ")", Kind = "warning" })
    end,
})

TrainTab:CreateButton({
    Name = "📊 Показать счётчик",
    Callback = function()
        Window:Notify({
            Title = "Тренировка",
            Content = "Всего повторений: " .. state.trainCounter,
            Kind = "info",
        })
    end,
})

TrainTab:CreateButton({
    Name = "💪 Один повтор вручную",
    Callback = function()
        task.spawn(function()
            doTrainCycle()
            Window:Notify({ Title = "Тренировка", Content = "1 повтор", Kind = "info" })
        end)
    end,
})

-- ============ ВКЛАДКА ВИЗУАЛЫ ============
local VisualsTab = Window:CreateTab({ Name = "Визуалы", Icon = "🎨" })
VisualsTab:CreateSection({ Text = "ESP" })
VisualsTab:CreateToggle({ Name = "ESP дыры", CurrentValue = false, Callback = function(v) setHoleESP(v) end })
VisualsTab:CreateToggle({ Name = "ESP предметов", CurrentValue = false, Callback = function(v) setItemESP(v) end })
VisualsTab:CreateToggle({ Name = "Подсветка цели", CurrentValue = false, Callback = function(v) setHighlight(v) end })

-- ============ ВКЛАДКА ИНФО ============
local InfoTab = Window:CreateTab({ Name = "Инфо", Icon = "ℹ" })
InfoTab:CreateParagraph({
    Title = "Walk Farm v13",
    Content = "Тренировка и фарм РАЗДЕЛЕНЫ. Вкладка 'Фарм' — только фарм. Вкладка 'Тренировка' — только гантель. Библиотека: HIros 6.0.",
})

print("скибиди")
