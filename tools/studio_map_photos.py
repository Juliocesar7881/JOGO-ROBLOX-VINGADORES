"""Photograph actual generated maps in Studio, restoring the shared editor afterward.

Only the battlefield terrain region is backed up/replaced. Source scripts, the
lobby and pre-existing models are not overwritten. Images are captured from the
Studio renderer, then imported as image assets for the portal signs.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time

import studio_sync

ROOT = Path(__file__).resolve().parent.parent
SETUP = r'''
assert(game.PlaceId==97132875544830 and game:GetService("RunService"):IsEdit(),"Open the shared place in edit mode")
assert(not _G.DoomPhotoSession,"Restore the existing photo session first")
local light,terrain=game:GetService("Lighting"),workspace.Terrain
local session={props={},effects={},materials={},terrainProps={},clouds={}}
session.region=terrain:CopyRegion(Region3int16.new(Vector3int16.new(-48,-8,-48),Vector3int16.new(48,24,48)))
session.camera,session.focus,session.fov=workspace.CurrentCamera.CFrame,workspace.CurrentCamera.Focus,workspace.CurrentCamera.FieldOfView
for _,key in ipairs({"ClockTime","Brightness","EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows","ShadowSoftness","Ambient","OutdoorAmbient","ExposureCompensation","FogColor","FogEnd","FogStart"}) do session.props[key]=light[key] end
for _,child in ipairs(light:GetChildren()) do table.insert(session.effects,child:Clone()) end
for _,mat in ipairs(Enum.Material:GetEnumItems()) do local ok,value=pcall(terrain.GetMaterialColor,terrain,mat); if ok then session.materials[mat]=value end end
for _,key in ipairs({"WaterColor","WaterTransparency","WaterReflectance","WaterWaveSize","WaterWaveSpeed"}) do session.terrainProps[key]=terrain[key] end
for _,child in ipairs(terrain:GetChildren()) do if child:IsA("Clouds") then table.insert(session.clouds,child:Clone()) end end
local function fresh(module) local copy=module:Clone(); copy.Parent=module.Parent; local result=require(copy); copy:Destroy(); return result end
local world=fresh(game:GetService("ServerScriptService").DoomServer.WorldBuilder)
session.world=setmetatable({catalog=fresh(game:GetService("ReplicatedStorage").DoomShared.Catalog)},world)
session.hidden={}
for _,name in ipairs({"DoomWorld","EditorBaseplate","EditorSpawn"}) do local item=workspace:FindFirstChild(name); if item then table.insert(session.hidden,item); item.Parent=nil end end
_G.DoomPhotoSession=session
game:GetService("Selection"):Set({})
print("__MARKER__")
'''
CLEAN = r'''
local s=_G.DoomPhotoSession
if s then
 if s.world.root then s.world.root:Destroy() end
 local terrain,light=workspace.Terrain,game:GetService("Lighting")
 terrain:PasteRegion(s.region,Vector3int16.new(-48,-8,-48),true)
 for mat,color in pairs(s.materials) do terrain:SetMaterialColor(mat,color) end
 for key,value in pairs(s.terrainProps) do terrain[key]=value end
 for _,child in ipairs(terrain:GetChildren()) do if child:IsA("Clouds") then child:Destroy() end end
 for _,child in ipairs(s.clouds) do child.Parent=terrain end
 for _,child in ipairs(light:GetChildren()) do child:Destroy() end
 for _,child in ipairs(s.effects) do child.Parent=light end
 for key,value in pairs(s.props) do light[key]=value end
 for _,item in ipairs(s.hidden) do item.Parent=workspace end
 workspace.CurrentCamera.CFrame,workspace.CurrentCamera.Focus,workspace.CurrentCamera.FieldOfView=s.camera,s.focus,s.fov
 _G.DoomPhotoSession=nil
end
print("__MARKER__")
'''

def command(code):
    marker = 'DOOM_PHOTO_' + str(time.time_ns())
    studio_sync.run_command(code.replace('__MARKER__', marker), 960)
    print(studio_sync.wait_for(marker, time.time(), 30), flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('map',choices=['manhattan','gamma','hydra','wakanda','latveria','asgard','clean'])
    parser.add_argument('--window-handle',type=int,required=True)
    parser.add_argument('--eye',type=float,nargs=3,default=[-38,13,44])
    parser.add_argument('--look',type=float,nargs=3,default=[8,10,-42])
    parser.add_argument('--fov',type=float,default=65)
    parser.add_argument('--keep',action='store_true',help='Keep temporary setup for the next photograph; finish with clean.')
    args=parser.parse_args()
    studio_sync.STUDIO_WINDOW=args.window_handle
    if args.map=='clean': command(CLEAN); return
    command('if not _G.DoomPhotoSession then\n'+SETUP+'\nelse print("__MARKER__") end')
    captured=False
    try:
        command(f'''
local s=_G.DoomPhotoSession
s.world:Build("{args.map}")
s.world.root.Name="DoomMapPhoto"
for _,item in ipairs(s.world.root:GetDescendants()) do if item:IsA("BillboardGui") then item.Enabled=false end end
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new({','.join(map(str,args.eye))}),Vector3.new({','.join(map(str,args.look))}))
workspace.CurrentCamera.Focus=CFrame.new({','.join(map(str,args.look))})
workspace.CurrentCamera.FieldOfView={args.fov}
print("__MARKER__")
''')
        studio_sync.run_command('-- Map photograph',961)
        output=Path('test-results')/'map-photos'/f'{args.map}-full.png'
        subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'tools'/'capture_map_photo.ps1'),'-WindowHandle',str(args.window_handle),'-OutputPath',str(output),'-MapId',args.map],check=True)
        dest=ROOT/'assets'/'map-photos'
        dest.mkdir(parents=True,exist_ok=True)
        (dest/f'{args.map}.camera.json').write_text(json.dumps({'map':args.map,'eye':args.eye,'look':args.look,'fov':args.fov,'source':'WorldBuilder.Build / Roblox Studio renderer'},indent=2)+'\n',encoding='utf-8')
        captured=True
    finally:
        if not args.keep or not captured: command(CLEAN)


if __name__=='__main__': main()
