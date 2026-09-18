#ifndef FYDELISAV_H
#define FYDELISAV_H
#include <QObject>
#include <QStringList>

class FydelisAV : public QObject {
    Q_OBJECT
public:
    static FydelisAV& instancia();
    bool inicializar();
    void desativar();
    bool estaAtivo() const { return m_ativo; }
    
    // 🔍 Verificação
    QStringList verificarPasta(const QString& caminho);
    bool arquivoSuspeito(const QString& caminho);

signals:
    void ameacaEncontrada(const QString& caminhoArquivo, const QString& motivo);

private:
    FydelisAV();
    bool m_ativo = false;
    QStringList m_assinaturas; // Padrões de ameaça
};
#endif