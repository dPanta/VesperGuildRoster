local _, addonTable = ...
local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local MidnightLureMap = vesperTools:NewModule("MidnightLureMap", "AceEvent-3.0")
local L = vesperTools.L
local MidnightLureData = addonTable.MidnightLureData or {}

local PIN_TEMPLATE_NAME = "vesperToolsMidnightLurePinTemplate"
local PIN_SIZE = 24
local PINS_BY_MAP_ID = MidnightLureData.locationsByMapID or {}

local function createWaypointPoint(uiMapID, x, y)
    if UiMapPoint and UiMapPoint.CreateFromCoordinates then
        return UiMapPoint.CreateFromCoordinates(uiMapID, x, y)
    end

    if CreateVector2D then
        return {
            uiMapID = uiMapID,
            position = CreateVector2D(x, y),
        }
    end

    return nil
end

local MidnightLurePinMixin = {}

function MidnightLurePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.18)
    self:SetSize(PIN_SIZE, PIN_SIZE)
    self:EnableMouse(true)
    self:RegisterForClicks("LeftButtonUp")
    self:SetHitRectInsets(-3, -3, -3, -3)

    vesperTools:ApplyModernIconButtonStyle(self, {
        size = PIN_SIZE,
        iconTexture = vesperTools:GetMidnightLureMapPinTexture(),
        iconScale = 0.72,
        backgroundColor = { 0.10, 0.07, 0.04 },
        backgroundAlpha = 0.94,
        borderColor = { 0.95, 0.78, 0.34 },
        borderAlpha = 0.38,
        hoverAlpha = 0.08,
        pressedAlpha = 0.14,
        iconAlpha = 0.96,
    })

    self:SetScript("OnEnter", function(pin)
        GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
        GameTooltip:AddLine(pin.data and (pin.data.zoneName or UNKNOWN) or UNKNOWN, 1, 1, 1)
        GameTooltip:AddLine(L["MIDNIGHT_LURE_SITE"], 0.95, 0.82, 0.45, true)
        GameTooltip:AddLine(L["MIDNIGHT_LURE_CLICK_SET_WAYPOINT"], 0.76, 0.76, 0.76, true)
        GameTooltip:Show()
    end)
    self:SetScript("OnLeave", GameTooltip_Hide)
    self:SetScript("OnClick", function(pin)
        pin:HandleClick()
    end)
end

function MidnightLurePinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    self:SetShown(true)
end

function MidnightLurePinMixin:HandleClick()
    local data = self.data
    if not data then
        return
    end

    if not (C_Map and C_Map.SetUserWaypoint) then
        return
    end

    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(data.uiMapID) then
        vesperTools:Print(L["MIDNIGHT_LURE_WAYPOINT_UNAVAILABLE"])
        return
    end

    local point = createWaypointPoint(data.uiMapID, data.x, data.y)
    if not point then
        return
    end

    C_Map.SetUserWaypoint(point)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

local MidnightLurePinProvider = {}

local function removeAllPinData(self)
    local mapCanvas = self.GetMap and self:GetMap() or nil
    if mapCanvas and mapCanvas.RemoveAllPinsByTemplate then
        mapCanvas:RemoveAllPinsByTemplate(PIN_TEMPLATE_NAME)
    end
end

local function refreshAllPinData(self)
    removeAllPinData(self)

    local mapCanvas = self.GetMap and self:GetMap() or nil
    if not mapCanvas or not mapCanvas.GetMapID then
        return
    end

    local uiMapID = mapCanvas:GetMapID()
    if not uiMapID then
        return
    end

    local pins = PINS_BY_MAP_ID[uiMapID]
    if not pins then
        return
    end

    for i = 1, #pins do
        mapCanvas:AcquirePin(PIN_TEMPLATE_NAME, pins[i])
    end
end

local function ensurePinProviderMixin()
    if MidnightLurePinProvider.vgIsMixed then
        return
    end

    Mixin(MidnightLurePinProvider, MapCanvasDataProviderMixin)
    MidnightLurePinProvider.RemoveAllData = removeAllPinData
    MidnightLurePinProvider.RefreshAllData = refreshAllPinData
    MidnightLurePinProvider.vgIsMixed = true
end

function MidnightLureMap:OnInitialize()
    self.mapPinsInitialized = false
end

function MidnightLureMap:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("ADDON_LOADED")

    if WorldMapFrame then
        self:TryInitializeWorldMapPins()
    end
end

function MidnightLureMap:PLAYER_LOGIN()
    self:UnregisterEvent("PLAYER_LOGIN")
    self:TryInitializeWorldMapPins()
end

function MidnightLureMap:ADDON_LOADED(_, addonName)
    if addonName == "Blizzard_WorldMap" then
        self:TryInitializeWorldMapPins()
    end
end

function MidnightLureMap:TryInitializeWorldMapPins()
    if self.mapPinsInitialized or not WorldMapFrame then
        return
    end

    if not (MapCanvasPinMixin and MapCanvasDataProviderMixin and WorldMapFrame.AddDataProvider) then
        return
    end

    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or nil
    if not canvas then
        return
    end

    ensurePinProviderMixin()

    local resetFunc = function(_, pin)
        pin.data = nil
        pin:Hide()
        pin:ClearAllPoints()
    end

    local createFunc = function()
        local pin = CreateFrame("Button", nil, canvas, "BackdropTemplate")
        Mixin(pin, MapCanvasPinMixin, MidnightLurePinMixin)
        pin:OnLoad()
        return pin
    end

    local pool
    if CreateUnsecuredRegionPoolInstance then
        pool = CreateUnsecuredRegionPoolInstance(PIN_TEMPLATE_NAME, createFunc, resetFunc)
    else
        pool = CreateFramePool("FRAME", canvas, nil, resetFunc, false, createFunc)
    end

    WorldMapFrame.pinPools = WorldMapFrame.pinPools or {}
    WorldMapFrame.pinPools[PIN_TEMPLATE_NAME] = pool
    WorldMapFrame:AddDataProvider(MidnightLurePinProvider)

    self.mapPinsInitialized = true
end
