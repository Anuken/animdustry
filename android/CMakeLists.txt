cmake_minimum_required(VERSION 3.4.1)

# build native_app_glue as a static lib
set(${CMAKE_C_FLAGS}, "${CMAKE_C_FLAGS}")
add_library(native_app_glue STATIC
    ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c)

# now build app's shared lib
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++11")

# Export ANativeActivity_onCreate(),
# Refer to: https://github.com/android-ndk/ndk/issues/381.
set(CMAKE_SHARED_LINKER_FLAGS
    "${CMAKE_SHARED_LINKER_FLAGS} -v -u ANativeActivity_onCreate")

file(GLOB SOURCES "*.c")

if(${ANDROID_ABI} STREQUAL "arm64-v8a" OR ${ANDROID_ABI} STREQUAL "x86_64")
 add_library(animdustry SHARED
 ${NIM_SOURCES_64}
 )
else()
 add_library(animdustry SHARED
 ${NIM_SOURCES_32}
 )
endif()

target_include_directories(animdustry PRIVATE
${ANDROID_NDK}/sources/android/native_app_glue
${NIM_INCLUDE_DIR}
)

set(CMAKE_CXX_FLAGS "-O3 -DSOLOUD_OGG_ONLY -DWITH_MINIAUDIO -D__ANDROID__ -flto")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DSOLOUD_OGG_ONLY -DWITH_MINIAUDIO -D__ANDROID__ -flto")

# add lib dependencies
target_link_libraries(animdustry
    android
    native_app_glue
    EGL
    GLESv2
    log
    )



