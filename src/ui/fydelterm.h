#ifndef FYDELTERM_H
#define FYDELTERM_H

#include <QDialog>
#include <QTextEdit>
#include <QLineEdit>

class FydelTerm : public QDialog {
    Q_OBJECT
public:
    explicit FydelTerm(QWidget* parent = nullptr);
    
private slots:
    void executarComando();
    
private:
    QTextEdit* m_saida;
    QLineEdit* m_entrada;
    
    // 📋 Comandos de Sistema
    void cmdAjuda();
    void cmdCls();
    void cmdVersao();
    void cmdPwd();
    void cmdLs();
    void cmdCd(const QString& caminho);
    void cmdMkdir(const QString& nome);
    void cmdCp(const QString& origem, const QString& destino);
    void cmdMv(const QString& origem, const QString& destino);
    void cmdRm(const QString& alvo);
    void cmdCat(const QString& arquivo);
    void cmdIpconfig();
    void cmdPing(const QString& endereco);
    
    // 🛡️ Suíte Pentest
    void cmdPentest();
    void cmdPortScan(const QString& alvo);
    void cmdNetInfo();
    void cmdSystemAudit();
    
    // 🔧 Utilitários
    QString caminhoAtual;
    QString extrairParametro(const QString& comando, int indice = 1);
};

#endif // FYDELTERM_H