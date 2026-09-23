#ifndef SPLASHSCREEN_H
#define SPLASHSCREEN_H

#include <QWidget>
#include <QLabel>
#include <QProgressBar>
#include <QTimer>
#include <QVBoxLayout>

class SplashScreen : public QWidget {
    Q_OBJECT
public:
    explicit SplashScreen(QWidget *parent = nullptr);

signals:
    void pronto(); // Emitido quando terminar

private slots:
    void atualizarProgresso();

private:
    QLabel *m_logo;
    QLabel *m_titulo;
    QLabel *m_status;
    QProgressBar *m_progresso;
    QTimer *m_timer;
    int m_porcentagem;
};

#endif // SPLASHSCREEN_H