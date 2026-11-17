#include "../include/fyd_formatos.h"

/* Funções do FS e Heap já existentes no seu kernel */
extern void *kmalloc(uint64_t size);
extern void  kfree(void *ptr);
extern int   fs_escrever_arquivo(const char *caminho, const void *dados, uint64_t tamanho);

static void fyd_memcpy(void *dst, const void *src, uint64_t n) {
    uint8_t *d = (uint8_t *)dst;
    const uint8_t *s = (const uint8_t *)src;
    for (uint64_t i = 0; i < n; i++) d[i] = s[i];
}

static void fyd_memset(void *dst, uint8_t val, uint64_t n) {
    uint8_t *d = (uint8_t *)dst;
    for (uint64_t i = 0; i < n; i++) d[i] = val;
}

static int fyd_strncmp(const char *a, const char *b, int n) {
    for (int i = 0; i < n; i++) {
        if (a[i] != b[i]) return (unsigned char)a[i] - (unsigned char)b[i];
        if (a[i] == '\0') return 0;
    }
    return 0;
}

static int fyd_strlen(const char *s) {
    int len = 0;
    while (s[len]) len++;
    return len;
}

/* =========================================================================
 * 1. CARREGADOR DE EXECUTÁVEIS (.fyd)
 * ========================================================================= */
int fyd_validar_executavel(const void *buffer, uint64_t tamanho_buf, FydExecHeader *out_hdr) {
    if (!buffer || tamanho_buf < sizeof(FydExecHeader)) return -1;

    const FydExecHeader *hdr = (const FydExecHeader *)buffer;
    if (hdr->magic != FYD_EXEC_MAGIC) return -2; /* Não é um arquivo .fyd válido */
    if (sizeof(FydExecHeader) + hdr->tamanho_codigo > tamanho_buf) return -3; /* Truncado */
    if (hdr->entry_offset >= hdr->tamanho_codigo) return -4; /* Entry point inválido */

    if (out_hdr) {
        fyd_memcpy(out_hdr, hdr, sizeof(FydExecHeader));
    }
    return 0;
}

int fyd_executar_binario(const void *buffer, uint64_t tamanho_buf) {
    FydExecHeader hdr;
    int err = fyd_validar_executavel(buffer, tamanho_buf, &hdr);
    if (err != 0) return err;

    /* Aloca memória contígua para Código + BSS */
    uint64_t mem_necessaria = hdr.tamanho_codigo + hdr.tamanho_bss;
    uint8_t *area_exec = (uint8_t *)kmalloc(mem_necessaria);
    if (!area_exec) return -5;

    const uint8_t *codigo_src = ((const uint8_t *)buffer) + sizeof(FydExecHeader);
    fyd_memcpy(area_exec, codigo_src, hdr.tamanho_codigo);

    if (hdr.tamanho_bss > 0) {
        fyd_memset(area_exec + hdr.tamanho_codigo, 0, hdr.tamanho_bss);
    }

    /* Salta para o ponto de entrada 64-bit e retorna status em EAX */
    typedef int (*FydEntryFunc)(void);
    FydEntryFunc entry = (FydEntryFunc)(area_exec + hdr.entry_offset);
    int ret = entry();

    kfree(area_exec);
    return ret;
}

/* =========================================================================
 * 2. INSTALADOR DE PACOTES (.fpkg)
 * ========================================================================= */
int fyd_instalar_pacote(const void *buffer, uint64_t tamanho_buf) {
    if (!buffer || tamanho_buf < sizeof(FydPkgHeader)) return -1;

    const FydPkgHeader *pkg = (const FydPkgHeader *)buffer;
    if (pkg->magic != FYD_PKG_MAGIC) return -2;

    uint64_t offset = sizeof(FydPkgHeader);
    const uint8_t *base = (const uint8_t *)buffer;

    for (uint16_t i = 0; i < pkg->qtd_arquivos; i++) {
        if (offset + sizeof(FydPkgEntry) > tamanho_buf) return -3;

        const FydPkgEntry *ent = (const FydPkgEntry *)(base + offset);
        offset += sizeof(FydPkgEntry);

        if (offset + ent->tamanho > tamanho_buf) return -4;

        /* Grava o arquivo extraído no sistema de arquivos /fyd */
        fs_escrever_arquivo(ent->destino, base + offset, ent->tamanho);
        offset += ent->tamanho;
    }

    return (int)pkg->qtd_arquivos;
}

/* =========================================================================
 * 3. PARSER DE CONFIGURAÇÃO (.fcfg)
 * Formato esperado em /fyd/config/*.fcfg:
 *   #!FYDCFG v1
 *   tema=roxo_neon
 *   timezone=-3
 * ========================================================================= */
int fyd_cfg_ler_chave(const char *conteudo_cfg, const char *chave, char *valor_out, int max_len) {
    if (!conteudo_cfg || !chave || !valor_out || max_len <= 0) return -1;

    int chave_len = fyd_strlen(chave);
    const char *p = conteudo_cfg;

    while (*p) {
        /* Ignora espaços iniciais */
        while (*p == ' ' || *p == '\t') p++;

        /* Ignora comentários (#) e linhas vazias */
        if (*p == '#' || *p == '\n' || *p == '\r') {
            while (*p && *p != '\n') p++;
            if (*p == '\n') p++;
            continue;
        }

        /* Verifica se a linha começa com "chave=" */
        if (fyd_strncmp(p, chave, chave_len) == 0 && p[chave_len] == '=') {
            p += chave_len + 1;
            int i = 0;
            while (*p && *p != '\n' && *p != '\r' && i < max_len - 1) {
                valor_out[i++] = *p++;
            }
            valor_out[i] = '\0';
            return 0; /* Chave encontrada */
        }

        /* Avança para a próxima linha */
        while (*p && *p != '\n') p++;
        if (*p == '\n') p++;
    }

    valor_out[0] = '\0';
    return -2; /* Chave não encontrada */
}
