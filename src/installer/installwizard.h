#ifndef INSTALLWIZARD_H
#define INSTALLWIZARD_H

#include <QWizard>

class InstallWizard : public QWizard {
    Q_OBJECT
public:
    explicit InstallWizard(QWidget *parent = nullptr);
    void accept() override;
};

#endif // INSTALLWIZARD_H