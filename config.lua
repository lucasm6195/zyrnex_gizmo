Config = {
    Locale = 'en',
    OutlineColor = { r = 255, g = 255, b = 255, a = 255 },
    OutlineShader = 0,
    Size = 0.5,
    Mode = 'translate',
    Space = 'world',
    TranslationSnap = 0.25,
    RotationSnap = 15,
    DistanceLimit = 12.0,
    Orbit = {
        MinRadius = 1.0,
        MaxRadius = 10.0,
        ZoomStep = 0.5,
        Sensitivity = 0.005,
        Blend = 250
    }
}

local locales = {
    en = {
        object = 'Object',
        move = 'Move',
        rotate = 'Rotate',
        tooFar = 'Too far',
        localAxes = 'Object axes',
        worldAxes = 'World axes',
        ground = 'To the ground',
        snapOn = 'Snap on',
        snapOff = 'Snap off',
        drag = 'Drag',
        camera = 'Camera',
        place = 'Place',
        cancel = 'Cancel'
    },
    es = {
        object = 'Objeto',
        move = 'Mover',
        rotate = 'Rotar',
        tooFar = 'Demasiado lejos',
        localAxes = 'Ejes del objeto',
        worldAxes = 'Ejes del mundo',
        ground = 'Al suelo',
        snapOn = 'Ajuste activado',
        snapOff = 'Ajuste desactivado',
        drag = 'Arrastrar',
        camera = 'Cámara',
        place = 'Colocar',
        cancel = 'Cancelar'
    }
}

Strings = locales[Config.Locale] or locales.en
