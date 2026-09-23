#ifndef FG_ADMINPANEL_H
#define FG_ADMINPANEL_H

#include <QDialog>
#include <QPushButton>
#include <QListWidget>
#include <QLabel>
#include <QTableWidget>
#include "fydelisguard.h"

// ==========================================
// 🎛️ FG_ADMINPANEL — Painel de Controle
// ==========================================

class FGAdminPanel : public QDialog {
    Q_OBJECT
public:
    explicit FGAdminPanel(QWidget* parent = nullptr);

private slots:
    void atualizarListaEventos();
    void adicionarIPListaNegra();
    void removerIPListaNegra();
    void alterarModoProtecao(bool maximo);
    void limparLogs();

private:
    void montarInterface();
    void atualizarEstatisticas();

    QLabel* lblStatus;
    QLabel* lblPermitidos;
    QLabel* lblBloqueados;
    QTableWidget* tabelaEventos;
    QPushButton* btnAtivar;
    QPushButton* btnDesativar;
    QPushButton* btnModoMaximo;
    QPushButton* btnAdicionarNegra;
    QPushButton* btnRemoverNegra;
};

#endif // FG_ADMINPANEL_H