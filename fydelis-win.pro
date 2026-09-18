# ==========================================
# FYDELIS TECH OS — PROJETO COMPLETO v2.0
# SQLCipher AES-256 · Salvador • Bahia 🇧🇷
# Compila Nativo: Windows + Linux
# ==========================================

# ✅ MÓDULOS QT
QT       += core gui widgets network multimedia sql
CONFIG   += c++17 c++20
DEFINES  += QT_NO_DEPRECATED_WARNINGS

TARGET = FydelisTechOS
TEMPLATE = app

# ==========================================
# 🔒 SQLCIPHER — CRIPTOGRAFIA AES-256
# ==========================================
INCLUDEPATH += $$PWD/3rdparty/sqlcipher

win32 {
    LIBS += -L$$PWD/lib -lsqlcipher -llibeay32 -lssleay32 -lws2_32
    DEFINES += SQLITE_HAS_CODEC SQLITE_TEMP_STORE=2
}

unix {
    LIBS += -L$$PWD/lib -lsqlcipher -lcrypto -ldl -lpthread
    DEFINES += SQLITE_HAS_CODEC SQLITE_TEMP_STORE=2
}

# ==========================================
# 📂 CAMINHOS DE CABEÇALHOS
# ==========================================
INCLUDEPATH += $$PWD/src \
               $$PWD/src/assets \
               $$PWD/src/boot \
               $$PWD/src/inc \
               $$PWD/src/kernel \
               $$PWD/src/core \
               $$PWD/src/core/auth \
               $$PWD/src/core/hardware \
               $$PWD/src/core/security        # 🛡️ Segurança
               $$PWD/src/core/services         # ⚙️ Serviços
               $$PWD/src/core/update           # 🔄 ATUALIZADOR
               $$PWD/src/ui \
               $$PWD/src/ui/splash \
               $$PWD/src/ui/login \
               $$PWD/src/ui/desktop \
               $$PWD/src/ui/controlpanel \
               $$PWD/src/ui/hardware \
               $$PWD/src/ui/services            # 🖥️ Painel Serviços
               $$PWD/src/ui/update              # 🖥️ ATUALIZADOR UI
               $$PWD/src/shell \
               $$PWD/src/shell/powershell \
               $$PWD/src/themes \
               $$PWD/src/installer \
               $$PWD/src/installer/pages

# ==========================================
# 🚀 ARQUIVOS FONTE — COMPLETO + UPDATE
# ==========================================
SOURCES += \
    src/core/main.cpp \
    src/core/securevault.cpp \
    src/core/configmanager.cpp \
    src/core/securitymanager.cpp \
    src/core/fsmap.cpp \
    src/core/thememanager.cpp \
    src/core/auth/usuario.cpp \
    src/core/auth/profilemanager.cpp \
    src/core/hardware/hardwaremanager.cpp \
    src/core/hardware/driverinstaller.cpp \
    \
    # 🛡️ SEGURANÇA — Firewall + Antivírus
    src/core/security/fydelisguard.cpp \
    src/core/security/fg_rules.cpp \
    src/core/security/fg_packet.cpp \
    src/core/security/fg_reputation.cpp \
    src/core/security/fydelisav.cpp \
    \
    # ⚙️ GERENCIADOR DE SERVIÇOS
    src/core/services/fydelisservices.cpp \
    src/core/services/servicemodel.cpp \
    \
    # 🔄 SISTEMA DE ATUALIZAÇÃO
    src/core/update/fydelisupdater.cpp \
    src/ui/update/updatepanel.cpp \
    \
    # 🖥️ INTERFACE
    src/ui/splash/splashscreen.cpp \
    src/ui/login/loginscreen.cpp \
    src/ui/desktop/desktop.cpp \
    src/ui/controlpanel.cpp \
    src/ui/fileexplorer.cpp \
    src/ui/hardware/hardwarepanel.cpp \
    src/ui/services/servicemanagerpanel.cpp \
    \
    # 💿 INSTALADOR
    src/installer/installwizard.cpp \
    src/installer/partitionmanager.cpp \
    src/installer/slideshow.cpp \
    src/installer/pages/bemvindopage.cpp \
    src/installer/pages/idiomapage.cpp \
    src/installer/pages/discopartpage.cpp \
    src/installer/pages/userpage.cpp \
    src/installer/pages/installpage.cpp \
    src/installer/pages/resumopage.cpp \
    src/installer/pages/conclupage.cpp

# ==========================================
# 📝 CABEÇALHOS (.h) — COMPLETO + UPDATE
# ==========================================
HEADERS += \
    src/core/securevault.h \
    src/core/configmanager.h \
    src/core/securitymanager.h \
    src/core/fsmap.h \
    src/core/thememanager.h \
    src/core/auth/usuario.h \
    src/core/auth/profilemanager.h \
    src/core/hardware/hardwaremanager.h \
    src/core/hardware/devicedatabase.h \
    src/core/hardware/driverinstaller.h \
    \
    # 🛡️ SEGURANÇA
    src/core/security/fydelisguard.h \
    src/core/security/fg_rules.h \
    src/core/security/fg_packet.h \
    src/core/security/fg_reputation.h \
    src/core/security/fydelisav.h \
    \
    # ⚙️ SERVIÇOS
    src/core/services/fydelisservices.h \
    src/core/services/servicemodel.h \
    \
    # 🔄 ATUALIZADOR
    src/core/update/fydelisupdater.h \
    src/ui/update/updatepanel.h \
    src/core/versao.h \
    \
    # 🖥️ INTERFACE
    src/ui/splash/splashscreen.h \
    src/ui/login/loginscreen.h \
    src/ui/desktop/desktop.h \
    src/ui/controlpanel.h \
    src/ui/fileexplorer.h \
    src/ui/hardware/hardwarepanel.h \
    src/ui/services/servicemanagerpanel.h \
    \
    # 💿 INSTALADOR
    src/installer/installwizard.h \
    src/installer/partitionmanager.h \
    src/installer/slideshow.h \
    src/installer/pages/bemvindopage.h \
    src/installer/pages/idiomapage.h \
    src/installer/pages/discopartpage.h \
    src/installer/pages/userpage.h \
    src/installer/pages/installpage.h \
    src/installer/pages/resumopage.h \
    src/installer/pages/conclupage.h

# ==========================================
# 🎨 Ícone e Recursos
# ==========================================
win32 {
    RC_ICONS = src/assets/logo.ico
}
RESOURCES += src/assets/resources.qrc

# ==========================================
# 📦 SAÍDA DO EXECUTÁVEL
# ==========================================
DESTDIR = $$OUT_PWD/bin