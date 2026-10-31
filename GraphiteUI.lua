local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local TextService = game:GetService("TextService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Touch = UserInputService.TouchEnabled
local RowHeight = Touch and 40 or 36
local TopHeight = Touch and 40 or 34

local function CanHover()
	return UserInputService.MouseEnabled
end

local FooterHeight = 44
local Icons = {
	Close = "rbxassetid://12953907125",
	File = "rbxassetid://11570895459",
	Gear = "rbxassetid://103052477976081",
	List = "rbxassetid://96541223"
}
local Canvas3D = Vector2.new(580, 400)
local BarCanvas = Vector2.new(360, 80)
local LogoImage = "rbxassetid://104226806827804"

local Graphite = {Version = "1.1"}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local DefaultBase = C(8, 8, 8)

local Motion = {Reduce = false, Performance = false}
local ActiveWindow
local PendingLoad
local ErrorLog = {message = nil, time = 0}

local NoteColors = {
	Success = C(80, 200, 120),
	Warning = C(240, 190, 70),
	Error = C(230, 85, 85)
}

local function Luma(color)
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function Shift(color, amount)
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

local function BuildTheme(base, text, accent, border)
	local dark = Luma(base) < 0.5
	local theme = {Main = base}
	if dark then
		theme.Top = Shift(base, -0.24)
		theme.Side = Shift(base, -0.12)
		theme.Element = Shift(base, 0.08)
		theme.Hover = Shift(base, 0.16)
		theme.Stroke = Shift(base, 0.24)
	else
		theme.Top = Shift(base, -0.08)
		theme.Side = Shift(base, -0.04)
		theme.Element = Shift(base, 0.55)
		theme.Hover = Shift(base, 0.25)
		theme.Stroke = Shift(base, -0.2)
	end
	theme.Text = text or (dark and C(255, 255, 255) or C(28, 28, 32))
	theme.Sub = theme.Text:Lerp(base, 0.42)
	theme.Accent = accent or (dark and Shift(base, 0.6) or Shift(base, -0.55))
	theme.Border = border or (dark and Shift(base, 0.5) or Shift(base, -0.38))
	return theme
end

local GamesFile = "Bio.Menu.Games.txt"

local function Duration(total)
	total = math.max(0, math.floor(total))
	return string.format("%02d:%02d:%02d", math.floor(total / 3600), math.floor(total % 3600 / 60), total % 60)
end

local function LoadGames()
	local list = {}
	if type(isfile) ~= "function" or type(readfile) ~= "function" then
		return list
	end
	local ok, text = pcall(function()
		if isfile(GamesFile) then
			return readfile(GamesFile)
		end
	end)
	if ok and type(text) == "string" then
		for line in string.gmatch(text, "[^\r\n]+") do
			local id, stamp, name = string.match(line, "^(%d+)|(%d+)|(.*)$")
			if id then
				table.insert(list, {id = tonumber(id), time = tonumber(stamp), name = name})
			end
		end
	end
	return list
end

local function SaveGames(list)
	if type(writefile) ~= "function" then
		return
	end
	local lines = {}
	for index, entry in ipairs(list) do
		if index > 10 then
			break
		end
		local name = string.gsub(tostring(entry.name), "[|\r\n]", " ")
		table.insert(lines, entry.id .. "|" .. entry.time .. "|" .. name)
	end
	pcall(writefile, GamesFile, table.concat(lines, "\n"))
end

local function Create(class, props)
	local inst = Instance.new(class)
	local parent
	for key, value in pairs(props) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	inst.Parent = parent
	return inst
end

local function Round(parent, radius)
	return Create("UICorner", {CornerRadius = UDim.new(0, radius or 6), Parent = parent})
end

local function Pad(parent, left, top, right, bottom)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		Parent = parent
	})
end

local function Animate(inst, props, time, style, direction)
	local duration = time or 0.15
	if Motion.Reduce then
		duration = 0
	elseif Motion.Performance then
		duration = duration * 0.5
	end
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

local function Linear(inst, props, time)
	local tween = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Linear), props)
	tween:Play()
	return tween
end

local function ParseImage(id)
	if id == nil or id == "" then
		return nil
	end
	if type(id) == "number" or tonumber(id) then
		return "rbxassetid://" .. tostring(id)
	end
	return id
end

local function IsPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function Report(err)
	warn("[Graphite] " .. tostring(err))
	local window = ActiveWindow
	if not window or window.Closed then
		return
	end
	local message = string.match(tostring(err), "[^\n]+") or "Unknown error"
	message = string.gsub(message, "^.-:%d+:%s*", "")
	if #message > 90 then
		message = string.sub(message, 1, 90) .. "..."
	end
	local now = os.clock()
	if ErrorLog.message == message and now - ErrorLog.time < 3 then
		return
	end
	ErrorLog.message = message
	ErrorLog.time = now
	window:Notify({Title = "Error", Content = message, Type = "Error", Duration = 5})
end

local function FireWith(callback, done, ...)
	if type(callback) ~= "function" then
		if done then
			done(true)
		end
		return
	end
	task.spawn(function(...)
		local ok, err = pcall(callback, ...)
		if not ok then
			Report(err)
		end
		if done then
			done(ok)
		end
	end, ...)
end

local function Fire(callback, ...)
	FireWith(callback, nil, ...)
end

local function ViewSize(gui)
	local size = gui.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return Workspace.CurrentCamera.ViewportSize
	end
	return size
end

local function Encode(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return {t = "c", r = value.R, g = value.G, b = value.B}
	end
	if kind == "EnumItem" then
		return {t = "k", n = value.Name}
	end
	return value
end

local function Decode(value)
	if type(value) == "table" then
		if value.t == "c" then
			return Color3.new(value.r, value.g, value.b)
		end
		if value.t == "k" then
			return Enum.KeyCode[value.n] or Enum.KeyCode.Unknown
		end
	end
	return value
end

local function GlobalEnv()
	if type(getgenv) == "function" then
		local ok, shared = pcall(getgenv)
		if ok and type(shared) == "table" then
			return shared
		end
	end
	return _G
end

local function Serialize(value)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "0"
		end
		return string.format("%.10g", value)
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "string" then
		return string.format("%q", value)
	elseif kind == "table" then
		local parts = {}
		for index = 1, #value do
			table.insert(parts, Serialize(value[index]))
		end
		for key, item in pairs(value) do
			if type(key) == "string" then
				table.insert(parts, "[" .. string.format("%q", key) .. "]=" .. Serialize(item))
			end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "nil"
end

local function LongString(text)
	local level = 3
	while string.find(text, "]" .. string.rep("=", level) .. "]", 1, true) do
		level = level + 1
	end
	local equals = string.rep("=", level)
	return "[" .. equals .. "[\n" .. text .. "\n]" .. equals .. "]"
end

function Window:Connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function Window:Bind(callback)
	table.insert(self.Hooks, callback)
	callback()
end

function Window:RunHooks()
	for _, hook in ipairs(self.Hooks) do
		pcall(hook)
	end
end

function Window:Paint(inst, property, key)
	self:Bind(function()
		inst[property] = self.Theme[key]
	end)
	return inst
end

function Window:Make(class, props, paints)
	local inst = Create(class, props)
	for property, key in pairs(paints or {}) do
		self:Paint(inst, property, key)
	end
	return inst
end

function Window:Stroke(parent, key, transparency)
	local stroke = Create("UIStroke", {
		Thickness = 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent
	})
	self:Paint(stroke, "Color", key or "Stroke")
	return stroke
end

local function Hover(win, inst, base, over)
	inst.MouseEnter:Connect(function()
		if CanHover() then
			Animate(inst, {BackgroundColor3 = win.Theme[over or "Hover"]}, 0.1)
		end
	end)
	inst.MouseLeave:Connect(function()
		Animate(inst, {BackgroundColor3 = win.Theme[base or "Element"]}, 0.1)
	end)
end

function Window:Pointer(handle, onBegin, onMove, onEnd)
	local active
	self:Connect(handle.InputBegan, function(input)
		if not IsPointer(input) then
			return
		end
		if active and active.UserInputState ~= Enum.UserInputState.End then
			return
		end
		active = input
		if onBegin then
			onBegin(input)
		end
	end)
	self:Connect(UserInputService.InputChanged, function(input)
		if not active then
			return
		end
		local match
		if active.UserInputType == Enum.UserInputType.Touch then
			match = input == active
		else
			match = input.UserInputType == Enum.UserInputType.MouseMovement
		end
		if match and onMove then
			onMove(input)
		end
	end)
	self:Connect(UserInputService.InputEnded, function(input)
		if active and input == active then
			active = nil
			if onEnd then
				onEnd(input)
			end
		end
	end)
end

function Window:Slide(hit, onMove, scroller, onBegin, onEnd)
	self:Pointer(hit, function(input)
		if scroller then
			scroller.ScrollingEnabled = false
		end
		if onBegin then
			onBegin()
		end
		onMove(self:Cursor(input.Position))
	end, function(input)
		onMove(self:Cursor(input.Position))
	end, function()
		if scroller then
			scroller.ScrollingEnabled = true
		end
		if onEnd then
			onEnd()
		end
	end)
end

function Window:Fancy()
	return not Motion.Reduce and not Motion.Performance and self.TargetScale >= 0.6
end

function Window:IsFresh()
	return os.clock() - self.Born < 1.5
end

function Window:Status(kind, detail)
	local presets = {
		Saved = {"Saved", "Success"},
		Loaded = {"Loaded", "Success"},
		Updated = {"Updated", "Info"},
		Error = {"Error", "Error"},
		Unsaved = {"Unsaved Changes", "Warning"}
	}
	local preset = presets[kind] or {tostring(kind), "Info"}
	self:Notify({
		Title = preset[1],
		Content = detail,
		Type = preset[2],
		Duration = kind == "Unsaved" and 2.5 or 3
	})
end

function Window:Touch(flag)
	if not flag or self.Loading or self.Dirty or self.Closed then
		return
	end
	self.Dirty = true
	self:Status("Unsaved", "Use Save Config to keep your changes")
end

function Window:SetLocked(state)
	self.Locked = state == true
	if self.Grip then
		self.Grip.Visible = not self.Locked and not self.Focus and not self.Mode3D
	end
	if self.LockToggle then
		self.LockToggle:Set(self.Locked, true)
	end
end

function Window:SetReduceMotion(state)
	Motion.Reduce = state == true
	if self.ReduceToggle then
		self.ReduceToggle:Set(Motion.Reduce, true)
	end
end

function Window:SetPerformance(state)
	Motion.Performance = state == true
	if self.PerformanceToggle then
		self.PerformanceToggle:Set(Motion.Performance, true)
	end
end

function Window:SetAutoPerformance(state)
	if self.PerfConnection then
		self.PerfConnection:Disconnect()
		self.PerfConnection = nil
	end
	if not state then
		return
	end
	local frames = 0
	local last = os.clock()
	local low = 0
	self.PerfConnection = RunService.RenderStepped:Connect(function()
		frames = frames + 1
		local now = os.clock()
		if now - last >= 1 then
			local fps = frames / (now - last)
			frames = 0
			last = now
			if fps < 24 then
				low = low + 1
			else
				low = 0
			end
			if low >= 3 and not Motion.Performance then
				self:SetPerformance(true)
				self:Status("Updated", "Performance Mode turned on because FPS is low")
			end
		end
	end)
	table.insert(self.Connections, self.PerfConnection)
end

function Window:Flash()
	local stroke = self.EdgeStroke
	if not stroke then
		return
	end
	local tween = Animate(stroke, {Color = self.Theme.Accent, Thickness = math.max(3, self.BorderThickness + 2)}, 0.14)
	tween.Completed:Connect(function()
		Animate(stroke, {Color = self.Theme.Border, Thickness = self.BorderThickness}, 0.4)
	end)
end

function Window:Ripple(button, input)
	if not self:Fancy() then
		return
	end
	local count = button:GetAttribute("Ripples") or 0
	if count >= 3 then
		return
	end
	button:SetAttribute("Ripples", count + 1)
	local factor = button:IsDescendantOf(self.Main) and self.UIScale.Scale or 1
	factor = math.max(factor, 0.01)
	local origin = button.AbsolutePosition
	local size = button.AbsoluteSize
	local part, canvas
	if self.Mode3D and self.BarSurface and button:IsDescendantOf(self.BarSurface) then
		part = self.BarPart
		canvas = BarCanvas
	end
	local point = self:Cursor(input.Position, part, canvas)
	local x = (point.X - origin.X) / factor
	local y = (point.Y - origin.Y) / factor
	local reach = math.max(size.X, size.Y) / factor * 1.7
	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = button
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = dot})
	local tween = Animate(dot, {Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1}, 0.45)
	tween.Completed:Connect(function()
		dot:Destroy()
		button:SetAttribute("Ripples", math.max((button:GetAttribute("Ripples") or 1) - 1, 0))
	end)
end

function Window:Pressable(button, base)
	base = base or "Element"
	local function Rest(touch)
		Animate(button, {BackgroundColor3 = self.Theme[touch and base or "Hover"]}, 0.14)
	end
	button.InputBegan:Connect(function(input)
		if not IsPointer(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			local press = {input = input, origin = input.Position, button = button, base = base}
			self.TouchPress = press
			task.delay(0.12, function()
				if self.TouchPress == press and not self.Closed then
					press.applied = true
					self:Ripple(button, input)
					Animate(button, {BackgroundColor3 = self.Theme.Stroke}, 0.06)
				end
			end)
		else
			self:Ripple(button, input)
			Animate(button, {BackgroundColor3 = self.Theme.Stroke}, 0.06)
		end
	end)
	button.InputEnded:Connect(function(input)
		if not IsPointer(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			local press = self.TouchPress
			if press and press.input == input then
				self.TouchPress = nil
				if press.applied then
					Rest(true)
				else
					local tween = Animate(button, {BackgroundColor3 = self.Theme.Stroke}, 0.05)
					tween.Completed:Connect(function()
						Rest(true)
					end)
				end
			end
		else
			Rest(false)
		end
	end)
end

function Window:Reveal(object, delay)
	if not self:Fancy() or object.BackgroundTransparency >= 1 then
		return
	end
	local goal = object:GetAttribute("Goal")
	if goal == nil then
		goal = object.BackgroundTransparency
		object:SetAttribute("Goal", goal)
	end
	object.BackgroundTransparency = 1
	task.delay(delay, function()
		if object.Parent and not self.Closed then
			Animate(object, {BackgroundTransparency = goal}, 0.2)
		end
	end)
end

function Window:Stagger(page)
	if not self:Fancy() then
		return
	end
	local count = 0
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then
			count = count + 1
			if count > 10 then
				break
			end
			self:Reveal(child, count * 0.025)
		end
	end
end

function Window:MoveIndicator(tab, instant)
	local indicator = self.TabIndicator
	if not indicator or not tab then
		return
	end
	local height = Touch and 36 or 30
	local y = 8 + (tab.Index - 1) * (height + 4) + height / 2 - 8 - self.TabList.CanvasPosition.Y
	local goal = UDim2.fromOffset(0, y)
	indicator.Visible = true
	if instant then
		indicator.Position = goal
	else
		Animate(indicator, {Position = goal}, 0.22, Enum.EasingStyle.Back)
	end
end

function Window:SetFileName(name)
	name = tostring(name or "")
	name = string.gsub(name, "[\\/:*?\"<>|%c]", "")
	name = string.gsub(name, "^[%s%.]+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" then
		name = "Bio.Menu.txt"
	end
	if not string.find(name, "%.%w+$") then
		name = name .. ".txt"
	end
	if #name > 60 then
		name = string.sub(name, 1, 56) .. ".txt"
	end
	self.FileName = name
	return name
end

function Window:SetBorderThickness(value)
	value = math.clamp(math.floor(value + 0.5), 1, 6)
	self.BorderThickness = value
	if self.Edge then
		self.Edge.Position = UDim2.fromOffset(value, value)
		self.Edge.Size = UDim2.new(1, -2 * value, 1, -2 * value)
	end
	if self.EdgeStroke then
		self.EdgeStroke.Thickness = value
	end
end

function Window:Cursor(position, part, canvas)
	local x = position.X
	local y = position.Y
	part = part or self.Part
	canvas = canvas or Canvas3D
	if not self.Mode3D or not part then
		return Vector2.new(x, y)
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector2.new(x, y)
	end
	local ray = camera:ScreenPointToRay(x, y)
	local normal = part.CFrame.LookVector
	local denominator = ray.Direction:Dot(normal)
	if math.abs(denominator) < 0.0001 then
		return Vector2.new(-100000, -100000), -1, -1
	end
	local distance = (part.Position - ray.Origin):Dot(normal) / denominator
	local hit = ray.Origin + ray.Direction * distance
	local point = part.CFrame:PointToObjectSpace(hit)
	local size = part.Size
	local u = 0.5 - point.X / size.X
	local v = 0.5 - point.Y / size.Y
	return Vector2.new(u * canvas.X, v * canvas.Y), u, v
end

function Window:Tween3D(field, goal, duration, style, direction, done)
	if self.FlyLink then
		self.FlyLink:Disconnect()
		self.FlyLink = nil
	end
	local old = self.FlyTween
	self.FlyTween = nil
	if old then
		old:Cancel()
	end
	local holder = Create("NumberValue", {Value = self[field]})
	local link = holder:GetPropertyChangedSignal("Value"):Connect(function()
		self[field] = holder.Value
	end)
	self.FlyLink = link
	local tween = Animate(holder, {Value = goal}, duration, style, direction)
	self.FlyTween = tween
	tween.Completed:Connect(function(playback)
		if playback and playback ~= Enum.PlaybackState.Completed then
			return
		end
		if self.FlyTween ~= tween then
			return
		end
		link:Disconnect()
		self.FlyLink = nil
		self.FlyTween = nil
		self[field] = goal
		holder:Destroy()
		if done then
			done()
		end
	end)
end

function Window:ShowBar3D(show)
	if not show then
		self.Restore.Visible = false
		return
	end
	if not self.BarPart then
		local part = Create("Part", {
			Name = "Graphite3DBar" .. math.random(1000, 9999),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(BarCanvas.X / 100, BarCanvas.Y / 100, 0.05),
			CFrame = self.Part.CFrame,
			Parent = Workspace
		})
		local surface = Create("SurfaceGui", {
			Name = "Graphite3DBarGui",
			Face = Enum.NormalId.Front,
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
			CanvasSize = BarCanvas,
			Active = true,
			Adornee = part
		})
		surface.Parent = self.Surface.Parent
		self.BarPart = part
		self.BarSurface = surface
		self.RestoreSaved = {Anchor = self.Restore.AnchorPoint, Position = self.Restore.Position}
		self.Restore.Parent = surface
		self.Restore.AnchorPoint = Vector2.new(0.5, 0.5)
		self.Restore.Position = UDim2.fromScale(0.5, 0.5)
	end
	self.Restore.Visible = true
	self.RestoreScale.Scale = 0.6
	Animate(self.RestoreScale, {Scale = 1}, 0.28, Enum.EasingStyle.Back)
	if self.Place3D then
		self.Place3D(1)
	end
end

function Window:Fly3D(hide)
	local token = self.Token
	if hide then
		self:Tween3D("Fly", 1, 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
			if self.Token == token and self.Hidden and self.Mode3D then
				self.Body.Visible = false
				self:ShowBar3D(true)
			end
		end)
	else
		self:ShowBar3D(false)
		self:EnsureLogo()
		self.Body.Visible = true
		self:Tween3D("Fly", 0, 0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out, nil)
	end
end

function Window:DropIn()
	local main = self.Main
	local goal = main.Position
	local view = ViewSize(self.Gui)
	local height = main.Size.Y.Offset * self.TargetScale
	local fall = goal.Y.Scale * view.Y + height / 2 + 24
	local function At(offset)
		return UDim2.new(goal.X.Scale, goal.X.Offset, goal.Y.Scale, goal.Y.Offset + offset)
	end
	main.Visible = true
	main.GroupTransparency = self.Fade
	self.UIScale.Scale = self.TargetScale
	main.Position = At(-fall)
	local function Step(offset, time, direction, nextStep)
		local tween = Animate(main, {Position = At(offset)}, time, Enum.EasingStyle.Quad, direction)
		if nextStep then
			tween.Completed:Connect(nextStep)
		end
	end
	Step(0, 0.38, Enum.EasingDirection.In, function()
		Step(-fall * 0.14, 0.15, Enum.EasingDirection.Out, function()
			Step(0, 0.15, Enum.EasingDirection.In, function()
				Step(-fall * 0.05, 0.1, Enum.EasingDirection.Out, function()
					Step(0, 0.1, Enum.EasingDirection.In, function()
						self:Clamp()
					end)
				end)
			end)
		end)
	end)
end

function Window:ApplyAlpha()
	local panel = self.PanelAlpha or 0
	if self.TopBar then
		self.TopBar.BackgroundTransparency = panel
	end
	if self.Side then
		self.Side.BackgroundTransparency = panel
	end
	if self.Footer then
		self.Footer.BackgroundTransparency = panel
	end
	local kept = {}
	for _, row in ipairs(self.Rows) do
		if row.Parent then
			row.BackgroundTransparency = self.RowAlpha or 0
			row:SetAttribute("Goal", self.RowAlpha or 0)
			table.insert(kept, row)
		end
	end
	self.Rows = kept
end

function Window:SetBackground(image, opacity)
	local id = ParseImage(image)
	if opacity then
		self.BackOpacity = math.clamp(opacity, 0, 1)
	end
	self.BackImageId = id
	local label = self.BackImage
	if id then
		label.Image = id
		label.ImageTransparency = 1 - self.BackOpacity
		label.Visible = true
	else
		label.Visible = false
		label.Image = ""
	end
	self.PanelAlpha = id and 0.25 or 0
	self.RowAlpha = id and 0.2 or 0
	self:ApplyAlpha()
end

function Window:Redraw()
	local main = self.Main
	if self.Hidden or not main.Visible then
		return
	end
	main.Visible = false
	task.defer(function()
		if not self.Closed and not self.Hidden then
			main.Visible = true
		end
	end)
end

function Window:Start3D()
	self.Links3D = {}
	local function Link(signal, handler)
		local connection = signal:Connect(handler)
		table.insert(self.Connections, connection)
		table.insert(self.Links3D, connection)
	end

	local function Place(blend)
		local camera = Workspace.CurrentCamera
		local part = self.Part
		if not camera or not part then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local look = camera.CFrame.LookVector
		local base
		local character = LocalPlayer and LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if self.FollowMode == "Character" and root then
			local forward = root.CFrame.LookVector
			forward = Vector3.new(forward.X, 0, forward.Z)
			if forward.Magnitude < 0.01 then
				forward = Vector3.new(0, 0, -1)
			else
				forward = forward.Unit
			end
			base = root.Position + forward * self.Depth + Vector3.new(0, 1.5, 0)
		else
			base = cameraPosition + look * self.Depth
		end
		local anchor = base + Vector3.new(0, self.Fly * 70, 0) + look * (self.Away * 90)
		local tilt = self.Tilt
		tilt.x = tilt.x + (tilt.tx - tilt.x) * blend
		tilt.y = tilt.y + (tilt.ty - tilt.y) * blend
		local target = CFrame.lookAt(anchor, cameraPosition) * CFrame.Angles(math.rad(tilt.x), math.rad(tilt.y), 0)
		if blend >= 1 then
			part.CFrame = target
		else
			part.CFrame = part.CFrame:Lerp(target, blend)
		end
		local bar = self.BarPart
		if bar then
			local barTarget = CFrame.lookAt(base + Vector3.new(0, 2.6, 0), cameraPosition)
			if blend >= 1 then
				bar.CFrame = barTarget
			else
				bar.CFrame = bar.CFrame:Lerp(barTarget, blend)
			end
		end
	end
	self.Place3D = Place
	Place(1)

	Link(RunService.RenderStepped, function(delta)
		if self.Closed or not self.Mode3D then
			return
		end
		if self.FlyTween then
			Place(1)
		else
			Place(math.min(1, (delta or 0.016) * 12))
		end
	end)

	local active
	local function Apply(position)
		local _, u, v = self:Cursor(position)
		if u and u >= 0 and u <= 1 and v >= 0 and v <= 1 then
			self.Tilt.ty = (u - 0.5) * 2 * self.TiltMax
			self.Tilt.tx = (0.5 - v) * 2 * self.TiltMax * 0.8
			return true
		end
		return false
	end
	Link(UserInputService.InputBegan, function(input)
		if not self.Hidden and IsPointer(input) and Apply(input.Position) then
			active = input
		end
	end)
	Link(UserInputService.InputChanged, function(input)
		if not active then
			return
		end
		local match
		if active.UserInputType == Enum.UserInputType.Touch then
			match = input == active
		else
			match = input.UserInputType == Enum.UserInputType.MouseMovement
		end
		if match then
			Apply(input.Position)
		end
	end)
	Link(UserInputService.InputEnded, function(input)
		if active and input == active then
			active = nil
			self.Tilt.tx = 0
			self.Tilt.ty = 0
		end
	end)
end

function Window:Stop3D()
	self.Mode3D = false
	self.Leaving = false
	if self.FlyLink then
		self.FlyLink:Disconnect()
		self.FlyLink = nil
	end
	local old = self.FlyTween
	self.FlyTween = nil
	if old then
		old:Cancel()
	end
	self.Fly = 0
	self.Away = 0
	for _, connection in ipairs(self.Links3D or {}) do
		connection:Disconnect()
	end
	self.Links3D = nil
	self.Place3D = nil
	if self.BarPart then
		self.Restore.Parent = self.Gui
		local saved = self.RestoreSaved
		if saved then
			self.Restore.AnchorPoint = saved.Anchor
			self.Restore.Position = saved.Position
		end
		self.RestoreSaved = nil
		self.BarSurface:Destroy()
		self.BarPart:Destroy()
		self.BarSurface = nil
		self.BarPart = nil
		self.Restore.Visible = self.Hidden
		self:ClampRestore()
	end
	local saved = self.Saved2D
	local holder = self.Holder
	self.Body = self.Main
	if holder then
		for _, child in ipairs(self.Moved3D or {}) do
			if child.Parent == holder then
				child.Parent = self.Main
			end
		end
		holder:Destroy()
	end
	self.Holder = nil
	self.Moved3D = nil
	self.Main.Visible = not self.Hidden
	if self.Grip then
		self.Grip.Visible = not self.Locked and not self.Focus and not self.Mode3D
	end
	if saved then
		self.Main.Size = saved.Size
		self.Main.Position = saved.Position
		self.TargetScale = saved.Scale
		if not self.Hidden then
			self.UIScale.Scale = saved.Scale
		end
	end
	self.Saved2D = nil
	if self.Surface then
		self.Surface:Destroy()
	end
	if self.Part then
		self.Part:Destroy()
	end
	self.Surface = nil
	self.Part = nil
	self.Exit3D.Visible = false
	self.Tilt.tx = 0
	self.Tilt.ty = 0
	self.Tilt.x = 0
	self.Tilt.y = 0
	self:Clamp()
end

function Window:SetMode3D(state)
	state = state == true
	if state == self.Mode3D then
		return true
	end
	if not state then
		if self.Leaving then
			return true
		end
		if self.Closed or self.Hidden then
			self:Stop3D()
			return true
		end
		self.Leaving = true
		self:CloseDialog()
		self:Tween3D("Away", 1, 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
			if self.Closed or not self.Mode3D then
				return
			end
			self:Stop3D()
			self:DropIn()
		end)
		return true
	end
	if self.Leaving then
		return false, "Wait for the menu to finish moving"
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return false, "The camera is not ready yet"
	end
	if self.Gated then
		return false, "Wait until the menu has finished loading"
	end
	local part = Create("Part", {
		Name = "Graphite3D" .. math.random(1000, 9999),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(Canvas3D.X / 100, Canvas3D.Y / 100, 0.05),
		CFrame = camera.CFrame * CFrame.new(0, 0, -self.Depth),
		Parent = Workspace
	})
	local surface = Create("SurfaceGui", {
		Name = "Graphite3DGui",
		Face = Enum.NormalId.Front,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Canvas3D,
		Active = true,
		Adornee = part
	})
	local placed = false
	if LocalPlayer then
		placed = pcall(function()
			surface.Parent = LocalPlayer:WaitForChild("PlayerGui", 3)
		end) and surface.Parent ~= nil
	end
	if not placed then
		pcall(function()
			surface.Parent = self.Gui.Parent
		end)
	end
	if not surface.Parent then
		part:Destroy()
		surface:Destroy()
		return false, "The 3D menu could not be created here"
	end
	local main = self.Main
	self.Part = part
	self.Surface = surface
	self.Saved2D = {Size = main.Size, Position = main.Position, Scale = self.TargetScale}
	local holder = Create("Frame", {
		Name = "Body3D",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(
			math.min(self.Saved2D.Size.X.Offset, Canvas3D.X - 24),
			math.min(self.Saved2D.Size.Y.Offset, Canvas3D.Y - 24)
		),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = surface
	})
	self:Paint(holder, "BackgroundColor3", "Main")
	Round(holder, 4)
	local moved = {}
	for _, child in ipairs(main:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIScale") then
			table.insert(moved, child)
		end
	end
	self.Holder = holder
	self.Moved3D = moved
	self.Body = holder
	for _, child in ipairs(moved) do
		child.Parent = holder
	end
	main.Visible = false
	if self.Grip then
		self.Grip.Visible = false
	end
	self.TargetScale = 1
	if not self.Hidden then
		self.UIScale.Scale = 1
	end
	self.Mode3D = true
	self.Exit3D.Visible = true
	self.Fly = 1
	self.Away = 0
	self:Start3D()
	if self.Hidden then
		self:ShowBar3D(true)
	else
		self:Tween3D("Fly", 0, 0.85, Enum.EasingStyle.Back, Enum.EasingDirection.Out, nil)
	end
	return true
end

function Window:ApplySaved(saved)
	self.Loading = true
	for flag, raw in pairs(saved) do
		local object = self.Elements[flag]
		if object then
			pcall(function()
				object:Set(Decode(raw))
			end)
		end
	end
	self.Loading = false
	self.Dirty = false
end

function Window:MakeFooter()
	if self.Closed then
		return
	end
	local old = self.Footer
	self.Footer = nil
	self.Logo = nil
	if old then
		old:Destroy()
	end
	local footer = self:Make("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FooterHeight),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 60,
		BackgroundTransparency = self.PanelAlpha or 0,
		Parent = self.Body
	}, {BackgroundColor3 = "Top"})
	self:Make("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = footer
	}, {BackgroundColor3 = "Border"})
	local logo = Create("ImageLabel", {
		Name = "GraphiteLogo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 1),
		Size = UDim2.fromOffset(170, 38),
		BackgroundTransparency = 1,
		Image = LogoImage,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 62,
		Parent = footer
	})
	self.Footer = footer
	self.Logo = logo
	if self.AttachDrag then
		self.AttachDrag(footer)
	end
	self:GuardLogo(footer, logo)
end

function Window:GuardLogo(footer, logo)
	local function Fix()
		if self.Closed or self.Fixing then
			return
		end
		task.defer(function()
			if not self.Closed then
				self:EnsureLogo()
			end
		end)
	end
	for _, property in ipairs({"Parent", "Visible"}) do
		self:Connect(footer:GetPropertyChangedSignal(property), Fix)
	end
	for _, property in ipairs({"Parent", "Visible", "Image", "ImageTransparency", "Size"}) do
		self:Connect(logo:GetPropertyChangedSignal(property), Fix)
	end
	self:Connect(footer.Destroying, Fix)
	self:Connect(logo.Destroying, Fix)
end

function Window:EnsureLogo()
	if self.Closed or self.Fixing then
		return
	end
	local footer = self.Footer
	local logo = self.Logo
	local healthy = footer and logo
		and footer.Parent == self.Body and logo.Parent == footer
		and footer.Visible and logo.Visible
		and logo.Image == LogoImage
		and (logo.ImageTransparency or 0) == 0
		and logo.Size.X.Offset >= 120 and logo.Size.Y.Offset >= 28
		and footer.Size.Y.Offset >= FooterHeight
	if healthy then
		return
	end
	if (self.LogoFixes or 0) >= 25 then
		return
	end
	self.LogoFixes = (self.LogoFixes or 0) + 1
	self.Fixing = true
	self:MakeFooter()
	self.Fixing = false
end

function Window:OpenMenu()
	self.Gated = false
	if self.Closed then
		return
	end
	self:EnsureLogo()
	self.Main.Visible = true
	self.Main.GroupTransparency = 1
	self.UIScale.Scale = self.TargetScale * 0.85
	Animate(self.UIScale, {Scale = self.TargetScale}, 0.35, Enum.EasingStyle.Back)
	Animate(self.Main, {GroupTransparency = self.Fade}, 0.25)
	self.Born = os.clock()
	if self.CurrentTab then
		self:Stagger(self.CurrentTab.Page)
	end
end

function Window:GateCard(width, height)
	local card = self:Make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height or 0),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self.Gui
	}, {BackgroundColor3 = "Top"})
	Round(card, 5)
	local edge = Create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = card
	})
	Round(edge, 5)
	self:Stroke(edge, "Border")
	local pop = Create("UIScale", {Scale = 0.9, Parent = card})
	Animate(pop, {Scale = 1}, 0.3, Enum.EasingStyle.Back)
	Animate(card, {GroupTransparency = 0}, 0.2)
	return card
end

function Window:CloseCard(card, after)
	local tween = Animate(card, {GroupTransparency = 1}, 0.2)
	tween.Completed:Connect(function()
		card:Destroy()
		if after then
			after()
		end
	end)
end

function Window:ShowLoading(config, seconds, done)
	local card = self:GateCard(340, 214)
	Create("ImageLabel", {
		Name = "GraphiteLogo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(260, 66),
		BackgroundTransparency = 1,
		Image = LogoImage,
		ScaleType = Enum.ScaleType.Crop,
		Parent = card
	})
	local orbit = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Parent = card
	})
	local custom = ParseImage(config.Spinner)
	if custom then
		local paints = nil
		if not config.KeepSpinnerColor then
			paints = {ImageColor3 = "Accent"}
		end
		self:Make("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = custom,
			Parent = orbit
		}, paints)
	else
		local ring = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = orbit
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ring})
		local ringStroke = Create("UIStroke", {Thickness = 3, Transparency = 0.5, Parent = ring})
		self:Paint(ringStroke, "Color", "Stroke")
		local dot = self:Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(18, 4),
			Size = UDim2.fromOffset(9, 9),
			BorderSizePixel = 0,
			Parent = orbit
		}, {BackgroundColor3 = "Accent"})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = dot})
	end
	local spin = TweenService:Create(
		orbit,
		TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{Rotation = 360}
	)
	spin:Play()
	table.insert(self.Connections, {
		Disconnect = function()
			spin:Cancel()
		end
	})

	local first = config.Text or ("Loading " .. (config.Title or self.Name) .. "...")
	local status = self:Make("TextLabel", {
		Position = UDim2.fromOffset(20, 134),
		Size = UDim2.new(1, -40, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = first,
		Parent = card
	}, {TextColor3 = "Text"})
	local track = self:Make("Frame", {
		Position = UDim2.fromOffset(20, 160),
		Size = UDim2.new(1, -40, 0, 6),
		BorderSizePixel = 0,
		Parent = card
	}, {BackgroundColor3 = "Stroke"})
	Round(track, 3)
	local fill = self:Make("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BorderSizePixel = 0,
		Parent = track
	}, {BackgroundColor3 = "Accent"})
	Round(fill, 3)
	local tips = {
		"Drag the top bar to move the menu.",
		"Drag the bottom corner to resize it.",
		"Open Settings to change the colors.",
		"Press the + button to bring a hidden menu back."
	}
	self:Make("TextLabel", {
		Position = UDim2.fromOffset(20, 174),
		Size = UDim2.new(1, -90, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = config.Tip or tips[math.random(1, #tips)],
		Parent = card
	}, {TextColor3 = "Sub"})
	local percent = self:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 174),
		Size = UDim2.fromOffset(60, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0%",
		Parent = card
	}, {TextColor3 = "Text"})

	local stages = {first, "Preparing menu...", "Almost ready..."}
	local connection = fill:GetPropertyChangedSignal("Size"):Connect(function()
		local ratio = fill.Size.X.Scale
		percent.Text = string.format("%d%%", math.floor(ratio * 100 + 0.5))
		status.Text = stages[ratio < 0.4 and 1 or (ratio < 0.85 and 2 or 3)]
	end)
	table.insert(self.Connections, connection)
	local tween = Linear(fill, {Size = UDim2.new(1, 0, 1, 0)}, seconds)
	tween.Completed:Connect(function()
		connection:Disconnect()
		spin:Cancel()
		if self.Closed then
			return
		end
		percent.Text = "100%"
		self:CloseCard(card, done)
	end)
end

function Window:CheckKey(config, key)
	key = (string.gsub(tostring(key or ""), "^%s*(.-)%s*$", "%1"))
	if key == "" then
		return false
	end
	if type(config.Validate) == "function" then
		local ok, result = pcall(config.Validate, key)
		if ok and result then
			return true
		end
	end
	for _, valid in ipairs(config.Keys or {}) do
		if key == valid then
			return true
		end
	end
	if type(config.Url) == "string" then
		local ok, body = pcall(function()
			return game:HttpGet(config.Url)
		end)
		if ok and type(body) == "string" then
			for line in string.gmatch(body, "[^\r\n]+") do
				if (string.gsub(line, "^%s*(.-)%s*$", "%1")) == key then
					return true
				end
			end
		end
	end
	return false
end

function Window:ShowKeyGate(options, done)
	local config = options
	if type(config) == "string" then
		config = {Keys = {config}}
	elseif type(config) == "table" and config.Keys == nil and config.Url == nil and config.Validate == nil and config.Key == nil and #config > 0 then
		config = {Keys = config}
	end
	if type(config) ~= "table" then
		done()
		return
	end
	if config.Key and not config.Keys then
		config.Keys = {config.Key}
	end
	local links = {}
	if type(config.Links) == "table" then
		for _, link in ipairs(config.Links) do
			table.insert(links, link)
		end
	end
	if type(config.Link) == "string" then
		table.insert(links, config.Link)
	end
	local file = config.File or "Bio.Menu.Key.txt"
	local save = config.Save ~= false
	if save and type(isfile) == "function" and type(readfile) == "function" then
		local ok, saved = pcall(function()
			if isfile(file) then
				return readfile(file)
			end
		end)
		if ok and type(saved) == "string" and saved ~= "" and self:CheckKey(config, saved) then
			done()
			return
		end
	end

	local card = self:GateCard(330, nil)
	local body = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card
	})
	Pad(body, 18, 16, 18, 16)
	Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})
	local order = 0
	local function Next()
		order = order + 1
		return order
	end
	Create("ImageLabel", {
		Name = "GraphiteLogo",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 1,
		Image = LogoImage,
		ScaleType = Enum.ScaleType.Crop,
		Parent = body
	})
	self:Make("TextLabel", {
		LayoutOrder = Next(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Title or "Key System",
		Parent = body
	}, {TextColor3 = "Text"})
	self:Make("TextLabel", {
		LayoutOrder = Next(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Note or "Enter your key to continue.",
		Parent = body
	}, {TextColor3 = "Sub"})
	local linkBox
	if #links > 0 then
		linkBox = self:Make("TextBox", {
			LayoutOrder = Next(),
			Size = UDim2.new(1, 0, 0, 30),
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			ClearTextOnFocus = false,
			TextEditable = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = links[1],
			Parent = body
		}, {BackgroundColor3 = "Top", TextColor3 = "Sub"})
		Round(linkBox, 4)
		self:Stroke(linkBox)
	end
	local keyBox = self:Make("TextBox", {
		LayoutOrder = Next(),
		Size = UDim2.new(1, 0, 0, 36),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		PlaceholderText = "Enter your key",
		ClearTextOnFocus = false,
		Text = "",
		Parent = body
	}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
	Round(keyBox, 4)
	self:Stroke(keyBox)
	local status = self:Make("TextLabel", {
		LayoutOrder = Next(),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = body
	}, {TextColor3 = "Sub"})
	local buttons = Create("Frame", {
		LayoutOrder = Next(),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = body
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttons
	})

	local linkCount = math.min(#links, 3)
	local total = linkCount + 1
	local function MakeButton(text, index, callback)
		local button = self:Make("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1 / total, -8 * (total - 1) / total, 1, 0),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ClipsDescendants = true,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Text = text,
			Parent = buttons
		}, {BackgroundColor3 = "Element", TextColor3 = "Text"})
		Round(button, 4)
		Hover(self, button)
		self:Pressable(button)
		button.MouseButton1Click:Connect(callback)
		return button
	end

	local function SetStatus(text, kind)
		status.Text = text
		status.TextColor3 = kind == "error" and NoteColors.Error or (kind == "success" and NoteColors.Success or self.Theme.Sub)
	end

	local function Shake()
		if not self:Fancy() then
			return
		end
		local base = card.Position
		local offsets = {10, -10, 6, 0}
		local index = 0
		local function Step()
			index = index + 1
			local offset = offsets[index]
			if offset == nil then
				return
			end
			local tween = Animate(card, {Position = UDim2.new(base.X.Scale, base.X.Offset + offset, base.Y.Scale, base.Y.Offset)}, 0.05)
			tween.Completed:Connect(Step)
		end
		Step()
	end

	for index = 1, linkCount do
		local base = config.GetText or config.CopyText or "Get Key"
		local label = (type(config.LinkNames) == "table" and config.LinkNames[index]) or (linkCount > 1 and (base .. " " .. index) or base)
		MakeButton(label, index, function()
			local link = links[index]
			if linkBox then
				linkBox.Text = link
			end
			local copied = false
			if type(setclipboard) == "function" then
				copied = pcall(setclipboard, link)
			end
			SetStatus(copied and "Link copied. Open it in your browser." or "Copy the link above and open it in your browser.", "info")
		end)
	end

	local busy = false
	local function Submit()
		if busy then
			return
		end
		local text = keyBox.Text
		if text == "" then
			SetStatus("Please enter a key.", "error")
			Shake()
			return
		end
		busy = true
		SetStatus("Checking...", "info")
		task.spawn(function()
			local valid = self:CheckKey(config, text)
			busy = false
			if self.Closed then
				return
			end
			if valid then
				SetStatus("Key accepted.", "success")
				if save and type(writefile) == "function" then
					pcall(writefile, file, text)
				end
				self:CloseCard(card, done)
			else
				SetStatus("Wrong key. Try again.", "error")
				Shake()
			end
		end)
	end

	MakeButton(config.CheckText or "Check Key", total, Submit)
	keyBox.FocusLost:Connect(function(enter)
		if enter then
			Submit()
		end
	end)
end

function Window:RunGate(config)
	local seconds
	if config.Min and config.Max then
		local low = math.min(config.Min, config.Max)
		local high = math.max(config.Min, config.Max)
		seconds = low + math.random() * (high - low)
	else
		seconds = config.Time or config.Seconds or 5
	end
	seconds = math.clamp(seconds, 0.3, 120)
	local function Finish()
		if self.Closed then
			return
		end
		if config.Key then
			self:ShowKeyGate(config.Key, function()
				self:OpenMenu()
			end)
		else
			self:OpenMenu()
		end
	end
	self:ShowLoading(config, seconds, Finish)
end

function Window:Rebuild()
	self.Theme = BuildTheme(self.Base, self.TextColor, self.AccentColor, self.BorderColor)
	self:RunHooks()
end

function Window:SyncPickers()
	if self.MenuPicker then
		self.MenuPicker:Set(self.Base, true)
	end
	if self.TextPicker then
		self.TextPicker:Set(self.Theme.Text, true)
	end
	if self.AccentPicker then
		self.AccentPicker:Set(self.Theme.Accent, true)
	end
	if self.BorderPicker then
		self.BorderPicker:Set(self.Theme.Border, true)
	end
end

function Window:SetMenuColor(color)
	self.Base = color
	self:Rebuild()
	if not self.TextColor and self.TextPicker then
		self.TextPicker:Set(self.Theme.Text, true)
	end
	if not self.AccentColor and self.AccentPicker then
		self.AccentPicker:Set(self.Theme.Accent, true)
	end
	if not self.BorderColor and self.BorderPicker then
		self.BorderPicker:Set(self.Theme.Border, true)
	end
end

function Window:SetTextColor(color)
	self.TextColor = color
	self:Rebuild()
end

function Window:SetAccent(color)
	self.AccentColor = color
	self:Rebuild()
end

function Window:SetBorderColor(color)
	self.BorderColor = color
	self:Rebuild()
end

function Window:ResetColors()
	self.Base = DefaultBase
	self.TextColor = nil
	self.AccentColor = nil
	self.BorderColor = nil
	self:Rebuild()
	self:SyncPickers()
end

function Window:SetTitle(text)
	self.Name = text
	self.TitleLabel.Text = text
	self.BarLabel.Text = text
	local width = math.min(TextService:GetTextSize(text, 13, Enum.Font.GothamMedium, Vector2.new(400, 30)).X + 6, 170)
	self.TitleLabel.Size = UDim2.new(0, width, 1, 0)
	if self.Strip then
		local stripX = self.TitleOffset + width + 10
		self.Strip.Position = UDim2.fromOffset(stripX, 0)
		self.Strip.Size = UDim2.new(1, -(stripX + self.ButtonsWidth), 1, 0)
	end
end

function Window:Clamp()
	if self.Mode3D then
		return
	end
	local view = ViewSize(self.Gui)
	local scale = self.TargetScale
	local size = self.Main.Size
	local halfWidth = size.X.Offset * scale / 2
	local halfHeight = size.Y.Offset * scale / 2
	local margin = Touch and 110 or 90
	local cx = self.Main.Position.X.Scale * view.X
	local cy = self.Main.Position.Y.Scale * view.Y
	local minX = margin - halfWidth
	local maxX = math.max(minX, view.X - margin + halfWidth)
	local minY = halfHeight
	local maxY = math.max(minY, view.Y - 44 + halfHeight)
	cx = math.clamp(cx, minX, maxX)
	cy = math.clamp(cy, minY, maxY)
	self.Main.Position = UDim2.fromScale(cx / view.X, cy / view.Y)
end

function Window:ClampRestore()
	local view = ViewSize(self.Gui)
	local bar = self.Restore
	local width = bar.AbsoluteSize.X
	local height = bar.AbsoluteSize.Y
	local position = bar.Position
	local cx = position.X.Scale * view.X + position.X.Offset
	local cy = position.Y.Scale * view.Y + position.Y.Offset
	cx = math.clamp(cx, width / 2, math.max(width / 2, view.X - width / 2))
	cy = math.clamp(cy, 0, math.max(0, view.Y - height))
	bar.Position = UDim2.new(cx / view.X, 0, cy / view.Y, 0)
end

function Window:OnViewport()
	if self.Mode3D then
		return
	end
	local view = ViewSize(self.Gui)
	local size = self.Main.Size
	local fit = math.min((view.X - 20) / size.X.Offset, (view.Y - 20) / size.Y.Offset)
	self.AutoScale = math.clamp(math.min(view.X / (self.BaseSize.X + 40), view.Y / (self.BaseSize.Y + 40), 1), 0.5, 1)
	if self.TargetScale > fit then
		self:SetScale(math.max(fit, 0.5))
	end
	self:Clamp()
	self:ClampRestore()
end

function Window:SetScale(value, fromSlider)
	if self.Mode3D then
		return
	end
	value = math.clamp(value, 0.5, 1.6)
	self.TargetScale = value
	if not self.Hidden then
		self.UIScale.Scale = value
	end
	if self.ZoomSlider and not fromSlider then
		self.ZoomSlider:Set(math.floor(value * 100 + 0.5), true)
	end
	self:Clamp()
end

function Window:GetScale()
	return self.TargetScale
end

function Window:SetOpacity(percent)
	self.Fade = 1 - math.clamp(percent, 20, 100) / 100
	if not self.Hidden then
		self.Main.GroupTransparency = self.Fade
	end
end

function Window:ResetLayout()
	if self.Mode3D then
		return
	end
	self.Main.Size = UDim2.fromOffset(self.BaseSize.X, self.BaseSize.Y)
	self.Main.Position = UDim2.fromScale(0.5, 0.5)
	self:SetScale(self.AutoScale)
end

function Window:SetHidden(state)
	if self.Closed or self.Gated or self.Leaving or self.Hidden == state then
		return
	end
	self:CloseDialog()
	self.Hidden = state
	self.Token = self.Token + 1
	local token = self.Token
	if self.Mode3D then
		self:Fly3D(state)
		return
	end
	if state then
		Animate(self.UIScale, {Scale = self.TargetScale * 0.85}, 0.18)
		local tween = Animate(self.Main, {GroupTransparency = 1}, 0.18)
		tween.Completed:Connect(function()
			if self.Token == token and self.Hidden then
				self.Main.Visible = false
			end
		end)
		self.Restore.Visible = true
		self.RestoreScale.Scale = 0.6
		Animate(self.RestoreScale, {Scale = 1}, 0.28, Enum.EasingStyle.Back)
		self:ClampRestore()
	else
		self:EnsureLogo()
		self.Restore.Visible = false
		self.Main.Visible = true
		self.Main.GroupTransparency = 1
		self.UIScale.Scale = self.TargetScale * 0.85
		Animate(self.UIScale, {Scale = self.TargetScale}, 0.32, Enum.EasingStyle.Back)
		Animate(self.Main, {GroupTransparency = self.Fade}, 0.22)
		self:Clamp()
	end
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

function Window:CloseDialog()
	local overlay = self.ActiveDialog
	if overlay then
		self.ActiveDialog = nil
		overlay:Destroy()
	end
end

function Window:Dialog(config)
	config = config or {}
	self:CloseDialog()
	local inside = not self.Hidden
	local overlay = Create("Frame", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 100,
		Parent = inside and self.Body or self.Gui
	})
	self.ActiveDialog = overlay
	if inside then
		Animate(overlay, {BackgroundTransparency = 0.45}, 0.18)
	end

	local box = self:Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Parent = overlay
	}, {BackgroundColor3 = "Top"})
	Round(box, 5)
	self:Stroke(box, "Border")
	Pad(box, 14, 14, 14, 14)
	Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box})
	local boxScale = Create("UIScale", {Scale = 0.85, Parent = box})
	Animate(boxScale, {Scale = 1}, 0.24, Enum.EasingStyle.Back)

	if config.Title then
		self:Make("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = config.Title,
			Parent = box
		}, {TextColor3 = "Text"})
	end
	if config.Content then
		self:Make("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = config.Content,
			Parent = box
		}, {TextColor3 = "Text"})
	end

	local row = Create("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Touch and 38 or 32),
		BackgroundTransparency = 1,
		Parent = box
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row
	})

	local buttons = config.Buttons or {{Name = "OK"}}
	local count = #buttons
	for index, spec in ipairs(buttons) do
		local button = self:Make("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Text = spec.Name,
			Parent = row
		}, {BackgroundColor3 = "Element", TextColor3 = "Text"})
		Round(button, 4)
		button.ClipsDescendants = true
		Hover(self, button)
		self:Pressable(button)
		button.MouseButton1Click:Connect(function()
			self:CloseDialog()
			Fire(spec.Callback)
		end)
	end
end

function Window:Confirm(content, callback)
	self:Dialog({
		Content = content,
		Buttons = {
			{Name = "No"},
			{Name = "Yes", Callback = callback}
		}
	})
end

function Window:RequestClose()
	self:Confirm("Do you want to close the menu?", function()
		self:Destroy()
	end)
end

function Window:Destroy()
	if self.Closed then
		return
	end
	if self.Mode3D then
		self:Stop3D()
	end
	self.Closed = true
	local registry = GlobalEnv().GraphiteActive
	if type(registry) == "table" then
		local at = table.find(registry, self)
		if at then
			table.remove(registry, at)
		end
	end
	if ActiveWindow == self then
		ActiveWindow = nil
	end
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Restore.Visible = false
	self:CloseDialog()
	Animate(self.UIScale, {Scale = self.UIScale.Scale * 0.85}, 0.2)
	Animate(self.Main, {GroupTransparency = 1}, 0.2)
	local gui = self.Gui
	task.delay(0.3, function()
		gui:Destroy()
	end)
	Fire(self.OnClose)
end

function Window:Notify(config)
	config = config or {}
	if self.Closed then
		return
	end
	local theme = self.Theme
	local kind = config.Type
	local color = NoteColors[kind] or theme.Accent
	local glyphs = {Success = "OK", Warning = "!", Error = "x"}
	local glyph = glyphs[kind] or "i"
	local duration = config.Duration or 4

	while #self.NoteList >= 4 do
		local oldest = table.remove(self.NoteList, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	self.NoteOrder = self.NoteOrder + 1
	local holder = Create("Frame", {
		LayoutOrder = self.NoteOrder,
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Notes
	})
	table.insert(self.NoteList, holder)
	holder.Destroying:Connect(function()
		local index = table.find(self.NoteList, holder)
		if index then
			table.remove(self.NoteList, index)
		end
	end)

	local card = Create("CanvasGroup", {
		Position = UDim2.fromOffset(280, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Top,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = holder
	})
	Round(card, 5)

	local edge = Create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = card
	})
	Round(edge, 4)
	Create("UIStroke", {
		Color = theme.Border,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = edge
	})

	local icon = Create("Frame", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card
	})
	Round(icon, 10)
	Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Luma(color) > 0.55 and Color3.fromRGB(20, 20, 20) or Color3.new(1, 1, 1),
		Text = glyph,
		Parent = icon
	})

	local body = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card
	})
	Pad(body, 42, 9, 12, 12)
	Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})
	Create("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Title or "Notice",
		Parent = body
	})
	if config.Content then
		Create("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = theme.Sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = config.Content,
			Parent = body
		})
	end

	local bar = Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = card
	})

	local dismissed = false
	local function Dismiss()
		if dismissed then
			return
		end
		dismissed = true
		local tween = Animate(card, {Position = UDim2.fromOffset(280, 0), GroupTransparency = 1}, 0.25)
		tween.Completed:Connect(function()
			holder:Destroy()
		end)
	end

	local tap = Create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = card
	})
	tap.MouseButton1Click:Connect(Dismiss)

	Animate(card, {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}, 0.3, Enum.EasingStyle.Back)
	Linear(bar, {Size = UDim2.new(0, 0, 0, 2)}, duration).Completed:Connect(Dismiss)
end

function Window:CreateWatermark(config)
	config = config or {}
	local label = self:Make("TextLabel", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = config.Text or self.Name,
		Visible = config.Visible ~= false,
		Parent = self.Gui
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(label, 5)
	self:Stroke(label)
	Pad(label, 10, 0, 10, 0)

	local frames = 0
	local last = os.clock()
	self:Connect(RunService.RenderStepped, function()
		frames = frames + 1
		local now = os.clock()
		if now - last >= 1 then
			local fps = math.floor(frames / (now - last) + 0.5)
			frames = 0
			last = now
			local parts = {config.Text or self.Name}
			if config.ShowFPS ~= false then
				table.insert(parts, fps .. " FPS")
			end
			if config.ShowPing then
				local ok, ping = pcall(function()
					return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
				end)
				if ok then
					table.insert(parts, ping .. " ms")
				end
			end
			label.Text = table.concat(parts, "  |  ")
		end
	end)

	local object = {}
	function object:SetVisible(state)
		label.Visible = state
	end
	function object:Destroy()
		label:Destroy()
	end
	return object
end

function Window:SaveConfig(name)
	if type(writefile) ~= "function" then
		return false, "File access is not supported by this executor"
	end
	local data = {}
	for flag, object in pairs(self.Elements) do
		data[flag] = Encode(object:Get())
	end
	pcall(function()
		if type(isfolder) == "function" and not isfolder(self.Folder) then
			makefolder(self.Folder)
		end
	end)
	local ok, err = pcall(function()
		writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
	end)
	if ok then
		self.Dirty = false
	end
	return ok, err
end

function Window:LoadConfig(name)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false, "File access is not supported by this executor"
	end
	local path = self.Folder .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "Config not found"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then
		return false, (not ok) and tostring(data) or "Config is damaged"
	end
	self.Loading = true
	for flag, raw in pairs(data) do
		local object = self.Elements[flag]
		if object then
			pcall(function()
				object:Set(Decode(raw))
			end)
		end
	end
	self.Loading = false
	self.Dirty = false
	return true
end

function Window:BuildScriptFile()
	local data = {}
	for flag, object in pairs(self.Elements) do
		local ok, value = pcall(function()
			return object:Get()
		end)
		if ok and value ~= nil then
			data[flag] = Encode(value)
		end
	end
	local lines = {
		"do",
		"local g = type(getgenv) == \"function\" and getgenv() or _G",
		"g.GraphiteSaved = " .. Serialize(data)
	}
	local source = self.Source
	if type(source) ~= "string" or source == "" then
		table.insert(lines, "end")
	elseif string.match(source, "^https?://%S+$") then
		table.insert(lines, "end")
		table.insert(lines, "loadstring(game:HttpGet(" .. string.format("%q", source) .. "))()")
	else
		table.insert(lines, "g.GraphiteSourceText = " .. LongString(source))
		table.insert(lines, "end")
		table.insert(lines, "loadstring((type(getgenv) == \"function\" and getgenv() or _G).GraphiteSourceText)()")
	end
	return table.concat(lines, "\n") .. "\n"
end

function Window:SaveScriptFile()
	if type(writefile) ~= "function" then
		return false, "Files are only available in an executor"
	end
	local hasSource = type(self.Source) == "string" and self.Source ~= ""
	local ok, err = pcall(function()
		writefile(self.FileName, self:BuildScriptFile())
	end)
	if not ok then
		return false, err
	end
	self.Dirty = false
	return true, (not hasSource) and "settings only" or nil
end

function Window:RunScriptFile()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false, "Files are only available in an executor"
	end
	if not isfile(self.FileName) then
		return false, self.FileName .. " was not found. Press Create File first"
	end
	if type(loadstring) ~= "function" then
		return false, "This executor cannot run scripts"
	end
	local read, content = pcall(readfile, self.FileName)
	if not read or type(content) ~= "string" or content == "" then
		return false, "The saved file could not be read"
	end
	local chunk = loadstring(content)
	if type(chunk) ~= "function" then
		return false, "The saved file is damaged"
	end
	task.spawn(function()
		local shared = GlobalEnv()
		shared.GraphiteSaved = nil
		local before = shared.GraphiteWindows or 0
		local passed, problem = pcall(chunk)
		if passed then
			if (shared.GraphiteWindows or 0) > before then
				shared.GraphiteSaved = nil
				self:Destroy()
			else
				local saved = shared.GraphiteSaved
				shared.GraphiteSaved = nil
				if type(saved) == "table" then
					self:ApplySaved(saved)
				end
				self:Status("Loaded", self.FileName)
			end
		else
			warn("[Graphite] " .. tostring(problem))
			if not self.Closed then
				self:Status("Error", "The saved file failed to run")
			end
		end
	end)
	return true
end

function Window:SelectTab(tab)
	local previous = self.CurrentTab
	for _, other in ipairs(self.Tabs) do
		other.Active = other == tab
		other.Page.Visible = other.Active
		other.Render(0.14)
	end
	for _, child in ipairs(self.Content:GetChildren()) do
		if child ~= tab.Page and child:IsA("ScrollingFrame") then
			child.Visible = false
		end
	end
	self.CurrentTab = tab
	if not tab.IsSettings then
		self.LastContentTab = tab
	end
	self:MoveIndicator(tab, previous == nil)
	if previous ~= tab and self:Fancy() then
		if tab.PageTween then
			tab.PageTween:Cancel()
		end
		tab.Page.Position = UDim2.fromOffset(0, 14)
		tab.PageTween = Animate(tab.Page, {Position = UDim2.fromOffset(0, 0)}, 0.2)
		self:Stagger(tab.Page)
	elseif previous ~= tab then
		tab.Page.Position = UDim2.fromOffset(0, 0)
	end
end

function Window:CreateTab(name, icon)
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = name or "Tab"
	tab.Order = 0
	tab.Active = false
	tab.Index = #self.Tabs + 1

	local button = Create("TextButton", {
		Name = tab.Name,
		Size = UDim2.new(1, 0, 0, Touch and 36 or 30),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = tab.Index,
		Parent = self.TabList
	})
	Round(button, 4)

	local textOffset = 12
	local iconLabel
	local image = ParseImage(icon)
	if image then
		iconLabel = Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = image,
			Parent = button
		})
		textOffset = 34
	end

	local label = Create("TextLabel", {
		Position = UDim2.fromOffset(textOffset, 0),
		Size = UDim2.new(1, -textOffset - 6, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tab.Name,
		Parent = button
	})

	local page = self:Make("ScrollingFrame", {
		Name = tab.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Content
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page})
	Pad(page, 10, 10, 12, 10)

	tab.Button = button
	tab.Page = page
	tab.Scroller = page
	tab.Root = tab
	tab.Controls = {}

	function tab.Render(time)
		local theme = self.Theme
		Animate(button, {
			BackgroundTransparency = tab.Active and 0 or 1,
			BackgroundColor3 = tab.Active and theme.Hover or theme.Element
		}, time)
		Animate(label, {TextColor3 = tab.Active and theme.Text or theme.Sub}, time)
		if iconLabel then
			Animate(iconLabel, {ImageColor3 = tab.Active and theme.Text or theme.Sub}, time)
		end
	end

	self:Bind(function()
		tab.Render(0)
	end)

	if self:Fancy() and self:IsFresh() then
		label.TextTransparency = 1
		if iconLabel then
			iconLabel.ImageTransparency = 1
		end
		task.delay(0.1 + tab.Index * 0.05, function()
			if label.Parent then
				Animate(label, {TextTransparency = 0}, 0.25)
				if iconLabel then
					Animate(iconLabel, {ImageTransparency = 0}, 0.25)
				end
			end
		end)
	end

	button.MouseEnter:Connect(function()
		if CanHover() and not tab.Active then
			Animate(button, {BackgroundTransparency = 0.6}, 0.1)
		end
	end)
	button.MouseLeave:Connect(function()
		if not tab.Active then
			Animate(button, {BackgroundTransparency = 1}, 0.1)
		end
	end)
	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

local function NewRow(tab, height, class, image)
	tab.Order = tab.Order + 1
	local row = tab.Window:Make(class or "Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder = tab.Order,
		Parent = tab.Page
	}, {BackgroundColor3 = "Element"})
	if class == "TextButton" then
		row.Text = ""
		row.AutoButtonColor = false
		row.ClipsDescendants = true
	end
	Round(row, 4)
	tab.Window:Stroke(row, "Stroke", 0.6)
	local win = tab.Window
	row.BackgroundTransparency = win.RowAlpha or 0
	table.insert(win.Rows, row)
	if image then
		local picture = Create("ImageLabel", {
			Name = "RowImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = ParseImage(image),
			ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = 0.55,
			ZIndex = 0,
			Parent = row
		})
		Round(picture, 4)
	end
	if win:IsFresh() and tab.Page.Visible then
		win:Reveal(row, math.min(tab.Order, 10) * 0.03)
	end
	return row
end

local function RowLabel(win, row, text, reserve, icon, desc, keepColor)
	local offset = 12
	local image = ParseImage(icon)
	if image then
		local paints = nil
		if not keepColor then
			paints = {ImageColor3 = "Text"}
		end
		win:Make("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0, row.Size.Y.Offset / 2),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Image = image,
			Parent = row
		}, paints)
		offset = 38
	end
	local width = -(offset + (reserve or 24) - 12)
	local label = win:Make("TextLabel", {
		Position = UDim2.fromOffset(offset, desc and 5 or 0),
		Size = UDim2.new(1, width, 0, desc and 20 or RowHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		Parent = row
	}, {TextColor3 = "Text"})
	local note
	if desc then
		note = win:Make("TextLabel", {
			Position = UDim2.fromOffset(offset, 25),
			Size = UDim2.new(1, width, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = desc,
			Parent = row
		}, {TextColor3 = "Sub"})
	end
	return label, note
end

local function Register(win, flag, object)
	if flag then
		win.Elements[flag] = object
		local saved = win.Pending and win.Pending[flag]
		if saved ~= nil then
			win.Loading = true
			pcall(function()
				object:Set(Decode(saved))
			end)
			win.Loading = false
		end
	end
end

function Tab:Track(object, default)
	local root = self.Root or self
	if root.Controls then
		table.insert(root.Controls, {object = object, default = default})
	end
	return object
end

function Tab:CreateGroup(config)
	config = config or {}
	local win = self.Window
	self.Order = self.Order + 1
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self.Order,
		Parent = self.Page
	})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})

	local header = win:Make("TextButton", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, RowHeight - 4),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Text = "",
		Parent = holder
	}, {BackgroundColor3 = "Element"})
	Round(header, 4)
	win:Stroke(header, "Stroke", 0.6)
	Hover(win, header)
	win:Pressable(header)
	local title = win:Make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = config.Name or "Group",
		Parent = header
	}, {TextColor3 = "Text"})
	local mark = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(18, RowHeight - 4),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "-",
		Parent = header
	}, {TextColor3 = "Sub"})

	local clip = Create("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = holder
	})
	local body = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = clip
	})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})
	Pad(body, 8, 0, 0, 0)

	local open = config.Open ~= false
	local height = 0
	local token = 0
	mark.Text = open and "-" or "+"
	clip.Visible = open

	local function Measure()
		return body.AbsoluteSize.Y / math.max(win.UIScale.Scale, 0.01)
	end

	local function Apply(state, animate)
		open = state
		mark.Text = open and "-" or "+"
		token = token + 1
		local current = token
		local moving = animate and win:Fancy()
		if moving then
			mark.Rotation = -90
			Animate(mark, {Rotation = 0}, 0.2)
		end
		if open then
			clip.Visible = true
			if moving and height > 1 then
				clip.AutomaticSize = Enum.AutomaticSize.None
				clip.Size = UDim2.new(1, 0, 0, 0)
				local tween = Animate(clip, {Size = UDim2.new(1, 0, 0, height)}, 0.22)
				tween.Completed:Connect(function()
					if token == current and open then
						clip.AutomaticSize = Enum.AutomaticSize.Y
						clip.Size = UDim2.new(1, 0, 0, 0)
					end
				end)
			else
				clip.AutomaticSize = Enum.AutomaticSize.Y
				clip.Size = UDim2.new(1, 0, 0, 0)
			end
		else
			height = math.max(Measure(), height)
			if moving and height > 1 then
				clip.AutomaticSize = Enum.AutomaticSize.None
				clip.Size = UDim2.new(1, 0, 0, height)
				local tween = Animate(clip, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
				tween.Completed:Connect(function()
					if token == current and not open then
						clip.Visible = false
					end
				end)
			else
				clip.Visible = false
			end
		end
	end

	header.MouseButton1Click:Connect(function()
		Apply(not open, true)
	end)
	table.insert(win.Groups, {
		Set = function(state)
			if state ~= open then
				Apply(state, true)
			end
		end,
		Open = function()
			return open
		end
	})

	local group = setmetatable({}, Tab)
	group.Window = win
	group.Page = body
	group.Scroller = self.Scroller
	group.Root = self.Root or self
	group.Order = 0
	group.Title = title
	return group
end

function Tab:CreateSection(text)
	local win = self.Window
	self.Order = self.Order + 1
	local caption = string.upper(text or "Section")
	local width = TextService:GetTextSize(caption, 11, Enum.Font.GothamBold, Vector2.new(1000, 22)).X
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = self.Order,
		Parent = self.Page
	})
	local label = win:Make("TextLabel", {
		Size = UDim2.fromOffset(width + 2, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = caption,
		Parent = holder
	}, {TextColor3 = "Sub"})
	win:Make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, width + 12, 0.5, 1),
		Size = UDim2.new(1, -(width + 12), 0, 1),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = holder
	}, {BackgroundColor3 = "Stroke"})
	return label
end

function Tab:CreateDivider()
	self.Order = self.Order + 1
	return self.Window:Make("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		LayoutOrder = self.Order,
		Parent = self.Page
	}, {BackgroundColor3 = "Stroke"})
end

function Tab:CreateLabel(text)
	local win = self.Window
	local row = NewRow(self, 30)
	local label = RowLabel(win, row, text or "Label")
	label.Size = UDim2.new(1, -24, 1, 0)
	win:Paint(label, "TextColor3", "Sub")
	local object = {}
	function object:SetText(value)
		label.Text = value
	end
	return object
end

function Tab:CreateParagraph(config)
	config = config or {}
	local win = self.Window
	self.Order = self.Order + 1
	local row = win:Make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		LayoutOrder = self.Order,
		Parent = self.Page
	}, {BackgroundColor3 = "Element"})
	Round(row, 4)
	win:Stroke(row, "Stroke", 0.6)
	Pad(row, 12, 9, 12, 9)
	Create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})
	local title = win:Make("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Title or "Title",
		Parent = row
	}, {TextColor3 = "Text"})
	local content = win:Make("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Content or "",
		Parent = row
	}, {TextColor3 = "Sub"})
	local object = {}
	function object:SetTitle(value)
		title.Text = value
	end
	function object:SetContent(value)
		content.Text = value
	end
	return object
end

function Tab:CreateImage(config)
	config = config or {}
	local row = NewRow(self, config.Height or 120)
	row.ClipsDescendants = true
	local image = Create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = ParseImage(config.Image) or "",
		ScaleType = config.Crop and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
		Parent = row
	})
	Round(image, 4)
	local object = {}
	function object:SetImage(id)
		image.Image = ParseImage(id) or ""
	end
	return object
end

function Tab:CreateGallery(config)
	config = config or {}
	local win = self.Window
	local titled = config.Name ~= nil
	local top = titled and 24 or 0
	local row = NewRow(self, top + 90)
	if titled then
		local title = RowLabel(win, row, config.Name)
		title.Size = UDim2.new(1, -24, 0, 24)
	end
	local scroller = win:Make("ScrollingFrame", {
		Position = UDim2.fromOffset(6, top + 2),
		Size = UDim2.new(1, -12, 1, -(top + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = row
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller
	})
	Pad(scroller, 2, 2, 2, 8)

	local count = 0
	local object = {}
	function object:Add(spec)
		count = count + 1
		local item = win:Make("TextButton", {
			LayoutOrder = count,
			Size = UDim2.fromOffset(76, 72),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = scroller
		}, {BackgroundColor3 = "Hover"})
		Round(item, 4)
		Create("ImageLabel", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(64, 44),
			BackgroundTransparency = 1,
			Image = ParseImage(spec.Image) or "",
			ScaleType = Enum.ScaleType.Fit,
			Parent = item
		})
		win:Make("TextLabel", {
			Position = UDim2.fromOffset(2, 53),
			Size = UDim2.new(1, -4, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = spec.Name or "",
			Parent = item
		}, {TextColor3 = "Sub"})
		item.MouseButton1Click:Connect(function()
			Fire(spec.Callback or config.Callback, spec)
		end)
	end
	function object:Clear()
		for _, child in ipairs(scroller:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		count = 0
	end
	for _, spec in ipairs(config.Items or {}) do
		object:Add(spec)
	end
	return object
end

function Tab:CreateButton(config)
	config = config or {}
	local win = self.Window
	local height = config.Description and (RowHeight + 20) or (RowHeight + 6)
	local row = NewRow(self, height, "TextButton", config.Image)
	local label, note = RowLabel(win, row, config.Name or "Button", 84, config.Icon, config.Description, config.KeepIconColor)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	if note then
		label.Position = UDim2.new(0, label.Position.X.Offset, 0, 9)
		note.Position = UDim2.new(0, note.Position.X.Offset, 0, 31)
	else
		label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 1, 0)
	end
	Hover(win, row)
	win:Pressable(row)

	local bar = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BorderSizePixel = 0,
		Parent = row
	})
	Round(bar, 2)
	win:Bind(function()
		bar.BackgroundColor3 = config.Danger and NoteColors.Error or win.Theme.Accent
	end)
	row.MouseEnter:Connect(function()
		if CanHover() then
			Animate(bar, {Size = UDim2.fromOffset(3, height - 20)}, 0.14)
		end
	end)
	row.MouseLeave:Connect(function()
		Animate(bar, {Size = UDim2.fromOffset(3, 0)}, 0.14)
	end)

	local status = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(72, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
		Text = "",
		Parent = row
	}, {TextColor3 = "Sub"})

	local token = 0
	local function Show(text, color)
		token = token + 1
		local current = token
		status.Text = text
		status.TextColor3 = color
		status.TextTransparency = 1
		Animate(status, {TextTransparency = 0}, 0.12)
		task.delay(1.4, function()
			if current == token and status.Parent then
				Animate(status, {TextTransparency = 1}, 0.25)
			end
		end)
	end

	local function Run()
		FireWith(config.Callback, function(ok)
			if win.Closed or not row.Parent then
				return
			end
			if ok then
				Show("OK", NoteColors.Success)
				row.BackgroundColor3 = win.Theme.Element:Lerp(NoteColors.Success, 0.28)
			else
				Show("Failed", NoteColors.Error)
				row.BackgroundColor3 = win.Theme.Element:Lerp(NoteColors.Error, 0.28)
			end
			Animate(row, {BackgroundColor3 = win.Theme.Element}, 0.5)
		end)
	end
	row.MouseButton1Click:Connect(Run)

	local object = {}
	function object:SetText(value)
		label.Text = value
	end
	function object:SetDescription(value)
		if note then
			note.Text = value
		end
	end
	function object:Run()
		Run()
	end
	return object
end

function Tab:CreateToggle(config)
	config = config or {}
	local win = self.Window
	local state = config.Default == true
	local row = NewRow(self, config.Description and (RowHeight + 14) or RowHeight, "TextButton", config.Image)
	RowLabel(win, row, config.Name or "Toggle", 70, config.Icon, config.Description, config.KeepIconColor)
	Hover(win, row)
	win:Pressable(row)

	local track = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BorderSizePixel = 0,
		Parent = row
	})
	Round(track, 11)
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track
	})
	Round(knob, 8)

	local function Render(time)
		Animate(track, {BackgroundColor3 = state and win.Theme.Accent or win.Theme.Stroke}, time)
		Animate(knob, {Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)}, time, Enum.EasingStyle.Back)
	end

	local function Pulse()
		if not win:Fancy() then
			return
		end
		local ring = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -11, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = track
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ring})
		local stroke = Create("UIStroke", {Color = win.Theme.Accent, Thickness = 2, Transparency = 0.2, Parent = ring})
		Animate(ring, {Size = UDim2.fromOffset(36, 36)}, 0.4)
		local tween = Animate(stroke, {Transparency = 1}, 0.4)
		tween.Completed:Connect(function()
			ring:Destroy()
		end)
	end

	win:Bind(function()
		Render(0)
	end)

	local object = {}
	function object:Set(value, silent)
		local was = state
		state = value == true
		Render(0.18)
		if state and not was and not silent then
			Pulse()
		end
		if not silent then
			win:Touch(config.Flag)
			if state and config.Important and win:Fancy() then
				row.BackgroundColor3 = win.Theme.Accent
				Animate(row, {BackgroundColor3 = win.Theme.Element}, 0.5)
			end
			Fire(config.Callback, state)
		end
	end
	function object:Get()
		return state
	end
	Register(win, config.Flag, object)

	row.MouseButton1Click:Connect(function()
		object:Set(not state)
	end)
	return self:Track(object, config.Default == true)
end

function Tab:CreateSlider(config)
	config = config or {}
	local win = self.Window
	local min = config.Min or 0
	local max = config.Max or 100
	local step = config.Increment or 1
	if step <= 0 then
		step = 1
	end
	local suffix = config.Suffix
	if suffix == nil then
		suffix = "%"
	end
	local default = math.clamp(config.Default or min, min, max)
	local value = default
	local decimals = 0
	local probe = step
	while decimals < 4 and math.abs(probe - math.floor(probe + 0.0001)) > 0.0001 do
		probe = probe * 10
		decimals = decimals + 1
	end
	local function Format(number)
		return string.format("%." .. decimals .. "f", number)
	end
	local stepper = config.Stepper ~= false
	local reserve = stepper and 148 or 92
	local row = NewRow(self, RowHeight + 52, nil, config.Image)

	local title = RowLabel(win, row, config.Name or "Slider", 24, config.Icon, nil, config.KeepIconColor)
	title.Font = Enum.Font.GothamMedium
	title.Size = UDim2.new(1, -(title.Position.X.Offset + reserve), 0, RowHeight)

	local controlY = (RowHeight - 26) / 2
	local box = win:Make("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, stepper and -40 or -10, 0, controlY),
		Size = UDim2.fromOffset(72, 26),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		ClearTextOnFocus = false,
		Text = "",
		Parent = row
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(box, 4)
	win:Stroke(box)

	local function StepButton(text, offset)
		local button = win:Make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, offset, 0, controlY),
			Size = UDim2.fromOffset(26, 26),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ClipsDescendants = true,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Text = text,
			Parent = row
		}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
		Round(button, 4)
		win:Stroke(button)
		Hover(win, button, "Top", "Hover")
		win:Pressable(button, "Top")
		return button
	end

	local trackY = RowHeight + 6
	local track = win:Make("Frame", {
		Position = UDim2.new(0, 14, 0, trackY),
		Size = UDim2.new(1, -28, 0, 8),
		BorderSizePixel = 0,
		Parent = row
	}, {BackgroundColor3 = "Stroke"})
	Round(track, 4)
	local fill = win:Make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = track
	}, {BackgroundColor3 = "Accent"})
	Round(fill, 4)
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		Rotation = 90,
		Parent = fill
	})
	local glow = Create("UIStroke", {Thickness = 0, Transparency = 0.55, Parent = fill})
	win:Paint(glow, "Color", "Accent")

	local divisions = (max - min) / step
	local tickCount = 0
	if config.Ticks == false or max == min then
		tickCount = 0
	elseif type(config.Ticks) == "number" then
		tickCount = math.clamp(math.floor(config.Ticks), 1, 20)
	elseif divisions <= 20 then
		tickCount = math.max(math.floor(divisions + 0.5), 1)
	else
		tickCount = 4
	end
	if tickCount > 0 then
		local marks = Create("Frame", {
			Position = UDim2.new(0, 14, 0, trackY + 19),
			Size = UDim2.new(1, -28, 0, 8),
			BackgroundTransparency = 1,
			Parent = row
		})
		for index = 0, tickCount do
			local tall = index == 0 or index == tickCount
			win:Make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(index / tickCount, 0),
				Size = UDim2.fromOffset(1, tall and 7 or 4),
				BorderSizePixel = 0,
				Parent = marks
			}, {BackgroundColor3 = "Stroke"})
		end
	end

	if config.ShowRange ~= false then
		win:Make("TextLabel", {
			Position = UDim2.new(0, 14, 0, trackY + 30),
			Size = UDim2.fromOffset(90, 12),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Format(min) .. suffix,
			Parent = row
		}, {TextColor3 = "Sub"})
		win:Make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, trackY + 30),
			Size = UDim2.fromOffset(90, 12),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Format(max) .. suffix,
			Parent = row
		}, {TextColor3 = "Sub"})
	end

	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track
	})
	Round(knob, 9)
	win:Make("UIStroke", {Thickness = 2, Parent = knob}, {Color = "Accent"})
	local bubble = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		TextTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = "",
		ZIndex = 6,
		Parent = knob
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(bubble, 4)
	Pad(bubble, 8, 0, 8, 0)

	local hit = Create("TextButton", {
		Position = UDim2.new(0, 6, 0, RowHeight - 2),
		Size = UDim2.new(1, -12, 0, 30),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row
	})

	local object = {Default = default}
	function object:Set(newValue, silent, smooth)
		newValue = math.clamp(newValue, min, max)
		newValue = math.floor((newValue - min) / step + 0.5) * step + min
		newValue = math.clamp(tonumber(string.format("%.4f", newValue)), min, max)
		value = newValue
		local alpha = max == min and 0 or (value - min) / (max - min)
		if smooth and win:Fancy() then
			Animate(fill, {Size = UDim2.fromScale(alpha, 1)}, 0.12)
			Animate(knob, {Position = UDim2.fromScale(alpha, 0.5)}, 0.12)
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		end
		local text = Format(value) .. suffix
		box.Text = text
		bubble.Text = text
		if not silent then
			win:Touch(config.Flag)
			Fire(config.Callback, value)
		end
	end
	function object:Get()
		return value
	end
	object:Set(value, true)
	Register(win, config.Flag, object)

	if stepper then
		StepButton("-", -116).MouseButton1Click:Connect(function()
			object:Set(value - step, false, true)
		end)
		StepButton("+", -10).MouseButton1Click:Connect(function()
			object:Set(value + step, false, true)
		end)
	end

	box.Focused:Connect(function()
		box.Text = Format(value)
	end)
	box.FocusLost:Connect(function()
		local parsed = tonumber(string.match(box.Text, "-?%d+%.?%d*"))
		if parsed then
			object:Set(parsed, false, true)
		else
			object:Set(value, true)
		end
	end)

	win:Slide(hit, function(position)
		local alpha = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		object:Set(min + (max - min) * alpha)
	end, self.Scroller, function()
		if win:Fancy() then
			Animate(glow, {Thickness = 4}, 0.15)
		end
		Animate(knob, {Size = UDim2.fromOffset(21, 21)}, 0.12, Enum.EasingStyle.Back)
		Animate(bubble, {BackgroundTransparency = 0, TextTransparency = 0}, 0.12)
	end, function()
		Animate(glow, {Thickness = 0}, 0.2)
		Animate(knob, {Size = UDim2.fromOffset(18, 18)}, 0.12)
		Animate(bubble, {BackgroundTransparency = 1, TextTransparency = 1}, 0.15)
	end)
	return self:Track(object, default)
end

function Tab:CreateProgress(config)
	config = config or {}
	local win = self.Window
	local value = math.clamp(config.Default or 0, 0, 100)
	local row = NewRow(self, 46)
	local title = RowLabel(win, row, config.Name or "Progress", 24, config.Icon, nil, config.KeepIconColor)
	title.Size = UDim2.new(1, -(title.Position.X.Offset + 70), 0, 28)
	local readout = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.fromOffset(60, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row
	}, {TextColor3 = "Sub"})
	local track = win:Make("Frame", {
		Position = UDim2.new(0, 12, 0, 32),
		Size = UDim2.new(1, -24, 0, 6),
		BorderSizePixel = 0,
		Parent = row
	}, {BackgroundColor3 = "Stroke"})
	Round(track, 3)
	local fill = win:Make("Frame", {
		Size = UDim2.fromScale(value / 100, 1),
		BorderSizePixel = 0,
		Parent = track
	}, {BackgroundColor3 = "Accent"})
	Round(fill, 3)
	local object = {}
	function object:Set(newValue)
		value = math.clamp(newValue, 0, 100)
		Animate(fill, {Size = UDim2.fromScale(value / 100, 1)}, 0.2)
		readout.Text = string.format("%d%%", math.floor(value + 0.5))
	end
	function object:Get()
		return value
	end
	object:Set(value)
	return object
end

function Tab:CreateInput(config)
	config = config or {}
	local win = self.Window
	local row = NewRow(self, RowHeight)
	RowLabel(win, row, config.Name or "Input", 170, config.Icon, nil, config.KeepIconColor)
	local box = win:Make("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(140, RowHeight - 12),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		PlaceholderText = config.Placeholder or "Type here",
		ClearTextOnFocus = config.ClearOnFocus == true,
		Text = config.Default or "",
		Parent = row
	}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
	Round(box, 5)
	win:Stroke(box)
	local last = box.Text
	box.FocusLost:Connect(function(enter)
		if box.Text ~= last then
			last = box.Text
			win:Touch(config.Flag)
		end
		Fire(config.Callback, box.Text, enter)
	end)
	local object = {}
	function object:Set(value, silent)
		box.Text = tostring(value)
		last = box.Text
		if not silent then
			win:Touch(config.Flag)
			Fire(config.Callback, box.Text, true)
		end
	end
	function object:Get()
		return box.Text
	end
	Register(win, config.Flag, object)
	return self:Track(object, config.Default or "")
end

function Tab:CreateKeybind(config)
	config = config or {}
	local win = self.Window
	local key = config.Default or Enum.KeyCode.Unknown
	local listening = false
	local row = NewRow(self, RowHeight)
	RowLabel(win, row, config.Name or "Keybind", 110, config.Icon, nil, config.KeepIconColor)
	local button = win:Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(84, RowHeight - 12),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Parent = row
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(button, 5)
	win:Stroke(button)

	local function Render()
		button.Text = key == Enum.KeyCode.Unknown and "None" or key.Name
	end
	Render()

	button.MouseButton1Click:Connect(function()
		listening = true
		button.Text = "..."
	end)

	win:Connect(UserInputService.InputBegan, function(input, processed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				key = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
				Render()
				win:Touch(config.Flag)
				Fire(config.Changed, key)
			end
			return
		end
		if not processed and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
			Fire(config.Callback, key)
		end
	end)

	local object = {}
	function object:Set(value)
		key = value
		Render()
		Fire(config.Changed, key)
	end
	function object:Get()
		return key
	end
	Register(win, config.Flag, object)
	return self:Track(object, config.Default or Enum.KeyCode.Unknown)
end

function Tab:CreateDropdown(config)
	config = config or {}
	local win = self.Window
	local multi = config.Multi == true
	local options = config.Options or {}
	local single
	local chosen = {}
	local open = false
	local buttons = {}
	local marks = {}
	local optionHeight = RowHeight - 10

	local row = NewRow(self, RowHeight)
	row.ClipsDescendants = true
	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, RowHeight),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row
	})
	local title = RowLabel(win, row, config.Name or "Dropdown", 24, config.Icon, nil, config.KeepIconColor)
	title.Size = UDim2.new(0.5, -title.Position.X.Offset, 0, RowHeight)
	local readout = win:Make("TextLabel", {
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.5, -34, 0, RowHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "None",
		Parent = row
	}, {TextColor3 = "Sub"})
	local mark = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(18, RowHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "+",
		Parent = row
	}, {TextColor3 = "Sub"})
	local list = win:Make("ScrollingFrame", {
		Position = UDim2.fromOffset(8, RowHeight + 4),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = row
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})

	local function ListHeight()
		return math.min(#options * (optionHeight + 3), 150)
	end

	local function Resize()
		list.Size = UDim2.new(1, -16, 0, ListHeight())
		Animate(row, {Size = UDim2.new(1, 0, 0, open and (RowHeight + 4 + ListHeight() + 8) or RowHeight)}, 0.2)
		mark.Text = open and "-" or "+"
		if open and win:Fancy() then
			local index = 0
			for _, option in ipairs(options) do
				local button = buttons[option]
				if button then
					index = index + 1
					if index > 8 then
						break
					end
					button.TextTransparency = 1
					task.delay(index * 0.02, function()
						if button.Parent then
							Animate(button, {TextTransparency = 0}, 0.15)
						end
					end)
				end
			end
		end
	end

	local control = {}
	function control.Close()
		if open then
			open = false
			Resize()
		end
	end
	table.insert(win.Dropdowns, control)

	local function Collect()
		local names = {}
		for _, option in ipairs(options) do
			if chosen[option] then
				table.insert(names, option)
			end
		end
		return names
	end

	local function Render()
		for option, button in pairs(buttons) do
			local active = multi and chosen[option] or (not multi and single == option)
			button.TextColor3 = active and win.Theme.Accent or win.Theme.Text
			button.BackgroundColor3 = win.Theme.Hover
			button.BackgroundTransparency = active and 0.35 or 1
			local tick = marks[option]
			if tick then
				tick.Visible = active and true or false
				tick.BackgroundColor3 = win.Theme.Accent
			end
		end
		if multi then
			local names = Collect()
			readout.Text = #names > 0 and table.concat(names, ", ") or "None"
		else
			readout.Text = single ~= nil and tostring(single) or "None"
		end
	end

	win:Bind(Render)

	local object = {}

	local function Commit(silent)
		Render()
		if not silent then
			win:Touch(config.Flag)
			Fire(config.Callback, multi and Collect() or single)
		end
	end

	local function Build()
		for _, button in pairs(buttons) do
			button:Destroy()
		end
		buttons = {}
		marks = {}
		for index, option in ipairs(options) do
			local button = Create("TextButton", {
				LayoutOrder = index,
				Size = UDim2.new(1, -6, 0, optionHeight),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = tostring(option),
				Parent = list
			})
			Round(button, 5)
			Pad(button, 14, 0, 6, 0)
			local tick = Create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -9, 0.5, 0),
				Size = UDim2.fromOffset(3, 14),
				BorderSizePixel = 0,
				Visible = false,
				Parent = button
			})
			Round(tick, 2)
			marks[option] = tick
			button.MouseButton1Click:Connect(function()
				if multi then
					chosen[option] = not chosen[option] or nil
				else
					single = option
					open = false
					Resize()
				end
				Commit(false)
			end)
			buttons[option] = button
		end
		Render()
	end

	function object:Refresh(newOptions)
		options = newOptions or {}
		chosen = {}
		single = nil
		Build()
		Resize()
		Commit(true)
	end
	function object:Set(value, silent)
		if multi then
			chosen = {}
			for _, option in ipairs(value or {}) do
				chosen[option] = true
			end
		else
			single = value
		end
		Commit(silent)
	end
	function object:Get()
		return multi and Collect() or single
	end
	Build()
	if config.Default ~= nil then
		object:Set(config.Default, true)
	end
	Register(win, config.Flag, object)

	header.MouseButton1Click:Connect(function()
		if not open then
			for _, other in ipairs(win.Dropdowns) do
				if other ~= control then
					other.Close()
				end
			end
		end
		open = not open
		Resize()
	end)
	return self:Track(object, config.Default)
end

function Tab:CreateColorPicker(config)
	config = config or {}
	local win = self.Window
	local original = config.Default or Color3.fromRGB(255, 255, 255)
	local color = original
	local hue, sat, val = color:ToHSV()
	local open = false
	local panelTop = RowHeight + 4

	local row = NewRow(self, RowHeight)
	row.ClipsDescendants = true
	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, RowHeight),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row
	})
	RowLabel(win, row, config.Name or "Color", 70, config.Icon, nil, config.KeepIconColor)
	local preview = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, RowHeight / 2),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = row
	})
	Round(preview, 4)
	win:Stroke(preview)

	local panel = Create("Frame", {
		Position = UDim2.fromOffset(0, panelTop),
		Size = UDim2.new(1, 0, 0, 166),
		BackgroundTransparency = 1,
		Parent = row
	})

	local field = Create("Frame", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -40, 0, 100),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		Parent = panel
	})
	Round(field, 4)
	local white = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = field
	})
	Round(white, 4)
	Create("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = white})
	local black = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = field
	})
	Round(black, 4)
	Create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black})
	local fieldCursor = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = field
	})
	Round(fieldCursor, 6)
	Create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Parent = fieldCursor})

	local bar = Create("Frame", {
		Position = UDim2.new(1, -24, 0, 0),
		Size = UDim2.fromOffset(16, 100),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = panel
	})
	Round(bar, 4)
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
		}),
		Parent = bar
	})
	local barCursor = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = bar
	})
	Round(barCursor, 2)
	Create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Parent = barCursor})

	local rgbRow = Create("Frame", {
		Position = UDim2.fromOffset(8, 108),
		Size = UDim2.new(1, -16, 0, 24),
		BackgroundTransparency = 1,
		Parent = panel
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rgbRow
	})
	local channels = {}
	for index, letter in ipairs({"R", "G", "B"}) do
		local channel = win:Make("TextBox", {
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			PlaceholderText = letter,
			ClearTextOnFocus = false,
			Text = "",
			Parent = rgbRow
		}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
		Round(channel, 5)
		win:Stroke(channel)
		channels[index] = channel
	end

	local hex = win:Make("TextBox", {
		Position = UDim2.fromOffset(8, 138),
		Size = UDim2.new(1, -100, 0, 24),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		PlaceholderText = "#RRGGBB",
		ClearTextOnFocus = false,
		Text = "",
		Parent = panel
	}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
	Round(hex, 5)
	win:Stroke(hex)

	local reset = win:Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 138),
		Size = UDim2.fromOffset(80, 24),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = "Reset",
		Parent = panel
	}, {BackgroundColor3 = "Hover", TextColor3 = "Text"})
	Round(reset, 5)
	Hover(win, reset, "Hover", "Stroke")

	local function Apply(silent)
		color = Color3.fromHSV(hue, sat, val)
		preview.BackgroundColor3 = color
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		fieldCursor.Position = UDim2.fromScale(sat, 1 - val)
		barCursor.Position = UDim2.fromScale(0.5, hue)
		hex.Text = "#" .. color:ToHex()
		channels[1].Text = tostring(math.floor(color.R * 255 + 0.5))
		channels[2].Text = tostring(math.floor(color.G * 255 + 0.5))
		channels[3].Text = tostring(math.floor(color.B * 255 + 0.5))
		if not silent then
			win:Touch(config.Flag)
			Fire(config.Callback, color)
		end
	end

	win:Slide(field, function(position)
		sat = math.clamp((position.X - field.AbsolutePosition.X) / field.AbsoluteSize.X, 0, 1)
		val = 1 - math.clamp((position.Y - field.AbsolutePosition.Y) / field.AbsoluteSize.Y, 0, 1)
		Apply(false)
	end, self.Scroller)

	win:Slide(bar, function(position)
		hue = math.clamp((position.Y - bar.AbsolutePosition.Y) / bar.AbsoluteSize.Y, 0, 1)
		Apply(false)
	end, self.Scroller)

	local function ReadChannels()
		local values = {}
		for index, channel in ipairs(channels) do
			local parsed = tonumber(channel.Text) or 0
			values[index] = math.clamp(math.floor(parsed + 0.5), 0, 255)
		end
		hue, sat, val = Color3.fromRGB(values[1], values[2], values[3]):ToHSV()
		Apply(false)
	end
	for _, channel in ipairs(channels) do
		channel.FocusLost:Connect(ReadChannels)
	end

	hex.FocusLost:Connect(function()
		local ok, parsed = pcall(Color3.fromHex, hex.Text)
		if ok and parsed then
			hue, sat, val = parsed:ToHSV()
		end
		Apply(false)
	end)

	local object = {}

	reset.MouseButton1Click:Connect(function()
		win:Confirm("Do you want to reset this color to default?", function()
			if config.OnReset then
				config.OnReset(object)
			else
				object:Set(original, false)
			end
		end)
	end)

	header.MouseButton1Click:Connect(function()
		open = not open
		Animate(row, {Size = UDim2.new(1, 0, 0, open and (panelTop + 170) or RowHeight)}, 0.2)
	end)

	Apply(true)

	function object:Set(value, silent)
		hue, sat, val = value:ToHSV()
		Apply(silent)
	end
	function object:Get()
		return color
	end
	Register(win, config.Flag, object)
	return self:Track(object, original)
end

function Window:ApplyBody()
	local menu = not self.OnTop
	self.Side.Visible = menu and self.SidebarVisible
	self.Content.Visible = menu
	self.TopContent.Visible = not menu
end

function Window:AddTopEntry(name, icon, page)
	local entry = {Name = name, Page = page, Active = false}
	local image = ParseImage(icon)
	local textWidth = TextService:GetTextSize(name, 12, Enum.Font.GothamMedium, Vector2.new(400, 20)).X
	local width = textWidth + 24 + (image and 20 or 0)
	local pill = Create("TextButton", {
		Name = name,
		LayoutOrder = #self.TopEntries + 1,
		Size = UDim2.fromOffset(width, TopHeight - 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = self.Strip
	})
	Round(pill, 4)
	local iconLabel
	if image then
		iconLabel = Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			Image = image,
			Parent = pill
		})
	end
	local label = Create("TextLabel", {
		Position = UDim2.fromOffset(image and 26 or 0, 0),
		Size = UDim2.new(1, image and -26 or 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = name,
		Parent = pill
	})
	function entry.Render(time)
		local theme = self.Theme
		Animate(pill, {
			BackgroundTransparency = entry.Active and 0 or 1,
			BackgroundColor3 = theme.Hover
		}, time)
		Animate(label, {TextColor3 = entry.Active and theme.Text or theme.Sub}, time)
		if iconLabel then
			Animate(iconLabel, {ImageColor3 = entry.Active and theme.Text or theme.Sub}, time)
		end
	end
	self:Bind(function()
		entry.Render(0)
	end)
	pill.MouseEnter:Connect(function()
		if CanHover() and not entry.Active then
			Animate(pill, {BackgroundTransparency = 0.6}, 0.1)
		end
	end)
	pill.MouseLeave:Connect(function()
		if not entry.Active then
			Animate(pill, {BackgroundTransparency = 1}, 0.1)
		end
	end)
	pill.MouseButton1Click:Connect(function()
		self:SelectTop(entry)
	end)
	table.insert(self.TopEntries, entry)
	self.Strip.Visible = #self.TopEntries > 1
	return entry
end

function Window:SelectTop(entry)
	if self.TopSelected == entry then
		return
	end
	local previous = self.TopSelected
	for _, other in ipairs(self.TopEntries) do
		other.Active = other == entry
		other.Render(0.14)
		if other.Page then
			other.Page.Visible = other.Active
		end
	end
	for _, child in ipairs(self.TopContent:GetChildren()) do
		if child ~= entry.Page and child:IsA("ScrollingFrame") then
			child.Visible = false
		end
	end
	self.TopSelected = entry
	self.OnTop = entry.Page ~= nil
	self:ApplyBody()
	if previous and previous.OnHide then
		previous.OnHide()
	end
	if entry.Page then
		if self:Fancy() then
			if entry.PageTween then
				entry.PageTween:Cancel()
			end
			entry.Page.Position = UDim2.fromOffset(0, 14)
			entry.PageTween = Animate(entry.Page, {Position = UDim2.fromOffset(0, 0)}, 0.2)
			self:Stagger(entry.Page)
		else
			entry.Page.Position = UDim2.fromOffset(0, 0)
		end
	end
	if entry.OnShow then
		entry.OnShow()
	end
end

function Window:BuildTopPage(name, icon)
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = name
	tab.Order = 0
	tab.Active = false
	tab.IsTop = true
	local page = self:Make("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.TopContent
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page})
	Pad(page, 10, 10, 12, 10)
	tab.Page = page
	tab.Scroller = page
	tab.Root = tab
	tab.Controls = {}
	local entry = self:AddTopEntry(name, icon, page)
	tab.Entry = entry
	return tab, entry
end

function Window:CreateTopTab(name, icon)
	if self.CustomTop >= 4 then
		warn("[Graphite] Only 4 custom top tabs are allowed")
		self:Status("Error", "Only 4 custom top tabs are allowed")
		return nil
	end
	self.CustomTop = self.CustomTop + 1
	local tab = self:BuildTopPage(name or "Tab", icon)
	table.insert(self.TopTabs, tab)
	return tab
end

Window.CreateHeaderTab = Window.CreateTopTab

function Window:Teleport(placeId, jobId, what)
	local function Go()
		self:Status("Updated", "Joining " .. what .. "...")
		local ok, err = pcall(function()
			if jobId then
				TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
			else
				TeleportService:Teleport(placeId, LocalPlayer)
			end
		end)
		if not ok then
			self:Status("Error", "Could not join: " .. tostring(err))
		end
	end
	if self.ConfirmTeleport then
		self:Confirm("Do you want to join " .. what .. "?", Go)
	else
		Go()
	end
end

function Window:FetchServers(order)
	local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100", game.PlaceId, order)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok or type(body) ~= "string" then
		return nil, "The server list is not available here"
	end
	local decoded, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
		return nil, "The server list could not be read"
	end
	return data.data
end

function Window:PickServer(mode)
	local list, problem = self:FetchServers(mode == "Emptiest" and "Asc" or "Desc")
	if not list then
		return nil, problem
	end
	local candidates = {}
	for _, server in ipairs(list) do
		local playing = server.playing
		if server.id ~= game.JobId and type(playing) == "number" and playing >= 1 and playing < (server.maxPlayers or math.huge) then
			table.insert(candidates, server)
		end
	end
	if #candidates == 0 then
		return nil, "No other server was found"
	end
	if mode == "Random" then
		return candidates[math.random(1, #candidates)]
	end
	return candidates[1]
end

function Window:JoinServer(mode)
	local server, problem = self:PickServer(mode)
	if not server then
		error(problem, 0)
	end
	self:Teleport(game.PlaceId, server.id, "a server with " .. tostring(server.playing) .. " players")
end

local function InfoRow(tab, name, clickable)
	local win = tab.Window
	local row = NewRow(tab, RowHeight - 2, clickable and "TextButton" or nil)
	win:Make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.45, -12, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
		Parent = row
	}, {TextColor3 = "Sub"})
	local value = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.55, -12, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "-",
		Parent = row
	}, {TextColor3 = "Text"})
	return value, row
end

function Window:BuildGuide(config)
	local tab, entry = self:BuildTopPage("Guide", nil)
	tab.Locked = true
	tab:CreateSection("Video Guide")
	if config.GuideVideo then
		local row = NewRow(tab, 176)
		row.ClipsDescendants = true
		local video = Create("VideoFrame", {
			Size = UDim2.new(1, 0, 1, -36),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Video = ParseImage(config.GuideVideo),
			Looped = false,
			Volume = 0.6,
			Parent = row
		})
		local playing = false
		local toggle = self:Make("TextButton", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -6),
			Size = UDim2.new(1, -16, 0, 26),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			Text = "Play",
			Parent = row
		}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
		Round(toggle, 5)
		toggle.MouseButton1Click:Connect(function()
			playing = not playing
			pcall(function()
				if playing then
					video:Play()
				else
					video:Pause()
				end
			end)
			toggle.Text = playing and "Pause" or "Play"
		end)
		entry.OnHide = function()
			if playing then
				playing = false
				toggle.Text = "Play"
				pcall(function()
					video:Pause()
				end)
			end
		end
	end
	if config.GuideUrl then
		tab:CreateButton({
			Name = "Copy Video Link",
			Description = "Copy the link, then open it in your browser",
			Callback = function()
				if type(setclipboard) ~= "function" then
					error("The clipboard is not supported here", 0)
				end
				setclipboard(config.GuideUrl)
			end
		})
	end
	if not config.GuideVideo and not config.GuideUrl then
		tab:CreateParagraph({Title = "No video yet", Content = "The menu author has not added a video guide."})
	end
	tab:CreateSection("Quick Guide")
	tab:CreateParagraph({Title = "Move and resize", Content = "Drag the top bar or the sidebar to move the menu. Drag the bottom right corner to resize it."})
	tab:CreateParagraph({Title = "Sliders", Content = "Drag the knob, type a value in the box, or use the - and + buttons for exact steps."})
	tab:CreateParagraph({Title = "Buttons", Content = "A button shows OK when it worked and Failed when something went wrong."})
	tab:CreateParagraph({Title = "Settings", Content = "Open Settings for colors, reset tools, Focus Mode, saving your values and the Bio.Menu.txt file."})
end

function Window:BuildProfile(config)
	local tab, entry = self:BuildTopPage("Profile", nil)
	tab.Locked = true
	local player = LocalPlayer
	local userId = player and player.UserId or 0

	local card = NewRow(tab, 100)
	local avatar = self:Make("ImageLabel", {
		Name = "Avatar",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(72, 72),
		BorderSizePixel = 0,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150",
		Parent = card
	}, {BackgroundColor3 = "Top"})
	Round(avatar, 36)
	self:Stroke(avatar, "Border")
	self:Make("TextLabel", {
		Position = UDim2.fromOffset(100, 14),
		Size = UDim2.new(1, -112, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = player and player.DisplayName or "Player",
		Parent = card
	}, {TextColor3 = "Text"})
	self:Make("TextLabel", {
		Position = UDim2.fromOffset(100, 41),
		Size = UDim2.new(1, -112, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "@" .. (player and player.Name or "player"),
		Parent = card
	}, {TextColor3 = "Sub"})
	self:Make("TextLabel", {
		Position = UDim2.fromOffset(100, 62),
		Size = UDim2.fromOffset(84, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "ID " .. tostring(userId),
		Parent = card
	}, {TextColor3 = "Sub"})
	local member = self:Make("TextLabel", {
		Position = UDim2.fromOffset(188, 62),
		Size = UDim2.new(1, -200, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "-",
		Parent = card
	}, {TextColor3 = "Accent"})

	tab:CreateSection("Stats")
	tab.Order = tab.Order + 1
	local grid = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = tab.Order,
		Parent = tab.Page
	})
	Create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 56),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid
	})

	local function Stat(name, order, clickable)
		local box = self:Make(clickable and "TextButton" or "Frame", {
			LayoutOrder = order,
			BorderSizePixel = 0,
			Parent = grid
		}, {BackgroundColor3 = "Element"})
		if clickable then
			box.Text = ""
			box.AutoButtonColor = false
		end
		Round(box, 4)
		self:Stroke(box, "Stroke", 0.6)
		self:Make("TextLabel", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = name,
			Parent = box
		}, {TextColor3 = "Sub"})
		local value = self:Make("TextLabel", {
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -24, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "-",
			Parent = box
		}, {TextColor3 = "Text"})
		return value, box
	end

	local created = Stat("Account Created", 1)
	local age = Stat("Account Age", 2)
	local menuTime = Stat("Menu Time", 3)
	local clock = Stat("Current Time", 4)
	local ping = Stat("Ping", 5)
	local serverId, serverBox = Stat("Server ID (tap to copy)", 6, true)
	Hover(self, serverBox)
	self:Pressable(serverBox)
	serverBox.MouseButton1Click:Connect(function()
		if type(setclipboard) == "function" and pcall(setclipboard, game.JobId) then
			self:Status("Saved", "Server ID copied")
		else
			self:Status("Error", "The clipboard is not supported here")
		end
	end)

	local gameRow = NewRow(tab, 56)
	self:Make("TextLabel", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Game",
		Parent = gameRow
	}, {TextColor3 = "Sub"})
	local gameName = self:Make("TextLabel", {
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "-",
		Parent = gameRow
	}, {TextColor3 = "Text"})

	local recent = tab:CreateParagraph({Title = "Recent Games", Content = "-"})

	local function Fill()
		local days = player and player.AccountAge or 0
		created.Text = os.date("%Y-%m-%d", os.time() - days * 86400)
		age.Text = tostring(days) .. " days"
		member.Text = (player and player.MembershipType and player.MembershipType.Name) or "Unknown"
		local job = game.JobId
		serverId.Text = job ~= "" and string.sub(job, 1, 13) or "Studio"
	end

	local function Record(name)
		local list = LoadGames()
		local now = os.time()
		local id = game.PlaceId
		local head = list[1]
		if head and head.id == id and now - head.time < 3600 then
			head.time = now
			if name then
				head.name = name
			end
		else
			table.insert(list, 1, {id = id, time = now, name = name or ("Place " .. tostring(id))})
		end
		while #list > 10 do
			table.remove(list)
		end
		SaveGames(list)
		return list
	end

	local function ShowRecent(list)
		local lines = {}
		for index, item in ipairs(list) do
			if index > 5 then
				break
			end
			table.insert(lines, item.name .. "  -  " .. os.date("%m-%d %H:%M", item.time))
		end
		recent:SetContent(#lines > 0 and table.concat(lines, "\n") or "No games recorded yet")
	end

	local ticking = false
	local function Tick()
		if self.Closed or not entry.Active then
			ticking = false
			return
		end
		menuTime.Text = Duration(os.clock() - self.Created)
		clock.Text = os.date("%H:%M:%S")
		local ok, value = pcall(function()
			return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
		end)
		ping.Text = ok and (value .. " ms") or "-"
		task.delay(1, Tick)
	end

	tab:CreateSection("Friends Online")
	local listRow = NewRow(tab, 172)
	local countLabel = self:Make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Friends online: -",
		Parent = listRow
	}, {TextColor3 = "Sub"})
	local friendList = self:Make("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 28),
		Size = UDim2.new(1, -12, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = listRow
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = friendList
	})
	Pad(friendList, 2, 2, 2, 6)
	local empty = self:Make("TextLabel", {
		LayoutOrder = 0,
		Size = UDim2.fromOffset(260, 120),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		Text = "Loading friends...",
		Parent = friendList
	}, {TextColor3 = "Sub"})
	local moreButton = self:Make("TextButton", {
		LayoutOrder = 100000,
		Size = UDim2.fromOffset(92, 120),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		Text = "Show more",
		Visible = false,
		Parent = friendList
	}, {BackgroundColor3 = "Hover", TextColor3 = "Text"})
	Round(moreButton, 4)

	local friends = {}
	local shown = 0
	local fetched = false

	local function AddCard(friend, index)
		local box = self:Make("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(92, 120),
			BorderSizePixel = 0,
			Parent = friendList
		}, {BackgroundColor3 = "Top"})
		box:SetAttribute("FriendRow", true)
		Round(box, 4)
		self:Stroke(box, "Stroke", 0.5)
		local photo = Create("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(52, 52),
			BackgroundTransparency = 1,
			Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(friend.VisitorId or 0) .. "&w=150&h=150",
			Parent = box
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = photo})
		self:Make("TextLabel", {
			Position = UDim2.fromOffset(4, 64),
			Size = UDim2.new(1, -8, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = friend.DisplayName or friend.UserName or "Friend",
			Parent = box
		}, {TextColor3 = "Text"})
		local where = "Online"
		if friend.IsOnline == false then
			where = "Offline"
		elseif type(friend.LastLocation) == "string" and friend.LastLocation ~= "" then
			where = friend.LastLocation
		end
		self:Make("TextLabel", {
			Position = UDim2.fromOffset(4, 80),
			Size = UDim2.new(1, -8, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = where,
			Parent = box
		}, {TextColor3 = "Sub"})
		local joinable = type(friend.PlaceId) == "number" and type(friend.GameId) == "string" and friend.GameId ~= ""
		if joinable then
			local join = self:Make("TextButton", {
				Position = UDim2.new(0, 8, 1, -28),
				Size = UDim2.new(1, -16, 0, 22),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ClipsDescendants = true,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = "Join",
				Parent = box
			}, {BackgroundColor3 = "Element", TextColor3 = "Text"})
			Round(join, 4)
			Hover(self, join)
			self:Pressable(join)
			join.MouseButton1Click:Connect(function()
				self:Teleport(friend.PlaceId, friend.GameId, (friend.DisplayName or friend.UserName or "your friend") .. "'s server")
			end)
		end
	end

	local function ShowMore()
		local limit = math.min(shown + 20, #friends)
		for index = shown + 1, limit do
			AddCard(friends[index], index)
		end
		shown = limit
		moreButton.Visible = shown < #friends
		moreButton.Text = "Show more (" .. (#friends - shown) .. " left)"
	end
	moreButton.MouseButton1Click:Connect(ShowMore)

	local function Fetch()
		empty.Visible = true
		empty.Text = "Loading friends..."
		task.spawn(function()
			local ok, result = pcall(function()
				return player:GetFriendsOnline(200)
			end)
			if self.Closed then
				return
			end
			friends = {}
			if ok and type(result) == "table" then
				for _, item in ipairs(result) do
					table.insert(friends, item)
				end
				table.sort(friends, function(a, b)
					local left = type(a.GameId) == "string" and a.GameId ~= ""
					local right = type(b.GameId) == "string" and b.GameId ~= ""
					if left ~= right then
						return left
					end
					return tostring(a.DisplayName) < tostring(b.DisplayName)
				end)
			end
			for _, child in ipairs(friendList:GetChildren()) do
				if child:GetAttribute("FriendRow") then
					child:Destroy()
				end
			end
			shown = 0
			if not ok then
				countLabel.Text = "Friends online: unavailable"
				empty.Text = "The friends list is not available here"
				empty.Visible = true
				moreButton.Visible = false
				return
			end
			countLabel.Text = "Friends online: " .. #friends
			empty.Text = "No friends are online right now"
			empty.Visible = #friends == 0
			ShowMore()
		end)
	end

	tab:CreateButton({
		Name = "Refresh Friends",
		Description = "Load the list of friends again",
		Callback = function()
			Fetch()
		end
	})

	tab:CreateSection("Server Tools")
	tab:CreateButton({
		Name = "Join Busiest Server",
		Description = "Join the server with the most players",
		Callback = function()
			self:JoinServer("Busiest")
		end
	})
	tab:CreateButton({
		Name = "Join Emptiest Server",
		Description = "Join the server with the fewest players",
		Callback = function()
			self:JoinServer("Emptiest")
		end
	})
	tab:CreateButton({
		Name = "Join Random Server",
		Description = "Hop to a random server",
		Callback = function()
			self:JoinServer("Random")
		end
	})

	local named = false
	entry.OnShow = function()
		Fill()
		ShowRecent(Record(nil))
		if not ticking then
			ticking = true
			Tick()
		end
		if not fetched then
			fetched = true
			Fetch()
		end
		if not named then
			named = true
			gameName.Text = "Place " .. tostring(game.PlaceId)
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(game.PlaceId)
				end)
				if self.Closed then
					return
				end
				if ok and type(info) == "table" and info.Name then
					gameName.Text = info.Name
					ShowRecent(Record(info.Name))
				end
			end)
		end
	end
end

function Window:BuildTopTabs(config)
	local menu = self:AddTopEntry("Menu", Icons.List, nil)
	self.MenuEntry = menu
	menu.Active = true
	menu.Render(0)
	self.TopSelected = menu
	if config.Guide ~= false then
		self:BuildGuide(config)
	end
	if config.Profile ~= false then
		self:BuildProfile(config)
	end
end

function Window:ResetTab(tab)
	tab = tab or self.LastContentTab or self.CurrentTab
	if not tab or not tab.Controls then
		return 0
	end
	local count = 0
	self.Loading = true
	for _, entry in ipairs(tab.Controls) do
		local ok = pcall(function()
			entry.object:Set(entry.default)
		end)
		if ok then
			count = count + 1
		end
	end
	self.Loading = false
	return count
end

function Window:ResetAll()
	local count = 0
	for _, tab in ipairs(self.Tabs) do
		if not tab.IsSettings then
			count = count + self:ResetTab(tab)
		end
	end
	for _, tab in ipairs(self.TopTabs) do
		count = count + self:ResetTab(tab)
	end
	return count
end

function Window:SetAllGroups(open)
	local count = 0
	for _, group in ipairs(self.Groups) do
		group.Set(open)
		count = count + 1
	end
	return count
end

function Window:SetSidebar(visible)
	self.SidebarVisible = visible
	local width = visible and 124 or 0
	if visible and not self.OnTop then
		self.Side.Visible = true
	end
	Animate(self.Side, {Size = UDim2.new(0, width, 1, -(TopHeight + FooterHeight))}, 0.2)
	local tween = Animate(self.Content, {
		Position = UDim2.fromOffset(width, TopHeight),
		Size = UDim2.new(1, -width, 1, -(TopHeight + FooterHeight))
	}, 0.2)
	tween.Completed:Connect(function()
		if not self.SidebarVisible and not self.Closed then
			self.Side.Visible = false
		end
	end)
end

function Window:SetFocusMode(state)
	self.Focus = state == true
	self:SetSidebar(not self.Focus)
	if self.Grip then
		self.Grip.Visible = not self.Locked and not self.Focus and not self.Mode3D
	end
end

function Window:RefreshUI()
	self:RunHooks()
	self:OnViewport()
	if self.CurrentTab then
		self:MoveIndicator(self.CurrentTab, true)
	end
	for _, control in ipairs(self.Dropdowns) do
		control.Close()
	end
	self:Flash()
end

function Window:DescribeSettings()
	local names = {}
	for flag in pairs(self.Elements) do
		table.insert(names, flag)
	end
	table.sort(names)
	local lines = {}
	for _, flag in ipairs(names) do
		local ok, value = pcall(function()
			return self.Elements[flag]:Get()
		end)
		if ok then
			local kind = typeof(value)
			local text
			if kind == "Color3" then
				text = "#" .. value:ToHex()
			elseif kind == "EnumItem" then
				text = value.Name
			elseif type(value) == "table" then
				text = "{" .. table.concat(value, ", ") .. "}"
			else
				text = tostring(value)
			end
			table.insert(lines, flag .. " = " .. text)
		end
	end
	return table.concat(lines, "\n"), #lines
end

function Window:CopySettings()
	local text, count = self:DescribeSettings()
	if count == 0 then
		return false, "No settings to copy yet. Give controls a Flag to include them"
	end
	if type(setclipboard) == "function" then
		local ok = pcall(setclipboard, text)
		if ok then
			return true, count .. " settings copied"
		end
	end
	self:Dialog({Title = "Current Settings", Content = string.sub(text, 1, 700), Buttons = {{Name = "Close"}}})
	return true, "Settings are shown in the window"
end

function Window:ShowHelp()
	self:Dialog({
		Title = "Help",
		Content = "Move: drag the top bar or the sidebar.\nResize: drag the bottom right corner.\nSliders: drag, type a value, or use - and +.\nButtons show OK or Failed after use.\nSettings has reset tools, Focus Mode, colors and config.",
		Buttons = {{Name = "Close"}}
	})
end

function Window:RestoreDefaults()
	self:ResetColors()
	self:ResetLayout()
	self:SetOpacity(100)
	self:SetLocked(false)
	self:SetReduceMotion(false)
	self:SetPerformance(false)
	self:SetAutoPerformance(false)
	self.PinchEnabled = false
	self:SetFocusMode(false)
	if self.OpacitySlider then
		self.OpacitySlider:Set(100, true)
	end
	if self.PinchToggle then
		self.PinchToggle:Set(false, true)
	end
	if self.AutoToggle then
		self.AutoToggle:Set(false, true)
	end
	if self.FpsToggle then
		self.FpsToggle:Set(false, true)
	end
	if self.Watermark then
		self.Watermark:SetVisible(false)
	end
	self:SetMode3D(false)
	self:SetBackground(nil)
	if self.BackInput then
		self.BackInput:Set("", true)
	end
	self:SetBorderThickness(1)
	self.Depth = 7
	self.TiltMax = 12
	self.FollowMode = "Character"
	if self.Toggle3D then
		self.Toggle3D:Set(false, true)
	end
	if self.BorderSlider then
		self.BorderSlider:Set(1, true)
	end
	if self.DepthSlider then
		self.DepthSlider:Set(7, true)
	end
	if self.TiltSlider then
		self.TiltSlider:Set(12, true)
	end
	if self.FollowDropdown then
		self.FollowDropdown:Set("Character", true)
	end
end

function Window:CreateSettingsTab(name, icon)
	local tab = self:CreateTab(name or "Settings", icon or Icons.Gear)
	tab.IsSettings = true
	self.SettingsTab = tab

	tab:CreateSection("Quick Settings")
	self.LockToggle = tab:CreateToggle({
		Name = "Lock Menu",
		Description = "Lock the position and size of the menu",
		Default = self.Locked,
		Callback = function(state)
			self:SetLocked(state)
		end
	})
	self.ReduceToggle = tab:CreateToggle({
		Name = "Reduce Motion",
		Description = "Turn off most animations",
		Default = Motion.Reduce,
		Callback = function(state)
			self:SetReduceMotion(state)
		end
	})
	self.PerformanceToggle = tab:CreateToggle({
		Name = "Performance Mode",
		Description = "Use lighter effects for better FPS",
		Default = Motion.Performance,
		Callback = function(state)
			self:SetPerformance(state)
		end
	})
	self.AutoToggle = tab:CreateToggle({
		Name = "Auto Performance",
		Description = "Turn on Performance Mode when FPS stays low",
		Default = false,
		Callback = function(state)
			self:SetAutoPerformance(state)
		end
	})
	tab:CreateButton({
		Name = "Hide Menu",
		Description = "Hide the menu. Press the + button to bring it back",
		Callback = function()
			self:SetHidden(true)
		end
	})

	tab:CreateSection("Tools")
	tab:CreateButton({
		Name = "Reset Current Tab",
		Description = "Restore the controls of the tab you were just using",
		Callback = function()
			local target = self.LastContentTab
			if not target or #(target.Controls or {}) == 0 then
				self:Status("Updated", "That tab has no controls to reset")
				return
			end
			self:Confirm("Do you want to reset " .. target.Name .. " to its default values?", function()
				local count = self:ResetTab(target)
				self:Flash()
				self:Status("Updated", count .. " controls reset in " .. target.Name)
			end)
		end
	})
	tab:CreateButton({
		Name = "Reset All Controls",
		Description = "Restore every control in every tab to its default value",
		Callback = function()
			self:Confirm("Do you want to reset all controls to their default values?", function()
				local count = self:ResetAll()
				self:Flash()
				self:Status("Updated", count .. " controls were reset")
			end)
		end
	})
	tab:CreateButton({
		Name = "Collapse All Groups",
		Description = "Fold every group so the lists are shorter",
		Callback = function()
			local count = self:SetAllGroups(false)
			self:Status("Updated", count > 0 and (count .. " groups collapsed") or "There are no groups yet")
		end
	})
	tab:CreateButton({
		Name = "Expand All Groups",
		Description = "Open every group",
		Callback = function()
			local count = self:SetAllGroups(true)
			self:Status("Updated", count > 0 and (count .. " groups expanded") or "There are no groups yet")
		end
	})
	tab:CreateButton({
		Name = "Show/Hide Sidebar",
		Description = "Hide the tab list to get more room",
		Callback = function()
			self:SetSidebar(not self.SidebarVisible)
		end
	})
	tab:CreateButton({
		Name = "Focus Mode",
		Description = "Show only the content. Press again to leave it",
		Callback = function()
			self:SetFocusMode(not self.Focus)
		end
	})
	tab:CreateButton({
		Name = "Refresh UI",
		Description = "Redraw the menu without losing your values",
		Callback = function()
			self:RefreshUI()
			self:Status("Updated", "Interface refreshed")
		end
	})
	tab:CreateButton({
		Name = "Copy Current Settings",
		Description = "Copy your settings as text so you can keep them",
		Callback = function()
			local ok, detail = self:CopySettings()
			self:Status(ok and "Saved" or "Error", detail)
		end
	})
	tab:CreateButton({
		Name = "Help",
		Description = "Short guide to the menu controls",
		Callback = function()
			self:ShowHelp()
		end
	})
	tab:CreateButton({
		Name = "Restore Defaults",
		Description = "Reset colors, layout and menu settings",
		Danger = true,
		Callback = function()
			self:Confirm("Do you want to restore the default menu settings?", function()
				self:RestoreDefaults()
				self:Flash()
				self:Status("Updated", "Default settings restored")
			end)
		end
	})
	tab:CreateButton({
		Name = "Reset Layout",
		Description = "Put the menu back to its first size and position",
		Callback = function()
			self:ResetLayout()
			self:Flash()
			self:Status("Updated", "Menu size and position were reset")
		end
	})

	tab:CreateSection("Colors")
	self.MenuPicker = tab:CreateColorPicker({
		Name = "Menu Color",
		Default = self.Base,
		Flag = "GraphiteMenuColor",
		Callback = function(color)
			self:SetMenuColor(color)
		end,
		OnReset = function(picker)
			self:SetMenuColor(DefaultBase)
			picker:Set(DefaultBase, true)
		end
	})
	self.TextPicker = tab:CreateColorPicker({
		Name = "Text Color",
		Default = self.Theme.Text,
		Flag = "GraphiteTextColor",
		Callback = function(color)
			self:SetTextColor(color)
		end,
		OnReset = function(picker)
			self.TextColor = nil
			self:Rebuild()
			picker:Set(self.Theme.Text, true)
		end
	})
	self.AccentPicker = tab:CreateColorPicker({
		Name = "Accent Color",
		Default = self.Theme.Accent,
		Flag = "GraphiteAccentColor",
		Callback = function(color)
			self:SetAccent(color)
		end,
		OnReset = function(picker)
			self.AccentColor = nil
			self:Rebuild()
			picker:Set(self.Theme.Accent, true)
		end
	})
	self.BorderPicker = tab:CreateColorPicker({
		Name = "Border Color",
		Default = self.Theme.Border,
		Flag = "GraphiteBorderColor",
		Callback = function(color)
			self:SetBorderColor(color)
		end,
		OnReset = function(picker)
			self.BorderColor = nil
			self:Rebuild()
			picker:Set(self.Theme.Border, true)
		end
	})
	self.BorderSlider = tab:CreateSlider({
		Name = "Border Thickness",
		Min = 1,
		Max = 6,
		Increment = 1,
		Default = self.BorderThickness,
		Suffix = " px",
		Flag = "GraphiteBorderThickness",
		Callback = function(value)
			self:SetBorderThickness(value)
		end
	})
	tab:CreateButton({
		Name = "Reset Theme",
		Description = "Back to the black menu with white text",
		Callback = function()
			self:Confirm("Do you want to reset all colors to default?", function()
				self:ResetColors()
				self:Flash()
				self:Status("Updated", "Theme colors were reset")
			end)
		end
	})

	tab:CreateSection("Background")
	self.BackInput = tab:CreateInput({
		Name = "Image ID",
		Placeholder = "Image ID or empty",
		Default = "",
		Flag = "GraphiteBackground",
		Callback = function(text)
			local value = string.gsub(tostring(text or ""), "%s", "")
			if value == "" then
				self:SetBackground(nil)
			else
				self:SetBackground(value)
			end
		end
	})
	self.BackSlider = tab:CreateSlider({
		Name = "Image Opacity",
		Min = 10,
		Max = 100,
		Increment = 5,
		Default = 40,
		Suffix = "%",
		Flag = "GraphiteBackOpacity",
		Callback = function(value)
			self.BackOpacity = value / 100
			if self.BackImageId then
				self:SetBackground(self.BackImageId, value / 100)
			end
		end
	})
	tab:CreateButton({
		Name = "Clear Background",
		Description = "Remove the menu image",
		Callback = function()
			self:SetBackground(nil)
			if self.BackInput then
				self.BackInput:Set("", true)
			end
		end
	})

	tab:CreateSection("Window")
	self.ZoomSlider = tab:CreateSlider({
		Name = "Menu Zoom",
		Min = 50,
		Max = 160,
		Increment = 1,
		Default = math.floor(self.TargetScale * 100 + 0.5),
		Suffix = "%",
		Callback = function(value)
			self:SetScale(value / 100, true)
		end
	})
	self.OpacitySlider = tab:CreateSlider({
		Name = "Menu Opacity",
		Min = 40,
		Max = 100,
		Increment = 1,
		Default = 100,
		Suffix = "%",
		Callback = function(value)
			self:SetOpacity(value)
		end
	})
	self.PinchToggle = tab:CreateToggle({
		Name = "Pinch To Zoom",
		Description = "Two fingers on the menu resize it",
		Default = false,
		Callback = function(state)
			self.PinchEnabled = state
		end
	})
	self.FpsToggle = tab:CreateToggle({
		Name = "Show FPS And Ping",
		Default = false,
		Callback = function(state)
			if state and not self.Watermark then
				self.Watermark = self:CreateWatermark({ShowPing = true})
			elseif self.Watermark then
				self.Watermark:SetVisible(state)
			end
		end
	})
	tab:CreateKeybind({
		Name = "Toggle Key",
		Default = self.ToggleKey,
		Changed = function(key)
			self:SetToggleKey(key)
		end
	})

	tab:CreateSection("3D Menu")
	self.Toggle3D = tab:CreateToggle({
		Name = "3D Menu",
		Description = "Float the menu in the game world. Only you can see it",
		Default = false,
		Callback = function(state)
			local ok, err = self:SetMode3D(state)
			if not ok then
				self.Toggle3D:Set(false, true)
				self:Status("Error", tostring(err))
			end
		end
	})
	self.DepthSlider = tab:CreateSlider({
		Name = "3D Distance",
		Min = 3,
		Max = 14,
		Increment = 1,
		Default = self.Depth,
		Suffix = " studs",
		Callback = function(value)
			self.Depth = value
		end
	})
	self.TiltSlider = tab:CreateSlider({
		Name = "3D Tilt",
		Min = 0,
		Max = 25,
		Increment = 1,
		Default = self.TiltMax,
		Suffix = " deg",
		Callback = function(value)
			self.TiltMax = value
		end
	})
	self.FollowDropdown = tab:CreateDropdown({
		Name = "3D Follow",
		Options = {"Character", "Camera"},
		Default = self.FollowMode,
		Callback = function(value)
			self.FollowMode = value or "Character"
		end
	})

	tab:CreateSection("Config")
	local configName = "default"
	tab:CreateInput({
		Name = "Config Name",
		Default = configName,
		Callback = function(text)
			if text ~= "" then
				configName = text
			end
		end
	})
	tab:CreateButton({
		Name = "Save Config",
		Description = "Keep your current control values",
		Callback = function()
			local ok, err = self:SaveConfig(configName)
			if ok then
				self:Flash()
				self:Status("Saved", configName)
			else
				self:Status("Error", tostring(err))
			end
		end
	})
	tab:CreateButton({
		Name = "Load Config",
		Description = "Bring back a saved set of values",
		Callback = function()
			local ok, err = self:LoadConfig(configName)
			if ok then
				self:Flash()
				self:Status("Loaded", configName)
			else
				self:Status("Error", tostring(err))
			end
		end
	})

	tab:CreateSection("Script File")
	local createButton
	local runButton
	local function Describe()
		if createButton and runButton then
			createButton:SetDescription("Saves " .. self.FileName .. " in the executor folder")
			runButton:SetDescription("Runs " .. self.FileName .. " and restores your settings")
		end
	end
	self.FileInput = tab:CreateInput({
		Name = "File Name",
		Default = self.FileName,
		Placeholder = "Bio.Menu.txt",
		Flag = "GraphiteFileName",
		Callback = function(text)
			local name = self:SetFileName(text)
			if self.FileInput then
				self.FileInput:Set(name, true)
			end
			Describe()
		end
	})
	createButton = tab:CreateButton({
		Name = "Create File",
		Icon = Icons.File,
		Description = "Saves " .. self.FileName .. " in the executor folder",
		Callback = function()
			local ok, err = self:SaveScriptFile()
			if ok then
				self:Flash()
				self:Status("Saved", self.FileName .. (err and (" (" .. err .. ")") or ""))
			else
				self:Status("Error", tostring(err))
			end
		end
	})
	runButton = tab:CreateButton({
		Name = "Run Saved File",
		Icon = Icons.File,
		Description = "Runs " .. self.FileName .. " and restores your settings",
		Callback = function()
			self:Confirm("Do you want to run the saved file? The current menu will be replaced.", function()
				local ok, err = self:RunScriptFile()
				if not ok then
					self:Status("Error", tostring(err))
				end
			end)
		end
	})

	tab:CreateSection("Menu")
	tab:CreateButton({
		Name = "Close Menu",
		Danger = true,
		Callback = function()
			self:RequestClose()
		end
	})
	return tab
end

function Graphite.load(first, second, third)
	if first == Graphite then
		first, second, third = second, third, nil
	end
	local config = {}
	if type(first) == "table" then
		for key, value in pairs(first) do
			config[key] = value
		end
	elseif type(first) == "number" then
		if type(second) == "number" and type(third) == "number" then
			if first == 2 then
				config.Min = second
				config.Max = third
			else
				config.Time = second
			end
		elseif type(second) == "number" then
			config.Min = first
			config.Max = second
		else
			config.Time = first
		end
	end
	if config.Time == nil and config.Min == nil and config.Seconds == nil then
		config.Time = 5
	end
	PendingLoad = config
	return config
end

Graphite.Load = Graphite.load
Graphite.Icons = Icons

function Graphite:CreateWindow(config)
	config = config or {}
	local self = setmetatable({}, Window)
	self.Name = config.Name or "Graphite"
	self.Flags = {}
	self.Elements = {}
	self.Tabs = {}
	self.Hooks = {}
	self.Connections = {}
	self.Folder = config.ConfigFolder or "Graphite"
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift
	self.OnClose = config.OnClose
	self.Hidden = false
	self.Closed = false
	self.PinchEnabled = false
	self.Token = 0
	self.Fade = 0
	self.MinSize = Vector2.new(380, 250)
	self.MaxSize = Vector2.new(900, 620)

	local base = config.Size or Vector2.new(480, 320)
	self.BaseSize = Vector2.new(math.max(base.X, self.MinSize.X), math.max(base.Y, self.MinSize.Y))

	self.Base = config.MenuColor or DefaultBase
	self.TextColor = config.TextColor
	self.AccentColor = config.AccentColor or config.Accent
	self.BorderColor = config.BorderColor
	self.Theme = BuildTheme(self.Base, self.TextColor, self.AccentColor, self.BorderColor)
	self.Born = os.clock()
	self.Locked = false
	self.Dirty = false
	self.Loading = false
	self.Dropdowns = {}
	self.NoteList = {}
	self.NoteOrder = 0
	ActiveWindow = self
	self.Groups = {}
	self.SidebarVisible = true
	self.Focus = false
	self.TopEntries = {}
	self.TopTabs = {}
	self.CustomTop = 0
	self.OnTop = false
	self.Created = os.clock()
	self.ConfirmTeleport = config.ConfirmTeleport ~= false
	self.BorderThickness = 1
	self.Depth = 7
	self.TiltMax = 12
	self.FollowMode = "Character"
	self.Mode3D = false
	self.LogoFixes = 0
	self.Tilt = {x = 0, y = 0, tx = 0, ty = 0}
	self.Fly = 0
	self.Away = 0
	self.Leaving = false
	self.Rows = {}
	self.PanelAlpha = 0
	self.RowAlpha = 0
	self.BackOpacity = 0.4
	self.FileName = config.FileName or "Bio.Menu.txt"
	local shared = GlobalEnv()
	self.Source = config.Source or shared.GraphiteSourceText
	shared.GraphiteWindows = (shared.GraphiteWindows or 0) + 1
	local active = shared.GraphiteActive
	if type(active) ~= "table" then
		active = {}
		shared.GraphiteActive = active
	end
	if config.AllowDuplicates ~= true then
		for index = #active, 1, -1 do
			local other = active[index]
			if other and other ~= self and not other.Closed and other.Name == self.Name then
				pcall(function()
					other:Destroy()
				end)
			end
		end
	end
	table.insert(active, self)
	if type(shared.GraphiteSaved) == "table" then
		self.Pending = shared.GraphiteSaved
		shared.GraphiteSaved = nil
		task.delay(10, function()
			self.Pending = nil
		end)
	end

	local gui = Create("ScreenGui", {
		Name = "Graphite" .. math.random(1000, 9999),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999
	})
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	local parented = false
	if type(gethui) == "function" then
		parented = pcall(function()
			gui.Parent = gethui()
		end)
	end
	if not parented or not gui.Parent then
		pcall(function()
			gui.Parent = CoreGui
		end)
	end
	if not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	self.Gui = gui

	local view = ViewSize(gui)
	self.AutoScale = math.clamp(math.min(view.X / (self.BaseSize.X + 40), view.Y / (self.BaseSize.Y + 40), 1), 0.5, 1)
	self.TargetScale = config.Scale or self.AutoScale

	local main = self:Make("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.BaseSize.X, self.BaseSize.Y),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = gui
	}, {BackgroundColor3 = "Main"})
	Round(main, 4)
	self.Main = main
	self.Body = main
	self.UIScale = Create("UIScale", {Scale = self.TargetScale * 0.85, Parent = main})
	local gate = PendingLoad
	PendingLoad = nil
	if gate then
		self.Gated = true
		main.Visible = false
	else
		Animate(self.UIScale, {Scale = self.TargetScale}, 0.35, Enum.EasingStyle.Back)
		Animate(main, {GroupTransparency = 0}, 0.25)
	end

	self.BackImage = Create("ImageLabel", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Visible = false,
		ZIndex = 0,
		Parent = main
	})

	local top = self:Make("Frame", {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, TopHeight),
		BorderSizePixel = 0,
		Active = true,
		Parent = main
	}, {BackgroundColor3 = "Top"})

	self.TopBar = top
	local titleOffset = 14
	local windowIcon = ParseImage(config.Icon)
	if windowIcon then
		Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Image = windowIcon,
			Parent = top
		})
		titleOffset = 38
	end
	local titleWidth = math.min(TextService:GetTextSize(self.Name, 13, Enum.Font.GothamMedium, Vector2.new(400, 30)).X + 6, 170)
	self.TitleOffset = titleOffset
	self.TitleLabel = self:Make("TextLabel", {
		Position = UDim2.fromOffset(titleOffset, 0),
		Size = UDim2.new(0, titleWidth, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Name,
		Parent = top
	}, {TextColor3 = "Text"})

	local buttonWidth = Touch and 38 or 32
	local buttonHeight = Touch and 30 or 26

	local function GlyphButton(parent, text, props, icon)
		props.Size = props.Size or UDim2.fromOffset(buttonWidth, buttonHeight)
		props.BackgroundTransparency = 1
		props.AutoButtonColor = false
		props.Font = Enum.Font.GothamBold
		props.TextSize = 14
		props.Text = icon and "" or text
		props.Parent = parent
		local button = self:Make("TextButton", props, {BackgroundColor3 = "Hover", TextColor3 = "Sub"})
		Round(button, 5)
		local image
		if icon then
			image = Create("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Image = icon,
				Parent = button
			})
			self:Paint(image, "ImageColor3", "Sub")
		end
		button.MouseEnter:Connect(function()
			if CanHover() then
				Animate(button, {BackgroundTransparency = 0, TextColor3 = self.Theme.Text}, 0.1)
				if image then
					Animate(image, {ImageColor3 = self.Theme.Text}, 0.1)
				end
			end
		end)
		button.MouseLeave:Connect(function()
			Animate(button, {BackgroundTransparency = 1, TextColor3 = self.Theme.Sub}, 0.1)
			if image then
				Animate(image, {ImageColor3 = self.Theme.Sub}, 0.1)
			end
		end)
		return button
	end

	local hideButton = GlyphButton(top, "-", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -(buttonWidth * 2 + 10), 0.5, 0)
	})
	local closeButton = GlyphButton(top, "X", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -(buttonWidth + 6), 0.5, 0)
	}, Icons.Close)

	local buttonsWidth = buttonWidth * 2 + 20
	local stripX = titleOffset + titleWidth + 10
	self.ButtonsWidth = buttonsWidth
	local strip = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(stripX, 0),
		Size = UDim2.new(1, -(stripX + buttonsWidth), 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = top
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = strip
	})
	self.Strip = strip
	local function UpdateStrip()
		local canvas = strip.AbsoluteCanvasSize
		local size = strip.AbsoluteSize
		if canvas and size then
			strip.ScrollingEnabled = canvas.X > size.X + 1
		end
	end
	self:Connect(strip:GetPropertyChangedSignal("AbsoluteCanvasSize"), UpdateStrip)
	self:Connect(strip:GetPropertyChangedSignal("AbsoluteSize"), UpdateStrip)
	UpdateStrip()

	local side = self:Make("Frame", {
		Position = UDim2.fromOffset(0, TopHeight),
		Size = UDim2.new(0, 124, 1, -(TopHeight + FooterHeight)),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = main
	}, {BackgroundColor3 = "Side"})
	self:Make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BorderSizePixel = 0,
		Parent = side
	}, {BackgroundColor3 = "Stroke"})
	local tabList = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = side
	})
	Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList})
	Pad(tabList, 8, 8, 9, 8)
	self.TabList = tabList
	self.Side = side
	self.TabIndicator = self:Make("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(3, 16),
		BorderSizePixel = 0,
		Visible = false,
		Parent = side
	}, {BackgroundColor3 = "Accent"})
	Round(self.TabIndicator, 2)
	self:Connect(tabList:GetPropertyChangedSignal("CanvasPosition"), function()
		if self.CurrentTab then
			self:MoveIndicator(self.CurrentTab, true)
		end
	end)

	local content = Create("Frame", {
		Position = UDim2.fromOffset(124, TopHeight),
		Size = UDim2.new(1, -124, 1, -(TopHeight + FooterHeight)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main
	})
	self.Content = content

	self.TopContent = Create("Frame", {
		Position = UDim2.fromOffset(0, TopHeight),
		Size = UDim2.new(1, 0, 1, -(TopHeight + FooterHeight)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		Parent = main
	})

	local edge = Create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 200,
		Parent = main
	})
	Round(edge, 3)
	self.EdgeStroke = self:Stroke(edge, "Border")
	self.Edge = edge
	self:SetBorderThickness(config.BorderThickness or 1)

	local gripSize = Touch and 30 or 20
	local grip = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(gripSize, gripSize),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 70,
		Parent = main
	})
	for _, offset in ipairs({Vector2.new(-6, -6), Vector2.new(-6, -11), Vector2.new(-11, -6)}) do
		local dot = self:Make("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, offset.X, 1, offset.Y),
			Size = UDim2.fromOffset(3, 3),
			BorderSizePixel = 0,
			ZIndex = 71,
			Parent = grip
		}, {BackgroundColor3 = "Sub"})
		Round(dot, 2)
	end

	self.Grip = grip
	local resizeOrigin
	local resizeStart
	local resizeCorner
	self:Pointer(grip, function(input)
		if self.Locked or self.Mode3D then
			resizeOrigin = nil
			return
		end
		resizeOrigin = input.Position
		resizeStart = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)
		resizeCorner = main.AbsolutePosition
	end, function(input)
		if not resizeOrigin then
			return
		end
		local scale = self.UIScale.Scale
		local delta = (input.Position - resizeOrigin) / scale
		local width = math.clamp(resizeStart.X + delta.X, self.MinSize.X, self.MaxSize.X)
		local height = math.clamp(resizeStart.Y + delta.Y, self.MinSize.Y, self.MaxSize.Y)
		local current = ViewSize(gui)
		main.Size = UDim2.fromOffset(width, height)
		main.Position = UDim2.fromScale(
			(resizeCorner.X + width * scale / 2) / current.X,
			(resizeCorner.Y + height * scale / 2) / current.Y
		)
		self:Clamp()
	end, function()
		resizeOrigin = nil
	end)

	local function AttachDrag(handle, canDrag)
		local origin
		local startCenter
		self:Pointer(handle, function(input)
			if self.Locked or self.Mode3D or (canDrag and not canDrag()) then
				origin = nil
				return
			end
			local current = ViewSize(gui)
			origin = input.Position
			startCenter = Vector2.new(main.Position.X.Scale * current.X, main.Position.Y.Scale * current.Y)
		end, function(input)
			if not origin then
				return
			end
			local current = ViewSize(gui)
			local delta = input.Position - origin
			main.Position = UDim2.fromScale((startCenter.X + delta.X) / current.X, (startCenter.Y + delta.Y) / current.Y)
			self:Clamp()
		end, function()
			origin = nil
		end)
	end
	self.AttachDrag = AttachDrag
	AttachDrag(top)
	AttachDrag(side)
	AttachDrag(strip, function()
		return not strip.ScrollingEnabled
	end)
	self:MakeFooter()

	local barHeight = Touch and 36 or 30
	local restore = self:Make("Frame", {
		Name = "Restore",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, barHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		Parent = gui
	}, {BackgroundColor3 = "Top"})
	Round(restore, 5)
	self:Stroke(restore)
	Pad(restore, 12, 0, 5, 0)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = restore
	})
	self.Restore = restore
	self.RestoreScale = Create("UIScale", {Scale = 1, Parent = restore})
	self.BarLabel = self:Make("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, barHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = self.Name,
		Parent = restore
	}, {TextColor3 = "Text"})
	local plusButton = GlyphButton(restore, "+", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(buttonWidth, barHeight - 8)
	})
	local barCloseButton = GlyphButton(restore, "X", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(buttonWidth, barHeight - 8)
	}, Icons.Close)

	local barOrigin
	local barStart
	self:Pointer(restore, function(input)
		local current = ViewSize(gui)
		local position = restore.Position
		barOrigin = input.Position
		barStart = Vector2.new(
			position.X.Scale * current.X + position.X.Offset,
			position.Y.Scale * current.Y + position.Y.Offset
		)
	end, function(input)
		local current = ViewSize(gui)
		local delta = input.Position - barOrigin
		restore.Position = UDim2.new(
			(barStart.X + delta.X) / current.X, 0,
			(barStart.Y + delta.Y) / current.Y, 0
		)
		self:ClampRestore()
	end)

	local exit3D = self:Make("TextButton", {
		Name = "Exit3D",
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.fromOffset(92, Touch and 34 or 28),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = "Exit 3D",
		Visible = false,
		Parent = gui
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(exit3D, 4)
	self:Stroke(exit3D, "Border")
	self:Pressable(exit3D, "Top")
	exit3D.MouseButton1Click:Connect(function()
		self:SetMode3D(false)
		if self.Toggle3D then
			self.Toggle3D:Set(false, true)
		end
	end)
	self.Exit3D = exit3D

	local notes = Create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 250, 1, -24),
		BackgroundTransparency = 1,
		Parent = gui
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = notes
	})
	self.Notes = notes

	hideButton.MouseButton1Click:Connect(function()
		self:SetHidden(true)
	end)
	plusButton.MouseButton1Click:Connect(function()
		self:SetHidden(false)
	end)
	closeButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end)
	barCloseButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end)

	self:Connect(UserInputService.InputBegan, function(input, processed)
		if processed or self.Closed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.ToggleKey then
			self:SetHidden(not self.Hidden)
		end
	end)

	local function BothOnMenu(positions)
		local origin = main.AbsolutePosition
		local size = main.AbsoluteSize
		for _, point in ipairs(positions) do
			if point.X < origin.X or point.X > origin.X + size.X or point.Y < origin.Y or point.Y > origin.Y + size.Y then
				return false
			end
		end
		return #positions > 1
	end

	local pinchBase
	self:Connect(UserInputService.TouchPinch, function(positions, pinchScale, _, state)
		if self.Hidden or self.Closed or self.Mode3D or not self.PinchEnabled then
			pinchBase = nil
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchBase = BothOnMenu(positions) and self.TargetScale or nil
		elseif state == Enum.UserInputState.Change then
			if pinchBase and BothOnMenu(positions) then
				self:SetScale(pinchBase * pinchScale)
			end
		else
			pinchBase = nil
		end
	end)

	self:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:OnViewport()
	end)

	self:Connect(UserInputService.InputChanged, function(input)
		local press = self.TouchPress
		if press and press.input == input then
			local moved = input.Position - press.origin
			if moved.Magnitude > 8 then
				self.TouchPress = nil
				if press.applied then
					Animate(press.button, {BackgroundColor3 = self.Theme[press.base]}, 0.1)
				end
			end
		end
	end)

	self:BuildTopTabs(config)
	if config.Background then
		self:SetBackground(config.Background, config.BackgroundOpacity)
	end

	if gate then
		self:RunGate(gate)
	end

	return self
end

GlobalEnv().En = Graphite

return Graphite
