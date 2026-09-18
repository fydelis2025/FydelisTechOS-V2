#ifndef CONTROLPANEL_H
#define CONTROLPANEL_H

#include "hardwarepanel.h"   // ✅ Também aqui se usar no cabeçalho
#include <QDialog>
#include <QTabWidget>
#include <QListWidget>
#include <QStackedWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QLineEdit>
#include <QSlider>
#include <QComboBox>
#include <QCheckBox>
#include <QGroupBox>
#include <QTableWidget>

class ControlPanel : public QDialog {
    Q_OBJECT
public:
    explicit ControlPanel(QWidget *parent = nullptr);

private slots:
    void itemSelecionado(QListWidgetItem*);

private:
    QTabWidget *m_abas;
    QListWidget *m_listaCategorias;
    QStackedWidget *m_paginas;

    // 🎧 Áudio
    QWidget* criarPaginaAudio();
    // 🖥️ Vídeo e Tela
    QWidget* criarPaginaVideo();
    // 📡 Rede e Internet
    QWidget* criarPaginaRede();
    // 🔋 Energia
    QWidget* criarPaginaEnergia();
    // 💾 Backup e Restauração
    QWidget* criarPaginaBackup();
    // 👤 Contas de Usuário
    QWidget* criarPaginaUsuarios();
    // 🌍 Região e Idioma
    QWidget* criarPaginaRegiao();
    // 🖨️ Impressoras
    QWidget* criarPaginaImpressora();
    // 🛡️ Segurança e Manutenção
    QWidget* criarPaginaSeguranca();
    // 🧱 Firewall
    QWidget* criarPaginaFirewall();

    QWidget* criarPaginaHardware();
};

#endif // CONTROLPANEL_H