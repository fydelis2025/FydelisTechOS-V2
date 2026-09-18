// ======================================
// RealSoft OS — Configuração PAM
// Arquivo de cabeçalho compartilhado
// Qt6 Login ↔ Sistema de Autenticação
// ======================================
#ifndef PAM_CONFIG_H
#define PAM_CONFIG_H

// ├── Bibliotecas PAM padrão do Linux
#include <security/pam_appl.h>
#include <security/pam_misc.h>

// ├── Nome do Serviço PAM
// Deve coincidir com: /etc/pam.d/realsoft-login
#define PAM_SERVICE_NAME    "realsoft-login"

// ├── Mensagens de Erro PAM
#define PAM_ERR_SUCCESS     "Autenticacao bem-sucedida"
#define PAM_ERR_UNKNOWN     "Erro desconhecido na autenticacao"
#define PAM_ERR_USER        "Usuario nao encontrado"
#define PAM_ERR_PASSWD      "Senha incorreta"
#define PAM_ERR_ACCT_EXPIRED "Conta expirada"
#define PAM_ERR_AUTH_DOWN   "Servico de autenticacao indisponivel"

// ├── Limites de Segurança
#define PAM_MAX_USERNAME    64
#define PAM_MAX_PASSWORD    128
#define PAM_MAX_RETRIES     3       // Tentativas máximas

// ├── Comportamento da Autenticação
#define PAM_ALLOW_EMPTY_PASSWD  0   // 0 = Senha vazia NÃO permitida
#define PAM_DISALLOW_ROOT_TTY   0   // Restringe root por terminal (opcional)

// ├── Caminhos de Sistema
#define PAM_PASSWD_PATH     "/etc/passwd"
#define PAM_SHADOW_PATH     "/etc/shadow"
#define PAM_GROUP_PATH      "/etc/group"

// ├── Sessão Pós-Login
#define PAM_SESSION_TIMEOUT  0       // 0 = Sem limite
#define PAM_CREATE_HOMEDIR  1       // Cria diretório se não existir
#define PAM_UMASK_DEFAULT   "0022"  // Permissões padrão

// ├── Flags pam_authenticate()
#define PAM_AUTH_FLAGS      0   // 0 = Comportamento padrão

// ├── Códigos de retorno amigáveis
enum PamStatus {
    PAM_OK = 0,
    PAM_ERROR_GENERAL = PAM_BUF_ERR,
    PAM_ERROR_AUTH = PAM_AUTH_ERR,
    PAM_ERROR_CRED = PAM_CRED_ERR,
    PAM_ERROR_ACCT_EXPIRED = PAM_ACCT_EXPIRED,
    PAM_ERROR_PERM_DENIED = PAM_PERM_DENIED
};

#endif // PAM_CONFIG_H