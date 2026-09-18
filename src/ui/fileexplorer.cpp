#include "fileexplorer.h"
#include "../core/configmanager.h"
#include "../core/thememanager.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QMessageBox>
#include <QDir>
#include <QFileDialog>
#include <QMenuBar>
#include <QContextMenuEvent>

// ==========================================
// 📁 EXPLORADOR DE ARQUIVOS — FYDELIS TECH OS
// Com Lixeira, Navegação e Tema Integrado
// De Salvador • Bahia 🇧🇷
// ==========================================

FileExplorer::FileExplorer(QWidget *pai) : QMainWindow(pai) {
    setWindowTitle("Explorador de Arquivos — FydelisTech OS");
    resize(1024, 650);

    // ✅ Inicializar modelos
    m_sistemaArquivos = new QFileSystemModel(this);
    m_sistemaArquivos->setRootPath(PASTA_RAIZ);
    m_sistemaArquivos->setReadOnly(false);

    m_filtro = new QSortFilterProxyModel(this);
    m_filtro->setSourceModel(m_sistemaArquivos);

    m_historico.clear();
    m_indiceHistorico = -1;

    montarInterface();
    aplicarTema();
    irPara(PASTA_RAIZ);
}

// ==========================================
// 🧩 CONSTRUIR INTERFACE COMPLETA
// ==========================================
void FileExplorer::montarInterface() {
    // 🧭 Barra de Ferramentas
    QToolBar *barra = addToolBar("Navegação");
    barra->setMovable(false);

    acaoVoltar   = barra->addAction("◀");
    acaoAvancar  = barra->addAction("▶");
    acaoSubir    = barra->addAction("⬆ Subir");
    barra->addSeparator();

    m_barraEndereco = new QLineEdit(this);
    m_barraEndereco->setPlaceholderText("Digite o caminho...");
    barra->addWidget(m_barraEndereco);

    m_barraPesquisa = new QLineEdit(this);
    m_barraPesquisa->setPlaceholderText("🔍 Pesquisar...");
    m_barraPesquisa->setMaximumWidth(250);
    barra->addWidget(m_barraPesquisa);

    barra->addSeparator();
    acaoVisaoIcone = barra->addAction("🖼 Ícones");
    acaoVisaoLista = barra->addAction("📋 Lista");
    acaoLixeira    = barra->addAction("🗑 Lixeira");

    // 📂 Área Central: Árvore + Conteúdo
    QWidget *central = new QWidget(this);
    QHBoxLayout *lay = new QHBoxLayout(central);
    lay->setContentsMargins(4,4,4,4);
    lay->setSpacing(4);

    m_divisor = new QSplitter(Qt::Horizontal, this);

    // 🌳 Árvore de Pastas (Esquerda)
    m_arvorePastas = new QTreeView(this);
    m_arvorePastas->setModel(m_sistemaArquivos);
    m_arvorePastas->setRootIndex(m_sistemaArquivos->index(PASTA_RAIZ));
    m_arvorePastas->setHeaderHidden(true);
    m_arvorePastas->hideColumn(1);
    m_arvorePastas->hideColumn(2);
    m_arvorePastas->hideColumn(3);
    m_arvorePastas->setFixedWidth(240);

    // 📋 Visualização de Arquivos (Direita)
    m_visualizacao = new QListView(this);
    m_visualizacao->setModel(m_filtro);
    m_visualizacao->setRootIndex(m_filtro->mapFromSource(m_sistemaArquivos->index(PASTA_RAIZ)));
    m_visualizacao->setViewMode(QListView::IconMode);
    m_visualizacao->setIconSize(QSize(48,48));
    m_visualizacao->setSpacing(12);

    m_divisor->addWidget(m_arvorePastas);
    m_divisor->addWidget(m_visualizacao);
    m_divisor->setStretchFactor(1, 1);

    lay->addWidget(m_divisor);
    setCentralWidget(central);

    // 📊 Barra de Status
    m_barraStatus = statusBar();
    m_statusInfo = new QLabel("Pronto");
    m_barraStatus->addPermanentWidget(m_statusInfo);

    // 🔗 CONECTAR EVENTOS
    connect(acaoVoltar, &QAction::triggered, this, &FileExplorer::voltar);
    connect(acaoAvancar, &QAction::triggered, this, &FileExplorer::avancar);
    connect(acaoSubir,   &QAction::triggered, this, &FileExplorer::subirNivel);
    connect(acaoLixeira, &QAction::triggered, this, &FileExplorer::irLixeira);
    connect(acaoVisaoIcone, &QAction::triggered, this, &FileExplorer::alterarVisaoIcone);
    connect(acaoVisaoLista, &QAction::triggered, this, &FileExplorer::alterarVisaoLista);

    connect(m_barraEndereco, &QLineEdit::returnPressed, this, &FileExplorer::atualizarCaminho);
    connect(m_barraPesquisa, &QLineEdit::textEdited, this, &FileExplorer::pesquisarArquivos);

    connect(m_arvorePastas, &QTreeView::clicked, this, &FileExplorer::itemClicado);
    connect(m_visualizacao, &QListView::doubleClicked, this, &FileExplorer::itemDuploClicado);
}

// ==========================================
// 📂 NAVEGAÇÃO — IR PARA PASTA
// ==========================================
void FileExplorer::irPara(const QString &caminho) {
    QString caminhoNormal = QDir::cleanPath(caminho) + "/";

    // ✅ Salvar no histórico
    if (m_indiceHistorico >= 0 && m_historico[m_indiceHistorico] != caminhoNormal) {
        m_historico = m_historico.mid(0, m_indiceHistorico + 1);
    }
    if (m_historico.isEmpty() || m_historico.last() != caminhoNormal) {
        m_historico.append(caminhoNormal);
        m_indiceHistorico = m_historico.size() - 1;
    }

    // ✅ Atualizar visualização
    QModelIndex raiz = m_sistemaArquivos->index(caminhoNormal);
    m_arvorePastas->setCurrentIndex(raiz);
    m_arvorePastas->expand(raiz);
    m_visualizacao->setRootIndex(m_filtro->mapFromSource(raiz));
    m_barraEndereco->setText(caminhoNormal);

    // ✅ Atualizar status
    QDir dir(caminhoNormal);
    int qtd = dir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries).size();
    m_statusInfo->setText(QString("%1 itens").arg(qtd));
}

QString FileExplorer::caminhoAtual() const {
    return m_barraEndereco->text();
}

void FileExplorer::atualizarCaminho() {
    irPara(m_barraEndereco->text());
}

// ==========================================
// ◀ HISTÓRICO: VOLTAR / AVANÇAR
// ==========================================
void FileExplorer::voltar() {
    if (m_indiceHistorico > 0) {
        m_indiceHistorico--;
        irPara(m_historico[m_indiceHistorico]);
    }
}

void FileExplorer::avancar() {
    if (m_indiceHistorico < m_historico.size() - 1) {
        m_indiceHistorico++;
        irPara(m_historico[m_indiceHistorico]);
    }
}

void FileExplorer::subirNivel() {
    QString caminho = caminhoAtual();
    QDir dir(caminho);
    if (dir.cdUp()) irPara(dir.absolutePath());
}

// ==========================================
// 🗑 LIXEIRA
// ==========================================
void FileExplorer::irLixeira() {
    QDir().mkpath(PASTA_LIXEIRA); // ✅ Garante que existe
    irPara(PASTA_LIXEIRA);
    QMessageBox::information(this, "🗑 Lixeira",
        "Arquivos excluídos ficam aqui até serem removidos permanentemente.\n\nCaminho: " + QString(PASTA_LIXEIRA));
}

// ==========================================
// 🖱 CLIQUES EM ITENS
// ==========================================
void FileExplorer::itemClicado(const QModelIndex &indice) {
    QString caminho = m_sistemaArquivos->filePath(indice);
    m_barraEndereco->setText(caminho);
}

void FileExplorer::itemDuploClicado(const QModelIndex &indiceFiltro) {
    QModelIndex indiceReal = m_filtro->mapToSource(indiceFiltro);
    QString caminho = m_sistemaArquivos->filePath(indiceReal);
    QFileInfo info(caminho);

    if (info.isDir()) {
        irPara(caminho); // ✅ Entra na pasta
    }
}

// ==========================================
// 🔍 PESQUISAR ARQUIVOS
// ==========================================
void FileExplorer::pesquisarArquivos() {
    QString texto = m_barraPesquisa->text();
    m_filtro->setFilterWildcard("*" + texto + "*");
    m_filtro->setFilterCaseSensitivity(Qt::CaseInsensitive);
}

// ==========================================
// 🖼 ALTERAR VISUALIZAÇÃO
// ==========================================
void FileExplorer::alterarVisaoIcone() {
    m_visualizacao->setViewMode(QListView::IconMode);
    m_visualizacao->setIconSize(QSize(64,64));
}

void FileExplorer::alterarVisaoLista() {
    m_visualizacao->setViewMode(QListView::ListMode);
    m_visualizacao->setIconSize(QSize(24,24));
}

// ==========================================
// 🎨 APLICAR TEMA DO SISTEMA
// ==========================================
void FileExplorer::aplicarTema() {
    auto &tema = ThemeManager::instancia();
    setStyleSheet(QString(R"(
        QMainWindow { background: %1; color: %2; }
        QTreeView, QListView {
            background: rgba(30, 20, 70, 0.4);
            border: 1px solid rgba(140, 180, 255, 0.25);
            border-radius: 6px;
            color: %2;
            padding: 4px;
        }
        QTreeView::item, QListView::item {
            padding: 6px; margin: 2px; border-radius: 4px;
        }
        QTreeView::item:selected, QListView::item:selected {
            background: #4f46e5; color: white;
        }
        QLineEdit {
            background: rgba(30, 20, 70, 0.5);
            border: 1px solid rgba(140, 180, 255, 0.3);
            border-radius: 4px;
            padding: 6px; color: white;
        }
        QToolBar { background: rgba(30, 20, 70, 0.5); border: none; spacing: 4px; }
        QToolBar QAction { padding: 6px 10px; color: %2; }
        QToolBar QAction:hover { background: #4f46e5; border-radius: 4px; }
        QStatusBar { background: rgba(20, 15, 50, 0.6); color: %3; }
    )").arg(tema.corFundo(), tema.corTextoPrimaria(), tema.corTextoDestaque()));
}