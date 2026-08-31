if getgenv().library_loaded then
    return;
end;
getgenv().library_loaded = true;
local runservice = game:GetService("RunService");
local players = game:GetService("Players");
local localplayer = players.LocalPlayer;
local typeofcache = typeof;
local tickcache = tick;
local renderstepped = runservice.RenderStepped;
local primarypart;
local clientcframe;
local connection;
local currentlooptype;
local isspoofing = false;
local writing_internal = false;
local stopspoofing = false;
local executing = false;
local cframecallback;
local activespoofs = {};
local registeredspoofs = {};
local persistentloops = {};
local currentactive;
local equip_pause_ticks = 0;

-- Continuously keep clientcframe synchronized to the real HumanoidRootPart when not actively spoofing
runservice.Heartbeat:Connect(function()
    if not isspoofing and not writing_internal and primarypart and primarypart.Parent then
        clientcframe = primarypart.CFrame;
    end;
end);

local function protect_equips(char)
    local function onDescendantAdded(desc)
        if desc:IsA("Weld") and desc.Name == "RightGrip" then
            equip_pause_ticks = 3;
            if isspoofing and primarypart and clientcframe then
                primarypart.CFrame = clientcframe;
            end;
        end;
    end;
    local function onChildAdded(child)
        if child:IsA("Tool") then
            equip_pause_ticks = 3;
            if isspoofing and primarypart and clientcframe then
                primarypart.CFrame = clientcframe;
            end;
        end;
    end;
    char.DescendantAdded:Connect(onDescendantAdded);
    char.ChildAdded:Connect(onChildAdded);
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Weld") and desc.Name == "RightGrip" then
            if isspoofing and primarypart and clientcframe then
                primarypart.CFrame = clientcframe;
            end;
        end;
    end;
end;

local function oncharacter(char)
    primarypart = char:WaitForChild("HumanoidRootPart");
    clientcframe = primarypart.CFrame;
    protect_equips(char);
end;

if localplayer.Character then
    oncharacter(localplayer.Character);
end;
localplayer.CharacterAdded:Connect(oncharacter);

local mt = getrawmetatable(game);
local originalindex = mt.__index;
local originalnewindex = mt.__newindex;
local hooked = false;
if not hooked then
    setreadonly(mt, false);
    mt.__index = newcclosure(function(self, property)
        if (not checkcaller() and self == primarypart and isspoofing) then
            if property == "CFrame" then
                return clientcframe;
            elseif property == "Position" then
                return clientcframe.Position;
            elseif property == "Rotation" then
                return clientcframe.Rotation;
            elseif property == "Orientation" then
                local rx, ry, rz = clientcframe:ToEulerAnglesXYZ()
                return Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
            end;
        end;
        return originalindex(self, property);
    end);
    mt.__newindex = newcclosure(function(self, property, value)
        if (self == primarypart and isspoofing and not writing_internal) then
            if property == "CFrame" then
                clientcframe = value;
                return;
            elseif property == "Position" then
                clientcframe = CFrame.new(value) * clientcframe.Rotation;
                return;
            elseif property == "Velocity" or property == "AssemblyLinearVelocity" or property == "RotVelocity" or property == "AssemblyAngularVelocity" then
                return;
            end;
        end;
        return originalnewindex(self, property, value);
    end);
    setreadonly(mt, true);
    hooked = true;
end;

local looptypes = {
    heartbeat = runservice.Heartbeat,
    renderstepped = runservice.RenderStepped,
    stepped = runservice.Stepped
};

local function evaluatecurrent()
    local best;
    for _, v in ipairs(activespoofs) do
        if not best then
            best = v;
        else
            if v.priority > best.priority then
                best = v;
            elseif v.priority == best.priority and v.timestamp < best.timestamp then
                best = v;
            end;
        end;
    end;
    currentactive = best;
end;

local function refreshconnection()
    if not currentactive then
        if connection then
            connection:Disconnect();
            connection = nil;
            currentlooptype = nil;
        end;
        return;
    end;
    local looptype = currentactive.looptype;
    if connection and currentlooptype == looptype then
        return;
    end;
    if connection then
        connection:Disconnect();
        connection = nil;
    end;
    currentlooptype = looptype;
    local event = looptypes[looptype] or runservice.Heartbeat;
    connection = event:Connect(function()
        if stopspoofing or executing then
            return;
        end;
        if not (primarypart and primarypart.Parent) then
            return;
        end;
        if equip_pause_ticks > 0 then
            equip_pause_ticks = equip_pause_ticks - 1;
            clientcframe = primarypart.CFrame;
            return;
        end;
        local spoof = currentactive;
        if not spoof then
            return;
        end;
        executing = true;
        clientcframe = primarypart.CFrame;
        local success, target, restore = pcall(spoof.callback, clientcframe);
        if success and target and typeofcache(target) == "CFrame" then
            local savedVel = primarypart.AssemblyLinearVelocity;
            local savedRotVel = primarypart.AssemblyAngularVelocity;
            isspoofing = true;
            writing_internal = true;
            primarypart.CFrame = target;
            writing_internal = false;
            renderstepped:Wait();
            local restore_target = clientcframe
            if restore then
                if typeofcache(restore) == "function" then
                    local ok, res = pcall(restore)
                    if ok and typeofcache(res) == "CFrame" then
                        restore_target = res
                    end
                elseif typeofcache(restore) == "CFrame" then
                    restore_target = restore
                end
            end
            writing_internal = true;
            primarypart.CFrame = restore_target;
            if savedVel.Magnitude > 0.01 then
                primarypart.AssemblyLinearVelocity = savedVel;
            else
                primarypart.AssemblyLinearVelocity = Vector3.new(0, 0.001, 0);
            end;
            primarypart.AssemblyAngularVelocity = savedRotVel;
            writing_internal = false;
            isspoofing = false;
            if cframecallback then
                cframecallback(target);
            end;
        elseif not success then
            warn("callback error [" .. spoof.name .. "]: " .. tostring(target));
        end;
        executing = false;
    end);
end;

getgenv().serverposition = function(looptype, logicname, targetlogic, priority)
    if typeofcache(logicname) ~= "string" then
        warn("invalid logic name");
        return;
    end;
    if registeredspoofs[logicname] then
        warn("logic already registered: " .. logicname);
        return;
    end;
    if typeofcache(targetlogic) ~= "function" then
        warn("invalid callback for: " .. logicname);
        return;
    end;
    if priority ~= nil and typeofcache(priority) ~= "number" then
        warn("invalid priority for: " .. logicname);
        return;
    end;
    if typeofcache(looptype) ~= "string" then
        warn("invalid looptype for: " .. logicname);
        return;
    end;
    local lt = looptype:lower();
    registeredspoofs[logicname] = {
        priority = priority or 0,
        timestamp = tickcache(),
        callback = targetlogic,
        looptype = lt,
        name = logicname
    };
end;

getgenv().setrunning = function(logicname, booleanref, persistent)
    local spoofdata = registeredspoofs[logicname];
    if not spoofdata then
        warn("invalid name: " .. tostring(logicname));
        return;
    end;
    local function applystatus(s)
        local status = s;
        if typeofcache(s) == "function" then
            status = s();
        end;
        if status == true then
            for _, v in ipairs(activespoofs) do
                if v.name == logicname then
                    return;
                end;
            end;
            table.insert(activespoofs, spoofdata);
            if not currentactive then
                currentactive = spoofdata;
            else
                if spoofdata.priority > currentactive.priority or (spoofdata.priority == currentactive.priority and spoofdata.timestamp < currentactive.timestamp) then
                    currentactive = spoofdata;
                end;
                if connection then
                    connection:Disconnect();
                    connection = nil;
                end;
            end;
            refreshconnection();
        else
            local removedcurrent = false;
            for i, v in ipairs(activespoofs) do
                if v.name == logicname then
                    if v == currentactive then removedcurrent = true; end;
                    table.remove(activespoofs, i);
                    break;
                end;
            end;
            if removedcurrent then evaluatecurrent(); end;
            refreshconnection();
        end;
    end;
    applystatus(booleanref);
    if persistent then
        persistentloops[logicname] = persistentloops[logicname] or {};
        persistentloops[logicname].paused = false;
        persistentloops[logicname].getter = booleanref;
        if not persistentloops[logicname].connection then
            persistentloops[logicname].connection = runservice.Heartbeat:Connect(function()
                local loop = persistentloops[logicname];
                if not loop.paused then
                    local desired;
                    if typeofcache(loop.getter) == "function" then
                        desired = loop.getter();
                    else
                        desired = loop.getter;
                    end;
                    if desired ~= getrunning(logicname) then
                        applystatus(loop.getter);
                    end;
                end;
            end);
        end;
    end;
end;

getgenv().getrunning = function(logicname)
    if not registeredspoofs[logicname] then
        return false;
    end;
    for _, v in ipairs(activespoofs) do
        if v.name == logicname then
            return true;
        end;
    end;
    return false;
end;

getgenv().resetcframe = function()
    stopspoofing = true;
    isspoofing = false;
    executing = false;
    if primarypart and clientcframe then
        primarypart.CFrame = clientcframe;
    end;
    for name, _ in pairs(registeredspoofs) do
        for _, v in ipairs(activespoofs) do
            if v.name == name then
                table.remove(activespoofs, _)
                break;
            end
        end
        if persistentloops[name] then
            persistentloops[name].paused = true;
        end
    end;
    currentactive = nil;
    if connection then
        connection:Disconnect();
        connection = nil;
        currentlooptype = nil;
    end;
    stopspoofing = false;
end;

getgenv().clearspoofs = function()
    for _, v in pairs(persistentloops) do
        if v.connection then
            v.connection:Disconnect();
        end;
    end;
    activespoofs = {};
    registeredspoofs = {};
    persistentloops = {};
    currentactive = nil;
    if connection then
        connection:Disconnect();
        connection = nil;
        currentlooptype = nil;
    end;
end;

getgenv().servercallback = function(callback)
    if typeofcache(callback) == "function" then
        cframecallback = callback;
    end;
end;
