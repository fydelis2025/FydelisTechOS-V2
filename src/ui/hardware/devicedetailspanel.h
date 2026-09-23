#ifndef DEVICEDETAILSPANEL_H
#define DEVICEDETAILSPANEL_H

#include <QDialog>
#include <QLabel>
#include <QPushButton>
#include "hardwaremanager.h"

// ==========================================
// 📋 PAINEL DETALHADO DE UM DISPOSITIVO
// FydelisTech OS v2.0 · Salvador 🇧🇷
// ==========================================

class DeviceDetailsPanel : public QDialog {
    Q_OBJECT
public:
    explicit DeviceDetailsPanel(const Dispositivo &dispositivo, QWidget *pai = nullptr);

private:
    void montarInterface();
    Dispositivo m_dev;

    QLabel *m_lblNome;
    QLabel *m_lblFabricante;
    QLabel *m_lblTipo;
    QLabel *m_lblID;
    QLabel *m_lblStatus;
    QLabel *m_lblVersao;
    QPushButton *m_btnBaixar;
    QPushButton *m_btnFechar;
};

#endif // DEVICEDETAILSPANEL_H