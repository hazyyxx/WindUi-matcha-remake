-- MatchaUI.lua v1.0.0
-- Drawing-based floating window UI for Matcha executor
-- WindUI-compatible API

local MatchaUI = { Version = "1.0.0", Values = {}, _windows = {} }

-- ============================================================
-- Constants
-- ============================================================
local C = {
	TH = 32,       -- title bar height
	SW = 140,      -- sidebar width
	WW = 560,      -- default window width
	WH = 420,      -- default window height
	EH = 32,       -- element row height
	SH = 26,       -- section header height
	P  = 8,        -- padding
	TBH = 26,      -- tab button height
	TBP = 4,       -- tab button padding
	TWP = 0.42,    -- slider track width %
	TOW = 40,      -- toggle track width
	TOH = 16,      -- toggle track height
	FSM = 12,      -- font size small
	FMD = 13,      -- font size medium
	FLG = 14,      -- font size large
	CRN = 4,       -- corner radius
}

-- ============================================================
-- Services
-- ============================================================
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")

local _mouse
local function getMouse()
	if not _mouse then
		pcall(function() _mouse = Players.LocalPlayer:GetMouse() end)
	end
	return _mouse
end

-- Fonts (7 available in Matcha, with safe fallbacks)
local function _font(name)
	local f; pcall(function() f = Drawing.Fonts[name] end); return f
end
MatchaUI.Fonts = {}
for _,n in ipairs({"UI","System","SystemBold","Minecraft","Monospace","Pixel","Fortnite"}) do
	MatchaUI.Fonts[n] = _font(n)
end
local FNT  = MatchaUI.Fonts.System or MatchaUI.Fonts.UI or 0
local FNTB = MatchaUI.Fonts.SystemBold or FNT
function MatchaUI:SetFont(name) local f=self.Fonts[name]; if f~=nil then FNT=f end end
function MatchaUI:SetBoldFont(name) local f=self.Fonts[name]; if f~=nil then FNTB=f end end

-- ============================================================
-- Drawing helpers
-- ============================================================
local function sq(x,y,w,h,col,corner,zi,vis)
	local d = Drawing.new("Square")
	d.Filled=true; d.Color=col; d.Corner=corner or 0; d.ZIndex=zi or 50
	d.Position=Vector2.new(math.floor(x+.5),math.floor(y+.5))
	d.Size=Vector2.new(math.floor(w+.5),math.floor(h+.5))
	d.Thickness=1; d.Visible=vis~=false
	return d
end
local function tx(text,x,y,col,sz,font,zi,vis)
	local d = Drawing.new("Text")
	d.Text=tostring(text); d.Color=col; d.Size=sz or C.FMD
	pcall(function() d.Font=font or FNT end)
	pcall(function() d.Outline=true end)
	d.ZIndex=zi or 54
	d.Position=Vector2.new(math.floor(x+.5),math.floor(y+.5))
	d.Visible=vis~=false
	return d
end
local function ln(x1,y1,x2,y2,col,thick,zi,vis)
	local d = Drawing.new("Line")
	d.From=Vector2.new(math.floor(x1+.5),math.floor(y1+.5))
	d.To=Vector2.new(math.floor(x2+.5),math.floor(y2+.5))
	d.Color=col; d.Thickness=thick or 1; d.ZIndex=zi or 51; d.Visible=vis~=false
	return d
end
local function ci(x,y,r,col,zi,vis)
	local d = Drawing.new("Circle")
	d.Position=Vector2.new(math.floor(x+.5),math.floor(y+.5))
	d.Radius=r; d.Color=col; d.Filled=true; d.Thickness=1
	pcall(function() d.NumSides=20 end)
	d.ZIndex=zi or 53; d.Visible=vis~=false
	return d
end
local function lighten(c,t)
	return Color3.fromRGB(
		math.floor(math.min(255, c.R*255+(255-c.R*255)*t)),
		math.floor(math.min(255, c.G*255+(255-c.G*255)*t)),
		math.floor(math.min(255, c.B*255+(255-c.B*255)*t)))
end
local function darken(c,t)
	return Color3.fromRGB(math.floor(c.R*255*(1-t)),math.floor(c.G*255*(1-t)),math.floor(c.B*255*(1-t)))
end
-- HSV -> Color3 (avoids relying on Color3.fromHSV which may be absent)
local function hsv(h,s,v)
	local r,g,b
	local i=math.floor(h*6); local f=h*6-i
	local p=v*(1-s); local q=v*(1-f*s); local t=v*(1-(1-f)*s)
	i=i%6
	if i==0 then r,g,b=v,t,p elseif i==1 then r,g,b=q,v,p elseif i==2 then r,g,b=p,v,t
	elseif i==3 then r,g,b=p,q,v elseif i==4 then r,g,b=t,p,v else r,g,b=v,p,q end
	return Color3.fromRGB(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))
end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function flr(x) return math.floor(x+.5) end

-- ============================================================
-- Image / icon support (Matcha beta: Drawing.Image)
-- ============================================================
local _imgCache = {}
local function imgData(src)
	if not src or src=="" then return nil end
	if _imgCache[src]~=nil then return _imgCache[src] or nil end
	local data
	if type(src)=="string" then
		if src:match("^https?://") then
			pcall(function() data = game:HttpGet(src) end)
		elseif isfile and isfile(src) then
			pcall(function() data = readfile(src) end)
		else
			data = src  -- assume already-raw image bytes
		end
	end
	_imgCache[src] = data or false
	return data
end
-- Create a Drawing.Image defensively (property name for the data is uncertain
-- across Matcha builds, so try the common ones).
local function im(src,x,y,w,h,zi,vis)
	local d
	local ok=pcall(function() d=Drawing.new("Image") end)
	if not ok or not d then return nil end
	pcall(function() d.Position=Vector2.new(math.floor(x+.5),math.floor(y+.5)) end)
	pcall(function() d.Size=Vector2.new(w,h) end)
	pcall(function() d.ZIndex=zi or 55 end)
	pcall(function() d.Visible=vis~=false end)
	local data=imgData(src)
	if data then
		local set=false
		for _,prop in ipairs({"Data","Image","Bitmap","ImageData"}) do
			if not set then pcall(function() d[prop]=data; set=true end) end
		end
		if not set then for _,prop in ipairs({"Uri","Url"}) do
			if not set and type(src)=="string" then pcall(function() d[prop]=src; set=true end) end
		end end
	end
	return d
end

-- Matcha Drawing objects reject custom properties, so per-drawing metadata
-- (relative offsets, visibility flags) lives in a weak-keyed side table.
local META = setmetatable({}, {__mode="k"})
local function M(d) local m=META[d]; if not m then m={}; META[d]=m end; return m end

-- ============================================================
-- Themes
-- ============================================================
MatchaUI.Themes = {
	Dark        = { Accent=Color3.fromHex"#18181b", Dialog=Color3.fromHex"#161616", Text=Color3.fromHex"#FFFFFF", Placeholder=Color3.fromHex"#7a7a7a", Background=Color3.fromHex"#101010", Button=Color3.fromHex"#52525b", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#0091FF", Element=Color3.fromHex"#2A2A2C" },
	Light       = { Accent=Color3.fromHex"#d4d4d8", Dialog=Color3.fromHex"#f4f4f5", Text=Color3.fromHex"#000000", Placeholder=Color3.fromHex"#555555", Background=Color3.fromHex"#e9e9e9", Button=Color3.fromHex"#18181b", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#0091FF", Element=Color3.fromHex"#EEEEEE" },
	Rose        = { Accent=Color3.fromHex"#be185d", Dialog=Color3.fromHex"#4c0519", Text=Color3.fromHex"#fdf2f8", Placeholder=Color3.fromHex"#d67aa6", Background=Color3.fromHex"#1f0308", Button=Color3.fromHex"#e95f74", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#0091FF", Element=Color3.fromHex"#381E23" },
	Plant       = { Accent=Color3.fromHex"#166534", Dialog=Color3.fromHex"#052e16", Text=Color3.fromHex"#f0fdf4", Placeholder=Color3.fromHex"#4fbf7a", Background=Color3.fromHex"#0a1b0f", Button=Color3.fromHex"#16a34a", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#0091FF", Element=Color3.fromHex"#28342A" },
	Red         = { Accent=Color3.fromHex"#991b1b", Dialog=Color3.fromHex"#450a0a", Text=Color3.fromHex"#fef2f2", Placeholder=Color3.fromHex"#d95353", Background=Color3.fromHex"#1c0606", Button=Color3.fromHex"#dc2626", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#FF4444", Element=Color3.fromHex"#322221" },
	Indigo      = { Accent=Color3.fromHex"#3730a3", Dialog=Color3.fromHex"#1e1b4b", Text=Color3.fromHex"#f1f5f9", Placeholder=Color3.fromHex"#7078d9", Background=Color3.fromHex"#0f0a2e", Button=Color3.fromHex"#4f46e5", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#4f46e5", Element=Color3.fromHex"#282543" },
	Sky         = { Accent=Color3.fromHex"#00d4ff", Dialog=Color3.fromHex"#0a4d66", Text=Color3.fromHex"#e6f7ff", Placeholder=Color3.fromHex"#66b3cc", Background=Color3.fromHex"#051a26", Button=Color3.fromHex"#00a8cc", Toggle=Color3.fromHex"#00d9d9", Slider=Color3.fromHex"#00d4ff", Element=Color3.fromHex"#172E3B" },
	Violet      = { Accent=Color3.fromHex"#6d28d9", Dialog=Color3.fromHex"#3c1361", Text=Color3.fromHex"#faf5ff", Placeholder=Color3.fromHex"#8f7ee0", Background=Color3.fromHex"#1e0a3e", Button=Color3.fromHex"#7c3aed", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#7c3aed", Element=Color3.fromHex"#342650" },
	Amber       = { Accent=Color3.fromHex"#b45309", Dialog=Color3.fromHex"#451a03", Text=Color3.fromHex"#fffbeb", Placeholder=Color3.fromHex"#d1a326", Background=Color3.fromHex"#1c1003", Button=Color3.fromHex"#d97706", Toggle=Color3.fromHex"#f59e0b", Slider=Color3.fromHex"#d97706", Element=Color3.fromHex"#3A2E22" },
	Emerald     = { Accent=Color3.fromHex"#047857", Dialog=Color3.fromHex"#022c22", Text=Color3.fromHex"#ecfdf5", Placeholder=Color3.fromHex"#3fbf8f", Background=Color3.fromHex"#011411", Button=Color3.fromHex"#059669", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#059669", Element=Color3.fromHex"#202E2A" },
	Midnight    = { Accent=Color3.fromHex"#1e3a8a", Dialog=Color3.fromHex"#0c1e42", Text=Color3.fromHex"#dbeafe", Placeholder=Color3.fromHex"#2f74d1", Background=Color3.fromHex"#0a0f1e", Button=Color3.fromHex"#2563eb", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#2563eb", Element=Color3.fromHex"#242836" },
	Crimson     = { Accent=Color3.fromHex"#b91c1c", Dialog=Color3.fromHex"#450a0a", Text=Color3.fromHex"#fef2f2", Placeholder=Color3.fromHex"#6f757b", Background=Color3.fromHex"#0c0404", Button=Color3.fromHex"#991b1b", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#b91c1c", Element=Color3.fromHex"#251F1F" },
	MonokaiPro  = { Accent=Color3.fromHex"#fc9867", Dialog=Color3.fromHex"#1e1e1e", Text=Color3.fromHex"#fcfcfa", Placeholder=Color3.fromHex"#6f6f6f", Background=Color3.fromHex"#191622", Button=Color3.fromHex"#ab9df2", Toggle=Color3.fromHex"#a9dc76", Slider=Color3.fromHex"#fc9867", Element=Color3.fromHex"#323039" },
	CottonCandy = { Accent=Color3.fromHex"#ec4899", Dialog=Color3.fromHex"#2d1b3d", Text=Color3.fromHex"#fdf2f8", Placeholder=Color3.fromHex"#8a5fd3", Background=Color3.fromHex"#1a0b2e", Button=Color3.fromHex"#d946ef", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#d946ef", Element=Color3.fromHex"#312643" },
	Mellowsi    = { Accent=Color3.fromHex"#342A1E", Dialog=Color3.fromHex"#291C13", Text=Color3.fromHex"#F5EBDD", Placeholder=Color3.fromHex"#9C8A73", Background=Color3.fromHex"#1C1002", Button=Color3.fromHex"#342A1E", Toggle=Color3.fromHex"#a9873f", Slider=Color3.fromHex"#C9A24D", Element=Color3.fromHex"#33291E" },
	Rainbow     = { Accent=Color3.fromHex"#00ff41", Dialog=Color3.fromHex"#1a0030", Text=Color3.fromHex"#ffffff", Placeholder=Color3.fromHex"#00ff80", Background=Color3.fromHex"#0a0015", Button=Color3.fromHex"#ff0080", Toggle=Color3.fromHex"#33C759", Slider=Color3.fromHex"#00ffff", Element=Color3.fromHex"#200820" },
}
MatchaUI.Theme = MatchaUI.Themes.Dark
function MatchaUI:SetTheme(name)
	self.Theme = self.Themes[name] or self.Themes.Dark
	for _,w in ipairs(self._windows or {}) do pcall(function() w:_applyTheme() end) end
end
function MatchaUI:SetAccent(color)
	if self.Theme then self.Theme.Accent = color end
	for _,w in ipairs(self._windows or {}) do pcall(function() w:_applyTheme() end) end
end

-- ============================================================
-- VK table
-- ============================================================
local KV = {A=0x41,B=0x42,C=0x43,D=0x44,E=0x45,F=0x46,G=0x47,H=0x48,I=0x49,J=0x4A,K=0x4B,L=0x4C,M=0x4D,N=0x4E,O=0x4F,P=0x50,Q=0x51,R=0x52,S=0x53,T=0x54,U=0x55,V=0x56,W=0x57,X=0x58,Y=0x59,Z=0x5A,["0"]=0x30,["1"]=0x31,["2"]=0x32,["3"]=0x33,["4"]=0x34,["5"]=0x35,["6"]=0x36,["7"]=0x37,["8"]=0x38,["9"]=0x39,F1=0x70,F2=0x71,F3=0x72,F4=0x73,F5=0x74,F6=0x75,F7=0x76,F8=0x77,F9=0x78,F10=0x79,F11=0x7A,F12=0x7B,Space=0x20,Enter=0x0D,Escape=0x1B,Backspace=0x08,Tab=0x09,Shift=0x10,Ctrl=0x11,Alt=0x12,Delete=0x2E,Left=0x25,Up=0x26,Right=0x27,Down=0x28,LMB=0x01,RMB=0x02,MMB=0x04}
local VK = {}
for k,v in pairs(KV) do VK[v]=k end
-- VK → printable char for Input element
local VC = {}
for i=0x41,0x5A do VC[i]=string.char(i+32) end
for i=0x30,0x39 do VC[i]=string.char(i) end
VC[0x20]=" "; VC[0xBE]="."; VC[0xBC]=","; VC[0xBF]="/"; VC[0xBA]=";"; VC[0xBD]="-"; VC[0xBB]="="

-- Matcha UIS.InputBegan gives KeyCode as a raw VK integer (no Enum.KeyCode).
-- Handle both raw-int and Enum forms defensively.
local function inpVK(inp)
	local kc = inp.KeyCode
	if type(kc)=="number" then return kc end
	local ok,v = pcall(function() return kc and kc.Value end)
	return ok and v or nil
end

-- ============================================================
-- Config system
-- ============================================================
local function buildCfgMgr(win)
	local base = "C:/matcha/workspace/MatchaUI/"
	local path = base .. (win.Folder or "default") .. "/config/"
	pcall(function()
		if not isfolder(base) then makefolder(base) end
		if not isfolder(base..(win.Folder or "default")) then makefolder(base..(win.Folder or "default")) end
		if not isfolder(path) then makefolder(path) end
	end)

	local function toHex(c) return string.format("%02X%02X%02X",flr(c.R*255),flr(c.G*255),flr(c.B*255)) end
	local parsers = {
		Toggle    = { S=function(e) return {__type="Toggle",   value=e.Value} end,                           L=function(e,d) if e.Set then e:Set(d.value==true or d.value=="true") end end },
		Slider    = { S=function(e) return {__type="Slider",   value=e.Value} end,                           L=function(e,d) if e.Set then e:Set(tonumber(d.value) or 0) end end },
		Dropdown  = { S=function(e) return {__type="Dropdown", value=e.Value} end,                           L=function(e,d) if e.Set then e:Set(d.value) end end },
		Input     = { S=function(e) return {__type="Input",    value=e.Value} end,                           L=function(e,d) if e.Set then e:Set(tostring(d.value or "")) end end },
		Keybind   = { S=function(e) return {__type="Keybind",  value=e.Value} end,                           L=function(e,d) if e.Set then e:Set(tostring(d.value or "")) end end },
		Colorpicker={ S=function(e) return {__type="Colorpicker",value=toHex(e.Value or Color3.new(1,1,1))} end, L=function(e,d) if e.Set then pcall(function() e:Set(Color3.fromHex(d.value)) end) end end },
	}

	local CM = { Path=path, Configs={} }

	function CM:Config(name, autoload)
		name = name or "default"
		local cfgPath = path .. name .. ".json"
		local cfg = { _id=name, Path=cfgPath, Elements={}, CustomData={}, AutoLoad=autoload or false }

		function cfg:Register(flag, elem) cfg.Elements[flag] = elem end
		function cfg:Set(k,v) cfg.CustomData[k]=v end
		function cfg:Get(k) return cfg.CustomData[k] end

		function cfg:Save()
			if not writefile then return false end
			-- pull in any pending flags from the window
			if win._flags then for flag,elem in pairs(win._flags) do if not cfg.Elements[flag] then cfg.Elements[flag]=elem end end end
			local data = {__version="1.0",__autoload=cfg.AutoLoad,__custom=cfg.CustomData,__elements={}}
			for flag,elem in pairs(cfg.Elements) do
				local p = parsers[elem.__type]
				if p then data.__elements[tostring(flag)] = p.S(elem) end
			end
			local ok,json = pcall(function() return HttpService:JSONEncode(data) end)
			if ok then pcall(writefile, cfgPath, json); return true end
			return false
		end

		function cfg:Load()
			if not readfile then return false end
			local ok2,raw = pcall(function() return isfile and isfile(cfgPath) end)
			if not ok2 or not raw then return false end
			local ok,data = pcall(function() return HttpService:JSONDecode(readfile(cfgPath)) end)
			if not ok or not data then return false end
			if win._flags then for flag,elem in pairs(win._flags) do if not cfg.Elements[flag] then cfg.Elements[flag]=elem end end end
			for flag,edata in pairs(data.__elements or {}) do
				local elem = cfg.Elements[flag]
				local p = edata.__type and parsers[edata.__type]
				if elem and p then task.spawn(function() p.L(elem,edata) end) end
			end
			cfg.CustomData = data.__custom or {}
			return cfg.CustomData
		end

		function cfg:Delete()
			if not delfile then return false end
			pcall(delfile, cfgPath)
			CM.Configs[name] = nil
			return true
		end

		if autoload then task.spawn(function() task.wait(0.6); pcall(function() cfg:Load() end) end) end
		CM.Configs[name] = cfg
		win.CurrentConfig = cfg
		return cfg
	end

	CM.CreateConfig = CM.Config
	function CM:AllConfigs()
		if not listfiles or not isfolder(path) then return {} end
		local ok,files = pcall(listfiles, path)
		if not ok or not files then return {} end
		local r = {}
		for _,f in ipairs(files) do local n=f:match("([^\\/]+)%.json$"); if n then r[#r+1]=n end end
		return r
	end
	function CM:GetConfig(name) return CM.Configs[name] end
	return CM
end

-- ============================================================
-- CreateWindow
-- ============================================================
function MatchaUI:CreateWindow(config)
	config = config or {}
	if config.Theme then self:SetTheme(config.Theme) end
	local T = self.Theme
	self._windows = self._windows or {}

	local vp = workspace.CurrentCamera.ViewportSize
	local WW = (config.Size and config.Size.X) or C.WW
	local WH = (config.Size and config.Size.Y) or C.WH

	local win = {
		Title   = config.Title or "Script",
		Folder  = config.Folder or "MatchaUI",
		wx = flr((vp.X-WW)/2), wy = flr((vp.Y-WH)/2),
		ww = WW, wh = WH,
		_alive=true, _minimized=false,
		_tabs={}, _active=nil,
		_scrollY=0, _scrollMax=0,
		_all={}, _hbs={},   -- all drawings, all hitboxes
		_flags={},          -- flag→elem registry
		_keybinds={},       -- set of keybind elements to poll
		_kCapture=nil,      -- keybind capture callback
		_iCapture=nil,      -- input capture elem
		_iConn=nil,         -- UIS connection for input
	}

	-- ---- helpers ----
	local function reg(d) win._all[#win._all+1]=d; return d end
	local function hb(x,y,x2,y2,fn,extra)
		local h={x=x,y=y,x2=x2,y2=y2,fn=fn}
		if extra then for k,v in pairs(extra) do h[k]=v end end
		win._hbs[#win._hbs+1]=h; return h
	end

	-- ---- window chrome ----
	local wBrd  = reg(sq(win.wx-1,win.wy-1,WW+2,WH+2, darken(T.Background,.5), C.CRN+1,48))
	local wBg   = reg(sq(win.wx,win.wy,WW,WH, T.Background, C.CRN,50))
	local wBar  = reg(sq(win.wx,win.wy,WW,C.TH, T.Accent, C.CRN,51))
	local wBarB = reg(sq(win.wx,win.wy+C.TH-4,WW,8, T.Accent,0,51))  -- cover rounded bottom of bar
	local _titleX = C.P+2
	if config.Icon then
		local wIco = im(config.Icon, win.wx+C.P, win.wy+7, 18,18, 56, true)
		if wIco then reg(wIco); local mi=M(wIco); mi.rx=C.P; mi.ry=7; _titleX = C.P+24 end
	end
	local wTtx  = reg(tx(win.Title, win.wx+_titleX,win.wy+9, T.Text, C.FLG,FNTB,55))
	local wSide = reg(sq(win.wx,win.wy+C.TH,C.SW,WH-C.TH, T.Dialog,0,50))
	local wSLn  = reg(ln(win.wx+C.SW,win.wy+C.TH, win.wx+C.SW,win.wy+WH, darken(T.Dialog,.35),1,52))
	local wCont = reg(sq(win.wx+C.SW+1,win.wy+C.TH,WW-C.SW-1,WH-C.TH, T.Background,0,49))
	-- scrollbar (geometry managed dynamically by win:_updateScrollbar)
	local wSbThumb = reg(sq(win.wx+WW-7,win.wy+C.TH+2,4,40, lighten(T.Dialog,.25),2,60,false))
	-- tooltip (positioned dynamically at cursor)
	local wTipBg = reg(sq(0,0,10,18, darken(T.Dialog,.25),4,95,false))
	local wTipTx = reg(tx("",0,0, T.Text, C.FSM,FNT,96,false))
	-- close & minimize
	local cX,cY = win.wx+WW-28,win.wy+7
	local mX,mY = win.wx+WW-52,win.wy+7
	local wClBg = reg(sq(cX,cY,20,18,Color3.fromRGB(180,40,40),3,56))
	local wClTx = reg(tx("x",cX+6,cY+2,Color3.fromRGB(255,255,255),C.FLG,FNTB,58))
	local wMnBg = reg(sq(mX,mY,20,18,darken(T.Accent,.4),3,56))
	local wMnTx = reg(tx("-",mX+7,mY+1,T.Text,C.FLG,FNTB,58))

	-- ---- position refresh ----
	-- Each drawing carries _rx,_ry (relative offsets from wx,wy).
	-- Lines also carry _rx2,_ry2 for the To endpoint.
	local function setRel(d,rx,ry,rx2,ry2)
		local m=M(d); m.rx=rx; m.ry=ry
		if rx2 then m.rx2=rx2; m.ry2=ry2 end
	end
	setRel(wBrd,-1,-1); setRel(wBg,0,0); setRel(wBar,0,0); setRel(wBarB,0,C.TH-4)
	setRel(wTtx,C.P+2,9); setRel(wSide,0,C.TH); setRel(wSLn,C.SW,C.TH,C.SW,WH)
	setRel(wCont,C.SW+1,C.TH); setRel(wClBg,WW-28,7); setRel(wClTx,WW-23,9)
	setRel(wMnBg,WW-52,7); setRel(wMnTx,WW-48,10)

	local function refreshChrome()
		for _,d in ipairs(win._all) do
			local m=META[d]
			if m and m.rx then
				if m.rx2 then  -- Line: use From/To, never Position
					d.From = Vector2.new(flr(win.wx+m.rx+.5),flr(win.wy+m.ry+.5))
					d.To   = Vector2.new(flr(win.wx+m.rx2+.5),flr(win.wy+m.ry2+.5))
				else
					d.Position = Vector2.new(flr(win.wx+m.rx+.5),flr(win.wy+m.ry+.5))
				end
			end
		end
	end

	-- Content clipping check
	local function inClip(y) return y >= win.wy+C.TH and y < win.wy+WH-2 end

	-- Scrollbar geometry (driven by active tab's scroll state)
	local function viewH() return WH-C.TH-4 end
	function win:_updateScrollbar()
		local sMax = win._scrollMax or 0
		if win._minimized or not win._active or sMax<=0 then
			wSbThumb.Visible=false; win._sbRect=nil; return
		end
		local vh=viewH(); local total=vh+sMax
		local thH=math.max(24, flr(vh*vh/total))
		local trackY=win.wy+C.TH+2
		local travel=vh-thH
		local sy=clamp(win._scrollY,0,sMax)
		local thY=trackY + (sMax>0 and flr(travel*(sy/sMax)) or 0)
		local thX=win.wx+WW-7
		wSbThumb.Position=Vector2.new(thX,thY)
		wSbThumb.Size=Vector2.new(4,thH)
		wSbThumb.Visible=true
		win._sbRect={x=thX-3,y=thY,x2=thX+7,y2=thY+thH,thH=thH,trackY=trackY,travel=travel}
	end
	-- Convert a mouse Y (with grab offset) into scrollY and apply
	function win:_scrollTo(my, grabOff)
		local r=win._sbRect; if not r then return end
		local sMax=win._scrollMax or 0
		local rel=clamp((my-grabOff-r.trackY)/math.max(1,r.travel),0,1)
		win._scrollY=flr(rel*sMax)
		if win._active then win._active:_refreshContentPos(); win._active:_refreshContentHbs() end
		win:_updateScrollbar()
	end

	-- ---- chrome hitboxes ----
	local closeHb = hb(cX,cY,cX+20,cY+18, function() win:Destroy() end)
	closeHb._chrome=true; closeHb._dRx=WW-28; closeHb._dRy=7; closeHb._dW=20; closeHb._dH=18

	local minHb = hb(mX,mY,mX+20,mY+18, function()
		win._minimized = not win._minimized
		local show = not win._minimized
		wBg.Size   = show and Vector2.new(WW,WH) or Vector2.new(WW,C.TH)
		wBrd.Size  = show and Vector2.new(WW+2,WH+2) or Vector2.new(WW+2,C.TH+2)
		wSide.Visible=show; wSLn.Visible=show; wCont.Visible=show
		for _,t in ipairs(win._tabs) do
			if t._btn then t._btn.Visible=show end
			if t._btx then t._btx.Visible=show end
			if t._bico then t._bico.Visible=show end
		end
		if win._active then win._active:_setAllVis(show) end
		win:_updateScrollbar()
	end)
	minHb._chrome=true; minHb._dRx=WW-52; minHb._dRy=7; minHb._dW=20; minHb._dH=18

	local function refreshChromeHbs()
		for _,h in ipairs(win._hbs) do
			if h._chrome then
				h.x=win.wx+h._dRx; h.y=win.wy+h._dRy
				h.x2=h.x+h._dW;    h.y2=h.y+h._dH
			end
		end
	end

	-- ============================================================
	-- Tab buttons
	-- ============================================================
	local function tabBtnY(idx) return win.wy+C.TH+(idx-1)*(C.TBH+2)+C.TBP end

	local function makeTabBtn(idx, title, icon)
		local T2=MatchaUI.Theme
		local by=tabBtnY(idx)
		local relY=(idx-1)*(C.TBH+2)+C.TH+C.TBP
		local btn=reg(sq(win.wx+C.TBP,by,C.SW-C.TBP*2,C.TBH, T2.Dialog,3,52))
		setRel(btn,C.TBP,relY)
		local txX=C.P+6; local ico
		if icon then
			ico=im(icon, win.wx+C.P+4, by+(C.TBH-15)//2, 15,15, 54, true)
			if ico then reg(ico); setRel(ico,C.P+4,relY+(C.TBH-15)//2); txX=C.P+24 end
		end
		local btx=reg(tx(title,win.wx+txX,by+6, T2.Placeholder,C.FSM,FNT,54))
		setRel(btx,txX,relY+6)
		return btn,btx,ico
	end

	-- ============================================================
	-- win:Tab
	-- ============================================================
	function win:Tab(cfg2)
		local T2=MatchaUI.Theme
		local ttl = type(cfg2)=="string" and cfg2 or (cfg2 and cfg2.Title or "Tab")
		local idx = #win._tabs+1
		local tab = { _title=ttl, _idx=idx, _sections={}, _built=false, _active=false, _tdraws={}, _thbs={} }
		win._tabs[#win._tabs+1]=tab

		local ticon = type(cfg2)=="table" and cfg2.Icon or nil
		tab._btn, tab._btx, tab._bico = makeTabBtn(idx, ttl, ticon)

		-- tab hitbox (sidebar button)
		local function tHbCoords()
			local by=tabBtnY(idx)
			return win.wx+C.TBP, by, win.wx+C.SW-C.TBP, by+C.TBH
		end
		local x1,y1,x2,y2=tHbCoords()
		local tbHb=hb(x1,y1,x2,y2, function()
			if win._active==tab then return end
			if win._active then win._active:_deactivate() end
			win._active=tab; win._scrollY=0; win._scrollMax=tab._scrollMax or 0
			tab:_activate()
			if not tab._built then tab:_build() else tab:_refreshContentPos(); tab:_refreshContentHbs() end
			win:_updateScrollbar()
		end)
		tbHb._tabHb=true; tbHb._tabIdx=idx

		function tab:_refreshTabHb()
			local a,b,c2,d2=tHbCoords()
			tbHb.x=a; tbHb.y=b; tbHb.x2=c2; tbHb.y2=d2
		end

		function tab:_setAllVis(v)
			for _,d in ipairs(tab._tdraws) do
				if v and M(d).own then d.Visible=inClip(d.Position.Y)
				elseif not v then d.Visible=false end
			end
		end

		function tab:_closePopups()
			for _,sc in ipairs(tab._sections) do
				for _,el in ipairs(sc._elements) do
					if el._popupDs then for _,d in ipairs(el._popupDs) do pcall(function()d:Remove()end) end; el._popupDs=nil end
				end
			end
			for i=#tab._thbs,1,-1 do if tab._thbs[i]._pop then table.remove(tab._thbs,i) end end
		end

		function tab:_deactivate()
			tab._active=false
			tab._btn.Color=MatchaUI.Theme.Dialog
			tab._btx.Color=MatchaUI.Theme.Placeholder
			tab:_closePopups()
			tab:_setAllVis(false)
		end

		function tab:_activate()
			tab._active=true
			tab._btn.Color=lighten(MatchaUI.Theme.Accent,.2)
			tab._btx.Color=MatchaUI.Theme.Text
			tab:_setAllVis(true)
		end

		-- content origin (absolute)
		local function CX() return win.wx+C.SW+1 end
		local function CY() return win.wy+C.TH end
		local function CW() return WW-C.SW-1 end
		local function EW() return CW()-C.P*2-8 end  -- reserve right gutter for scrollbar

		-- register content drawing: stores relative offset within content area
		local function rcd(d, cx,cy, opts)
			local m=M(d); m.crx=cx; m.cry=cy; m.own=true  -- relative to content area origin
			if opts then for k,v in pairs(opts) do m[k]=v end end
			tab._tdraws[#tab._tdraws+1]=d
			win._all[#win._all+1]=d
			return d
		end
		local function setOwn(list, show)
			for _,d in ipairs(list) do local m=M(d); m.own=show; m.elemVis=show end
		end

		function tab:_refreshContentPos()
			local ox=CX(); local oy=CY(); local sy=win._scrollY
			local clipT=oy; local clipB=oy+WH-C.TH-2
			for _,d in ipairs(tab._tdraws) do
				local m=META[d]
				if m and m.crx ~= nil then
					local ax=ox+C.P+m.crx
					local ay=oy+m.cry-sy
					if m.crx2~=nil then  -- Line: use From/To, never Position
						d.From=Vector2.new(flr(ax+.5),flr(ay+.5))
						d.To=Vector2.new(flr(ox+C.P+m.crx2+.5),flr(oy+m.cry2-sy+.5))
					else
						d.Position=Vector2.new(flr(ax+.5),flr(ay+.5))
					end
					if m.own then
						d.Visible = tab._active and m.elemVis~=false and (ay>=clipT and ay<clipB)
					end
				end
			end
		end

		function tab:_refreshContentHbs()
			local ox=CX(); local oy=CY(); local sy=win._scrollY
			for _,h in ipairs(tab._thbs) do
				if h._crx~=nil then
					h.x=ox+C.P+h._crx; h.y=oy+h._cry-sy
					h.x2=ox+C.P+h._crx2; h.y2=oy+h._cry2-sy
				end
			end
			-- also refresh chrome and tab hitboxes
			refreshChromeHbs()
			for _,t in ipairs(win._tabs) do t:_refreshTabHb() end
		end

		local function chb(crx,cry,crx2,cry2, fn, extra)
			local ox=CX(); local oy=CY(); local sy=win._scrollY
			local h={
				x=ox+C.P+crx, y=oy+cry-sy, x2=ox+C.P+crx2, y2=oy+cry2-sy,
				fn=fn, _crx=crx,_cry=cry,_crx2=crx2,_cry2=cry2,
			}
			if extra then for k,v in pairs(extra) do h[k]=v end end
			tab._thbs[#tab._thbs+1]=h
			return h
		end

		-- ============================================================
		-- tab:Section
		-- ============================================================
		function tab:Section(cfg3)
			local stl = type(cfg3)=="string" and cfg3 or (cfg3 and cfg3.Title or "")
			local sec={_title=stl, _elements={}, _collapsed=false}
			tab._sections[#tab._sections+1]=sec

			local function addEl(e,c)
				if c and type(c)=="table" and c.Tooltip then e.Tooltip=c.Tooltip end
				if e._id then win._flags[e._id]=e; MatchaUI.Values[e._id]=e.Value end
				sec._elements[#sec._elements+1]=e
				return e
			end

			function sec:Toggle(c)
				local e={__type="Toggle",_id=c.Flag or c.Title,Title=c.Title or "Toggle",Value=c.Value or false,Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:Set(v,nc) self.Value=v; if self._id then MatchaUI.Values[self._id]=v end
					if self._track then self._track.Color=v and MatchaUI.Theme.Toggle or MatchaUI.Theme.Button end
					if self._thumb and self._track then
						local th=C.TOH; local tw=C.TOW
						local tm=M(self._thumb); local trm=M(self._track)
						tm.crx = v and (trm.crx+tw-th//2) or (trm.crx+th//2)
						local base=self._track.Position.X-trm.crx
						self._thumb.Position=Vector2.new(flr(base+tm.crx+.5),self._thumb.Position.Y)
					end
					if not nc then pcall(self.Callback,v) end
				end
				return addEl(e,c)
			end

			function sec:Slider(c)
				local e={__type="Slider",_id=c.Flag or c.Title,Title=c.Title or "Slider",
					Value=(c.Value and c.Value.Default) or 0, Min=(c.Value and c.Value.Min) or 0,
					Max=(c.Value and c.Value.Max) or 100, Step=c.Step or 1,
					Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:Set(v,nc)
					v=clamp(v,self.Min,self.Max)
					if self.Step==math.floor(self.Step) then v=math.floor(v/self.Step+.5)*self.Step end
					self.Value=v; if self._id then MatchaUI.Values[self._id]=v end
					if self._fill and self._trackW then
						local pct=(v-self.Min)/math.max(1,self.Max-self.Min)
						local fw=math.max(4,flr(pct*self._trackW+.5))
						self._fill.Size=Vector2.new(fw,self._fill.Size.Y)
						local fm=M(self._fill)
						if self._thumb2 and fm.crx~=nil then
							local t2m=M(self._thumb2)
							t2m.crx=fm.crx+fw
							local base=self._fill.Position.X-fm.crx
							self._thumb2.Position=Vector2.new(flr(base+t2m.crx+.5),self._fill.Position.Y+self._fill.Size.Y//2)
						end
						if self._vtx then
							local isF=self.Step~=math.floor(self.Step)
							self._vtx.Text=isF and string.format("%.1f",v) or tostring(flr(v))
						end
					end
					if not nc then pcall(self.Callback,v) end
				end
				return addEl(e,c)
			end

			function sec:Dropdown(c)
				local function flat(vals)
					local r={}
					for _,v in ipairs(vals or {}) do
						if type(v)=="string" then r[#r+1]=v
						elseif type(v)=="table" and v.Title then r[#r+1]=v.Title end
					end
					return r
				end
				local items=flat(c.Values)
				local defV=c.Value
				if type(defV)=="number" then defV=items[defV] end
				local e={__type="Dropdown",_id=c.Flag or c.Title,Title=c.Title or "Dropdown",
					Value=defV or items[1],Items=items,Callback=c.Callback or function()end,
					_drawings={},_elemVis=true,_popupDs=nil}
				function e:Set(v,nc) self.Value=v; if self._id then MatchaUI.Values[self._id]=v end
					if self._stx then self._stx.Text=tostring(v or "") end
					if not nc then pcall(self.Callback,v) end
				end
				function e:Refresh(nv)
					local r={}
					for _,v in ipairs(nv or {}) do
						if type(v)=="string" then r[#r+1]=v
						elseif type(v)=="table" and v.Title then r[#r+1]=v.Title end
					end
					self.Items=r
				end
				function e:Select(v) if type(v)=="table" then v=v[1] end; self:Set(v) end
				return addEl(e,c)
			end

			function sec:Button(c)
				local e={__type="Button",Title=c.Title or "Button",Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:Highlight()
					if self._bg then local oc=self._bg.Color; pcall(function() self._bg.Color=lighten(MatchaUI.Theme.Button,.4) end)
						task.spawn(function() task.wait(.25); pcall(function() self._bg.Color=oc end) end) end
				end
				return addEl(e,c)
			end

			function sec:Keybind(c)
				local e={__type="Keybind",_id=c.Flag or c.Title,Title=c.Title or "Keybind",
					Value=c.Value or "F",_vk=KV[c.Value] or 0x46,
					Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:IsEnabled() return iskeypressed and iskeypressed(self._vk) or false end
				function e:Set(v,nc)
					if type(v)=="string" then self.Value=v; self._vk=KV[v] or self._vk
					elseif type(v)=="number" then self._vk=v; self.Value=VK[v] or tostring(v) end
					if self._id then MatchaUI.Values[self._id]=self.Value end
					if self._ktx then self._ktx.Text="["..self.Value.."]" end
					if not nc then pcall(self.Callback,self.Value) end
				end
				return addEl(e,c)
			end

			function sec:Input(c)
				local e={__type="Input",_id=c.Flag or c.Title,Title=c.Title or "Input",
					Value=c.Value or "",Placeholder=c.Placeholder or "Type...",
					Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:Set(v,nc) self.Value=tostring(v or ""); if self._id then MatchaUI.Values[self._id]=self.Value end
					if self._itx then
						self._itx.Text=#self.Value>0 and self.Value or self.Placeholder
						self._itx.Color=#self.Value>0 and MatchaUI.Theme.Text or MatchaUI.Theme.Placeholder
					end
					if not nc then pcall(self.Callback,self.Value) end
				end
				return addEl(e,c)
			end

			function sec:Colorpicker(c)
				local dC=c.Default or Color3.fromRGB(255,255,255)
				local e={__type="Colorpicker",_id=c.Flag or c.Title,Title=c.Title or "Color",
					Default=dC,Value=dC,Transparency=c.Transparency or 1,
					Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:Set(v,nc) self.Value=v; self.Default=v; if self._id then MatchaUI.Values[self._id]=v end
					if self._prev then self._prev.Color=v end
					if not nc then pcall(self.Callback,v) end
				end
				function e:Update(v,tr) self:Set(v,false) end
				return addEl(e,c)
			end

			function sec:Checkbox(c)
				local e={__type="Toggle",_ctype="Checkbox",_id=c.Flag or c.Title,Title=c.Title or "Checkbox",Value=c.Value or false,Callback=c.Callback or function()end,_drawings={},_elemVis=true}
				function e:Set(v,nc) self.Value=v; if self._id then MatchaUI.Values[self._id]=v end
					if self._box then self._box.Color=v and MatchaUI.Theme.Toggle or MatchaUI.Theme.Button end
					if self._tick then self._tick.Visible=v and (self._elemVis~=false) end
					if not nc then pcall(self.Callback,v) end
				end
				return addEl(e,c)
			end

			function sec:Label(c)
				local e={__type="Label",_id=c.Flag,Title=(type(c)=="string" and c) or c.Title or "Label",
					Value=(type(c)=="table" and c.Value) or "",_drawings={},_elemVis=true}
				function e:SetValue(v) self.Value=tostring(v or ""); if self._vtx then self._vtx.Text=self.Value end
					if self._id then MatchaUI.Values[self._id]=self.Value end end
				e.Set=e.SetValue
				return addEl(e,c)
			end

			function sec:Paragraph(c)
				c=c or {}
				local e={__type="Paragraph",Title=c.Title or "",Desc=c.Desc or c.Content or "",_drawings={},_elemVis=true}
				function e:SetTitle(t) self.Title=tostring(t or ""); if self._ttx then self._ttx.Text=self.Title end end
				function e:SetDesc(t) self.Desc=tostring(t or ""); if self._dtx then self._dtx.Text=self.Desc end end
				sec._elements[#sec._elements+1]=e
				return e
			end

			function sec:Space() sec._elements[#sec._elements+1]={__type="Space",_drawings={},_elemVis=true} end

			function sec:Text(c)
				local t=type(c)=="string" and c or (c and (c.Title or c.Content or "") or "")
				sec._elements[#sec._elements+1]={__type="Text",text=t,_drawings={},_elemVis=true}
			end

			function sec:Section(c)
				local t=type(c)=="string" and c or (c and c.Title or "")
				sec._elements[#sec._elements+1]={__type="Text",text=t,isHdr=true,_drawings={},_elemVis=true}
			end

			return sec
		end  -- tab:Section

		-- shorthand element methods directly on tab (NOT "Section" — that is a real method)
		for _,m in ipairs({"Toggle","Slider","Dropdown","Button","Checkbox","Keybind","Input","Colorpicker","Label","Paragraph","Space","Text"}) do
			local mm=m
			tab[mm]=function(self,c)
				if #self._sections==0 then self:Section({Title=""}) end
				local s=self._sections[#self._sections]
				return s[mm](s,c)
			end
		end
		function tab:Group(c) return self:Section(c or {Title=""}) end

		-- ============================================================
		-- tab:_build — creates all Drawing objects
		-- ============================================================
		function tab:_build()
			if tab._built then return end
			tab._built=true
			local T2=MatchaUI.Theme
			local ew=EW()
			local cy=C.P  -- running Y within content area

			for _,sec in ipairs(tab._sections) do
				-- Section header
				if sec._title ~= "" then
					local shBg  = rcd(sq(0,0,ew,C.SH,darken(T2.Accent,.15),3,51,tab._active), 0,cy)
					local shTx  = rcd(tx(sec._title,0,0,T2.Text,C.FSM,FNTB,55,tab._active), C.P,cy+6)
					local shArr = rcd(tx(sec._collapsed and "+" or "-",0,0,T2.Placeholder,C.FSM,FNT,55,tab._active), ew-18,cy+6)
					-- collapse hitbox
					local scy=cy
					local shrH=chb(0,scy,ew,scy+C.SH, function()
						sec._collapsed=not sec._collapsed
						shArr.Text=sec._collapsed and "+" or "-"
						for _,el in ipairs(sec._elements) do
							local show=not sec._collapsed and tab._active
							el._elemVis=show
							for _,d in ipairs(el._drawings or {}) do
								M(d).own=show
								d.Visible=show and inClip(d.Position.Y)
							end
						end
					end)
					cy=cy+C.SH+2
					-- suppress unused refs
				end

				-- Elements
				for _,el in ipairs(sec._elements) do
					local ecy=cy
					local show=tab._active and not sec._collapsed
					el._elemVis=show
					local elH=C.EH
					local lblx = (el.Icon and (C.P+22)) or C.P
					local _thb0=#tab._thbs

					if el.__type=="Toggle" and el._ctype=="Checkbox" then
						local bg   = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl  = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local bs=18; local bx=ew-bs-C.P; local by=ecy+(C.EH-bs)//2
						local box  = rcd(sq(0,0,bs,bs,el.Value and T2.Toggle or T2.Button,4,53,show), bx,by)
						local tick = rcd(tx("X",0,0,Color3.fromRGB(255,255,255),C.FMD,FNTB,55,show and el.Value), bx+4,by+1)
						setOwn({bg,lbl,box}, show)
						M(tick).own=(show and el.Value); M(tick).elemVis=el.Value
						el._drawings={bg,lbl,box,tick}; el._box=box; el._tick=tick
						chb(0,ecy,ew,ecy+C.EH, function() el:Set(not el.Value) end)

					elseif el.__type=="Toggle" then
						local bg   = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl  = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local tw=C.TOW; local th=C.TOH
						local trkX=ew-tw-C.P; local trkY=ecy+8
						local trk  = rcd(sq(0,0,tw,th,el.Value and T2.Toggle or T2.Button,th//2,53,show), trkX,trkY)
						local tmX  = el.Value and (trkX+tw-th+2) or (trkX+2)
						local tmb  = rcd(ci(0,0,th//2-2,Color3.fromRGB(255,255,255),55,show), tmX+th//2-2,trkY+th//2)
						setOwn({bg,lbl,trk,tmb}, show)
						el._drawings={bg,lbl,trk,tmb}; el._track=trk; el._thumb=tmb
						chb(0,ecy,ew,ecy+C.EH, function()
							el:Set(not el.Value)
							-- thumb position is updated inside Set via _track.Position
						end)

					elseif el.__type=="Slider" then
						local bg  = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+6)
						local tw  = flr(ew*C.TWP)
						local tkX = ew-tw-C.P; local tkY=ecy+14; local tkH=5
						local tkBg= rcd(sq(0,0,tw,tkH,darken(T2.Button,.3),2,51,show), tkX,tkY)
						local pct =(el.Value-el.Min)/math.max(1,el.Max-el.Min)
						local fw  = math.max(4,flr(pct*tw+.5))
						local fill= rcd(sq(0,0,fw,tkH,T2.Slider,2,53,show), tkX,tkY)
						local tmb = rcd(ci(0,0,7,lighten(T2.Slider,.2),55,show), tkX+fw,tkY+tkH//2)
						local isF = el.Step~=math.floor(el.Step)
						local vts = isF and string.format("%.1f",el.Value) or tostring(flr(el.Value))
						local vtx = rcd(tx(vts,0,0,T2.Placeholder,C.FSM,FNT,54,show), tkX-44,ecy+7)
						setOwn({bg,lbl,tkBg,fill,tmb,vtx}, show)
						el._drawings={bg,lbl,tkBg,fill,tmb,vtx}
						el._fill=fill; el._thumb2=tmb; el._trackW=tw; el._vtx=vtx
						-- drag hitbox
						local dh=chb(tkX-8,ecy,tkX+tw+8,ecy+C.EH, function()end, {isDrag=true,_elem=el})
						dh._tkX=tkX; dh._tw=tw
						dh.drag=function(mx)
							local pct2=clamp((mx-(CX()+C.P+tkX))/tw,0,1)
							el:Set(el.Min+pct2*(el.Max-el.Min))
						end

					elseif el.__type=="Button" then
						local bh=C.EH-6
						local bg = rcd(sq(0,0,ew,bh,T2.Button,4,51,show), 0,ecy+3)
						local cw = math.min(#el.Title*7,ew-16)
						local lbl= rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,55,show), flr((ew-cw)/2),ecy+3+flr((bh-C.FMD)/2))
						setOwn({bg,lbl}, show)
						el._drawings={bg,lbl}; el._bg=bg
						chb(0,ecy+3,ew,ecy+3+bh, function()
							local oc=bg.Color; pcall(function() bg.Color=lighten(T2.Button,.35) end)
							task.spawn(function() task.wait(.12); pcall(function() bg.Color=oc end) end)
							pcall(el.Callback)
						end)

					elseif el.__type=="Dropdown" then
						local bg  = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local stx = rcd(tx(tostring(el.Value or ""),0,0,T2.Placeholder,C.FSM,FNT,54,show), ew-92,ecy+9)
						local arr = rcd(tx("v",0,0,T2.Placeholder,C.FSM,FNT,54,show), ew-18,ecy+10)
						setOwn({bg,lbl,stx,arr}, show)
						el._drawings={bg,lbl,stx,arr}; el._stx=stx

						local function closePopup()
							if el._popupDs then
								for _,d in ipairs(el._popupDs) do pcall(function()d:Remove()end) end
								el._popupDs=nil
							end
							for i=#tab._thbs,1,-1 do if tab._thbs[i]._pop then table.remove(tab._thbs,i) end end
						end

						local ddHb
						ddHb=chb(0,ecy,ew,ecy+C.EH, function()
							if el._popupDs then closePopup(); return end
							el._popupDs={}
							local maxS=math.min(#el.Items,7)
							local pH=maxS*22+4
							local pY2=ddHb.y+C.EH
							if pY2+pH>win.wy+WH-8 then pY2=ddHb.y-pH end
							local pBg=Drawing.new("Square")
							pBg.Filled=true; pBg.Color=T2.Dialog; pBg.Corner=4; pBg.ZIndex=80
							pBg.Position=Vector2.new(ddHb.x,pY2); pBg.Size=Vector2.new(ew,pH); pBg.Visible=true
							el._popupDs[#el._popupDs+1]=pBg
							for i,item in ipairs(el.Items) do
								if i>maxS then break end
								local iy=pY2+(i-1)*22+2
								local iBg=Drawing.new("Square"); iBg.Filled=true
								iBg.Color=(tostring(el.Value)==item) and lighten(T2.Accent,.1) or T2.Dialog
								iBg.Corner=3; iBg.ZIndex=81
								iBg.Position=Vector2.new(ddHb.x+2,iy); iBg.Size=Vector2.new(ew-4,20); iBg.Visible=true
								local iTx=Drawing.new("Text"); iTx.Text=item; iTx.Color=T2.Text
								iTx.Size=C.FSM; iTx.Font=FNT; iTx.Outline=false; iTx.ZIndex=82
								iTx.Position=Vector2.new(ddHb.x+10,iy+4); iTx.Visible=true
								el._popupDs[#el._popupDs+1]=iBg; el._popupDs[#el._popupDs+1]=iTx
								local itemH={x=ddHb.x+2,y=iy,x2=ddHb.x+ew-2,y2=iy+20,_pop=true,fn=function()
									el:Set(item); closePopup()
								end}
								tab._thbs[#tab._thbs+1]=itemH
							end
						end)

					elseif el.__type=="Keybind" then
						local bg  = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local kbg = rcd(sq(0,0,62,18,T2.Button,3,52,show), ew-70,ecy+7)
						local ktx = rcd(tx("["..el.Value.."]",0,0,T2.Text,C.FSM,FNT,55,show), ew-66,ecy+9)
						setOwn({bg,lbl,kbg,ktx}, show)
						el._drawings={bg,lbl,kbg,ktx}; el._ktx=ktx; el._kbg=kbg
						win._keybinds[el]=true
						chb(ew-70,ecy+7,ew-8,ecy+25, function()
							kbg.Color=lighten(T2.Accent,.2); ktx.Text="[...]"
							win._kCapture=function(vk)
								pcall(function() kbg.Color=T2.Button end); el:Set(vk)
								win._kCapture=nil
							end
						end)

					elseif el.__type=="Input" then
						local bg  = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local ibg = rcd(sq(0,0,126,20,T2.Button,3,52,show), ew-134,ecy+6)
						local dt  = #el.Value>0 and el.Value or el.Placeholder
						local itx = rcd(tx(dt,0,0, #el.Value>0 and T2.Text or T2.Placeholder,C.FSM,FNT,55,show), ew-130,ecy+9)
						setOwn({bg,lbl,ibg,itx}, show)
						el._drawings={bg,lbl,ibg,itx}; el._itx=itx; el._ibg=ibg
						chb(ew-134,ecy+6,ew-8,ecy+26, function()
							-- typing handled by the key-polling loop (UIS keyboard is unreliable in Matcha)
							if win._iCapture and win._iCapture~=el and win._iCapture._ibg then
								pcall(function() win._iCapture._ibg.Color=T2.Button end)
							end
							win._iCapture=el; el._ibg=ibg; el._itx=itx
							pcall(function() ibg.Color=lighten(T2.Accent,.1) end)
						end)

					elseif el.__type=="Colorpicker" then
						local bg   = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl  = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local pbrd = rcd(sq(0,0,32,20,T2.Placeholder,3,52,show), ew-39,ecy+6)
						local prev = rcd(sq(0,0,28,16,el.Value,3,53,show), ew-37,ecy+8)
						setOwn({bg,lbl,pbrd,prev}, show)
						el._drawings={bg,lbl,pbrd,prev}; el._prev=prev
						local function closeCP()
							if el._popupDs then for _,d in ipairs(el._popupDs) do pcall(function()d:Remove()end) end; el._popupDs=nil end
							for i=#tab._thbs,1,-1 do if tab._thbs[i]._pop then table.remove(tab._thbs,i) end end
						end
						local cpHb
						cpHb=chb(0,ecy,ew,ecy+C.EH, function()
							if el._popupDs then closeCP(); return end
							el._popupDs={}
							local ds=el._popupDs
							local function addD(d) ds[#ds+1]=d; return d end
							local pw=206; local cols=10; local rows=8; local sw=19
							local R=flr(el.Value.R*255); local G=flr(el.Value.G*255); local B=flr(el.Value.B*255)
							local sliders={}; local hexTx
							local function refresh()
								local c=Color3.fromRGB(R,G,B); el:Set(c)
								if hexTx then hexTx.Text=string.format("#%02X%02X%02X",R,G,B) end
								local chv={R,G,B}
								for i,sl in ipairs(sliders) do
									local pp=chv[i]/255
									sl.fill.Size=Vector2.new(math.max(1,flr(pp*sl.w)),6)
									sl.thumb.Position=Vector2.new(sl.x+flr(pp*sl.w),sl.y+3)
								end
							end
							local palH=rows*sw; local slArea=3*20+6; local ph=8+palH+10+slArea+8+16+4
							local px=cpHb.x; local py=cpHb.y+C.EH
							if py+ph>win.wy+WH-6 then py=cpHb.y-ph end
							if px+pw>win.wx+WW then px=win.wx+WW-pw-4 end
							local panel=addD(Drawing.new("Square")); panel.Filled=true; panel.Color=T2.Dialog; panel.Corner=5; panel.ZIndex=80
							pcall(function() panel.Position=Vector2.new(px,py); panel.Size=Vector2.new(pw,ph); panel.Visible=true end)
							local palX=px+8; local palY=py+8
							for r=0,rows-1 do for cI=0,cols-1 do
								local col
								if cI==cols-1 then col=hsv(0,0,1-(r/(rows-1))) else col=hsv(cI/(cols-1),1,1-(r/rows)*0.92) end
								local swx=palX+cI*sw; local swy=palY+r*sw
								local sd=addD(Drawing.new("Square")); sd.Filled=true; sd.Color=col; sd.ZIndex=81
								pcall(function() sd.Position=Vector2.new(swx,swy); sd.Size=Vector2.new(sw-2,sw-2); sd.Visible=true end)
								local cc=col
								tab._thbs[#tab._thbs+1]={x=swx,y=swy,x2=swx+sw-2,y2=swy+sw-2,_pop=true,fn=function() R=flr(cc.R*255); G=flr(cc.G*255); B=flr(cc.B*255); refresh() end}
							end end
							local sY=palY+palH+10; local labels={"R","G","B"}; local cols3={Color3.fromRGB(225,70,70),Color3.fromRGB(70,200,90),Color3.fromRGB(80,140,235)}; local chans={R,G,B}
							for i=1,3 do
								local ly=sY+(i-1)*20
								local lt=addD(Drawing.new("Text")); lt.Text=labels[i]; lt.Color=T2.Text; lt.Size=C.FSM; lt.ZIndex=82; pcall(function() lt.Font=FNT end)
								pcall(function() lt.Position=Vector2.new(px+8,ly-1); lt.Visible=true end)
								local tkx=px+24; local tkw=pw-24-12
								local tbg=addD(Drawing.new("Square")); tbg.Filled=true; tbg.Color=darken(T2.Button,.3); tbg.Corner=2; tbg.ZIndex=82
								pcall(function() tbg.Position=Vector2.new(tkx,ly+2); tbg.Size=Vector2.new(tkw,6); tbg.Visible=true end)
								local fl=addD(Drawing.new("Square")); fl.Filled=true; fl.Color=cols3[i]; fl.Corner=2; fl.ZIndex=83
								pcall(function() fl.Position=Vector2.new(tkx,ly+2); fl.Size=Vector2.new(math.max(1,flr(chans[i]/255*tkw)),6); fl.Visible=true end)
								local th=addD(Drawing.new("Circle")); th.Filled=true; th.Color=Color3.fromRGB(255,255,255); th.Radius=5; th.ZIndex=84; pcall(function() th.NumSides=16 end)
								pcall(function() th.Position=Vector2.new(tkx+flr(chans[i]/255*tkw),ly+5); th.Visible=true end)
								sliders[i]={fill=fl,thumb=th,x=tkx,y=ly+2,w=tkw}
								local idx=i
								tab._thbs[#tab._thbs+1]={x=tkx-6,y=ly-2,x2=tkx+tkw+6,y2=ly+14,_pop=true,isDrag=true,fn=function() end,drag=function(mx)
									local pp=clamp((mx-tkx)/tkw,0,1); local v=flr(pp*255)
									if idx==1 then R=v elseif idx==2 then G=v else B=v end
									refresh()
								end}
							end
							hexTx=addD(Drawing.new("Text")); hexTx.Text=string.format("#%02X%02X%02X",R,G,B); hexTx.Color=T2.Placeholder; hexTx.Size=C.FSM; hexTx.ZIndex=82; pcall(function() hexTx.Font=FNT end)
							pcall(function() hexTx.Position=Vector2.new(px+8,py+ph-18); hexTx.Visible=true end)
						end)

					elseif el.__type=="Label" then
						local bg  = rcd(sq(0,0,ew,C.EH,T2.Element,3,50,show), 0,ecy)
						local lbl = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNT,54,show), lblx,ecy+9)
						local vtx = rcd(tx(tostring(el.Value or ""),0,0,T2.Placeholder,C.FSM,FNT,54,show), ew-150,ecy+9)
						setOwn({bg,lbl,vtx}, show)
						el._drawings={bg,lbl,vtx}; el._vtx=vtx

					elseif el.__type=="Paragraph" then
						elH=44
						local bg  = rcd(sq(0,0,ew,elH,T2.Element,3,50,show), 0,ecy)
						local ttx = rcd(tx(el.Title,0,0,T2.Text,C.FMD,FNTB,54,show), lblx,ecy+6)
						local dtx = rcd(tx(el.Desc,0,0,T2.Placeholder,C.FSM,FNT,54,show), C.P,ecy+24)
						setOwn({bg,ttx,dtx}, show)
						el._drawings={bg,ttx,dtx}; el._ttx=ttx; el._dtx=dtx

					elseif el.__type=="Space" then
						local sln=rcd(ln(0,0,0,0,darken(T2.Button,.3),1,51,show), 4,ecy+5)
						local sm=M(sln); sm.crx2=ew-4; sm.cry2=ecy+5; sm.own=show; sm.elemVis=show
						el._drawings={sln}

					elseif el.__type=="Text" then
						local fc=el.isHdr and T2.Text or T2.Placeholder
						local ff=el.isHdr and FNTB or FNT
						local fs=el.isHdr and C.FMD or C.FSM
						local t=rcd(tx(el.text,0,0,fc,fs,ff,54,show), C.P,ecy+5)
						setOwn({t}, show)
						el._drawings={t}
					end

					if el.Icon and el._drawings then
						local isz=16
						local ic=im(el.Icon,0,0,isz,isz,56,show)
						if ic then rcd(ic, C.P, ecy+(C.EH-isz)//2); local imm=M(ic); imm.own=show; imm.elemVis=show; table.insert(el._drawings, ic) end
					end
					if el.Tooltip then for hi=_thb0+1,#tab._thbs do if not tab._thbs[hi]._tip then tab._thbs[hi]._tip=el.Tooltip end end end
					cy=cy+elH+2
				end  -- elements
				cy=cy+4
			end  -- sections

			tab._scrollMax=math.max(0,cy-(WH-C.TH)+C.P)
			if tab._active then win._scrollMax=tab._scrollMax end
			tab:_refreshContentPos()
			tab:_refreshContentHbs()
			win:_updateScrollbar()
		end  -- tab:_build

		-- First tab auto-activates and builds
		if idx==1 then
			win._active=tab; tab._active=true
			tab._btn.Color=lighten(T.Accent,.2); tab._btx.Color=T.Text
			task.spawn(function() task.wait(); tab:_build() end)
		end

		return tab
	end  -- win:Tab

	-- Section shorthand on window (returns group proxy with :Tab)
	function win:Section(cfg2)
		local lbl=type(cfg2)=="string" and cfg2 or (cfg2 and cfg2.Title or "")
		local g={_tabs={}}
		function g:Tab(c) local t=win:Tab(c); g._tabs[#g._tabs+1]=t; return t end
		for _,m in ipairs({"Toggle","Slider","Dropdown","Button","Keybind","Input","Colorpicker","Space","Text"}) do
			local mm=m
			g[mm]=function(self,c)
				if #g._tabs==0 then g:Tab({Title=lbl}) end
				return g._tabs[#g._tabs][mm](g._tabs[#g._tabs],c)
			end
		end
		return g
	end

	-- Live theme: recolor chrome, rebuild content drawings with current theme
	function win:_applyTheme()
		local T2=MatchaUI.Theme
		pcall(function()
			wBrd.Color=darken(T2.Background,.5); wBg.Color=T2.Background
			wBar.Color=T2.Accent; wBarB.Color=T2.Accent; wTtx.Color=T2.Text
			wSide.Color=T2.Dialog; wSLn.Color=darken(T2.Dialog,.35); wCont.Color=T2.Background
			wMnBg.Color=darken(T2.Accent,.4); wMnTx.Color=T2.Text
			wSbThumb.Color=lighten(T2.Dialog,.25); wTipBg.Color=darken(T2.Dialog,.25); wTipTx.Color=T2.Text
		end)
		for _,t in ipairs(win._tabs) do
			if t._active then pcall(function() t._btn.Color=lighten(T2.Accent,.2); t._btx.Color=T2.Text end)
			else pcall(function() t._btn.Color=T2.Dialog; t._btx.Color=T2.Placeholder end) end
		end
		-- rebuild content drawings (they carry baked-in colors)
		local contentSet={}
		for _,t in ipairs(win._tabs) do
			pcall(function() t:_closePopups() end)
			for _,d in ipairs(t._tdraws) do contentSet[d]=true end
		end
		for d in pairs(contentSet) do pcall(function()d:Remove()end) end
		local na={}
		for _,d in ipairs(win._all) do if not contentSet[d] then na[#na+1]=d end end
		win._all=na
		for _,t in ipairs(win._tabs) do t._tdraws={}; t._thbs={}; t._built=false end
		win._scrollY=0
		if win._active then pcall(function() win._active:_build() end) end
		win:_updateScrollbar()
	end
	function win:SetTheme(name) MatchaUI.Theme=MatchaUI.Themes[name] or MatchaUI.Theme; win:_applyTheme() end
	function win:SetAccent(color) if MatchaUI.Theme then MatchaUI.Theme.Accent=color end; win:_applyTheme() end

	-- Destroy
	function win:Destroy()
		win._alive=false
		if win._iConn then pcall(function()win._iConn:Disconnect()end) end
		if win._uisConn then pcall(function()win._uisConn:Disconnect()end) end
		if win._scrollConn then pcall(function()win._scrollConn:Disconnect()end) end
		-- close dropdown popups
		for _,tab2 in ipairs(win._tabs) do
			for _,sec in ipairs(tab2._sections) do
				for _,el in ipairs(sec._elements) do
					if el._popupDs then for _,d in ipairs(el._popupDs) do pcall(function()d:Remove()end) end end
				end
			end
		end
		for _,d in ipairs(win._all) do pcall(function()d:Remove()end) end
		for i=#MatchaUI._windows,1,-1 do if MatchaUI._windows[i]==win then table.remove(MatchaUI._windows,i) end end
	end

	win.ConfigManager = buildCfgMgr(win)
	MatchaUI._windows[#MatchaUI._windows+1] = win

	-- ============================================================
	-- Render / input loop
	-- ============================================================
	task.spawn(function()
		local lmb=false; local drag=false; local dox,doy=0,0; local sldHb=nil
		local sbDrag=false; local sbOff=0
		local keyDown={}; local frameN=0

		while win._alive do
			task.wait(0.033)
			frameN=frameN+1
			local m=getMouse(); if not m then continue end
			local mx,my=m.X,m.Y
			local lnow=ismouse1pressed()
			local rise=lnow and not lmb
			local fall=not lnow and lmb

			if rise then
				local inW = mx>=win.wx and mx<=win.wx+WW and my>=win.wy and my<=win.wy+WH
				-- scrollbar thumb grab (highest priority)
				local r=win._sbRect
				if r and mx>=r.x and mx<=r.x2 and my>=r.y and my<=r.y2 then
					sbDrag=true; sbOff=my-r.y
				elseif inW then
					-- title bar drag (not on buttons)
					if my>=win.wy and my<=win.wy+C.TH and mx<win.wx+WW-56 then
						drag=true; dox=mx-win.wx; doy=my-win.wy
					end
					-- check window-level hitboxes first (close, min, tab buttons)
					local handled=false
					for i=#win._hbs,1,-1 do
						local h=win._hbs[i]
						if mx>=h.x and mx<=h.x2 and my>=h.y and my<=h.y2 then
							pcall(h.fn); handled=true; break
						end
					end
					-- then active tab hitboxes
					if not handled and win._active then
						for i=#win._active._thbs,1,-1 do
							local h=win._active._thbs[i]
							if mx>=h.x and mx<=h.x2 and my>=h.y and my<=h.y2 then
								if h.isDrag then sldHb=h; h.drag(mx)
								else pcall(h.fn) end
								break
							end
						end
					end
				end
			end

			if lnow then
				if drag then
					local vp2=workspace.CurrentCamera.ViewportSize
					local nx=clamp(mx-dox,0,vp2.X-WW); local ny=clamp(my-doy,0,vp2.Y-WH)
					if nx~=win.wx or ny~=win.wy then
						win.wx=nx; win.wy=ny
						refreshChrome(); refreshChromeHbs()
						for _,t in ipairs(win._tabs) do t:_refreshTabHb() end
						if win._active then win._active:_refreshContentPos(); win._active:_refreshContentHbs() end
						win:_updateScrollbar()
					end
				end
				if sbDrag then pcall(function() win:_scrollTo(my, sbOff) end) end
				if sldHb then pcall(sldHb.drag,mx) end
			end

			-- keyboard polling (input typing + keybind capture) — iskeypressed is reliable
			if (win._iCapture or win._kCapture) and iskeypressed then
				local shiftDn = iskeypressed(0x10) or iskeypressed(0xA0) or iskeypressed(0xA1)
				for _,vk in pairs(KV) do
					if vk~=0x01 and vk~=0x02 and vk~=0x04 then
						local down = iskeypressed(vk)
						if down then
							local held = keyDown[vk] or 0
							local fire = (held==0) or (held>=9 and (held-9)%2==0)
							keyDown[vk]=held+1
							if fire then
								if win._kCapture then
									local fn=win._kCapture; win._kCapture=nil; pcall(fn,vk)
								elseif win._iCapture then
									local el=win._iCapture
									if vk==0x0D or vk==0x1B then
										if el._ibg then pcall(function() el._ibg.Color=MatchaUI.Theme.Button end) end
										win._iCapture=nil
										if el._itx then el._itx.Text=#el.Value>0 and el.Value or el.Placeholder; el._itx.Color=#el.Value>0 and MatchaUI.Theme.Text or MatchaUI.Theme.Placeholder end
										if vk==0x0D then pcall(el.Callback, el.Value) end
									elseif vk==0x08 then
										el.Value=el.Value:sub(1,-2)
										if el._id then MatchaUI.Values[el._id]=el.Value end
									else
										local ch=VC[vk]
										if ch then
											if shiftDn then ch=ch:upper() end
											el.Value=el.Value..ch
											if el._id then MatchaUI.Values[el._id]=el.Value end
										end
									end
								end
							end
						else
							keyDown[vk]=nil
						end
					end
				end
			elseif next(keyDown) then keyDown={} end

			-- keybind activation: fire callback when a bound key is pressed (edge)
			if iskeypressed and not win._kCapture then
				for el in pairs(win._keybinds) do
					local vk=el._vk
					if vk and vk~=0 then
						local down=iskeypressed(vk)
						if down and not el._kdown then pcall(el.Callback, el.Value) end
						el._kdown=down
					end
				end
			end

			-- input cursor blink + live text
			if win._iCapture and win._iCapture._itx then
				local el=win._iCapture
				local cur = ((frameN//15)%2==0) and "|" or ""
				if #el.Value>0 then el._itx.Text=el.Value..cur; el._itx.Color=MatchaUI.Theme.Text
				else el._itx.Text=(cur~="" and cur) or el.Placeholder; el._itx.Color=(cur~="") and MatchaUI.Theme.Text or MatchaUI.Theme.Placeholder end
			end

			-- tooltip on hover (only when idle, not dragging/clicking)
			local tip=nil
			if not lnow and not drag and not sbDrag and not sldHb and not win._minimized and win._active then
				for i=#win._active._thbs,1,-1 do
					local h=win._active._thbs[i]
					if h._tip and mx>=h.x and mx<=h.x2 and my>=h.y and my<=h.y2 then tip=h._tip; break end
				end
			end
			if tip then
				local w=#tip*7+12
				wTipTx.Text=tip
				wTipBg.Size=Vector2.new(w,18)
				local tx0=clamp(mx+14,0,(workspace.CurrentCamera.ViewportSize.X)-w)
				local ty0=my+18
				wTipBg.Position=Vector2.new(flr(tx0),flr(ty0))
				wTipTx.Position=Vector2.new(flr(tx0)+6,flr(ty0)+3)
				wTipBg.Visible=true; wTipTx.Visible=true
			else
				wTipBg.Visible=false; wTipTx.Visible=false
			end

			if fall then drag=false; sldHb=nil; sbDrag=false end
			lmb=lnow
		end
	end)

	-- UIS connection for keybind capture
	win._uisConn = UIS.InputBegan:Connect(function(inp)
		if not win._alive then return end
		local vk = inpVK(inp)
		if win._kCapture and vk and vk~=0 then
			local fn=win._kCapture; win._kCapture=nil; pcall(fn,vk)
		end
	end)

	-- Scroll wheel (UIS.InputChanged is not guaranteed to exist in Matcha)
	pcall(function()
		if not UIS.InputChanged then return end
		win._scrollConn = UIS.InputChanged:Connect(function(inp)
			if not win._alive then return end
			local ok,isWheel=pcall(function()
				local t=inp.UserInputType
				return (type(t)=="number" and t==3) or (t and t.Name=="MouseWheel")
			end)
			if ok and isWheel then
				local m=getMouse()
				if m and m.X>=win.wx+C.SW and m.X<=win.wx+WW and m.Y>=win.wy+C.TH and m.Y<=win.wy+WH then
					local dz=0; pcall(function() dz=inp.Position.Z end)
					win._scrollY=clamp(win._scrollY-dz*25, 0, win._scrollMax)
					if win._active then win._active:_refreshContentPos(); win._active:_refreshContentHbs() end
				end
			end
		end)
	end)

	return win
end  -- CreateWindow

-- ============================================================
-- Notify / Popup stubs
-- ============================================================
function MatchaUI:Notify(cfg)
	cfg=cfg or {}
	pcall(notify, cfg.Content or cfg.Desc or "", cfg.Title or "", cfg.Duration or 5)
end

function MatchaUI:Popup(cfg)
	cfg=cfg or {}
	self:Notify({Title=cfg.Title or "Popup", Content=cfg.Content or "", Duration=4})
end

-- Gradient stub (WindUI compatibility — returns nil gracefully)
function MatchaUI:Gradient() return nil end

function MatchaUI:DestroyAll()
	for _,w in ipairs(self._windows or {}) do pcall(function() w:Destroy() end) end
	self._windows = {}
end

-- Matcha's loadstring return value is non-standard, so also expose the
-- library as a global. Loaders can grab it via getgenv().MatchaUI / _G.MatchaUI
-- if `loadstring(game:HttpGet(...))()` does not propagate the return value.
-- On reload, tear down the previous instance's windows so they don't stack.
pcall(function()
	local g = (getgenv and getgenv()) or _G
	if g then
		if g.MatchaUI and g.MatchaUI ~= MatchaUI and g.MatchaUI.DestroyAll then
			pcall(function() g.MatchaUI:DestroyAll() end)
		end
		g.MatchaUI = MatchaUI
	end
end)

return MatchaUI
