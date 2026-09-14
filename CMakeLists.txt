cmake_minimum_required(VERSION 3.16)
project(omp-config VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml Network)

qt_standard_project_setup()

qt_add_executable(omp-config
    src/main.cpp
    src/yamlstore.h
    src/yamlstore.cpp
    src/yamlrewrite.h
    src/yamlrewrite.cpp
    src/ompconfigbackend.h
    src/ompconfigbackend.cpp
    src/icons/icons.qrc
)

qt_add_qml_module(omp-config
    URI ompconfig
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
)

target_link_libraries(omp-config PRIVATE Qt6::Quick Qt6::Qml Qt6::Network)

set_target_properties(omp-config PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

# ---- 安装 & 打包(CPack DEB) ----
install(TARGETS omp-config RUNTIME DESTINATION bin)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/ompconfig
        DESTINATION lib/omp-config/qml)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/packaging/omp-config.desktop
        DESTINATION share/applications)
install(FILES src/icons/pi.png
        DESTINATION share/icons/hicolor/256x256/apps RENAME omp-config.png)
install(FILES src/icons/pi@2x.png
        DESTINATION share/icons/hicolor/512x512/apps RENAME omp-config.png)

set(CPACK_PACKAGE_NAME            omp-config)
set(CPACK_PACKAGE_VENDOR          "ut000427")
set(CPACK_PACKAGE_CONTACT         "ut000427 <ut000427@uos>")
set(CPACK_PACKAGE_VERSION         ${PROJECT_VERSION})
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "omp (Oh My Pi) configuration GUI")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
include(CPack)