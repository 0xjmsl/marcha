cmake_minimum_required(VERSION 3.10)
project(marcha_native)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add source files
add_library(marcha_native SHARED
    startup_manager.cpp
    virtual_desktop_manager.cpp
    process_manager.cpp
)

# Link Windows APIs
target_link_libraries(marcha_native
    user32
    kernel32
    shell32
    advapi32
)

# Set output directory
set_target_properties(marcha_native PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# Export symbols for FFI
set_target_properties(marcha_native PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)