local _, addonTable = ...

local WindowLifecycle = {}
addonTable.WindowLifecycle = WindowLifecycle

function WindowLifecycle:GetOrCreateNamedFrame(owner, stateKey, frameName, createFunc)
    if owner and stateKey and owner[stateKey] then
        return owner[stateKey], false
    end

    local existing = type(frameName) == "string" and _G[frameName] or nil
    if existing then
        if owner and stateKey then
            owner[stateKey] = existing
        end
        return existing, false
    end

    local frame = type(createFunc) == "function" and createFunc() or nil
    if owner and stateKey then
        owner[stateKey] = frame
    end
    return frame, true
end

function WindowLifecycle:Show(frame)
    if not frame then
        return
    end

    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
end

function WindowLifecycle:Hide(frame)
    if frame and frame.Hide then
        frame:Hide()
    end
end
