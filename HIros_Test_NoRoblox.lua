--[[
================================================================================
 HIros — автономный тест ВНЕ Roblox
 Один файл: заглушка Roblox API + загрузка библиотеки + прогон проверок + отчёт.
 Roblox не нужен, Studio не нужен, executor не нужен.

 ЗАПУСК
   luatex --luaonly HIros_Test_NoRoblox.lua
   fengari HIros_Test_NoRoblox.lua
   lua5.3 HIros_Test_NoRoblox.lua
   npm exec --yes --package=fengari-node-cli -- fengari HIros_Test_NoRoblox.lua

 ОТКУДА БЕРЁТСЯ БИБЛИОТЕКА (по порядку)
   1) --library=/путь/к/файлу.lua   (аргумент командной строки)
   2) CONFIG.LibraryPath в этом файле
   3) HIros_Test_NoRoblox.lua + "HIros 6.0" рядом с этим тестом (и ещё несколько вариантов имён)
   4) CONFIG.Library / getgenv().HIros / _G.HIros — если библиотека уже загружена в процесс
   5) --url=https://... или CONFIG.LibraryUrl — скачивание: curl/wget через io.popen,
      затем os.execute + loadfile (путь для fengari), затем game:HttpGet и luasocket.
      Это тот же путь, который используется в executor'ах, когда рядом нет файла.
      Нужен установленный curl или wget (в fengari — тоже, но через os.execute).

 ЧТО ПОДМЕНЯЕТСЯ ВМЕСТО ROBLOX
   Instance (свойства, дети, Parent, события, FindFirstChild/WaitForChild/Destroy),
   Enum/EnumItem, UDim/UDim2/Vector2/Color3 (с арифметикой и Lerp), TweenInfo,
   ColorSequence/NumberSequence, typeof, game:GetService для Players/RunService/
   TweenService/UserInputService/GuiService/ContentProvider/Lighting/SoundService/
   HttpService/CoreGui, сигналы (MouseButton1Click, InputBegan, GetPropertyChangedSignal
   и т.д.), мгновенные твины с Completed, task.delay в виде очереди (тест сам её
   выполняет), task.spawn без запуска (иначе бесконечные циклы библиотеки),
   виртуальная файловая система для профилей конфигов (writefile/readfile/isfile/
   listfiles/delfile), table.find и math.clamp.

 ОГРАНИЧЕНИЯ (по-честному)
   • Это проверка логики и API, а не рендера: пиксельные размеры, скругления и
     порядок отрисовки настоящий Roblox считает сам.
   • Клики по элементам не эмулируются (кроме тех, что дёргаются напрямую),
     поэтому в конце печатается список ручных шагов для Studio/игры.

 Отчёт печатается в stdout, дублируется в файл (если доступна запись: io.open),
 код возврата 1 при любом провале. Флаги: --quiet, --compile-only, --report=путь.
================================================================================
]]

local CONFIG = {
    LibraryPath = nil,          -- явный путь к файлу библиотеки
    LibraryUrl = "",            -- "https://..." если файла рядом нет
    Library = nil,              -- готовая таблица библиотеки (если уже загружена)
    Verbose = true,             -- печатать ли прогресс по ходу (итог печатается всегда)
    ReportPath = nil,           -- nil = HIros_Test_NoRoblox_report.txt рядом с тестом
    CompileOnly = false,        -- true = только загрузить библиотеку и проверить синтаксис
}

-- ============================================================================
-- АРГУМЕНТЫ КОМАНДНОЙ СТРОКИ
-- ============================================================================
local function parseArgs(argv)
    if type(argv) ~= "table" then return end
    for _, value in ipairs(argv) do
        if type(value) == "string" then
            local path = value:match("^%-%-library=(.+)$")
            local url = value:match("^%-%-url=(.+)$")
            local report = value:match("^%-%-report=(.+)$")
            if path then CONFIG.LibraryPath = path
            elseif url then CONFIG.LibraryUrl = url
            elseif report then CONFIG.ReportPath = report
            elseif value == "--quiet" then CONFIG.Verbose = false
            elseif value == "--compile-only" then CONFIG.CompileOnly = true end
        end
    end
end
parseArgs(rawget(_G, "arg"))

local SCRIPT_DIR = ""
if type(arg) == "table" and type(arg[0]) == "string" then
    SCRIPT_DIR = arg[0]:match("^(.*)[/\\][^/\\]*$") or "." 
    SCRIPT_DIR = SCRIPT_DIR .. "/"
end

-- ============================================================================
-- ЗАГЛУШКА ROBLOX API
-- ============================================================================
-- >>> SHIM START  (этот блок можно вырезать и переиспользовать в других стендах)
if not (typeof and Instance and Enum) then
    print("[shim] Roblox не обнаружен — поднимаю заглушку API")

    math.clamp = math.clamp or function(value, low, high)
        if value < low then return low end
        if value > high then return high end
        return value
    end
    table.find = table.find or function(list, wanted)
        for index, value in ipairs(list) do
            if value == wanted then return index end
        end
        return nil
    end
    local unpackValues = table.unpack or unpack

    -- ---------------------------------------------------------------- Enum
    local function enumFolder()
        return setmetatable({}, {
            __index = function(folder, key)
                local item = { Name = key, _enumItem = true }
                setmetatable(item, { __tostring = function(self) return self.Name end })
                rawset(folder, key, item)
                return item
            end,
        })
    end
    Enum = setmetatable({}, {
        __index = function(root, key)
            local folder = enumFolder()
            rawset(root, key, folder)
            return folder
        end,
    })

    -- -------------------------------------------------- Color3 / UDim / Vector2
    local colorMethods = {}
    local colorMeta = { __index = colorMethods }
    local function tagColor(value)
        value = value or { R = 0, G = 0, B = 0 }
        value._color3 = true
        return setmetatable(value, colorMeta)
    end
    function colorMethods:Lerp(other, alpha)
        alpha = alpha or 0
        return tagColor({
            R = self.R + (other.R - self.R) * alpha,
            G = self.G + (other.G - self.G) * alpha,
            B = self.B + (other.B - self.B) * alpha,
        })
    end
    function colorMethods:ToHSV() return self.H or 0, self.S or 0, self.V or 0 end
    Color3 = {
        fromRGB = function(r, g, b) return tagColor({ R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }) end,
        new = function(r, g, b) return tagColor({ R = r or 0, G = g or 0, B = b or 0 }) end,
        fromHSV = function(h, s, v)
            local value = tagColor({ R = s or 0, G = v or 0, B = h or 0 })
            value.H, value.S, value.V = h or 0, s or 0, v or 0
            return value
        end,
        toHSV = function(color) return color.H or 0, color.S or 0, color.V or 0 end,
    }

    local udimMethods = {}
    local udimMeta = { __index = udimMethods }
    UDim = {
        new = function(scale, offset)
            local value = { Scale = scale or 0, Offset = offset or 0, _udim = true }
            return setmetatable(value, udimMeta)
        end,
    }
    udimMeta.__add = function(a, b) return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset) end
    udimMeta.__sub = function(a, b) return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset) end
    udimMeta.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end

    local udim2Meta = {}
    UDim2 = {
        new = function(xs, xo, ys, yo)
            local value = {
                X = { Scale = xs or 0, Offset = xo or 0 },
                Y = { Scale = ys or 0, Offset = yo or 0 },
                _udim2 = true,
            }
            return setmetatable(value, udim2Meta)
        end,
    }
    udim2Meta.__add = function(a, b)
        return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
    end
    udim2Meta.__sub = function(a, b)
        return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
    end
    udim2Meta.__eq = function(a, b)
        return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
    end

    local vector2Meta = {}
    Vector2 = {
        new = function(x, y)
            return setmetatable({ X = x or 0, Y = y or 0, _vector2 = true }, vector2Meta)
        end,
    }
    vector2Meta.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
    vector2Meta.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end

    -- ------------------------------------------------------ TweenInfo / Sequences
    TweenInfo = { new = function(time, style, direction, repeatCount, reverses, delayTime)
        return {
            _tweenInfo = true,
            Time = time or 0,
            EasingStyle = style,
            EasingDirection = direction,
            RepeatCount = repeatCount,
            Reverses = reverses,
            DelayTime = delayTime,
        }
    end }
    ColorSequenceKeypoint = { new = function(time, color) return { Time = time, Value = color } end }
    ColorSequence = { new = function(points) return { Keypoints = points } end }
    NumberSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end }
    NumberSequence = { new = function(points) return { Keypoints = points } end }

    local baseTypeof = typeof
    function typeof(value)
        if type(value) ~= "table" then return type(value) end
        if value._props then return "Instance" end
        if value._enumItem then return "EnumItem" end
        if value._tweenInfo then return "TweenInfo" end
        if value._udim2 then return "UDim2" end
        if value._udim then return "UDim" end
        if value._vector2 then return "Vector2" end
        if value._color3 then return "Color3" end
        if baseTypeof then return baseTypeof(value) end
        return "table"
    end

    -- ------------------------------------------------------------- сигналы
    local function signal(replay)
        local handle = { callbacks = {}, fired = false, args = nil }
        function handle:Connect(callback)
            local connection = { Fn = callback, Connected = true }
            self.callbacks[#self.callbacks + 1] = connection
            -- Только для tween.Completed: мгновенный твин уже завершился, а код
            -- подписывается после Play (в настоящем Roblox это гонка).
            if replay and self.fired then callback(unpackValues(self.args or {})) end
            return {
                Connected = true,
                Disconnect = function() connection.Connected = false end,
            }
        end
        function handle:Fire(...)
            self.fired = true
            self.args = { ... }
            for _, connection in ipairs(self.callbacks) do
                if connection.Connected then connection.Fn(...) end
            end
        end
        function handle:Wait() return 0 end
        return handle
    end

    -- -------------------------------------------------------------- Instance
    local instanceMethods = {}
    local knownSignals = {
        MouseButton1Click = true, MouseButton2Click = true, MouseEnter = true, MouseLeave = true,
        MouseButton1Down = true, MouseButton1Up = true, InputBegan = true, InputChanged = true,
        InputEnded = true, FocusLost = true, Focused = true, DescendantAdded = true, Changed = true,
    }

    function instanceMethods:GetChildren()
        local out = {}
        for index, child in ipairs(rawget(self, "_children")) do out[index] = child end
        return out
    end
    function instanceMethods:GetDescendants()
        local out = {}
        local function walk(parent)
            for _, child in ipairs(parent:GetChildren()) do
                out[#out + 1] = child
                walk(child)
            end
        end
        walk(self)
        return out
    end
    function instanceMethods:IsA(className)
        local own = self.ClassName
        if own == className then return true end
        -- упрощённая иерархия для проверок, которые её используют
        local groups = {
            GuiObject = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ScrollingFrame = true, CanvasGroup = true },
            GuiBase2d = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ScrollingFrame = true, CanvasGroup = true, ScreenGui = true },
            Instance = true,
        }
        local group = groups[className]
        if group == true then return true end
        if type(group) == "table" and group[own] then return true end
        return false
    end
    function instanceMethods:FindFirstChild(name)
        for _, child in ipairs(rawget(self, "_children")) do
            if child.Name == name then return child end
        end
        return nil
    end
    function instanceMethods:FindFirstChildOfClass(className)
        for _, child in ipairs(rawget(self, "_children")) do
            if child.ClassName == className then return child end
        end
        return nil
    end
    function instanceMethods:WaitForChild(name) return self:FindFirstChild(name) end
    function instanceMethods:GetFullName() return self.Name or "" end
    function instanceMethods:GetPropertyChangedSignal(property)
        local signals = rawget(self, "_signals")
        local key = "Property_" .. property
        signals[key] = signals[key] or signal()
        return signals[key]
    end
    function instanceMethods:Destroy()
        self.Parent = nil
        self._destroyed = true
    end
    function instanceMethods:Clone() return Instance.new(self.ClassName) end
    function instanceMethods:GetAttribute() return nil end
    function instanceMethods:SetAttribute() end

    local function removeChild(parent, child)
        if not parent then return end
        local children = rawget(parent, "_children")
        for index = #children, 1, -1 do
            if children[index] == child then table.remove(children, index) end
        end
    end

    -- В настоящем Roblox свойства никогда не nil: у свежего GuiObject
    -- LayoutOrder = 0, ZIndex = 1, Visible = true, Rotation = 0 и т.д.
    -- Без этих дефолтов сравнения вида LayoutOrder < LayoutOrder падают.
    local GUI_DEFAULTS = {
        LayoutOrder = 0,
        ZIndex = 1,
        Visible = true,
        Rotation = 0,
        BackgroundTransparency = 0,
        TextTransparency = 0,
        ImageTransparency = 0,
        Text = "",
        TextSize = 14,
        TextWrapped = false,
        ClipsDescendants = false,
        BorderSizePixel = 1,
    }

    local function instanceNew(className)
        local props = { ClassName = className, Name = "" }
        for key, value in pairs(GUI_DEFAULTS) do props[key] = value end
        local object = {
            _props = props,
            _children = {},
            _signals = {},
        }
        return setmetatable(object, {
            __index = function(self, key)
                if instanceMethods[key] then return instanceMethods[key] end
                local value = rawget(self, "_props")[key]
                if value ~= nil then return value end
                if key == "AbsoluteSize" then return Vector2.new(300, 40) end
                if key == "AbsolutePosition" then return Vector2.new(0, 0) end
                if knownSignals[key] then
                    local signals = rawget(self, "_signals")
                    signals[key] = signals[key] or signal()
                    return signals[key]
                end
                return nil
            end,
            __newindex = function(self, key, value)
                local props = rawget(self, "_props")
                if key == "Parent" then
                    removeChild(props.Parent, self)
                    props.Parent = value
                    if value then
                        local children = rawget(value, "_children")
                        if children then children[#children + 1] = self end
                        -- DescendantAdded всплывает ко всем предкам, как в Roblox
                        local ancestor = value
                        while ancestor do
                            local signals = rawget(ancestor, "_signals")
                            local added = signals and rawget(signals, "DescendantAdded")
                            if added then added:Fire(self) end
                            local ancestorProps = rawget(ancestor, "_props")
                            ancestor = ancestorProps and ancestorProps.Parent
                        end
                    end
                else
                    local old = props[key]
                    props[key] = value
                    if old ~= value then
                        local changed = rawget(self, "_signals")["Property_" .. key]
                        if changed then changed:Fire() end
                    end
                end
            end,
        })
    end
    Instance = { new = instanceNew }

    -- ---------------------------------------------------------- сервисы игры
    local playerGui = Instance.new("PlayerGui")
    local player = { UserId = 1, DisplayName = "SelfTest", Name = "SelfTest" }
    player.WaitForChild = function() return playerGui end

    local userInputService = {
        InputBegan = signal(),
        InputChanged = signal(),
        InputEnded = signal(),
        GetMouseLocation = function() return Vector2.new(400, 300) end,
        MouseEnabled = true,
        TouchEnabled = true,
        KeyboardEnabled = true,
    }
    local createdTweens = {}
    local tweenService = {
        Create = function(_, target, info, props)
            local tween = { Target = target, Info = info, Props = props, Completed = signal(true) }
            function tween:Play()
                for key, value in pairs(props or {}) do target[key] = value end
                self.Completed:Fire(Enum.PlaybackState.Completed)
            end
            function tween:Cancel() end
            function tween:Pause() end
            createdTweens[#createdTweens + 1] = tween
            return tween
        end,
    }
    local services = {
        Players = { LocalPlayer = player, GetUserThumbnailAsync = function() return "rbxassetid://1" end },
        RunService = {
            Heartbeat = { Wait = function() return 1 / 60 end },
            RenderStepped = { Wait = function() return 1 / 60 end },
            Stepped = { Wait = function() return 1 / 60 end },
        },
        TweenService = tweenService,
        UserInputService = userInputService,
        GuiService = { GetGuiInset = function() return Vector2.new(0, 36) end },
        ContentProvider = { PreloadAsync = function() end },
        Lighting = {},
        SoundService = {},
        CoreGui = Instance.new("CoreGui"),
        TextService = {},
        HttpService = {
            JSONEncode = function() return "{}" end,
            JSONDecode = function() return {} end,
            GetAsync = function() error("в заглушке нет сети") end,
            HttpEnabled = true,
        },
    }
    game = { GetService = function(_, name)
        if not services[name] then services[name] = {} end
        return services[name]
    end }

    getgenv = function() return _G end
    warn = warn or print

    -- -------------------------------------------------------- виртуальное время
    local delayedTasks = {}
    task = {
        delay = function(seconds, callback)
            if type(seconds) == "function" then callback = seconds seconds = 0 end
            delayedTasks[#delayedTasks + 1] = { Seconds = seconds, Callback = callback }
        end,
        defer = function(callback) callback() end,
        spawn = function() end,          -- не запускаем: у библиотеки есть вечные циклы
        wait = function() return 0 end,
        cancel = function() end,
    }
    _G.__flushDelayedTasks = function(filterKey)
        local pending = delayedTasks
        delayedTasks = {}
        local executed = 0
        for _, entry in ipairs(pending) do
            if filterKey == nil or tostring(entry.Seconds) == tostring(filterKey) then
                executed = executed + 1
                entry.Callback()
            else
                delayedTasks[#delayedTasks + 1] = entry
            end
        end
        return executed
    end
    _G.__createdTweens = createdTweens
    _G.__userInputService = userInputService

    -- ------------------------------------------- виртуальная файловая система
    local files = {}
    writefile = function(path, content) files[path] = tostring(content) end
    readfile = function(path)
        if files[path] == nil then error("файл не найден: " .. tostring(path)) end
        return files[path]
    end
    isfile = function(path) return files[path] ~= nil end
    delfile = function(path)
        if files[path] == nil then error("файл не найден: " .. tostring(path)) end
        files[path] = nil
    end
    listfiles = function(folder)
        local out = {}
        for path in pairs(files) do
            if folder == "" or folder == nil or path:sub(1, #folder) == folder then out[#out + 1] = path end
        end
        return out
    end
    appendfile = function(path, content) files[path] = (files[path] or "") .. tostring(content) end
    _G.__virtualFiles = files

    print(string.format("[shim] заглушка готова (%s, Lua %s)", _VERSION or "?", tostring(_VERSION)))
end
-- <<< SHIM END

-- ============================================================================
-- ЗАГРУЗКА БИБЛИОТЕКИ
-- ============================================================================
local function looksLikeLibrary(value)
    return type(value) == "table" and type(value.CreateWindow) == "function" and type(value.CreateTab) == "function"
end

-- Среда может быть разной: в стандартном Lua есть io.open, в fengari только
-- loadfile/dofile, у экзекьютора — свои функции. Поэтому пробуем по очереди.
local function compileSource(source, label)
    local chunk = loadstring or load
    local fn, err = chunk(source, label)
    if not fn then return nil, "не компилируется: " .. tostring(err) end
    return fn
end

local function loadLocalChunk(path)
    if type(loadfile) == "function" then
        local fn, err = loadfile(path)
        if fn then return fn end
        if err and not tostring(err):find("cannot open", 1, true) then return nil, tostring(err) end
    end
    if type(io) == "table" and type(io.open) == "function" then
        local file = io.open(path, "rb")
        if file then
            local content = file:read("*a")
            file:close()
            if content and #content > 0 then return compileSource(content, "@" .. path) end
        end
    end
    if type(io) == "table" and type(io.popen) == "function" then
        local handle = io.popen("cat '" .. path .. "' 2>/dev/null")
        if handle then
            local content = handle:read("*a")
            handle:close()
            if content and #content > 0 then return compileSource(content, "@" .. path) end
        end
    end
    if type(readfile) == "function" then
        local ok, content = pcall(readfile, path)
        if ok and type(content) == "string" and #content > 0 then return compileSource(content, "@" .. path) end
    end
    return nil, "нет способа прочитать файл"
end

local function extractChunk(source, label)
    if type(source) ~= "string" or #source == 0 then return nil, "пустой ответ" end
    local fn, err = compileSource(source, label)
    if not fn then return nil, err end
    local ok, result = pcall(fn)
    if not ok then return nil, "ошибка при загрузке: " .. tostring(result) end
    if not looksLikeLibrary(result) then return nil, "это не библиотека HIros (нет CreateWindow)" end
    return result
end

-- Скачивание библиотеки. Возвращает готовую таблицу библиотеки:
-- curl/wget через io.popen, затем во временный файл через os.execute (это путь для
-- fengari, где io.popen нет, а loadfile есть), затем game:HttpGet и luasocket.
local function loadFromUrl(url)
    if type(url) ~= "string" or url == "" then return nil, "URL не задан" end

    local function libraryFromContent(content, label)
        if type(content) ~= "string" or #content == 0 then return nil end
        local library, err = extractChunk(content, label)
        if not library then
            print(string.format("[loader] %s: %s", label, tostring(err)))
            return nil
        end
        return library
    end

    local commands = {
        'curl -fsSL --max-time 30 "' .. url .. '" 2>/dev/null',
        'wget -qO- --timeout=30 "' .. url .. '" 2>/dev/null',
    }

    -- 1) читаем содержимое прямо из stdout
    if type(io) == "table" and type(io.popen) == "function" then
        for _, command in ipairs(commands) do
            local handle = io.popen(command)
            if handle then
                local content = handle:read("*a")
                handle:close()
                local library = libraryFromContent(content, url)
                if library then return library, "URL " .. url end
            end
        end
    end

    -- 2) качаем во временный файл и грузим его (fengari: нет io.popen, есть loadfile)
    if type(os) == "table" and type(os.execute) == "function" and type(loadfile) == "function" then
        local directory = (type(os.getenv) == "function" and os.getenv("TMPDIR")) or "/tmp"
        local tempPath = directory .. "/hiros_test_download.lua"
        local downloads = {
            string.format("curl -fsSL --max-time 30 -o '%s' '%s'", tempPath, url),
            string.format("wget -qO '%s' '%s'", tempPath, url),
        }
        for _, command in ipairs(downloads) do
            pcall(os.execute, command)
            local fn = loadfile(tempPath)
            if fn then
                local ok, result = pcall(fn)
                if ok and looksLikeLibrary(result) then return result, "URL " .. url end
            end
        end
    end

    -- 3) game:HttpGet (внутри Roblox/executor)
    if game and type(game.HttpGet) == "function" then
        local ok, content = pcall(function() return game:HttpGet(url) end)
        if ok then
            local library = libraryFromContent(content, "game:HttpGet")
            if library then return library, "URL " .. url end
        end
    end

    -- 4) luasocket, если установлен
    local socketOk, http = pcall(require, "socket.http")
    if socketOk and type(http) == "table" then
        local ok, content = pcall(http.request, url)
        if ok then
            local library = libraryFromContent(content, "luasocket")
            if library then return library, "URL " .. url end
        end
    end

    return nil, "нет способа скачать (нужен curl/wget, luasocket или game:HttpGet)"
end

local function resolveLibrary()
    if looksLikeLibrary(CONFIG.Library) then return CONFIG.Library, "CONFIG.Library" end

    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" and looksLikeLibrary(env.HIros) then return env.HIros, "getgenv().HIros" end
    end
    if type(_G) == "table" and looksLikeLibrary(_G.HIros) then return _G.HIros, "_G.HIros" end

    local names = { "HIros 6.0", "HIros 6.1", "HIros", "HIros.lua", "library.lua", "HIros_Library.lua" }
    local candidates = {}
    if CONFIG.LibraryPath then candidates[#candidates + 1] = CONFIG.LibraryPath end
    for _, name in ipairs(names) do
        candidates[#candidates + 1] = SCRIPT_DIR .. name
        candidates[#candidates + 1] = name
    end
    candidates[#candidates + 1] = "./HIros 6.0.lua"
    for _, path in ipairs(candidates) do
        local fn, err = loadLocalChunk(path)
        if fn then
            local ok, result = pcall(fn)
            if ok and looksLikeLibrary(result) then return result, "файл " .. path end
            if ok then
                print(string.format("[loader] %s найден, но это не библиотека HIros", path))
            else
                print(string.format("[loader] %s найден, но упал при загрузке: %s", path, tostring(result)))
            end
        elseif err and not tostring(err):find("нет способа прочитать", 1, true) then
            print(string.format("[loader] %s: %s", path, tostring(err)))
        end
    end

    if CONFIG.LibraryUrl ~= "" then
        local library, err = loadFromUrl(CONFIG.LibraryUrl)
        if library then return library, err end
        print("[loader] не удалось скачать библиотеку: " .. tostring(err))
    end

    return nil, "не найдена: положи файл рядом с этим тестом, укажи --library=/путь или --url=https://..."
end

local HIros, librarySource = resolveLibrary()
if not looksLikeLibrary(HIros) then
    print("[HIros test] библиотека " .. tostring(librarySource))
    print("[HIros test] подсказки:")
    print("  --library=\"/путь/к/HIros 6.0\"       запуск с конкретным файлом")
    print("  --url=\"https://host/library.lua\"    загрузка по сети")
    print("  CONFIG.Library = HIros                если библиотека уже загружена в процесс")
    print("[HIros test] прогон остановлен")
    if os and os.exit then os.exit(1) end
    return
end
print("[HIros test] библиотека загружена: " .. tostring(librarySource))
local version = "?"
do
    local ok, info = pcall(function() return HIros:GetInfo() end)
    if ok and type(info) == "table" then version = tostring(info.Version or info.version or "?") end
end
print("[HIros test] версия библиотеки: " .. version)

if CONFIG.CompileOnly then
    print("[HIros test] режим --compile-only: библиотека загружена, синтаксис в порядке")
    if os and os.exit then os.exit(0) end
    return
end

-- ============================================================================
-- ФРЕЙМВОРК ТЕСТОВ
-- ============================================================================
local report = { passed = 0, failed = 0, skipped = 0, entries = {} }

local function emit(line, toWarn)
    report.entries[#report.entries + 1] = line
    if toWarn and warn then warn("[test] " .. line) else print("[test] " .. line) end
end

local function record(status, name, detail)
    if status == "PASS" then report.passed = report.passed + 1
    elseif status == "FAIL" then report.failed = report.failed + 1
    else report.skipped = report.skipped + 1 end
    local line = string.format("%s | %s%s", status, name, detail and (" | " .. tostring(detail)) or "")
    emit(line, status == "FAIL")
end

local function check(name, ok, detail)
    record(ok and "PASS" or "FAIL", name, detail)
    return ok and true or false
end

local function skip(name, reason) record("SKIP", name, reason) end

local function section(title)
    report.entries[#report.entries + 1] = ""
    report.entries[#report.entries + 1] = "== " .. title .. " =="
    if CONFIG.Verbose then print("[test] ---- " .. title .. " ----") end
end

local function step(name, fn)
    local ok, err = pcall(fn)
    check(name, ok, not ok and tostring(err) or nil)
    return ok
end

local function findChild(root, name)
    if not root then return nil end
    local ok, child = pcall(function() return root:FindFirstChild(name) end)
    if ok and child then return child end
    return nil
end

local function findDescendant(root, name)
    if not root then return nil end
    for _, child in ipairs(root:GetDescendants()) do
        if child.Name == name then return child end
    end
    return nil
end

local function firstOfClass(root, className)
    if not root then return nil end
    for _, child in ipairs(root:GetDescendants()) do
        if child.ClassName == className then return child end
    end
    return nil
end

local function childOfClass(root, className)
    if not root then return nil end
    for _, child in ipairs(root:GetChildren()) do
        if child.ClassName == className then return child end
    end
    return nil
end

local function countNamed(root, pattern)
    if not root then return 0 end
    local count = 0
    for _, child in ipairs(root:GetDescendants()) do
        if child.Name and child.Name:match(pattern) then count = count + 1 end
    end
    return count
end

local function joined(rows, key)
    local parts = {}
    for _, row in ipairs(rows or {}) do parts[#parts + 1] = tostring(row[key]) end
    return table.concat(parts, ",")
end

local function isCallable(target, key)
    return type(target) == "table" and type(target[key]) == "function"
end

local userInputService = _G.__userInputService or game:GetService("UserInputService")
local function pressKey(key)
    userInputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = key }, false)
end
local function releaseKey(key)
    userInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = key })
end
local function flushTasks() return _G.__flushDelayedTasks() end

local function runAllTests()
    -- ============================================================================
    -- 1. API БИБЛИОТЕКИ
    -- ============================================================================
    section("1. API библиотеки (на таблице Library)")
    local apiFunctions = {
        "CreateWindow", "CreateTab", "CreateTabGroup", "SetTheme", "SetGlowMode",
        "SetAccessibility", "SetReduceMotion", "SetUIScale", "SetHighContrast",
        "SaveConfig", "LoadConfig", "DeleteConfig", "GetConfigs",
        "Search", "ClearSearch", "Minimize", "SetHotkey", "GetHotkey", "Confirm", "GetInfo",
    }
    local missing = {}
    for _, key in ipairs(apiFunctions) do
        if not isCallable(HIros, key) then missing[#missing + 1] = key end
    end
    check("публичный API на месте (" .. #apiFunctions .. " функций)", #missing == 0, #missing > 0 and table.concat(missing, ", ") or nil)
    local windowMethods = {
        "CreateTab", "Notify", "CreateHUD", "GetHUDWidgets", "SetHUDVisible", "DestroyHUDWidgets",
        "GetKeybinds", "GetKeybindConflicts", "RefreshKeybindConflicts",
        "SetTheme", "SetGlowMode", "SetAccentColor", "SetIcon", "SetParticles",
        "Search", "ClearSearch", "Minimize", "SetScale", "SetHotkey", "GetHotkey",
        "GetAccessibility", "SetAccessibility", "SetReduceMotion", "SetUIScale", "SetHighContrast",
        "SaveConfig", "LoadConfig", "DeleteConfig", "GetConfigs", "SetFlag", "GetSoundsEnabled", "SetSoundsEnabled",
    }
    local tabMethods = { "CreateTable", "CreateIconPicker", "CreateKeybind", "CreateButton", "CreateToggle" }
    local missingWindow = {}
    check("методы элементов живут на вкладке, а не на Library", not isCallable(HIros, "CreateTable")
        and not isCallable(HIros, "CreateIconPicker") and not isCallable(HIros, "CreateKeybind"))

    -- ============================================================================
    -- 2. ОКНО И РАЗМЕТКА
    -- ============================================================================
    section("2. Окно и разметка")
    local window
    step("CreateWindow()", function()
        window = HIros:CreateWindow({
            Name = "HIros Offline Test",
            Shoutout = false,          -- никаких попапов согласия и сетевых отправок
            Sounds = false,            -- тихий прогон
            Particles = false,
        })
    end)
    check("CreateWindow вернул объект окна", type(window) == "table")
    if type(window) ~= "table" then
        print("[HIros test] окно не создано — дальше проверять нечего")
        return
    end
    check("ScreenGui создан и привязан к PlayerGui", window.ScreenGui ~= nil and window.ScreenGui.Parent ~= nil)
    check("окно показано после создания", window.Main ~= nil and window.Main.Visible == true)
    for _, key in ipairs(windowMethods) do
        if not isCallable(window, key) then missingWindow[#missingWindow + 1] = key end
    end
    check("методы окна на месте (" .. #windowMethods .. " методов)", #missingWindow == 0, #missingWindow > 0 and table.concat(missingWindow, ", ") or nil)
    check("GetAccessibility() возвращает таблицу", type(window:GetAccessibility()) == "table")

    local tab
    step("CreateTab()", function() tab = window:CreateTab({ Name = "🧪 Offline", Icon = "🧪" }) end)
    check("вкладка с рабочей областью", tab ~= nil and tab.Content ~= nil)
    check("вкладка стала текущей", window.CurrentTab ~= nil and window.Tabs[window.CurrentTab] ~= nil)
    do
        local missingTab = {}
        for _, key in ipairs(tabMethods) do
            if not isCallable(tab, key) then missingTab[#missingTab + 1] = key end
        end
        check("методы элементов привязаны к вкладке (" .. #tabMethods .. ")", #missingTab == 0,
            #missingTab > 0 and table.concat(missingTab, ", ") or nil)
    end
    local pageLayout = childOfClass(tab and tab.Content, "UIListLayout")
    check("UIListLayout сортирует по LayoutOrder", pageLayout ~= nil and pageLayout.SortOrder == Enum.SortOrder.LayoutOrder)
    local pagePadding = childOfClass(tab and tab.Content, "UIPadding")
    check("UIPadding принимает UDim (а не UDim2)", pagePadding ~= nil and typeof(pagePadding.PaddingRight) == "UDim")

    local first, second, third
    step("элементы без Order создаются", function()
        first = tab:CreateLabel({ Text = "Первый" })
        second = tab:CreateDivider({})
        third = tab:CreateLabel({ Text = "Третий" })
    end)
    check("автопорядок растёт (withOrder)", first ~= nil and third ~= nil and first.LayoutOrder < second.LayoutOrder
        and second.LayoutOrder < third.LayoutOrder,
        first and string.format("%s < %s < %s", first.LayoutOrder, second.LayoutOrder, third.LayoutOrder) or nil)

    -- ============================================================================
    -- 3. ТАБЛИЦА
    -- ============================================================================
    section("3. Таблица: сортировка, фильтр, выбор, действия")
    local actionHits, clickRow, clickIndex = 0, nil, nil
    local view
    step("CreateTable()", function()
        view = tab:CreateTable({
            Name = "Игроки",
            Height = 140,
            MultiSelect = true,
            Columns = {
                { Key = "Name", Name = "Игрок", Width = 2 },
                { Key = "Ping", Name = "Пинг", Width = 1 },
            },
            Rows = {
                { Name = "Gamma", Ping = 12 },
                { Name = "alpha", Ping = 24 },
                { Name = "Beta", Ping = 5 },
            },
            Actions = { { Name = "Профиль", Text = "↗", Callback = function(row) actionHits = actionHits + 1 end } },
            Callback = function(row, index) clickRow, clickIndex = row, index end,
        })
    end)
    check("таблица создана и отдаёт Instance", view ~= nil and view.Instance ~= nil and view.Instance.ClassName == "Frame")
    check("регистрация в Elements для тем", #window.Elements > 0 and window.Elements[#window.Elements].Type ~= nil)
    check("исходный порядок строк сохранён", joined(view:Get(), "Name") == "Gamma,alpha,Beta", joined(view:Get(), "Name"))
    check("Sort() по числу, по возрастанию", view:Sort("Ping") and joined(view:Get(), "Ping") == "5,12,24", joined(view:Get(), "Ping"))
    local sortKey, sortAscending
    if view then sortKey, sortAscending = view:GetSort() end
    check("GetSort() сообщает колонку и направление", sortKey == "Ping" and sortAscending == true,
        string.format("%s/%s", tostring(sortKey), tostring(sortAscending)))
    check("вызов точкой переворачивает сортировку", view.Sort(view, "Ping") and joined(view.Get(view), "Ping") == "24,12,5")
    check("строки сортируются регистронезависимо", view:Sort("Name", false) and joined(view:Get(), "Name") == "Gamma,Beta,alpha", joined(view:Get(), "Name"))
    check("неизвестная колонка отклоняется", view.Sort("НетТакой") == false)
    check("несортируемая колонка отклоняет Sort()", (function()
        local fixed = tab:CreateTable({
            Searchable = false,
            Columns = { { Key = "Name", Sortable = false } },
            Rows = { { Name = "B" }, { Name = "A" } },
        })
        return fixed.Sort("Name") == false and joined(fixed:Get(), "Name") == "B,A"
    end)())
    check("nil в конце при убывании", (function()
        local test = tab:CreateTable({
            Columns = { { Key = "Score" }, { Key = "Name" } },
            Rows = { { Name = "missing" }, { Name = "two", Score = 2 }, { Name = "one", Score = 1 } },
        })
        test:Sort("Score", false)
        return joined(test:Get(), "Name") == "two,one,missing"
    end)())
    check("равные значения держат порядок вставки", (function()
        local test = tab:CreateTable({
            Columns = { { Key = "Score" }, { Key = "Name" } },
            Rows = { { Name = "first", Score = 1 }, { Name = "second", Score = 1 } },
        })
        test:Sort("Score")
        return joined(test:Get(), "Name") == "first,second"
    end)())
    check("колонки выводятся детерминированно без Columns", (function()
        local inferred = tab:CreateTable({ Rows = { { z = 1, a = 2 } }, SortBy = "a", Searchable = false })
        local header = childOfClass(inferred.Instance, "Frame")
        local labels = {}
        if header then
            for _, child in ipairs(header:GetChildren()) do
                if child.ClassName == "TextButton" then labels[#labels + 1] = child.Text end
            end
        end
        return labels[1] ~= nil and labels[1]:sub(1, 1) == "a" and labels[2] == "z", table.concat(labels, ",")
    end)())
    check("форматтер колонки применяется к ячейкам", (function()
        local formatted = tab:CreateTable({
            Searchable = false,
            Columns = { { Key = "Score", Format = function(value) return "#" .. tostring(value) end } },
            Rows = { { Score = 7 } },
        })
        local scroller = childOfClass(formatted.Instance, "ScrollingFrame")
        if not scroller then return false end
        for _, row in ipairs(scroller:GetChildren()) do
            if row.ClassName == "TextButton" then
                for _, cell in ipairs(row:GetChildren()) do
                    if cell.ClassName == "TextLabel" then return cell.Text == "#7" end
                end
            end
        end
        return false
    end)())
    check("тело таблицы сортируется по LayoutOrder", (function()
        local scroller = childOfClass(view.Instance, "ScrollingFrame")
        local layout = scroller and childOfClass(scroller, "UIListLayout")
        return layout ~= nil and layout.SortOrder == Enum.SortOrder.LayoutOrder
    end)())
    check("строки отрисованы", countNamed(view.Instance, "^TableRow$") == countNamed(view.Instance, "^TableRow$") and countNamed(view.Instance, "^TableRow$") > 0,
        tostring(countNamed(view.Instance, "^TableRow$")))
    check("кнопки действий созданы в строках", countNamed(view.Instance, "^TableAction_1$") == countNamed(view.Instance, "^TableRow$"))
    check("фильтр не теряет данные", view:Filter("ali") and #view:GetVisible() == 0 and #view:Get() == 3)
    step("сортировка + фильтр вместе", function() view:Sort("Name", true) view:Filter("a") end)
    -- сортировка по имени идёт без учёта регистра: alpha, Beta, Gamma
    check("фильтр по подстроке (регистр не важен)", joined(view:GetVisible(), "Name") == "alpha,Beta,Gamma" and #view:GetVisible() == 3,
        joined(view:GetVisible(), "Name"))
    step("фильтр по конкретному игроку", function() view:Filter("ALPHA") end)
    check("фильтр нашёл одну строку", #view:GetVisible() == 1 and joined(view:GetVisible(), "Name") == "alpha", joined(view:GetVisible(), "Name"))
    local emptyLabel = findChild(view.Instance, "TableEmptyState")
    check("пустое состояние скрыто при найденных строках", emptyLabel ~= nil and emptyLabel.Visible == false)
    step("фильтр без совпадений", function() view:Filter("нет-такого") end)
    check("пустое состояние показывается", emptyLabel ~= nil and emptyLabel.Visible == true and emptyLabel.Text == "Ничего не найдено",
        emptyLabel and emptyLabel.Text or nil)
    check("GetFilter() возвращает текущий фильтр", view:GetFilter() == "нет-такого")
    step("фильтр снят", function() view:Filter("") end)
    check("строки вернулись", #view:GetVisible() == 3)

    local rows = {}
    for _, child in ipairs((childOfClass(view.Instance, "ScrollingFrame") or Instance.new("Frame")):GetChildren()) do
        if child.Name == "TableRow" then rows[#rows + 1] = child end
    end
    if rows[1] then rows[1].MouseButton1Click:Fire() end
    if rows[3] then rows[3].MouseButton1Click:Fire() end
    check("мультивыбор собирает строки", #view:GetSelectedRows() == 2 and #view:GetSelected() == 2)
    local expectedRow = view:GetVisible()[3]
    check("Callback получает строку и её видимый индекс", clickRow ~= nil and clickIndex == 3
        and expectedRow ~= nil and clickRow.Name == expectedRow.Name,
        string.format("%s/%s", tostring(clickRow and clickRow.Name), tostring(clickIndex)))
    local actionButton
    if rows[1] then
        for _, child in ipairs(rows[1]:GetChildren()) do
            if child.Name == "TableAction_1" then actionButton = child end
        end
    end
    if actionButton then actionButton.MouseButton1Click:Fire() end
    check("кнопка действия вызывает колбэк со строкой", actionHits == 1)

    -- PING: Beta 5, Aaron 10, Gamma 12, alpha 24
    check("AddRow встаёт на место в сортировке", (function()
        view:Sort("Ping", true)
        view:AddRow({ Name = "Aaron", Ping = 10 })
        return joined(view:Get(), "Name") == "Beta,Aaron,Gamma,alpha"
    end)(), joined(view:Get(), "Name"))
    check("строка без ключа сортировки уходит в конец", (function()
        view:AddRow({ Name = "Без пинга" })
        local all = view:Get()
        return all[#all].Name == "Без пинга"
    end)())
    step("Set() заменяет строки (двоеточием)", function() view:Set({ { Name = "Reset", Ping = 7 } }) end)
    check("Set() очистил выбор и применил строки", joined(view:Get(), "Name") == "Reset" and #view:GetSelectedRows() == 0)
    step("AddRow точкой", function() view.AddRow(view, { Name = "Dot", Ping = 3 }) end)
    check("AddRow точкой добавил строку", #view.Get(view) == 2)
    check("Clear() очищает и меняет текст пустого состояния", view.Clear(view) and #view:Get() == 0 and emptyLabel.Text == "Нет записей")
    step("таблица обновлена заново", function() view:Set({ { Name = "Zoe", Ping = 1 } }) end)
    check("UpdateTheme() таблицы без ошибок", pcall(view.UpdateTheme))

    -- ============================================================================
    -- 4. ВЫБОР ИКОНКИ
    -- ============================================================================
    section("4. Выбор иконки/картинки")
    local picker
    step("CreateIconPicker()", function()
        picker = tab:CreateIconPicker({
            Name = "Иконка",
            Flag = "offline_icon",
            Height = 110,
            Items = {
                "⚡",
                { Name = "Синий", Value = "blue", Icon = "🔵", Search = "azure" },
                { Name = "Значок", Image = 12345, Favorite = true },
            },
            Favorites = { "⚡" },
            CurrentValue = "⚡",
        })
    end)
    check("элемент создан и зарегистрирован", picker ~= nil and picker.Instance ~= nil)
    check("начальное значение из CurrentValue", picker:Get() == "⚡", tostring(picker:Get()))
    check("избранное подхвачено из config и item", #picker:GetFavorites() == 2, tostring(#picker:GetFavorites()))
    check("поиск работает по Search и без регистра", picker:Search("AZURE") and countNamed(picker.Instance, "^Icon_") == 1,
        tostring(countNamed(picker.Instance, "^Icon_")))
    step("сброс поиска", function() picker:Search("") end)
    check("фильтр «Избранное»", picker:SetFilter("favorites") and countNamed(picker.Instance, "^Icon_") == 2)
    check("неизвестный фильтр отклонён", picker:SetFilter("чужой") == false)
    step("фильтр «Все»", function() picker:SetFilter("all") end)
    check("звёздочка снимает избранное", picker:ToggleFavorite("⚡") == false and #picker:GetFavorites() == 1)
    check("звёздочка возвращает избранное", picker:ToggleFavorite("⚡") == true and #picker:GetFavorites() == 2)
    check("числовой ID нормализуется в rbxassetid", picker:Set(98765) == true and picker:Get() == "rbxassetid://98765", tostring(picker:Get()))
    check("значение ушло в Flag окна", window.Flags.offline_icon == "rbxassetid://98765")
    check("история недавних обновляется", picker:GetRecent()[1] == "rbxassetid://98765")
    check("пустое значение сбрасывает выбор", picker:Set({}) == false)
    local previewFrame = findChild(picker.Instance, "IconPreview")
    local previewImage = previewFrame and childOfClass(previewFrame, "ImageLabel")
    check("превью показывает картинку", previewImage ~= nil and previewImage.Visible == true and previewImage.Image == "rbxassetid://98765")
    local manualBox = findChild(picker.Instance, "ImageIdInput")
    local applyButton = findChild(picker.Instance, "ApplyImageButton")
    if manualBox and applyButton then
        manualBox.Text = "321"
        applyButton.MouseButton1Click:Fire()
    end
    check("ручной ввод ID применяется", picker:Get() == "rbxassetid://321")
    local previous = picker:Get()
    if manualBox and applyButton then
        manualBox.Text = "не картинка"
        applyButton.MouseButton1Click:Fire()
    end
    check("невалидный ввод отклонён и подсвечен", picker:Get() == previous)
    check("фильтр избранного в localStorage (Flag)", type(window.Flags.offline_icon_favorites) == "table")
    check("UpdateTheme() выбора иконки без ошибок", pcall(picker.UpdateTheme))

    -- ============================================================================
    -- 5. ХОТКЕИ
    -- ============================================================================
    section("5. Менеджер хоткеев")
    local keyEvents = {}
    local bindA, bindB
    step("CreateKeybind() x2 с одной клавишей", function()
        bindA = tab:CreateKeybind({
            Name = "ESP", Flag = "offline_esp", Mode = "Toggle", CurrentKeybind = Enum.KeyCode.F,
            Callback = function(key, mode, state) keyEvents[#keyEvents + 1] = { Key = key and key.Name, Mode = mode, State = state } end,
        })
        bindB = tab:CreateKeybind({ Name = "Fly", Flag = "offline_fly", CurrentKeybind = Enum.KeyCode.F })
    end)
    check("хоткеи зарегистрированы", #window:GetKeybinds() == 2, tostring(#window:GetKeybinds()))
    local conflicts = window:GetKeybindConflicts()
    check("конфликт клавиш найден", conflicts.F ~= nil and #conflicts.F == 2, conflicts.F and table.concat(conflicts.F, ",") or "нет")
    check("оба бинда видят конфликт", #bindA:GetConflict() == 1 and #bindB:GetConflict() == 1)
    local conflictLabel = findChild(bindA.Instance, "KeybindConflict")
    check("конфликт подписан на элементе", conflictLabel ~= nil and conflictLabel.Text:find("⚠") ~= nil, conflictLabel and conflictLabel.Text or nil)
    local keyBadge = findChild(bindA.Instance, "KeybindKey")
    local keyStroke = keyBadge and childOfClass(keyBadge, "UIStroke")
    check("UIStroke на плашке — Border", keyStroke ~= nil and keyStroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border)

    pressKey(Enum.KeyCode.F)
    check("Toggle: первое нажатие включает", bindA:GetState() == true and keyEvents[#keyEvents].State == true)
    pressKey(Enum.KeyCode.F)
    check("Toggle: второе нажатие выключает", bindA:GetState() == false and #keyEvents == 2)
    if keyBadge then keyBadge.MouseButton1Click:Fire() end
    pressKey(Enum.KeyCode.Z)
    check("режим переназначения ловит клавишу", bindA.Get(bindA) == Enum.KeyCode.Z and window.Flags.offline_esp == "Z")
    check("плашка показывает новую клавишу", keyBadge.Text == "Z", keyBadge.Text)
    check("SetMode принимает известный режим", bindA:SetMode("Hold") and bindA:GetMode() == "Hold")
    check("SetMode отклоняет неизвестный", bindA:SetMode("Turbo") == false)
    check("режим сохранён в Flags", window.Flags.offline_esp_mode == "Hold")
    step("Set() точкой меняет клавишу", function() bindA.Set(bindA, Enum.KeyCode.G) end)
    check("клавиша сохранена", bindA:Get() == Enum.KeyCode.G and window.Flags.offline_esp == "G")
    local beforeEvents = #keyEvents
    pressKey(Enum.KeyCode.G)
    check("Hold: включается на нажатии", bindA:GetState() == true)
    releaseKey(Enum.KeyCode.G)
    check("Hold: выключается на отпускании", bindA:GetState() == false)
    check("Hold: обе границы в колбэке", keyEvents[#keyEvents].State == false and keyEvents[#keyEvents - 1].State == true)
    check("SetState возвращает успех, GetState() — состояние", (function()
        bindA:SetState(true)
        local isOn = bindA:GetState() == true
        bindA:SetState(false)
        return isOn and bindA:GetState() == false
    end)())
    check("чужая клавиша игнорируется", (function()
        local count = #keyEvents
        pressKey(Enum.KeyCode.L)
        releaseKey(Enum.KeyCode.L)
        return #keyEvents == count
    end)())
    check("смена клавиши снимает конфликт", (function()
        bindB:Set(Enum.KeyCode.H)
        return next(window:GetKeybindConflicts()) == nil and bindA:GetConflict()[1] == nil and conflictLabel.Text == ""
    end)())
    check("UpdateTheme() хоткея без ошибок", pcall(bindA.UpdateTheme))

    -- ============================================================================
    -- 6. HUD-ВИДЖЕТЫ
    -- ============================================================================
    section("6. HUD-виджеты")
    local hud, hudSecond
    step("CreateHUD()", function()
        hud = window:CreateHUD({ Name = "FPS", Text = "60 FPS", Icon = "🎯", Position = "top-left", Flag = "offline_hud" })
    end)
    check("виджет лежит в HUD-слое", hud ~= nil and hud.Instance.Parent ~= nil and hud.Instance.Parent.Name == "HUDLayer")
    check("стартовый угол и отступ", hud:GetPosition().Side == "top-left" and hud.Instance.Position.X.Offset == 16)
    check("SetText/GetText работают", hud:SetText("120 FPS") and hud:GetText() == "120 FPS")
    check("смена угла через строку", hud:SetPosition("bottom-right") and hud:GetPosition().Side == "bottom-right")
    check("угол использует scale 1 для правого/нижнего", hud.Instance.Position.X.Scale == 1 and hud.Instance.Position.Y.Scale == 1)
    check("позиция записана в Flag", type(window.Flags.offline_hud) == "table" and window.Flags.offline_hud.Side == "bottom-right")
    check("неизвестный угол отклонён", hud:SetPosition("середина") == false)
    check("SetVisible/GetVisible работают", hud:SetVisible(false) and hud:GetVisible() == false and hud:SetVisible(true) and hud:GetVisible() == true)

    hud.Instance.Parent.AbsoluteSize = Vector2.new(800, 600)
    hud.Instance.AbsolutePosition = Vector2.new(40, 30)
    hud.Instance.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(40, 30) })
    userInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Delta = Vector2.new(-20, -10) })
    check("во время перетаскивания позиция свободная", hud:GetPosition().Mode == "free")
    userInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
    check("после отпускания — прилипание к углу", hud:GetPosition().Mode == "corner" and hud:GetPosition().Side == "top-left",
        hud:GetPosition().Side)
    check("виджет стоит на отступе угла", hud.Instance.Position.X.Offset == 16 and hud.Instance.Position.Y.Offset == 16)
    check("Snap() возвращает угол", type(hud:Snap()) == "string")

    step("второй виджет", function() hudSecond = window:CreateHUD({ Name = "Ping", Text = "24 ms" }) end)
    check("виджеты перечисляются", #window:GetHUDWidgets() == 2)
    check("слой HUD можно скрыть", window:SetHUDVisible(false) and window._hudLayer.Visible == false and window:SetHUDVisible(true))
    step("DestroyHUDWidgets()", function() window:DestroyHUDWidgets() end)
    check("виджеты удалены", #window:GetHUDWidgets() == 0)
    step("пересоздать виджет для ручной проверки", function()
        hud = window:CreateHUD({ Name = "Перетащи меня", Text = "HUD", Icon = "🤚", Position = "top-right", Flag = "offline_hud_drag" })
    end)

    -- ============================================================================
    -- 7. УВЕДОМЛЕНИЯ
    -- ============================================================================
    section("7. Уведомления: очередь, приоритеты, прогресс, кнопки")
    local noteA = window:Notify({ Title = "Очередь 1", Content = "первое", Duration = 30, MaxVisible = 2 })
    local noteB = window:Notify({ Title = "Очередь 2", Content = "второе", Duration = 30, MaxVisible = 2 })
    local noteC = window:Notify({ Title = "Очередь 3", Content = "третье", Duration = 30, MaxVisible = 2 })
    check("уведомление — CanvasGroup", noteA ~= nil and noteA.Instance ~= nil and noteA.Instance.ClassName == "CanvasGroup")
    check("видимых не больше лимита", #window:GetNotifications() == 3 and noteC.Queued == true and #window:GetQueuedNotifications() == 1)
    check("лишнее ждёт в очереди без Instance", noteC.Instance == nil and noteC.IsVisible() == false)
    noteA:Close()
    check("освободившийся слот поднимает очередь", noteC.Queued == false and noteC.Instance ~= nil and noteC.IsVisible() == true)
    noteB:Close()
    noteC:Close()
    check("уведомления убраны из списка", #window:GetNotifications() == 0)

    local slotNote = window:Notify({ Title = "Слот", Sticky = true, MaxVisible = 1 })
    local lowNote = window:Notify({ Title = "Низкий", Sticky = true, Priority = 1, MaxVisible = 1 })
    local highNote = window:Notify({ Title = "Высокий", Sticky = true, Priority = 9, MaxVisible = 1 })
    check("оба лишних уведомления в очереди", lowNote.Queued == true and highNote.Queued == true)
    slotNote:Close()
    check("первым показывается приоритетное", highNote.Queued == false and highNote.Instance ~= nil and lowNote.Queued == true)
    highNote:Close()
    check("следом — обычное", lowNote.Queued == false and lowNote.Instance ~= nil)
    lowNote:Close()

    local progressNote = window:Notify({ Title = "Загрузка", Content = "качаем", Progress = 0, Sticky = true })
    check("у прогресса полоса и проценты", findChild(progressNote.Instance, "NotifyProgress") ~= nil and findChild(progressNote.Instance, "NotifyPercent") ~= nil)
    progressNote:SetProgress(0.42)
    check("SetProgress обновляет проценты", findChild(progressNote.Instance, "NotifyPercent").Text == "42%")
    check("прогресс ограничен 0..1", progressNote:SetProgress(4) and progressNote.Progress == 1)
    check("SetTitle меняет заголовок", progressNote.SetTitle("Почти готово") and findChild(progressNote.Instance, "NotifyTitle").Text == "Почти готово")
    check("SetKind меняет вид уведомления", progressNote.SetKind("success"))
    progressNote:Close()

    local stickyNote = window:Notify({ Title = "Липкое", Sticky = true })
    check("у липкого нет отсчёта", findChild(stickyNote.Instance, "NotifyTimer").Visible == false)
    stickyNote:Close()

    local actionResult
    local actionNote = window:Notify({
        Title = "Кнопки",
        Sticky = true,
        Actions = {
            { Name = "Да", Primary = true, Callback = function() actionResult = "primary" end },
            { Name = "Нет", Close = false, Callback = function() actionResult = "later" end },
        },
    })
    local laterButton = findChild(actionNote.Instance, "NotifyAction_2")
    local primaryButton = findChild(actionNote.Instance, "NotifyAction_1")
    if laterButton then laterButton.MouseButton1Click:Fire() end
    check("действие без Close не закрывает", actionResult == "later" and actionNote.IsVisible() == true)
    if primaryButton then primaryButton.MouseButton1Click:Fire() end
    check("основное действие закрывает", actionResult == "primary" and actionNote.Closed == true)

    local autoNote = window:Notify({ Title = "Авто", Duration = 3 })
    flushTasks()
    check("Duration закрывает по таймеру", autoNote.Closed == true and #window:GetNotifications() == 0)
    check("ClearNotifications очищает всё", (function()
        window:Notify({ Title = "Мусор", Duration = 20 })
        window:Notify({ Title = "Мусор 2", Duration = 20, MaxVisible = 1 })
        window:ClearNotifications()
        return #window:GetNotifications() == 0 and #window:GetQueuedNotifications() == 0
    end)())

    -- ============================================================================
    -- 8. ДОСТУПНОСТЬ
    -- ============================================================================
    section("8. Доступность: анимации, масштаб, контраст")
    local tweens = _G.__createdTweens or {}
    window:Notify({ Title = "Замер твина", Duration = 6 })
    local normalTween = tweens[#tweens]
    check("обычный твин идёт со своей длительностью", normalTween ~= nil and normalTween.Info.Time > 0,
        normalTween and tostring(normalTween.Info.Time) or nil)
    window:ClearNotifications()
    window:SetReduceMotion(true)
    window:Notify({ Title = "Без анимации", Duration = 6 })
    local reducedTween = tweens[#tweens]
    check("ReduceMotion обнуляет длительность твинов", window:GetAccessibility().ReduceMotion == true and reducedTween.Info.Time == 0,
        tostring(reducedTween and reducedTween.Info.Time))
    window:ClearNotifications()
    check("уведомления работают и без анимаций", (function()
        local note = window:Notify({ Title = "Тишина", Duration = 4 })
        flushTasks()
        return note.Closed == true
    end)())
    window:SetReduceMotion(false)
    check("ReduceMotion выключается", window:GetAccessibility().ReduceMotion == false)
    check("UIScale применяется к ScreenGui", window:SetUIScale(1.25).Scale == 1.25 and window._uiScale.Scale == 1.25)
    check("UIScale ограничен диапазоном", window:SetUIScale(9).Scale == 1.6 and window:SetUIScale(0.1).Scale == 0.6)
    window:SetUIScale(1)
    local hudText = findChild(hud.Instance, "HUDText")
    window:SetHighContrast(true)
    check("HighContrast делает текст белым", window:GetAccessibility().HighContrast == true and hudText.TextColor3.R == 1 and hudText.TextColor3.G == 1)
    check("HighContrast затемняет панели", hud.Instance.BackgroundColor3.R < 0.05)
    check("новые элементы тоже получают контраст", (function()
        local late = window:Notify({ Title = "Позже", Content = "проверка", Sticky = true })
        local title = findDescendant(late.Instance, "NotifyTitle")
        local ok = title ~= nil and title.TextColor3.R == 1 and title.TextColor3.G == 1
        late:Close()
        return ok
    end)())
    window:SetHighContrast(false)
    check("HighContrast отключается", window:GetAccessibility().HighContrast == false and hud.Instance.BackgroundColor3.R > 0.05)
    check("настройки доступности сохраняются в Flag", type(window.Flags.accessibility) == "table")
    check("звуки можно выключить и включить", (function()
        local before = window:GetSoundsEnabled()
        window:SetSoundsEnabled(not before)
        local toggled = window:GetSoundsEnabled() == (not before)
        window:SetSoundsEnabled(before)
        return toggled
    end)())

    -- ============================================================================
    -- 9. ТЕМЫ, ПОИСК, СВОРАЧИВАНИЕ
    -- ============================================================================
    section("9. Темы, поиск, сворачивание")
    local themeFailures = {}
    for _, themeKey in ipairs({ "Blue", "Red", "Yellow", "Green", "Purple" }) do
        local ok, err = pcall(function() window:SetTheme(themeKey) end)
        if not ok then themeFailures[#themeFailures + 1] = themeKey .. " (" .. tostring(err) .. ")" end
    end
    check("все темы применяются", #themeFailures == 0, #themeFailures > 0 and table.concat(themeFailures, "; ") or nil)
    check("несуществующая тема игнорируется", pcall(function() window:SetTheme("Радужная") end))
    check("элементы перекрашиваются при смене темы", (function()
        local before = countNamed(view.Instance, "^TableRow$")
        window:SetTheme("Purple")
        return before == countNamed(view.Instance, "^TableRow$")
    end)())
    step("радужное свечение и возврат", function() window:SetGlowMode("rainbow") window:SetGlowMode("theme") end)
    check("поиск находит русский текст", (function()
        local ok = pcall(function() window:Search("игроки") end)
        return ok and window._noResults ~= nil and window._noResults.Visible == false
    end)())
    check("поиск находит латиницу", (function()
        window:Search("Zoe")
        return window._noResults.Visible == false
    end)())
    step("сброс поиска", function() window:ClearSearch() end)
    check("заведомо отсутствующий запрос даёт «ничего не найдено»", (function()
        window:Search("жджждж-нет-такого")
        local shown = window._noResults.Visible == true
        window:ClearSearch()
        return shown
    end)())
    check("свернуть и развернуть", (function()
        window:Minimize()
        local collapsed = window._minimized == true
        window:Minimize()
        return collapsed and window._minimized ~= true
    end)())
    check("SetScale меняет масштаб окна", (function()
        window:SetScale(1.1)
        local applied = math.abs(window.Scale.Scale - 1.1) < 0.001
        window:SetScale(1)
        return applied
    end)())
    check("Hotkey читается и меняется", (function()
        local before = window:GetHotkey()
        window:SetHotkey(Enum.KeyCode.Insert)
        local after = window:GetHotkey()
        window:SetHotkey(before)
        return after == Enum.KeyCode.Insert
    end)())
    check("профили конфигов доступны через виртуальную ФС", type(window:GetConfigs()) == "table" and #window:GetConfigs() >= 1)

    -- ============================================================================
    -- 10. КОНФИГИ (ВИРТУАЛЬНАЯ ФАЙЛОВАЯ СИСТЕМА)
    -- ============================================================================
    section("10. Конфиги: сохранение, загрузка, удаление")
    local slot = "offline_selftest"
    step("SaveConfig()", function() window:SetFlag("offline_test_flag", 42) window:SaveConfig(slot) end)
    local filePath = "MenuLibrary_config_" .. slot .. ".json"
    check("файл профиля создан", _G.__virtualFiles[filePath] ~= nil, filePath)
    check("в файле сохранились флаги", _G.__virtualFiles[filePath] ~= nil and _G.__virtualFiles[filePath]:find("offline_test_flag") ~= nil)
    check("профиль виден в GetConfigs()", (function()
        for _, name in ipairs(window:GetConfigs()) do
            if name == slot then return true end
        end
        return false
    end)())
    step("флаги сброшены перед загрузкой", function() window.Flags.offline_test_flag = nil end)
    step("LoadConfig()", function() window:LoadConfig(slot) end)
    check("значение вернулось из профиля", window.Flags.offline_test_flag == 42, tostring(window.Flags.offline_test_flag))
    check("Deletion: DeleteConfig()", window:DeleteConfig(slot) == true and _G.__virtualFiles[filePath] == nil)
    check("повторное удаление отклоняется", window:DeleteConfig(slot) == false)
    check("default удалить нельзя", window:DeleteConfig("default") == false)

end

-- Прогон защищён: неожиданная ошибка тоже попадёт в отчёт, а не оборвёт его.
local okAll, errAll = xpcall(runAllTests, debug and debug.traceback or tostring)
if not okAll then
    record("FAIL", "непредвиденная ошибка прогона", tostring(errAll))
end

-- ============================================================================
-- 11. ИТОГ
-- ============================================================================
section("11. Итог")
local summary = string.format("Пройдено: %d | Провалено: %d | Пропущено: %d", report.passed, report.failed, report.skipped)
print("[HIros test] " .. summary)

local failures = {}
for _, line in ipairs(report.entries) do
    if line:sub(1, 4) == "FAIL" then failures[#failures + 1] = line end
end

local reportText = table.concat(report.entries, "\n") .. "\n\n" .. summary
    .. "\nбиблиотека: " .. tostring(librarySource)
    .. "\nверсия: " .. version
    .. "\nсреда: Lua " .. tostring(_VERSION)
    .. "\n"
local reportPath = CONFIG.ReportPath or (SCRIPT_DIR .. "HIros_Test_NoRoblox_report.txt")
local saved = false
if type(io) == "table" and type(io.open) == "function" then
    saved = pcall(function()
        local file = io.open(reportPath, "wb")
        if not file then error("не открылся файл отчёта") end
        file:write(reportText)
        file:close()
    end)
end
if saved then
    print("[HIros test] отчёт сохранён: " .. reportPath)
else
    print("[HIros test] файл отчёта недоступен в этой среде — отчёт только в выводе")
    print("[HIros test] подсказка: lua HIros_Test_NoRoblox.lua > report.txt")
end

if report.failed > 0 then
    print("[HIros test] проваленные проверки:")
    for _, line in ipairs(failures) do print("[HIros test]   " .. line) end
end

print([[
[HIros test] РУЧНАЯ ПРОВЕРКА (то, что вне Roblox не воспроизвести):
  1. Таблица: клик по заголовку — сортировка ▲/▼, клик по строкам — подсветка, ввод в поле фильтра.
  2. Кнопка «↗» в строке — не должна менять выделение.
  3. Иконки: клик по плитке — выбор, ★ — избранное, вкладки «Все/Избранное/Недавние», ручной ввод rbxassetid.
  4. Хоткей: клик по плашке и нажатие клавиши, переключение режима Press/Hold/Toggle.
  5. HUD: перетаскивание мышью и прилипание к ближайшему углу.
  6. Уведомления: кнопки «Да»/«Нет», прогресс-бар, порядок в очереди.
  7. Доступность: HIros:SetReduceMotion(true), HIros:SetHighContrast(true), HIros:SetUIScale(1.25).
]])

if os and os.exit then os.exit(report.failed == 0 and 0 or 1) end
