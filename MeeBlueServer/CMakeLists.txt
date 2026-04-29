cmake_minimum_required(VERSION 3.16)

project(MeeBlueServer VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick WebSockets Core Network)

qt_standard_project_setup(REQUIRES 6.8)

set(CMAKE_AUTORCC ON) #NB! without this resources are not included

qt_add_executable(appMeeBlueServer
    main.cpp
)

qt_add_qml_module(appMeeBlueServer
    URI MeeBlueServer
    VERSION 1.0
    QML_FILES
        Main.qml
    SOURCES
        osclient.h osclient.cpp
        qosc/QOsc_global.h
        qosc/qosctypes.h qosc/qosctypes.cpp
        qosc/qoscclient.h qosc/qoscclient.cpp
        qosc/qoscserver.h qosc/qoscserver.cpp
        RESOURCES resources.qrc
)

# not sure if this is needed...
qt_add_resources(appMeeBlueServer "conf"
    PREFIX "/"
    FILES qtquickcontrols2.conf
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appMeeBlueServer PROPERTIES
    #MACOSX_BUNDLE_GUI_IDENTIFIER org.tarmoj.appMeeBlueServer
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appMeeBlueServer PRIVATE
    Qt6::Quick
    Qt6::WebSockets
    Qt6::Core
    Qt6::Network
)

if (APPLE)

    set(MACOSX_BUNDLE_GUI_IDENTIFIER "org.tarmoj.meeblueserver")
    set(MACOSX_BUNDLE_BUNDLE_NAME "Meeblue Server")

    # Copy M.png into the macOS bundle Resources and declare it as the icon
    target_sources(appMeeBlueServer PRIVATE "${CMAKE_SOURCE_DIR}/images/M.png")
    set_source_files_properties("${CMAKE_SOURCE_DIR}/images/M.png" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )
    set_target_properties(appMeeBlueServer PROPERTIES
        MACOSX_BUNDLE_ICON_FILE M
    )

endif()

include(GNUInstallDirs)
install(TARGETS appMeeBlueServer
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
