-- Volt EditableMesh original OBJ test, model_0 / mag_0
-- Upload model_0.json and mag_0.rgba to the ROOT of a PUBLIC GitHub repo.
-- Replace the repository URL below with your own raw.githubusercontent.com URL.
local BASE = "https://raw.githubusercontent.com/USERNAME/REPO/main/"
local SCALE = 10 -- original OBJ units may be small; change as needed

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local function fetch(name)
    local url = BASE .. name
    local response = request({Url=url, Method="GET"})
    assert(response and response.StatusCode == 200, "HTTP failed: "..name.." "..tostring(response and response.StatusCode))
    return response.Body
end

local ok,err=pcall(function()
    local data=HttpService:JSONDecode(fetch("model_0.json"))
    local rgba=fetch("mag_0.rgba")
    assert(#rgba==1024*1024*4, "Wrong RGBA byte count: "..#rgba)
    local image=assert(AssetService:CreateEditableImage({Size=Vector2.new(1024,1024)}))
    image:WritePixelsBuffer(Vector2.zero,Vector2.new(1024,1024),buffer.fromstring(rgba))
    local mesh=assert(AssetService:CreateEditableMesh())
    local verts={}
    for i,p in ipairs(data.v) do
        verts[i]=mesh:AddVertex(Vector3.new(p[1]*SCALE,p[2]*SCALE,p[3]*SCALE))
    end
    local uvIds={}
    for i,uv in ipairs(data.uv) do
        uvIds[i]=mesh:AddUV(Vector2.new(uv[1],uv[2]))
    end
    for i,t in ipairs(data.f) do
        local face=mesh:AddTriangle(verts[t[1][1]],verts[t[2][1]],verts[t[3][1]])
        mesh:SetFaceUVs(face,{uvIds[t[1][2]],uvIds[t[2][2]],uvIds[t[3][2]]})
        if i%500==0 then task.wait() end
    end
    local part=AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
    part.Name="OriginalMagazineTest"
    part.Anchored=true
    part.CanCollide=false
    part.DoubleSided=true
    part.Color=Color3.new(1,1,1)
    part.TextureContent=Content.fromObject(image)
    local camera=workspace.CurrentCamera
    part.CFrame=camera.CFrame*CFrame.new(0,0,-8)
    part.Parent=workspace
    print("Original magazine loaded:", #data.v, "vertices /", #data.f, "triangles")
end)
print("Volt original model test:",ok)
if not ok then warn(err) end
