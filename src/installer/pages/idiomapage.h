#ifndef IDIOMAPAGE_H
#define IDIOMAPAGE_H

#include <QWizardPage>
#include <QComboBox>
#include <QLabel>

class IdiomaPage : public QWizardPage {
    Q_OBJECT
public:
    explicit IdiomaPage(QWidget *parent = nullptr);
    bool isComplete() const override;

private:
    QComboBox *m_idioma;
};

#endif // IDIOMAPAGE_H