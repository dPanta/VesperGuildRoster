local _, addonTable = ...

local AceComm = assert(LibStub("AceComm-3.0", true), "vesperTools CommAdapter requires AceComm-3.0")

local dispatcher = {}
AceComm:Embed(dispatcher)

local CommAdapter = {}
addonTable.CommAdapter = CommAdapter

CommAdapter.dispatcher = dispatcher
CommAdapter.ownerByPrefix = {}
CommAdapter.handlerByPrefix = {}
CommAdapter.prefixesByOwner = setmetatable({}, { __mode = "k" })
CommAdapter.dispatcherRegistrations = {}

local function resolveOwnerLabel(owner)
    if type(owner) == "table" then
        if type(owner.moduleName) == "string" and owner.moduleName ~= "" then
            return owner.moduleName
        end
        if type(owner.name) == "string" and owner.name ~= "" then
            return owner.name
        end
    end

    return tostring(owner)
end

local function resolveHandler(owner, handler)
    local resolvedHandler = handler or "OnCommReceived"
    if type(resolvedHandler) == "string" then
        local method = owner and owner[resolvedHandler] or nil
        if type(method) ~= "function" then
            error(string.format("CommAdapter handler '%s' is missing on %s", resolvedHandler, resolveOwnerLabel(owner)), 3)
        end
        return resolvedHandler
    end

    if type(resolvedHandler) ~= "function" then
        error("CommAdapter handler must be a function or method name", 3)
    end

    return resolvedHandler
end

function dispatcher:OnCommReceived(prefix, message, distribution, sender)
    CommAdapter:Dispatch(prefix, message, distribution, sender)
end

function CommAdapter:EnsureDispatcherRegistration(prefix)
    if self.dispatcherRegistrations[prefix] then
        return true
    end

    dispatcher:RegisterComm(prefix, "OnCommReceived")
    self.dispatcherRegistrations[prefix] = true
    return true
end

function CommAdapter:Register(owner, prefix, handler)
    if type(owner) ~= "table" then
        error("CommAdapter:Register owner must be a table", 2)
    end
    if type(prefix) ~= "string" or prefix == "" then
        error("CommAdapter:Register prefix must be a non-empty string", 2)
    end

    local existingOwner = self.ownerByPrefix[prefix]
    if existingOwner and existingOwner ~= owner then
        error(string.format(
            "CommAdapter prefix '%s' is already owned by %s",
            prefix,
            resolveOwnerLabel(existingOwner)
        ), 2)
    end

    local resolvedHandler = resolveHandler(owner, handler)
    self:EnsureDispatcherRegistration(prefix)
    self.ownerByPrefix[prefix] = owner
    self.handlerByPrefix[prefix] = resolvedHandler

    local ownerPrefixes = self.prefixesByOwner[owner]
    if not ownerPrefixes then
        ownerPrefixes = {}
        self.prefixesByOwner[owner] = ownerPrefixes
    end
    ownerPrefixes[prefix] = true

    return true
end

function CommAdapter:Dispatch(prefix, message, distribution, sender)
    local owner = self.ownerByPrefix[prefix]
    local handler = self.handlerByPrefix[prefix]
    if not owner or not handler then
        return
    end

    if type(handler) == "string" then
        owner[handler](owner, prefix, message, distribution, sender)
        return
    end

    handler(owner, prefix, message, distribution, sender)
end

function CommAdapter:Send(prefix, message, distribution, target, prio, callbackFn, callbackArg)
    if type(prefix) ~= "string" or prefix == "" then
        error("CommAdapter:Send prefix must be a non-empty string", 2)
    end

    self:EnsureDispatcherRegistration(prefix)
    dispatcher:SendCommMessage(prefix, message, distribution, target, prio, callbackFn, callbackArg)
    return true
end

function CommAdapter:Unregister(owner, prefix)
    if type(prefix) ~= "string" or prefix == "" then
        return false
    end

    local currentOwner = self.ownerByPrefix[prefix]
    if not currentOwner or (owner and currentOwner ~= owner) then
        return false
    end

    self.ownerByPrefix[prefix] = nil
    self.handlerByPrefix[prefix] = nil

    local ownerPrefixes = self.prefixesByOwner[currentOwner]
    if ownerPrefixes then
        ownerPrefixes[prefix] = nil
        if next(ownerPrefixes) == nil then
            self.prefixesByOwner[currentOwner] = nil
        end
    end

    if self.dispatcherRegistrations[prefix] then
        dispatcher:UnregisterComm(prefix)
        self.dispatcherRegistrations[prefix] = nil
    end

    return true
end

function CommAdapter:UnregisterOwner(owner)
    local ownerPrefixes = owner and self.prefixesByOwner[owner] or nil
    if not ownerPrefixes then
        return false
    end

    local prefixes = {}
    for prefix in pairs(ownerPrefixes) do
        prefixes[#prefixes + 1] = prefix
    end

    for i = 1, #prefixes do
        self:Unregister(owner, prefixes[i])
    end

    return true
end
