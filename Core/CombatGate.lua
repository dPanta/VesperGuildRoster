local _, addonTable = ...

local CombatGate = {}
addonTable.CombatGate = CombatGate

CombatGate.pendingByOwner = setmetatable({}, { __mode = "k" })

local eventFrame = CreateFrame("Frame")
CombatGate.eventFrame = eventFrame

local function isLockedDown()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function reportError(err)
    local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
    if type(handler) == "function" then
        handler(err)
        return
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(tostring(err))
        return
    end

    print(tostring(err))
end

local function runProtected(callback)
    local ok, err = xpcall(callback, debugstack and function(message)
        return string.format("%s\n%s", tostring(message), debugstack(2, 20, 20))
    end or tostring)
    if not ok then
        reportError(err)
    end
end

function CombatGate:IsLockedDown()
    return isLockedDown()
end

function CombatGate:Run(callback)
    if type(callback) ~= "function" then
        return false
    end

    if self:IsLockedDown() then
        return false
    end

    runProtected(callback)
    return true
end

function CombatGate:RunNamed(owner, key, callback)
    if type(callback) ~= "function" then
        return false
    end

    if not self:IsLockedDown() then
        runProtected(callback)
        return true
    end

    local resolvedOwner = owner or self
    local resolvedKey = key or callback
    local bucket = self.pendingByOwner[resolvedOwner]
    if not bucket then
        bucket = {}
        self.pendingByOwner[resolvedOwner] = bucket
    end

    bucket[resolvedKey] = callback
    return false
end

function CombatGate:Cancel(owner, key)
    local bucket = owner and self.pendingByOwner[owner] or nil
    if not bucket then
        return
    end

    bucket[key] = nil
    if next(bucket) == nil then
        self.pendingByOwner[owner] = nil
    end
end

function CombatGate:CancelOwner(owner)
    if owner then
        self.pendingByOwner[owner] = nil
    end
end

function CombatGate:Flush()
    if self:IsLockedDown() then
        return
    end

    for owner, bucket in pairs(self.pendingByOwner) do
        self.pendingByOwner[owner] = nil
        for _, callback in pairs(bucket) do
            runProtected(callback)
        end
    end
end

eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function()
    CombatGate:Flush()
end)
