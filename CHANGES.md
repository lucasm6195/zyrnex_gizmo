# Changes from object_gizmo

Based on https://github.com/DemiAutomatic/object_gizmo (commit b5a17cb, version 3.0.0), GPL-3.0.

- Orbit camera and move or rotate modes only. Scale, clipboard copy, boundary zones, peds, network control, global keybinds and the original locales were removed.
- Ground snapping uses a raycast that rests the real base of the model instead of `PlaceObjectOnGroundProperly_2`.
- `hud.lua` draws its own key hint bar instead of `client/modules/hud.lua`.
- Exports renamed to `useGizmo`, `groundEntity`, `isActive` and `cancel`.
- English and Spanish texts in `config.lua`.
- `web/src` is the original source without changes. `web/dist` is its build.
