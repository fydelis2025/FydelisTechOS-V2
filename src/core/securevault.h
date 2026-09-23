#ifndef SECUREVAULT_H
#define SECUREVAULT_H

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QDir>
#include <QFile>

class SecureVault : public QObject {
    Q_OBJECT
public:
    static SecureVault& instancia();

    bool inicializar();
    bool gerarChaveMestra();
    QString carregarChaveMestra();
    QSqlDatabase bancoUsuarios();

private:
    explicit SecureVault(QObject *parent = nullptr);
    QString caminhoPastaRaiz() const;
    QString caminhoCofre() const;
    QString caminhoSeguranca() const;
    QString caminhoDatabase() const;
    QString caminhoProfiles() const;
    bool protegerArquivo(const QString &caminho);

    bool m_inicializado;
    QString m_chaveMestra;
    QSqlDatabase m_dbUsuarios;
};

#endif // SECUREVAULT_H