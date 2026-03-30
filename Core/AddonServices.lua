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

    local slashName = "ACECONSOLE_" .. string.upper(command)
    if type(func) == "string" then
        SlashCmdList[slashName] = function(input, editBox)
            local method = owner and owner[func]
            if type(method) == "function" then
                method(owner, input, editBox)
            end
        end
    elseif type(func) == "function" then
        SlashCmdList[slashName] = function(input, editBox)
            func(owner, input, editBox)
        end
    else
        return false
    end

    _G["SLASH_" .. slashName .. "1"] = "/" .. string.lower(command)
    return true
end
