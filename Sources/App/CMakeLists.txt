
# QML resources to bundle
set(QML_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Resources/MainWindow.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Resources/ProfilePage.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Resources/LibraryPage.qml
)

set(RESOURCE_FILES
    ${QML_FILES}
    "Resources/icons/epic-games-logo.svg"
)

add_executable(relic
    App.swift
    AppViewModel.swift
    UserViewModel.swift
    LibraryViewModel.swift
    ${QML_FILES}
)

target_link_libraries(relic
    PRIVATE
        QtBridge
        KirigamiSupport
        EpicKit
        LegendaryKit
)

target_compile_options(relic PRIVATE 
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
    "$<$<COMPILE_LANGUAGE:Swift>:-parse-as-library>"
)


if(APPLE)
    set_target_properties(relic PROPERTIES
        MACOSX_BUNDLE TRUE
    )
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
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    # macOS: Install inside the .app bundle
    set(LEGENDARY_DEST_DIR "$<TARGET_BUNDLE_CONTENT_DIR:relic>/Resources/bin")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    # Windows: Install next to the executable
    set(LEGENDARY_DEST_DIR "$<TARGET_FILE_DIR:relic>/bin")
else()
    # Linux: Install in a bin subdirectory
    set(LEGENDARY_DEST_DIR "$<TARGET_FILE_DIR:relic>/bin")
endif()

add_custom_command(TARGET relic PRE_BUILD
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/fetch_legendary.py "${LEGENDARY_DEST_DIR}"
    COMMENT "Downloading legendary binary for current platform"
    VERBATIM
)
