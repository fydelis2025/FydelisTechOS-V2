// slideshow.h
#ifndef SLIDESHOW_H
#define SLIDESHOW_H

#include <QWidget>
#include <QLabel>
#include <QTimer>
#include <QPixmap>

class SlideShow : public QWidget {
    Q_OBJECT
public:
    explicit SlideShow(QWidget *parent = nullptr);
    void adicionarImagem(const QString &caminho);
    void iniciar(int intervaloMs = 3000); // 3s por imagem
    void parar();

private slots:
    void proximaImagem();

private:
    QLabel *m_imagem;
    QTimer *m_timer;
    QStringList m_imagens;
    int m_indice;
};

#endif // SLIDESHOW_H