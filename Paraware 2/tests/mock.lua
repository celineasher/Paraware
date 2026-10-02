math.clamp = function(n,lo,hi) return math.max(lo,math.min(n,hi)) end
function signal()
 local s={connections={}}
 function s:Connect(fn)
  local c={fn=fn,Connected=true}; function c:Disconnect() self.Connected=false end
  table.insert(self.connections,c); return c
 end
 function s:Fire(...) for _,c in ipairs(self.connections) do if c.Connected then c.fn(...) end end end
 return s
end
local vmt={}
Vector3={}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmt) end
vmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vmt.__index=function(v,k)
 if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=='Unit' then local n=v.Magnitude; return Vector3.new(v.X/n,v.Y/n,v.Z/n) end
end
Vector3.zero=Vector3.new(0,0,0)
Vector2={new=function(x,y) return {X=x,Y=y} end}
UDim2={fromOffset=function(x,y) return {x,y} end,new=function(...) return {...} end}
UDim={new=function(...) return {...} end}
Color3={fromHex=function(s) return s end,fromRGB=function(...) return {...} end}
ColorSequence={new=function(...) return {...} end}
Enum=setmetatable({}, {__index=function(t,k) local v=setmetatable({}, {__index=function(_,x) return k..'.'..x end});rawset(t,k,v);return v end})
created={}
Instance={new=function(class)
 local x={ClassName=class}; function x:Destroy() self.Parent=nil;self.Destroyed=true end
 table.insert(created,x);return x
end}
function makeCharacter(speed,jump,usePower)
 local h={WalkSpeed=speed,JumpPower=jump,JumpHeight=7,UseJumpPower=usePower,Health=100,PlatformStand=false,AutoRotate=true,MoveDirection=Vector3.zero,Parent=true}
 function h:ChangeState(s) self.LastState=s end
 local r={CanCollide=true,Parent=true,CFrame={Rotation='rootRotation'},AssemblyLinearVelocity=Vector3.zero,AssemblyAngularVelocity=Vector3.zero}
 function r:IsA(c) return c=='BasePart' end
 local limb={CanCollide=false,Parent=true};function limb:IsA(c) return c=='BasePart' end
 local c={Parent=true,H=h,R=r,Limb=limb}
 function c:WaitForChild(name) if name=='Humanoid' then return h else return r end end
 function c:GetDescendants() return {r,limb} end
 return c
end
player={Character=makeCharacter(16,50,true),CharacterAdded=signal(),CharacterRemoving=signal()}
input={TouchEnabled=false,MouseEnabled=true,KeyboardEnabled=true,InputBegan=signal(),TouchTapInWorld=signal(),JumpRequest=signal(),WindowFocusReleased=signal(),WindowFocused=signal(),keys={}}
function input:GetFocusedTextBox() return self.textbox end
function input:IsKeyDown(key) return self.keys[key] or false end
function input:GetMouseLocation() return Vector2.new(900,300) end
runservice={PreSimulation=signal(),RenderStepped=signal()}
lighting={Brightness=1,ClockTime=6,FogEnd=500,GlobalShadows=true,Ambient='ambient',OutdoorAmbient='outdoor'}
function makeCamera(fov)
 local c={FieldOfView=fov,Parent=true,ViewportSize=Vector2.new(1440,900),CFrame={Rotation='cameraRotation',LookVector=Vector3.new(0,0,-1),RightVector=Vector3.new(1,0,0)}}
 function c:ViewportPointToRay(x,y) return {Origin=Vector3.zero,Direction=Vector3.new(0,0,-1)} end
 return c
end
workspace={CurrentCamera=makeCamera(70),cameraSignal=signal()}
function workspace:GetPropertyChangedSignal() return self.cameraSignal end
function workspace:Raycast(...) return self.rayTarget and {Instance=self.rayTarget} end
RaycastParams={new=function() return {} end}
guiService={GetGuiInset=function() return Vector2.new(0,36) end}
market={GetProductInfo=function() return {Name='Test Place'} end}
game={PlaceId=123,GameId=456}
function game:GetService(name) return ({Players={LocalPlayer=player},UserInputService=input,RunService=runservice,Lighting=lighting,MarketplaceService=market,GuiService=guiService})[name] end
function game:HttpGet(url)
 if url:find('7dd8a34') then return 'mock WindUI' end
 assert(url:find('a6c93592'));return 'mock exporter'
end
task={spawn=function(fn,...) fn(...) end,wait=function() end}
warn=print
clipboard=nil
setclipboard=function(text) clipboard=text end
windows={}
wind={}
function wind:AddTheme(theme) assert(theme.Name=='Paraware') end
function wind:Notify(info) self.LastNotice=info.Content end
function wind:CreateWindow(config)
 local root={FindFirstChild=function() return {} end}
 local w={config=config,controls={},tabs={},sections={},UIElements={Main=root,MainBar={},SideBarContainer={}}}
 function w:OnDestroy(fn) self.cleanup=fn end
 function w:Destroy() self.Destroyed=true;self.cleanup() end
 function w:Tab(config)
  local tab={Title=config.Title}
  function tab:Select() w.selected=self.Title end
  function tab:Section(cfg)
   local section=w:Tab({Title=cfg.Title});w.tabs[cfg.Title]=nil;w.sections[cfg.Title]=section;return section
  end
  for _,kind in ipairs({'Paragraph','Toggle','Slider','Button','Dropdown'}) do
   tab[kind]=function(self,cfg)
    local control={config=cfg,kind=kind,Value=cfg.Value,Desc=cfg.Desc,Title=cfg.Title}
    function control:Set(value,call) self.Value=value;if call then self.config.Callback(value) end end
    function control:SetDesc(desc) self.Desc=desc end
    function control:SetTitle(title) self.Title=title end
    w.controls[self.Title..'/'..cfg.Title]=control
    return control
   end
  end
  w.tabs[config.Title]=tab;return tab
 end
 table.insert(windows,w);return w
end
files={}
writefile=function(path,data) files[path]=data end
readfile=function(path) return assert(files[path]) end
isfile=function(path) return files[path]~=nil end
getcustomasset=function(path) assert(files[path]);return 'rbxasset://'..path end
loadstring=function(text)
 if text=='mock WindUI' then return function() return wind end end
 assert(text=='mock exporter')
 return function() return function(options)
  lastExport=options
  assert(options.Binary and options.IsModel and options.Object and not options.Decompile and not options.SaveBytecode)
  if exportFailure=='empty' then return end
  if exportFailure=='invalid' then options.Callback('invalid');return end
  options.Callback('<roblox!\137\255\r\n\26\nmock model payload')
 end end
end
function control(name)
 local prefix,tail=name:match('^([^/]+)/(.+)$')
 local aliases={Overview='Controls',Player='Movement',World='Camera & world',Console='Session',Settings='Session',Game='Place module'}
 name=(aliases[prefix] or prefix)..'/'..tail
 return assert(windows[#windows].controls[name],name)
end
function click(name,...) return control(name).config.Callback(...) end
function expect(n,a,b) assert(a==b,n..': '..tostring(a)..' ~= '..tostring(b)) end
