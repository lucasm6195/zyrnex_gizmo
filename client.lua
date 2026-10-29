local settings = Config
local hud = GizmoHud

local session
local lastToggle = {}

local BLOCKED_CONTROLS <const> = {
  21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 45, 47,
  58, 75, 140, 141, 142, 143, 199, 200, 202, 241, 242, 245, 257, 263, 264,
  1, 2, 106
}

local RAY_FLAGS <const> = 1 | 16

local function clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

local function cartesianToSpherical(x, y, z)
  local radius = math.sqrt(x * x + y * y + z * z)
  if radius < 0.001 then return 0.001, 0.0, 1.0 end
  return radius, math.atan(y, x), math.acos(clamp(z / radius, -1.0, 1.0))
end

local function sphericalToCartesian(radius, theta, phi)
  return vector3(
    radius * math.sin(phi) * math.cos(theta),
    radius * math.sin(phi) * math.sin(theta),
    radius * math.cos(phi)
  )
end

local function rotationToDirection(rot)
  local z = math.rad(rot.z)
  local x = math.rad(rot.x)
  local horizontal = math.abs(math.cos(x))
  return vector3(-math.sin(z) * horizontal, math.cos(z) * horizontal, math.sin(x))
end

local function packVec(vec)
  return { x = vec.x + 0.0, y = vec.y + 0.0, z = vec.z + 0.0 }
end

local function once(name)
  local now = GetGameTimer()
  local previous = lastToggle[name]
  if previous and (now - previous) < 150 then return false end
  lastToggle[name] = now
  return true
end

local function pivotOf(entity)
  local center = session.center
  return GetOffsetFromEntityInWorldCoords(entity, center.x, center.y, center.z)
end

local function clampOrigin(entity)
  local limit = session.distanceLimit
  local offset = GetEntityCoords(entity) - session.limitOrigin
  local distance = #offset

  if distance <= limit or distance < 0.0001 then
    session.limited = false
    return false
  end

  local clamped = session.limitOrigin + (offset * (limit / distance))
  SetEntityCoordsNoOffset(entity, clamped.x, clamped.y, clamped.z, false, false, false)
  session.limited = true
  return true
end

local function groundEntity(entity)
  local min, max = GetModelDimensions(GetEntityModel(entity))
  local rotation = GetEntityRotation(entity, 2)
  SetEntityRotation(entity, 0.0, 0.0, rotation.z, 2, true)

  local from = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, (min.z + max.z) * 0.5)
  local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, from.x, from.y, from.z - 15.0, RAY_FLAGS, entity, 7)
  local _, hit, ground = GetShapeTestResult(handle)
  if hit ~= true and hit ~= 1 then return false end

  local coords = GetEntityCoords(entity)
  SetEntityCoordsNoOffset(entity, coords.x, coords.y, ground.z - min.z, false, false, false)
  return true
end

local function makeResult()
  local entity = session.entity
  local exists = DoesEntityExist(entity)
  local snap = session.snapshot

  return {
    handle = entity,
    position = exists and GetEntityCoords(entity) or snap.coords,
    rotation = exists and GetEntityRotation(entity, 2) or snap.rotation,
    cancelled = session.cancelled and true or false,
    confirmed = (not session.open) and not session.cancelled
  }
end

local function pushEntity()
  if not session or not DoesEntityExist(session.entity) then return end
  SendNUIMessage({
    action = 'setEntity',
    data = {
      handle = session.entity,
      position = packVec(pivotOf(session.entity)),
      rotation = packVec(GetEntityRotation(session.entity, 2)),
      scale = { x = 1.0, y = 1.0, z = 1.0 }
    }
  })
end

local function pushControls()
  if not session then return end
  SendNUIMessage({
    action = 'configure',
    data = {
      mode = session.mode,
      space = session.space,
      translationSnap = session.snap and settings.TranslationSnap or 0,
      rotationSnap = session.snap and settings.RotationSnap or 0,
      scaleSnap = 0,
      size = settings.Size,
      cursor = true,
      camera = 'orbit'
    }
  })
end

local function refreshHud()
  if not session then return end
  hud.draw({
    label = session.label,
    mode = session.mode,
    space = session.space,
    snap = session.snap,
    limited = session.limited
  })
end

local function setMode(mode)
  if not session or not session.open or session.mode == mode then return end
  session.mode = mode
  pushControls()
  refreshHud()
end

local function toggleSpace()
  if not session or not session.open or not once('space') then return end
  session.space = session.space == 'local' and 'world' or 'local'
  pushControls()
  refreshHud()
end

local function toggleSnap()
  if not session or not session.open or not once('snap') then return end
  session.snap = not session.snap
  pushControls()
  refreshHud()
end

local function snapToGround()
  if not session or not session.open or not once('ground') then return end
  if not DoesEntityExist(session.entity) then return end
  groundEntity(session.entity)
  clampOrigin(session.entity)
  pushEntity()
  refreshHud()
end

local function closeSession(cancelled)
  if not session or not session.open then return end
  session.cancelled = cancelled
  session.open = false
end

local function updateOrbit(entity)
  local pivot = pivotOf(entity)
  if not session.dragging then
    session.camTarget = session.camTarget + (pivot - session.camTarget) * 0.18
  end

  local position = session.camTarget + sphericalToCartesian(session.radius, session.theta, session.phi)
  SetCamCoord(session.cam, position.x, position.y, position.z)
  PointCamAtCoord(session.cam, session.camTarget.x, session.camTarget.y, session.camTarget.z)
end

local function destroyOrbitCam()
  local cam = session and session.cam
  if not cam then return end
  local blend = settings.Orbit.Blend
  session.cam = nil
  RenderScriptCams(false, true, blend, true, true)
  CreateThread(function()
    Wait(blend)
    if DoesCamExist(cam) then
      DestroyCam(cam, false)
    end
  end)
end

local function sendCamera()
  SendNUIMessage({
    action = 'setCamera',
    data = {
      position = packVec(GetFinalRenderedCamCoord()),
      forward = packVec(rotationToDirection(GetFinalRenderedCamRot(2))),
      fov = GetFinalRenderedCamFov()
    }
  })
end

local function disableFrameControls()
  for i = 1, #BLOCKED_CONTROLS do
    DisableControlAction(0, BLOCKED_CONTROLS[i], true)
  end
  DisablePlayerFiring(PlayerId(), true)
end

local function restoreSnapshot(entity)
  local snap = session.snapshot
  SetEntityCoordsNoOffset(entity, snap.coords.x, snap.coords.y, snap.coords.z, false, false, false)
  SetEntityRotation(entity, snap.rotation.x, snap.rotation.y, snap.rotation.z, 2, true)
end

local function cleanup()
  if not session then return end

  local entity = session.entity
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ action = 'close' })
  hud.hide()
  destroyOrbitCam()

  if DoesEntityExist(entity) then
    SetEntityDrawOutline(entity, false)
    FreezeEntityPosition(entity, session.entityFrozen)
  end
end

local function applyMove(data)
  local entity = session.entity
  if not DoesEntityExist(entity) or type(data.position) ~= 'table' or type(data.rotation) ~= 'table' then
    return false
  end

  local pivot = vector3(data.position.x + 0.0, data.position.y + 0.0, data.position.z + 0.0)

  SetEntityCoordsNoOffset(entity, pivot.x, pivot.y, pivot.z, false, false, false)
  SetEntityRotation(entity, data.rotation.x + 0.0, data.rotation.y + 0.0, data.rotation.z + 0.0, 2, true)

  local center = session.center
  local worldCenter = GetOffsetFromEntityInWorldCoords(entity, center.x, center.y, center.z)
  local coords = GetEntityCoords(entity)
  SetEntityCoordsNoOffset(entity,
    coords.x + (pivot.x - worldCenter.x),
    coords.y + (pivot.y - worldCenter.y),
    coords.z + (pivot.z - worldCenter.z),
    false, false, false
  )

  return clampOrigin(entity)
end

local function useGizmo(entity, options)
  options = options or {}

  if session or not entity or not DoesEntityExist(entity) then
    return { handle = entity, cancelled = true, confirmed = false }
  end

  local min, max = GetModelDimensions(GetEntityModel(entity))
  local startCoords = GetEntityCoords(entity)
  local orbit = settings.Orbit

  session = {
    open = true,
    cancelled = false,
    entity = entity,
    label = options.label or Strings.object,
    center = vector3((min.x + max.x) * 0.5, (min.y + max.y) * 0.5, (min.z + max.z) * 0.5),
    mode = settings.Mode,
    space = settings.Space,
    snap = false,
    distanceLimit = options.distanceLimit or settings.DistanceLimit,
    limitOrigin = options.origin or startCoords,
    snapshot = { coords = startCoords, rotation = GetEntityRotation(entity, 2) },
    entityFrozen = IsEntityPositionFrozen(entity),
    limited = false,
    dragging = false,
    confirmArmed = false,
    cancelArmed = false
  }

  FreezeEntityPosition(entity, true)

  local color = settings.OutlineColor
  SetEntityDrawOutlineColor(color.r, color.g, color.b, color.a)
  SetEntityDrawOutlineShader(settings.OutlineShader)
  SetEntityDrawOutline(entity, true)

  local pivot = pivotOf(entity)
  local offset = GetGameplayCamCoord() - pivot
  local radius, theta, phi = cartesianToSpherical(offset.x, offset.y, offset.z)
  session.radius = clamp(radius, orbit.MinRadius, orbit.MaxRadius)
  session.theta = theta
  session.phi = clamp(phi, 0.12, math.pi - 0.12)
  session.camTarget = pivot
  session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamFov(session.cam, GetGameplayCamFov())
  updateOrbit(entity)
  SetCamActive(session.cam, true)
  RenderScriptCams(true, true, orbit.Blend, true, true)

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(true)
  SendNUIMessage({
    action = 'open',
    data = {
      handle = entity,
      position = packVec(pivot),
      rotation = packVec(GetEntityRotation(entity, 2)),
      scale = { x = 1.0, y = 1.0, z = 1.0 },
      mode = session.mode,
      space = session.space,
      translationSnap = 0,
      rotationSnap = 0,
      scaleSnap = 0,
      size = settings.Size,
      cursor = true,
      camera = 'orbit'
    }
  })

  refreshHud()

  local nextHud = 0
  local ok, err = pcall(function()
    while session and session.open do
      if not DoesEntityExist(entity) then
        session.cancelled = true
        session.open = false
        break
      end

      disableFrameControls()

      if session.cam then
        updateOrbit(entity)
      end

      sendCamera()

      if not session.confirmArmed then
        if not (IsDisabledControlPressed(0, 18) or IsDisabledControlPressed(0, 191) or IsDisabledControlPressed(0, 201)
          or IsControlPressed(0, 18) or IsControlPressed(0, 191) or IsControlPressed(0, 201)) then
          session.confirmArmed = true
        end
      end

      if not session.cancelArmed then
        if not (IsDisabledControlPressed(0, 200) or IsDisabledControlPressed(0, 202)
          or IsControlPressed(0, 200) or IsControlPressed(0, 202)) then
          session.cancelArmed = true
        end
      end

      local now = GetGameTimer()
      if now >= nextHud then
        nextHud = now + 200
        refreshHud()
      end

      Wait(0)
    end
  end)

  if not ok then
    print(('[zyrnex_gizmo] %s'):format(err))
    if session then
      session.cancelled = true
      session.open = false
    end
  end

  if not session then
    return { handle = entity, cancelled = true, confirmed = false }
  end

  if session.cancelled and DoesEntityExist(entity) then
    restoreSnapshot(entity)
  end

  local result = makeResult()
  cleanup()
  session = nil
  return result
end

exports('useGizmo', useGizmo)
exports('groundEntity', groundEntity)

exports('isActive', function()
  return session ~= nil
end)

exports('cancel', function()
  closeSession(true)
end)

RegisterNUICallback('moveEntity', function(data, cb)
  if not session or not session.open or data.handle ~= session.entity then
    return cb({ ok = false })
  end

  if not applyMove(data) then
    return cb({ ok = true, clamped = false })
  end

  cb({
    ok = true,
    clamped = true,
    position = packVec(pivotOf(session.entity)),
    rotation = packVec(GetEntityRotation(session.entity, 2))
  })
end)

RegisterNUICallback('setDragging', function(data, cb)
  if session then
    session.dragging = data.dragging and true or false
  end
  cb({ ok = true })
end)

RegisterNUICallback('rotateCamera', function(data, cb)
  if session and session.open and not session.dragging then
    local sensitivity = settings.Orbit.Sensitivity
    session.theta = session.theta - (tonumber(data.x) or 0.0) * sensitivity
    session.phi = clamp(session.phi - (tonumber(data.y) or 0.0) * sensitivity, 0.12, math.pi - 0.12)
  end
  cb({ ok = true })
end)

RegisterNUICallback('zoomCamera', function(data, cb)
  if session and session.open then
    local orbit = settings.Orbit
    local delta = tonumber(data.delta) or 0.0
    if delta > 0 then
      session.radius = session.radius + orbit.ZoomStep
    elseif delta < 0 then
      session.radius = session.radius - orbit.ZoomStep
    end
    session.radius = clamp(session.radius, orbit.MinRadius, orbit.MaxRadius)
  end
  cb({ ok = true })
end)

RegisterNUICallback('key', function(data, cb)
  cb({ ok = true })
  if not session or not session.open or IsPauseMenuActive() or type(data.code) ~= 'string' then return end

  local code = data.code
  if code == 'Escape' then
    if session.cancelArmed then closeSession(true) end
  elseif code == 'Enter' or code == 'NumpadEnter' then
    if session.confirmArmed then closeSession(false) end
  elseif code == 'KeyW' then
    setMode('translate')
  elseif code == 'KeyR' then
    setMode('rotate')
  elseif code == 'KeyQ' then
    toggleSpace()
  elseif code == 'AltLeft' then
    snapToGround()
  elseif code == 'KeyX' then
    toggleSnap()
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() or not session then return end
  session.open = false
  cleanup()
  session = nil
end)
