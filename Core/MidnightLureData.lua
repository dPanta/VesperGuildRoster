local _, addonTable = ...

local locations = {
    {
        id = "eversong-woods-lure-1",
        uiMapID = 2395,
        x = 0.4194,
        y = 0.7971,
        zoneName = "Eversong Woods",
    },
    {
        id = "zulaman-lure-1",
        uiMapID = 2437,
        x = 0.4756,
        y = 0.5263,
        zoneName = "Zul'Aman",
    },
    {
        id = "harandar-lure-1",
        uiMapID = 2413,
        x = 0.6661,
        y = 0.4784,
        zoneName = "Harandar",
    },
    {
        id = "voidstorm-lure-1",
        uiMapID = 2405,
        x = 0.5412,
        y = 0.6523,
        zoneName = "Voidstorm",
    },
}

local locationsByMapID = {}
for i = 1, #locations do
    local location = locations[i]
    local uiMapID = tonumber(location.uiMapID)
    if uiMapID then
        locationsByMapID[uiMapID] = locationsByMapID[uiMapID] or {}
        locationsByMapID[uiMapID][#locationsByMapID[uiMapID] + 1] = location
    end
end

addonTable.MidnightLureData = {
    locations = locations,
    locationsByMapID = locationsByMapID,
}
