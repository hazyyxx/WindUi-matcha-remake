-- MatchaUI demo / icon test.
-- Run this whole thing in Matcha. It loads the lib, then builds a window so
-- there is actually something on screen (loadstring alone only DEFINES the lib).
loadstring(game:HttpGet("https://raw.githubusercontent.com/hazyyxx/WindUi-matcha-remake/main/MatchaUI.lua?v="..tick()))()
local UI = (getgenv and getgenv().MatchaUI) or _G.MatchaUI
if not UI then notify("MatchaUI failed to load","demo",5); return end

-- If icons look too thin/thick at small sizes, set this BEFORE CreateWindow:
-- UI.IconStroke = 2

local Window = UI:CreateWindow({
	Title    = "MatchaUI",
	SubTitle = "vector icons",
	Icon     = "rocket",          -- title-bar icon
	Theme    = "Dark",
	Size     = Vector2.new(560, 420),
})

-- Tab icons (sidebar)
local Main = Window:Tab({ Title = "Main",     Icon = "house"    })
local Combat = Window:Tab({ Title = "Combat",   Icon = "swords"   })
local Visual = Window:Tab({ Title = "Visuals",  Icon = "eye"      })

-- Elements with icons (icon shows left of the label)
local s1 = Main:Section("Elements")
s1:Toggle({ Title = "Auto farm",  Icon = "bot",      Value = false, Tooltip = "Automatically gather resources while you play", Callback = function(v) notify("toggle "..tostring(v),"demo",2) end })
s1:Toggle({ Title = "God mode",   Icon = "shield",   Value = true,  Tooltip = "Take no damage from any source" })
s1:Slider({ Title = "Walk speed", Icon = "gauge",    Value = { Default = 16, Min = 16, Max = 200 }, Step = 1, Tooltip = "Move faster than the default of 16 studs/sec" })
s1:Button({ Title = "Teleport",   Icon = "navigation", Tooltip = "Teleport to a saved location", Callback = function() notify("clicked","demo",2) end })
s1:Keybind({ Title = "Panic key", Icon = "keyboard", Value = "RShift", Tooltip = "Press to disable all features instantly" })

local s2 = Main:Section("More")
s2:Dropdown({ Title = "Target",  Icon = "target", Values = { "Closest", "Mouse", "Random" }, Value = "Closest" })
s2:Dropdown({ Title = "Modules", Icon = "boxes",  Multi = true, Values = { "ESP","Aimbot","Speed","Fly","Noclip","Reach","Killaura","Tracers","Hitbox","Wallhack","Triggerbot","Sprint" }, Value = { "ESP","Speed" }, Callback = function(list) notify(table.concat(list,", "),"Modules",2) end })
s2:Input({ Title = "Webhook",     Icon = "link",   Placeholder = "https://..." })
s2:Colorpicker({ Title = "ESP color", Icon = "palette", Default = Color3.fromRGB(0,170,255) })
s2:Paragraph({ Title = "Note", Desc = "Icons are now drawn with native lines + circles — no PNGs, themeable, crisp." })

-- A grid of icons so you can eyeball the whole set rendering
local g = Combat:Section("Icon gallery")
for _,name in ipairs({"sword","swords","crosshair","skull","flame","bomb","zap","crown","gem","heart","star","flag"}) do
	g:Label({ Title = name, Icon = name })
end

local v = Visual:Section("Icon gallery 2")
for _,name in ipairs({"eye","eye-off","monitor","camera","image","sun","moon","droplet","sparkles","wifi","map-pin","compass"}) do
	v:Label({ Title = name, Icon = name })
end

notify("MatchaUI demo loaded","demo",3)
