#ifndef BEMVINDOPAGE_H
#define BEMVINDOPAGE_H

#include <QWizardPage>
#include <QLabel>
#include <QVBoxLayout>

class BemVindoPage : public QWizardPage {
    Q_OBJECT
public:
    explicit BemVindoPage(QWidget *parent = nullptr);
    int nextId() const override;
};

#endif // BEMVINDOPAGE_H