-- VOLT ALL MODELS: Github-hosted original OBJ geometry + UV + original RGBA atlases.
-- All parts preserve OBJ-space alignment; spawned in front of camera.
local BASE = "https://raw.githubusercontent.com/commits0985891/rep/main/"
local SCALE = 10
local DISTANCE = 12
local LOAD_ONLY = nil -- set 0..15 to test one component; nil = all 16
local TRIANGLES_PER_YIELD = 200
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local function fetch(name)
    local response = request({Url=BASE .. name, Method="GET"})
    assert(response and response.StatusCode == 200, "download failed for " .. name .. ": " .. tostring(response and response.StatusCode))
    return response.Body
end

local manifest = HttpService:JSONDecode(fetch("manifest.json"))
local camera = assert(workspace.CurrentCamera)
local anchor = camera.CFrame * CFrame.new(0, 0, -DISTANCE)
local previous = workspace:FindFirstChild("VoltOriginalModels")
if previous then previous:Destroy() end
local folder = Instance.new("Model")
folder.Name = "VoltOriginalModels"
folder.Parent = workspace

local function loadItem(item)
    local image
    if item.texture then
        local bytes = fetch(item.texture)
        assert(#bytes == item.width * item.height * 4, "texture byte count mismatch: " .. item.texture)
        image = assert(AssetService:CreateEditableImage({Size=Vector2.new(item.width,item.height)}))
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(item.width,item.height), buffer.fromstring(bytes))
    end
    local group = Instance.new("Model")
    group.Name = "model_" .. item.id
    group.Parent = folder
    for idx,filename in ipairs(item.chunks) do
        local data = HttpService:JSONDecode(fetch(filename))
        local mesh = assert(AssetService:CreateEditableMesh())
        local vids = {}
        for i,p in ipairs(data.v) do
            vids[i] = mesh:AddVertex(Vector3.new(p[1]*SCALE,p[2]*SCALE,p[3]*SCALE))
        end
        local uids = {}
        for i,p in ipairs(data.uv) do
            uids[i] = mesh:AddUV(Vector2.new(p[1],p[2]))
        end
        for i,f in ipairs(data.f) do
            local face = mesh:AddTriangle(vids[f[1][1]], vids[f[2][1]], vids[f[3][1]])
            mesh:SetFaceUVs(face, {uids[f[1][2]],uids[f[2][2]],uids[f[3][2]]})
            if i % TRIANGLES_PER_YIELD == 0 then task.wait() end
        end
        local part = assert(AssetService:CreateMeshPartAsync(Content.fromObject(mesh)))
        part.Name = "part_" .. idx
        part.Anchored = true
        part.CanCollide = false
        part.DoubleSided = true
        part.Color = Color3.new(1,1,1)
        if image then part.TextureContent = Content.fromObject(image) end
        -- Each chunk was built in the original OBJ coordinate system.
        -- Roblox centers MeshPart geometry at its own origin; place at the original
        -- chunk bounds center to preserve positioning across separated chunks.
        local min, max = Vector3.new(math.huge,math.huge,math.huge), Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,p in ipairs(data.v) do
            local v = Vector3.new(p[1]*SCALE,p[2]*SCALE,p[3]*SCALE)
            min = Vector3.new(math.min(min.X,v.X),math.min(min.Y,v.Y),math.min(min.Z,v.Z))
            max = Vector3.new(math.max(max.X,v.X),math.max(max.Y,v.Y),math.max(max.Z,v.Z))
        end
        part.CFrame = anchor * CFrame.new((min+max)*0.5)
        part.Parent = group
        print("loaded model",item.id,"chunk",idx,"/",#item.chunks)
        task.wait()
    end
end

local done,failed=0,0
for _,item in ipairs(manifest.models) do
    if LOAD_ONLY == nil or LOAD_ONLY == item.id then
        local ok,err=pcall(loadItem,item)
        if ok then done+=1 else failed+=1;warn("model_"..item.id..": "..tostring(err)) end
    end
end
print("Volt model loading complete:",done,"models succeeded,",failed,"failed")
