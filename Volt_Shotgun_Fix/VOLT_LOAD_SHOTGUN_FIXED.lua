-- Shotgun texture/geometry replacement for Volt.
-- Upload the extracted Shotgun_Fix folder to the "guns" branch.
local BASE = "https://raw.githubusercontent.com/commits0985891/rep/guns/Shotgun_Fix/"
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local SCALE = 0.16 -- original shotgun uses larger OBJ units than the earlier pack
local DISTANCE = 12
local function fetch(name)
    local res = request({Url = BASE .. name, Method = "GET"})
    assert(res and res.StatusCode == 200, "GitHub download failed for " .. name .. ": " .. tostring(res and res.StatusCode))
    return res.Body
end
local manifest = HttpService:JSONDecode(fetch("shotgun_manifest.json"))
local assets = {}
local globalMin = Vector3.new(math.huge,math.huge,math.huge)
local globalMax = Vector3.new(-math.huge,-math.huge,-math.huge)
local function expand(v)
    globalMin = Vector3.new(math.min(globalMin.X,v.X), math.min(globalMin.Y,v.Y), math.min(globalMin.Z,v.Z))
    globalMax = Vector3.new(math.max(globalMax.X,v.X), math.max(globalMax.Y,v.Y), math.max(globalMax.Z,v.Z))
end
for _,item in ipairs(manifest.models) do
    local data = HttpService:JSONDecode(fetch(item.chunks[1]))
    assets[#assets+1] = {item=item, data=data}
    for _,v in ipairs(data.v) do expand(Vector3.new(v[1],v[2],v[3])) end
end
local globalCenter = (globalMin + globalMax) * 0.5
local camera = assert(workspace.CurrentCamera)
local anchor = camera.CFrame * CFrame.new(0, 0, -DISTANCE)
local newGroup = Instance.new("Model")
newGroup.Name = "VoltShotgunReplacement"
-- keep it unparented until all meshes succeed; failed loads do not remove the old shotgun
local ok,err = pcall(function()
    for _,obj in ipairs(assets) do
        local item,data=obj.item,obj.data
        local bytes=fetch(item.texture)
        assert(#bytes==item.width*item.height*4, "Invalid texture: " .. item.texture)
        local image=assert(AssetService:CreateEditableImage({Size=Vector2.new(item.width,item.height)}))
        image:WritePixelsBuffer(Vector2.zero,Vector2.new(item.width,item.height),buffer.fromstring(bytes))
        local low=Vector3.new(math.huge,math.huge,math.huge)
        local high=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,p in ipairs(data.v) do
            local v=Vector3.new(p[1],p[2],p[3])
            low=Vector3.new(math.min(low.X,v.X),math.min(low.Y,v.Y),math.min(low.Z,v.Z))
            high=Vector3.new(math.max(high.X,v.X),math.max(high.Y,v.Y),math.max(high.Z,v.Z))
        end
        local center=(low+high)*0.5
        local mesh=assert(AssetService:CreateEditableMesh())
        local vids,uids={},{}
        for i,p in ipairs(data.v) do
            vids[i]=mesh:AddVertex((Vector3.new(p[1],p[2],p[3])-center)*SCALE)
        end
        for i,p in ipairs(data.uv) do uids[i]=mesh:AddUV(Vector2.new(p[1],p[2])) end
        for i,f in ipairs(data.f) do
            local face=mesh:AddTriangle(vids[f[1][1]],vids[f[2][1]],vids[f[3][1]])
            mesh:SetFaceUVs(face,{uids[f[1][2]],uids[f[2][2]],uids[f[3][2]]})
            if i%200==0 then task.wait() end
        end
        local part=assert(AssetService:CreateMeshPartAsync(Content.fromObject(mesh)))
        part.Name="ShotgunPart_"..item.id
        part.Anchored=true
        part.CanCollide=false
        part.DoubleSided=true
        part.Color=Color3.new(1,1,1)
        part.TextureContent=Content.fromObject(image)
        part.CFrame=anchor*CFrame.new((center-globalCenter)*SCALE)
        part.Parent=newGroup
        print("Shotgun part loaded:", item.id)
        task.wait()
    end
end)
if not ok then
    newGroup:Destroy()
    warn("Shotgun replacement failed: "..tostring(err))
    return
end
local old = workspace:FindFirstChild("VoltShotgunReplacement")
if old then old:Destroy() end
newGroup.Parent=workspace
local original = workspace:FindFirstChild("VoltOriginalModels")
if original then
    for _,id in ipairs({13,14,15}) do
        local part=original:FindFirstChild("model_"..id)
        if part then part:Destroy() end
    end
end
print("Shotgun replacement complete (3 textured mesh parts)")
