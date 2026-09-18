#ifndef THEMEMANAGER_H
#define THEMEMANAGER_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QGradient>

class ThemeManager : public QObject {
    Q_OBJECT
public:
    static ThemeManager& instancia();
    bool carregarTema(const QString &caminhoArquivo = ":/themes/default.json");
    QString corFundo() const;
    QString estiloJanelaVidro() const;
    QString estiloBarraTarefas() const;
    QString corTextoPrimaria() const;
    QString corTextoSecundaria() const;
    QString corTextoDestaque() const;
    int brilhoIntensidade() const;
    QString corBrilho() const;
	bool carregarTemaDoJSON(const QString &jsonTexto);

private:
    explicit ThemeManager(QObject *parent = nullptr);
    QJsonObject m_dados;
    QString lerValor(const QString &chave, const QString &padrao="") const;
};

#endif // THEMEMANAGER_H