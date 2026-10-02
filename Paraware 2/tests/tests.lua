firstWindow=windows[1]
expect('home selection',firstWindow.selected,'Controls')
local count=0;for _ in pairs(firstWindow.tabs) do count=count+1 end;expect('compact sidebar',count,3)
assert(firstWindow.tabs.Controls and firstWindow.tabs['Object export'] and firstWindow.tabs.Session)
expect('desktop width',firstWindow.config.Size[1],920)
expect('desktop height',firstWindow.config.Size[2],600)
expect('sidebar width',firstWindow.config.SideBarWidth,180)
expect('right-side window controls',firstWindow.config.Topbar.ButtonsType,'Default')
expect('game thumbnail',control('Overview/Detecting game...').config.Image,'rbxthumb://type=GameIcon&id=456&w=150&h=150')
assert(firstWindow.UIElements.SideBarContainer.Visible)
expect('detected game name',control('Overview/Detecting game...').Title,'Test Place')
assert(firstWindow.sections.Movement and firstWindow.sections.Flight and firstWindow.sections['Camera & world'])
expect('starts unmodified',player.Character.H.WalkSpeed,16)
click('Player/Walk speed',64);expect('disabled slider',player.Character.H.WalkSpeed,16)
click('Player/Custom speed',true);expect('speed enable',player.Character.H.WalkSpeed,64)
click('Player/Custom speed',false);expect('speed restore',player.Character.H.WalkSpeed,16)
player.Character.H.WalkSpeed=20
click('Player/Custom speed',true);click('Player/Custom speed',false);expect('fresh speed capture',player.Character.H.WalkSpeed,20)
click('Player/Jump power',90);click('Player/Custom jump',true);expect('jump power',player.Character.H.JumpPower,90)
click('Player/Custom jump',false);expect('jump restore',player.Character.H.JumpPower,50)
player.Character.H.UseJumpPower=false
click('Player/Jump height',24);click('Player/Custom jump',true);expect('jump height',player.Character.H.JumpHeight,24)
click('Player/Custom jump',false);expect('height restore',player.Character.H.JumpHeight,7)
click('Player/Infinite jump',true);input.JumpRequest:Fire();expect('air jump',player.Character.H.LastState,Enum.HumanoidStateType.Jumping)
click('Player/Infinite jump',false)
click('Player/Noclip',true);runservice.PreSimulation:Fire();expect('collision off',player.Character.R.CanCollide,false)
click('Player/Noclip',false);expect('collision restored',player.Character.R.CanCollide,true);expect('noncolliding preserved',player.Character.Limb.CanCollide,false)
print('PASS: speed, both jump modes, infinite jump, noclip, captured-value restoration')
click('Flight/Rise');expect('guard while disabled',wind.LastNotice,'Enable Fly first.')
click('Flight/Fly',true);expect('flight state',player.Character.H.PlatformStand,true)
runservice.PreSimulation:Fire();runservice.RenderStepped:Fire()
click('Flight/Fly speed',75);click('Flight/Rise');runservice.RenderStepped:Fire()
local velocity=created[#created-1]
expect('rise speed',velocity.VectorVelocity.Y,75)
click('Flight/Hold altitude');runservice.RenderStepped:Fire();expect('hold altitude',velocity.VectorVelocity.Y,0)
click('Flight/Descend');runservice.RenderStepped:Fire();expect('descend',velocity.VectorVelocity.Y,-75)
input.keys[Enum.KeyCode.W]=true;input.keys[Enum.KeyCode.E]=true
runservice.RenderStepped:Fire();assert(velocity.VectorVelocity.Magnitude<=75.001)
input.keys={};input.textbox=true;runservice.RenderStepped:Fire();expect('typing stops movement',velocity.VectorVelocity.Magnitude,0);input.textbox=nil
input.WindowFocusReleased:Fire();input.keys[Enum.KeyCode.W]=true;runservice.RenderStepped:Fire();expect('unfocused hover',velocity.VectorVelocity.Magnitude,0);input.WindowFocused:Fire();input.keys={}
click('Flight/Stop flight');expect('flight restore',player.Character.H.PlatformStand,false);expect('rotation restore',player.Character.H.AutoRotate,true);expect('flight collision restore',player.Character.R.CanCollide,true)
for _,object in ipairs(created) do if object.ClassName=='Attachment' or object.ClassName=='LinearVelocity' or object.ClassName=='AlignOrientation' then assert(object.Destroyed) end end
input.InputBegan:Fire({KeyCode=Enum.KeyCode.F},false);expect('fly hotkey',player.Character.H.PlatformStand,true)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.F},true);expect('processed hotkey ignored',player.Character.H.PlatformStand,true)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.F},false)
print('PASS: flight constraints, rise/hold/descend, typing guard, normalized speed, hotkey, cleanup')
click('World/Field of view',100);click('World/Custom field of view',true);expect('FOV enabled',workspace.CurrentCamera.FieldOfView,100)
local oldCamera=workspace.CurrentCamera
workspace.CurrentCamera=makeCamera(85);workspace.cameraSignal:Fire();expect('camera replacement',workspace.CurrentCamera.FieldOfView,100)
click('World/Custom field of view',false);expect('new camera restore',workspace.CurrentCamera.FieldOfView,85);expect('old camera restore',oldCamera.FieldOfView,70)
click('World/Reset camera to player');expect('camera subject',workspace.CurrentCamera.CameraSubject,player.Character.H)
click('World/Fullbright',true);expect('lighting changed',lighting.ClockTime,14)
click('World/Fullbright',false);expect('lighting restored',lighting.ClockTime,6);expect('shadows restored',lighting.GlobalShadows,true)
print('PASS: FOV across camera replacements, reset camera, lighting restoration')
click('Settings/Copy game IDs');expect('copy IDs',clipboard,'PlaceId = 123\nGameId = 456')
click('Console/Copy log');assert(clipboard:find('Fullbright'))
click('Console/Clear console');assert(control('Console/Session log').Desc:find('cleared'))
print('PASS: console copy/clear and game IDs')
local model={Name='Test/Model',Parent=workspace}
local part={Name='Clicked Part',Parent=model}
function part:IsA(class) return false end
function part:FindFirstAncestorOfClass(class) return model end
workspace.rayTarget=part
click('Object export/Object picker',true)
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=Vector3.new(900,300,0)},true)
assert(lastExport==nil)
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=Vector3.new(900,300,0)},false)
expect('model selection',lastExport.Object,model)
assert(lastExport.FilePath:match('Test_Model.*%.rbxm$'))
assert(files[lastExport.FilePath]:sub(1,8)=='<roblox!')
expect('saved status',control('Object export/Picker off').Title,'Model saved')
click('Object export/Selection','Clicked part')
input.TouchTapInWorld:Fire(Vector2.new(900,300),false)
expect('touch part selection',lastExport.Object,part)
exportFailure='empty';input.TouchTapInWorld:Fire(Vector2.new(900,300),false)
expect('missing output reports failure',control('Object export/Picker off').Title,'Export failed')
exportFailure='invalid';input.TouchTapInWorld:Fire(Vector2.new(900,300),false)
expect('invalid output reports failure',control('Object export/Picker off').Title,'Export failed')
exportFailure=nil
local originalWrite=writefile;writefile=nil;input.TouchTapInWorld:Fire(Vector2.new(900,300),false)
expect('no writefile message',control('Object export/Picker off').Title,'Export unavailable');writefile=originalWrite
click('Object export/Object picker',false)
print('PASS: mouse/touch object picker, model/part scope, binary file write, missing/invalid output, missing writefile, UI input guard')
click('Player/Custom speed',true);click('Player/Custom jump',true);click('Flight/Fly',true)
local old=player.Character
player.CharacterRemoving:Fire(old);expect('old spawn restored',old.H.WalkSpeed,20);expect('old flight stopped',old.H.PlatformStand,false)
player.Character=makeCharacter(18,60,true);player.CharacterAdded:Fire(player.Character)
expect('speed after respawn',player.Character.H.WalkSpeed,64);expect('jump after respawn',player.Character.H.JumpPower,90);expect('flight after respawn',player.Character.H.PlatformStand,true)
click('Settings/Restore all controls');expect('reset speed',player.Character.H.WalkSpeed,18);expect('reset jump',player.Character.H.JumpPower,60);expect('reset fly',player.Character.H.PlatformStand,false)
click('Settings/Restore all controls')
print('PASS: respawn rebind and reset restore the new character defaults')
click('Player/Custom speed',true);click('World/Fullbright',true);click('World/Custom field of view',true)
-- The source runs again next; the second launch must restore this session first.
