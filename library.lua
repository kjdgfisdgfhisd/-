-- MenuLibrary (LocalScript)
-- Путь: StarterPlayer > StarterPlayerScripts
-- Это "библиотека" — сама ничего не создаёт, ждёт вызова из TestMenu

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Library = {}
Library.__index = Library

-- === ТЕМЫ ===
local THEMES = {
    Default = {
        Accent = Color3.fromRGB(0, 162, 255),
        Background = Color3.fromRGB(20, 20, 25),
        Secondary = Color3.fromRGB(28, 28, 34),
        Element = Color3.fromRGB(38, 38, 48),
        Text = Color3.fromRGB(240, 240, 245),
        SubText = Color3.fromRGB(150, 150, 165),
    },
    Purple = {
        Accent = Color3.fromRGB(138, 43, 226),
        Background = Color3.fromRGB(15, 15, 18),
        Secondary = Color3.fromRGB(25, 25, 30),
        Element = Color3.fromRGB(35, 35, 42),
        Text = Color3.fromRGB(230, 230, 235),
        SubText = Color3.fromRGB(130, 130, 145),
    },
    Green = {
        Accent = Color3.fromRGB(40, 200, 120),
        Background = Color3.fromRGB(18, 22, 20),
        Secondary = Color3.fromRGB(26, 32, 28),
        Element = Color3.fromRGB(36, 44, 40),
        Text = Color3.fromRGB(235, 245, 238),
        SubText = Color3.fromRGB(150, 170, 158),
    },
}

Library.Theme = THEMES.Default
Library.Flags = {}

-- === СОЗДАНИЕ ОКНА ===
function Library:CreateWindow(config)
    local self = setmetatable({}, Library)
    self.Config = config or {}
    self.Name = self.Config.Name or "Library"
    self.Enabled = false
    self.Tabs = {}
    self.TabButtons = {}
    self.CurrentTab = nil

    if self.Config.Theme and THEMES[self.Config.Theme] then
        self.Theme = THEMES[self.Config.Theme]
    end

    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "MenuLibrary_" .. self.Name
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.DisplayOrder = 100
    self.ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- wrapper для перетаскивания
    self.Wrapper = Instance.new("Frame")
    self.Wrapper.Name = "Wrapper"
    self.Wrapper.BackgroundTransparency = 1
    self.Wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Wrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.Wrapper.Size = UDim2.new(0, 0, 0, 0)
    self.Wrapper.Parent = self.ScreenGui

    -- свечение (под окном)
    self.GlowHolder = Instance.new("Frame")
    self.GlowHolder.BackgroundTransparency = 1
    self.GlowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    self.GlowHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.GlowHolder.Size = UDim2.new(0, 0, 0, 0)
    self.GlowHolder.ZIndex = 0
    self.GlowHolder.Visible = false
    self.GlowHolder.Parent = self.Wrapper

    self.GlowLayers = {}
    for i, cfg in ipairs({
        { padding = 24, transparency = 0.94 },
        { padding = 14, transparency = 0.89 },
        { padding = 6,  transparency = 0.82 },
    }) do
        local layer = Instance.new("Frame")
        layer.AnchorPoint = Vector2.new(0.5, 0.5)
        layer.Position = UDim2.new(0.5, 0, 0.5, 0)
        layer.BackgroundColor3 = self.Theme.Accent
        layer.BackgroundTransparency = cfg.transparency
        layer.BorderSizePixel = 0
        layer.ZIndex = 0
        layer.Parent = self.GlowHolder

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12 + cfg.padding * 0.6)
        corner.Parent = layer

        table.insert(self.GlowLayers, { instance = layer, config = cfg })
    end

    self.WindowSize = Vector2.new(620, 420)
    self:_syncGlowSize()

    -- пульсация
    task.spawn(function()
        while self.GlowHolder.Parent do
            for _, l in ipairs(self.GlowLayers) do
                TweenService:Create(l.instance, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    BackgroundTransparency = math.clamp(l.config.transparency + 0.05, 0, 1),
                }):Play()
            end
            task.wait(1.8)
            for _, l in ipairs(self.GlowLayers) do
                TweenService:Create(l.instance, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    BackgroundTransparency = l.config.transparency,
                }):Play()
            end
            task.wait(1.8)
        end
    end)

    -- основное окно
    self.Main = Instance.new("Frame")
    self.Main.Name = "Main"
    self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.Main.Size = UDim2.new(0, self.WindowSize.X, 0, self.WindowSize.Y)
    self.Main.BackgroundColor3 = self.Theme.Background
    self.Main.BorderSizePixel = 0
    self.Main.ClipsDescendants = true
    self.Main.Visible = false
    self.Main.ZIndex = 2
    self.Main.Parent = self.Wrapper

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = self.Main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = self.Theme.Accent
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = self.Main
    self.MainStroke = mainStroke

    -- TitleBar
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 40)
    self.TitleBar.BackgroundColor3 = self.Theme.Secondary
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Active = true
    self.TitleBar.ZIndex = 3
    self.TitleBar.Parent = self.Main

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 12)
    tbCorner.Parent = self.TitleBar

    local tbPatch = Instance.new("Frame")
    tbPatch.Size = UDim2.new(1, 0, 0, 14)
    tbPatch.Position = UDim2.new(0, 0, 1, -14)
    tbPatch.BackgroundColor3 = self.Theme.Secondary
    tbPatch.BorderSizePixel = 0
    tbPatch.ZIndex = 3
    tbPatch.Parent = self.TitleBar

    local titleText = Instance.new("TextLabel")
    titleText.BackgroundTransparency = 1
    titleText.Position = UDim2.new(0, 16, 0, 0)
    titleText.Size = UDim2.new(1, -100, 1, 0)
    titleText.Font = Enum.Font.GothamBold
    titleText.Text = self.Name
    titleText.TextColor3 = self.Theme.Text
    titleText.TextSize = 15
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.ZIndex = 4
    titleText.Parent = self.TitleBar

    -- Close
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(230, 70, 80)
    closeBtn.AutoButtonColor = false
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.ZIndex = 4
    closeBtn.Parent = self.TitleBar

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 8)
    cbCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle(false)
    end)

    -- Sidebar
    self.Sidebar = Instance.new("ScrollingFrame")
    self.Sidebar.Name = "Sidebar"
    self.Sidebar.Size = UDim2.new(0, 160, 1, -40)
    self.Sidebar.Position = UDim2.new(0, 0, 0, 40)
    self.Sidebar.BackgroundColor3 = self.Theme.Secondary
    self.Sidebar.BorderSizePixel = 0
    self.Sidebar.ScrollBarThickness = 0
    self.Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.Sidebar.ZIndex = 3
    self.Sidebar.Parent = self.Main

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.Parent = self.Sidebar

    local sidebarPad = Instance.new("UIPadding")
    sidebarPad.PaddingTop = UDim.new(0, 8)
    sidebarPad.PaddingLeft = UDim.new(0, 8)
    sidebarPad.PaddingRight = UDim.new(0, 8)
    sidebarPad.Parent = self.Sidebar

    -- Content
    self.ContentArea = Instance.new("ScrollingFrame")
    self.ContentArea.Name = "Content"
    self.ContentArea.Size = UDim2.new(1, -160, 1, -40)
    self.ContentArea.Position = UDim2.new(0, 160, 0, 40)
    self.ContentArea.BackgroundTransparency = 1
    self.ContentArea.BorderSizePixel = 0
    self.ContentArea.ScrollBarThickness = 4
    self.ContentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.ContentArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.ContentArea.ZIndex = 3
    self.ContentArea.Parent = self.Main

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.Parent = self.ContentArea

    local contentPad = Instance.new("UIPadding")
    contentPad.PaddingTop = UDim.new(0, 12)
    contentPad.PaddingLeft = UDim.new(0, 12)
    contentPad.PaddingRight = UDim.new(0, 12)
    contentPad.PaddingBottom = UDim.new(0, 12)
    contentPad.Parent = self.ContentArea

    self:_setupDrag()
    self:_createToggleButton()

    self:Toggle(true)

    return self
end

function Library:_syncGlowSize()
    for _, l in ipairs(self.GlowLayers) do
        local pad = l.config.padding
        l.instance.Size = UDim2.new(0, self.WindowSize.X + pad * 2, 0, self.WindowSize.Y + pad * 2)
    end
end

function Library:_setupDrag()
    local self = self
    local dragging, dragStart, startPos

    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.Wrapper.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.Wrapper.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function Library:_createToggleButton()
    local self = self

    self.ToggleBtn = Instance.new("TextButton")
    self.ToggleBtn.Size = UDim2.new(0, 48, 0, 48)
    self.ToggleBtn.Position = UDim2.new(1, -68, 1, -68)
    self.ToggleBtn.BackgroundColor3 = self.Theme.Secondary
    self.ToggleBtn.AutoButtonColor = false
    self.ToggleBtn.Font = Enum.Font.GothamBold
    self.ToggleBtn.Text = "☰"
    self.ToggleBtn.TextColor3 = self.Theme.Text
    self.ToggleBtn.TextSize = 22
    self.ToggleBtn.Parent = self.ScreenGui

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = self.ToggleBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = self.Theme.Accent
    btnStroke.Thickness = 2
    btnStroke.Transparency = 0.3
    btnStroke.Parent = self.ToggleBtn

    self.ToggleBtn.MouseButton1Click:Connect(function()
        self:Toggle(not self.Enabled)
    end)

    -- горячая клавиша
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            self:Toggle(not self.Enabled)
        end
    end)
end

function Library:Toggle(enabled)
    self.Enabled = enabled
    if enabled then
        self.Main.Visible = true
        self.GlowHolder.Visible = true
        self.Main.Size = UDim2.new(0, self.WindowSize.X, 0, 0)
        TweenService:Create(self.Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, self.WindowSize.X, 0, self.WindowSize.Y),
        }):Play()
    else
        local tween = TweenService:Create(self.Main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, self.WindowSize.X, 0, 0),
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not self.Enabled then
                self.Main.Visible = false
                self.GlowHolder.Visible = false
            end
        end)
    end
end

-- === ТАБЫ ===
function Library:CreateTab(name)
    local self = self
    local tab = { Name = name, Elements = {} }
    tab.Parent = self
    self.Tabs[name] = tab

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = self.Theme.Element
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.Text = "  " .. name
    btn.TextColor3 = self.Theme.SubText
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 4
    btn.Parent = self.Sidebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    self.TabButtons[name] = btn

    local content = Instance.new("Frame")
    content.Name = name .. "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.ZIndex = 3
    content.Parent = self.ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = content

    tab.Content = content

    btn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    if not self.CurrentTab then
        self:SelectTab(name)
    end

    return tab
end

function Library:SelectTab(name)
    if self.CurrentTab == name then return end
    self.CurrentTab = name

    for tabName, tab in pairs(self.Tabs) do
        tab.Content.Visible = (tabName == name)
    end

    for tabName, btn in pairs(self.TabButtons) do
        local active = (tabName == name)
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and self.Theme.Accent or self.Theme.Element,
            TextColor3 = active and Color3.fromRGB(255, 255, 255) or self.Theme.SubText,
        }):Play()
    end
end

-- === ЭЛЕМЕНТЫ ===

function Library:CreateButton(tab, config)
    local self = self
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = self.Theme.Element
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.Text = "  " .. (config.Name or "Button")
    btn.TextColor3 = self.Theme.Text
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 4
    btn.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(48, 48, 60) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = self.Theme.Element }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        if config.Callback then config.Callback() end
    end)

    return btn
end

function Library:CreateToggle(tab, config)
    local self = self
    local state = config.CurrentValue or false
    local flag = config.Flag

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = self.Theme.Element
    row.AutoButtonColor = false
    row.Font = Enum.Font.GothamMedium
    row.Text = "  " .. (config.Name or "Toggle")
    row.TextColor3 = self.Theme.Text
    row.TextSize = 13
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.ZIndex = 4
    row.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 36, 0, 18)
    track.Position = UDim2.new(1, -46, 0.5, -9)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    track.BorderSizePixel = 0
    track.ZIndex = 5
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function updateVisual()
        if state then
            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = self.Theme.Accent }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.new(1, -16, 0.5, -7) }):Play()
        else
            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(60, 60, 75) }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.new(0, 2, 0.5, -7) }):Play()
        end
    end
    updateVisual()

    row.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        if flag then Library.Flags[flag] = state end
        if config.Callback then config.Callback(state) end
    end)

    table.insert(tab.Elements, { Type = "Toggle", Instance = row, UpdateTheme = updateVisual })

    return {
        Instance = row,
        Get = function() return state end,
        Set = function(v)
            state = v and true or false
            updateVisual()
            if flag then Library.Flags[flag] = state end
            if config.Callback then config.Callback(state) end
        end,
        UpdateTheme = updateVisual,
    }
end

function Library:CreateSlider(tab, config)
    local self = self
    local value = config.CurrentValue or 0
    local min = config.Min or 0
    local max = config.Max or 100
    local increment = config.Increment or 1
    local suffix = config.Suffix or ""
    local flag = config.Flag

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = self.Theme.Element
    row.BorderSizePixel = 0
    row.ZIndex = 4
    row.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 10, 0, 0)
    label.Size = UDim2.new(1, -80, 0, 24)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "Slider"
    label.TextColor3 = self.Theme.Text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -70, 0, 0)
    valueLabel.Size = UDim2.new(0, 60, 0, 24)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(value) .. suffix
    valueLabel.TextColor3 = self.Theme.Accent
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 5
    valueLabel.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 6)
    track.Position = UDim2.new(0, 10, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    track.BorderSizePixel = 0
    track.ZIndex = 5
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = self.Theme.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 7
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function updateVisual()
        local alpha = (max - min > 0) and (value - min) / (max - min) or 0
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(value) .. suffix
    end
    updateVisual()

    local dragging = false
    local function handleInput(input)
        local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor((min + alpha * (max - min)) / increment + 0.5) * increment
        updateVisual()
        if flag then Library.Flags[flag] = value end
        if config.Callback then config.Callback(value) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            handleInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            handleInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    table.insert(tab.Elements, { Type = "Slider", Instance = row, UpdateTheme = updateVisual })

    return {
        Instance = row,
        Get = function() return value end,
        Set = function(v)
            value = v
            updateVisual()
            if flag then Library.Flags[flag] = value end
            if config.Callback then config.Callback(value) end
        end,
    }
end

function Library:CreateColorPicker(tab, config)
    local self = self
    local current = config.CurrentValue or Color3.fromRGB(0, 162, 255)
    local flag = config.Flag
    local open = false
    local h, s, v = Color3.toHSV(current)

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = self.Theme.Element
    row.AutoButtonColor = false
    row.Font = Enum.Font.GothamMedium
    row.Text = "  " .. (config.Name or "Color")
    row.TextColor3 = self.Theme.Text
    row.TextSize = 13
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.ZIndex = 4
    row.Parent = tab.Content

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 20, 0, 20)
    preview.Position = UDim2.new(1, -30, 0.5, -10)
    preview.BackgroundColor3 = current
    preview.BorderSizePixel = 0
    preview.ZIndex = 5
    preview.Parent = row

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 4)
    previewCorner.Parent = preview

    -- Holder
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.BackgroundColor3 = self.Theme.Secondary
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.Visible = false
    holder.ZIndex = 4
    holder.Parent = tab.Content

    local holderCorner = Instance.new("UICorner")
    holderCorner.CornerRadius = UDim.new(0, 6)
    holderCorner.Parent = holder

    local holderPad = Instance.new("UIPadding")
    holderPad.PaddingTop = UDim.new(0, 10)
    holderPad.PaddingLeft = UDim.new(0, 10)
    holderPad.PaddingRight = UDim.new(0, 10)
    holderPad.PaddingBottom = UDim.new(0, 10)
    holderPad.Parent = holder

    -- SV field
    local svField = Instance.new("ImageLabel")
    svField.Size = UDim2.new(1, 0, 0, 100)
    svField.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    svField.BorderSizePixel = 0
    svField.ZIndex = 5
    svField.Parent = holder

    local svCorner = Instance.new("UICorner")
    svCorner.CornerRadius = UDim.new(0, 4)
    svCorner.Parent = svField

    local svGrad = Instance.new("UIGradient")
    svGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
    })
    svGrad.Parent = svField

    local svDark = Instance.new("Frame")
    svDark.Size = UDim2.new(1, 0, 1, 0)
    svDark.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    svDark.BorderSizePixel = 0
    svDark.ZIndex = 6
    svDark.Parent = svField

    local svDarkCorner = Instance.new("UICorner")
    svDarkCorner.CornerRadius = UDim.new(0, 4)
    svDarkCorner.Parent = svDark

    local svDarkGrad = Instance.new("UIGradient")
    svDarkGrad.Rotation = 90
    svDarkGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    svDarkGrad.Parent = svDark

    local svMarker = Instance.new("Frame")
    svMarker.Size = UDim2.new(0, 10, 0, 10)
    svMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    svMarker.BackgroundTransparency = 1
    svMarker.ZIndex = 8
    svMarker.Parent = svField

    local svMarkerStroke = Instance.new("UIStroke")
    svMarkerStroke.Thickness = 2
    svMarkerStroke.Color = Color3.fromRGB(255, 255, 255)
    svMarkerStroke.Parent = svMarker

    local svMarkerCorner = Instance.new("UICorner")
    svMarkerCorner.CornerRadius = UDim.new(1, 0)
    svMarkerCorner.Parent = svMarker

    -- Hue bar
    local hueBar = Instance.new("ImageLabel")
    hueBar.Size = UDim2.new(1, 0, 0, 12)
    hueBar.Position = UDim2.new(0, 0, 0, 110)
    hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueBar.BorderSizePixel = 0
    hueBar.ZIndex = 5
    hueBar.Parent = holder

    local hueCorner = Instance.new("UICorner")
    hueCorner.CornerRadius = UDim.new(1, 0)
    hueCorner.Parent = hueBar

    local hueGrad = Instance.new("UIGradient")
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
    })
    hueGrad.Parent = hueBar

    local hueMarker = Instance.new("Frame")
    hueMarker.Size = UDim2.new(0, 12, 0, 12)
    hueMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    hueMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueMarker.ZIndex = 8
    hueMarker.Parent = hueBar

    local hueMarkerCorner = Instance.new("UICorner")
    hueMarkerCorner.CornerRadius = UDim.new(1, 0)
    hueMarkerCorner.Parent = hueMarker

    local hueMarkerStroke = Instance.new("UIStroke")
    hueMarkerStroke.Thickness = 2
    hueMarkerStroke.Color = Color3.fromRGB(0, 0, 0)
    hueMarkerStroke.Transparency = 0.6
    hueMarkerStroke.Parent = hueMarker

    -- HEX
    local hexBox = Instance.new("TextBox")
    hexBox.Size = UDim2.new(1, 0, 0, 24)
    hexBox.Position = UDim2.new(0, 0, 0, 130)
    hexBox.BackgroundColor3 = self.Theme.Element
    hexBox.BorderSizePixel = 0
    hexBox.Font = Enum.Font.GothamMedium
    hexBox.Text = "#000000"
    hexBox.TextColor3 = self.Theme.Text
    hexBox.TextSize = 12
    hexBox.ClearTextOnFocus = false
    hexBox.ZIndex = 5
    hexBox.Parent = holder

    local hexCorner = Instance.new("UICorner")
    hexCorner.CornerRadius = UDim.new(0, 4)
    hexCorner.Parent = hexBox

    local hexPad = Instance.new("UIPadding")
    hexPad.PaddingLeft = UDim.new(0, 8)
    hexPad.Parent = hexBox

    local function toHex(c)
        return string.format("#%02X%02X%02X",
            math.floor(c.R * 255 + 0.5),
            math.floor(c.G * 255 + 0.5),
            math.floor(c.B * 255 + 0.5)
        )
    end

    local function fromHex(str)
        str = str:gsub("#", "")
        if #str ~= 6 then return nil end
        local r = tonumber(str:sub(1, 2), 16)
        local g = tonumber(str:sub(3, 4), 16)
        local b = tonumber(str:sub(5, 6), 16)
        if not (r and g and b) then return nil end
        return Color3.fromRGB(r, g, b)
    end

    local updating = false
    local function refresh()
        updating = true
        svGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
        })
        svMarker.Position = UDim2.new(s, 0, 1 - v, 0)
        hueMarker.Position = UDim2.new(h, 0, 0.5, 0)
        preview.BackgroundColor3 = current
        hexBox.Text = toHex(current)
        updating = false
    end

    local function apply()
        current = Color3.fromHSV(h, s, v)
        refresh()
        if flag then Library.Flags[flag] = current end
        if config.Callback then config.Callback(current) end
    end

    -- SV drag
    local draggingSV = false
    local function handleSV(input)
        s = math.clamp((input.Position.X - svField.AbsolutePosition.X) / svField.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((input.Position.Y - svField.AbsolutePosition.Y) / svField.AbsoluteSize.Y, 0, 1)
        apply()
    end

    svField.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = true
            handleSV(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            handleSV(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = false
        end
    end)

    -- Hue drag
    local draggingHue = false
    local function handleHue(input)
        h = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        apply()
    end

    hueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            handleHue(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            handleHue(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = false
        end
    end)

    hexBox.FocusLost:Connect(function()
        if updating then return end
        local col = fromHex(hexBox.Text)
        if col then
            h, s, v = Color3.toHSV(col)
            apply()
        else
            hexBox.Text = toHex(current)
        end
    end)

    row.MouseButton1Click:Connect(function()
        open = not open
        if open then
            holder.Visible = true
            TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, 164),
            }):Play()
            refresh()
        else
            local t = TweenService:Create(holder, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0),
            })
            t:Play()
            t.Completed:Connect(function()
                if not open then holder.Visible = false end
            end)
        end
    end)

    refresh()

    table.insert(tab.Elements, { Type = "ColorPicker", Instance = row })

    return {
        Instance = row,
        Get = function() return current end,
        Set = function(col)
            h, s, v = Color3.toHSV(col)
            apply()
        end,
    }
end

function Library:CreateLabel(tab, config)
    local self = self
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = config.Text or "Label"
    label.TextColor3 = self.Theme.SubText
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 4
    label.Parent = tab.Content
    return label
end

function Library:CreateDivider(tab)
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    divider.BorderSizePixel = 0
    divider.ZIndex = 4
    divider.Parent = tab.Content
    return divider
end

function Library:Notify(config)
    local self = self
    local notify = Instance.new("Frame")
    notify.Size = UDim2.new(0, 280, 0, 70)
    notify.Position = UDim2.new(1, 300, 0, 20)
    notify.BackgroundColor3 = self.Theme.Secondary
    notify.BorderSizePixel = 0
    notify.Parent = self.ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notify

    local stroke = Instance.new("UIStroke")
    stroke.Color = self.Theme.Accent
    stroke.Thickness = 2
    stroke.Parent = notify

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 12, 0, 8)
    title.Size = UDim2.new(1, -24, 0, 20)
    title.Font = Enum.Font.GothamBold
    title.Text = config.Title or "Notification"
    title.TextColor3 = self.Theme.Text
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = notify

    local content = Instance.new("TextLabel")
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 12, 0, 30)
    content.Size = UDim2.new(1, -24, 0, 32)
    content.Font = Enum.Font.Gotham
    content.Text = config.Content or ""
    content.TextColor3 = self.Theme.SubText
    content.TextSize = 12
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextWrapped = true
    content.Parent = notify

    TweenService:Create(notify, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -300, 0, 20),
    }):Play()

    task.delay(config.Duration or 5, function()
        local tween = TweenService:Create(notify, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 300, 0, 20),
        })
        tween:Play()
        tween.Completed:Connect(function()
            notify:Destroy()
        end)
    end)

    return notify
end

-- === ЭКСПОРТ ЧЕРЕЗ _G (для теста) ===
_G.MenuLibrary = Library

return Library
