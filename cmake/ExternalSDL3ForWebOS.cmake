# webOS UI still calls SDL2 (LVGL 8). sdl2-compat is that API on top of SDL3,
# so the TV runs webosbrew's SDL 3.4.16 (Steam Controller HID, newer gamepad
# path) without a second UI stack. sdl2-compat dlopens libSDL3.so.0 from the
# same directory as itself, which is why both land in lib/backports.

if (POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif ()

include(ExternalProject)

set(EXT_SDL3_TOOLCHAIN_ARGS)
if (CMAKE_TOOLCHAIN_FILE)
    list(APPEND EXT_SDL3_TOOLCHAIN_ARGS "-DCMAKE_TOOLCHAIN_FILE:string=${CMAKE_TOOLCHAIN_FILE}")
endif ()
if (CMAKE_TOOLCHAIN_ARGS)
    list(APPEND EXT_SDL3_TOOLCHAIN_ARGS "-DCMAKE_TOOLCHAIN_ARGS:string=${CMAKE_TOOLCHAIN_ARGS}")
endif ()

set(SDL3_WEBOS_RELEASE "release-3.4.16-webos.5")
set(SDL3_WEBOS_ARCHIVE "SDL3-3.4.16-webos.5.tar.gz")
set(SDL2COMPAT_GIT_TAG "release-2.32.74")
# Private SONAME. Aurora's shim occupies libSDL2-2.0.so.0 and forwards NDL to this SDL3.
set(LIB_FILENAME "libSDL2-webos.so.0")

if (CMAKE_BUILD_TYPE STREQUAL "Release")
    set(EXT_SDL2COMPAT_BUILD_TYPE "Release")
else ()
    set(EXT_SDL2COMPAT_BUILD_TYPE "RelWithDebInfo")
endif ()

ExternalProject_Add(ext_sdl3_webos
        URL "https://github.com/webosbrew/SDL-webOS/releases/download/${SDL3_WEBOS_RELEASE}/${SDL3_WEBOS_ARCHIVE}"
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <INSTALL_DIR>
        BUILD_BYPRODUCTS <INSTALL_DIR>/lib/libSDL3.so.0.4.16
)

ExternalProject_Get_Property(ext_sdl3_webos INSTALL_DIR)
set(SDL3_WEBOS_PREFIX "${INSTALL_DIR}")

ExternalProject_Add(ext_sdl2_compat
        GIT_REPOSITORY "https://github.com/libsdl-org/sdl2-compat.git"
        GIT_TAG "${SDL2COMPAT_GIT_TAG}"
        GIT_SHALLOW TRUE
        UPDATE_COMMAND ""
        PATCH_COMMAND patch -p1 -N -i "${CMAKE_SOURCE_DIR}/scripts/webos/sdl2-compat-webos-scancode.patch"
        COMMAND patch -p1 -N -i "${CMAKE_SOURCE_DIR}/scripts/webos/sdl2-compat-private-soname.patch"
        DEPENDS ext_sdl3_webos
        CMAKE_ARGS ${EXT_SDL3_TOOLCHAIN_ARGS}
        -DCMAKE_BUILD_TYPE:string=${EXT_SDL2COMPAT_BUILD_TYPE}
        -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
        -DCMAKE_INSTALL_LIBDIR:string=lib
        -DSDL2COMPAT_TESTS:BOOL=OFF
        -DSDL2COMPAT_INSTALL:BOOL=ON
        -DSDL2COMPAT_INSTALL_CPACK:BOOL=OFF
        -DSDL2COMPAT_STATIC:BOOL=OFF
        -DSDL2COMPAT_WERROR:BOOL=OFF
        -DSDL2COMPAT_X11:BOOL=OFF
        -DSDL2COMPAT_VENDOR_INFO:string=webOS\ SDL3
        "-DSDL3_INCLUDE_DIRS:PATH=${SDL3_WEBOS_PREFIX}/include"
        BUILD_BYPRODUCTS <INSTALL_DIR>/lib/${LIB_FILENAME}
        INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR>
        COMMAND ${CMAKE_COMMAND} -E copy "${SDL3_WEBOS_PREFIX}/lib/libSDL3.so.0.4.16" <INSTALL_DIR>/lib/libSDL3.so.0
)

ExternalProject_Get_Property(ext_sdl2_compat INSTALL_DIR)

add_library(ext_sdl2_backport_target SHARED IMPORTED)
set_target_properties(ext_sdl2_backport_target PROPERTIES IMPORTED_LOCATION ${INSTALL_DIR}/lib/${LIB_FILENAME})
target_compile_definitions(ext_sdl2_backport_target INTERFACE __WEBOS__)
add_dependencies(ext_sdl2_backport_target ext_sdl2_compat)

set(SDL2_INCLUDE_DIRS ${INSTALL_DIR}/include/SDL2)
set(SDL2_LIBRARIES ext_sdl2_backport_target)
set(SDL2_FOUND TRUE)

if (NOT DEFINED CMAKE_INSTALL_LIBDIR)
    set(CMAKE_INSTALL_LIBDIR lib)
endif ()

install(DIRECTORY ${INSTALL_DIR}/lib/ DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PATTERN "include" EXCLUDE PATTERN "bin" EXCLUDE PATTERN "share" EXCLUDE
        PATTERN "pkgconfig" EXCLUDE PATTERN "cmake" EXCLUDE PATTERN "*.a" EXCLUDE)
