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
add_subdirectory(Sources/App)

include(FetchContent)
FetchContent_Declare(QtBridge
    GIT_REPOSITORY https://github.com/0xZaph/qtbridge-swift.git
    GIT_TAG hooks
)
FetchContent_MakeAvailable(QtBridge)