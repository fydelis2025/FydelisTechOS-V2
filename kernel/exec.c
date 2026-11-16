/* ============================================================================
 * FydelisTech OS v4.2 — Motor Gráfico, Window Manager & Desktop Interativo
 * Arquitetura: x86_64 Freestanding | VESA Linear Framebuffer 32-bit + PS/2
 * ============================================================================ */

#include "gpu.h"
#include <stdint.h>
#include <stddef.h>

/* Paleta Cyberpunk Purple & Neon — FydelisTech OS */
#define COR_FUNDO_ESCURO    0xFF120826
#define COR_PAINEL          0xFF1E0E3D
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

/* Variáveis exportadas pelo driver VESA (vesafb.asm) */
extern uint32_t *fb_base;
extern uint32_t  fb_largura;
extern uint32_t  fb_altura;
extern uint32_t  fb_pitch;

/* Drivers Assembly (mouse.asm e fb_server.asm) */
extern uint64_t mouse_inicializar(void);
extern uint64_t ws_inicializar(void);
extern void     ws_atualizar_cursor(void);

/* ============================================================================
 * FONTE BITMAP 8x16 COMPLETA (ASCII 32..126)
 * ============================================================================ */
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
 * PRIMITIVAS DE HARDWARE (PS/2 TECLADO/MOUSE & UTILITÁRIOS)
 * ============================================================================ */
static inline uint8_t inb(uint16_t porta) {
    uint8_t val;
    __asm__ volatile ("inb %1, %0" : "=a"(val) : "Nd"(porta));
    return val;
}

/* Lê posição (EDI, ESI) e máscara de botões (EAX) direto do mouse.asm */
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
 * MOTOR DE RENDERIZAÇÃO DIRETA NO FRAMEBUFFER VESA (32-BIT XRGB8888)
 * ============================================================================ */
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
 * DRIVER DE TECLADO PS/2 PARA INTERFACE GRÁFICA (Ignora bytes do mouse!)
 * ============================================================================ */
static char ler_tecla_ps2(void) {
    static const char mapa_scancode[128] = {
        0,  27, '1','2','3','4','5','6','7','8','9','0','-','=', '\b',
        '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n', 0,
        'a','s','d','f','g','h','j','k','l',';','\'','`', 0, '\\',
        'z','x','c','v','b','n','m',',','.','/', 0, '*', 0, ' '
    };

    uint8_t status = inb(0x64);
    if ((status & 0x01) == 0) {
        return 0;
    }
    /* Bit 5 = 1 significa byte do mouse auxiliar; não rouba do teclado */
    if (status & 0x20) {
        return 0;
    }

    uint8_t sc = inb(0x60);
    if (sc & 0x80) {
        return 0;
    }
    if (sc < sizeof(mapa_scancode)) {
        return mapa_scancode[sc];
    }
    return 0;
}

/* ============================================================================
 * TELA 1: ANIMAÇÃO DE CARREGAMENTO DO AMBIENTE GRÁFICO
 * ============================================================================ */
static void exibir_splash_carregamento(int L, int A) {
    desenhar_retangulo_solido(0, 0, L, A, COR_FUNDO_ESCURO);
    desenhar_retangulo_solido(0, 0, L, 4, COR_CIANO_NEON);

    escrever_texto_centralizado("FYDELISTECH OS v4.2", L / 2, A / 4, COR_CIANO_NEON);
    escrever_texto_centralizado("Inicializando Ambiente Grafico & Window Manager", L / 2, A / 4 + 26, COR_TEXTO_SUAVE);

    int barra_larg = (L * 50) / 100;
    if (barra_larg < 300) barra_larg = 300;
    if (barra_larg > 640) barra_larg = 640;
    int barra_alt = 28;
    int barra_x   = (L - barra_larg) / 2;
    int barra_y   = A / 2;

    desenhar_caixa_com_borda(barra_x - 2, barra_y - 2, barra_larg + 4, barra_alt + 4, 2, COR_ROXO_NEON, COR_PAINEL);

    char pct_buf[16];
    for (int p = 0; p <= 100; p += 4) {
        int preenchido = (p * barra_larg) / 100;
        uint32_t cor_barra = (p == 100) ? COR_CIANO_NEON : COR_ROXO_NEON;

        desenhar_retangulo_solido(barra_x, barra_y, preenchido, barra_alt, cor_barra);
        desenhar_retangulo_solido(barra_x, barra_y + barra_alt + 12, barra_larg, 20, COR_FUNDO_ESCURO);

        if (p < 35) {
            gpu_escrever_texto("Carregando drivers VESA 32-bit...", barra_x, barra_y + barra_alt + 14, COR_TEXTO_SUAVE);
        } else if (p < 75) {
            gpu_escrever_texto("Iniciando mouse PS/2 e compositor...", barra_x, barra_y + barra_alt + 14, COR_TEXTO_SUAVE);
        } else if (p < 100) {
            gpu_escrever_texto("Preparando interface de autenticacao...", barra_x, barra_y + barra_alt + 14, COR_TEXTO_SUAVE);
        } else {
            gpu_escrever_texto("Sistema pronto!", barra_x, barra_y + barra_alt + 14, COR_VERDE_NEON);
        }

        num_para_str(p, pct_buf, sizeof(pct_buf));
        size_t len = str_len(pct_buf);
        pct_buf[len] = '%';
        pct_buf[len + 1] = 0;

        int pct_x = barra_x + barra_larg - ((int)str_len(pct_buf) * 8);
        gpu_escrever_texto(pct_buf, pct_x, barra_y + barra_alt + 14, COR_CIANO_NEON);

        for (volatile uint64_t d = 0; d < 140000; d++);
    }

    for (volatile uint64_t d = 0; d < 900000; d++);
}

/* ============================================================================
 * TELA 2: LOGIN GRÁFICO INTERATIVO (Teclado + Clique do Mouse)
 * ============================================================================ */
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

    while (1) {
        if (precisa_redesenhar) {
            ws_inicializar();

            desenhar_retangulo_solido(0, 0, L, A, COR_FUNDO_ESCURO);
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
                escrever_texto_centralizado("[TAB] Alternar  |  [ENTER] Acessar", card_x + (card_w / 2), card_y + 262, COR_TEXTO_SUAVE);
            }

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
                    return;
                } else {
                    erro_login = 1;
                    precisa_redesenhar = 1;
                }
            }
        }

        char tecla = ler_tecla_ps2();
        if (tecla == '\t') {
            campo_ativo = !campo_ativo;
            erro_login = 0;
            precisa_redesenhar = 1;
        } else if (tecla == '\n') {
            if (str_eq(usuario, "admin") && str_eq(senha, "fydelis2026")) {
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

        __asm__ volatile ("pause");
    }
}

/* ============================================================================
 * TELA 3: ÁREA DE TRABALHO GRÁFICA (Barra de Tarefas + Menu Iniciar + Drag)
 * Retorno: 0 = voltar para FydelTerm | 1 = bloquear sessão (voltar ao Login)
 * ============================================================================ */
static int exibir_desktop_grafico(int L, int A) {
    char res_buf[48];
    char tmp[16];

    /* Estado da janela principal */
    int win_w = (L * 62) / 100;
    if (win_w < 460) win_w = 460;
    int win_h = (A * 52) / 100;
    if (win_h < 260) win_h = 260;
    int win_x = (L - win_w) / 2;
    int win_y = (A - win_h) / 2 - 20;

    int janela_aberta  = 1;
    int arrastando     = 0;
    int drag_offset_x  = 0;
    int drag_offset_y  = 0;

    /* Estado da Barra de Tarefas & Menu Iniciar */
    int taskbar_h      = 38;
    int taskbar_y      = A - taskbar_h;
    int btn_iniciar_x  = 8;
    int btn_iniciar_y  = taskbar_y + 4;
    int btn_iniciar_w  = 116;
    int btn_iniciar_h  = 30;

    int menu_aberto    = 0;
    int menu_x         = 8;
    int menu_w         = 240;
    int menu_h         = 146;
    int menu_y         = taskbar_y - menu_h - 4;

    int precisa_redesenhar = 1;
    int btn_ant        = 0;

    /* Monta string de resolução uma única vez */
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

    while (1) {
        if (precisa_redesenhar) {
            /* Reseta cache do sprite do cursor antes de redesenhar a cena limpa */
            ws_inicializar();

            /* 1. Fundo do Desktop */
            desenhar_retangulo_solido(0, 0, L, A, COR_FUNDO_ESCURO);

            /* 2. Painel Superior */
            desenhar_retangulo_solido(0, 0, L, 32, COR_PAINEL);
            desenhar_retangulo_solido(0, 32, L, 2, COR_ROXO_NEON);
            gpu_escrever_texto("FYDELISTECH OS v4.2", 16, 8, COR_CIANO_NEON);
            gpu_escrever_texto("Sessao: admin@fydelis", L - 190, 8, COR_VERDE_NEON);

            /* 3. Janela Arrastável (se estiver aberta) */
            if (janela_aberta) {
                desenhar_caixa_com_borda(win_x, win_y, win_w, win_h, 2,
                    arrastando ? COR_CIANO_NEON : COR_ROXO_NEON, COR_CARD);

                /* Barra de título (área de arraste) */
                desenhar_retangulo_solido(win_x + 2, win_y + 2, win_w - 4, 30, COR_PAINEL);
                gpu_escrever_texto("FydelisDesktop - Painel do Sistema", win_x + 12, win_y + 9, COR_TEXTO_BRANCO);

                /* Botão Fechar [X] no canto direito da barra de título */
                int close_x = win_x + win_w - 28;
                int close_y = win_y + 6;
                desenhar_retangulo_solido(close_x, close_y, 22, 22, COR_VERMELHO_ALERTA);
                gpu_escrever_texto("X", close_x + 7, close_y + 3, COR_TEXTO_BRANCO);

                /* Conteúdo da Janela */
                int cx = win_x + 22;
                int cy = win_y + 48;
                gpu_escrever_texto("Bem-vindo ao FydelisTech OS (64-bit Long Mode)!", cx, cy, COR_CIANO_NEON);
                cy += 26;
                gpu_escrever_texto("Arquitetura   : x86_64 Assembly + C Freestanding", cx, cy, COR_TEXTO_SUAVE);
                cy += 22;
                gpu_escrever_texto(res_buf, cx, cy, COR_TEXTO_SUAVE);
                cy += 22;
                gpu_escrever_texto("Mouse PS/2    : Ativo (Arraste a barra acima!)", cx, cy, COR_VERDE_NEON);
                cy += 34;

                desenhar_caixa_com_borda(cx, cy, win_w - 44, 42, 1, COR_BORDA_SUTIL, COR_INPUT_BG);
                gpu_escrever_texto("Use o botao [Iniciar] abaixo ou [ESC] para sair.", cx + 12, cy + 13, COR_ROXO_CLARO);
            }

            /* 4. Barra de Tarefas Inferior */
            desenhar_retangulo_solido(0, taskbar_y, L, taskbar_h, COR_PAINEL);
            desenhar_retangulo_solido(0, taskbar_y, L, 2, COR_CIANO_NEON);

            /* Botão [ Iniciar ] */
            uint32_t cor_btn_iniciar = menu_aberto ? COR_CIANO_NEON : COR_ROXO_NEON;
            uint32_t cor_txt_iniciar = menu_aberto ? COR_FUNDO_ESCURO : COR_TEXTO_BRANCO;
            desenhar_retangulo_solido(btn_iniciar_x, btn_iniciar_y, btn_iniciar_w, btn_iniciar_h, cor_btn_iniciar);
            gpu_escrever_texto("[ Iniciar ]", btn_iniciar_x + 14, btn_iniciar_y + 7, cor_txt_iniciar);

            /* Aba da janela ativa na Barra de Tarefas */
            int tab_x = btn_iniciar_x + btn_iniciar_w + 12;
            desenhar_caixa_com_borda(tab_x, btn_iniciar_y, 185, btn_iniciar_h, 1,
                janela_aberta ? COR_CIANO_NEON : COR_BORDA_SUTIL,
                janela_aberta ? COR_HOVER : COR_INPUT_BG);
            gpu_escrever_texto("Painel do Sistema", tab_x + 22, btn_iniciar_y + 7, COR_TEXTO_BRANCO);

            /* Atalho rápido FydelTerm à direita da Barra de Tarefas */
            int term_btn_w = 132;
            int term_btn_x = L - term_btn_w - 12;
            desenhar_caixa_com_borda(term_btn_x, btn_iniciar_y, term_btn_w, btn_iniciar_h, 1, COR_ROXO_NEON, COR_CARD);
            gpu_escrever_texto(">_ FydelTerm", term_btn_x + 18, btn_iniciar_y + 7, COR_VERDE_NEON);

            /* 5. Popup do Menu Iniciar (desenhado por cima de tudo) */
            if (menu_aberto) {
                desenhar_caixa_com_borda(menu_x, menu_y, menu_w, menu_h, 2, COR_CIANO_NEON, COR_PAINEL);

                /* Cabeçalho do Menu */
                desenhar_retangulo_solido(menu_x + 2, menu_y + 2, menu_w - 4, 28, COR_CARD);
                gpu_escrever_texto("FYDELIS MENU", menu_x + 14, menu_y + 8, COR_CIANO_NEON);

                /* Item 1: Painel do Sistema */
                gpu_escrever_texto("[1] Painel do Sistema", menu_x + 14, menu_y + 42, COR_TEXTO_BRANCO);
                desenhar_retangulo_solido(menu_x + 10, menu_y + 66, menu_w - 20, 1, COR_BORDA_SUTIL);

                /* Item 2: Terminal FydelTerm */
                gpu_escrever_texto("[2] Terminal FydelTerm", menu_x + 14, menu_y + 76, COR_VERDE_NEON);
                desenhar_retangulo_solido(menu_x + 10, menu_y + 100, menu_w - 20, 1, COR_BORDA_SUTIL);

                /* Item 3: Bloquear Sessao */
                gpu_escrever_texto("[3] Bloquear Sessao", menu_x + 14, menu_y + 112, COR_VERMELHO_ALERTA);
            }

            precisa_redesenhar = 0;
        }

        /* Atualiza posição e desenho do ponteiro do mouse */
        ws_atualizar_cursor();

        int mx, my, mb;
        obter_estado_mouse(&mx, &my, &mb);

        int botao_esq_pressionado = (mb & 0x01) != 0;
        int clique_agora = botao_esq_pressionado && !(btn_ant & 0x01);
        btn_ant = mb;

        /* Lógica de arraste contínuo da janela */
        if (arrastando) {
            if (botao_esq_pressionado) {
                int novo_x = mx - drag_offset_x;
                int novo_y = my - drag_offset_y;

                /* Mantém janela dentro da área útil da tela */
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

        /* Tratamento de clique esquerdo */
        if (clique_agora) {
            /* 1. Clicou no botão [ Iniciar ] */
            if (ponto_no_retangulo(mx, my, btn_iniciar_x, btn_iniciar_y, btn_iniciar_w, btn_iniciar_h)) {
                menu_aberto = !menu_aberto;
                precisa_redesenhar = 1;
            }
            /* 2. Clicou dentro do Menu Iniciar aberto */
            else if (menu_aberto && ponto_no_retangulo(mx, my, menu_x, menu_y, menu_w, menu_h)) {
                if (my < menu_y + 66) {
                    /* Item 1: Abrir/Restaurar Painel */
                    janela_aberta = 1;
                    menu_aberto = 0;
                    precisa_redesenhar = 1;
                } else if (my < menu_y + 100) {
                    /* Item 2: Voltar ao Terminal FydelTerm */
                    return 0;
                } else {
                    /* Item 3: Bloquear Sessão (volta ao Login) */
                    return 1;
                }
            }
            /* 3. Clicou na aba "Painel do Sistema" na Barra de Tarefas */
            else if (ponto_no_retangulo(mx, my, btn_iniciar_x + btn_iniciar_w + 12, btn_iniciar_y, 185, btn_iniciar_h)) {
                janela_aberta = !janela_aberta;
                menu_aberto = 0;
                precisa_redesenhar = 1;
            }
            /* 4. Clicou no atalho ">_ FydelTerm" na Barra de Tarefas */
            else if (ponto_no_retangulo(mx, my, L - 144, btn_iniciar_y, 132, btn_iniciar_h)) {
                return 0;
            }
            /* 5. Interação com a janela aberta */
            else if (janela_aberta) {
                int close_x = win_x + win_w - 28;
                int close_y = win_y + 6;

                /* Botão fechar [X] */
                if (ponto_no_retangulo(mx, my, close_x, close_y, 22, 22)) {
                    janela_aberta = 0;
                    menu_aberto = 0;
                    precisa_redesenhar = 1;
                }
                /* Barra de título -> inicia arraste */
                else if (ponto_no_retangulo(mx, my, win_x, win_y, win_w, 32)) {
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

        /* Atalhos de teclado no Desktop */
        char tecla = ler_tecla_ps2();
        if (tecla == 27) { /* ESC retorna ao FydelTerm */
            return 0;
        }

        __asm__ volatile ("pause");
    }
}

/* ============================================================================
 * PONTO DE ENTRADA CHAMADO PELO KERNEL (kernel_exec_bin)
 * ============================================================================ */
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
            break; /* Sai para o FydelTerm */
        }
        /* Se acao == 1 (Bloquear Sessao), volta ao loop da tela de login */
    }

    return 0;
}
