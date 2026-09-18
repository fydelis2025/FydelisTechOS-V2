#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QString>
#include <QVariant>

class ConfigManager {
public:
    static ConfigManager& instancia();

    // ✅ Inicializar — CRIA O BANCO SE NÃO EXISTIR
    bool inicializar();

    // ✅ Ler e salvar configurações
    QVariant valor(const QString &chave, const QVariant &padrao = QVariant());
    bool definirValor(const QString &chave, const QVariant &valor);

    // ==========================================
    // 📋 TODAS AS CONFIGURAÇÕES — VÍDEO, SOM, REDE, IMPRESSORA, TEMA...
    // ==========================================

    // 🎨 TEMA
    QString temaAtual();
    bool definirTemaAtual(const QString &nome);

    // 🖥️ VÍDEO / TELA
    QString resolucaoTela();
    bool definirResolucaoTela(const QString &res);

    int taxaAtualizacao();
    bool definirTaxaAtualizacao(int hz);

    // 🎧 SOM
    int volumePrincipal();
    bool definirVolumePrincipal(int vol);

    bool somLigado();
    bool definirSomLigado(bool ligado);

    QString dispositivoSom();
    bool definirDispositivoSom(const QString &nome);

    // 📡 REDE
    bool dhcpAtivado();
    bool definirDHCP(bool ativo);

    QString ipManual();
    bool definirIPManual(const QString &ip);

    QString mascaraRede();
    bool definirMascaraRede(const QString &masc);

    QString gateway();
    bool definirGateway(const QString &gw);

    QString dnsPrimario();
    bool definirDNSPrimario(const QString &dns);

    QString dnsSecundario();
    bool definirDNSSecundario(const QString &dns);

    // 🖨️ IMPRESSORA
    QString impressoraPadrao();
    bool definirImpressoraPadrao(const QString &nome);

    // 🔋 ENERGIA
    QString planoEnergia();
    bool definirPlanoEnergia(const QString &nome);

    int desligarTelaBateria();
    bool definirDesligarTelaBateria(int min);

    int desligarTelaTomada();
    bool definirDesligarTelaTomada(int min);

    // 🌍 REGIÃO
    QString idioma();
    bool definirIdioma(const QString &sigla);

    // 🔒 SEGURANÇA
    bool firewallAtivado();
    bool definirFirewall(bool ativo);

    bool protecaoTempoReal();
    bool definirProtecaoTempoReal(bool ativo);

private:
    ConfigManager();
    QString caminhoBanco();
    bool criarTabela();
};

#endif // CONFIGMANAGER_H