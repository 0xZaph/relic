add_executable(relic
    App.swift
    AppViewModel.swift
    UserViewModel.swift
    LibraryViewModel.swift
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

set(MAIN_QML_FILE "${CMAKE_SOURCE_DIR}/Resources/main.qml")

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
