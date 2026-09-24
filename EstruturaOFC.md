```text
FydelisTechOS/
│
├── FydelisSystem/                  🛡️ NÚCLEO DO SISTEMA
│   ├── database/                    → Bancos SQLite (config, segurança)
│   ├── security/                    → Firewall + Antivírus + Monitor USB
│   │   ├── quarentena/              → Arquivos isolados
│   │   ├── antivirus.db
│   │   └── usb_monitor.db
│   ├── profiles/                    → Perfis de usuários
│   ├── kernel/                      → Kernel nativo + Assembly
│   ├── drivers/                     → Drivers de hardware
│   └── services/                    → Serviços em segundo plano
│
├── Users/
│   └── Default/                     📂 PERFIL PADRÃO DO USUÁRIO
│       ├── Downloads/               → Arquivos baixados
│       ├── Documentos/               → Trabalhos, documentos (.fydoc, .fysheet, .fyslide)
│       ├── Imagens/                 → Fotos e capturas
│       ├── Musicas/                  → Áudios e playlists
│       ├── Videos/                   → Vídeos
│       ├── Desktop/                  → Área de trabalho (atalhos)
│       └── Favoritos/                → Links e marcadores
│
├── Program Files/                   📦 APLICATIVOS — POR CATEGORIAS
│   └── FydelisTech-Suite/
│       │
│       ├── Produtividade/            📝 Escrita, Planilhas, Desenho
│       │   ├── FydelisTech++/       🗒️ Editor de Texto (avançado)
│       │   ├── Fydelis-Paint/       🎨 Editor de Imagem
│       │   ├── FydelisView/         📄 Visualizador de Arquivos
│       │   │
│       │   └── FydelisOffice/       📊 PACOTE DE ESCRITÓRIO ✅
│       │       ├── fydelis_writer.exe       📝 Editor de Texto (.fydoc)
│       │       ├── fydelis_calc.exe         📊 Planilhas (.fysheet)
│       │       ├── fydelis_slide.exe        📈 Apresentações (.fyslide)
│       │       ├── recursos/                📄 Modelos, fontes, recursos
│       │       │   ├── modelos/
│       │       │   │   ├── carta.fytpl
│       │       │   │   ├── relatorio.fytpl
│       │       │   │   └── apresentacao.fytpl
│       │       │   ├── fontes/
│       │       │   └── icones/
│       │       └── compartilhado/           🔧 Código/estilos comuns
│       │           ├── estilos.qss
│       │           └── formatos.h
│       │
│       ├── Internet/                 🌍 Navegação, Email, Rede
│       │   ├── FydelisTech-Web/       🌍 Navegador — Uso Geral
│       │   ├── fydelis-email/         ✉️ Gerenciador de Email
│       │   └── FydelisTech-Web-Pentest/ 🔍 Navegador — Análise/Pentest
│       │
│       ├── Multimidia/               🎵 Áudio, Vídeo, Câmera
│       │   ├── Fydelis-Player/        ▶️ Reprodutor de Música e Vídeo
│       │   ├── FydelisCam/            📷 Gerenciador de Webcam
│       │   └── FydelisCapture/       🎥 Gravador de Tela/Câmera
│       │
│       ├── Sistema/                  ⚙️ Discos, Partições, Atualização
│       │   ├── FydelisTech-DiscoTools/ 💿 Gerenciador de Partições
│       │   └── FydelisTech-Updater/   🔄 Atualizador do Sistema
│       │
│       └── Seguranca/                 🛡️ Firewall, Pentest, Análise
│           ├── FydelisTech-Attack/    ⚠️ Ferramenta de Pentest
│           ├── FydelisGuard-Painel/   🛡️ Painel do Firewall
│           └── Fydelis-Analyzer/       🔬 Análise de Arquivos e Ameaças
│
├── Windows/                         🪟 CAMADA DE COMPATIBILIDADE (.exe externos)
│   ├── System32/
│   ├── System64/
│   └── System32/WindowsPowerShell/
│
└── ProgramData/                     📋 DADOS GLOBAIS COMPARTILHADOS
    ├── Config/                       → Configurações de todos os apps
    ├── Logs/                          → Registros do sistema
    └── Cache/                         → Arquivos temporários
