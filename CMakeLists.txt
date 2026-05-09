cmake_minimum_required(VERSION 3.29)
project(relic LANGUAGES CXX Swift)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Widgets QuickControls2 Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Kirigami I18n CoreAddons IconThemes)

add_subdirectory(KirigamiSupport)

include(FetchContent)
FetchContent_Declare(QtBridge
    GIT_REPOSITORY https://github.com/0xZaph/qtbridge-swift.git
    GIT_TAG hooks
)
FetchContent_MakeAvailable(QtBridge)

add_executable(relic
    Sources/App.swift
)

target_link_libraries(relic
    PRIVATE
        QtBridge
        KirigamiSupport
)

target_compile_options(relic PRIVATE 
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
    "$<$<COMPILE_LANGUAGE:Swift>:-parse-as-library>"
)

set(MAIN_QML_FILE "${CMAKE_CURRENT_SOURCE_DIR}/Resources/main.qml")

if(APPLE)
    set_target_properties(relic PROPERTIES
        MACOSX_BUNDLE TRUE
    )
    target_sources(relic PRIVATE "${MAIN_QML_FILE}")
    set_source_files_properties("${MAIN_QML_FILE}" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )
else()
    add_custom_command(
        TARGET relic POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            "${MAIN_QML_FILE}"
            "$<TARGET_FILE_DIR:relic>/main.qml"
        COMMENT "Copying QML file next to executable"
    )
endif()