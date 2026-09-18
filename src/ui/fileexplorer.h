#ifndef FILEEXPLORER_H
#define FILEEXPLORER_H

#include <QMainWindow>
#include <QTreeView>
#include <QListView>
#include <QTableView>
#include <QFileSystemModel>
#include <QSortFilterProxyModel>
#include <QLineEdit>
#include <QToolBar>
#include <QAction>
#include <QComboBox>
#include <QCheckBox>
#include <QSplitter>
#include <QStatusBar>
#include <QLabel>

// 📂 CAMINHOS PADRÃO DO SISTEMA
#define PASTA_RAIZ          "/"
#define PASTA_USUARIOS      "Users/"
#define PASTA_DOCUMENTOS    "Users/Fydelis/Documentos/"
#define PASTA_LIXEIRA       "FydelisSystem/Lixeira/"
#define PASTA_PROGRAMAS     "Program Files/"
#define PASTA_SISTEMA       "FydelisSystem/"

class FileExplorer : public QMainWindow {
    Q_OBJECT
public:
    explicit FileExplorer(QWidget *pai = nullptr);

    // ✅ Navegação
    void irPara(const QString &caminho);
    QString caminhoAtual() const;

private slots:
    void atualizarCaminho();
    void itemClicado(const QModelIndex &indice);
    void itemDuploClicado(const QModelIndex &indice);
    void voltar();
    void avancar();
    void subirNivel();
    void irLixeira();
    void irInicio();
    void alterarVisaoIcone();
    void alterarVisaoLista();
    void pesquisarArquivos();

private:
    void montarInterface();
    void criarAcoes();
    void carregarFavoritos();
    void aplicarTema();

    // 📊 Modelos
    QFileSystemModel *m_sistemaArquivos;
    QSortFilterProxyModel *m_filtro;

    // 🧩 Componentes
    QTreeView *m_arvorePastas;
    QListView *m_visualizacao;
    QLineEdit *m_barraEndereco;
    QLineEdit *m_barraPesquisa;
    QComboBox *m_caminhosRapidos;
    QSplitter *m_divisor;
    QStatusBar *m_barraStatus;
    QLabel *m_statusInfo;

    // 🔗 Histórico de navegação
    QStringList m_historico;
    int m_indiceHistorico;

    // ⚙️ Ações
    QAction *acaoVoltar, *acaoAvancar, *acaoSubir;
    QAction *acaoNovaPasta, *acaoCopiar, *acaoColar, *acaoExcluir;
    QAction *acaoVisaoIcone, *acaoVisaoLista, *acaoLixeira;
};

#endif // FILEEXPLORER_H