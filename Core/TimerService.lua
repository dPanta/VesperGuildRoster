local _, addonTable = ...

local TimerService = {}
addonTable.TimerService = TimerService

local function resolveCallback(owner, callbackOrMethod)
    if type(callbackOrMethod) == "string" then
        local method = owner and owner[callbackOrMethod]
        if type(method) ~= "function" then
            return nil
        end

        return function()
            method(owner)
        end
    end

    if type(callbackOrMethod) ~= "function" then
        return nil
    end

    if owner ~= nil then
        return function()
            callbackOrMethod(owner)
        end
    end

    return callbackOrMethod
end

function TimerService:Schedule(owner, callbackOrMethod, delaySeconds)
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        return nil
    end

    local callback = resolveCallback(owner, callbackOrMethod)
    if not callback then
        return nil
    end

    local delay = math.max(0, tonumber(delaySeconds) or 0)
    return C_Timer.NewTimer(delay, callback)
end

function TimerService:Cancel(timerHandle)
    if timerHandle and type(timerHandle.Cancel) == "function" then
        pcall(timerHandle.Cancel, timerHandle)
    end

    return nil
end
