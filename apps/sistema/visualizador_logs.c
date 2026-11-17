#include <stdint.h>
#include "../apps.h"
#include "../../include/fydlog.h"

/* Primitivas gráficas exportadas pelo kernel/exec.c */
extern void desenhar_retangulo_solido(int x, int y, int w, int h, uint32_t cor);
extern void desenhar_caixa_com_borda(int x, int y, int w, int h, int borda, uint32_t cor_borda, uint32_t cor_fundo);
extern void gpu_escrever_texto(const char *texto, int x, int y, uint32_t cor);

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
    .titulo   = "FydLog - /fyd/dados/logs/sistema.flog",
    .x        = 180,
    .y        = 95,
    .w        = 600,
    .h        = 360,
    .aberta   = 0,
    .abrir    = vlog_abrir,
    .desenhar = vlog_desenhar,
    .on_click = vlog_on_click,
    .on_key   = vlog_on_key
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
    desenhar_caixa_com_borda(x, y, w, h, 2, LOG_COR_BORDA, LOG_COR_FUNDO);
    desenhar_retangulo_solido(x + 2, y + 2, w - 4, 26, LOG_COR_BARRA);
    gpu_escrever_texto(app_visualizador_logs.titulo, x + 10, y + 7, LOG_COR_CIANO);

    /* Botão Fechar [X] */
    desenhar_retangulo_solido(x + w - 24, y + 4, 20, 20, LOG_COR_VERMELHO);
    gpu_escrever_texto("X", x + w - 18, y + 6, LOG_COR_TEXTO);

    /* Barra de ferramentas superior (Subir, Descer, Atualizar, Testar Log) */
    int tb_y = y + 34;
    desenhar_caixa_com_borda(x + 12, tb_y, 76, 22, 1, LOG_COR_BORDA, LOG_COR_BTN);
    gpu_escrever_texto("Subir", x + 28, tb_y + 4, LOG_COR_TEXTO);

    desenhar_caixa_com_borda(x + 96, tb_y, 82, 22, 1, LOG_COR_BORDA, LOG_COR_BTN);
    gpu_escrever_texto("Descer", x + 111, tb_y + 4, LOG_COR_TEXTO);

    desenhar_caixa_com_borda(x + 186, tb_y, 96, 22, 1, LOG_COR_CIANO, LOG_COR_BTN);
    gpu_escrever_texto("Atualizar", x + 198, tb_y + 4, LOG_COR_CIANO);

    desenhar_caixa_com_borda(x + 290, tb_y, 118, 22, 1, LOG_COR_VERDE, LOG_COR_BTN);
    gpu_escrever_texto("+ Evento Teste", x + 298, tb_y + 4, LOG_COR_VERDE);

    /* Área de leitura do arquivo .flog */
    int vx = x + 12;
    int vy = y + 64;
    int vw = w - 24;
    int vh = h - 88;
    desenhar_caixa_com_borda(vx, vy, vw, vh, 1, 0xFF4C2889, LOG_COR_VISOR);

    const char *buf = fydlog_obter_buffer();
    if (!buf || !buf[0]) {
        gpu_escrever_texto("Nenhum registro encontrado em /fyd/dados/logs/sistema.flog.", vx + 12, vy + 14, LOG_COR_SUAVE);
        return;
    }

    /* Avança até linha_topo */
    int linha_atual = 0;
    const char *p = buf;
    while (*p && linha_atual < linha_topo) {
        if (*p == '\n') linha_atual++;
        p++;
    }

    /* Renderiza até MAX_LINHAS_VISIVEIS */
    int desenhadas = 0;
    char linha_tmp[MAX_CHARS_LINHA + 1];

    while (*p && desenhadas < MAX_LINHAS_VISIVEIS) {
        int i = 0;
        while (*p && *p != '\n' && i < MAX_CHARS_LINHA) {
            linha_tmp[i++] = *p++;
        }
        linha_tmp[i] = '\0';

        /* Se a linha for maior que o visor, avança até o próximo '\n' */
        while (*p && *p != '\n') p++;
        if (*p == '\n') p++;

        uint32_t cor = log_cor_por_nivel(linha_tmp);
        gpu_escrever_texto(linha_tmp, vx + 10, vy + 10 + (desenhadas * 17), cor);
        desenhadas++;
    }

    /* Rodapé informativo */
    gpu_escrever_texto("Formato: #!FYDLOG v1 | Use Setas Cima/Baixo ou os botoes acima.", x + 14, y + h - 18, LOG_COR_SUAVE);
}

static void vlog_on_click(int rel_x, int rel_y) {
    const char *buf = fydlog_obter_buffer();
    int total = log_contar_linhas(buf);
    int max_topo = (total > MAX_LINHAS_VISIVEIS) ? (total - MAX_LINHAS_VISIVEIS) : 0;

    /* Cliques na barra de ferramentas (tb_y = 34..56) */
    if (rel_y >= 34 && rel_y <= 56) {
        if (rel_x >= 12 && rel_x <= 88) {
            /* Subir */
            if (linha_topo > 0) linha_topo--;
        } else if (rel_x >= 96 && rel_x <= 178) {
            /* Descer */
            if (linha_topo < max_topo) linha_topo++;
        } else if (rel_x >= 186 && rel_x <= 282) {
            /* Atualizar -> vai para o final */
            linha_topo = max_topo;
        } else if (rel_x >= 290 && rel_x <= 408) {
            /* Grava evento manual de diagnóstico */
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
