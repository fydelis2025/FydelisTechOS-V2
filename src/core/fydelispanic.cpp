#include "fydelispanic.h"
#include <QApplication>
#include <QMessageBox>
#include <QDateTime>
#include <QPushButton>

FydelisPanic& FydelisPanic::instancia() {
    static FydelisPanic p;
    return p;
}

FydelisPanic::FydelisPanic() : m_pidAtual(-1) {}

void FydelisPanic::definirProcesso(const QString& nome, int pid) {
    m_processoAtual = nome;
    m_pidAtual = pid;
}

void FydelisPanic::disparar(const QString& codigo,
                            const QString& mensagem,
                            const QString& modulo,
                            const QString& endereco,
                            const QStringList& pilha) {

    m_ultimoErro.codigo = codigo;
    m_ultimoErro.mensagem = mensagem;
    m_ultimoErro.modulo = modulo.isEmpty() ? "Desconhecido" : modulo;
    m_ultimoErro.endereco = endereco.isEmpty() ? "0x0" : endereco;
    m_ultimoErro.processo = m_processoAtual
        + (m_pidAtual > 0 ? QString(" (PID: 0x%1)").arg(m_pidAtual, 0, 16) : "");
    m_ultimoErro.rastreio = pilha;
    m_ultimoErro.dataHora = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
    m_ultimoErro.critico = true;

    QString pilhaTexto = m_ultimoErro.rastreio.isEmpty()
        ? "  [indisponível — símbolos não carregados]"
        : m_ultimoErro.rastreio.join("<br>");

    QString codigoRelatorio = QString("FYD-%1-%2")
        .arg(QDateTime::currentDateTime().toString("yyyyMMdd"))
        .arg(codigo.mid(2));

    QString tela = QString(R"(
<style>
body {
    background: #050508;
    color: #00FF88;
    font-family: 'Consolas', 'Courier New', monospace;
    font-size: 14px;
    line-height: 1.6;
    margin: 0;
}
.titulo {
    color: #00FF88;
    font-weight: bold;
    font-size: 17px;
    border-bottom: 1px solid #00AA55;
    padding-bottom: 10px;
    margin-bottom: 20px;
}
.codigo {
    color: #FF4444;
    font-weight: bold;
    font-size: 16px;
    margin: 10px 0;
}
.rotulo { color: #888888; display: inline-block; width: 130px; }
.valor { color: #E0E0E0; }
.pilha {
    background: #0a1a10;
    padding: 15px;
    border-left: 3px solid #00FF88;
    margin: 15px 0;
}
.dica { color: #FFCC00; margin-top: 20px; }
.rodape { color: #444444; margin-top: 25px; font-size: 12px; }
</style>

<div class="titulo">
╔══════════════════════════════════════════════════════════════╗<br>
║  FYDELIS TECH OS — EXCEÇÃO DE SISTEMA                         ║<br>
║  Sistema Operacional Seguro · Salvador • Bahia 🇧🇷             ║<br>
╚══════════════════════════════════════════════════════════════╝
</div>

<p class="codigo">⚠️ FALHA DE EXECUÇÃO DETECTADA</p>

<p>
<span class="rotulo">CÓDIGO:</span> <span class="valor">%1</span><br>
<span class="rotulo">ERRO:</span> <span class="valor">%2</span><br>
<span class="rotulo">MÓDULO:</span> <span class="valor">%3</span><br>
<span class="rotulo">ENDEREÇO:</span> <span class="valor">%4</span><br>
<span class="rotulo">PROCESSO:</span> <span class="valor">%5</span><br>
<span class="rotulo">DATA/HORA:</span> <span class="valor">%6</span>
</p>

<p><b>📋 RASTREIO DE PILHA:</b></p>
<div class="pilha">%7</div>

<p class="dica">
💡 O QUE FAZER:<br>
• O sistema foi protegido contra corrupção<br>
• Salve seus arquivos se possível e reinicie<br>
• Relate este código no suporte: <b>%8</b>
</p>

<p class="rodape">Pressione OK para encerrar...</p>
    )").arg(
        m_ultimoErro.codigo,
        m_ultimoErro.mensagem,
        m_ultimoErro.modulo,
        m_ultimoErro.endereco,
        m_ultimoErro.processo,
        m_ultimoErro.dataHora,
        pilhaTexto,
        codigoRelatorio
    );

    QMessageBox aviso;
    aviso.setIcon(QMessageBox::Critical);
    aviso.setWindowTitle("💀 EXCEÇÃO — FydelisTech OS");
    aviso.setText(tela);
    aviso.setStandardButtons(QMessageBox::Ok);
    aviso.setStyleSheet(R"(
        QDialog { background: #050508; }
        QLabel { color: #00FF88; font-family: Consolas, monospace; }
        QPushButton {
            background: #1a3a2a;
            color: #00FF88;
            border: 1px solid #00FF88;
            border-radius: 4px;
            padding: 8px 24px;
            font-family: Consolas;
            font-weight: bold;
            min-width: 140px;
            min-height: 36px;
        }
        QPushButton:hover { background: #2a5a3a; }
    )");

    aviso.exec();

    if (m_ultimoErro.critico) {
        qApp->exit(1);
    }
}