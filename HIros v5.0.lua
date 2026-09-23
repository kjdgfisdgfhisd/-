-- HIros UI Library v5.0 — full edition
-- Loader: local HIros = loadstring(game:HttpGet(".../library.lua"))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local BRAND = "HIros"
local VERSION = "5.0"

local Library = {}
Library.__index = Library

-- ============================================================
-- THEMES
-- ============================================================
local THEMES = {
    Blue   = { Name = "Синяя",   Accent = Color3.fromRGB(88, 101, 242), AccentLight = Color3.fromRGB(160, 170, 255) },
    Red    = { Name = "Красная", Accent = Color3.fromRGB(235, 70, 85),  AccentLight = Color3.fromRGB(255, 150, 160) },
    Yellow = { Name = "Жёлтая",  Accent = Color3.fromRGB(235, 180, 45), AccentLight = Color3.fromRGB(255, 220, 130) },
    Green  = { Name = "Зелёная", Accent = Color3.fromRGB(40, 200, 120), AccentLight = Color3.fromRGB(150, 245, 190) },
    Purple = { Name = "Фиолет",  Accent = Color3.fromRGB(138, 43, 226), AccentLight = Color3.fromRGB(200, 150, 255) },
}
local currentThemeKey = "Blue"

local BG_DARK    = Color3.fromRGB(18, 18, 22)
local BG_PANEL   = Color3.fromRGB(26, 26, 31)
local BG_ITEM    = Color3.fromRGB(34, 34, 40)
local BG_HOVER   = Color3.fromRGB(44, 44, 52)
local TEXT_COLOR = Color3.fromRGB(235, 235, 240)
local SUBTEXT    = Color3.fromRGB(150, 150, 160)

local DEFAULT_HOTKEY = Enum.KeyCode.RightShift
local CONFIG_FILE_PREFIX = "MenuLibrary_config"

-- ============================================================
-- LIBRARY API
-- ============================================================
function Library:RegisterTheme(name, themeTable)
    if type(name) ~= "string" or type(themeTable) ~= "table" then return end
    THEMES[name] = {
        Name = themeTable.Name or name,
        Accent = themeTable.Accent or Color3.fromRGB(88, 101, 242),
        AccentLight = themeTable.AccentLight or (themeTable.Accent or Color3.fromRGB(88, 101, 242)):Lerp(Color3.new(1,1,1), 0.4),
    }
end

function Library:GetInfo()
    return { Version = VERSION, Brand = BRAND, Author = "kjdgfisdgfhisd" }
end

function Library:SetAPI()
    if getgenv then
        getgenv().HIros = Library
        getgenv().HIrosVersion = VERSION
    end
    _G.HIros = Library
    _G.HIrosVersion = VERSION
end

-- ============================================================
-- JSON
-- ============================================================
local function jsonEncode(tbl)
    local function enc(v)
        local t = type(v)
        if t == "string" then return '"' .. v:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n") .. '"'
        elseif t == "number" or t == "boolean" then return tostring(v)
        elseif t == "table" then
            if typeof(v) == "Color3" or (v.R and v.G and v.B) then
                return string.format('{"__c3":[%f,%f,%f]}', v.R, v.G, v.B)
            end
            local parts = {}
            for k, val in pairs(v) do
                local key = (type(k) == "string") and ('"' .. k .. '"') or tostring(k)
                table.insert(parts, key .. ":" .. enc(val))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return "null"
    end
    return enc(tbl)
end

local function jsonDecode(str)
    local pos = 1
    local function skip() while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end end
    local function parse()
        skip()
        local c = str:sub(pos,pos)
        if c == "{" then
            pos = pos + 1
            if str:sub(pos, pos+9) == '"__c3"' then
                local arrStart = str:find("%[", pos)
                local arrEnd = str:find("%]", arrStart)
                local arr = str:sub(arrStart+1, arrEnd-1)
                pos = arrEnd + 1
                skip()
                if str:sub(pos,pos) == "}" then pos = pos + 1 end
                local r,g,b = arr:match("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
                return Color3.new(tonumber(r), tonumber(g), tonumber(b))
            end
            local obj = {}
            skip()
            if str:sub(pos,pos) == "}" then pos = pos + 1 return obj end
            while true do
                skip()
                if str:sub(pos,pos) ~= '"' then break end
                local ke = str:find('"', pos+1)
                local key = str:sub(pos+1, ke-1)
                pos = ke + 1
                skip()
                if str:sub(pos,pos) == ":" then pos = pos + 1 end
                obj[key] = parse()
                skip()
                local ch = str:sub(pos,pos)
                if ch == "," then pos = pos + 1
                elseif ch == "}" then pos = pos + 1 break
                else break end
            end
            return obj
        elseif c == '"' then
            local ep = pos + 1
            while ep <= #str do
                local ch = str:sub(ep,ep)
                if ch == "\\" then ep = ep + 2
                elseif ch == '"' then break
                else ep = ep + 1 end
            end
            local raw = str:sub(pos+1, ep-1)
            pos = ep + 1
            return raw:gsub('\\"','"'):gsub('\\\\','\\'):gsub('\\n','\n')
        elseif str:sub(pos,pos+3) == "true" then pos = pos + 4 return true
        elseif str:sub(pos,pos+4) == "false" then pos = pos + 5 return false
        elseif str:sub(pos,pos+3) == "null" then pos = pos + 4 return nil
        else
            local num = str:match("^[%-%d%.eE]+", pos)
            if num then pos = pos + #num return tonumber(num) end
        end
        return nil
    end
    local ok, r = pcall(parse)
    return ok and r or {}
end

-- ============================================================
-- UTILS
-- ============================================================
local function createCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = parent
    return c
end

local function makeRowBase(parent, order, height)
    local row = Instance.new("TextButton")
    row.BackgroundColor3 = BG_ITEM
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, height or 40)
    row.LayoutOrder = order or 0
    row.Font = Enum.Font.GothamMedium
    row.Text = ""
    row.TextColor3 = TEXT_COLOR
    row.TextSize = 13
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.ZIndex = 4
    row.Parent = parent
    createCorner(row, 10)
    return row
end

local function addHover(row)
    row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = BG_HOVER }):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = BG_ITEM }):Play()
    end)
    row.MouseButton1Down:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), { BackgroundColor3 = THEMES[currentThemeKey].Accent }):Play()
    end)
    row.MouseButton1Up:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.15), { BackgroundColor3 = BG_HOVER }):Play()
    end)
end

local function makeBadge(parent, text, color)
    local badge = Instance.new("TextLabel")
    badge.BackgroundColor3 = color or THEMES[currentThemeKey].Accent
    badge.BorderSizePixel = 0
    badge.Font = Enum.Font.GothamBold
    badge.Text = text
    badge.TextColor3 = Color3.fromRGB(255,255,255)
    badge.TextSize = 9
    badge.Size = UDim2.new(0, 36, 0, 14)
    badge.ZIndex = 6
    badge.Parent = parent
    createCorner(badge, 4)
    return badge
end

local function playSound(kind)
    if not SoundService then return end
    pcall(function()
        local id
        if kind == "success" then id = "rbxassetid://6895079853"
        elseif kind == "error" then id = "rbxassetid://6895079929"
        elseif kind == "warning" then id = "rbxassetid://6895079999"
        else id = "rbxassetid://6895080031" end
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = 0.4
        s.Parent = SoundService
        s:Play()
        task.delay(2, function() s:Destroy() end)
    end)
end

-- ============================================================
-- CREATE WINDOW
-- ============================================================
function Library:CreateWindow(config)
    local self = setmetatable({}, Library)
    self.Config = config or {}
    self.Name = self.Config.Name or BRAND
    self.Enabled = false
    self.Tabs = {}
    self.TabButtons = {}
    self.CurrentTab = nil
    self.Flags = {}
    self.Elements = {}
    self._saveToken = 0
    self._scrollBars = {}
    self._hotkey = DEFAULT_HOTKEY
    self._configSlot = "default"
    self._scale = 1

    if self.Config.Theme and THEMES[self.Config.Theme] then
        currentThemeKey = self.Config.Theme
    end

    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "HIros_" .. self.Name
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.DisplayOrder = 50
    self.ScreenGui.Parent = PlayerGui

    self.Wrapper = Instance.new("Frame")
    self.Wrapper.Name = "Wrapper"
    self.Wrapper.BackgroundTransparency = 1
    self.Wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Wrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.Wrapper.Size = UDim2.new(0, 0, 0, 0)
    self.Wrapper.Parent = self.ScreenGui

    self.Scale = Instance.new("UIScale")
    self.Scale.Scale = 1
    self.Scale.Parent = self.Wrapper

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
        { padding = 26, transparency = 0.93 },
        { padding = 16, transparency = 0.88 },
        { padding = 8,  transparency = 0.80 },
    }) do
        local layer = Instance.new("Frame")
        layer.Name = "Glow" .. i
        layer.AnchorPoint = Vector2.new(0.5, 0.5)
        layer.Position = UDim2.new(0.5, 0, 0.5, 0)
        layer.BackgroundColor3 = THEMES[currentThemeKey].Accent
        layer.BackgroundTransparency = cfg.transparency
        layer.BorderSizePixel = 0
        layer.ZIndex = 0
        layer.Parent = self.GlowHolder
        createCorner(layer, 18 + cfg.padding * 0.6)
        table.insert(self.GlowLayers, { instance = layer, config = cfg })
    end

    self.WindowSize = Vector2.new(560, 380)
    self:_syncGlowSize()

    task.spawn(function()
        while self.GlowHolder.Parent do
            if self.Enabled then
                for _, l in ipairs(self.GlowLayers) do
                    TweenService:Create(l.instance, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = math.clamp(l.config.transparency + 0.05, 0, 1),
                    }):Play()
                end
            end
            task.wait(1.8)
            if self.Enabled then
                for _, l in ipairs(self.GlowLayers) do
                    TweenService:Create(l.instance, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = l.config.transparency,
                    }):Play()
                end
            end
            task.wait(1.8)
        end
    end)

    self.Main = Instance.new("Frame")
    self.Main.Name = "Window"
    self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.Main.Size = UDim2.new(0, self.WindowSize.X, 0, self.WindowSize.Y)
    self.Main.BackgroundColor3 = BG_DARK
    self.Main.BackgroundTransparency = 0.18
    self.Main.BorderSizePixel = 0
    self.Main.ClipsDescendants = true
    self.Main.Active = true
    self.Main.Visible = false
    self.Main.ZIndex = 2
    self.Main.Parent = self.Wrapper

    createCorner(self.Main, 18)

    self.MainStroke = Instance.new("UIStroke")
    self.MainStroke.Thickness = 1.6
    self.MainStroke.Transparency = 0.1
    self.MainStroke.Parent = self.Main

    self.StrokeGradient = Instance.new("UIGradient")
    self.StrokeGradient.Parent = self.MainStroke

    local glassShine = Instance.new("Frame")
    glassShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glassShine.BorderSizePixel = 0
    glassShine.Size = UDim2.new(1, 0, 0, 90)
    glassShine.ZIndex = 3
    glassShine.Parent = self.Main
    local shineGrad = Instance.new("UIGradient")
    shineGrad.Rotation = 90
    shineGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(1, 1),
    })
    shineGrad.Parent = glassShine

    -- TitleBar
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.BackgroundColor3 = BG_PANEL
    self.TitleBar.BackgroundTransparency = 0.15
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Size = UDim2.new(1, 0, 0, 42)
    self.TitleBar.Active = true
    self.TitleBar.ZIndex = 3
    self.TitleBar.Parent = self.Main
    createCorner(self.TitleBar, 18)

    local tbPatch = Instance.new("Frame")
    tbPatch.BackgroundColor3 = BG_PANEL
    tbPatch.BackgroundTransparency = 0.15
    tbPatch.BorderSizePixel = 0
    tbPatch.Size = UDim2.new(1, 0, 0, 16)
    tbPatch.Position = UDim2.new(0, 0, 1, -16)
    tbPatch.ZIndex = 3
    tbPatch.Parent = self.TitleBar

    -- иконка окна
    self.TitleIcon = Instance.new("TextLabel")
    self.TitleIcon.BackgroundTransparency = 1
    self.TitleIcon.Position = UDim2.new(0, 12, 0, 0)
    self.TitleIcon.Size = UDim2.new(0, 24, 1, 0)
    self.TitleIcon.Font = Enum.Font.GothamBold
    self.TitleIcon.Text = "⚡"
    self.TitleIcon.TextColor3 = THEMES[currentThemeKey].Accent
    self.TitleIcon.TextSize = 16
    self.TitleIcon.ZIndex = 4
    self.TitleIcon.Parent = self.TitleBar

    self.TitleText = Instance.new("TextLabel")
    self.TitleText.BackgroundTransparency = 1
    self.TitleText.Position = UDim2.new(0, 38, 0, 0)
    self.TitleText.Size = UDim2.new(1, -160, 1, 0)
    self.TitleText.Font = Enum.Font.GothamBold
    self.TitleText.Text = self.Name
    self.TitleText.TextColor3 = TEXT_COLOR
    self.TitleText.TextSize = 15
    self.TitleText.TextXAlignment = Enum.TextXAlignment.Left
    self.TitleText.ZIndex = 4
    self.TitleText.Parent = self.TitleBar

    -- minimize
    local minBtn = Instance.new("TextButton")
    minBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
    minBtn.AutoButtonColor = false
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -68, 0.5, -13)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.TextSize = 14
    minBtn.ZIndex = 4
    minBtn.Parent = self.TitleBar
    createCorner(minBtn, 10)

    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundColor3 = Color3.fromRGB(235, 80, 90)
    closeBtn.AutoButtonColor = false
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -13)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.ZIndex = 4
    closeBtn.Parent = self.TitleBar
    createCorner(closeBtn, 10)

    closeBtn.MouseButton1Click:Connect(function() self:Toggle(false) end)
    minBtn.MouseButton1Click:Connect(function() self:Minimize() end)

    -- Sidebar
    self.Sidebar = Instance.new("Frame")
    self.Sidebar.BackgroundColor3 = BG_PANEL
    self.Sidebar.BackgroundTransparency = 0.15
    self.Sidebar.BorderSizePixel = 0
    self.Sidebar.Position = UDim2.new(0, 0, 0, 42)
    self.Sidebar.Size = UDim2.new(0, 150, 1, -42)
    self.Sidebar.ZIndex = 3
    self.Sidebar.Parent = self.Main

    local profileBox = Instance.new("Frame")
    profileBox.BackgroundTransparency = 1
    profileBox.Size = UDim2.new(1, 0, 0, 84)
    profileBox.ZIndex = 3
    profileBox.Parent = self.Sidebar

    self.Avatar = Instance.new("ImageLabel")
    self.Avatar.Size = UDim2.new(0, 48, 0, 48)
    self.Avatar.Position = UDim2.new(0.5, -24, 0, 14)
    self.Avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
    self.Avatar.Image = ""
    self.Avatar.ZIndex = 4
    self.Avatar.Parent = profileBox
    createCorner(self.Avatar, 999)

    self.AvatarStroke = Instance.new("UIStroke")
    self.AvatarStroke.Thickness = 2
    self.AvatarStroke.Transparency = 0.2
    self.AvatarStroke.Parent = self.Avatar

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0, 8, 0, 64)
    nameLabel.Size = UDim2.new(1, -16, 0, 18)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = LocalPlayer.DisplayName
    nameLabel.TextColor3 = TEXT_COLOR
    nameLabel.TextSize = 13
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 4
    nameLabel.Parent = profileBox

    local divider = Instance.new("Frame")
    divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    divider.BackgroundTransparency = 0.92
    divider.BorderSizePixel = 0
    divider.Size = UDim2.new(1, -20, 0, 1)
    divider.Position = UDim2.new(0, 10, 0, 86)
    divider.ZIndex = 3
    divider.Parent = self.Sidebar

    self.TabList = Instance.new("ScrollingFrame")
    self.TabList.BackgroundTransparency = 1
    self.TabList.Position = UDim2.new(0, 8, 0, 96)
    self.TabList.Size = UDim2.new(1, -16, 1, -104)
    self.TabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.TabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.TabList.ScrollBarThickness = 3
    self.TabList.ScrollBarImageColor3 = THEMES[currentThemeKey].Accent
    self.TabList.ZIndex = 3
    self.TabList.Parent = self.Sidebar
    table.insert(self._scrollBars, self.TabList)

    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.Padding = UDim.new(0, 6)
    tabListLayout.Parent = self.TabList

    local watermark = Instance.new("TextLabel")
    watermark.BackgroundTransparency = 1
    watermark.Position = UDim2.new(0, 0, 1, -18)
    watermark.Size = UDim2.new(1, 0, 0, 16)
    watermark.Font = Enum.Font.GothamBold
    watermark.Text = "⚡ " .. BRAND .. " v" .. VERSION
    watermark.TextColor3 = SUBTEXT
    watermark.TextTransparency = 0.35
    watermark.TextSize = 10
    watermark.ZIndex = 3
    watermark.Parent = self.Sidebar

    self.ContentArea = Instance.new("Frame")
    self.ContentArea.BackgroundTransparency = 1
    self.ContentArea.Position = UDim2.new(0, 150, 0, 42)
    self.ContentArea.Size = UDim2.new(1, -150, 1, -42)
    self.ContentArea.ZIndex = 3
    self.ContentArea.Parent = self.Main

    self.ContentPadding = Instance.new("Frame")
    self.ContentPadding.BackgroundTransparency = 1
    self.ContentPadding.Position = UDim2.new(0, 20, 0, 18)
    self.ContentPadding.Size = UDim2.new(1, -40, 1, -36)
    self.ContentPadding.ZIndex = 3
    self.ContentPadding.Parent = self.ContentArea

    self:_setupDrag()
    self:_loadConfig()

    if self.Flags["_window_hotkey"] and type(self.Flags["_window_hotkey"]) == "string" then
        local ok, kc = pcall(function() return Enum.KeyCode[self.Flags["_window_hotkey"]] end)
        if ok and kc then self._hotkey = kc end
    end
    if self.Flags["_window_scale"] and type(self.Flags["_window_scale"]) == "number" then
        self:SetScale(self.Flags["_window_scale"])
    end

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
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
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
    self.ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
    self.ToggleBtn.Position = UDim2.new(1, -62, 1, -62)
    self.ToggleBtn.BackgroundColor3 = BG_PANEL
    self.ToggleBtn.AutoButtonColor = false
    self.ToggleBtn.Font = Enum.Font.GothamBold
    self.ToggleBtn.Text = "☰"
    self.ToggleBtn.TextColor3 = TEXT_COLOR
    self.ToggleBtn.TextSize = 20
    self.ToggleBtn.Parent = self.ScreenGui
    createCorner(self.ToggleBtn, 999)

    self.ToggleBtnStroke = Instance.new("UIStroke")
    self.ToggleBtnStroke.Transparency = 0.4
    self.ToggleBtnStroke.Parent = self.ToggleBtn

    self.ToggleBtn.MouseButton1Click:Connect(function() self:Toggle(not self.Enabled) end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local key = self._hotkey or DEFAULT_HOTKEY
        if input.KeyCode == key then self:Toggle(not self.Enabled) end
    end)
end

-- ============================================================
-- WINDOW METHODS
-- ============================================================
function Library:Toggle(enabled)
    self.Enabled = enabled
    if enabled then
        self.Main.Visible = true
        self.GlowHolder.Visible = true
        for _, l in ipairs(self.GlowLayers) do
            l.instance.BackgroundTransparency = l.config.transparency
        end
        self.Main.Size = UDim2.new(0, self.WindowSize.X, 0, 0)
        TweenService:Create(self.Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, self.WindowSize.X, 0, self.WindowSize.Y),
        }):Play()
        self:_syncGlowSize()
        for _, l in ipairs(self.GlowLayers) do
            TweenService:Create(l.instance, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                BackgroundTransparency = l.config.transparency,
            }):Play()
        end
    else
        local t = TweenService:Create(self.Main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, self.WindowSize.X, 0, 0),
        })
        t:Play()
        for _, l in ipairs(self.GlowLayers) do
            TweenService:Create(l.instance, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                BackgroundTransparency = 1,
            }):Play()
        end
        t.Completed:Connect(function()
            if not self.Enabled then
                self.Main.Visible = false
                self.GlowHolder.Visible = false
            end
        end)
    end
end

function Library:Destroy()
    if self.ScreenGui then self.ScreenGui:Destroy() end
    if self.ToggleBtn then self.ToggleBtn:Destroy() end
end

function Library:SetHotkey(key)
    if not key then return end
    if typeof(key) == "string" then
        local ok, kc = pcall(function() return Enum.KeyCode[key] end)
        if ok and kc then key = kc end
    end
    self._hotkey = key
    self:SetFlag("_window_hotkey", key.Name)
end

function Library:GetHotkey()
    return self._hotkey or DEFAULT_HOTKEY
end

function Library:Minimize()
    if self._minimized then
        self._minimized = false
        TweenService:Create(self.Main, TweenInfo.new(0.25), { Size = UDim2.new(0, self.WindowSize.X, 0, self.WindowSize.Y) }):Play()
        self:_syncGlowSize()
    else
        self._minimized = true
        TweenService:Create(self.Main, TweenInfo.new(0.25), { Size = UDim2.new(0, self.WindowSize.X, 0, 42) }):Play()
        self:_syncGlowSize()
    end
end

function Library:SetScale(n)
    n = math.clamp(n or 1, 0.5, 1.5)
    self._scale = n
    if self.Scale then self.Scale.Scale = n end
    self:SetFlag("_window_scale", n)
end

function Library:SetIcon(txt)
    if self.TitleIcon then self.TitleIcon.Text = tostring(txt or "⚡") end
end

function Library:SetAccentColor(color)
    if typeof(color) ~= "Color3" then return end
    THEMES[currentThemeKey].Accent = color
    THEMES[currentThemeKey].AccentLight = color:Lerp(Color3.new(1,1,1), 0.4)
    self:SetTheme(currentThemeKey)
end

function Library:Confirm(config)
    local popup = Instance.new("Frame")
    popup.Size = UDim2.new(0, 320, 0, 160)
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.Position = UDim2.new(0.5, 0, 0.5, 0)
    popup.BackgroundColor3 = BG_DARK
    popup.BorderSizePixel = 0
    popup.ZIndex = 5000
    popup.Parent = self.ScreenGui
    createCorner(popup, 14)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEMES[currentThemeKey].Accent
    stroke.Thickness = 2
    stroke.Parent = popup

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 16, 0, 14)
    title.Size = UDim2.new(1, -32, 0, 24)
    title.Font = Enum.Font.GothamBold
    title.Text = config.Title or "Подтверждение"
    title.TextColor3 = TEXT_COLOR
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 5001
    title.Parent = popup

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 16, 0, 44)
    body.Size = UDim2.new(1, -32, 0, 60)
    body.Font = Enum.Font.Gotham
    body.Text = config.Content or ""
    body.TextColor3 = SUBTEXT
    body.TextSize = 13
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextWrapped = true
    body.ZIndex = 5001
    body.Parent = popup

    local yes = Instance.new("TextButton")
    yes.Size = UDim2.new(0, 130, 0, 34)
    yes.Position = UDim2.new(0, 16, 1, -50)
    yes.BackgroundColor3 = THEMES[currentThemeKey].Accent
    yes.BorderSizePixel = 0
    yes.Font = Enum.Font.GothamBold
    yes.Text = config.YesText or "Да"
    yes.TextColor3 = Color3.fromRGB(255,255,255)
    yes.TextSize = 13
    yes.ZIndex = 5001
    yes.Parent = popup
    createCorner(yes, 8)

    local no = Instance.new("TextButton")
    no.Size = UDim2.new(0, 130, 0, 34)
    no.Position = UDim2.new(1, -146, 1, -50)
    no.BackgroundColor3 = BG_ITEM
    no.BorderSizePixel = 0
    no.Font = Enum.Font.GothamBold
    no.Text = config.NoText or "Отмена"
    no.TextColor3 = TEXT_COLOR
    no.TextSize = 13
    no.ZIndex = 5001
    no.Parent = popup
    createCorner(no, 8)

    local function close(result)
        if config.Callback then config.Callback(result) end
        popup:Destroy()
    end

    yes.MouseButton1Click:Connect(function() close(true) end)
    no.MouseButton1Click:Connect(function() close(false) end)

    -- appear
    popup.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 160),
    }):Play()
end

-- ============================================================
-- CONFIG
-- ============================================================
local function configPathFor(slot)
    if slot and slot ~= "default" and slot ~= "" then
        return CONFIG_FILE_PREFIX .. "_" .. slot .. ".json"
    end
    return CONFIG_FILE_PREFIX .. ".json"
end

function Library:_loadConfig(slot)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    local path = configPathFor(slot or self._configSlot)
    if not isfile(path) then return end
    local ok, content = pcall(readfile, path)
    if not ok or not content then return end
    local ok2, data = pcall(jsonDecode, content)
    if ok2 and type(data) == "table" then
        for k, v in pairs(data) do self.Flags[k] = v end
    end
end

function Library:_saveConfig(slot)
    if type(writefile) ~= "function" then return end
    local path = configPathFor(slot or self._configSlot)
    local ok, encoded = pcall(jsonEncode, self.Flags)
    if ok then pcall(writefile, path, encoded) end
end

function Library:SetFlag(flag, value)
    if not flag then return end
    self.Flags[flag] = value
    self._saveToken = self._saveToken + 1
    local token = self._saveToken
    task.delay(0.4, function()
        if self._saveToken == token then self:_saveConfig() end
    end)
end

function Library:SaveConfig(slot)
    self:_saveConfig(slot)
    self._configSlot = slot or self._configSlot
end

function Library:LoadConfig(slot)
    self._configSlot = slot or self._configSlot
    self:_loadConfig(slot)
end

function Library:GetConfigs()
    if type(getcustomasset) ~= "function" or type(listfiles) ~= "function" then
        return { "default" }
    end
    local list = {}
    pcall(function()
        for _, file in ipairs(listfiles("")) do
            local m = file:match(CONFIG_FILE_PREFIX .. "_(.-)%.json$")
            if m then table.insert(list, m) end
        end
    end)
    table.insert(list, 1, "default")
    return list
end

-- ============================================================
-- TABS
-- ============================================================
function Library:CreateTab(nameOrConfig)
    local self = self
    local name, icon
    if type(nameOrConfig) == "table" then
        name = nameOrConfig.Name or "Tab"
        icon = nameOrConfig.Icon
    else
        name = nameOrConfig or "Tab"
    end

    local key = name
    local idx = 2
    while self.Tabs[key] do key = name .. "_" .. idx; idx = idx + 1 end

    local tab = { Name = name, Key = key, Elements = {}, Parent = self }
    self.Tabs[key] = tab

    local btn = Instance.new("TextButton")
    btn.Name = key .. "Tab"
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = BG_ITEM
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 4
    btn.Parent = self.TabList
    createCorner(btn, 10)

    local textOffset = 12
    if icon then
        local iconInst
        if type(icon) == "string" and (icon:match("^rbxassetid://") or icon:match("^https?://")) then
            iconInst = Instance.new("ImageLabel")
            iconInst.Size = UDim2.new(0, 18, 0, 18)
            iconInst.Position = UDim2.new(0, 10, 0.5, -9)
            iconInst.BackgroundTransparency = 1
            iconInst.Image = icon
            iconInst.ZIndex = 5
            iconInst.Parent = btn
        else
            iconInst = Instance.new("TextLabel")
            iconInst.Size = UDim2.new(0, 20, 0, 20)
            iconInst.Position = UDim2.new(0, 10, 0.5, -10)
            iconInst.BackgroundTransparency = 1
            iconInst.Font = Enum.Font.GothamBold
            iconInst.Text = tostring(icon)
            iconInst.TextColor3 = Color3.fromRGB(255,255,255)
            iconInst.TextSize = 14
            iconInst.ZIndex = 5
            iconInst.Parent = btn
        end
        tab.Icon = iconInst
        textOffset = 36
    end

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, textOffset, 0, 0)
    label.Size = UDim2.new(1, -textOffset - 6, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = name
    label.TextColor3 = SUBTEXT
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 5
    label.Parent = btn
    tab.Label = label

    self.TabButtons[key] = btn

    local page = Instance.new("ScrollingFrame")
    page.BackgroundTransparency = 1
    page.Size = UDim2.new(1, 0, 1, 0)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEMES[currentThemeKey].Accent
    page.ClipsDescendants = true
    page.Visible = false
    page.ZIndex = 3
    page.Parent = self.ContentPadding
    table.insert(self._scrollBars, page)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingRight = UDim.new(0, 10)
    pagePad.PaddingBottom = UDim.new(0, 4)
    pagePad.Parent = page

    tab.Content = page

    btn.MouseButton1Click:Connect(function() self:SelectTab(key) end)
    if not self.CurrentTab then self:SelectTab(key) end

    tab.CreateButton = function(_, cfg) return self:_addButton(tab, cfg) end
    tab.CreateToggle = function(_, cfg) return self:_addToggle(tab, cfg) end
    tab.CreateSlider = function(_, cfg) return self:_addSlider(tab, cfg) end
    tab.CreateColorPicker = function(_, cfg) return self:_addColorPicker(tab, cfg) end
    tab.CreateDropdown = function(_, cfg) return self:_addDropdown(tab, cfg) end
    tab.CreateMultiDropdown = function(_, cfg) return self:_addMultiDropdown(tab, cfg) end
    tab.CreateInput = function(_, cfg) return self:_addInput(tab, cfg) end
    tab.CreateTextBox = function(_, cfg) return self:_addTextBox(tab, cfg) end
    tab.CreateLabel = function(_, cfg) return self:_addLabel(tab, cfg) end
    tab.CreateDivider = function(_, cfg) return self:_addDivider(tab, cfg) end
    tab.CreateDividerText = function(_, cfg) return self:_addDividerText(tab, cfg) end
    tab.CreateSection = function(_, cfg) return self:_addSection(tab, cfg) end
    tab.CreateKeybind = function(_, cfg) return self:_addKeybind(tab, cfg) end
    tab.CreateParagraph = function(_, cfg) return self:_addParagraph(tab, cfg) end
    tab.CreateProgressBar = function(_, cfg) return self:_addProgressBar(tab, cfg) end
    tab.CreateStepper = function(_, cfg) return self:_addStepper(tab, cfg) end
    tab.CreateRadioGroup = function(_, cfg) return self:_addRadioGroup(tab, cfg) end
    tab.CreateRow = function(_, cfg) return self:_addRow(tab, cfg) end

    return tab
end

function Library:SelectTab(key)
    if self.CurrentTab == key then return end
    self.CurrentTab = key
    local theme = THEMES[currentThemeKey]

    for k, tab in pairs(self.Tabs) do tab.Content.Visible = (k == key) end
    for k, btn in pairs(self.TabButtons) do
        local active = (k == key)
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and theme.Accent or BG_ITEM,
        }):Play()
        local tabData = self.Tabs[k]
        if tabData then
            if tabData.Label then
                TweenService:Create(tabData.Label, TweenInfo.new(0.15), {
                    TextColor3 = active and Color3.fromRGB(255,255,255) or SUBTEXT,
                }):Play()
            end
            if tabData.Icon then
                if tabData.Icon:IsA("ImageLabel") then
                    tabData.Icon.ImageColor3 = active and Color3.fromRGB(255,255,255) or SUBTEXT
                elseif tabData.Icon:IsA("TextLabel") then
                    tabData.Icon.TextColor3 = active and Color3.fromRGB(255,255,255) or SUBTEXT
                end
            end
        end
    end
end

-- ============================================================
-- ELEMENTS
-- ============================================================
function Library:_addButton(tab, config)
    local row = makeRowBase(tab.Content, config.Order, 40)
    row.Text = "   " .. (config.Name or "Button")
    addHover(row)

    if config.Badge then
        local badge = makeBadge(row, config.Badge, config.BadgeColor)
        badge.Position = UDim2.new(1, -50, 0.5, -7)
        row.Text = "   " .. (config.Name or "Button")
        row.Size = UDim2.new(1, 0, 0, 40)
    end

    if config.Keybind then
        local kb = Instance.new("TextLabel")
        kb.BackgroundColor3 = BG_HOVER
        kb.BorderSizePixel = 0
        kb.Position = UDim2.new(1, -60, 0.5, -11)
        kb.Size = UDim2.new(0, 50, 0, 22)
        kb.Font = Enum.Font.GothamBold
        kb.Text = config.Keybind.Name
        kb.TextColor3 = THEMES[currentThemeKey].Accent
        kb.TextSize = 11
        kb.ZIndex = 6
        kb.Parent = row
        createCorner(kb, 6)
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == config.Keybind then
                if config.Callback then config.Callback() end
            end
        end)
    end

    if config.Confirm then
        row.MouseButton1Click:Connect(function()
            self:Confirm({
                Title = config.Name or "Подтверждение",
                Content = config.ConfirmText or "Ты уверен?",
                Callback = function(yes)
                    if yes and config.Callback then config.Callback() end
                end,
            })
        end)
    else
        row.MouseButton1Click:Connect(function()
            if config.Callback then config.Callback() end
        end)
    end

    table.insert(self.Elements, { Type = "Button", Instance = row })
    return row
end

function Library:_addToggle(tab, config)
    local self = self
    local flag = config.Flag
    local state
    if flag and self.Flags[flag] ~= nil then state = self.Flags[flag]
    else state = config.CurrentValue end
    state = state and true or false

    local row = makeRowBase(tab.Content, config.Order, config.Description and 50 or 40)
    row.Text = ""
    addHover(row)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0, 12, 0, config.Description and 6 or 0)
    nameLabel.Size = UDim2.new(1, -70, 0, config.Description and 18 or 40)
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.Text = config.Name or "Toggle"
    nameLabel.TextColor3 = TEXT_COLOR
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 5
    nameLabel.Parent = row

    if config.Description then
        local descLabel = Instance.new("TextLabel")
        descLabel.BackgroundTransparency = 1
        descLabel.Position = UDim2.new(0, 12, 0, 24)
        descLabel.Size = UDim2.new(1, -70, 0, 16)
        descLabel.Font = Enum.Font.Gotham
        descLabel.Text = config.Description
        descLabel.TextColor3 = SUBTEXT
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.ZIndex = 5
        descLabel.Parent = row
    end

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 40, 0, 20)
    track.Position = UDim2.new(1, -50, 0.5, -10)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    track.BorderSizePixel = 0
    track.ZIndex = 4
    track.Parent = row
    createCorner(track, 999)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track
    createCorner(knob, 999)

    local function updateVisual()
        local theme = THEMES[currentThemeKey]
        if state then
            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = theme.Accent }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.new(1, -18, 0.5, -8) }):Play()
        else
            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(60,60,70) }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.new(0, 2, 0.5, -8) }):Play()
        end
    end
    updateVisual()

    row.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        self:SetFlag(flag, state)
        if config.Callback then config.Callback(state) end
    end)

    -- AutoExecute
    if config.AutoExecute and state and config.Callback then
        task.defer(function() config.Callback(true) end)
    elseif flag and self.Flags[flag] ~= nil and config.Callback then
        task.defer(function() config.Callback(state) end)
    end

    local obj = {
        Instance = row,
        Get = function() return state end,
        Set = function(v)
            state = v and true or false
            updateVisual()
            self:SetFlag(flag, state)
            if config.Callback then config.Callback(state) end
        end,
        UpdateTheme = updateVisual,
    }
    table.insert(self.Elements, { Type = "Toggle", Instance = row, UpdateTheme = updateVisual })
    return obj
end

function Library:_addSlider(tab, config)
    local self = self
    local min = config.Min or 0
    local max = config.Max or 100
    local increment = config.Increment or 1
    local suffix = config.Suffix or ""
    local flag = config.Flag
    local value
    if flag and type(self.Flags[flag]) == "number" then value = self.Flags[flag]
    else value = config.CurrentValue or min end

    local row = Instance.new("Frame")
    row.BackgroundColor3 = BG_ITEM
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 44)
    row.LayoutOrder = config.Order or 0
    row.ZIndex = 4
    row.Parent = tab.Content
    createCorner(row, 10)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -90, 0, 22)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "Slider"
    label.TextColor3 = TEXT_COLOR
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -80, 0, 0)
    valueLabel.Size = UDim2.new(0, 68, 0, 22)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(value) .. suffix
    valueLabel.TextColor3 = THEMES[currentThemeKey].Accent
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 5
    valueLabel.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    track.BorderSizePixel = 0
    track.ZIndex = 5
    track.Parent = row
    createCorner(track, 999)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = THEMES[currentThemeKey].Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    fill.Parent = track
    createCorner(fill, 999)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 7
    knob.Parent = track
    createCorner(knob, 999)

    local function updateVisual()
        local alpha = (max - min > 0) and (value - min) / (max - min) or 0
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(value) .. suffix
        valueLabel.TextColor3 = THEMES[currentThemeKey].Accent
    end
    updateVisual()

    local dragging = false
    local function handleInput(input)
        local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor((min + alpha * (max - min)) / increment + 0.5) * increment
        updateVisual()
        self:SetFlag(flag, value)
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

    if flag and self.Flags[flag] ~= nil and config.Callback then
        task.defer(function() config.Callback(value) end)
    end

    local obj = {
        Instance = row,
        Get = function() return value end,
        Set = function(v)
            value = math.clamp(v, min, max)
            updateVisual()
            self:SetFlag(flag, value)
            if config.Callback then config.Callback(value) end
        end,
    }
    table.insert(self.Elements, { Type = "Slider", Instance = row })
    return obj
end

function Library:_addDropdown(tab, config)
    local self = self
    local flag = config.Flag
    local options = config.Options or {}
    local current
    if flag and self.Flags[flag] ~= nil then current = self.Flags[flag]
    else current = config.CurrentOption or options[1] end

    local open = false
    local row = makeRowBase(tab.Content, config.Order, 40)
    row.Text = "   " .. (config.Name or "Dropdown")
    addHover(row)

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -220, 0, 0)
    valueLabel.Size = UDim2.new(0, 180, 1, 0)
    valueLabel.Font = Enum.Font.GothamMedium
    valueLabel.Text = tostring(current)
    valueLabel.TextColor3 = SUBTEXT
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 4
    valueLabel.Parent = row

    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Position = UDim2.new(1, -30, 0, 0)
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Font = Enum.Font.GothamBold
    arrow.Text = "▼"
    arrow.TextColor3 = SUBTEXT
    arrow.TextSize = 10
    arrow.ZIndex = 4
    arrow.Parent = row

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = BG_PANEL
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.ClipsDescendants = true
    holder.Visible = false
    holder.LayoutOrder = (config.Order or 0) + 0.5
    holder.ZIndex = 4
    holder.Parent = tab.Content
    createCorner(holder, 10)

    local holderLayout = Instance.new("UIListLayout")
    holderLayout.Padding = UDim.new(0, 4)
    holderLayout.Parent = holder

    local holderPad = Instance.new("UIPadding")
    holderPad.PaddingTop = UDim.new(0, 8)
    holderPad.PaddingBottom = UDim.new(0, 8)
    holderPad.PaddingLeft = UDim.new(0, 8)
    holderPad.PaddingRight = UDim.new(0, 8)
    holderPad.Parent = holder

    local optionButtons = {}

    local function updateOptionVisuals()
        for _, data in ipairs(optionButtons) do
            local isSelected = (data.Name == current)
            TweenService:Create(data.Btn, TweenInfo.new(0.12), {
                BackgroundColor3 = isSelected and THEMES[currentThemeKey].Accent or BG_ITEM,
                TextColor3 = isSelected and Color3.fromRGB(255,255,255) or TEXT_COLOR,
            }):Play()
        end
        valueLabel.Text = tostring(current)
    end

    local function setOpen(v)
        open = v
        if open then
            holder.Visible = true
            local targetH = #options * 32 + math.max(0, #options - 1) * 4 + 16
            TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, targetH),
            }):Play()
            TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = 180 }):Play()
        else
            local t = TweenService:Create(holder, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0),
            })
            t:Play()
            t.Completed:Connect(function() if not open then holder.Visible = false end end)
            TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = 0 }):Play()
        end
    end

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 32)
        optBtn.BackgroundColor3 = BG_ITEM
        optBtn.AutoButtonColor = false
        optBtn.BorderSizePixel = 0
        optBtn.Font = Enum.Font.GothamMedium
        optBtn.Text = "   " .. tostring(opt)
        optBtn.TextColor3 = TEXT_COLOR
        optBtn.TextSize = 12
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.LayoutOrder = i
        optBtn.ZIndex = 5
        optBtn.Parent = holder
        createCorner(optBtn, 8)

        optBtn.MouseButton1Click:Connect(function()
            current = opt
            updateOptionVisuals()
            setOpen(false)
            self:SetFlag(flag, current)
            if config.Callback then config.Callback(current) end
        end)

        table.insert(optionButtons, { Name = opt, Btn = optBtn })
    end
    updateOptionVisuals()

    row.MouseButton1Click:Connect(function() setOpen(not open) end)

    if flag and self.Flags[flag] ~= nil and config.Callback then
        task.defer(function() config.Callback(current) end)
    end

    local obj = {
        Instance = row,
        Get = function() return current end,
        Set = function(v)
            current = v
            updateOptionVisuals()
            self:SetFlag(flag, current)
            if config.Callback then config.Callback(current) end
        end,
        UpdateTheme = updateOptionVisuals,
    }
    table.insert(self.Elements, { Type = "Dropdown", Instance = row, UpdateTheme = updateOptionVisuals })
    return obj
end

function Library:_addMultiDropdown(tab, config)
    local self = self
    local flag = config.Flag
    local options = config.Options or {}
    local selected = {}
    if flag and type(self.Flags[flag]) == "table" then
        for _, v in ipairs(self.Flags[flag]) do selected[v] = true end
    elseif config.Default then
        for _, v in ipairs(config.Default) do selected[v] = true end
    end

    local open = false
    local row = makeRowBase(tab.Content, config.Order, 40)
    row.Text = "   " .. (config.Name or "MultiDropdown")
    addHover(row)

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -220, 0, 0)
    valueLabel.Size = UDim2.new(0, 180, 1, 0)
    valueLabel.Font = Enum.Font.GothamMedium
    valueLabel.Text = ""
    valueLabel.TextColor3 = SUBTEXT
    valueLabel.TextSize = 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    valueLabel.ZIndex = 4
    valueLabel.Parent = row

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = BG_PANEL
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.ClipsDescendants = true
    holder.Visible = false
    holder.LayoutOrder = (config.Order or 0) + 0.5
    holder.ZIndex = 4
    holder.Parent = tab.Content
    createCorner(holder, 10)

    local holderLayout = Instance.new("UIListLayout")
    holderLayout.Padding = UDim.new(0, 4)
    holderLayout.Parent = holder

    local holderPad = Instance.new("UIPadding")
    holderPad.PaddingTop = UDim.new(0, 8)
    holderPad.PaddingBottom = UDim.new(0, 8)
    holderPad.PaddingLeft = UDim.new(0, 8)
    holderPad.PaddingRight = UDim.new(0, 8)
    holderPad.Parent = holder

    local optionButtons = {}

    local function getList()
        local t = {}
        for _, o in ipairs(options) do if selected[o] then table.insert(t, o) end end
        return t
    end

    local function update()
        local list = getList()
        if #list == 0 then valueLabel.Text = "(пусто)"
        else valueLabel.Text = table.concat(list, ", ") end
        for _, data in ipairs(optionButtons) do
            local isOn = selected[data.Name]
            TweenService:Create(data.Btn, TweenInfo.new(0.12), {
                BackgroundColor3 = isOn and THEMES[currentThemeKey].Accent or BG_ITEM,
                TextColor3 = isOn and Color3.fromRGB(255,255,255) or TEXT_COLOR,
            }):Play()
        end
    end

    local function setOpen(v)
        open = v
        if open then
            holder.Visible = true
            local targetH = #options * 32 + math.max(0, #options - 1) * 4 + 16
            TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, targetH),
            }):Play()
        else
            local t = TweenService:Create(holder, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0),
            })
            t:Play()
            t.Completed:Connect(function() if not open then holder.Visible = false end end)
        end
    end

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 32)
        optBtn.BackgroundColor3 = BG_ITEM
        optBtn.AutoButtonColor = false
        optBtn.BorderSizePixel = 0
        optBtn.Font = Enum.Font.GothamMedium
        optBtn.Text = "   " .. tostring(opt)
        optBtn.TextColor3 = TEXT_COLOR
        optBtn.TextSize = 12
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.LayoutOrder = i
        optBtn.ZIndex = 5
        optBtn.Parent = holder
        createCorner(optBtn, 8)

        optBtn.MouseButton1Click:Connect(function()
            selected[opt] = not selected[opt] or nil
            update()
            self:SetFlag(flag, getList())
            if config.Callback then config.Callback(getList()) end
        end)

        table.insert(optionButtons, { Name = opt, Btn = optBtn })
    end
    update()

    row.MouseButton1Click:Connect(function() setOpen(not open) end)

    if flag and self.Flags[flag] ~= nil and config.Callback then
        task.defer(function() config.Callback(getList()) end)
    end

    local obj = {
        Instance = row,
        Get = function() return getList() end,
        Set = function(list)
            selected = {}
            for _, v in ipairs(list) do selected[v] = true end
            update()
            self:SetFlag(flag, getList())
            if config.Callback then config.Callback(getList()) end
        end,
        UpdateTheme = update,
    }
    table.insert(self.Elements, { Type = "MultiDropdown", Instance = row, UpdateTheme = update })
    return obj
end

function Library:_addInput(tab, config)
    local self = self
    local flag = config.Flag
    local initial
    if flag and type(self.Flags[flag]) == "string" then initial = self.Flags[flag]
    else initial = config.CurrentValue or config.Placeholder or "" end

    local row = makeRowBase(tab.Content, config.Order, 40)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(0, 130, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "Input"
    label.TextColor3 = TEXT_COLOR
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 4
    label.Parent = row

    local box = Instance.new("TextBox")
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    box.BorderSizePixel = 0
    box.Position = UDim2.new(1, -240, 0.5, -13)
    box.Size = UDim2.new(0, 228, 0, 26)
    box.Font = Enum.Font.Gotham
    box.PlaceholderText = config.Placeholder or "введи..."
    box.Text = initial
    box.TextColor3 = TEXT_COLOR
    box.PlaceholderColor3 = SUBTEXT
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.ZIndex = 4
    box.Parent = row
    createCorner(box, 8)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.Parent = box

    box.FocusLost:Connect(function()
        self:SetFlag(flag, box.Text)
        if config.Callback then config.Callback(box.Text) end
    end)

    local obj = {
        Instance = row,
        Get = function() return box.Text end,
        Set = function(v) box.Text = tostring(v) end,
    }
    table.insert(self.Elements, { Type = "Input", Instance = row })
    return obj
end

function Library:_addTextBox(tab, config)
    local self = self
    local flag = config.Flag
    local lines = config.Lines or 5
    local initial
    if flag and type(self.Flags[flag]) == "string" then initial = self.Flags[flag]
    else initial = config.CurrentValue or "" end

    local wrap = Instance.new("Frame")
    wrap.BackgroundColor3 = BG_ITEM
    wrap.BorderSizePixel = 0
    wrap.Size = UDim2.new(1, 0, 0, 26 + lines * 18 + 12)
    wrap.LayoutOrder = config.Order or 0
    wrap.ZIndex = 4
    wrap.Parent = tab.Content
    createCorner(wrap, 10)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 4)
    label.Size = UDim2.new(1, -24, 0, 20)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "TextBox"
    label.TextColor3 = TEXT_COLOR
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = wrap

    local box = Instance.new("TextBox")
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    box.BorderSizePixel = 0
    box.Position = UDim2.new(0, 12, 0, 26)
    box.Size = UDim2.new(1, -24, 0, lines * 18)
    box.Font = Enum.Font.Gotham
    box.PlaceholderText = config.Placeholder or ""
    box.Text = initial
    box.TextColor3 = TEXT_COLOR
    box.PlaceholderColor3 = SUBTEXT
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.TextWrapped = true
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.MultiLine = true
    box.ZIndex = 5
    box.Parent = wrap
    createCorner(box, 6)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingTop = UDim.new(0, 4)
    pad.Parent = box

    box.FocusLost:Connect(function()
        self:SetFlag(flag, box.Text)
        if config.Callback then config.Callback(box.Text) end
    end)

    local obj = {
        Instance = wrap,
        Get = function() return box.Text end,
        Set = function(v) box.Text = tostring(v) end,
    }
    table.insert(self.Elements, { Type = "TextBox", Instance = wrap })
    return obj
end

function Library:_addLabel(tab, config)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 22)
    label.LayoutOrder = config.Order or 0
    label.Font = Enum.Font.Gotham
    label.Text = config.Text or "Label"
    label.TextColor3 = SUBTEXT
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.ZIndex = 4
    label.Parent = tab.Content
    return label
end

function Library:_addDivider(tab, config)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 9)
    wrap.LayoutOrder = (config and config.Order) or 0
    wrap.ZIndex = 4
    wrap.Parent = tab.Content

    local divider = Instance.new("Frame")
    divider.BackgroundColor3 = Color3.fromRGB(255,255,255)
    divider.BackgroundTransparency = 0.9
    divider.BorderSizePixel = 0
    divider.AnchorPoint = Vector2.new(0.5, 0.5)
    divider.Position = UDim2.new(0.5, 0, 0.5, 0)
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.ZIndex = 4
    divider.Parent = wrap

    return wrap
end

function Library:_addDividerText(tab, config)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 20)
    wrap.LayoutOrder = config.Order or 0
    wrap.ZIndex = 4
    wrap.Parent = tab.Content

    local left = Instance.new("Frame")
    left.BackgroundColor3 = Color3.fromRGB(255,255,255)
    left.BackgroundTransparency = 0.9
    left.BorderSizePixel = 0
    left.Position = UDim2.new(0, 0, 0.5, 0)
    left.Size = UDim2.new(0.4, 0, 0, 1)
    left.ZIndex = 4
    left.Parent = wrap

    local right = Instance.new("Frame")
    right.BackgroundColor3 = Color3.fromRGB(255,255,255)
    right.BackgroundTransparency = 0.9
    right.BorderSizePixel = 0
    right.Position = UDim2.new(0.6, 0, 0.5, 0)
    right.Size = UDim2.new(0.4, 0, 0, 1)
    right.ZIndex = 4
    right.Parent = wrap

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.new(0.4, 0, 0, 0)
    text.Size = UDim2.new(0.2, 0, 1, 0)
    text.Font = Enum.Font.GothamBold
    text.Text = config.Text or ""
    text.TextColor3 = SUBTEXT
    text.TextSize = 11
    text.ZIndex = 5
    text.Parent = wrap

    return wrap
end

function Library:_addSection(tab, config)
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 26)
    wrap.LayoutOrder = config.Order or 0
    wrap.ZIndex = 4
    wrap.Parent = tab.Content

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = (config.Text or "Section"):upper()
    label.TextColor3 = SUBTEXT
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 4
    label.Parent = wrap

    local line = Instance.new("Frame")
    line.BackgroundColor3 = Color3.fromRGB(255,255,255)
    line.BackgroundTransparency = 0.9
    line.BorderSizePixel = 0
    line.Position = UDim2.new(0, 0, 1, -1)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.ZIndex = 4
    line.Parent = wrap

    return wrap
end

function Library:_addKeybind(tab, config)
    local self = self
    local flag = config.Flag

    local function decodeKey(v)
        if typeof(v) == "EnumItem" then return v end
        if type(v) == "string" and v ~= "" and v ~= "null" then
            local ok, kc = pcall(function() return Enum.KeyCode[v] end)
            if ok and kc then return kc end
        end
        return nil
    end

    local current
    if flag and self.Flags[flag] ~= nil then current = decodeKey(self.Flags[flag]) end
    if not current then current = config.CurrentKeybind or Enum.KeyCode.RightShift end

    local listening = false
    local row = makeRowBase(tab.Content, config.Order, 40)
    row.Text = "   " .. (config.Name or "Keybind")
    addHover(row)

    local keyBadge = Instance.new("TextButton")
    keyBadge.Size = UDim2.new(0, 84, 0, 26)
    keyBadge.Position = UDim2.new(1, -94, 0.5, -13)
    keyBadge.BackgroundColor3 = BG_HOVER
    keyBadge.AutoButtonColor = false
    keyBadge.Font = Enum.Font.GothamBold
    keyBadge.Text = current and current.Name or "None"
    keyBadge.TextColor3 = TEXT_COLOR
    keyBadge.TextSize = 12
    keyBadge.ZIndex = 5
    keyBadge.Parent = row
    createCorner(keyBadge, 8)

    local badgeStroke = Instance.new("UIStroke")
    badgeStroke.Color = THEMES[currentThemeKey].Accent
    badgeStroke.Transparency = 1
    badgeStroke.Thickness = 1.5
    badgeStroke.Parent = keyBadge

    local listenConn

    local function refresh()
        keyBadge.Text = listening and "..." or (current and current.Name or "None")
        badgeStroke.Transparency = listening and 0.2 or 1
    end

    local function stopListen()
        listening = false
        if listenConn then listenConn:Disconnect(); listenConn = nil end
        refresh()
    end

    local function startListen()
        if listening then stopListen() return end
        listening = true
        refresh()
        listenConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Escape then stopListen() return end
            current = input.KeyCode
            stopListen()
            self:SetFlag(flag, current.Name)
            if config.Callback then config.Callback(current) end
        end)
    end

    keyBadge.MouseButton1Click:Connect(startListen)
    refresh()

    local obj = {
        Instance = row,
        Get = function() return current end,
        Set = function(kc)
            current = decodeKey(kc) or kc
            refresh()
            self:SetFlag(flag, current and current.Name or nil)
            if config.Callback then config.Callback(current) end
        end,
        UpdateTheme = refresh,
    }
    table.insert(self.Elements, { Type = "Keybind", Instance = row, UpdateTheme = refresh })
    return obj
end

function Library:_addParagraph(tab, config)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = BG_ITEM
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, 0, 0, 0)
    card.LayoutOrder = config.Order or 0
    card.ZIndex = 4
    card.Parent = tab.Content
    createCorner(card, 10)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = card

    local innerLayout = Instance.new("UIListLayout")
    innerLayout.Padding = UDim.new(0, 4)
    innerLayout.Parent = card

    if config.Title then
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.AutomaticSize = Enum.AutomaticSize.Y
        title.Size = UDim2.new(1, 0, 0, 0)
        title.Font = Enum.Font.GothamBold
        title.Text = config.Title
        title.TextColor3 = TEXT_COLOR
        title.TextSize = 13
        title.TextWrapped = true
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.LayoutOrder = 1
        title.ZIndex = 5
        title.Parent = card
    end

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Font = Enum.Font.Gotham
    body.Text = config.Content or config.Text or ""
    body.TextColor3 = SUBTEXT
    body.TextSize = 12
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.LayoutOrder = 2
    body.ZIndex = 5
    body.Parent = card

    return card
end

function Library:_addProgressBar(tab, config)
    local self = self
    local min = config.Min or 0
    local max = config.Max or 100
    local value = config.CurrentValue or min

    local row = Instance.new("Frame")
    row.BackgroundColor3 = BG_ITEM
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 44)
    row.LayoutOrder = config.Order or 0
    row.ZIndex = 4
    row.Parent = tab.Content
    createCorner(row, 10)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -90, 0, 22)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "Progress"
    label.TextColor3 = TEXT_COLOR
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -80, 0, 0)
    valueLabel.Size = UDim2.new(0, 68, 0, 22)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = string.format("%d%%", math.floor((value - min) / (max - min) * 100))
    valueLabel.TextColor3 = THEMES[currentThemeKey].Accent
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 5
    valueLabel.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 8)
    track.Position = UDim2.new(0, 12, 0, 28)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    track.BorderSizePixel = 0
    track.ZIndex = 5
    track.Parent = row
    createCorner(track, 999)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = THEMES[currentThemeKey].Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    fill.Parent = track
    createCorner(fill, 999)

    local function update()
        local alpha = (max - min > 0) and math.clamp((value - min) / (max - min), 0, 1) or 0
        TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.new(alpha, 0, 1, 0) }):Play()
        valueLabel.Text = string.format("%d%%", math.floor(alpha * 100))
    end
    update()

    local obj = {
        Instance = row,
        Get = function() return value end,
        Set = function(v)
            value = math.clamp(v, min, max)
            update()
        end,
    }
    table.insert(self.Elements, { Type = "ProgressBar", Instance = row })
    return obj
end

function Library:_addStepper(tab, config)
    local self = self
    local min = config.Min or 0
    local max = config.Max or 10
    local step = config.Increment or 1
    local flag = config.Flag
    local value
    if flag and type(self.Flags[flag]) == "number" then value = self.Flags[flag]
    else value = config.CurrentValue or min end

    local row = makeRowBase(tab.Content, config.Order, 40)
    addHover(row)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -170, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "Stepper"
    label.TextColor3 = TEXT_COLOR
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = row

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 28, 0, 26)
    minus.Position = UDim2.new(1, -120, 0.5, -13)
    minus.BackgroundColor3 = BG_HOVER
    minus.BorderSizePixel = 0
    minus.Font = Enum.Font.GothamBold
    minus.Text = "−"
    minus.TextColor3 = TEXT_COLOR
    minus.TextSize = 16
    minus.ZIndex = 5
    minus.Parent = row
    createCorner(minus, 6)

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1
    valLbl.Position = UDim2.new(1, -90, 0, 0)
    valLbl.Size = UDim2.new(0, 40, 1, 0)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.Text = tostring(value)
    valLbl.TextColor3 = THEMES[currentThemeKey].Accent
    valLbl.TextSize = 13
    valLbl.ZIndex = 5
    valLbl.Parent = row

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 28, 0, 26)
    plus.Position = UDim2.new(1, -46, 0.5, -13)
    plus.BackgroundColor3 = BG_HOVER
    plus.BorderSizePixel = 0
    plus.Font = Enum.Font.GothamBold
    plus.Text = "+"
    plus.TextColor3 = TEXT_COLOR
    plus.TextSize = 16
    plus.ZIndex = 5
    plus.Parent = row
    createCorner(plus, 6)

    local function update()
        valLbl.Text = tostring(value)
        valLbl.TextColor3 = THEMES[currentThemeKey].Accent
    end

    minus.MouseButton1Click:Connect(function()
        value = math.max(min, value - step)
        update()
        self:SetFlag(flag, value)
        if config.Callback then config.Callback(value) end
    end)
    plus.MouseButton1Click:Connect(function()
        value = math.min(max, value + step)
        update()
        self:SetFlag(flag, value)
        if config.Callback then config.Callback(value) end
    end)

    if flag and self.Flags[flag] ~= nil and config.Callback then
        task.defer(function() config.Callback(value) end)
    end

    local obj = {
        Instance = row,
        Get = function() return value end,
        Set = function(v)
            value = math.clamp(v, min, max)
            update()
            self:SetFlag(flag, value)
            if config.Callback then config.Callback(value) end
        end,
    }
    table.insert(self.Elements, { Type = "Stepper", Instance = row })
    return obj
end

function Library:_addRadioGroup(tab, config)
    local self = self
    local flag = config.Flag
    local options = config.Options or {}
    local current
    if flag and self.Flags[flag] ~= nil then current = self.Flags[flag]
    else current = config.CurrentOption or options[1] end

    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, 0, 0, 60)
    wrap.LayoutOrder = config.Order or 0
    wrap.ZIndex = 4
    wrap.Parent = tab.Content

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -24, 0, 20)
    label.Font = Enum.Font.GothamMedium
    label.Text = config.Name or "RadioGroup"
    label.TextColor3 = TEXT_COLOR
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = wrap

    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Position = UDim2.new(0, 0, 0, 24)
    row.Size = UDim2.new(1, 0, 0, 32)
    row.ZIndex = 5
    row.Parent = wrap

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.Parent = row

    local buttons = {}

    local function update()
        for _, data in ipairs(buttons) do
            local on = (data.Name == current)
            TweenService:Create(data.Btn, TweenInfo.new(0.15), {
                BackgroundColor3 = on and THEMES[currentThemeKey].Accent or BG_ITEM,
                TextColor3 = on and Color3.fromRGB(255,255,255) or TEXT_COLOR,
            }):Play()
        end
    end

    for _, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 80, 1, 0)
        btn.BackgroundColor3 = BG_ITEM
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.Text = tostring(opt)
        btn.TextColor3 = TEXT_COLOR
        btn.TextSize = 12
        btn.ZIndex = 5
        btn.Parent = row
        createCorner(btn, 8)

        btn.MouseButton1Click:Connect(function()
            current = opt
            update()
            self:SetFlag(flag, current)
            if config.Callback then config.Callback(current) end
        end)
        table.insert(buttons, { Name = opt, Btn = btn })
    end
    update()

    if flag and self.Flags[flag] ~= nil and config.Callback then
        task.defer(function() config.Callback(current) end)
    end

    local obj = {
        Instance = wrap,
        Get = function() return current end,
        Set = function(v)
            current = v
            update()
            self:SetFlag(flag, current)
            if config.Callback then config.Callback(current) end
        end,
        UpdateTheme = update,
    }
    table.insert(self.Elements, { Type = "RadioGroup", Instance = wrap, UpdateTheme = update })
    return obj
end

function Library:_addRow(tab, config)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 40)
    row.LayoutOrder = config.Order or 0
    row.ZIndex = 4
    row.Parent = tab.Content

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.Parent = row

    return row
end

function Library:_addColorPicker(tab, config)
    local self = self
    local flag = config.Flag
    local current
    if flag and typeof(self.Flags[flag]) == "Color3" then current = self.Flags[flag]
    else current = config.CurrentValue or THEMES[currentThemeKey].Accent end
    local open = false
    local h, s, v = Color3.toHSV(current)

    local row = makeRowBase(tab.Content, config.Order, 40)
    row.Text = "   " .. (config.Name or "Color")
    addHover(row)

    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 22, 0, 22)
    preview.Position = UDim2.new(1, -32, 0.5, -11)
    preview.BackgroundColor3 = current
    preview.BorderSizePixel = 0
    preview.ZIndex = 5
    preview.Parent = row
    createCorner(preview, 8)

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = BG_PANEL
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.ClipsDescendants = true
    holder.Visible = false
    holder.LayoutOrder = (config.Order or 0) + 0.5
    holder.ZIndex = 4
    holder.Parent = tab.Content
    createCorner(holder, 10)

    local holderPad = Instance.new("UIPadding")
    holderPad.PaddingTop = UDim.new(0, 10)
    holderPad.PaddingBottom = UDim.new(0, 10)
    holderPad.PaddingLeft = UDim.new(0, 10)
    holderPad.PaddingRight = UDim.new(0, 10)
    holderPad.Parent = holder

    local svField = Instance.new("ImageLabel")
    svField.Size = UDim2.new(1, 0, 0, 100)
    svField.BackgroundColor3 = Color3.fromRGB(255,255,255)
    svField.BorderSizePixel = 0
    svField.ZIndex = 5
    svField.Parent = holder
    createCorner(svField, 8)

    local svGrad = Instance.new("UIGradient")
    svGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
    })
    svGrad.Parent = svField

    local svDark = Instance.new("Frame")
    svDark.Size = UDim2.new(1, 0, 1, 0)
    svDark.BackgroundColor3 = Color3.fromRGB(0,0,0)
    svDark.BorderSizePixel = 0
    svDark.ZIndex = 6
    svDark.Parent = svField
    createCorner(svDark, 8)

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
    svMarkerStroke.Color = Color3.fromRGB(255,255,255)
    svMarkerStroke.Parent = svMarker
    createCorner(svMarker, 999)

    local hueBar = Instance.new("ImageLabel")
    hueBar.Size = UDim2.new(1, 0, 0, 12)
    hueBar.Position = UDim2.new(0, 0, 0, 110)
    hueBar.BackgroundColor3 = Color3.fromRGB(255,255,255)
    hueBar.BorderSizePixel = 0
    hueBar.ZIndex = 5
    hueBar.Parent = holder
    createCorner(hueBar, 999)

    local hueGrad = Instance.new("UIGradient")
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
    })
    hueGrad.Parent = hueBar

    local hueMarker = Instance.new("Frame")
    hueMarker.Size = UDim2.new(0, 12, 0, 12)
    hueMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    hueMarker.BackgroundColor3 = Color3.fromRGB(255,255,255)
    hueMarker.ZIndex = 8
    hueMarker.Parent = hueBar
    createCorner(hueMarker, 999)

    local hueMarkerStroke = Instance.new("UIStroke")
    hueMarkerStroke.Thickness = 2
    hueMarkerStroke.Color = Color3.fromRGB(0,0,0)
    hueMarkerStroke.Transparency = 0.6
    hueMarkerStroke.Parent = hueMarker

    -- alpha slider (опционально)
    local alphaValue = 1
    local alphaBar, alphaFill
    if config.WithAlpha then
        local alphaLabel = Instance.new("TextLabel")
        alphaLabel.BackgroundTransparency = 1
        alphaLabel.Position = UDim2.new(0, 0, 0, 128)
        alphaLabel.Size = UDim2.new(0, 40, 0, 12)
        alphaLabel.Font = Enum.Font.Gotham
        alphaLabel.Text = "Alpha"
        alphaLabel.TextColor3 = SUBTEXT
        alphaLabel.TextSize = 10
        alphaLabel.ZIndex = 5
        alphaLabel.Parent = holder

        alphaBar = Instance.new("Frame")
        alphaBar.Size = UDim2.new(1, -50, 0, 10)
        alphaBar.Position = UDim2.new(0, 50, 0, 128)
        alphaBar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        alphaBar.BorderSizePixel = 0
        alphaBar.ZIndex = 5
        alphaBar.Parent = holder
        createCorner(alphaBar, 999)

        alphaFill = Instance.new("Frame")
        alphaFill.Size = UDim2.new(1, 0, 1, 0)
        alphaFill.BackgroundColor3 = current
        alphaFill.BorderSizePixel = 0
        alphaFill.ZIndex = 6
        alphaFill.Parent = alphaBar
        createCorner(alphaFill, 999)
    end

    local hexBox = Instance.new("TextBox")
    hexBox.Size = UDim2.new(1, 0, 0, 24)
    hexBox.Position = UDim2.new(0, 0, 0, config.WithAlpha and 148 or 130)
    hexBox.BackgroundColor3 = BG_ITEM
    hexBox.BorderSizePixel = 0
    hexBox.Font = Enum.Font.GothamMedium
    hexBox.Text = "#000000"
    hexBox.TextColor3 = TEXT_COLOR
    hexBox.TextSize = 12
    hexBox.ClearTextOnFocus = false
    hexBox.ZIndex = 5
    hexBox.Parent = holder
    createCorner(hexBox, 8)

    local hexPad = Instance.new("UIPadding")
    hexPad.PaddingLeft = UDim.new(0, 8)
    hexPad.Parent = hexBox

    local function toHex(c)
        return string.format("#%02X%02X%02X",
            math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
    end
    local function fromHex(str)
        str = str:gsub("#","")
        if #str ~= 6 then return nil end
        local r = tonumber(str:sub(1,2), 16)
        local g = tonumber(str:sub(3,4), 16)
        local b = tonumber(str:sub(5,6), 16)
        if not (r and g and b) then return nil end
        return Color3.fromRGB(r, g, b)
    end

    local updating = false
    local function refresh()
        updating = true
        svGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
        })
        svMarker.Position = UDim2.new(s, 0, 1 - v, 0)
        hueMarker.Position = UDim2.new(h, 0, 0.5, 0)
        preview.BackgroundColor3 = current
        preview.BackgroundTransparency = config.WithAlpha and (1 - alphaValue) or 0
        hexBox.Text = toHex(current)
        if alphaFill then alphaFill.BackgroundColor3 = current end
        updating = false
    end
    local function apply()
        current = Color3.fromHSV(h, s, v)
        refresh()
        self:SetFlag(flag, current)
        if config.Callback then config.Callback(current, config.WithAlpha and alphaValue or 1) end
    end

    local dsv = false
    local function handleSV(input)
        s = math.clamp((input.Position.X - svField.AbsolutePosition.X) / svField.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((input.Position.Y - svField.AbsolutePosition.Y) / svField.AbsoluteSize.Y, 0, 1)
        apply()
    end
    svField.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dsv = true; handleSV(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dsv and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            handleSV(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dsv = false end
    end)

    local dh = false
    local function handleHue(input)
        h = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        apply()
    end
    hueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dh = true; handleHue(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dh and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            handleHue(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dh = false end
    end)

    if alphaBar then
        local da = false
        local function handleAlpha(input)
            alphaValue = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
            refresh()
            if config.Callback then config.Callback(current, alphaValue) end
        end
        alphaBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                da = true; handleAlpha(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if da and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                handleAlpha(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then da = false end
        end)
    end

    hexBox.FocusLost:Connect(function()
        if updating then return end
        local col = fromHex(hexBox.Text)
        if col then h, s, v = Color3.toHSV(col) apply()
        else hexBox.Text = toHex(current) end
    end)

    row.MouseButton1Click:Connect(function()
        open = not open
        if open then
            holder.Visible = true
            local hh = config.WithAlpha and 184 or 174
            TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, hh),
            }):Play()
            refresh()
        else
            local t = TweenService:Create(holder, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0),
            })
            t:Play()
            t.Completed:Connect(function() if not open then holder.Visible = false end end)
        end
    end)

    refresh()

    local obj = {
        Instance = row,
        Get = function() return current end,
        Set = function(col)
            h, s, v = Color3.toHSV(col)
            apply()
        end,
        GetAlpha = function() return alphaValue end,
        SetAlpha = function(a)
            alphaValue = math.clamp(a, 0, 1)
            refresh()
        end,
    }
    table.insert(self.Elements, { Type = "ColorPicker", Instance = row })
    return obj
end

-- ============================================================
-- PLAYER LIST
-- ============================================================
function Library:AddPlayerList(tab, config)
    local self = self
    config = config or {}
    tab:CreateSection({ Text = config.Title or "Игроки" })

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = BG_ITEM
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.ZIndex = 4
    holder.Parent = tab.Content
    createCorner(holder, 10)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim2.new(0, 8)
    pad.PaddingBottom = UDim2.new(0, 8)
    pad.PaddingLeft = UDim2.new(0, 8)
    pad.PaddingRight = UDim2.new(0, 8)
    pad.Parent = holder

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = holder

    local function refresh()
        for _, c in ipairs(holder:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local r = Instance.new("TextButton")
                r.BackgroundColor3 = BG_ITEM
                r.AutoButtonColor = false
                r.BorderSizePixel = 0
                r.Size = UDim2.new(1, 0, 0, 32)
                r.Font = Enum.Font.GothamMedium
                r.Text = "   " .. plr.Name
                r.TextColor3 = TEXT_COLOR
                r.TextSize = 12
                r.TextXAlignment = Enum.TextXAlignment.Left
                r.ZIndex = 5
                r.Parent = holder
                createCorner(r, 8)

                if config.OnPlayer then
                    r.MouseButton1Click:Connect(function() config.OnPlayer(plr) end)
                end
            end
        end
    end
    refresh()

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.BackgroundColor3 = THEMES[currentThemeKey].Accent
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Size = UDim2.new(1, 0, 0, 32)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.Text = "🔄 Обновить"
    refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
    refreshBtn.TextSize = 12
    refreshBtn.ZIndex = 5
    refreshBtn.Parent = holder
    createCorner(refreshBtn, 8)
    refreshBtn.MouseButton1Click:Connect(refresh)

    Players.PlayerAdded:Connect(refresh)
    Players.PlayerRemoving:Connect(function() task.wait(0.1) refresh() end)

    return { Refresh = refresh }
end

-- ============================================================
-- THEME
-- ============================================================
function Library:SetTheme(key)
    if not THEMES[key] then return end
    currentThemeKey = key
    local theme = THEMES[key]

    if self.AvatarStroke then TweenService:Create(self.AvatarStroke, TweenInfo.new(0.3), { Color = theme.Accent }):Play() end
    for _, l in ipairs(self.GlowLayers or {}) do
        TweenService:Create(l.instance, TweenInfo.new(0.3), { BackgroundColor3 = theme.Accent }):Play()
    end
    if self.StrokeGradient then
        self.StrokeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Accent),
            ColorSequenceKeypoint.new(0.5, theme.AccentLight),
            ColorSequenceKeypoint.new(1, theme.Accent),
        })
    end
    if self.TitleIcon then self.TitleIcon.TextColor3 = theme.Accent end
    if self.ToggleBtnStroke then TweenService:Create(self.ToggleBtnStroke, TweenInfo.new(0.3), { Color = theme.Accent }):Play() end

    for _, sb in ipairs(self._scrollBars or {}) do
        TweenService:Create(sb, TweenInfo.new(0.3), { ScrollBarImageColor3 = theme.Accent }):Play()
    end
    for _, el in ipairs(self.Elements) do
        if el.UpdateTheme then el.UpdateTheme() end
    end
    if self.CurrentTab and self.TabButtons[self.CurrentTab] then
        TweenService:Create(self.TabButtons[self.CurrentTab], TweenInfo.new(0.2), { BackgroundColor3 = theme.Accent }):Play()
    end
end

-- ============================================================
-- NOTIFY
-- ============================================================
function Library:Notify(config)
    local kind = config.Kind or "info"
    local accent = THEMES[currentThemeKey].Accent
    if kind == "success" then accent = Color3.fromRGB(60, 200, 120)
    elseif kind == "error" then accent = Color3.fromRGB(235, 80, 90)
    elseif kind == "warning" then accent = Color3.fromRGB(255, 180, 60) end

    local notify = Instance.new("Frame")
    notify.Size = UDim2.new(0, 280, 0, 70)
    notify.Position = UDim2.new(1, 300, 0, 20)
    notify.BackgroundColor3 = BG_PANEL
    notify.BorderSizePixel = 0
    notify.ZIndex = 999
    notify.Parent = self.ScreenGui
    createCorner(notify, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 2
    stroke.Parent = notify

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 12, 0, 8)
    title.Size = UDim2.new(1, -24, 0, 20)
    title.Font = Enum.Font.GothamBold
    title.Text = config.Title or "Уведомление"
    title.TextColor3 = TEXT_COLOR
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 1000
    title.Parent = notify

    local content = Instance.new("TextLabel")
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 12, 0, 30)
    content.Size = UDim2.new(1, -24, 0, 32)
    content.Font = Enum.Font.Gotham
    content.Text = config.Content or ""
    content.TextColor3 = SUBTEXT
    content.TextSize = 12
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextWrapped = true
    content.ZIndex = 1000
    content.Parent = notify

    -- Стек уведомлений
    self._notifyY = (self._notifyY or 20)
    notify.Position = UDim2.new(1, 300, 0, self._notifyY)
    self._notifyY = self._notifyY + 78

    TweenService:Create(notify, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -300, 0, notify.Position.Y.Offset),
    }):Play()

    if config.Sound ~= false then playSound(kind) end

    task.delay(config.Duration or 5, function()
        local t = TweenService:Create(notify, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 300, 0, notify.Position.Y.Offset),
        })
        t:Play()
        t.Completed:Connect(function()
            self._notifyY = math.max(20, (self._notifyY or 20) - 78)
            notify:Destroy()
        end)
    end)
    return notify
end

-- ============================================================
-- PATCH: avatar + shine
-- ============================================================
local _origCreateWindow = Library.CreateWindow
function Library:CreateWindow(config)
    local w = _origCreateWindow(self, config)
    if w.Avatar then
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(
                    LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100
                )
            end)
            if ok and content then w.Avatar.Image = content end
        end)
    end
    task.spawn(function()
        local offset = 0
        while w.ScreenGui and w.ScreenGui.Parent do
            offset = (offset + 0.006) % 1
            if w.StrokeGradient then w.StrokeGradient.Offset = Vector2.new(offset, 0) end
            RunService.Heartbeat:Wait()
        end
    end)
    return w
end

return Library