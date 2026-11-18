#ifndef GRAPHICSBRIDGE_H
#define GRAPHICSBRIDGE_H

#include <QObject>
#include <QResizeEvent>
#include <QWidget>

// ==========================================
// 🌉 PONTE REDIMENSIONAMENTO DINÂMICO
// Captura evento Qt → atualiza kernel → ajusta geometria
// FydelisTech OS v2.2 · Salvador • Bahia 🇧🇷
// ==========================================

struct GeometriaTela {
    int colunas;     // caracteres por linha
    int linhas;      // linhas visíveis
    int fonteLargura;
    int fonteAltura;
    int larguraPx;
    int alturaPx;
};

class GraphicsBridge : public QObject {
    Q_OBJECT
public:
    static GraphicsBridge& instancia();

    // Inicialização
    bool inicializar();

    // Geometria atual
    GeometriaTela geometria() const { return m_geo; }

    // ✅ Chamado pela janela ao redimensionar
    bool redimensionarPara(int novaLarguraPx, int novaAlturaPx);

    // Verificação
    bool estaAtivo() const { return m_ativo; }

signals:
    void geometriaAlterada(const GeometriaTela& novaGeo);
    void redimensionamentoRejeitado();

private:
    GraphicsBridge();
    GeometriaTela m_geo;
    bool m_ativo = false;
};

// ========== Funções Assembly do kernel ==========
extern "C" {
    int  fb_redimensionar(int novaLargura, int novaAltura);
    void fb_get_geometria(GeometriaTela* saida);
}

#endif // GRAPHICSBRIDGE_H