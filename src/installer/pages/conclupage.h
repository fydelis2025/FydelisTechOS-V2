#ifndef CONCLUPAGE_H
#define CONCLUPAGE_H

#include <QWizardPage>
#include <QLabel>
#include <QPushButton>

class ConcluPage : public QWizardPage {
    Q_OBJECT
public:
    explicit ConcluPage(QWidget *parent = nullptr);

private slots:
    void reiniciarSistema();

private:
    QLabel *m_texto;
};

#endif // CONCLUPAGE_H