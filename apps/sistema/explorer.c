#include "../apps.h"
#include "../../include/fyd_formatos.h"
#include "../../include/icones.h"
#include <stdint.h>
#include <stddef.h>

extern void gui_retangulo(int x, int y, int w, int h, uint32_t cor);
extern void gui_borda(int x, int y, int w, int h, uint32_t cor);
extern void gui_texto(int x, int y, const char *str, uint32_t cor);
extern void gpu_desenhar_icone(const uint32_t *pixels, int x, int y, int w, int h);

extern const char **fs_obter_lista_pastas(void);
extern uint64_t fs_total_pastas(void);

#define EXP_COR_PAINEL      0xFF1E0E3D
#define EXP_COR_TOPO        0xFF120826
#define EXP_COR_FUNDO_ARV   0xFF160A2E
#define EXP_COR_FUNDO_DIR   0xFF120726
#define EXP_COR_ITEM_SEL    0xFF3B1D75
#define EXP_COR_ROXO        0xFF9D4EDD
#define EXP_COR_CIANO       0xFF00F5D4
#define EXP_COR_VERDE       0xFF00FF9C
#define EXP_COR_AMARELO     0xFFFFD166
#define EXP_COR_VERMELHO    0xFFFF4D6D
#define EXP_COR_TEXTO       0xFFF8FAFC
#define EXP_COR_SUAVE       0xFFCBD5E1

static int exp_indice_selecionado = 0;

/* Arvore padrao garantida caso fs_total_pastas() ainda esteja vazio */
static const char *arvore_fallback[] = {
    "/fyd",
    "/fyd/sistema",
    "/fyd/sistema/drivers",
    "/fyd/apps",
    "/fyd/rede",
    "/fyd/config",
    "/fyd/logs",
    "/fyd/usuario",
    "/fyd/usuario/documentos",
    "/fyd/usuario/imagens"
};
#define TOTAL_FALLBACK 10

static const char *exp_obter_pasta(int idx, int *total_out) {
    uint64_t total_fs = fs_total_pastas();
    const char **lista_fs = fs_obter_lista_pastas();

    if (lista_fs && total_fs > 0) {
        if (total_out) *total_out = (int)total_fs;
        if (idx >= 0 && idx < (int)total_fs && lista_fs[idx]) {
            return lista_fs[idx];
        }
        return lista_fs[0];
    }

    if (total_out) *total_out = TOTAL_FALLBACK;
    if (idx >= 0 && idx < TOTAL_FALLBACK) return arvore_fallback[idx];
    return arvore_fallback[0];
}

/* Conta quantas '/' existem para indentar como arvore visual */
static int exp_nivel_arvore(const char *caminho) {
    int barras = 0;
    for (int i = 0; caminho && caminho[i]; i++) {
        if (caminho[i] == '/') barras++;
    }
    return (barras > 1) ? (barras - 1) : 0;
}

static int exp_contem(const char *texto, const char *sub) {
    if (!texto || !sub) return 0;
    for (int i = 0; texto[i]; i++) {
        int j = 0;
        while (sub[j] && texto[i + j] == sub[j]) j++;
        if (!sub[j]) return 1;
    }
    return 0;
}

static void explorer_abrir(void) {
    app_explorer.aberta = 1;
}

static void explorer_desenhar(void) {
    if (!app_explorer.aberta) return;

    int x = app_explorer.x;
    int y = app_explorer.y;
    int w = app_explorer.w;
    int h = app_explorer.h;

    int total = 0;
    const char *caminho_ativo = exp_obter_pasta(exp_indice_selecionado, &total);

    /* Moldura principal e cabecalho */
    gui_retangulo(x, y, w, h, EXP_COR_PAINEL);
    gui_borda(x, y, w, h, EXP_COR_ROXO);
    gui_retangulo(x + 2, y + 2, w - 4, 26, EXP_COR_TOPO);

    gpu_desenhar_icone(icone_pasta_aberta, x + 8, y + 6, 16, 16);
    gui_texto(x + 30, y + 7, "FydelisExplorer - Gerenciador de Arquivos", EXP_COR_CIANO);

    /* Botao [X] */
    gui_retangulo(x + w - 24, y + 4, 20, 20, EXP_COR_VERMELHO);
    gui_texto(x + w - 18, y + 6, "X", EXP_COR_TEXTO);

    /* Barra de endereco superior */
    gui_retangulo(x + 10, y + 34, w - 20, 24, EXP_COR_FUNDO_ARV);
    gui_borda(x + 10, y + 34, w - 20, 24, 0xFF4C2889);
    gui_texto(x + 18, y + 38, "Caminho:", EXP_COR_SUAVE);
    gui_texto(x + 88, y + 38, caminho_ativo, EXP_COR_VERDE);

    /* Painel Esquerdo: Arvore de Diretorios */
    int tree_x = x + 10;
    int tree_y = y + 64;
    int tree_w = 225;
    int tree_h = h - 94;

    gui_retangulo(tree_x, tree_y, tree_w, tree_h, EXP_COR_FUNDO_ARV);
    gui_borda(tree_x, tree_y, tree_w, tree_h, 0xFF4C2889);
    gui_texto(tree_x + 8, tree_y + 6, "ARVORE /fyd", EXP_COR_ROXO);

    int max_linhas = (tree_h - 28) / 22;
    if (total < max_linhas) max_linhas = total;

    int cy = tree_y + 26;
    for (int i = 0; i < max_linhas; i++) {
        const char *p = exp_obter_pasta(i, NULL);
        int nivel = exp_nivel_arvore(p);
        int indent = nivel * 14;
        int sel = (i == exp_indice_selecionado);

        if (sel) {
            gui_retangulo(tree_x + 4, cy - 2, tree_w - 8, 20, EXP_COR_ITEM_SEL);
            gui_borda(tree_x + 4, cy - 2, tree_w - 8, 20, EXP_COR_CIANO);
        }

        if (nivel > 0) {
            gui_texto(tree_x + 6 + indent - 12, cy + 1, "|-", EXP_COR_SUAVE);
        }

        gpu_desenhar_icone(sel ? icone_pasta_aberta : icone_pasta_fechada,
                           tree_x + 8 + indent, cy, 16, 16);
        gui_texto(tree_x + 28 + indent, cy + 2, p, sel ? EXP_COR_CIANO : EXP_COR_TEXTO);
        cy += 22;
    }

    /* Painel Direito: Conteudo da Pasta Selecionada */
    int pane_x = tree_x + tree_w + 8;
    int pane_y = tree_y;
    int pane_w = w - tree_w - 28;
    int pane_h = tree_h;

    gui_retangulo(pane_x, pane_y, pane_w, pane_h, EXP_COR_FUNDO_DIR);
    gui_borda(pane_x, pane_y, pane_w, pane_h, 0xFF4C2889);

    int px = pane_x + 12;
    int py = pane_y + 10;
    gui_texto(px, py, "CONTEUDO DO DIRETORIO:", EXP_COR_CIANO);
    py += 20;
    gui_texto(px, py, caminho_ativo, EXP_COR_VERDE);
    py += 26;

    if (exp_contem(caminho_ativo, "sistema") || exp_contem(caminho_ativo, "drivers")) {
        gui_texto(px, py, "[BIN] kernel.bin        (64-bit Ring 0)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[DRV] vesafb.sys        (Linear Framebuffer)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[DRV] e1000_net.sys     (Intel Gigabit PCI)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[DRV] ata_pio28.sys     (Disco Primario)", EXP_COR_TEXTO);
    } else if (exp_contem(caminho_ativo, "apps")) {
        gui_texto(px, py, "[APP] FydelTerm.app     (Shell Nativo)", EXP_COR_VERDE); py += 20;
        gui_texto(px, py, "[APP] FydelisBrowser    (Navegador Web)", EXP_COR_CIANO); py += 20;
        gui_texto(px, py, "[APP] Calculadora.app   (Acessorios)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[APP] VisualizadorLogs  (Auditoria .flog)", EXP_COR_TEXTO);
    } else if (exp_contem(caminho_ativo, "rede")) {
        gui_texto(px, py, "[CFG] interfaces.cfg    (eth0 + wlan0)", EXP_COR_CIANO); py += 20;
        gui_texto(px, py, "[CFG] dhcp_lease.dat    (Cliente RFC 2131)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[SEC] cve_guard.sig     (Assinaturas Ativas)", EXP_COR_AMARELO);
    } else if (exp_contem(caminho_ativo, "config")) {
        gui_texto(px, py, "[CFG] sistema.fcfg      (timezone=-3)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[CFG] video_vesa.fcfg   (1024x768x32)", EXP_COR_TEXTO);
    } else if (exp_contem(caminho_ativo, "logs")) {
        gui_texto(px, py, "[LOG] boot.flog         (Inicializacao OK)", EXP_COR_VERDE); py += 20;
        gui_texto(px, py, "[LOG] rede.flog         (Eventos E1000/DHCP)", EXP_COR_TEXTO);
    } else {
        gui_texto(px, py, "[DIR] /fyd/sistema      (Nucleo & Drivers)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[DIR] /fyd/apps         (Aplicativos GUI)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[DIR] /fyd/rede         (Pilha TCP/IP & Wi-Fi)", EXP_COR_TEXTO); py += 20;
        gui_texto(px, py, "[DIR] /fyd/usuario      (Arquivos Pessoais)", EXP_COR_TEXTO);
    }

    /* Barra de status inferior */
    gui_retangulo(x + 2, y + h - 22, w - 4, 20, EXP_COR_TOPO);
    gui_texto(x + 12, y + h - 19, "Clique em uma pasta na arvore ao lado para abrir", EXP_COR_SUAVE);
}

static void explorer_on_click(int rel_x, int rel_y) {
    int tree_x = 10;
    int tree_y = 64;
    int tree_w = 225;
    int tree_h = app_explorer.h - 94;

    if (rel_x >= tree_x && rel_x <= tree_x + tree_w &&
        rel_y >= tree_y + 24 && rel_y <= tree_y + tree_h) {
        int idx = (rel_y - (tree_y + 24)) / 22;
        int total = 0;
        exp_obter_pasta(0, &total);
        if (idx >= 0 && idx < total) {
            exp_indice_selecionado = idx;
        }
    }
}

static void explorer_on_key(char tecla) {
    int total = 0;
    exp_obter_pasta(0, &total);
    if (total <= 0) return;

    if (tecla == '\t' || tecla == 's' || tecla == 'S') {
        exp_indice_selecionado = (exp_indice_selecionado + 1) % total;
    } else if (tecla == 'w' || tecla == 'W') {
        exp_indice_selecionado = (exp_indice_selecionado - 1 + total) % total;
    }
}

FydelisApp app_explorer = {
    .aberta   = 0,
    .x        = 110,
    .y        = 65,
    .w        = 610,
    .h        = 350,
    .abrir    = explorer_abrir,
    .desenhar = explorer_desenhar,
    .on_click = explorer_on_click,
    .on_key   = explorer_on_key
};
