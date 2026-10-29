# zyrnex_gizmo

3D gizmo to move and rotate objects in FiveM with an orbit camera. It's the editor used by **zyrnex_housing** to place furniture, and you can use it in any resource.

Based on [object_gizmo](https://github.com/DemiAutomatic/object_gizmo) by DemiAutomatic (GPL-3.0). See [CHANGES.md](CHANGES.md) for what changed.

## Controls

| Key | Action |
|---|---|
| `W` | Move |
| `R` | Rotate |
| `Q` | Object or world axes |
| `Alt` | Drop to the ground |
| `X` | Snap on or off |
| Drag / wheel | Orbit and zoom the camera |
| `Enter` | Place |
| `Esc` | Cancel |

## Usage

```lua
local result = exports.zyrnex_gizmo:useGizmo(entity, { label = 'Sofa', origin = GetEntityCoords(PlayerPedId()) })

if result.confirmed then
    print(result.position, result.rotation)
end
```

| Export | What it does |
|---|---|
| `useGizmo(entity, options)` | Opens the editor and waits until the player places or cancels. Returns `{ confirmed, cancelled, position, rotation, handle }`. `options.label` is shown on screen, `options.origin` and `options.distanceLimit` limit how far the object can go |
| `groundEntity(entity)` | Puts the object on the ground with a raycast from its real base |
| `isActive()` | `true` while the editor is open |
| `cancel()` | Closes the editor and restores the object |

Settings and texts (English and Spanish) are in `config.lua`.

## License

[GPL-3.0](LICENSE), same as the original. The source of the web part is in `web/src`.
