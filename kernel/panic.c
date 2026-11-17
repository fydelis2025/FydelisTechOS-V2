#include <stdint.h>
#include "../include/fydlog.h"

extern uint32_t *fb_base;
extern uint32_t  fb_largura;
extern uint32_t  fb_altura;
extern uint32_t  fb_pitch;

extern void gpu_escrever_titulo(const char *texto, int x, int y, uint32_t cor);
extern void gpu_escrever_texto(const char *texto, int x, int y, uint32_t cor);
extern void print_string(const char *s);
extern void print_newline(void);
extern void fydelis_panic_excecao(void);

static void u64_para_hex(uint64_t val, char *out) {
    const char *hex = "0123456789ABCDEF";
    out[0] = '0';
    out[1] = 'x';
    for (int i = 0; i < 16; i++) {
        out[2 + i] = hex[(val >> ((15 - i) * 4)) & 0xF];
    }
    out[18] = '\0';
}

static void panic_retangulo(int x, int y, int w, int h, uint32_t cor) {
    if (!fb_base || fb_largura == 0 || fb_altura == 0) return;
    uint32_t stride = (fb_pitch > 0) ? (fb_pitch / 4) : fb_largura;

    for (int dy = 0; dy < h; dy++) {
        int py = y + dy;
        if (py < 0 || py >= (int)fb_altura) continue;
        uint32_t *linha = fb_base + (py * stride);
        for (int dx = 0; dx < w; dx++) {
            int px = x + dx;
            if (px >= 0 && px < (int)fb_largura) {
                linha[px] = cor;
            }
        }
    }
}

void kernel_panic_handler(
    uint64_t vetor_id,
    uint64_t error_code,
    uint64_t rip,
    uint64_t cr2,
    uint64_t rsp_orig,
    const uint64_t *regs
) {
    (void)regs;

    const char *nome_exc = "EXCECAO DESCONHECIDA DE CPU";
    const char *log_msg  = "PANIC: Excecao critica de hardware";

    if (vetor_id == 0) {
        nome_exc = "#DE — DIVISAO POR ZERO (Vetor 0)";
        log_msg  = "PANIC #DE: Divisao por zero no kernel";
    } else if (vetor_id == 8) {
        nome_exc = "#DF — FALHA DUPLA / DOUBLE FAULT (Vetor 8)";
        log_msg  = "PANIC #DF: Falha dupla de pilha/IDT";
    } else if (vetor_id == 13) {
        nome_exc = "#GP — FALHA DE PROTECAO GERAL (Vetor 13)";
        log_msg  = "PANIC #GP: Acesso invalido de segmento/instrucao";
    } else if (vetor_id == 14) {
        nome_exc = "#PF — FALHA DE PAGINA / PAGE FAULT (Vetor 14)";
        log_msg  = "PANIC #PF: Acesso a pagina de memoria nao mapeada";
    }

    /* 1. Registra no FydLog (/fyd/dados/logs/sistema.flog) e no console texto */
    fydlog_escrever(LOG_CRITICO, log_msg);
    print_newline();
    print_string("================ [ FYDELISTECH OS - KERNEL PANIC ] ================");
    print_newline();
    print_string(nome_exc);
    print_newline();

    char hex_rip[20], hex_cr2[20], hex_err[20], hex_rsp[20];
    u64_para_hex(rip, hex_rip);
    u64_para_hex(cr2, hex_cr2);
    u64_para_hex(error_code, hex_err);
    u64_para_hex(rsp_orig, hex_rsp);

    print_string("RIP: "); print_string(hex_rip);
    print_string("  CR2: "); print_string(hex_cr2);
    print_newline();
    print_string("ERR: "); print_string(hex_err);
    print_string("  RSP: "); print_string(hex_rsp);
    print_newline();

    /* 2. Se o Framebuffer VESA estiver ativo, desenha a Tela de Panic Gráfica */
    if (fb_base && fb_largura > 0 && fb_altura > 0) {
        int L = (int)fb_largura;
        int A = (int)fb_altura;

        /* Fundo vermelho-escuro cyberpunk com borda de alerta */
        panic_retangulo(0, 0, L, A, 0xFF1A050D);
        panic_retangulo(0, 0, L, 48, 0xFF991B1B);
        panic_retangulo(0, 48, L, 3, 0xFFFF4D6D);

        gpu_escrever_titulo("FYDELISTECH OS — KERNEL PANIC (PARADA DE SEGURANCA)", 24, 12, 0xFFFFFFFF);

        int bx = 40;
        int by = 80;
        int bw = L - 80;
        int bh = A - 130;
        panic_retangulo(bx, by, bw, bh, 0xFF290A14);

        gpu_escrever_texto("O nucleo interceptou uma excecao critica e interrompeu a execucao:", bx + 20, by + 20, 0xFFFCA5A5);
        gpu_escrever_texto(nome_exc, bx + 20, by + 50, 0xFF00F5D4);

        gpu_escrever_texto("Ponteiro de Instrucao (RIP) :", bx + 20, by + 95,  0xFFCBD5E1);
        gpu_escrever_texto(hex_rip,                        bx + 260, by + 95, 0xFFFFFFFF);

        gpu_escrever_texto("Endereco Faltante (CR2)     :", bx + 20, by + 125, 0xFFCBD5E1);
        gpu_escrever_texto(hex_cr2,                        bx + 260, by + 125, 0xFFFF4D6D);

        gpu_escrever_texto("Codigo de Erro (ERR)        :", bx + 20, by + 155, 0xFFCBD5E1);
        gpu_escrever_texto(hex_err,                        bx + 260, by + 155, 0xFFFFFFFF);

        gpu_escrever_texto("Pilha Original (RSP)        :", bx + 20, by + 185, 0xFFCBD5E1);
        gpu_escrever_texto(hex_rsp,                        bx + 260, by + 185, 0xFFFFFFFF);

        gpu_escrever_texto("Evento registrado em /fyd/dados/logs/sistema.flog [LOG_CRITICO].", bx + 20, by + 235, 0xFF00FF9C);
        gpu_escrever_texto("Reinicie a maquina virtual ou pressione Reset para reiniciar.", bx + 20, by + 265, 0xFFCBD5E1);
    }

    /* 3. Paralisa a CPU com seguranca */
    fydelis_panic_excecao();
}
