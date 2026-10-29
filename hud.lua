GizmoHud = {}

local signature

function GizmoHud.draw(state)
  local key = ('%s|%s|%s|%s|%s'):format(state.label, state.mode, state.space, state.snap, state.limited)
  if key == signature then return end
  signature = key

  local mode = state.mode == 'rotate' and Strings.rotate or Strings.move
  local main = ('%s · %s'):format(state.label, mode)
  if state.limited then
    main = ('%s · %s'):format(main, Strings.tooFar)
  end

  SendNUIMessage({
    action = 'hint',
    main = main,
    keys = {
      { 'W', Strings.move },
      { 'R', Strings.rotate },
      { 'Q', state.space == 'local' and Strings.localAxes or Strings.worldAxes },
      { 'Alt', Strings.ground },
      { 'X', state.snap and Strings.snapOn or Strings.snapOff },
      { Strings.drag, Strings.camera },
      { 'Enter', Strings.place },
      { 'Esc', Strings.cancel }
    }
  })
end

function GizmoHud.hide()
  signature = nil
  SendNUIMessage({ action = 'hintHide' })
end
