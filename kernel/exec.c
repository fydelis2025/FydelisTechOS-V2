/* ============================================================================
- FydelisTech OS v4.2 — Motor Gráfico, Window Manager & Desktop Interativo
- Arquitetura: x86_64 Freestanding | VESA Linear Framebuffer 32-bit + PS/2
- Otimizado: Wallpapers via Disco ATA PIO28, Cursor Sincronizado e Polling PS/2
- ============================================================================ */
#include "../apps/apps.h"
#include "../include/fyd_formatos.h"
#include "../include/fydlog.h"
#include "syscalls/gpu.h"
#include "icones.h"
#include "fontes_ui.h"
#include "fydelis_core.h"
#include <stdint.h>
#include <stddef.h>

/* Paleta Cyberpunk Purple & Neon — FydelisTech OS */
#undef COR_ROXO_NEON
#undef COR_CIANO_NEON
#define COR_FUNDO_ESCURO    0xFF120826
#define COR_PAINEL          0xFF1E0E3D
#define COR_PAINEL_SEC      0xFF160A2E
#define COR_CARD            0xFF281352
#define COR_INPUT_BG        0xFF160A2E
#define COR_HOVER           0xFF3B1D75
#define COR_ROXO_NEON       0xFF9D4EDD
#define COR_ROXO_CLARO      0xFFC77DFF
#define COR_CIANO_NEON      0xFF00F5D4
#define COR_VERDE_NEON      0xFF00FF9C
#define COR_VERMELHO_ALERTA 0xFFFF4D6D
#define COR_TEXTO_BRANCO    0xFFF8FAFC
#define COR_TEXTO_SUAVE     0xFFCBD5E1
#define COR_BORDA_SUTIL     0xFF4C2889

/* ============================================================================
 * INTEGRAÇÃO DRIVER WI-FI & DHCP (Símbolos exportados pelo Assembly/Drivers)
 * ============================================================================ */
#define MAX_REDES_WIFI 32

typedef struct __attribute__((packed)) {
    char    ssid[33];         /* Offset 0..32 */
    uint8_t canal;            /* Offset 33 */
    uint8_t potencia;         /* Offset 34 */
    uint8_t seguranca;        /* Offset 35: 0 = Aberta, 1 = WPA2 */
    uint8_t bssid[6];         /* Offset 36..41 */
    uint8_t reservado[22];    /* Offset 42..63 -> Total = 64 bytes */
} WifiRede;

extern WifiRede wifi_scan_lista[MAX_REDES_WIFI];

extern int      wifi_detectar_placa(void);
extern int      wifi_inicializar(void);
extern int      sys_wifi_scan(void);
extern int      sys_wifi_conectar(const char *ssid);
extern void     sys_wifi_desconectar(void);
extern uint64_t wifi_ler_status(void);
extern void     dhcp_cliente_iniciar(void);

/* ============================================================================
 * POPUP DE REDES WI-FI (SYSTRAY ICON)
 * ============================================================================ */
#define WIFI_POP_W          280
#define WIFI_POP_H          260
#define WIFI_MAX_VISIVEIS   6

/* Paleta Cyberpunk Purple & Neon */
#define WIFI_COR_FUNDO      0xFF1A0B36
#define WIFI_COR_BARRA      0xFF281352
#define WIFI_COR_ITEM       0xFF120726
#define WIFI_COR_ITEM_SEL   0xFF3B1D75
#define WIFI_COR_BORDA      0xFF9D4EDD
#define WIFI_COR_CIANO      0xFF00F5D4
#define WIFI_COR_VERDE      0xFF00FF9C
#define WIFI_COR_AMARELO    0xFFFFD166
#define WIFI_COR_VERMELHO   0xFFFF4D6D
#define WIFI_COR_TEXTO      0xFFF8FAFC
#define WIFI_COR_SUAVE      0xFF94A3B8

static int  wifi_popup_aberto = 0;
static int  wifi_indice_selecionado = -1;
static char wifi_status_msg[48] = "Pronto para escanear";

/* Variáveis exportadas pelo driver VESA (vesafb.asm) */
extern uint32_t *fb_base;
extern uint32_t  fb_largura;
extern uint32_t  fb_altura;
extern uint32_t  fb_pitch;

/* Drivers Assembly (mouse.asm, fb_server.asm, rede_bridge.asm, timer.asm) */
extern uint64_t mouse_inicializar(void);
extern uint64_t ws_inicializar(void);
extern void     ws_atualizar_cursor(void);
extern void     cursor_restaurar_fundo(void);
extern void     cursor_desenhar_novo(void);
extern uint64_t rede_ler_status_link(void);
extern uint64_t timer_ler_ticks(void);
extern uint64_t bt_detectar_placa(void);
extern uint64_t bt_inicializar(void);
extern uint64_t bt_ler_status(void);
extern void     audio_init(void);
extern uint64_t audio_ler_status(void);
extern uint64_t detectar_disco(uint64_t numero_disco);
extern uint64_t obter_tamanho_disco(void);

extern const char *fs_ler_config_padrao(void);
extern FydelisApp app_visualizador_logs;
extern FydelisApp app_explorer;
extern FydelisApp app_browser;

enum {
    MODO_JANELA_SISTEMA  = 1,
    MODO_JANELA_APPS     = 3,
    MODO_JANELA_CONFIG   = 4
};

typedef struct {
    uint8_t seg;
    uint8_t min;
    uint8_t hora;
    uint8_t dia;
    uint8_t mes;
    uint8_t ano;
} RtcDataHora;

typedef struct {
    const char     *rotulo;
    const uint32_t *icone;
    int             coluna;
    int             acao_id;
} ItemMenuIniciar;

typedef struct {
    char     cpu_vendor[16];
    int      cpu_uso_pct;
    uint32_t ram_total_mb;
    uint32_t ram_usada_mb;
    uint32_t disco_total_mb;
    int      disco_online;
} TelemetriaSistema;

static inline uint64_t ler_tsc(void) {
    uint32_t lo, hi;
    __asm__ volatile ("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

/* Evita travamento quando PIC legado esta mascarado (0xFF) sem IRQs ativas */
static inline void descansar_cpu_hlt(void) {
    __asm__ volatile ("pause");
}

static const ItemMenuIniciar itens_menu[] = {
    { "Explorer (/fyd)", icone_pasta_aberta,  0, 1 },
    { "FydelisBrowser",  icone_ethernet,      0, 10 },
    { "Aplicativos",     icone_iniciar,       0, 2 },
    { "FydelTerm",       icone_terminal,      0, 3 },
    { "Agenda",          icone_agenda,        0, 4 },
    { "Calculadora",     icone_config,        0, 8 },
    { "Painel Sistema",  icone_sistema,       1, 5 },
    { "Configuracoes",   icone_config,        1, 6 },
    { "Rede & Wi-Fi",    icone_ethernet,      1, 7 },
    { "Logs (.flog)",    icone_terminal,      1, 9 },
};
#define TOTAL_ITENS_MENU (int)(sizeof(itens_menu) / sizeof(itens_menu[0]))

/* ============================================================================
- RENDERIZAÇÃO DIRETA NA VRAM COM VSYNC
- ============================================================================ */
extern void fb_sincronizar_vsync(void);

static void backbuffer_iniciar_frame(void) {
    fb_sincronizar_vsync();
}

static void backbuffer_apresentar_frame(int L, int A) {
    (void)L;
    (void)A;
}

/* ============================================================================
- FONTE BITMAP 8x16 COMPLETA (ASCII 32..126)
- ============================================================================ */
static const uint8_t fonte_8x16[95][16] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 32 ' ' */
    {0x00,0x00,0x18,0x3C,0x3C,0x3C,0x18,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00}, /* 33 '!' */
    {0x00,0x66,0x66,0x66,0x24,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 34 '"' */
    {0x00,0x00,0x00,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x00,0x00,0x00,0x00}, /* 35 '#' */
    {0x00,0x18,0x18,0x7C,0xC6,0xC2,0xC0,0x7C,0x06,0x86,0xC6,0x7C,0x18,0x18,0x00,0x00}, /* 36 '$' */
    {0x00,0x00,0x00,0x00,0xC2,0xC6,0x0C,0x18,0x30,0x60,0xC6,0x86,0x00,0x00,0x00,0x00}, /* 37 '%' */
    {0x00,0x00,0x38,0x6C,0x6C,0x38,0x76,0xDC,0xCC,0xCC,0xCC,0x76,0x00,0x00,0x00,0x00}, /* 38 '&' */
    {0x00,0x30,0x30,0x30,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 39 ''' */
    {0x00,0x00,0x0C,0x18,0x30,0x30,0x30,0x30,0x30,0x30,0x18,0x0C,0x00,0x00,0x00,0x00}, /* 40 '(' */
    {0x00,0x00,0x30,0x18,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x18,0x30,0x00,0x00,0x00,0x00}, /* 41 ')' */
    {0x00,0x00,0x00,0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 42 '*' */
    {0x00,0x00,0x00,0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 43 '+' */
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x30,0x00,0x00}, /* 44 ',' */
    {0x00,0x00,0x00,0x00,0x00,0x00,0xFE,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 45 '-' */
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00}, /* 46 '.' */
    {0x00,0x00,0x02,0x06,0x0C,0x18,0x30,0x60,0xC0,0x80,0x00,0x00,0x00,0x00,0x00,0x00}, /* 47 '/' */
    {0x00,0x00,0x7C,0xC6,0xCE,0xDE,0xF6,0xE6,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 48 '0' */
    {0x00,0x00,0x18,0x38,0x78,0x18,0x18,0x18,0x18,0x18,0x7E,0x00,0x00,0x00,0x00,0x00}, /* 49 '1' */
    {0x00,0x00,0x7C,0xC6,0x06,0x0C,0x18,0x30,0x60,0xC6,0xFE,0x00,0x00,0x00,0x00,0x00}, /* 50 '2' */
    {0x00,0x00,0x7C,0xC6,0x06,0x06,0x3C,0x06,0x06,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 51 '3' */
    {0x00,0x00,0x0C,0x1C,0x3C,0x6C,0xCC,0xFE,0x0C,0x0C,0x1E,0x00,0x00,0x00,0x00,0x00}, /* 52 '4' */
    {0x00,0x00,0xFE,0xC0,0xC0,0xC0,0xFC,0x06,0x06,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 53 '5' */
    {0x00,0x00,0x38,0x60,0xC0,0xC0,0xFC,0xC6,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 54 '6' */
    {0x00,0x00,0xFE,0xC6,0x06,0x0C,0x18,0x30,0x30,0x30,0x30,0x00,0x00,0x00,0x00,0x00}, /* 55 '7' */
    {0x00,0x00,0x7C,0xC6,0xC6,0xC6,0x7C,0xC6,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 56 '8' */
    {0x00,0x00,0x7C,0xC6,0xC6,0xC6,0x7E,0x06,0x06,0x0C,0x78,0x00,0x00,0x00,0x00,0x00}, /* 57 '9' */
    {0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00}, /* 58 ':' */
    {0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x18,0x18,0x30,0x00,0x00,0x00,0x00}, /* 59 ';' */
    {0x00,0x00,0x00,0x06,0x0C,0x18,0x30,0x60,0x30,0x18,0x0C,0x06,0x00,0x00,0x00,0x00}, /* 60 '<' */
    {0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 61 '=' */
    {0x00,0x00,0x00,0x60,0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x60,0x00,0x00,0x00,0x00}, /* 62 '>' */
    {0x00,0x00,0x7C,0xC6,0xC6,0x0C,0x18,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00}, /* 63 '?' */
    {0x00,0x00,0x7C,0xC6,0xC6,0xDE,0xDE,0xDE,0xDC,0xC0,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 64 '@' */
    {0x00,0x00,0x10,0x38,0x6C,0xC6,0xC6,0xFE,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 65 'A' */
    {0x00,0x00,0xFC,0x66,0x66,0x66,0x7C,0x66,0x66,0x66,0xFC,0x00,0x00,0x00,0x00,0x00}, /* 66 'B' */
    {0x00,0x00,0x3C,0x66,0xC2,0xC0,0xC0,0xC0,0xC2,0x66,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 67 'C' */
    {0x00,0x00,0xF8,0x6C,0x66,0x66,0x66,0x66,0x66,0x6C,0xF8,0x00,0x00,0x00,0x00,0x00}, /* 68 'D' */
    {0x00,0x00,0xFE,0x66,0x62,0x68,0x78,0x68,0x62,0x66,0xFE,0x00,0x00,0x00,0x00,0x00}, /* 69 'E' */
    {0x00,0x00,0xFE,0x66,0x62,0x68,0x78,0x68,0x60,0x60,0xF0,0x00,0x00,0x00,0x00,0x00}, /* 70 'F' */
    {0x00,0x00,0x3C,0x66,0xC2,0xC0,0xC0,0xDE,0xC6,0x66,0x3A,0x00,0x00,0x00,0x00,0x00}, /* 71 'G' */
    {0x00,0x00,0xC6,0xC6,0xC6,0xC6,0xFE,0xC6,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 72 'H' */
    {0x00,0x00,0x3C,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 73 'I' */
    {0x00,0x00,0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0xCC,0xCC,0x78,0x00,0x00,0x00,0x00,0x00}, /* 74 'J' */
    {0x00,0x00,0xE6,0x66,0x6C,0x6C,0x78,0x6C,0x6C,0x66,0xE6,0x00,0x00,0x00,0x00,0x00}, /* 75 'K' */
    {0x00,0x00,0xF0,0x60,0x60,0x60,0x60,0x60,0x62,0x66,0xFE,0x00,0x00,0x00,0x00,0x00}, /* 76 'L' */
    {0x00,0x00,0xC6,0xEE,0xFE,0xFE,0xD6,0xC6,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 77 'M' */
    {0x00,0x00,0xC6,0xE6,0xF6,0xFE,0xDE,0xCE,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 78 'N' */
    {0x00,0x00,0x7C,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 79 'O' */
    {0x00,0x00,0xFC,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0xF0,0x00,0x00,0x00,0x00,0x00}, /* 80 'P' */
    {0x00,0x00,0x7C,0xC6,0xC6,0xC6,0xC6,0xC6,0xD6,0xDE,0x7C,0x0E,0x00,0x00,0x00,0x00}, /* 81 'Q' */
    {0x00,0x00,0xFC,0x66,0x66,0x66,0x7C,0x6C,0x66,0x66,0xE6,0x00,0x00,0x00,0x00,0x00}, /* 82 'R' */
    {0x00,0x00,0x7C,0xC6,0xC6,0x60,0x38,0x0C,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 83 'S' */
    {0x00,0x00,0x7E,0x7E,0x5A,0x18,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 84 'T' */
    {0x00,0x00,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 85 'U' */
    {0x00,0x00,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x6C,0x38,0x10,0x00,0x00,0x00,0x00,0x00}, /* 86 'V' */
    {0x00,0x00,0xC6,0xC6,0xC6,0xC6,0xD6,0xFE,0xFE,0x6C,0x44,0x00,0x00,0x00,0x00,0x00}, /* 87 'W' */
    {0x00,0x00,0xC6,0xC6,0x6C,0x38,0x38,0x6C,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 88 'X' */
    {0x00,0x00,0x66,0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 89 'Y' */
    {0x00,0x00,0xFE,0xC6,0x8C,0x18,0x30,0x60,0xC2,0xC6,0xFE,0x00,0x00,0x00,0x00,0x00}, /* 90 'Z' */
    {0x00,0x00,0x3C,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 91 '[' */
    {0x00,0x00,0x80,0xC0,0x60,0x30,0x18,0x0C,0x06,0x02,0x00,0x00,0x00,0x00,0x00,0x00}, /* 92 '\' */
    {0x00,0x00,0x3C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 93 ']' */
    {0x00,0x10,0x38,0x6C,0xC6,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 94 '^' */
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00}, /* 95 '_' */
    {0x00,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 96 '`' */
    {0x00,0x00,0x00,0x00,0x00,0x78,0x0C,0x7C,0xCC,0xCC,0x76,0x00,0x00,0x00,0x00,0x00}, /* 97 'a' */
    {0x00,0x00,0xE0,0x60,0x60,0x78,0x6C,0x66,0x66,0x66,0xDC,0x00,0x00,0x00,0x00,0x00}, /* 98 'b' */
    {0x00,0x00,0x00,0x00,0x00,0x7C,0xC6,0xC0,0xC0,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 99 'c' */
    {0x00,0x00,0x1C,0x0C,0x0C,0x3C,0x6C,0xCC,0xCC,0xCC,0x76,0x00,0x00,0x00,0x00,0x00}, /* 100 'd' */
    {0x00,0x00,0x00,0x00,0x00,0x7C,0xC6,0xFE,0xC0,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 101 'e' */
    {0x00,0x00,0x38,0x6C,0x64,0x60,0xF0,0x60,0x60,0x60,0xF0,0x00,0x00,0x00,0x00,0x00}, /* 102 'f' */
    {0x00,0x00,0x00,0x00,0x00,0x76,0xCC,0xCC,0xCC,0x7C,0x0C,0xCC,0x78,0x00,0x00,0x00}, /* 103 'g' */
    {0x00,0x00,0xE0,0x60,0x60,0x6C,0x76,0x66,0x66,0x66,0xE6,0x00,0x00,0x00,0x00,0x00}, /* 104 'h' */
    {0x00,0x00,0x18,0x18,0x00,0x38,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 105 'i' */
    {0x00,0x00,0x06,0x06,0x00,0x0E,0x06,0x06,0x06,0x06,0x66,0x66,0x3C,0x00,0x00,0x00}, /* 106 'j' */
    {0x00,0x00,0xE0,0x60,0x60,0x66,0x6C,0x78,0x6C,0x66,0xE6,0x00,0x00,0x00,0x00,0x00}, /* 107 'k' */
    {0x00,0x00,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00}, /* 108 'l' */
    {0x00,0x00,0x00,0x00,0x00,0xEC,0xFE,0xD6,0xD6,0xD6,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 109 'm' */
    {0x00,0x00,0x00,0x00,0x00,0xDC,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00}, /* 110 'n' */
    {0x00,0x00,0x00,0x00,0x00,0x7C,0xC6,0xC6,0xC6,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 111 'o' */
    {0x00,0x00,0x00,0x00,0x00,0xDC,0x66,0x66,0x66,0x7C,0x60,0x60,0xF0,0x00,0x00,0x00}, /* 112 'p' */
    {0x00,0x00,0x00,0x00,0x00,0x76,0xCC,0xCC,0xCC,0x7C,0x0C,0x0C,0x1E,0x00,0x00,0x00}, /* 113 'q' */
    {0x00,0x00,0x00,0x00,0x00,0xDC,0x76,0x66,0x60,0x60,0xF0,0x00,0x00,0x00,0x00,0x00}, /* 114 'r' */
    {0x00,0x00,0x00,0x00,0x00,0x7C,0xC6,0x70,0x1C,0xC6,0x7C,0x00,0x00,0x00,0x00,0x00}, /* 115 's' */
    {0x00,0x00,0x10,0x30,0x30,0xFC,0x30,0x30,0x30,0x36,0x1C,0x00,0x00,0x00,0x00,0x00}, /* 116 't' */
    {0x00,0x00,0x00,0x00,0x00,0xCC,0xCC,0xCC,0xCC,0xCC,0x76,0x00,0x00,0x00,0x00,0x00}, /* 117 'u' */
    {0x00,0x00,0x00,0x00,0x00,0xC6,0xC6,0xC6,0x6C,0x38,0x10,0x00,0x00,0x00,0x00,0x00}, /* 118 'v' */
    {0x00,0x00,0x00,0x00,0x00,0xC6,0xC6,0xD6,0xD6,0xFE,0x6C,0x00,0x00,0x00,0x00,0x00}, /* 119 'w' */
    {0x00,0x00,0x00,0x00,0x00,0xC6,0x6C,0x38,0x38,0x6C,0xC6,0x00,0x00,0x00,0x00,0x00}, /* 120 'x' */
    {0x00,0x00,0x00,0x00,0x00,0xC6,0xC6,0xC6,0xC6,0x7E,0x06,0x0C,0x78,0x00,0x00,0x00}, /* 121 'y' */
    {0x00,0x00,0x00,0x00,0x00,0xFE,0x8C,0x18,0x30,0x62,0xFE,0x00,0x00,0x00,0x00,0x00}, /* 122 'z' */
    {0x00,0x00,0x0E,0x18,0x18,0x18,0x70,0x18,0x18,0x18,0x0E,0x00,0x00,0x00,0x00,0x00}, /* 123 '{' */
    {0x00,0x00,0x18,0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00}, /* 124 '|' */
    {0x00,0x00,0x70,0x18,0x18,0x18,0x0E,0x18,0x18,0x18,0x70,0x00,0x00,0x00,0x00,0x00}, /* 125 '}' */
    {0x00,0x00,0x76,0xDC,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}  /* 126 '~' */
};


/* ============================================================================
- PRIMITIVAS DE HARDWARE (PS/2, CMOS RTC & UTILITÁRIOS)
- ============================================================================ */
static inline uint8_t inb(uint16_t porta) {
    uint8_t val;
    __asm__ volatile ("inb %1, %0" : "=a"(val) : "Nd"(porta));
    return val;
}

static inline void outb(uint16_t porta, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(porta));
}

static uint8_t ler_cmos(uint8_t reg) {
    outb(0x70, reg);
    return inb(0x71);
}

static uint8_t bcd_para_bin(uint8_t val) {
    return (uint8_t)((val & 0x0F) + ((val >> 4) * 10));
}

static void rtc_ler_agora(RtcDataHora *dt) {
    for (int timeout = 1000; timeout > 0 && (ler_cmos(0x0A) & 0x80); timeout--) {
        __asm__ volatile ("pause");
    }

    uint8_t seg  = ler_cmos(0x00);
    uint8_t min  = ler_cmos(0x02);
    uint8_t hora = ler_cmos(0x04);
    uint8_t dia  = ler_cmos(0x07);
    uint8_t mes  = ler_cmos(0x08);
    uint8_t ano  = ler_cmos(0x09);
    uint8_t regB = ler_cmos(0x0B);

    if (!(regB & 0x04)) {
        seg  = bcd_para_bin(seg);
        min  = bcd_para_bin(min);
        hora = bcd_para_bin(hora & 0x7F);
        dia  = bcd_para_bin(dia);
        mes  = bcd_para_bin(mes);
        ano  = bcd_para_bin(ano);
    }

    dt->seg  = seg;
    dt->min  = min;
    dt->hora = hora;
    dt->dia  = dia;
    dt->mes  = mes;
    dt->ano  = ano;
}

static void formatar_2dig(uint8_t val, char *out) {
    out[0] = (char)('0' + ((val / 10) % 10));
    out[1] = (char)('0' + (val % 10));
}

static void obter_estado_mouse(int *x, int *y, int *botoes) {
    uint32_t mx, my, mb;
    __asm__ volatile (
        "call mouse_ler_posicao"
        : "=D"(mx), "=S"(my), "=a"(mb)
        :
        : "rcx", "rdx", "r8", "r9", "r10", "r11", "memory"
    );
    *x = (int)mx;
    *y = (int)my;
    *botoes = (int)mb;
}

static int ponto_no_retangulo(int px, int py, int rx, int ry, int rw, int rh) {
    return (px >= rx && px < (rx + rw) && py >= ry && py < (ry + rh));
}

static size_t str_len(const char *s) {
    size_t n = 0;
    while (s && s[n]) n++;
    return n;
}

static int str_eq(const char *a, const char *b) {
    size_t i = 0;
    while (a[i] && b[i]) {
        if (a[i] != b[i]) return 0;
        i++;
    }
    return a[i] == b[i];
}

static void str_copy(char *dst, const char *src, size_t max_len) {
    size_t i = 0;
    if (max_len == 0) return;
    while (src[i] && i < max_len - 1) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = 0;
}

static void num_para_str(int valor, char *buf, size_t tam) {
    if (tam < 2) return;
    char tmp[16];
    int i = 0;
    if (valor == 0) {
        buf[0] = '0';
        buf[1] = 0;
        return;
    }
    if (valor < 0) {
        buf[0] = '-';
        buf[1] = 0;
        return;
    }
    while (valor > 0 && i < 15) {
        tmp[i++] = (char)('0' + (valor % 10));
        valor /= 10;
    }
    size_t j = 0;
    while (i > 0 && j < tam - 1) {
        buf[j++] = tmp[--i];
    }
    buf[j] = 0;
}

/* ============================================================================
- MOTOR DE RENDERIZAÇÃO DIRETA NO FRAMEBUFFER (32-BIT XRGB8888)
- ============================================================================ */
static void desenhar_retangulo_solido(int x, int y, int largura, int altura, uint32_t cor) {
    if (!fb_base || largura <= 0 || altura <= 0) return;

    int x0 = (x < 0) ? 0 : x;
    int y0 = (y < 0) ? 0 : y;
    int x1 = (x + largura > (int)fb_largura) ? (int)fb_largura : (x + largura);
    int y1 = (y + altura  > (int)fb_altura)  ? (int)fb_altura  : (y + altura);

    if (x0 >= x1 || y0 >= y1) return;

    uint32_t pitch_bytes = fb_pitch ? fb_pitch : (fb_largura * 4);
    for (int py = y0; py < y1; py++) {
        uint32_t *linha_ptr = (uint32_t *)((uint8_t *)fb_base + (uint64_t)py * pitch_bytes) + x0;
        int count = x1 - x0;
        for (int i = 0; i < count; i++) {
            linha_ptr[i] = cor;
        }
    }
}

#define BG_W 640
#define BG_H 512
#define BG_SETORES 2560
#define LBA_BG_SPLASH  8192
#define LBA_BG_LOGIN   10752
#define LBA_BG_DESKTOP 13312

/* Buffer fixo em 4 MB (0x00400000) — zero impacto no tamanho do kernel.bin */
static uint32_t * const bg_buffer_ram = (uint32_t *)0x00400000;
static uint32_t lba_bg_carregado = 0;

static int ata_ler_setor_pio28(uint32_t lba, uint16_t *destino) {
    for (int t = 100000; t > 0 && (inb(0x1F7) & 0x80); t--) __asm__ volatile ("pause");

    outb(0x1F6, (uint8_t)(0xE0 | ((lba >> 24) & 0x0F)));
    outb(0x1F2, 1);
    outb(0x1F3, (uint8_t)(lba & 0xFF));
    outb(0x1F4, (uint8_t)((lba >> 8) & 0xFF));
    outb(0x1F5, (uint8_t)((lba >> 16) & 0xFF));
    outb(0x1F7, 0x20); /* READ SECTORS */

    /* Atraso de 400ns exigido pela especificacao ATA PIO */
    inb(0x3F6); inb(0x3F6); inb(0x3F6); inb(0x3F6);

    int pronto = 0;
    for (int t = 100000; t > 0; t--) {
        uint8_t st = inb(0x1F7);
        if (st & 0x01) return -1;
        if (!(st & 0x80) && (st & 0x08)) { pronto = 1; break; }
        __asm__ volatile ("pause");
    }
    if (!pronto) return -1;

    for (int i = 0; i < 256; i++) {
        uint16_t w;
        __asm__ volatile ("inw %1, %0" : "=a"(w) : "Nd"((uint16_t)0x1F0));
        destino[i] = w;
    }
    return 0;
}

static int carregar_wallpaper_ata(uint32_t lba_inicial) {
    if (lba_bg_carregado == lba_inicial) return 1;
    if (detectar_disco(0) == 0) return 0;

    uint16_t *ptr = (uint16_t *)bg_buffer_ram;
    for (uint32_t s = 0; s < BG_SETORES; s++) {
        if (ata_ler_setor_pio28(lba_inicial + s, ptr + (s * 256)) != 0) {
            lba_bg_carregado = 0;
            return 0;
        }
    }
    lba_bg_carregado = lba_inicial;
    return 1;
}

static void desenhar_background_ata(uint32_t lba_inicial, int L, int A) {
    if (!fb_base || L <= 0 || A <= 0 || !carregar_wallpaper_ata(lba_inicial)) {
        desenhar_retangulo_solido(0, 0, L, A, COR_FUNDO_ESCURO);
        return;
    }

    uint32_t pitch_bytes = fb_pitch ? fb_pitch : (fb_largura * 4);
    int map_x[2048];
    int max_w = (L < 2048) ? L : 2048;

    for (int px = 0; px < max_w; px++) {
        map_x[px] = (px * BG_W) / L;
    }

    for (int py = 0; py < A; py++) {
        int sy = (py * BG_H) / A;
        if (sy >= BG_H) sy = BG_H - 1;
        const uint32_t *src_linha = bg_buffer_ram + (sy * BG_W);
        uint32_t *dst_linha = (uint32_t *)((uint8_t *)fb_base + (uint64_t)py * pitch_bytes);

        for (int px = 0; px < max_w; px++) {
            dst_linha[px] = src_linha[map_x[px]];
        }
    }
}

static void desenhar_caixa_com_borda(int x, int y, int w, int h, int espessura, uint32_t cor_borda, uint32_t cor_fundo) {
    desenhar_retangulo_solido(x, y, w, h, cor_borda);
    desenhar_retangulo_solido(
        x + espessura,
        y + espessura,
        w - (espessura * 2),
        h - (espessura * 2),
        cor_fundo
    );
}

void gpu_desenhar_icone(const uint32_t *pixels, int x, int y, int w, int h) {
    if (!pixels || !fb_base) return;
    uint32_t pitch_bytes = fb_pitch ? fb_pitch : (fb_largura * 4);

    for (int lin = 0; lin < h; lin++) {
        int py = y + lin;
        if (py < 0 || py >= (int)fb_altura) continue;
        uint32_t *dst_linha = (uint32_t *)((uint8_t *)fb_base + (uint64_t)py * pitch_bytes);

        for (int col = 0; col < w; col++) {
            int px = x + col;
            if (px < 0 || px >= (int)fb_largura) continue;

            uint32_t src = pixels[lin * w + col];
            uint32_t alpha = (src >> 24) & 0xFF;
            if (alpha == 0) continue;
            if (alpha == 255) {
                dst_linha[px] = src;
                continue;
            }

            uint32_t dst = dst_linha[px];
            uint32_t inv = 255 - alpha;
            uint32_t r = (((src >> 16) & 0xFF) * alpha + ((dst >> 16) & 0xFF) * inv) >> 8;
            uint32_t g = (((src >> 8)  & 0xFF) * alpha + ((dst >> 8)  & 0xFF) * inv) >> 8;
            uint32_t b = (( src        & 0xFF) * alpha + ( dst        & 0xFF) * inv) >> 8;
            dst_linha[px] = 0xFF000000 | (r << 16) | (g << 8) | b;
        }
    }
}

static void gpu_escrever_titulo(const char *texto, int x, int y, uint32_t cor) {
    if (!texto || !fb_base) return;
    uint32_t pitch_bytes = fb_pitch ? fb_pitch : (fb_largura * 4);

    uint32_t sr = (cor >> 16) & 0xFF;
    uint32_t sg = (cor >> 8)  & 0xFF;
    uint32_t sb =  cor        & 0xFF;

    int cx = x;
    while (*texto) {
        unsigned char c = (unsigned char)(*texto++);
        if (c < 32 || c > 126) c = '?';
        const uint8_t *glifo = fonte_ui_alpha[c - 32];

        for (int lin = 0; lin < FONTE_UI_H; lin++) {
            int py = y + lin;
            if (py < 0 || py >= (int)fb_altura) continue;
            uint32_t *dst_linha = (uint32_t *)((uint8_t *)fb_base + (uint64_t)py * pitch_bytes);

            for (int col = 0; col < FONTE_UI_W; col++) {
                int px = cx + col;
                if (px < 0 || px >= (int)fb_largura) continue;

                uint32_t alpha = glifo[lin * FONTE_UI_W + col];
                if (alpha == 0) continue;
                if (alpha == 255) {
                    dst_linha[px] = cor;
                    continue;
                }

                uint32_t dst = dst_linha[px];
                uint32_t inv = 255 - alpha;
                uint32_t r = (sr * alpha + ((dst >> 16) & 0xFF) * inv) >> 8;
                uint32_t g = (sg * alpha + ((dst >> 8)  & 0xFF) * inv) >> 8;
                uint32_t b = (sb * alpha + ( dst        & 0xFF) * inv) >> 8;
                dst_linha[px] = 0xFF000000 | (r << 16) | (g << 8) | b;
            }
        }
        cx += FONTE_UI_W;
    }
}

void gpu_escrever_texto(const char *texto, int x, int y, uint32_t cor) {
    if (!texto || !fb_base) return;

    int cx = x;
    int cy = y;
    uint32_t pitch_bytes = fb_pitch ? fb_pitch : (fb_largura * 4);

    while (*texto) {
        unsigned char c = (unsigned char)(*texto++);
        if (c == '\n') {
            cx = x;
            cy += 18;
            continue;
        }
        if (c < 32 || c > 126) {
            c = '?';
        }

        const uint8_t *glifos = fonte_8x16[c - 32];
        for (int linha = 0; linha < 16; linha++) {
            int py = cy + linha;
            if (py < 0 || py >= (int)fb_altura) continue;

            uint8_t bits = glifos[linha];
            if (!bits) continue;

            uint32_t *linha_ptr = (uint32_t *)((uint8_t *)fb_base + (uint64_t)py * pitch_bytes);
            for (int col = 0; col < 8; col++) {
                if (bits & (1 << (7 - col))) {
                    int px = cx + col;
                    if (px >= 0 && px < (int)fb_largura) {
                        linha_ptr[px] = cor;
                    }
                }
            }
        }
        cx += 8;
    }
}

static void escrever_texto_centralizado(const char *texto, int centro_x, int y, uint32_t cor) {
    int largura_px = (int)str_len(texto) * 8;
    gpu_escrever_texto(texto, centro_x - (largura_px / 2), y, cor);
}

/* ============================================================================
- TELEMETRIA DE HARDWARE
- ============================================================================ */
static void obter_cpu_vendor(char *out16) {
    uint32_t eax, ebx, ecx, edx;
    __asm__ volatile ("cpuid" : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx) : "a"(0));

    *(uint32_t *)(out16 + 0) = ebx;
    *(uint32_t *)(out16 + 4) = edx;
    *(uint32_t *)(out16 + 8) = ecx;
    out16[12] = 0;
}

static uint32_t detectar_ram_total_mb(void) {
    uint32_t b64_lo = ler_cmos(0x34);
    uint32_t b64_hi = ler_cmos(0x35);
    uint32_t blocos_64k = (b64_hi << 8) | b64_lo;

    if (blocos_64k > 0) {
        return 16 + ((blocos_64k * 64) / 1024);
    }

    uint32_t kb_lo = ler_cmos(0x30);
    uint32_t kb_hi = ler_cmos(0x31);
    uint32_t ext_kb = (kb_hi << 8) | kb_lo;
    return 1 + (ext_kb / 1024);
}

static void inicializar_telemetria(TelemetriaSistema *tel, int L, int A) {
    obter_cpu_vendor(tel->cpu_vendor);
    tel->cpu_uso_pct = 4;

    tel->ram_total_mb = detectar_ram_total_mb();
    if (tel->ram_total_mb < 32) tel->ram_total_mb = 128;

    uint32_t fb_mb = (uint32_t)(((uint64_t)L * (uint64_t)A * 4ULL) / (1024ULL * 1024ULL));
    tel->ram_usada_mb = 12 + fb_mb;
    if (tel->ram_usada_mb > tel->ram_total_mb) {
        tel->ram_usada_mb = tel->ram_total_mb / 2;
    }

    tel->disco_online = (detectar_disco(0) != 0);
    if (tel->disco_online) {
        uint64_t setores = obter_tamanho_disco();
        tel->disco_total_mb = (uint32_t)(setores / 2048ULL);
    } else {
        tel->disco_total_mb = 0;
    }
}

static void desenhar_barra_progresso(int x, int y, int w, int h, int pct, uint32_t cor_fill) {
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    desenhar_caixa_com_borda(x, y, w, h, 1, COR_BORDA_SUTIL, COR_INPUT_BG);
    int fill_w = ((w - 2) * pct) / 100;
    if (fill_w > 0) {
        desenhar_retangulo_solido(x + 1, y + 1, fill_w, h - 2, cor_fill);
    }
}

static void desenhar_widgets_sistema(int L, const TelemetriaSistema *tel) {
    int w_larg = 256;
    int w_alt  = 214;
    int wx     = L - w_larg - 14;
    int wy     = 48;

    char linha[48];
    char num[16];
    size_t p;

    desenhar_caixa_com_borda(wx, wy, w_larg, w_alt, 1, COR_ROXO_NEON, COR_PAINEL);
    desenhar_retangulo_solido(wx + 1, wy + 1, w_larg - 2, 24, COR_CARD);
    gpu_escrever_texto("MONITOR DE HARDWARE", wx + 12, wy + 5, COR_CIANO_NEON);

    int cx = wx + 12;
    int cy = wy + 34;
    int bar_w = w_larg - 24;

    /* --- WIDGET 1: CPU --- */
    gpu_desenhar_icone(icone_sistema, cx, cy - 2, ICONE_TAM, ICONE_TAM);
    str_copy(linha, "CPU: ", sizeof(linha));
    p = str_len(linha);
    str_copy(linha + p, tel->cpu_vendor, sizeof(linha) - p);
    gpu_escrever_texto(linha, cx + 26, cy, COR_TEXTO_BRANCO);

    num_para_str(tel->cpu_uso_pct, num, sizeof(num));
    p = str_len(num);
    num[p] = '%';
    num[p + 1] = 0;
    gpu_escrever_texto(num, wx + w_larg - 44, cy, COR_CIANO_NEON);

    cy += 22;
    desenhar_barra_progresso(cx, cy, bar_w, 12, tel->cpu_uso_pct, COR_CIANO_NEON);
    cy += 24;

    /* --- WIDGET 2: MEMORIA RAM --- */
    gpu_desenhar_icone(icone_agenda, cx, cy - 2, ICONE_TAM, ICONE_TAM);
    str_copy(linha, "RAM: ", sizeof(linha));
    num_para_str((int)tel->ram_usada_mb, num, sizeof(num));
    p = str_len(linha);
    str_copy(linha + p, num, sizeof(linha) - p);
    p = str_len(linha);
    str_copy(linha + p, "/", sizeof(linha) - p);
    num_para_str((int)tel->ram_total_mb, num, sizeof(num));
    p = str_len(linha);
    str_copy(linha + p, num, sizeof(linha) - p);
    p = str_len(linha);
    str_copy(linha + p, " MB", sizeof(linha) - p);
    gpu_escrever_texto(linha, cx + 26, cy, COR_TEXTO_BRANCO);

    int ram_pct = (tel->ram_total_mb > 0)
        ? (int)((tel->ram_usada_mb * 100U) / tel->ram_total_mb)
        : 0;
    cy += 22;
    desenhar_barra_progresso(cx, cy, bar_w, 12, ram_pct, COR_VERDE_NEON);
    cy += 24;

    /* --- WIDGET 3: DISCO TOTAL --- */
    gpu_desenhar_icone(icone_disco, cx, cy - 2, ICONE_TAM, ICONE_TAM);
    if (tel->disco_online) {
        str_copy(linha, "DISCO: ", sizeof(linha));
        num_para_str((int)tel->disco_total_mb, num, sizeof(num));
        p = str_len(linha);
        str_copy(linha + p, num, sizeof(linha) - p);
        p = str_len(linha);
        str_copy(linha + p, " MB Total", sizeof(linha) - p);
        gpu_escrever_texto(linha, cx + 26, cy, COR_TEXTO_BRANCO);
    } else {
        gpu_escrever_texto("DISCO: Nao detectado", cx + 26, cy, COR_VERMELHO_ALERTA);
    }

    cy += 22;
    desenhar_barra_progresso(cx, cy, bar_w, 12, tel->disco_online ? 100 : 0, COR_ROXO_CLARO);
    cy += 18;
    gpu_escrever_texto(tel->disco_online ? "ATA Primary Master (0x1F0) OK" : "Verifique imagem .vdi/.img",
                       cx, cy, COR_TEXTO_SUAVE);
}


/* ============================================================================
- SYSTEM TRAY
- ============================================================================ */
#define SYSTRAY_LARGURA 248

static void desenhar_systray(int L, int taskbar_y, int taskbar_h,
                             int link_ativo, int disco_ok, int bt_status, int audio_status,
                             const RtcDataHora *dt, int mx, int my) {
    int tray_w = SYSTRAY_LARGURA;
    int tray_h = taskbar_h - 6;
    int tray_x = L - tray_w - 8;
    int tray_y = taskbar_y + 3;

    int hover_tray = ponto_no_retangulo(mx, my, tray_x, tray_y, tray_w, tray_h);

    desenhar_caixa_com_borda(tray_x, tray_y, tray_w, tray_h, 1,
        hover_tray ? COR_CIANO_NEON : COR_BORDA_SUTIL,
        hover_tray ? COR_HOVER : COR_PAINEL_SEC);

    int ico_y = tray_y + 6;

    /* 1. Rede Cabeada */
    int eth_x = tray_x + 8;
    gpu_desenhar_icone(icone_ethernet, eth_x, ico_y, ICONE_TAM, ICONE_TAM);
    desenhar_retangulo_solido(eth_x + ICONE_TAM - 4, ico_y + ICONE_TAM - 4, 5, 5,
        link_ativo ? COR_VERDE_NEON : COR_ROXO_CLARO);

    /* 2. Rede Wi-Fi */
    int wifi_x = eth_x + 26;
    gpu_desenhar_icone(icone_wifi, wifi_x, ico_y, ICONE_TAM, ICONE_TAM);

    /* 3. Bluetooth */
    int bt_x = wifi_x + 26;
    gpu_desenhar_icone(icone_bluetooth, bt_x, ico_y, ICONE_TAM, ICONE_TAM);
    uint32_t cor_led_bt = COR_BORDA_SUTIL;
    if (bt_status == 2)      cor_led_bt = COR_VERDE_NEON;
    else if (bt_status == 1) cor_led_bt = COR_CIANO_NEON;
    desenhar_retangulo_solido(bt_x + ICONE_TAM - 4, ico_y + ICONE_TAM - 4, 5, 5, cor_led_bt);

    /* 4. Audio */
    int aud_x = bt_x + 26;
    gpu_desenhar_icone(icone_audio, aud_x, ico_y, ICONE_TAM, ICONE_TAM);
    uint32_t cor_led_aud = COR_BORDA_SUTIL;
    if (audio_status == 1)      cor_led_aud = COR_VERDE_NEON;
    else if (audio_status == 2) cor_led_aud = COR_VERMELHO_ALERTA;
    desenhar_retangulo_solido(aud_x + ICONE_TAM - 4, ico_y + ICONE_TAM - 4, 5, 5, cor_led_aud);

    /* 5. Disco ATA/IDE */
    int disk_x = aud_x + 26;
    gpu_desenhar_icone(icone_disco, disk_x, ico_y, ICONE_TAM, ICONE_TAM);
    desenhar_retangulo_solido(disk_x + ICONE_TAM - 4, ico_y + ICONE_TAM - 4, 5, 5,
        disco_ok ? COR_VERDE_NEON : COR_VERMELHO_ALERTA);

    int sep_x = disk_x + 26;
    desenhar_retangulo_solido(sep_x, tray_y + 5, 1, tray_h - 10, COR_BORDA_SUTIL);

    /* 6. Relogio Digital + Data */
    char hora_str[8];
    char data_str[12];

    formatar_2dig(dt->hora, &hora_str[0]);
    hora_str[2] = ':';
    formatar_2dig(dt->min, &hora_str[3]);
    hora_str[5] = 0;

    formatar_2dig(dt->dia, &data_str[0]);
    data_str[2] = '/';
    formatar_2dig(dt->mes, &data_str[3]);
    data_str[5] = '/';
    data_str[6] = '2';
    data_str[7] = '0';
    formatar_2dig(dt->ano, &data_str[8]);
    data_str[10] = 0;

    int relogio_x = sep_x + 12;
    gpu_escrever_texto(hora_str, relogio_x + 20, tray_y + 2, COR_TEXTO_BRANCO);
    gpu_escrever_texto(data_str, relogio_x, tray_y + 16, COR_TEXTO_SUAVE);
}

/* ============================================================================
- DRIVER DE TECLADO PS/2 PARA INTERFACE GRÁFICA (Shift, Backspace, Tab & Setas)
- ============================================================================ */
static char ler_tecla_ps2(void) {
    static int shift_ativo   = 0;
    static int estendido_e0  = 0;

    static const char mapa_normal[128] = {
        0,  27, '1','2','3','4','5','6','7','8','9','0','-','=', '\b',
        '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n', 0,
        'a','s','d','f','g','h','j','k','l',';','\'','`', 0, '\\',
        'z','x','c','v','b','n','m',',','.','/', 0, '*', 0, ' '
    };

    static const char mapa_shift[128] = {
        0,  27, '!','@','#','$','%','^','&','*','(',')','_','+', '\b',
        '\t','Q','W','E','R','T','Y','U','I','O','P','{','}','\n', 0,
        'A','S','D','F','G','H','J','K','L',':','"','~', 0, '|',
        'Z','X','C','V','B','N','M','<','>','?', 0, '*', 0, ' '
    };

    while (1) {
        uint8_t status = inb(0x64);
        if ((status & 0x01) == 0) return 0;
        if (status & 0x20) return 0; /* Dado pertence ao mouse PS/2 */

        uint8_t sc = inb(0x60);

        if (sc == 0xE0) {
            estendido_e0 = 1;
            continue;
        }

        if (estendido_e0) {
            estendido_e0 = 0;
            if (sc & 0x80) continue;
            if (sc == 0x48 || sc == 0x50) return '\t'; /* Setas Cima/Baixo alternam campo */
            continue;
        }

        /* Shift pressionado / solto (Left Shift 0x2A, Right Shift 0x36) */
        if (sc == 0x2A || sc == 0x36) {
            shift_ativo = 1;
            continue;
        }
        if (sc == 0xAA || sc == 0xB6) {
            shift_ativo = 0;
            continue;
        }

        if (sc & 0x80) continue;
        if (sc < sizeof(mapa_normal)) {
            char ch = shift_ativo ? mapa_shift[sc] : mapa_normal[sc];
            if (ch != 0) return ch;
        }
    }
}

/* ============================================================================
- TELA 1: ANIMAÇÃO DE CARREGAMENTO DO AMBIENTE GRÁFICO (Via Disco ATA)
- ============================================================================ */
static void exibir_splash_carregamento(int L, int A) {
    if (fb_base) {
        uint32_t total_pixels = (fb_pitch ? (fb_pitch / 4) : (uint32_t)L) * (uint32_t)A;
        for (uint32_t i = 0; i < total_pixels; i++) {
            fb_base[i] = COR_FUNDO_ESCURO;
        }
    }

    desenhar_background_ata(LBA_BG_SPLASH, L, A);
    desenhar_retangulo_solido(0, 0, L, 4, COR_CIANO_NEON);

    int box_w = (L * 54) / 100;
    if (box_w < 340) box_w = 340;
    if (box_w > 680) box_w = 680;
    int box_h = 170;
    int box_x = (L - box_w) / 2;
    int box_y = (A - box_h) / 2;

    desenhar_caixa_com_borda(box_x, box_y, box_w, box_h, 2, COR_ROXO_NEON, COR_PAINEL_SEC);
    escrever_texto_centralizado("FYDELISTECH OS v4.2", L / 2, box_y + 20, COR_CIANO_NEON);
    escrever_texto_centralizado("Inicializando Ambiente Grafico & Window Manager", L / 2, box_y + 44, COR_TEXTO_SUAVE);

    int barra_larg = box_w - 48;
    int barra_alt  = 24;
    int barra_x    = box_x + 24;
    int barra_y    = box_y + 82;

    desenhar_caixa_com_borda(barra_x - 2, barra_y - 2, barra_larg + 4, barra_alt + 4, 1, COR_BORDA_SUTIL, COR_INPUT_BG);

    char pct_buf[16];
    for (int p = 0; p <= 100; p += 10) {
        int preenchido = (p * barra_larg) / 100;
        uint32_t cor_barra = (p == 100) ? COR_CIANO_NEON : COR_ROXO_NEON;

        desenhar_retangulo_solido(barra_x, barra_y, preenchido, barra_alt, cor_barra);
        desenhar_retangulo_solido(barra_x, barra_y + barra_alt + 10, barra_larg, 20, COR_PAINEL_SEC);

        if (p < 40) {
            gpu_escrever_texto("Carregando drivers VESA 32-bit...", barra_x, barra_y + barra_alt + 12, COR_TEXTO_SUAVE);
        } else if (p < 80) {
            gpu_escrever_texto("Iniciando mouse PS/2 e compositor...", barra_x, barra_y + barra_alt + 12, COR_TEXTO_SUAVE);
        } else if (p < 100) {
            gpu_escrever_texto("Preparando interface de autenticacao...", barra_x, barra_y + barra_alt + 12, COR_TEXTO_SUAVE);
        } else {
            gpu_escrever_texto("Sistema pronto!", barra_x, barra_y + barra_alt + 12, COR_VERDE_NEON);
        }

        num_para_str(p, pct_buf, sizeof(pct_buf));
        size_t len = str_len(pct_buf);
        pct_buf[len] = '%';
        pct_buf[len + 1] = 0;

        int pct_x = barra_x + barra_larg - ((int)str_len(pct_buf) * 8);
        gpu_escrever_texto(pct_buf, pct_x, barra_y + barra_alt + 12, COR_CIANO_NEON);

        for (volatile uint64_t d = 0; d < 1800000; d++) {
            __asm__ volatile ("pause");
        }
    }
}
/* ============================================================================
- TELA 2: LOGIN GRÁFICO INTERATIVO (Via Disco ATA, Cursor Limpo e Tab/Backspace)
- ============================================================================ */
static void exibir_tela_login(int L, int A) {
    char usuario[24];
    char senha[24];
    char mascara[24];
    int campo_ativo = 1;
    int erro_login  = 0;
    int precisa_redesenhar = 1;
    int btn_ant = 0;

    str_copy(usuario, "admin", sizeof(usuario));
    str_copy(senha, "fydelis2026", sizeof(senha));

    int card_w = (L * 42) / 100;
    if (card_w < 340) card_w = 340;
    if (card_w > 460) card_w = 460;
    int card_h = 310;
    int card_x = (L - card_w) / 2;
    int card_y = (A - card_h) / 2;

    int input_x = card_x + 28;
    int input_w = card_w - 56;
    int input_h = 32;
    int user_y  = card_y + 88;
    int pass_y  = card_y + 156;
    int btn_y   = card_y + 212;

    ws_inicializar();

    while (1) {
        if (precisa_redesenhar) {
            cursor_restaurar_fundo();
            backbuffer_iniciar_frame();

            desenhar_background_ata(LBA_BG_LOGIN, L, A);
            desenhar_retangulo_solido(0, 0, L, 32, COR_PAINEL);
            desenhar_retangulo_solido(0, 32, L, 1, COR_BORDA_SUTIL);
            gpu_escrever_texto("FydelisTech OS v4.2", 16, 8, COR_CIANO_NEON);
            gpu_escrever_texto("Salvador - Bahia | x86_64", L - 216, 8, COR_TEXTO_SUAVE);

            desenhar_caixa_com_borda(card_x, card_y, card_w, card_h, 2, COR_ROXO_NEON, COR_CARD);
            escrever_texto_centralizado("AUTENTICACAO DO SISTEMA", card_x + (card_w / 2), card_y + 24, COR_CIANO_NEON);
            escrever_texto_centralizado("Entre com suas credenciais", card_x + (card_w / 2), card_y + 46, COR_TEXTO_SUAVE);

            gpu_escrever_texto("USUARIO:", input_x, user_y - 18, COR_ROXO_CLARO);
            desenhar_caixa_com_borda(input_x, user_y, input_w, input_h, 2,
                (campo_ativo == 0) ? COR_CIANO_NEON : COR_BORDA_SUTIL, COR_INPUT_BG);
            gpu_escrever_texto(usuario, input_x + 10, user_y + 8, COR_TEXTO_BRANCO);
            if (campo_ativo == 0) {
                gpu_escrever_texto("_", input_x + 10 + (int)str_len(usuario) * 8, user_y + 8, COR_CIANO_NEON);
            }

            gpu_escrever_texto("SENHA:", input_x, pass_y - 18, COR_ROXO_CLARO);
            desenhar_caixa_com_borda(input_x, pass_y, input_w, input_h, 2,
                (campo_ativo == 1) ? COR_CIANO_NEON : COR_BORDA_SUTIL, COR_INPUT_BG);
            size_t slen = str_len(senha);
            for (size_t i = 0; i < slen; i++) mascara[i] = '*';
            mascara[slen] = 0;
            gpu_escrever_texto(mascara, input_x + 10, pass_y + 8, COR_TEXTO_BRANCO);
            if (campo_ativo == 1) {
                gpu_escrever_texto("_", input_x + 10 + (int)slen * 8, pass_y + 8, COR_CIANO_NEON);
            }

            desenhar_retangulo_solido(input_x, btn_y, input_w, 36, COR_ROXO_NEON);
            escrever_texto_centralizado("[ ENTER / CLIQUE ] ENTRAR", card_x + (card_w / 2), btn_y + 10, COR_TEXTO_BRANCO);

            if (erro_login) {
                escrever_texto_centralizado("Usuario ou senha invalidos!", card_x + (card_w / 2), card_y + 262, COR_VERMELHO_ALERTA);
            } else {
                escrever_texto_centralizado("[TAB / SETAS] Alternar  |  [ENTER] Acessar", card_x + (card_w / 2), card_y + 262, COR_TEXTO_SUAVE);
            }

            backbuffer_apresentar_frame(L, A);
            cursor_desenhar_novo();
            precisa_redesenhar = 0;
        }

        ws_atualizar_cursor();

        int mx, my, mb;
        obter_estado_mouse(&mx, &my, &mb);
        int clique_esq = (mb & 0x01) && !(btn_ant & 0x01);
        btn_ant = mb;

        if (clique_esq) {
            if (ponto_no_retangulo(mx, my, input_x, user_y, input_w, input_h)) {
                campo_ativo = 0;
                precisa_redesenhar = 1;
            } else if (ponto_no_retangulo(mx, my, input_x, pass_y, input_w, input_h)) {
                campo_ativo = 1;
                precisa_redesenhar = 1;
            } else if (ponto_no_retangulo(mx, my, input_x, btn_y, input_w, 36)) {
                if (str_eq(usuario, "admin") && str_eq(senha, "fydelis2026")) {
                    cursor_restaurar_fundo();
                    return;
                } else {
                    erro_login = 1;
                    precisa_redesenhar = 1;
                }
            }
        }

        char tecla;
        while ((tecla = ler_tecla_ps2()) != 0) {
            if (tecla == '\t') {
                campo_ativo = !campo_ativo;
                erro_login = 0;
                precisa_redesenhar = 1;
            } else if (tecla == '\n') {
                if (str_eq(usuario, "admin") && str_eq(senha, "fydelis2026")) {
                    cursor_restaurar_fundo();
                    return;
                } else {
                    erro_login = 1;
                    precisa_redesenhar = 1;
                }
            } else if (tecla == '\b') {
                char *alvo = (campo_ativo == 0) ? usuario : senha;
                size_t len = str_len(alvo);
                if (len > 0) alvo[len - 1] = 0;
                erro_login = 0;
                precisa_redesenhar = 1;
            } else if (tecla >= 32 && tecla <= 126) {
                char *alvo = (campo_ativo == 0) ? usuario : senha;
                size_t len = str_len(alvo);
                if (len < 20) {
                    alvo[len] = tecla;
                    alvo[len + 1] = 0;
                }
                erro_login = 0;
                precisa_redesenhar = 1;
            }
        }

        descansar_cpu_hlt();
    }
}

void gui_retangulo(int x, int y, int w, int h, uint32_t cor) {
    desenhar_retangulo_solido(x, y, w, h, cor);
}

void gui_borda(int x, int y, int w, int h, uint32_t cor) {
    desenhar_retangulo_solido(x, y, w, 1, cor);
    desenhar_retangulo_solido(x, y + h - 1, w, 1, cor);
    desenhar_retangulo_solido(x, y, 1, h, cor);
    desenhar_retangulo_solido(x + w - 1, y, 1, h, cor);
}

void gui_texto(int x, int y, const char *str, uint32_t cor) {
    gpu_escrever_texto(str, x, y, cor);
}

/* ============================================================================
- POPUP DE REDE CABEADA (ETH0 - IP FIXO / DHCP)
- ============================================================================ */
#define ETH_POP_W 296
#define ETH_POP_H 256

static int  eth_popup_aberto = 0;
static int  eth_campo_ativo  = 0; /* 0 = IP, 1 = Mascara, 2 = Gateway */
static char eth_ip_str[20]   = "10.0.2.15";
static char eth_mask_str[20] = "255.255.255.0";
static char eth_gw_str[20]   = "10.0.2.2";
static char eth_status_msg[44] = "Modo: DHCP Automatico";

extern void dhcp_cliente_resetar(void);

static void eth_copiar_str(char *dst, const char *src, int max) {
    int i = 0;
    while (src && src[i] && i < max - 1) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = '\0';
}

static int eth_str_len(const char *s) {
    int n = 0;
    while (s[n]) n++;
    return n;
}

static void eth_popup_alternar(void) {
    eth_popup_aberto = !eth_popup_aberto;
    if (eth_popup_aberto) {
        wifi_popup_aberto = 0;
    }
}

static void eth_popup_desenhar(void) {
    if (!eth_popup_aberto) return;

    int px = (int)fb_largura - ETH_POP_W - 14;
    int py = (int)fb_altura - ETH_POP_H - 38;
    if (px < 10) px = 10;
    if (py < 10) py = 10;

    gui_retangulo(px, py, ETH_POP_W, ETH_POP_H, WIFI_COR_FUNDO);
    gui_borda(px, py, ETH_POP_W, ETH_POP_H, WIFI_COR_CIANO);
    gui_retangulo(px + 2, py + 2, ETH_POP_W - 4, 24, WIFI_COR_BARRA);
    gui_texto(px + 10, py + 6, "Rede Cabeada (eth0 - E1000)", WIFI_COR_CIANO);

    /* Botao [X] */
    gui_retangulo(px + ETH_POP_W - 22, py + 4, 18, 18, WIFI_COR_VERMELHO);
    gui_texto(px + ETH_POP_W - 17, py + 5, "X", WIFI_COR_TEXTO);

    const char *labels[3] = { "Endereco IP:", "Mascara Rede:", "Gateway:" };
    char *campos[3] = { eth_ip_str, eth_mask_str, eth_gw_str };

    int cy = py + 34;
    for (int i = 0; i < 3; i++) {
        gui_texto(px + 12, cy, labels[i], WIFI_COR_SUAVE);
        cy += 16;

        int box_x = px + 12;
        int box_w = ETH_POP_W - 24;
        gui_retangulo(box_x, cy, box_w, 22, WIFI_COR_ITEM);
        gui_borda(box_x, cy, box_w, 22, (eth_campo_ativo == i) ? WIFI_COR_CIANO : 0xFF4C2889);
        gui_texto(box_x + 8, cy + 4, campos[i], WIFI_COR_TEXTO);

        if (eth_campo_ativo == i) {
            int len = eth_str_len(campos[i]);
            gui_texto(box_x + 8 + (len * 8), cy + 4, "_", WIFI_COR_CIANO);
        }
        cy += 28;
    }

    /* Botao [Aplicar IP Fixo] */
    int btn_y = py + 196;
    gui_retangulo(px + 12, btn_y, 144, 24, WIFI_COR_ITEM_SEL);
    gui_borda(px + 12, btn_y, 144, 24, WIFI_COR_VERDE);
    gui_texto(px + 20, btn_y + 4, "Aplicar IP Fixo", WIFI_COR_VERDE);

    /* Botao [Usar DHCP] */
    gui_retangulo(px + 164, btn_y, 120, 24, WIFI_COR_ITEM_SEL);
    gui_borda(px + 164, btn_y, 120, 24, WIFI_COR_CIANO);
    gui_texto(px + 184, btn_y + 4, "Usar DHCP", WIFI_COR_CIANO);

    /* Barra de status */
    gui_retangulo(px + 2, py + ETH_POP_H - 22, ETH_POP_W - 4, 20, WIFI_COR_BARRA);
    gui_texto(px + 10, py + ETH_POP_H - 18, eth_status_msg, WIFI_COR_VERDE);
}

static int eth_popup_processar_clique(int mx, int my) {
    if (!eth_popup_aberto) return 0;

    int px = (int)fb_largura - ETH_POP_W - 14;
    int py = (int)fb_altura - ETH_POP_H - 38;
    if (px < 10) px = 10;
    if (py < 10) py = 10;

    if (mx < px || mx > px + ETH_POP_W || my < py || my > py + ETH_POP_H) {
        eth_popup_aberto = 0;
        return 0;
    }

    int rx = mx - px;
    int ry = my - py;

    /* Fechar [X] */
    if (rx >= ETH_POP_W - 22 && rx <= ETH_POP_W - 4 && ry >= 4 && ry <= 22) {
        eth_popup_aberto = 0;
        return 1;
    }

    /* Selecao dos 3 campos de texto */
    int cy = 50;
    for (int i = 0; i < 3; i++) {
        if (rx >= 12 && rx <= ETH_POP_W - 12 && ry >= cy && ry <= cy + 22) {
            eth_campo_ativo = i;
            return 1;
        }
        cy += 44;
    }

    /* Botao [Aplicar IP Fixo] */
    if (rx >= 12 && rx <= 156 && ry >= 196 && ry <= 220) {
        eth_copiar_str(eth_status_msg, "IP Fixo: ", sizeof(eth_status_msg));
        int p = eth_str_len(eth_status_msg);
        eth_copiar_str(eth_status_msg + p, eth_ip_str, sizeof(eth_status_msg) - p);
        return 1;
    }

    /* Botao [Usar DHCP] */
    if (rx >= 164 && rx <= 284 && ry >= 196 && ry <= 220) {
        dhcp_cliente_resetar();
        dhcp_cliente_iniciar();
        eth_copiar_str(eth_status_msg, "DHCP solicitado na eth0", sizeof(eth_status_msg));
        return 1;
    }

    return 1;
}

static void eth_popup_on_key(char tecla) {
    char *alvo = (eth_campo_ativo == 0) ? eth_ip_str :
                 (eth_campo_ativo == 1) ? eth_mask_str : eth_gw_str;
    int len = eth_str_len(alvo);

    if (tecla == 27) {
        eth_popup_aberto = 0;
    } else if (tecla == '\t' || tecla == '\n') {
        eth_campo_ativo = (eth_campo_ativo + 1) % 3;
    } else if (tecla == '\b') {
        if (len > 0) alvo[len - 1] = '\0';
    } else if (((tecla >= '0' && tecla <= '9') || tecla == '.') && len < 15) {
        alvo[len] = tecla;
        alvo[len + 1] = '\0';
    }
}

// Bloco Wifi
static void wifi_copiar_str(char *dst, const char *src, int max) {
    int i = 0;
    while (src && src[i] && i < max - 1) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = '\0';
}

/* Alterna abertura do popup ao clicar no ícone do Systray */
void wifi_popup_alternar(void) {
    wifi_popup_aberto = !wifi_popup_aberto;
    if (wifi_popup_aberto) {
        if (!wifi_detectar_placa()) {
            wifi_copiar_str(wifi_status_msg, "Placa Wi-Fi nao detectada", sizeof(wifi_status_msg));
            return;
        }
        wifi_inicializar();
        sys_wifi_scan();
        wifi_copiar_str(wifi_status_msg, "Redes atualizadas", sizeof(wifi_status_msg));
    }
}

/* Renderiza o popup acima da barra de tarefas no canto direito */
void wifi_popup_desenhar(void) {
    if (!wifi_popup_aberto) return;

    int px = (int)fb_largura - WIFI_POP_W - 14;
    int py = (int)fb_altura - WIFI_POP_H - 38; /* Acima da barra inferior */
    if (px < 10) px = 10;
    if (py < 10) py = 10;

    /* Moldura principal e cabeçalho */
    gui_retangulo(px, py, WIFI_POP_W, WIFI_POP_H, WIFI_COR_FUNDO);
    gui_borda(px, py, WIFI_POP_W, WIFI_POP_H, WIFI_COR_BORDA);
    gui_retangulo(px + 2, py + 2, WIFI_POP_W - 4, 24, WIFI_COR_BARRA);
    gui_texto(px + 10, py + 6, "Wi-Fi FydelisNet", WIFI_COR_CIANO);

    /* Botão [X] fechar */
    gui_retangulo(px + WIFI_POP_W - 22, py + 4, 18, 18, WIFI_COR_VERMELHO);
    gui_texto(px + WIFI_POP_W - 17, py + 5, "X", WIFI_COR_TEXTO);

    /* Botão [Escanear] */
    gui_retangulo(px + 10, py + 32, 92, 22, WIFI_COR_ITEM_SEL);
    gui_borda(px + 10, py + 32, 92, 22, WIFI_COR_CIANO);
    gui_texto(px + 20, py + 36, "Escanear", WIFI_COR_CIANO);

    /* Botão [Desconectar] */
    gui_retangulo(px + WIFI_POP_W - 112, py + 32, 102, 22, WIFI_COR_ITEM_SEL);
    gui_borda(px + WIFI_POP_W - 112, py + 32, 102, 22, WIFI_COR_AMARELO);
    gui_texto(px + WIFI_POP_W - 104, py + 36, "Desconectar", WIFI_COR_AMARELO);

    /* Lista de redes encontradas */
    int ly = py + 62;
    int exibidas = 0;

    for (int i = 0; i < MAX_REDES_WIFI && exibidas < WIFI_MAX_VISIVEIS; i++) {
        if (wifi_scan_lista[i].ssid[0] == '\0') continue;

        uint32_t bg = (i == wifi_indice_selecionado) ? WIFI_COR_ITEM_SEL : WIFI_COR_ITEM;
        gui_retangulo(px + 10, ly, WIFI_POP_W - 20, 24, bg);
        gui_borda(px + 10, ly, WIFI_POP_W - 20, 24, 0xFF4C2889);

        /* Nome da rede (SSID) */
        gui_texto(px + 16, ly + 5, wifi_scan_lista[i].ssid, WIFI_COR_TEXTO);

        /* Tipo de segurança à direita */
        if (wifi_scan_lista[i].seguranca == 0) {
            gui_texto(px + WIFI_POP_W - 72, ly + 5, "Aberta", WIFI_COR_VERDE);
        } else {
            gui_texto(px + WIFI_POP_W - 60, ly + 5, "WPA2", WIFI_COR_AMARELO);
        }

        ly += 27;
        exibidas++;
    }

    if (exibidas == 0) {
        gui_texto(px + 16, py + 80, "Nenhuma rede Wi-Fi encontrada.", WIFI_COR_SUAVE);
    }

    /* Barra de status inferior do popup */
    gui_retangulo(px + 2, py + WIFI_POP_H - 22, WIFI_POP_W - 4, 20, WIFI_COR_BARRA);
    gui_texto(px + 10, py + WIFI_POP_H - 18, wifi_status_msg, WIFI_COR_VERDE);
}

/* Trata cliques dentro do popup (retorna 1 se consumiu o clique, 0 caso contrário) */
int wifi_popup_processar_clique(int mx, int my) {
    if (!wifi_popup_aberto) return 0;

    int px = (int)fb_largura - WIFI_POP_W - 14;
    int py = (int)fb_altura - WIFI_POP_H - 38;
    if (px < 10) px = 10;
    if (py < 10) py = 10;

    /* Se clicou fora do popup, fecha automaticamente */
    if (mx < px || mx > px + WIFI_POP_W || my < py || my > py + WIFI_POP_H) {
        wifi_popup_aberto = 0;
        return 0;
    }

    int rx = mx - px;
    int ry = my - py;

    /* Clique no [X] */
    if (rx >= WIFI_POP_W - 22 && rx <= WIFI_POP_W - 4 && ry >= 4 && ry <= 22) {
        wifi_popup_aberto = 0;
        return 1;
    }

    /* Clique em [Escanear] */
    if (rx >= 10 && rx <= 102 && ry >= 32 && ry <= 54) {
        if (wifi_detectar_placa()) {
            wifi_inicializar();
            sys_wifi_scan();
            wifi_copiar_str(wifi_status_msg, "Escaneamento concluido", sizeof(wifi_status_msg));
        } else {
            wifi_copiar_str(wifi_status_msg, "Sem placa Wi-Fi PCI", sizeof(wifi_status_msg));
        }
        return 1;
    }

    /* Clique em [Desconectar] */
    if (rx >= WIFI_POP_W - 112 && rx <= WIFI_POP_W - 10 && ry >= 32 && ry <= 54) {
        sys_wifi_desconectar();
        wifi_indice_selecionado = -1;
        wifi_copiar_str(wifi_status_msg, "Desconectado", sizeof(wifi_status_msg));
        return 1;
    }

    /* Clique em uma rede da lista para conectar */
    int ly = 62;
    int exibidas = 0;
    for (int i = 0; i < MAX_REDES_WIFI && exibidas < WIFI_MAX_VISIVEIS; i++) {
        if (wifi_scan_lista[i].ssid[0] == '\0') continue;

        if (rx >= 10 && rx <= WIFI_POP_W - 10 && ry >= ly && ry <= ly + 24) {
            wifi_indice_selecionado = i;
            if (sys_wifi_conectar(wifi_scan_lista[i].ssid)) {
                dhcp_cliente_iniciar();
                wifi_copiar_str(wifi_status_msg, "Conectado via DHCP!", sizeof(wifi_status_msg));
            } else {
                wifi_copiar_str(wifi_status_msg, "Falha ao conectar na rede", sizeof(wifi_status_msg));
            }
            return 1;
        }
        ly += 27;
        exibidas++;
    }

    return 1;
}

/* ============================================================================
- MENU INICIAR ORGANIZADO POR CATEGORIA
- ============================================================================ */
static void desenhar_menu_iniciar_categorizado(int menu_x, int menu_y, int menu_w, int menu_h, int mx, int my) {
    int cab_h     = 36;
    int rodape_h  = 40;
    int col_esq_w = 215;
    int col_dir_w = menu_w - col_esq_w;
    int corpo_y   = menu_y + cab_h;
    int corpo_h   = menu_h - cab_h - rodape_h;

    desenhar_caixa_com_borda(menu_x, menu_y, menu_w, menu_h, 2, COR_CIANO_NEON, COR_PAINEL);
    desenhar_retangulo_solido(menu_x + col_esq_w, corpo_y, col_dir_w - 2, corpo_h, COR_PAINEL_SEC);
    desenhar_retangulo_solido(menu_x + col_esq_w, corpo_y, 1, corpo_h, COR_BORDA_SUTIL);

    desenhar_retangulo_solido(menu_x + 2, menu_y + 2, menu_w - 4, cab_h - 2, COR_CARD);
    gpu_desenhar_icone(icone_fydelis_f, menu_x + 10, menu_y + 8, ICONE_TAM, ICONE_TAM);
    gpu_escrever_texto("FYDELISTECH OS v4.2", menu_x + 38, menu_y + 10, COR_CIANO_NEON);
    gpu_escrever_texto("admin@fydelis", menu_x + menu_w - 116, menu_y + 10, COR_VERDE_NEON);

    gpu_escrever_texto("APLICATIVOS", menu_x + 14, corpo_y + 8, COR_ROXO_CLARO);
    gpu_escrever_texto("SISTEMA & CONFIG", menu_x + col_esq_w + 12, corpo_y + 8, COR_ROXO_CLARO);

    int idx_esq = 0;
    int idx_dir = 0;
    for (int i = 0; i < TOTAL_ITENS_MENU; i++) {
        int ix, iy, iw;
        int ih = 32;

        if (itens_menu[i].coluna == 0) {
            ix = menu_x + 10;
            iy = corpo_y + 28 + (idx_esq * 36);
            iw = col_esq_w - 20;
            idx_esq++;
        } else {
            ix = menu_x + col_esq_w + 10;
            iy = corpo_y + 28 + (idx_dir * 36);
            iw = col_dir_w - 20;
            idx_dir++;
        }

        int hover = ponto_no_retangulo(mx, my, ix, iy, iw, ih);
        if (hover) {
            desenhar_caixa_com_borda(ix, iy, iw, ih, 1, COR_CIANO_NEON, COR_HOVER);
        }

        gpu_desenhar_icone(itens_menu[i].icone, ix + 6, iy + 6, ICONE_TAM, ICONE_TAM);
        gpu_escrever_texto(itens_menu[i].rotulo, ix + 32, iy + 8,
                           hover ? COR_CIANO_NEON : COR_TEXTO_BRANCO);
    }

    int rod_y = menu_y + menu_h - rodape_h;
    desenhar_retangulo_solido(menu_x + 2, rod_y, menu_w - 4, 1, COR_BORDA_SUTIL);

    int btn_w = (menu_w - 28) / 3;
    int btn_h = 28;
    int btn_y = rod_y + 6;

    int bx1 = menu_x + 8;
    int h1  = ponto_no_retangulo(mx, my, bx1, btn_y, btn_w, btn_h);
    desenhar_caixa_com_borda(bx1, btn_y, btn_w, btn_h, 1, COR_ROXO_NEON, h1 ? COR_HOVER : COR_CARD);
    gpu_desenhar_icone(icone_bloquear, bx1 + 6, btn_y + 4, ICONE_TAM, ICONE_TAM);
    gpu_escrever_texto("Travar", bx1 + 30, btn_y + 6, COR_TEXTO_BRANCO);

    int bx2 = bx1 + btn_w + 6;
    int h2  = ponto_no_retangulo(mx, my, bx2, btn_y, btn_w, btn_h);
    desenhar_caixa_com_borda(bx2, btn_y, btn_w, btn_h, 1, COR_CIANO_NEON, h2 ? COR_HOVER : COR_CARD);
    gpu_desenhar_icone(icone_relogio, bx2 + 6, btn_y + 4, ICONE_TAM, ICONE_TAM);
    gpu_escrever_texto("Reiniciar", bx2 + 30, btn_y + 6, COR_CIANO_NEON);

    int bx3 = bx2 + btn_w + 6;
    int h3  = ponto_no_retangulo(mx, my, bx3, btn_y, btn_w, btn_h);
    desenhar_caixa_com_borda(bx3, btn_y, btn_w, btn_h, 1, COR_VERMELHO_ALERTA, h3 ? 0xFF5A1830 : COR_CARD);
    gpu_desenhar_icone(icone_desligar, bx3 + 6, btn_y + 4, ICONE_TAM, ICONE_TAM);
    gpu_escrever_texto("Desligar", bx3 + 30, btn_y + 6, COR_VERMELHO_ALERTA);
}

/* ============================================================================
- TELA 3: ÁREA DE TRABALHO GRÁFICA (Via Disco ATA e Drag sem Rastro)
- ============================================================================ */
static int exibir_desktop_grafico(int L, int A) {
    char res_buf[48];
    char tmp[16];

    char tz_buf[8];
    int offset_fuso = -3;
    if (fyd_cfg_ler_chave(fs_ler_config_padrao(), "timezone", tz_buf, sizeof(tz_buf)) == 0) {
        if (tz_buf[0] == '-' && tz_buf[1] >= '0' && tz_buf[1] <= '9') {
            offset_fuso = -(tz_buf[1] - '0');
        } else if (tz_buf[0] >= '0' && tz_buf[0] <= '9') {
            offset_fuso = (tz_buf[0] - '0');
        }
    }

    int win_w = (L * 64) / 100;
    if (win_w < 500) win_w = 500;
    int win_h = (A * 56) / 100;
    if (win_h < 300) win_h = 300;
    int win_x = (L - win_w) / 2;
    int win_y = (A - win_h) / 2 - 20;

    int janela_aberta  = 1;
    int modo_janela    = MODO_JANELA_SISTEMA;
    int arrastando     = 0;
    int drag_offset_x  = 0;
    int drag_offset_y  = 0;

    int arrastando_calc = 0;
    int calc_drag_off_x = 0;
    int calc_drag_off_y = 0;

    int arrastando_logs = 0;
    int logs_drag_off_x = 0;
    int logs_drag_off_y = 0;

    int arrastando_exp  = 0;
    int exp_drag_off_x  = 0;
    int exp_drag_off_y  = 0;

    int arrastando_brw  = 0;
    int brw_drag_off_x  = 0;
    int brw_drag_off_y  = 0;

    int taskbar_h      = 38;
    int taskbar_y      = A - taskbar_h;
    int btn_f_x        = 8;
    int btn_f_y        = taskbar_y + 3;
    int btn_f_w        = 42;
    int btn_f_h        = 32;

    int menu_aberto    = 0;
    int menu_x         = 8;
    int menu_w         = 410;
    int menu_h         = 336;
    int menu_y         = taskbar_y - menu_h - 4;

    int precisa_redesenhar = 1;
    int btn_ant        = 0;
    int hover_ant      = -1;

    /* Cache de hardware consultado uma única vez para não travar a interface */
    TelemetriaSistema telemetria;
    inicializar_telemetria(&telemetria, L, A);

    int disco_detectado = telemetria.disco_online;
    int link_rede_ativo = (rede_ler_status_link() != 0);
    int bt_estado       = (int)bt_ler_status();
    int audio_estado    = (int)audio_ler_status();

    fydlog_escrever(LOG_INFO, "Desktop grafico iniciado");
    if (!disco_detectado) {
        fydlog_escrever(LOG_AVISO, "Disco ATA primario nao respondeu");
    }

    RtcDataHora dt_atual;
    rtc_ler_agora(&dt_atual);
    int hora_local = (int)dt_atual.hora + offset_fuso;
    if (hora_local < 0)   hora_local += 24;
    if (hora_local >= 24) hora_local -= 24;
    dt_atual.hora = (uint8_t)hora_local;

    uint8_t min_anterior   = dt_atual.min;
    uint64_t ticks_ant     = timer_ler_ticks();
    uint32_t ciclos_poll   = 0;

    str_copy(res_buf, "Video VESA    : ", sizeof(res_buf));
    num_para_str(L, tmp, sizeof(tmp));
    size_t pos = str_len(res_buf);
    str_copy(res_buf + pos, tmp, sizeof(res_buf) - pos);
    pos = str_len(res_buf);
    str_copy(res_buf + pos, "x", sizeof(res_buf) - pos);
    num_para_str(A, tmp, sizeof(tmp));
    pos = str_len(res_buf);
    str_copy(res_buf + pos, tmp, sizeof(res_buf) - pos);
    pos = str_len(res_buf);
    str_copy(res_buf + pos, " @ 32-bit", sizeof(res_buf) - pos);

    uint64_t tsc_anterior  = ler_tsc();
    uint64_t ciclos_ativos = 0;

    ws_inicializar();

    while (1) {
        int mx, my, mb;
        obter_estado_mouse(&mx, &my, &mb);

        /* Atualiza RTC e telemetria pontualmente (sem repintar a tela inteira) */
        uint64_t ticks_agora = timer_ler_ticks();
        ciclos_poll++;

        if ((ticks_agora - ticks_ant) >= 300 || ciclos_poll >= 250000) {
            ticks_ant   = ticks_agora;
            ciclos_poll = 0;

            rtc_ler_agora(&dt_atual);
            hora_local = (int)dt_atual.hora + offset_fuso;
            if (hora_local < 0)   hora_local += 24;
            if (hora_local >= 24) hora_local -= 24;
            dt_atual.hora = (uint8_t)hora_local;

            int novo_link  = (rede_ler_status_link() != 0);
            int novo_bt    = (int)bt_ler_status();
            int novo_audio = (int)audio_ler_status();

            uint64_t tsc_agora = ler_tsc();
            uint64_t delta_tsc = tsc_agora - tsc_anterior;
            tsc_anterior = tsc_agora;

            if (delta_tsc > 0) {
                int pct = (int)((ciclos_ativos * 100ULL) / delta_tsc);
                if (pct < 2) pct = 2;
                if (pct > 100) pct = 100;
                if (pct != telemetria.cpu_uso_pct) {
                    telemetria.cpu_uso_pct = pct;
                    if (!menu_aberto) {
                        cursor_restaurar_fundo();
                        desenhar_widgets_sistema(L, &telemetria);
                        cursor_desenhar_novo();
                    }
                }
            }
            ciclos_ativos = 0;

            if (dt_atual.min != min_anterior || novo_link != link_rede_ativo ||
                novo_bt != bt_estado || novo_audio != audio_estado) {
                min_anterior    = dt_atual.min;
                link_rede_ativo = novo_link;
                bt_estado       = novo_bt;
                audio_estado    = novo_audio;
                cursor_restaurar_fundo();
                desenhar_systray(L, taskbar_y, taskbar_h, link_rede_ativo, disco_detectado,
                                 bt_estado, audio_estado, &dt_atual, mx, my);
                cursor_desenhar_novo();
            }
        }

        /* Só redesenha o Menu Iniciar quando estiver aberto e o hover mudar */
        int hover_atual = -1;
        if (menu_aberto && ponto_no_retangulo(mx, my, menu_x, menu_y, menu_w, menu_h)) {
            hover_atual = (my - menu_y) / 16;
            if (hover_atual != hover_ant) {
                hover_ant = hover_atual;
                cursor_restaurar_fundo();
                desenhar_menu_iniciar_categorizado(menu_x, menu_y, menu_w, menu_h, mx, my);
                cursor_desenhar_novo();
            }
        } else {
            hover_ant = -1;
        }

        if (precisa_redesenhar) {
            uint64_t t_frame_ini = ler_tsc();
            cursor_restaurar_fundo();
            backbuffer_iniciar_frame();

            /* 1. Wallpaper do Desktop carregado do Disco ATA */
            desenhar_background_ata(LBA_BG_DESKTOP, L, A);

            /* 2. Painel Superior */
            desenhar_retangulo_solido(0, 0, L, 32, COR_PAINEL);
            desenhar_retangulo_solido(0, 32, L, 2, COR_ROXO_NEON);
            gpu_escrever_titulo("FYDELISTECHOS", 14, 4, COR_CIANO_NEON);
            gpu_escrever_texto("Sessao: admin@fydelis", L - 196, 8, COR_VERDE_NEON);

            /* 3. Atalhos Rapidos na Area de Trabalho */
            gpu_desenhar_icone(icone_pasta_fechada, 22, 54, ICONE_TAM, ICONE_TAM);
            gpu_escrever_texto("Explorer", 48, 56, COR_TEXTO_BRANCO);

            gpu_desenhar_icone(icone_iniciar, 22, 88, ICONE_TAM, ICONE_TAM);
            gpu_escrever_texto("Aplicativos", 48, 90, COR_CIANO_NEON);

            gpu_desenhar_icone(icone_config, 22, 122, ICONE_TAM, ICONE_TAM);
            gpu_escrever_texto("Configuracoes", 48, 124, COR_TEXTO_SUAVE);

            gpu_desenhar_icone(icone_ethernet, 22, 156, ICONE_TAM, ICONE_TAM);
            gpu_escrever_texto("FydelisBrowser", 48, 158, COR_CIANO_NEON);

            /* 3.1 Widgets de CPU, RAM e Disco Total */
            desenhar_widgets_sistema(L, &telemetria);

            /* 4. Janela Arrastável Dinâmica */
            if (janela_aberta) {
                desenhar_caixa_com_borda(win_x, win_y, win_w, win_h, 2,
                    arrastando ? COR_CIANO_NEON : COR_ROXO_NEON, COR_CARD);

                desenhar_retangulo_solido(win_x + 2, win_y + 2, win_w - 4, 30, COR_PAINEL);

                const uint32_t *icone_win = icone_sistema;
                const char *titulo_win    = "Painel do Sistema";
                if (modo_janela == MODO_JANELA_APPS) {
                    icone_win  = icone_iniciar;
                    titulo_win = "Central de Aplicativos";
                } else if (modo_janela == MODO_JANELA_CONFIG) {
                    icone_win  = icone_config;
                    titulo_win = "Dispositivos, Rede & Sistema";
                }

                gpu_desenhar_icone(icone_win, win_x + 10, win_y + 7, ICONE_TAM, ICONE_TAM);
                gpu_escrever_texto(titulo_win, win_x + 36, win_y + 9, COR_TEXTO_BRANCO);

                int close_x = win_x + win_w - 28;
                int close_y = win_y + 6;
                desenhar_retangulo_solido(close_x, close_y, 22, 22, COR_VERMELHO_ALERTA);
                gpu_escrever_texto("X", close_x + 7, close_y + 3, COR_TEXTO_BRANCO);

                int cx = win_x + 22;
                int cy = win_y + 46;

                if (modo_janela == MODO_JANELA_SISTEMA) {
                    gpu_escrever_texto("Bem-vindo ao FydelisTechOS (64-bit Long Mode)!", cx, cy, COR_CIANO_NEON);
                    cy += 26;
                    gpu_escrever_texto("Arquitetura   : x86_64 Assembly + C Freestanding", cx, cy, COR_TEXTO_SUAVE);
                    cy += 22;
                    gpu_escrever_texto(res_buf, cx, cy, COR_TEXTO_SUAVE);
                    cy += 22;
                    gpu_escrever_texto("Diretorio CWD : ", cx, cy, COR_TEXTO_SUAVE);
                    gpu_escrever_texto(diretorio_atual, cx + 128, cy, COR_VERDE_NEON);
                    cy += 34;
                    desenhar_caixa_com_borda(cx, cy, win_w - 44, 42, 1, COR_BORDA_SUTIL, COR_INPUT_BG);
                    gpu_escrever_texto("Clique no botao [F] abaixo para abrir Explorer, Browser ou Config.", cx + 12, cy + 13, COR_ROXO_CLARO);
                } else if (modo_janela == MODO_JANELA_APPS) {
                    gpu_escrever_texto("Aplicativos instalados em /fyd/apps:", cx, cy, COR_CIANO_NEON);
                    cy += 28;
                    gpu_desenhar_icone(icone_terminal, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto("FydelTerm Shell (CLI Nativo)", cx + 28, cy, COR_VERDE_NEON);
                    cy += 28;
                    gpu_desenhar_icone(icone_agenda, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto("Agenda & Calendario do Sistema", cx + 28, cy, COR_TEXTO_BRANCO);
                    cy += 28;
                    gpu_desenhar_icone(icone_video, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto("FydelisMedia Player (/fyd/midia)", cx + 28, cy, COR_TEXTO_BRANCO);
                    cy += 28;
                    gpu_desenhar_icone(icone_imagem, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto("Visualizador de Imagens (/fyd/usuario/imagens)", cx + 28, cy, COR_TEXTO_BRANCO);
                } else if (modo_janela == MODO_JANELA_CONFIG) {
                    gpu_escrever_texto("Dispositivos & Hardware (/fyd/config):", cx, cy, COR_CIANO_NEON);
                    cy += 26;
                    gpu_desenhar_icone(icone_ethernet, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto(link_rede_ativo ? "Rede Cabeada (E1000): CONECTADA" : "Rede Cabeada (E1000): Aguardando cabo",
                                       cx + 28, cy, link_rede_ativo ? COR_VERDE_NEON : COR_TEXTO_SUAVE);
                    cy += 26;
                    gpu_desenhar_icone(icone_wifi, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto("Controlador Wi-Fi: Pronto (/fyd/rede)", cx + 28, cy, COR_TEXTO_BRANCO);
                    cy += 26;
                    gpu_desenhar_icone(icone_bluetooth, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto(bt_estado == 2 ? "Bluetooth HCI: Conectado" : (bt_estado == 1 ? "Bluetooth HCI: Ativo" : "Bluetooth HCI: Nao detectado"),
                                       cx + 28, cy, bt_estado ? COR_CIANO_NEON : COR_TEXTO_SUAVE);
                    cy += 26;
                    gpu_desenhar_icone(icone_audio, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto(audio_estado == 1 ? "Audio (AC97/HDA): Ativo" : (audio_estado == 2 ? "Audio: MUDO" : "Audio: Nao detectado"),
                                       cx + 28, cy, audio_estado == 1 ? COR_VERDE_NEON : (audio_estado == 2 ? COR_VERMELHO_ALERTA : COR_TEXTO_SUAVE));
                    cy += 26;
                    gpu_desenhar_icone(icone_disco, cx, cy - 2, ICONE_TAM, ICONE_TAM);
                    gpu_escrever_texto(disco_detectado ? "Disco ATA Primario (0x1F0): Online" : "Disco ATA: Offline",
                                       cx + 28, cy, disco_detectado ? COR_VERDE_NEON : COR_VERMELHO_ALERTA);
                }
            }

            /* Janelas Modulares Independentes */
            if (app_calculadora.aberta) {
                app_calculadora.desenhar();
            }
            if (app_visualizador_logs.aberta) {
                app_visualizador_logs.desenhar();
            }
            if (app_explorer.aberta) {
                app_explorer.desenhar();
            }
            if (app_browser.aberta) {
                app_browser.desenhar();
            }

            /* 5. Barra de Tarefas Inferior */
            desenhar_retangulo_solido(0, taskbar_y, L, taskbar_h, COR_PAINEL);
            desenhar_retangulo_solido(0, taskbar_y, L, 2, COR_CIANO_NEON);

            desenhar_caixa_com_borda(btn_f_x, btn_f_y, btn_f_w, btn_f_h, 1,
                menu_aberto ? COR_CIANO_NEON : COR_ROXO_NEON,
                menu_aberto ? COR_HOVER : COR_CARD);
            gpu_desenhar_icone(icone_fydelis_f, btn_f_x + 11, btn_f_y + 6, ICONE_TAM, ICONE_TAM);

            int tab_x = btn_f_x + btn_f_w + 10;
            desenhar_caixa_com_borda(tab_x, btn_f_y + 1, 195, 30, 1,
                janela_aberta ? COR_CIANO_NEON : COR_BORDA_SUTIL,
                janela_aberta ? COR_HOVER : COR_INPUT_BG);
            const char *rotulo_aba = "Painel do Sistema";
            if (modo_janela == MODO_JANELA_APPS) rotulo_aba = "Aplicativos";
            else if (modo_janela == MODO_JANELA_CONFIG) rotulo_aba = "Configuracoes";
            gpu_escrever_texto(rotulo_aba, tab_x + 16, btn_f_y + 8, COR_TEXTO_BRANCO);

            desenhar_systray(L, taskbar_y, taskbar_h, link_rede_ativo, disco_detectado, bt_estado, audio_estado, &dt_atual, mx, my);

            int term_btn_w = 132;
            int term_btn_x = L - SYSTRAY_LARGURA - term_btn_w - 16;
            desenhar_caixa_com_borda(term_btn_x, btn_f_y + 1, term_btn_w, 30, 1, COR_ROXO_NEON, COR_CARD);
            gpu_desenhar_icone(icone_terminal, term_btn_x + 8, btn_f_y + 6, ICONE_TAM, ICONE_TAM);
            gpu_escrever_texto("FydelTerm", term_btn_x + 34, btn_f_y + 8, COR_VERDE_NEON);

            if (menu_aberto) {
                desenhar_menu_iniciar_categorizado(menu_x, menu_y, menu_w, menu_h, mx, my);
            }

            wifi_popup_desenhar();
            eth_popup_desenhar();

            backbuffer_apresentar_frame(L, A);
            cursor_desenhar_novo();

            ciclos_ativos += (ler_tsc() - t_frame_ini);
            precisa_redesenhar = 0;
        }

        ws_atualizar_cursor();

        int botao_esq_pressionado = (mb & 0x01) != 0;
        int clique_agora = botao_esq_pressionado && !(btn_ant & 0x01);
        btn_ant = mb;

        if (arrastando) {
            if (botao_esq_pressionado) {
                int novo_x = mx - drag_offset_x;
                int novo_y = my - drag_offset_y;

                if (novo_x < 0) novo_x = 0;
                if (novo_x + win_w > L) novo_x = L - win_w;
                if (novo_y < 34) novo_y = 34;
                if (novo_y + win_h > taskbar_y) novo_y = taskbar_y - win_h;

                if (novo_x != win_x || novo_y != win_y) {
                    win_x = novo_x;
                    win_y = novo_y;
                    precisa_redesenhar = 1;
                }
            } else {
                arrastando = 0;
                precisa_redesenhar = 1;
            }
        }

        if (arrastando_calc) {
            if (botao_esq_pressionado) {
                int nx = mx - calc_drag_off_x;
                int ny = my - calc_drag_off_y;

                if (nx < 0) nx = 0;
                if (nx + app_calculadora.w > L) nx = L - app_calculadora.w;
                if (ny < 34) ny = 34;
                if (ny + app_calculadora.h > taskbar_y) ny = taskbar_y - app_calculadora.h;

                if (nx != app_calculadora.x || ny != app_calculadora.y) {
                    app_calculadora.x = nx;
                    app_calculadora.y = ny;
                    precisa_redesenhar = 1;
                }
            } else {
                arrastando_calc = 0;
                precisa_redesenhar = 1;
            }
        }

        if (arrastando_logs) {
            if (botao_esq_pressionado) {
                int nx = mx - logs_drag_off_x;
                int ny = my - logs_drag_off_y;
                if (nx < 0) nx = 0;
                if (nx + app_visualizador_logs.w > L) nx = L - app_visualizador_logs.w;
                if (ny < 34) ny = 34;
                if (ny + app_visualizador_logs.h > taskbar_y) ny = taskbar_y - app_visualizador_logs.h;
                if (nx != app_visualizador_logs.x || ny != app_visualizador_logs.y) {
                    app_visualizador_logs.x = nx;
                    app_visualizador_logs.y = ny;
                    precisa_redesenhar = 1;
                }
            } else {
                arrastando_logs = 0;
                precisa_redesenhar = 1;
            }
        }

        if (arrastando_exp) {
            if (botao_esq_pressionado) {
                int nx = mx - exp_drag_off_x;
                int ny = my - exp_drag_off_y;
                if (nx < 0) nx = 0;
                if (nx + app_explorer.w > L) nx = L - app_explorer.w;
                if (ny < 34) ny = 34;
                if (ny + app_explorer.h > taskbar_y) ny = taskbar_y - app_explorer.h;
                if (nx != app_explorer.x || ny != app_explorer.y) {
                    app_explorer.x = nx;
                    app_explorer.y = ny;
                    precisa_redesenhar = 1;
                }
            } else {
                arrastando_exp = 0;
                precisa_redesenhar = 1;
            }
        }

        if (arrastando_brw) {
            if (botao_esq_pressionado) {
                int nx = mx - brw_drag_off_x;
                int ny = my - brw_drag_off_y;
                if (nx < 0) nx = 0;
                if (nx + app_browser.w > L) nx = L - app_browser.w;
                if (ny < 34) ny = 34;
                if (ny + app_browser.h > taskbar_y) ny = taskbar_y - app_browser.h;
                if (nx != app_browser.x || ny != app_browser.y) {
                    app_browser.x = nx;
                    app_browser.y = ny;
                    precisa_redesenhar = 1;
                }
            } else {
                arrastando_brw = 0;
                precisa_redesenhar = 1;
            }
        }

        if (clique_agora) {
            int term_btn_w = 132;
            int term_btn_x = L - SYSTRAY_LARGURA - term_btn_w - 16;
            int tray_x     = L - SYSTRAY_LARGURA - 8;

            if (wifi_popup_aberto && wifi_popup_processar_clique(mx, my)) {
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, btn_f_x, btn_f_y, btn_f_w, btn_f_h)) {
                menu_aberto = !menu_aberto;
                precisa_redesenhar = 1;
            }
            else if (menu_aberto && ponto_no_retangulo(mx, my, menu_x, menu_y, menu_w, menu_h)) {
                int rod_y = menu_y + menu_h - 40;
                int btn_w = (menu_w - 28) / 3;
                int btn_y = rod_y + 6;

                if (ponto_no_retangulo(mx, my, menu_x + 8, btn_y, btn_w, 28)) {
                    cursor_restaurar_fundo();
                    return 1;
                } else if (ponto_no_retangulo(mx, my, menu_x + 14 + btn_w, btn_y, btn_w, 28)) {
                    energia_reiniciar_agora();
                } else if (ponto_no_retangulo(mx, my, menu_x + 20 + (btn_w * 2), btn_y, btn_w, 28)) {
                    energia_desligar_agora();
                } else {
                    int cab_h = 36, col_esq_w = 215, col_dir_w = menu_w - col_esq_w;
                    int corpo_y = menu_y + cab_h;
                    int idx_e = 0, idx_d = 0;

                    for (int i = 0; i < TOTAL_ITENS_MENU; i++) {
                        int ix = (itens_menu[i].coluna == 0) ? (menu_x + 10) : (menu_x + col_esq_w + 10);
                        int iy = corpo_y + 28 + ((itens_menu[i].coluna == 0 ? idx_e++ : idx_d++) * 36);
                        int iw = (itens_menu[i].coluna == 0) ? (col_esq_w - 20) : (col_dir_w - 20);

                        if (ponto_no_retangulo(mx, my, ix, iy, iw, 32)) {
                            int acao = itens_menu[i].acao_id;
                            if (acao == 1)       { app_explorer.abrir(); }
                            else if (acao == 2)  { modo_janela = MODO_JANELA_APPS;    janela_aberta = 1; }
                            else if (acao == 3)  { cursor_restaurar_fundo(); return 0; }
                            else if (acao == 4)  { modo_janela = MODO_JANELA_APPS;    janela_aberta = 1; }
                            else if (acao == 5)  { modo_janela = MODO_JANELA_SISTEMA; janela_aberta = 1; }
                            else if (acao == 6)  { modo_janela = MODO_JANELA_CONFIG;  janela_aberta = 1; }
                            else if (acao == 7)  { modo_janela = MODO_JANELA_CONFIG;  janela_aberta = 1; }
                            else if (acao == 8)  { app_calculadora.abrir(); }
                            else if (acao == 9)  { app_visualizador_logs.abrir(); }
                            else if (acao == 10) { app_browser.abrir(); }

                            menu_aberto = 0;
                            precisa_redesenhar = 1;
                            break;
                        }
                    }
                }
            }
            else if (app_browser.aberta &&
                     ponto_no_retangulo(mx, my, app_browser.x, app_browser.y,
                                        app_browser.w, app_browser.h)) {
                int rel_x = mx - app_browser.x;
                int rel_y = my - app_browser.y;

                if (rel_x >= app_browser.w - 24 && rel_x <= app_browser.w - 4 &&
                    rel_y >= 3 && rel_y <= 24) {
                    app_browser.aberta = 0;
                    arrastando_brw = 0;
                } else if (rel_y >= 0 && rel_y <= 28) {
                    arrastando_brw = 1;
                    brw_drag_off_x = rel_x;
                    brw_drag_off_y = rel_y;
                } else {
                    app_browser.on_click(rel_x, rel_y);
                }

                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (app_explorer.aberta &&
                     ponto_no_retangulo(mx, my, app_explorer.x, app_explorer.y,
                                        app_explorer.w, app_explorer.h)) {
                int rel_x = mx - app_explorer.x;
                int rel_y = my - app_explorer.y;

                if (rel_x >= app_explorer.w - 24 && rel_x <= app_explorer.w - 4 &&
                    rel_y >= 3 && rel_y <= 24) {
                    app_explorer.aberta = 0;
                    arrastando_exp = 0;
                } else if (rel_y >= 0 && rel_y <= 28) {
                    arrastando_exp = 1;
                    exp_drag_off_x = rel_x;
                    exp_drag_off_y = rel_y;
                } else {
                    app_explorer.on_click(rel_x, rel_y);
                }

                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (app_calculadora.aberta &&
                     ponto_no_retangulo(mx, my, app_calculadora.x, app_calculadora.y,
                                        app_calculadora.w, app_calculadora.h)) {
                int rel_x = mx - app_calculadora.x;
                int rel_y = my - app_calculadora.y;

                if (rel_x >= app_calculadora.w - 24 && rel_x <= app_calculadora.w - 4 &&
                    rel_y >= 3 && rel_y <= 23) {
                    app_calculadora.aberta = 0;
                    arrastando_calc = 0;
                }
                else if (rel_y >= 0 && rel_y <= 26) {
                    arrastando_calc = 1;
                    calc_drag_off_x = rel_x;
                    calc_drag_off_y = rel_y;
                }
                else {
                    app_calculadora.on_click(rel_x, rel_y);
                }

                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (app_visualizador_logs.aberta &&
                     ponto_no_retangulo(mx, my, app_visualizador_logs.x, app_visualizador_logs.y,
                                        app_visualizador_logs.w, app_visualizador_logs.h)) {
                int rel_x = mx - app_visualizador_logs.x;
                int rel_y = my - app_visualizador_logs.y;

                if (rel_x >= app_visualizador_logs.w - 24 && rel_x <= app_visualizador_logs.w - 4 &&
                    rel_y >= 3 && rel_y <= 23) {
                    app_visualizador_logs.aberta = 0;
                    arrastando_logs = 0;
                } else if (rel_y >= 0 && rel_y <= 26) {
                    arrastando_logs = 1;
                    logs_drag_off_x = rel_x;
                    logs_drag_off_y = rel_y;
                } else {
                    app_visualizador_logs.on_click(rel_x, rel_y);
                }
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, btn_f_x + btn_f_w + 10, btn_f_y + 1, 195, 30)) {
                janela_aberta = !janela_aberta;
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, tray_x, btn_f_y, SYSTRAY_LARGURA, 32)) {
                int eth_ico_x  = tray_x + 8;
                int wifi_ico_x = tray_x + 34;

                if (ponto_no_retangulo(mx, my, eth_ico_x - 2, btn_f_y, 26, 32)) {
                    eth_popup_alternar();
                } else if (ponto_no_retangulo(mx, my, wifi_ico_x - 2, btn_f_y, 26, 32)) {
                    eth_popup_aberto = 0;
                    wifi_popup_alternar();
                } else {
                    eth_popup_aberto = 0;
                    wifi_popup_aberto = 0;
                    modo_janela = MODO_JANELA_CONFIG;
                    janela_aberta = 1;
                }
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, term_btn_x, btn_f_y + 1, term_btn_w, 30)) {
                cursor_restaurar_fundo();
                return 0;
            }
            else if (ponto_no_retangulo(mx, my, 22, 54, 110, 22)) {
                app_explorer.abrir();
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, 22, 88, 125, 22)) {
                modo_janela = MODO_JANELA_APPS;
                janela_aberta = 1;
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, 22, 122, 140, 22)) {
                modo_janela = MODO_JANELA_CONFIG;
                janela_aberta = 1;
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (ponto_no_retangulo(mx, my, 22, 156, 150, 22)) {
                app_browser.abrir();
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            else if (janela_aberta) {
                int close_x = win_x + win_w - 28;
                int close_y = win_y + 6;

                if (ponto_no_retangulo(mx, my, close_x, close_y, 22, 22)) {
                    janela_aberta = 0;
                    menu_aberto = 0;
                    precisa_redesenhar = 1;
                } else if (ponto_no_retangulo(mx, my, win_x, win_y, win_w, 32)) {
                    arrastando = 1;
                    drag_offset_x = mx - win_x;
                    drag_offset_y = my - win_y;
                    menu_aberto = 0;
                    precisa_redesenhar = 1;
                } else if (menu_aberto) {
                    menu_aberto = 0;
                    precisa_redesenhar = 1;
                }
            } else if (menu_aberto) {
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
        }

        char tecla;
        while ((tecla = ler_tecla_ps2()) != 0) {
            if (app_browser.aberta) {
                if (tecla == 27) {
                    app_browser.aberta = 0;
                    arrastando_brw = 0;
                } else {
                    app_browser.on_key(tecla);
                }
                precisa_redesenhar = 1;
            } else if (app_explorer.aberta) {
                if (tecla == 27) {
                    app_explorer.aberta = 0;
                    arrastando_exp = 0;
                } else {
                    app_explorer.on_key(tecla);
                }
                precisa_redesenhar = 1;
            } else if (app_calculadora.aberta) {
                if (tecla == 27) {
                    app_calculadora.aberta = 0;
                    arrastando_calc = 0;
                } else {
                    app_calculadora.on_key(tecla);
                }
                precisa_redesenhar = 1;
            } else if (tecla == 27) {
                cursor_restaurar_fundo();
                return 0;
            }
        }

        descansar_cpu_hlt();
    }
}

/* ============================================================================
- PONTO DE ENTRADA CHAMADO PELO KERNEL (kernel_exec_bin)
- ============================================================================ */
int kernel_exec_bin(void) {
    gpu_inicializar();

    if (!fb_base || fb_largura == 0 || fb_altura == 0) {
        return -1;
    }

    int L = (int)fb_largura;
    int A = (int)fb_altura;

    mouse_inicializar();
    ws_inicializar();

    exibir_splash_carregamento(L, A);

    while (1) {
        exibir_tela_login(L, A);
        int acao = exibir_desktop_grafico(L, A);
        if (acao == 0) {
            break;
        }
    }

    return 0;
}
