#ifndef DISCOPARTPAGE_H
#define DISCOPARTPAGE_H

#include <QWizardPage>
#include <QListWidget>
#include <QRadioButton>
#include <QPushButton>
#include "partitionmanager.h"

class DiscoPartPage : public QWizardPage {
    Q_OBJECT
public:
    explicit DiscoPartPage(QWidget *parent = nullptr);
    bool validatePage() override;
    void initializePage() override;

private slots:
    void atualizarEspaco();

private:
    PartitionManager *m_pm;
    QListWidget *m_listaDiscos;
    QRadioButton *m_radioDiscoInteiro;
    QRadioButton *m_radioParticaoManual;
    QLabel *m_lblEspaco;
    QList<Particao> m_discos;
};

#endif // DISCOPARTPAGE_H