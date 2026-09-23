#ifndef USERPAGE_H
#define USERPAGE_H

#include <QWizardPage>
#include <QLineEdit>
#include <QCheckBox>
#include <QLabel>

class UserPage : public QWizardPage {
    Q_OBJECT
public:
    explicit UserPage(QWidget *parent = nullptr);
    bool validatePage() override;

private:
    QLineEdit *m_usuario;
    QLineEdit *m_senha;
    QLineEdit *m_confirmaSenha;
    QCheckBox *m_loginAuto;
    QLabel *m_erro;
};

#endif // USERPAGE_H