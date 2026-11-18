QT += qml
QT -= gui
TEMPLATE = lib
CONFIG += plugin c++17 release
CONFIG -= debug
TARGET = workspace_switcher_native
SOURCES += $$PWD/coreplugin.cpp
isEmpty(RUST_TARGET_DIR): error(Build the native module using bin/build)
INCLUDEPATH += $$RUST_TARGET_DIR/cxxbridge
LIBS += $$RUST_TARGET_DIR/release/libworkspace_switcher_native.a -ldl -lpthread -lm
PRE_TARGETDEPS += $$RUST_TARGET_DIR/release/libworkspace_switcher_native.a
DESTDIR = $$PWD
