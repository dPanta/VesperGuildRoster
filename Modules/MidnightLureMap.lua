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

    if UiMapPoint and UiMapPoint.CreateFromVector2D and CreateVector2D then
        return UiMapPoint.CreateFromVector2D(uiMapID, CreateVector2D(x, y))
    end

    if CreateVector2D then
        return {
            uiMapID = uiMapID,
            position = CreateVector2D(x, y),
        }
    end

    return nil
end

local MidnightLurePinMixin = CreateFromMixins(MapCanvasPinMixin)

function MidnightLurePinMixin:OnLoad()
    if self.vgMidnightLureInitialized then
        return
    end

    self.vgMidnightLureInitialized = true
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.18)
    self:SetSize(PIN_SIZE, PIN_SIZE)
    self:EnableMouse(true)
    self:SetHitRectInsets(-3, -3, -3, -3)
    if self.SetMouseClickEnabled then
        self:SetMouseClickEnabled(true)
    end
    if self.SetMouseMotionEnabled then
        self:SetMouseMotionEnabled(true)
    end

    local background = self.vgBackground
    if not background then
        background = self:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", self, "TOPLEFT", -2, 2)
        background:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 2, -2)
        background:SetColorTexture(0.10, 0.07, 0.04, 0.92)
        self.vgBackground = background
    end

    local icon = self.vgIcon
    if not icon then
        icon = self:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetAlpha(0.96)
        self.vgIcon = icon
    end
    icon:SetTexture(vesperTools:GetMidnightLureMapPinTexture())

    local highlight = self.vgHighlight
    if not highlight then
        highlight = self:CreateTexture(nil, "OVERLAY")
        highlight:SetAllPoints(self)
        highlight:SetColorTexture(1, 1, 1, 0.08)
        highlight:Hide()
        self.vgHighlight = highlight
    end

    self:SetScript("OnEnter", function(pin)
        pin:OnMouseEnter()
    end)
    self:SetScript("OnLeave", function(pin)
        pin:OnMouseLeave()
    end)
    self:SetScript("OnMouseUp", function(pin, mouseButton)
        pin:TryHandlePointer(mouseButton)
    end)
end

function MidnightLurePinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    if self.vgIcon then
        self.vgIcon:SetTexture(vesperTools:GetMidnightLureMapPinTexture())
        self.vgIcon:SetAlpha(0.96)
    end
    if self.vgHighlight then
        self.vgHighlight:Hide()
    end
    self:SetShown(true)
end

function MidnightLurePinMixin:OnMouseEnter()
    if self.vgHighlight then
        self.vgHighlight:Show()
    end
    if self.vgIcon then
        self.vgIcon:SetAlpha(1)
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.data and (self.data.zoneName or UNKNOWN) or UNKNOWN, 1, 1, 1)
    GameTooltip:AddLine(L["MIDNIGHT_LURE_SITE"], 0.95, 0.82, 0.45, true)
    GameTooltip:AddLine(L["MIDNIGHT_LURE_CLICK_SET_WAYPOINT"], 0.76, 0.76, 0.76, true)
    GameTooltip:Show()
end

function MidnightLurePinMixin:OnMouseLeave()
    if self.vgHighlight then
        self.vgHighlight:Hide()
    end
    if self.vgIcon then
        self.vgIcon:SetAlpha(0.96)
    end
    GameTooltip_Hide()
end

function MidnightLurePinMixin:OnClick(mouseButton)
    self:TryHandlePointer(mouseButton)
end

function MidnightLurePinMixin:HandleClick()
    local data = self.data
    if not data then
        return
    end

    if not (C_Map and C_Map.SetUserWaypoint) then
        return
    end

    local point = createWaypointPoint(data.uiMapID, data.x, data.y)
    if not point then
        return
    end

    local didSetWaypoint = pcall(C_Map.SetUserWaypoint, point)
    if didSetWaypoint then
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        return
    end

    vesperTools:Print(L["MIDNIGHT_LURE_WAYPOINT_UNAVAILABLE"])
end

function MidnightLurePinMixin:TryHandlePointer(mouseButton)
    if mouseButton and mouseButton ~= "LeftButton" then
        return
    end

    local now = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
    if self.lastHandleClickAt and (now - self.lastHandleClickAt) <= 0.15 then
        return
    end

    self.lastHandleClickAt = now
    self:HandleClick()
end

local MidnightLurePinProvider

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

function MidnightLureMap:OnInitialize()
    self.mapPinsInitialized = false
    self.worldMapShowHooked = false
    self.pendingMapPinInitialization = false
end

function MidnightLureMap:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("ADDON_LOADED")

    if WorldMapFrame then
        self:HookWorldMapShow()
        self:ScheduleWorldMapPinInitialization()
    end
end

function MidnightLureMap:PLAYER_LOGIN()
    self:UnregisterEvent("PLAYER_LOGIN")
    self:HookWorldMapShow()
    self:ScheduleWorldMapPinInitialization()
end

function MidnightLureMap:ADDON_LOADED(_, addonName)
    if addonName == "Blizzard_WorldMap" then
        self:HookWorldMapShow()
        self:ScheduleWorldMapPinInitialization()
    end
end

function MidnightLureMap:ScheduleWorldMapPinInitialization()
    if self.mapPinsInitialized or self.pendingMapPinInitialization or not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end

    self.pendingMapPinInitialization = true
    C_Timer.After(0, function()
        self.pendingMapPinInitialization = false

        if not self:IsEnabled() or not WorldMapFrame or not WorldMapFrame:IsShown() then
            return
        end

        self:TryInitializeWorldMapPins()
    end)
end

function MidnightLureMap:HookWorldMapShow()
    if self.worldMapShowHooked or not WorldMapFrame then
        return
    end

    WorldMapFrame:HookScript("OnShow", function()
        self:ScheduleWorldMapPinInitialization()
    end)
    self.worldMapShowHooked = true
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

    local pinPools = WorldMapFrame.pinPools
    if type(pinPools) ~= "table" then
        return
    end

    if not MidnightLurePinProvider then
        MidnightLurePinProvider = CreateFromMixins(MapCanvasDataProviderMixin)
        MidnightLurePinProvider.RemoveAllData = removeAllPinData
        MidnightLurePinProvider.RefreshAllData = refreshAllPinData
    end

    local resetFunc = function(_, pin)
        pin.data = nil
        pin:Hide()
        pin:ClearAllPoints()
    end

    local createFunc = function()
        local pin = CreateFrame("Frame", nil, canvas)
        Mixin(pin, MidnightLurePinMixin)
        pin:OnLoad()
        return pin
    end

    local pool
    if CreateUnsecuredRegionPoolInstance then
        pool = CreateUnsecuredRegionPoolInstance(PIN_TEMPLATE_NAME, createFunc, resetFunc)
    else
        pool = CreateFramePool("FRAME", canvas, nil, resetFunc, false, createFunc)
    end

    pinPools[PIN_TEMPLATE_NAME] = pool
    WorldMapFrame:AddDataProvider(MidnightLurePinProvider)

    self.mapPinsInitialized = true
end
