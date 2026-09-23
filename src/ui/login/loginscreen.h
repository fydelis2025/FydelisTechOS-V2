#ifndef LOGINSCREEN_H
#define LOGINSCREEN_H

#include <QWidget>
#include <QLineEdit>
#include <QPushButton>
#include <QLabel>
#include <QVBoxLayout>
#include "../core/securevault.h"

class LoginScreen : public QWidget {
    Q_OBJECT
public:
    explicit LoginScreen(QWidget *parent = nullptr);

signals:
    void loginConcluido(); // Vai para Área de Trabalho

private slots:
    void tentarLogin();

private:
    QLineEdit *m_usuario;
    QLineEdit *m_senha;
    QLabel *m_erro;
    QPushButton *m_btnEntrar;
};

#endif // LOGINSCREEN_H