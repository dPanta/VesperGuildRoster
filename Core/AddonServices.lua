local addonName, addonTable = ...

local AddonServices = {}
addonTable.AddonServices = AddonServices

local tmp = {}

local function resolveOwnerLabel(owner)
    if type(owner) == "table" then
        if type(owner.name) == "string" and owner.name ~= "" then
            return owner.name
        end
        if type(owner.moduleName) == "string" and owner.moduleName ~= "" then
            return owner.moduleName
        end
    end

    return addonName
end

function AddonServices:Print(owner, ...)
    local frame = DEFAULT_CHAT_FRAME
    local startIndex = 1
    local firstArg = select(1, ...)
    if type(firstArg) == "table" and firstArg.AddMessage then
        frame = firstArg
        startIndex = 2
    end

    local argCount = select("#", ...)
    local count = 0
    if owner ~= nil then
        count = count + 1
        tmp[count] = "|cff33ff99" .. tostring(resolveOwnerLabel(owner)) .. "|r:"
    end

    for index = startIndex, argCount do
        count = count + 1
        tmp[count] = tostring(select(index, ...))
    end

    if frame and type(frame.AddMessage) == "function" then
        frame:AddMessage(table.concat(tmp, " ", 1, count))
    else
        print(table.concat(tmp, " ", 1, count))
    end

    for index = 1, count do
        tmp[index] = nil
    end
end

function AddonServices:RegisterChatCommand(owner, command, func)
    if type(command) ~= "string" or command == "" then
        return false
    end

    -- Use a vesperTools-private slash namespace so we don't share keys with every
    -- AceConsole-3.0 addon in the ecosystem (their UnregisterChatCommand wipes the
    -- global SlashCmdList entry, the SLASH_*1 global, AND hash_SlashCmdList["/X"]).
    local slashName = "VESPERTOOLS_" .. string.upper(command)
    local upperCommand = string.upper(command)

    local handler
    if type(func) == "string" then
        local method = owner and owner[func]
        if type(method) ~= "function" then
            return false
        end
        handler = function(input, editBox)
            method(owner, input, editBox)
        end
    elseif type(func) == "function" then
        handler = function(input, editBox)
            func(owner, input, editBox)
        end
    else
        return false
    end

    SlashCmdList[slashName] = handler
    _G["SLASH_" .. slashName .. "1"] = "/" .. string.lower(command)

    -- Prime the hash so the first invocation skips the SLASH_* scan and so any
    -- previously cached nil entry is replaced immediately.
    if hash_SlashCmdList then
        hash_SlashCmdList["/" .. upperCommand] = handler
    end

    return true
end
