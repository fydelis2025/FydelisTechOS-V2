#include "../apps/apps.h"
#include <stdint.h>
#include <stddef.h>

extern void gui_retangulo(int x, int y, int w, int h, uint32_t cor);
extern void gui_borda(int x, int y, int w, int h, uint32_t cor);
extern void gui_texto(int x, int y, const char *str, uint32_t cor);

#define BRW_COR_PAINEL      0xFF1E0E3D
#define BRW_COR_TOPO        0xFF120826
#define BRW_COR_VIEW        0xFF120726
#define BRW_COR_INPUT       0xFF160A2E
#define BRW_COR_BTN         0xFF3B1D75
#define BRW_COR_ROXO        0xFF9D4EDD
#define BRW_COR_CIANO       0xFF00F5D4
#define BRW_COR_VERDE       0xFF00FF9C
#define BRW_COR_AMARELO     0xFFFFD166
#define BRW_COR_VERMELHO    0xFFFF4D6D
#define BRW_COR_TEXTO       0xFFF8FAFC
#define BRW_COR_SUAVE       0xFFCBD5E1

static char brw_url[64] = "fydelis://home";
static int  brw_url_len = 14;
static int  brw_foco_url = 0;
static int  brw_pagina_id = 0; /* 0 = home, 1 = rede, 2 = cve, 3 = externa */

static int brw_str_eq(const char *a, const char *b) {
    int i = 0;
    while (a[i] && b[i]) {
        if (a[i] != b[i]) return 0;
        i++;
    }
    return a[i] == b[i];
}

static void brw_set_url(const char *nova) {
    int i = 0;
    while (nova[i] && i < 62) {
        brw_url[i] = nova[i];
        i++;
    }
    brw_url[i] = '\0';
    brw_url_len = i;
}

static void browser_navegar(void) {
    if (brw_str_eq(brw_url, "fydelis://home") || brw_str_eq(brw_url, "home")) {
        brw_pagina_id = 0;
    } else if (brw_str_eq(brw_url, "fydelis://rede") || brw_str_eq(brw_url, "rede")) {
        brw_pagina_id = 1;
    } else if (brw_str_eq(brw_url, "fydelis://cve") || brw_str_eq(brw_url, "cve")) {
        brw_pagina_id = 2;
    } else {
        brw_pagina_id = 3;
    }
}

static void browser_abrir(void) {
    app_browser.aberta = 1;
    browser_navegar();
}

static void browser_desenhar(void) {
    if (!app_browser.aberta) return;

    int x = app_browser.x;
    int y = app_browser.y;
    int w = app_browser.w;
    int h = app_browser.h;

    /* Moldura e cabeçalho */
    gui_retangulo(x, y, w, h, BRW_COR_PAINEL);
    gui_borda(x, y, w, h, BRW_COR_CIANO);
    gui_retangulo(x + 2, y + 2, w - 4, 26, BRW_COR_TOPO);
    gui_texto(x + 12, y + 7, "FydelisBrowser v1.0 - Motor Web Nativo", BRW_COR_CIANO);

    /* Botão [X] */
    gui_retangulo(x + w - 24, y + 4, 20, 20, BRW_COR_VERMELHO);
    gui_texto(x + w - 18, y + 6, "X", BRW_COR_TEXTO);

    /* Barra de navegação: [Home] + [URL Input] + [Ir] */
    int nav_y = y + 34;
    gui_retangulo(x + 10, nav_y, 52, 24, BRW_COR_BTN);
    gui_borda(x + 10, nav_y, 52, 24, BRW_COR_ROXO);
    gui_texto(x + 18, nav_y + 4, "Home", BRW_COR_TEXTO);

    int url_x = x + 68;
    int url_w = w - 124;
    gui_retangulo(url_x, nav_y, url_w, 24, BRW_COR_INPUT);
    gui_borda(url_x, nav_y, url_w, 24, brw_foco_url ? BRW_COR_CIANO : BRW_COR_ROXO);
    gui_texto(url_x + 8, nav_y + 4, brw_url, BRW_COR_TEXTO);
    if (brw_foco_url) {
        gui_texto(url_x + 8 + (brw_url_len * 8), nav_y + 4, "_", BRW_COR_CIANO);
    }

    int go_x = x + w - 50;
    gui_retangulo(go_x, nav_y, 40, 24, BRW_COR_BTN);
    gui_borda(go_x, nav_y, 40, 24, BRW_COR_CIANO);
    gui_texto(go_x + 12, nav_y + 4, "Ir", BRW_COR_CIANO);

    /* Barra de favoritos clicáveis */
    int fav_y = nav_y + 28;
    gui_texto(x + 12, fav_y + 2, "Favoritos:", BRW_COR_SUAVE);
    gui_texto(x + 100, fav_y + 2, "[Inicio]", BRW_COR_CIANO);
    gui_texto(x + 176, fav_y + 2, "[Status Rede]", BRW_COR_VERDE);
    gui_texto(x + 292, fav_y + 2, "[CVE Guard]", BRW_COR_AMARELO);

    /* Área de renderização da página */
    int view_x = x + 10;
    int view_y = fav_y + 22;
    int view_w = w - 20;
    int view_h = h - 108;

    gui_retangulo(view_x, view_y, view_w, view_h, BRW_COR_VIEW);
    gui_borda(view_x, view_y, view_w, view_h, 0xFF4C2889);

    int tx = view_x + 14;
    int ty = view_y + 12;

    if (brw_pagina_id == 0) {
        gui_texto(tx, ty, "PORTAL INTRANET - FYDELISTECH OS v4.2", BRW_COR_CIANO);
        ty += 24;
        gui_texto(tx, ty, "Navegador rodando em Ring 0 (64-bit Freestanding).", BRW_COR_TEXTO);
        ty += 22;
        gui_texto(tx, ty, "Clique nos favoritos acima ou digite uma URL e tecle ENTER:", BRW_COR_SUAVE);
        ty += 26;
        gui_texto(tx, ty, "> fydelis://home  - Pagina inicial do sistema", BRW_COR_VERDE);
        ty += 20;
        gui_texto(tx, ty, "> fydelis://rede  - Diagnostico TCP/IP, E1000 e Wi-Fi", BRW_COR_VERDE);
        ty += 20;
        gui_texto(tx, ty, "> fydelis://cve   - Assinaturas ativas do CVE Guard", BRW_COR_VERDE);
    } else if (brw_pagina_id == 1) {
        gui_texto(tx, ty, "DIAGNOSTICO DE REDE & INTERFACES", BRW_COR_VERDE);
        ty += 24;
        gui_texto(tx, ty, "Interface 0 (eth0): Controlador Intel E1000 MMIO", BRW_COR_TEXTO);
        ty += 20;
        gui_texto(tx, ty, "Interface 1 (wlan0): Driver 802.11 + WPA2 + DHCP", BRW_COR_TEXTO);
        ty += 20;
        gui_texto(tx, ty, "Pilha Protocolos: Ethernet / ARP / IPv4 / ICMP / UDP", BRW_COR_CIANO);
    } else if (brw_pagina_id == 2) {
        gui_texto(tx, ty, "FYDELIS CVE GUARD - ESCUDO ATIVO DO KERNEL", BRW_COR_AMARELO);
        ty += 24;
        gui_texto(tx, ty, "[ATIVO] CVE-2024-3094  - Bloqueio de payload XZ Backdoor", BRW_COR_TEXTO);
        ty += 20;
        gui_texto(tx, ty, "[ATIVO] CVE-2021-44228 - Filtro JNDI/LDAP Log4Shell", BRW_COR_TEXTO);
        ty += 20;
        gui_texto(tx, ty, "[ATIVO] FYD-MEM-001    - Deteccao de NOP sled 0x90909090", BRW_COR_TEXTO);
    } else {
        gui_texto(tx, ty, "AGUARDANDO CONEXAO HTTP EXTERNA (PORTA 80)", BRW_COR_AMARELO);
        ty += 24;
        gui_texto(tx, ty, "Endereco solicitado:", BRW_COR_SUAVE);
        gui_texto(tx + 170, ty, brw_url, BRW_COR_CIANO);
        ty += 24;
        gui_texto(tx, ty, "Dica: Use fydelis://home, fydelis://rede ou fydelis://cve", BRW_COR_TEXTO);
    }

    /* Barra de status */
    gui_retangulo(x + 2, y + h - 20, w - 4, 18, BRW_COR_TOPO);
    gui_texto(x + 10, y + h - 18, "Pronto | Clique na barra de URL para digitar", BRW_COR_VERDE);
}

static void browser_on_click(int rel_x, int rel_y) {
    int nav_y = 34;
    int fav_y = nav_y + 28;

    /* Botão [Home] */
    if (rel_x >= 10 && rel_x <= 62 && rel_y >= nav_y && rel_y <= nav_y + 24) {
        brw_set_url("fydelis://home");
        brw_foco_url = 0;
        browser_navegar();
        return;
    }

    /* Caixa de URL */
    if (rel_x >= 68 && rel_x <= app_browser.w - 56 && rel_y >= nav_y && rel_y <= nav_y + 24) {
        brw_foco_url = 1;
        return;
    }

    /* Botão [Ir] */
    if (rel_x >= app_browser.w - 50 && rel_x <= app_browser.w - 10 && rel_y >= nav_y && rel_y <= nav_y + 24) {
        brw_foco_url = 0;
        browser_navegar();
        return;
    }

    /* Barra de Favoritos */
    if (rel_y >= fav_y && rel_y <= fav_y + 18) {
        if (rel_x >= 100 && rel_x <= 165) {
            brw_set_url("fydelis://home");
            browser_navegar();
        } else if (rel_x >= 176 && rel_x <= 282) {
            brw_set_url("fydelis://rede");
            browser_navegar();
        } else if (rel_x >= 292 && rel_x <= 385) {
            brw_set_url("fydelis://cve");
            browser_navegar();
        }
        brw_foco_url = 0;
        return;
    }

    brw_foco_url = 0;
}

static void browser_on_key(char tecla) {
    if (!brw_foco_url) return;

    if (tecla == '\n') {
        brw_foco_url = 0;
        browser_navegar();
    } else if (tecla == '\b') {
        if (brw_url_len > 0) {
            brw_url[--brw_url_len] = '\0';
        }
    } else if (tecla >= 32 && tecla <= 126 && brw_url_len < 62) {
        brw_url[brw_url_len++] = tecla;
        brw_url[brw_url_len] = '\0';
    }
}

FydelisApp app_browser = {
    .aberta   = 0,
    .x        = 170,
    .y        = 85,
    .w        = 560,
    .h        = 360,
    .abrir    = browser_abrir,
    .desenhar = browser_desenhar,
    .on_click = browser_on_click,
    .on_key   = browser_on_key
};
