cmake_minimum_required(VERSION 3.16)
project(omp-config VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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