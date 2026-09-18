#include "idiomapage.h"
#include <QVBoxLayout>
#include <QLineEdit>

IdiomaPage::IdiomaPage(QWidget *parent) : QWizardPage(parent) {
    setTitle("Idioma");
    setSubTitle("Escolha o idioma do sistema.");

    m_idioma = new QComboBox;
    m_idioma->addItem("🇧🇷 Português (Brasil)", "pt_BR");
    m_idioma->addItem("🇺🇸 English", "en_US");
    m_idioma->addItem("🇪🇸 Español", "es_ES");
    m_idioma->setCurrentIndex(0);

    registerField("idioma*", m_idioma, "currentData");

    auto *lay = new QVBoxLayout;
    lay->addWidget(new QLabel("Selecione o idioma:"));
    lay->addWidget(m_idioma);
    lay->addSpacing(10);
    lay->addWidget(new QLabel("<i>Você poderá alterar o idioma depois nas configurações.</i>"));
    lay->addStretch();
    setLayout(lay);
}

bool IdiomaPage::isComplete() const {
    return m_idioma->currentIndex() >= 0;
}