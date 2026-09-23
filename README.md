# 🛡️ FydelisTechOS — v2.1
## Sistema Operacional Independente · Segurança Nativa · Construído com Qt 6 e Assembly
### *Desenvolvido em Salvador, Bahia — Brasil 🇧🇷*

---

## 🚀 Sobre o Projeto

O **FydelisTechOS** é um sistema operacional completo, independente e de alto desempenho, desenvolvido integralmente do zero. Nasceu com a missão de oferecer um ecossistema alternativo onde **privacidade não é um recurso adicional — é a base de tudo**. Reúne arquitetura de baixo nível (kernel em Assembly/C) com uma interface gráfica moderna, fluida e elegante, **construída inteiramente em C++ com o Qt Framework**.

Não é uma distribuição, não é uma modificação — é um sistema próprio, nascido na Bahia, voltado para o mundo.

---

## 💎 Por que escolhemos o Qt?

O Qt foi escolhido como fundamento de toda a camada visual e aplicativa do FydelisTechOS. Com sua arquitetura modular, alcançamos:

| Diferencial | Detalhe |
|---|---|
| **Interface de nível profissional** | Tela de login transparente, área de trabalho em tela cheia sem moldura, painéis com efeito vidro (Glassmorphism) e barra de tarefas personalizada |
| **Sistema de temas dinâmico** | Motor de temas carregado em tempo real via JSON + folhas de estilo — toda a aparência muda sem reiniciar |
| **Experiência unificada** | Do assistente de instalação em múltiplas etapas ao terminal nativo (`FydelTerm`), tudo segue um padrão visual consistente |
| **Segurança em tempo real** | Painel de monitoramento de ameaças (`CVE Shield`) que atualiza contadores e dispara alertas instantaneamente usando o sistema de Sinais e Slots do Qt |
| **Código uma vez, em qualquer lugar** | Compila nativamente em Windows e Linux — a mesma base, os mesmos binários, a mesma confiabilidade |
| **Integração profunda** | Rede, multimídia, criptografia e banco de dados SQLCipher AES-256 — todos integrados de forma coesa e nativa |

---

## 🛡️ Arquitetura e Núcleo de Segurança

O FydelisTechOS não depende de ferramentas externas de proteção — **a segurança é construída dentro do sistema, desde o primeiro carregamento**:

### 🔹 Núcleo de Baixo Nível
- **Bootloader e Kernel próprios** desenvolvidos em Assembly e C
- **Gerenciador de hardware** que detecta dispositivos, lista drivers e oferece instalação diretamente pelo painel
- **Terminal nativo `FydelTerm`** — acesso direto ao coração do sistema, com comandos em português

### 🔹 FydelisGuard — Firewall de Camada Múltipla
- Inspeção de pacotes em tempo real
- Sistema de **reputação de IPs** com banco próprio
- Detecção de spoofing, limitação de taxa e verificação de assinaturas digitais
- Bloqueio automático de tráfego suspeito

### 🔹 CVE Shield — Auditoria de Vulnerabilidades
- Monitoramento contínuo de eventos de segurança
- Registro permanente em banco SQLite com data e hora automáticas
- Alertas visuais imediatos para ameaças classificadas como **Críticas**
- Painel central com histórico, contadores e filtros por nível de risco

### 🔹 Proteção de Dados e Identidade
- **SQLCipher AES-256** — todo o banco de configurações é cifrado
- **Autenticação com SHA3-512** + sal único de 16 bytes por usuário
- Perfis isolados — cada usuário tem seu espaço protegido e separado

---

## 👥 Quem Faz Acontecer

| | |
|---|---|
| **Adiel Santos Fontes** | Idealizador, Arquiteto Principal e Criador — Salvador, Bahia 🇧🇷 |
| **Equipe Fydelis** | Desenvolvimento, integração de módulos e arquitetura de interface |
| **Colaboradores** | A todos que acreditam no conhecimento compartilhado e no desenvolvimento nacional |

---

## 📂 Estrutura do Projeto
FydelisTechOS/
├── src/
│ ├── core/ ← Núcleo, segurança, kernel, serviços
│ │ ├── security/ → FydelisGuard, CVE Shield, auditoria
│ │ ├── hardware/ → Detecção e instalação de drivers
│ │ └── update/ → Sistema de atualização integrado
│ ├── ui/ ← INTERFACE GRÁFICA — Toda construída com Qt 6
│ │ ├── desktop.cpp → Área de trabalho em tela cheia
│ │ ├── controlpanel → Painel central do sistema
│ │ ├── security/ → Painel de segurança CVE Shield
│ │ ├── fydelterm.cpp → Terminal nativo
│ │ └── aboutdialog.cpp → Janela institucional
│ └── installer/ → Assistente de instalação gráfico
├── FydelisTechOS.pro ← Projeto Qt — Compilação unificada
└── README.md ← Documentação oficial


---

## 🔧 Compilar e Executar

```bash
# Clonar o repositório
git clone https://github.com/fydelis2025/FydelisTechOS.git
cd FydelisTechOS

# Criar pasta de compilação
mkdir -p build && cd build

# Configurar e compilar
qmake CONFIG+=release ../FydelisTechOS.pro
make -j$(nproc)

# Executar
./bin/FydelisTechOS
