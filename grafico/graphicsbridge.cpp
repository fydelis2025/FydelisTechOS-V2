#include "graphicsbridge.h"
#include <QDebug>

GraphicsBridge& GraphicsBridge::instancia() {
    static GraphicsBridge inst;
    return inst;
}

GraphicsBridge::GraphicsBridge() = default;

bool GraphicsBridge::inicializar() {
    // Lê geometria inicial do kernel
    fb_get_geometria(&m_geo);
    m_ativo = true;
    qDebug() << "[GraphicsBridge] ✅ Tela:" << m_geo.larguraPx
             << "x" << m_geo.alturaPx
             << "→" << m_geo.colunas << "×" << m_geo.linhas << "caracteres";
    return true;
}

// ✅ EVENTO DISPARADO PELA JANELA PRINCIPAL
bool GraphicsBridge::redimensionarPara(int novaLarguraPx, int novaAlturaPx) {
    if (!m_ativo) return false;

    qDebug() << "[GraphicsBridge] Redimensionando para"
             << novaLarguraPx << "×" << novaAlturaPx;

    // Envia para o kernel
    bool ok = fb_redimensionar(novaLarguraPx, novaAlturaPx) != 0;

    if (!ok) {
        qWarning() << "[GraphicsBridge] Kernel rejeitou resolução";
        emit redimensionamentoRejeitado();
        return false;
    }

    // Atualiza cópia local
    fb_get_geometria(&m_geo);
    qDebug() << "[GraphicsBridge] ✅ Nova geometria:"
             << m_geo.colunas << "×" << m_geo.linhas
             << "(fonte:" << m_geo.fonteLargura << "×" << m_geo.fonteAltura << ")";

    emit geometriaAlterada(m_geo);
    return true;
}