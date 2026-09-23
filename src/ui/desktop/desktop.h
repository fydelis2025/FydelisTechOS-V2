#ifndef DESKTOP_H
#define DESKTOP_H

#include <QMainWindow>
#include <QTabWidget>
#include <QToolBar>
#include <QStatusBar>
#include <QLabel>
#include <QDateTime>
#include <QTimer>

// ✅ Forward declarations — sem erro de compilação
class FydelTermWindow;
class FileExplorer;
class ControlPanel;
class CVEPanel;

class Desktop : public QMainWindow {
    Q_OBJECT
public:
    explicit Desktop(QWidget *parent = nullptr);

private slots:
    void abrirExploradorArquivos();
    void abrirNavegador();
    void abrirEditor();
    void abrirTerminal();
    void abrirPainelSeguranca();      // 🛡️ CVE Shield
    void abrirConfiguracoes();
    void abrirPainelControle();
    void atualizarRelogio();

private:
    // 🧭 Interface
    QTabWidget *m_abas;
    QLabel *m_lblRelogio;
    QTimer *m_timerRelogio;

    // 📦 Métodos de construção
    void montarBarraTarefas();
};

#endif // DESKTOP_H