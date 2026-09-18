#ifndef HARDWAREPANEL_H
#define HARDWAREPANEL_H

#include <QDialog>
#include <QListView>
#include <QPushButton>
#include <QLabel>
#include <QStackedWidget>
#include "hardwaremanager.h"

class HardwarePanel : public QDialog {
    Q_OBJECT
public:
    explicit HardwarePanel(QWidget *pai = nullptr);

private slots:
    void atualizarLista();
    void dispositivoSelecionado(const QModelIndex &indice);
    void baixarDriverAtual();
    void instalarDriver();
    void verificarNovamente();
    void filtrarPorStatus();

private:
    void montarInterface();
    void atualizarDetalhes(const Dispositivo &dev);

    QListView *m_listaDispositivos;
    QLabel *m_lblTotal;
    QLabel *m_lblSemDriver;
    QPushButton *m_btnVerificar;
    QPushButton *m_btnBaixar;
    QPushButton *m_btnInstalar;
    QPushButton *m_btnReiniciar;

    QStackedWidget *m_paginas;
    QWidget *m_paginaLista;
    QWidget *m_paginaDetalhes;

    QLabel *m_nomeDispositivo;
    QLabel *m_fabricante;
    QLabel *m_tipo;
    QLabel *m_status;
    QLabel *m_versaoDriver;
    QLabel *m_progresso;

    Dispositivo m_dispositivoAtual;
    QString m_caminhoDriverBaixado;
};

#endif // HARDWAREPANEL_H