#include <stdint.h>
#include "../apps.h"
#include "../../include/fydlog.h"

/* Paleta Cyberpunk Purple & Neon */
#define LOG_COR_FUNDO      0xFF1A0B36
#define LOG_COR_BARRA      0xFF281352
#define LOG_COR_VISOR      0xFF100622
#define LOG_COR_BORDA      0xFF9D4EDD
#define LOG_COR_CIANO      0xFF00F5D4
#define LOG_COR_VERDE      0xFF00FF9C
#define LOG_COR_AMARELO    0xFFFFD166
#define LOG_COR_VERMELHO   0xFFFF4D6D
#define LOG_COR_TEXTO      0xFFF8FAFC
#define LOG_COR_SUAVE      0xFF94A3B8
#define LOG_COR_BTN        0xFF3B1D75

#define MAX_LINHAS_VISIVEIS 15
#define MAX_CHARS_LINHA     68

static int linha_topo = 0;

static int log_strncmp(const char *a, const char *b, int n) {
    for (int i = 0; i < n; i++) {
        if (a[i] != b[i]) return 1;
        if (a[i] == '\0') return 0;
    }
    return 0;
}

static int log_contar_linhas(const char *buf) {
    if (!buf || !buf[0]) return 0;
    int linhas = 1;
    for (int i = 0; buf[i]; i++) {
        if (buf[i] == '\n' && buf[i + 1] != '\0') linhas++;
    }
    return linhas;
}

static uint32_t log_cor_por_nivel(const char *linha) {
    if (linha[0] == '#') return LOG_COR_SUAVE;
    if (log_strncmp(linha, "[INFO]", 6) == 0)    return LOG_COR_VERDE;
    if (log_strncmp(linha, "[AVISO]", 7) == 0)   return LOG_COR_AMARELO;
    if (log_strncmp(linha, "[ERRO]", 6) == 0)    return LOG_COR_VERMELHO;
    if (log_strncmp(linha, "[CRITICO]", 9) == 0) return LOG_COR_VERMELHO;
    return LOG_COR_TEXTO;
}

static void vlog_abrir(void);
static void vlog_desenhar(void);
static void vlog_on_click(int rel_x, int rel_y);
static void vlog_on_key(char tecla);

FydelisApp app_visualizador_logs = {
    .nome      = "FydLog - /fyd/dados/logs/sistema.flog",
    .categoria = CAT_SISTEMA,
    .aberta    = 0,
    .x         = 180,
    .y         = 95,
    .w         = 600,
    .h         = 360,
    .abrir     = vlog_abrir,
    .desenhar  = vlog_desenhar,
    .on_click  = vlog_on_click,
    .on_key    = vlog_on_key
};

static void vlog_abrir(void) {
    app_visualizador_logs.aberta = 1;
    const char *buf = fydlog_obter_buffer();
    int total = log_contar_linhas(buf);
    linha_topo = (total > MAX_LINHAS_VISIVEIS) ? (total - MAX_LINHAS_VISIVEIS) : 0;
}

static void vlog_desenhar(void) {
    if (!app_visualizador_logs.aberta) return;

    int x = app_visualizador_logs.x;
    int y = app_visualizador_logs.y;
    int w = app_visualizador_logs.w;
    int h = app_visualizador_logs.h;

    /* Moldura e Barra de Título */
    gui_retangulo(x, y, w, h, LOG_COR_FUNDO);
    gui_borda(x, y, w, h, LOG_COR_BORDA);
    gui_retangulo(x + 2, y + 2, w - 4, 26, LOG_COR_BARRA);
    gui_texto(x + 10, y + 7, app_visualizador_logs.nome, LOG_COR_CIANO);

    /* Botão Fechar [X] */
    gui_retangulo(x + w - 24, y + 4, 20, 20, LOG_COR_VERMELHO);
    gui_texto(x + w - 18, y + 6, "X", LOG_COR_TEXTO);

    /* Barra de ferramentas superior */
    int tb_y = y + 34;
    gui_retangulo(x + 12, tb_y, 76, 22, LOG_COR_BTN);
    gui_borda(x + 12, tb_y, 76, 22, LOG_COR_BORDA);
    gui_texto(x + 28, tb_y + 4, "Subir", LOG_COR_TEXTO);

    gui_retangulo(x + 96, tb_y, 82, 22, LOG_COR_BTN);
    gui_borda(x + 96, tb_y, 82, 22, LOG_COR_BORDA);
    gui_texto(x + 111, tb_y + 4, "Descer", LOG_COR_TEXTO);

    gui_retangulo(x + 186, tb_y, 96, 22, LOG_COR_BTN);
    gui_borda(x + 186, tb_y, 96, 22, LOG_COR_CIANO);
    gui_texto(x + 198, tb_y + 4, "Atualizar", LOG_COR_CIANO);

    gui_retangulo(x + 290, tb_y, 118, 22, LOG_COR_BTN);
    gui_borda(x + 290, tb_y, 118, 22, LOG_COR_VERDE);
    gui_texto(x + 298, tb_y + 4, "+ Evento Teste", LOG_COR_VERDE);

    /* Área de leitura do arquivo .flog */
    int vx = x + 12;
    int vy = y + 64;
    int vw = w - 24;
    int vh = h - 88;
    gui_retangulo(vx, vy, vw, vh, LOG_COR_VISOR);
    gui_borda(vx, vy, vw, vh, 0xFF4C2889);

    const char *buf = fydlog_obter_buffer();
    if (!buf || !buf[0]) {
        gui_texto(vx + 12, vy + 14, "Nenhum registro encontrado em /fyd/dados/logs/sistema.flog.", LOG_COR_SUAVE);
        return;
    }

    int linha_atual = 0;
    const char *p = buf;
    while (*p && linha_atual < linha_topo) {
        if (*p == '\n') linha_atual++;
        p++;
    }

    int desenhadas = 0;
    char linha_tmp[MAX_CHARS_LINHA + 1];

    while (*p && desenhadas < MAX_LINHAS_VISIVEIS) {
        int i = 0;
        while (*p && *p != '\n' && i < MAX_CHARS_LINHA) {
            linha_tmp[i++] = *p++;
        }
        linha_tmp[i] = '\0';

        while (*p && *p != '\n') p++;
        if (*p == '\n') p++;

        uint32_t cor = log_cor_por_nivel(linha_tmp);
        gui_texto(vx + 10, vy + 10 + (desenhadas * 17), linha_tmp, cor);
        desenhadas++;
    }

    gui_texto(x + 14, y + h - 18, "Formato: #!FYDLOG v1 | Use W/S ou os botoes acima para rolar.", LOG_COR_SUAVE);
}

static void vlog_on_click(int rel_x, int rel_y) {
    const char *buf = fydlog_obter_buffer();
    int total = log_contar_linhas(buf);
    int max_topo = (total > MAX_LINHAS_VISIVEIS) ? (total - MAX_LINHAS_VISIVEIS) : 0;

    if (rel_y >= 34 && rel_y <= 56) {
        if (rel_x >= 12 && rel_x <= 88) {
            if (linha_topo > 0) linha_topo--;
        } else if (rel_x >= 96 && rel_x <= 178) {
            if (linha_topo < max_topo) linha_topo++;
        } else if (rel_x >= 186 && rel_x <= 282) {
            linha_topo = max_topo;
        } else if (rel_x >= 290 && rel_x <= 408) {
            fydlog_escrever(LOG_INFO, "Evento de diagnostico registrado pelo Visualizador");
            total = log_contar_linhas(fydlog_obter_buffer());
            linha_topo = (total > MAX_LINHAS_VISIVEIS) ? (total - MAX_LINHAS_VISIVEIS) : 0;
        }
    }
}

static void vlog_on_key(char tecla) {
    const char *buf = fydlog_obter_buffer();
    int total = log_contar_linhas(buf);
    int max_topo = (total > MAX_LINHAS_VISIVEIS) ? (total - MAX_LINHAS_VISIVEIS) : 0;

    if (tecla == 'w' || tecla == 'W') {
        if (linha_topo > 0) linha_topo--;
    } else if (tecla == 's' || tecla == 'S') {
        if (linha_topo < max_topo) linha_topo++;
    }
}
