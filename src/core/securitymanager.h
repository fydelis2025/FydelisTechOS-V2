#ifndef SECURITYMANAGER_H
#define SECURITYMANAGER_H

#include <QString>
#include <QByteArray>

class SecurityManager {
public:
    static SecurityManager& instancia();

    // ✅ Inicializar sistema de segurança (gerar chaves se não existirem)
    bool inicializarSeguranca();

    // ✅ Salte global para senhas
    QByteArray salteGlobal();

    // ✅ Chave privada do sistema
    QByteArray chavePrivadaSistema();

    // ✅ Caminhos protegidos
    QString pastaSeguranca();

private:
    SecurityManager();
    QByteArray gerarBytesAleatorios(int qtde);
    QByteArray m_salteGlobal;
    QByteArray m_chavePrivada;
};

#endif // SECURITYMANAGER_H