#ifndef RESUMOPAGE_H
#define RESUMOPAGE_H

#include <QWizardPage>
#include <QLabel>

class ResumoPage : public QWizardPage {
    Q_OBJECT
public:
    explicit ResumoPage(QWidget *parent = nullptr);
    void initializePage() override;

private:
    QLabel *m_textoResumo;
};

#endif // RESUMOPAGE_H