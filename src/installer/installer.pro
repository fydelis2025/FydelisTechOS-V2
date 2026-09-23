# ==========================================
# FYDELIS TECH OS — INSTALADOR
# De Salvador • Bahia 🇧🇷
# Compila: Windows + Linux
# ==========================================

QT       += core gui widgets sql
CONFIG   += c++17 c++20
DEFINES  += QT_NO_DEPRECATED_WARNINGS

TARGET = FydelisInstaller
TEMPLATE = app

# ==========================================
# 🎨 Ícone e Recursos
# ==========================================
win32 {
    RC_ICONS = ../assets/images/logo.ico
}

RESOURCES += resources.qrc

# ==========================================
# 📂 Caminhos de inclusão
# ==========================================
INCLUDEPATH += $$PWD/../core \
               $$PWD/../core/auth

# ==========================================
# 🚀 Arquivos Fonte
# ==========================================
SOURCES += \
    main.cpp \
    installwizard.cpp \
    slideshow.cpp \
    partitionmanager.cpp \
    pages/bemvindopage.cpp \
    pages/idiomapage.cpp \
    pages/discopartpage.cpp \
    pages/userpage.cpp \
    pages/resumopage.cpp \
    pages/installpage.cpp \
    pages/conclupage.cpp

# ==========================================
# 📝 Cabeçalhos
# ==========================================
HEADERS += \
    installwizard.h \
    slideshow.h \
    partitionmanager.h \
    pages/bemvindopage.h \
    pages/idiomapage.h \
    pages/discopartpage.h \
    pages/userpage.h \
    pages/resumopage.h \
    pages/installpage.h \
    pages/conclupage.h

# ==========================================
# ✅ Avisos do compilador
# ==========================================
QMAKE_CXXFLAGS += -Wall -Wextra

# ==========================================
# 📦 Saída do executável
# ==========================================
DESTDIR = $$OUT_PWD/../../bin