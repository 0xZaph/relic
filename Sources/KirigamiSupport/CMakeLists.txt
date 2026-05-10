add_library(KirigamiSupport STATIC KirigamiSupport.cpp)

target_link_libraries(KirigamiSupport
    PUBLIC
        Qt6::Widgets
        Qt6::QuickControls2
        KF6::Kirigami
        KF6::I18n
        KF6::CoreAddons
        KF6::IconThemes
        Qt6::Qml
        Qt6::Network
)

target_include_directories(KirigamiSupport
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)