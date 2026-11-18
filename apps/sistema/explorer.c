#include "../apps.h"
#include "../../include/fyd_formatos.h"
#include <stdint.h>
#include <stddef.h>

/* Primitivas gráficas do motor (exec.c / gpu.h) */
extern void gui_retangulo(int x, int y, int w, int h, uint32_t cor);
extern void gui_borda(int x, int y, int w, int h, uint32_t cor);
extern void gui_texto(int x, int y, const char *str, uint32_t cor);
extern void gpu_desenhar_icone(const uint32_t *pixels, int x, int y, int w, int h);

extern const uint32_t icone_pasta_aberta[];
extern const uint32_t icone_pasta_fechada[];
extern const char **fs_obter_lista_pastas(void);
extern uint64_t fs_total_pastas(void);

#define EXP_COR_PAINEL      0xFF1E0E3D
#define EXP_COR_TOPO        0xFF120826
#define EXP_COR_FUNDO_LISTA 0xFF160A2E
#define EXP_COR_ITEM_SEL    0xFF3B1D75
#define EXP_COR_ROXO        0xFF9D4EDD
#define EXP_COR_CIANO       0xFF00F5D4
#define EXP_COR_VERDE       0xFF00FF9C
#define EXP_COR_VERMELHO    0xFFFF4D6D
#define EXP_COR_TEXTO       0xFFF8FAFC
#define EXP_COR_SUAVE       0xFFCBD5E1

static int exp_indice_selecionado = 0;

static void explorer_abrir(void) {
    app_explorer.aberta = 1;
}

static void explorer_desenhar(void) {
    if (!app_explorer.aberta) return;

    int x = app_explorer.x;
    int y = app_explorer.y;
    int w = app_explorer.w;
    int h = app_explorer.h;

    /* Moldura e barra de título */
    gui_retangulo(x, y, w, h, EXP_COR_PAINEL);
    gui_borda(x, y, w, h, EXP_COR_ROXO);
    gui_retangulo(x + 2, y + 2, w - 4, 26, EXP_COR_TOPO);

    gpu_desenhar_icone(icone_pasta_aberta, x + 8, y + 6, 16, 16);
    gui_texto(x + 30, y + 7, "FydelisExplorer - Sistema de Arquivos", EXP_COR_CIANO);

    /* Botão [X] */
    gui_retangulo(x + w - 24, y + 4, 20, 20, EXP_COR_VERMELHO);
    gui_texto(x + w - 18, y + 6, "X", EXP_COR_TEXTO);

    /* Barra de caminho atual */
    const char **pastas = fs_obter_lista_pastas();
    uint64_t total = fs_total_pastas();
    const char *caminho_ativo = (total > 0 && exp_indice_selecionado < (int)total)
        ? pastas[exp_indice_selecionado]
        : "/fyd";

    gui_retangulo(x + 12, y + 34, w - 24, 24, EXP_COR_FUNDO_LISTA);
    gui_borda(x + 12, y + 34, w - 24, 24, 0xFF4C2889);
    gui_texto(x + 18, y + 38, "Local:", EXP_COR_SUAVE);
    gui_texto(x + 72, y + 38, caminho_ativo, EXP_COR_VERDE);

    /* Área da lista de diretórios */
    int list_x = x + 12;
    int list_y = y + 66;
    int list_w = w - 24;
    int list_h = h - 78;

    gui_retangulo(list_x, list_y, list_w, list_h, EXP_COR_FUNDO_LISTA);
    gui_borda(list_x, list_y, list_w, list_h, 0xFF4C2889);

    int max_linhas = (list_h - 12) / 24;
    if ((int)total < max_linhas) max_linhas = (int)total;

    int cy = list_y + 8;
    for (int i = 0; i < max_linhas; i++) {
        int sel = (i == exp_indice_selecionado);
        if (sel) {
            gui_retangulo(list_x + 6, cy - 2, list_w - 12, 22, EXP_COR_ITEM_SEL);
            gui_borda(list_x + 6, cy - 2, list_w - 12, 22, EXP_COR_CIANO);
        }

        gpu_desenhar_icone(sel ? icone_pasta_aberta : icone_pasta_fechada,
                           list_x + 12, cy, 16, 16);
        gui_texto(list_x + 36, cy + 2, pastas[i], sel ? EXP_COR_CIANO : EXP_COR_TEXTO);
        cy += 24;
    }
}

static void explorer_on_click(int rel_x, int rel_y) {
    int list_y = 66;
    int list_h = app_explorer.h - 78;

    if (rel_x >= 12 && rel_x <= app_explorer.w - 12 &&
        rel_y >= list_y + 8 && rel_y <= list_y + list_h) {
        int idx = (rel_y - (list_y + 8)) / 24;
        uint64_t total = fs_total_pastas();
        if (idx >= 0 && idx < (int)total) {
            exp_indice_selecionado = idx;
        }
    }
}

static void explorer_on_key(char tecla) {
    uint64_t total = fs_total_pastas();
    if (total == 0) return;

    if (tecla == '\t' || tecla == 's' || tecla == 'S') {
        exp_indice_selecionado = (exp_indice_selecionado + 1) % (int)total;
    }
}

FydelisApp app_explorer = {
    .aberta   = 0,
    .x        = 130,
    .y        = 75,
    .w        = 480,
    .h        = 330,
    .abrir    = explorer_abrir,
    .desenhar = explorer_desenhar,
    .on_click = explorer_on_click,
    .on_key   = explorer_on_key
};
