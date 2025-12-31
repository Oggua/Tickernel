cmake_minimum_required(VERSION 3.26)
project(TickernelEngine LANGUAGES C)

# Dependencies
find_package(Vulkan REQUIRED)

# Add subdirectories
add_subdirectory(freetype)
add_subdirectory(cglm)
set(SPIRV_REFLECT_STATIC_LIB ON CACHE BOOL "Build SPIRV-Reflect static library" FORCE)
set(SPIRV_REFLECT_EXECUTABLE OFF CACHE BOOL "Build spirv-reflect executable" FORCE)
add_subdirectory(spirv_reflect)
add_subdirectory(tkn)
add_subdirectory(lua)

# Create an umbrella target that depends on all sub-projects
add_custom_target(${PROJECT_NAME} ALL)
add_dependencies(${PROJECT_NAME} Tickernel TickernelLua)

## Compile shaders
message(CMAKE_BINARY_DIR "${CMAKE_BINARY_DIR}")
find_program(GLSLC glslc REQUIRED)
set(SHADER_SOURCE_DIR ${CMAKE_SOURCE_DIR}/res/glsl)
set(SHADER_OUTPUT_DIR ${CMAKE_SOURCE_DIR}/assets/shaders)
file(MAKE_DIRECTORY ${SHADER_OUTPUT_DIR})
file(GLOB_RECURSE SHADER_FILES ${SHADER_SOURCE_DIR}/*.vert ${SHADER_SOURCE_DIR}/*.frag)
set(SPIRV_BINARIES)
foreach(SHADER ${SHADER_FILES})
    get_filename_component(SHADER_NAME ${SHADER} NAME)
    set(SPIRV ${SHADER_OUTPUT_DIR}/${SHADER_NAME}.spv)
    add_custom_command(
        OUTPUT ${SPIRV}
        COMMAND ${GLSLC} ${SHADER} -o ${SPIRV}
        MAIN_DEPENDENCY ${SHADER}
        COMMENT "Compiling shader: ${SHADER_NAME}"
        VERBATIM
    )
    list(APPEND SPIRV_BINARIES ${SPIRV})
endforeach()

if(SHADER_FILES)
    add_custom_target(CompileShaders DEPENDS ${SPIRV_BINARIES})
    add_dependencies(${PROJECT_NAME} CompileShaders)
    message(STATUS "Shader compilation target created")
else()
    message(STATUS "No shaders found to compile")
endif()

## Compress textures
find_program(ASTCENC astcenc)
if(ASTCENC)
    set(TEXTURE_SOURCE_DIR ${CMAKE_SOURCE_DIR}/res/textures)
    set(TEXTURE_OUTPUT_DIR ${CMAKE_SOURCE_DIR}/assets/textures)
    file(MAKE_DIRECTORY ${TEXTURE_OUTPUT_DIR})

    file(GLOB_RECURSE TEXTURE_FILES
        ${TEXTURE_SOURCE_DIR}/*.png
        ${TEXTURE_SOURCE_DIR}/*.jpg
        ${TEXTURE_SOURCE_DIR}/*.jpeg
        ${TEXTURE_SOURCE_DIR}/*.tga
        ${TEXTURE_SOURCE_DIR}/*.bmp
    )

    set(ASTC_TEXTURES)
message(${ASTCENC}~)

    foreach(TEXTURE ${TEXTURE_FILES})
        get_filename_component(TEXTURE_NAME_WE ${TEXTURE} NAME_WE)
        get_filename_component(TEXTURE_DIR ${TEXTURE} DIRECTORY)
        string(REPLACE "${TEXTURE_SOURCE_DIR}" "" RELATIVE_DIR ${TEXTURE_DIR})
        set(OUTPUT_DIR "${TEXTURE_OUTPUT_DIR}${RELATIVE_DIR}")
        file(MAKE_DIRECTORY ${OUTPUT_DIR})

        set(ASTC_OUTPUT "${OUTPUT_DIR}/${TEXTURE_NAME_WE}.astc")

        add_custom_command(
            OUTPUT ${ASTC_OUTPUT}
            # -fastest      : 2
            # -fast         : 3
            # -medium       : 3
            # -thorough     : 4
            # -verythorough : 6
            # -exhaustive   : 8
            COMMAND ${ASTCENC} -cl ${TEXTURE} ${ASTC_OUTPUT} 6x6 -thorough
            MAIN_DEPENDENCY ${TEXTURE}
            COMMENT "Compressing texture: ${TEXTURE_NAME_WE}"
            VERBATIM
        )

        list(APPEND ASTC_TEXTURES ${ASTC_OUTPUT})
    endforeach()

    if(TEXTURE_FILES)
        add_custom_target(CompressTextures DEPENDS ${ASTC_TEXTURES})
        add_dependencies(${PROJECT_NAME} CompressTextures)
        message(STATUS "Texture compression target created")
    else()
        message(STATUS "No textures found to compress")
    endif()
else()
    message(WARNING "ASTC encoder not found - ASTC texture compression disabled")
endif()
