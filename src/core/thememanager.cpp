#include "thememanager.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonValue>
#include <QDebug>

// ==========================================
// 🎨 GERENCIADOR DE TEMAS — CARREGA JSON
// De Salvador • Bahia 🇧🇷
// ==========================================

ThemeManager& ThemeManager::instancia() {
    static ThemeManager inst;
    return inst;
}

ThemeManager::ThemeManager(QObject *parent) : QObject(parent) {}

// 📂 CARREGAR TEMA DO ARQUIVO JSON
bool ThemeManager::carregarTema(const QString &caminhoArquivo) {
    QFile arq(caminhoArquivo);
    if (!arq.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "⚠️ Não foi possível carregar tema:" << caminhoArquivo;
        qWarning() << "✅ Usando tema padrão embutido.";
        return false;
    }

    QByteArray dadosJson = arq.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(dadosJson);
    if (!doc.isObject()) {
        qWarning() << "❌ JSON de tema inválido!";
        return false;
    }

    m_dados = doc.object();
    qDebug() << "✅ Tema carregado:" << lerValor("nome", "Desconhecido");
    return true;
}

// 📥 AUXILIAR — LER VALOR COM PADRÃO
QString ThemeManager::lerValor(const QString &chave, const QString &padrao) const {
    QStringList caminho = chave.split(".");
    QJsonObject obj = m_dados;

    for (int i = 0; i < caminho.size() - 1; i++) {
        if (obj.contains(caminho[i]) && obj[caminho[i]].isObject())
            obj = obj[caminho[i]].toObject();
        else
            return padrao;
    }

    QString ultimo = caminho.last();
    if (obj.contains(ultimo))
        return obj[ultimo].toString();
    return padrao;
}

// 🎨 FUNDO GRADIENTE
QString ThemeManager::corFundo() const {
    QString c1 = lerValor("fundo.cor1", "#1a0f47");
    QString c2 = lerValor("fundo.cor2", "#251b60");
    QString c3 = lerValor("fundo.cor3", "#0f173a");
    return QString(
        "qlineargradient(x1:0, y1:0, x2:1, y2:1, "
        "stop:0 %1, stop:0.5 %2, stop:1 %3)"
    ).arg(c1, c2, c3);
}

// 🪟 ESTILO JANELA VIDRO
QString ThemeManager::estiloJanelaVidro() const {
    QString fundo = lerValor("janelaVidro.fundo", "rgba(60, 40, 110, 0.40)");
    QString borda = lerValor("janelaVidro.borda", "rgba(140, 180, 255, 0.35)");
    int raio = lerValor("janelaVidro.raioCantos", "24").toInt();
    return QString(
        "background: %1; border-radius: %2px; border: 1px solid %3;"
    ).arg(fundo).arg(raio).arg(borda);
}

// 🧭 ESTILO BARRA DE TAREFAS
QString ThemeManager::estiloBarraTarefas() const {
    QString fundo = lerValor("barraTarefas.fundo", "rgba(30, 20, 70, 0.50)");
    QString borda = lerValor("barraTarefas.bordaSuperior", "rgba(140, 180, 255, 0.25)");
    return QString(
        "background: %1; border-top: 1px solid %2; border-bottom: none; "
        "spacing: 6px; padding: 6px 10px;"
    ).arg(fundo).arg(borda);
}

// ✍️ CORES DE TEXTO
QString ThemeManager::corTextoPrimaria() const {
    return lerValor("texto.primaria", "#e6eeff");
}
QString ThemeManager::corTextoSecundaria() const {
    return lerValor("texto.secundaria", "#94a3b8");
}
QString ThemeManager::corTextoDestaque() const {
    return lerValor("texto.destaque", "#a5b4fc");
}

// ✨ BRILHO / GLOW
int ThemeManager::brilhoIntensidade() const {
    return lerValor("janelaVidro.brilhoIntensidade", "50").toInt();
}
QString ThemeManager::corBrilho() const {
    QString cor = lerValor("janelaVidro.brilhoCor", "rgba(100, 140, 255, 0.35)");
    cor.remove("rgba(").chop(1);
    QStringList partes = cor.split(",");
    if (partes.size() >= 3) {
        int r = partes[0].trimmed().toInt();
        int g = partes[1].trimmed().toInt();
        int b = partes[2].trimmed().toInt();
        return QString("rgba(%1, %2, %3, 90)").arg(r).arg(g).arg(b);
    }
    return "rgba(100, 140, 255, 90)";
}

// ✅ CARREGA TEMA DIRETO DO TEXTO JSON
bool ThemeManager::carregarTemaDoJSON(const QString &jsonTexto) {
    QJsonDocument doc = QJsonDocument::fromJson(jsonTexto.toUtf8());
    if (!doc.isObject()) {
        qWarning() << "❌ JSON inválido!";
        return false;
    }
    m_dados = doc.object();
    qDebug() << "✅ Tema aplicado:" << lerValor("nome", "Desconhecido");
    return true;
}