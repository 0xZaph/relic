cmake_minimum_required(VERSION 3.29)
project(relic LANGUAGES CXX Swift)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Widgets QuickControls2 Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Kirigami I18n CoreAddons IconThemes)
find_package(Python3 REQUIRED)

add_subdirectory(Sources/KirigamiSupport)
add_subdirectory(Sources/EpicKit)
add_subdirectory(Sources/LegendaryKit)

set(QML_FILES
    ${CMAKE_SOURCE_DIR}/Resources/MainWindow.qml
    ${CMAKE_SOURCE_DIR}/Resources/ProfilePage.qml
    ${CMAKE_SOURCE_DIR}/Resources/LibraryPage.qml
    ${CMAKE_SOURCE_DIR}/Resources/AboutPage.qml
)

add_subdirectory(Sources/App)

if(APPLE)
    set_target_properties(relic PROPERTIES
        MACOSX_BUNDLE TRUE
    )
    target_sources(relic PRIVATE ${QML_FILES})
    foreach(qml ${QML_FILES})
        set_source_files_properties(${qml} PROPERTIES
            MACOSX_PACKAGE_LOCATION Resources
        )
    endforeach()
else()
    foreach(qml ${QML_FILES})
        add_custom_command(
            TARGET relic POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
                "${qml}"
                "$<TARGET_FILE_DIR:relic>/"
            COMMENT "Copying QML file next to executable"
        )
    endforeach()
endif()

include(FetchContent)
FetchContent_Declare(QtBridge
    GIT_REPOSITORY https://github.com/0xZaph/qtbridge-swift.git
    GIT_TAG hooks
)
FetchContent_MakeAvailable(QtBridge)