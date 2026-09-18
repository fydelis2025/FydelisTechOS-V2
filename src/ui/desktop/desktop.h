#ifndef DESKTOP_H
#define DESKTOP_H
#include <QMainWindow>
#include <QTabWidget>
#include <QToolBar>
#include <QStatusBar>
#include <QLabel>
#include <QDateTime>
#include <QTimer>  // ✅ Já estava faltando
class Desktop : public QMainWindow {
    Q_OBJECT
public:
    explicit Desktop(QWidget *parent = nullptr);
private slots:
    void abrirNavegador();
    void abrirEditor();
    void abrirTerminal();
    void abrirConfiguracoes();
    void atualizarRelogio();
	void abrirPainelControle();
	void abrirExploradorArquivos();

private:
    QTabWidget *m_abas;
    QLabel *m_lblRelogio;
    QTimer *m_timerRelogio;
    void montarBarraTarefas();
	QLabel *m_lblRelogio;
    QTimer *m_timerRelogio;
};
#endif // DESKTOP_H