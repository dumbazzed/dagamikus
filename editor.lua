require("rocx")

local PANEL = {}
PANEL.URL = "http://metastruct.github.io/lua_editor/"
PANEL.COMPILE = "C"
local js_esc_replacements = {
	["\\"] = "\\\\",
	["\0"] = "\\0",
	["\b"] = "\\b",
	["\t"] = "\\t",
	["\n"] = "\\n",
	["\v"] = "\\v",
	["\f"] = "\\f",
	["\r"] = "\\r",
	["\""] = "\\\"",
	["\'"] = "\\'",
}
function PANEL:Init()
	self.Code = ""

	self.ErrorPanel = self:Add("DButton")
	self.ErrorPanel:SetFont('BudgetLabel')
	self.ErrorPanel:SetTextColor(Color(255,255,255))
	self.ErrorPanel:SetText("")
	self.ErrorPanel:SetTall(0)
	self.ErrorPanel.DoClick = function()
		self:GotoErrorLine()
	end
	self.ErrorPanel.DoRightClick = function(self)
		SetClipboardText(self:GetText())
	end
	self.ErrorPanel.Paint = function(self,w,h)
		surface.SetDrawColor(255,50,50)
		surface.DrawRect(0,0,w,h)
	end

	self:StartHTML()
end

function PANEL:Think()
	if self.NextValidate&&self.NextValidate<CurTime() then
		self:ValidateCode()
	end
end

function PANEL:StartHTML()
	self.HTML = self:Add("DHTML")

	self:AddJavascriptCallback("OnCode")
	self:AddJavascriptCallback("OnLog")

	self.HTML:OpenURL(self.URL)
	self.HTML:RequestFocus()
end

function PANEL:ReloadHTML()
	self.HTML:OpenURL(self.URL)
end

function PANEL:JSSafe(str)
	str = str:gsub(".",js_esc_replacements)
	str = str:gsub("\226\128\168","\\\226\128\168")
	str = str:gsub("\226\128\169","\\\226\128\169")
	return str
end

function PANEL:CallJS(JS)
	self.HTML:Call(JS)
end

function PANEL:AddJavascriptCallback(name)
	local func = self[name]
	self.HTML:AddFunction("gmodinterface",name,function(...)
		func(self,HTML,...)
	end)
end

function PANEL:OnCode(_,code)
	self.NextValidate = CurTime()+0.2
	self.Code = code
end

function PANEL:OnLog(_,...)
	Msg("Editor: ")
	print(...)
end

function PANEL:SetCode(code)
	self.Code = code
	self:CallJS('SetContent("'..self:JSSafe(code)..'");')
end

function PANEL:GetCode()
	return self.Code
end

function PANEL:SetGutterError(errline,errstr)
	self:CallJS("SetErr('"..errline.."','"..self:JSSafe(errstr).."')")
end

function PANEL:GotoLine(num)
	self:CallJS("GotoLine('"..num.."')")
end

function PANEL:ClearGutter()
	self:CallJS("ClearErr()")
end

function PANEL:GotoErrorLine()
	self:GotoLine(self.ErrorLine||1)
end

function PANEL:SetError(err)
	if!IsValid(self.HTML) then
		self.ErrorPanel:SetText("")
		self:ClearGutter()
		return
	end

	local tall = 0

	if err then
		local line,err = string.match(err,self.COMPILE..":(%d*):(.+)")
		if line&&err then
			tall = 20
			self.ErrorPanel:SetText((line&&err)&&("Line "..line..": "..err)||err||"")
			self.ErrorLine = tonumber(string.match(err," at line (%d)%")||line)||1
			self:SetGutterError(self.ErrorLine,err)
		end
	else
		self.ErrorPanel:SetText("")
		self:ClearGutter()
	end

	local wide = self:GetWide()
	local tallm = self:GetTall()

	self.ErrorPanel:SetPos(0,tallm-tall)
	self.ErrorPanel:SetSize(wide,tall)
	self.HTML:SetSize(wide,tallm-tall)
end

function PANEL:ValidateCode()
    local time = SysTime()
    local code = self:GetCode()
    self.NextValidate = nil
    if not code or code == "" then
        self:SetError()
        return
    end
	
    local errormsg = CompileString(code, self.COMPILE, false)
    time = SysTime() - time

    if type(errormsg) == "string" then
        self:SetError(errormsg)
    elseif time > 0.25 then
        self:SetError("Compiling too long (" .. math.Round(time * 1000) .. "ms)")
    else
        self:SetError()
    end
end

function PANEL:PerformLayout(w,h)
	local tall = self.ErrorPanel:GetTall()
	self.ErrorPanel:SetPos(0,h-tall)
	self.ErrorPanel:SetSize(w,tall)
	self.HTML:SetSize(w,h-tall)
end

vgui.Register("CodeEditor",PANEL,"EditablePanel")

local surface = surface 
local surface_SetDrawColor 		= surface.SetDrawColor
local surface_DrawRect 			= surface.DrawRect
local surface_DrawOutlinedRect  = surface.DrawOutlinedRect
local pal = { { 40, 40, 40 }, { 60, 56, 54 }, { 146, 131, 116 }, { 204, 36, 29 }, { 251, 73, 52 }, { 152, 151, 26 }, { 184, 187, 38 }, { 215, 153, 33 }, { 250, 189, 47 }, { 69, 133, 136 }, { 131, 165, 152 }, { 177, 98, 134 }, { 211, 134, 155 }, { 104, 157, 106 }, { 142, 192, 124 }, { 168, 153, 132 }, { 235, 219, 178 }, { 214, 93, 14 }, { 254, 128, 25 },	 }

function SetPalColor( i ) 
	local use = pal[ i ]
	surface_SetDrawColor( use[1], use[2], use[3] )
end

local filen = "None"
local blockstring = false

file.CreateDir( "zxc" )
file.CreateDir( "zxc/saved" )
file.CreateDir( "zxc/auto" )

if frame then
    frame:Remove()
    frame = false
end

frame = vgui.Create( "DFrame" )
frame:SetTitle("")
frame:SetSize(648, 520)
frame:Center()
frame:MakePopup()
frame:ShowCloseButton(false)
function frame:Paint( w, h )
    SetPalColor(1) 
    surface_DrawRect(0, 0, w, h)
	SetPalColor(1) 
    surface_DrawOutlinedRect( 0, 0, w, h)
	surface_DrawRect( 0, 0, w, 24 )
	surface_DrawRect( 128, 0, 1, h )
end

local ePan = frame:Add( "CodeEditor" )
ePan:SetPos( 129, 24 )
ePan:SetSize( 518, 495 )

local fPan
function UpdateFiles()
	if fPan then
		fPan:Remove()
		fPan = false 
	end
	fPan = frame:Add("DPanel")
	fPan:SetPos(4, 28)
	fPan:SetSize(120, 488)

	local bg = fPan:Add("DHTML")
	bg:Dock(FILL)
	bg:OpenURL("https://cdn.discordapp.com/attachments/1338953075028791339/1339997043812204605/photo_2024-12-13_23-08-51_2.jpg?ex=67b0c0ff&is=67af6f7f&hm=749fdf1b2aab0065d8bb38552c0895a0ee4986d176ff64d717b62811f91ffb76")

	local files, dirs = file.Find("zxc/saved/*", "DATA")
	for key, val in pairs(files) do
		local hButton = fPan:Add("DButton")
		hButton:Dock(TOP)
		hButton:SetText(val)
		hButton:SetFont(string.len(val) > 16 and "HudHintTextSmall" or "Trebuchet18")
		hButton:SetTextColor(Color(255, 255, 255))
		hButton:SizeToContents()
		hButton:SetHeight(20)
		hButton:DockMargin(2, 0, 0, 0)
		hButton.Paint = function(self, w, h)
			SetPalColor(1)
			surface_DrawRect(0, 0, w, h) 
			SetPalColor(3)
			surface_DrawRect(0, h - 1, w, 1)
		end		
		hButton.DoClick = function()
			ePan:SetCode(file.Read("zxc/saved/" .. val, "DATA"))
			filen = val
		end
		hButton.DoRightClick = function()
			if not IsInGame() then return end
			RunOnClient(file.Read("zxc/saved/" .. val, "DATA"))
		end
	end
end

UpdateFiles()

local options = {
	[ "Save" ] = { 
		function( self ) 
			file.Write( "zxc/saved/" .. os.time() .. ".txt", ePan:GetCode() ) 
			filen = os.time()
			UpdateFiles() 
		end, Color( 255, 255, 255 ), 10 
	},
	[ "Safe [OFF]" ] = {
		function( self )
			blockstring = not blockstring
			self:SetText( "Safe " .. ( blockstring and "[ON]" or "[OFF]" ) )
		end, Color( 255, 255, 255 ), 10
	},
	[ "Load" ] = {
		function( self ) 
			if not IsInGame() then
				return
			end 
			
			RunOnClient( ePan:GetCode() )
		end, Color( 255, 255, 255 ), 10
	}
}
local bPan = frame:Add( "DPanel" )
bPan:SetPos( 326, 2 )
bPan:SetSize( 320, 20 )
bPan.Paint = nil
for key, val in pairs( options ) do
	local data = options[ key ] 
	local hButton = bPan:Add( "DButton" )
	hButton:Dock( RIGHT )
	hButton:SetText( key )
	hButton:SetFont( "Trebuchet18" )
	hButton:SetTextColor( data[ 2 ] )
	hButton:SizeToContents()
	hButton:SetHeight( 20 )
	hButton:DockMargin( 2, 0, 0, 0 )
	function hButton:Paint( w, h )
		SetPalColor( data[ 3 ] ) 
		surface_DrawRect( 0, 0, w, h )
	end
	hButton.DoClick = data[ 1 ]
end

local hk = {}

function hk.GameContentChanged()
    frame:MakePopup()
end

local key, keyon = 74, false
function hk.Think()
    if input.IsKeyDown( key ) and not keyon then
        frame:ToggleVisible()
    end
    keyon = input.IsKeyDown( key )
end

function hk.RunOnClient( path, run )
	if path:find( "/dac/" ) then 
		return "" 
	end

    return blockstring and "" or run
end

for key, val in pairs( hk ) do
    hook.Add( key, "H:" .. key, val )
end