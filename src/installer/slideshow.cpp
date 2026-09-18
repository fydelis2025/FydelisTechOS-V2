// slideshow.cpp
#include "slideshow.h"
#include <QVBoxLayout>

SlideShow::SlideShow(QWidget *parent) : QWidget(parent), m_indice(0) {
    m_imagem = new QLabel(this);
    m_imagem->setAlignment(Qt::AlignCenter);
    m_imagem->setScaledContents(true);
    
    m_timer = new QTimer(this);
    connect(m_timer, &QTimer::timeout, this, &SlideShow::proximaImagem);
    
    auto *lay = new QVBoxLayout(this);
    lay->addWidget(m_imagem);
    lay->setContentsMargins(0,0,0,0);
}

void SlideShow::adicionarImagem(const QString &caminho) {
    m_imagens << caminho;
}

void SlideShow::iniciar(int intervaloMs) {
    if (!m_imagens.isEmpty()) proximaImagem();
    m_timer->start(intervaloMs);
}

void SlideShow::parar() { m_timer->stop(); }

void SlideShow::proximaImagem() {
    if (m_imagens.isEmpty()) return;
    m_indice = (m_indice + 1) % m_imagens.size();
    QPixmap img(m_imagens[m_indice]);
    if (!img.isNull()) m_imagem->setPixmap(img);
}