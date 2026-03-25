local structureConfig = {}

structureConfig.types = {
    iceWall = {
        name = "iceWall",
        temperature = 1,
        humidity = 7,
        integrity = 256,
    },
    dirtWall = {
        name = "dirtWall",
        temperature = 4,
        humidity = 4,
        integrity = 256,
    },
    rockWall = {
        name = "rockWall",
        temperature = 7,
        humidity = 1,
        integrity = 256,
    },
}

return structureConfig
