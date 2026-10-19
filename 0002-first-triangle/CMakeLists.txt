cmake_minimum_required(VERSION 3.28)

project(first-triangle-cpp LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Minimum macOS version")

option(ENABLE_SANITIZERS "Build with AddressSanitizer and UndefinedBehaviorSanitizer" OFF)

find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)

function(add_macos_gui_app target source)
    add_executable(${target} ${source})
    target_compile_options(${target} PRIVATE
        -fobjc-arc
        -Wall
        -Wextra
        -Wpedantic
        -Werror
        -Wshadow
        -Wformat=2
    )
    if(ENABLE_SANITIZERS)
        target_compile_options(${target} PRIVATE
            -fsanitize=address,undefined
            -fno-omit-frame-pointer
        )
        target_link_options(${target} PRIVATE
            -fsanitize=address,undefined
        )
    endif()
endfunction()

add_macos_gui_app(cpp-metal-triangle cpp-metal/src/main.mm)
target_link_libraries(cpp-metal-triangle PRIVATE
    ${COCOA_FRAMEWORK}
    ${COREGRAPHICS_FRAMEWORK}
    ${METAL_FRAMEWORK}
    ${QUARTZCORE_FRAMEWORK}
)
