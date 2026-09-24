FydelisTechOS/
│
├── src/
│   │
│   ├── core/                        🧠 NÚCLEO DO SISTEMA
│   │   ├── main.cpp
│   │   ├── versao.h
│   │   │
│   │   ├── fydelispanic.cpp            # Tela de exceção estilo hacker
│   │   ├── fydelispanic.h
│   │   ├── fydelispanic_excecao.cpp
│   │   ├── fydelispanic_excecao.h
│   │   │
│   │   ├── securevault.cpp             # Cofre de dados criptografados
│   │   ├── securevault.h
│   │   ├── configmanager.cpp           # Gerenciador de configurações
│   │   ├── configmanager.h
│   │   ├── securitymanager.cpp         # Gestão de segurança geral
│   │   ├── securitymanager.h
│   │   ├── fsmap.cpp                   # Mapeamento do sistema de arquivos
│   │   ├── fsmap.h
│   │   ├── fydelispentest.cpp          # Módulo de pentest
│   │   ├── fydelispentest.h
│   │   ├── thememanager.cpp            # Sistema de temas
│   │   ├── thememanager.h
│   │   │
│   │   ├── auth/                       🔐 AUTENTICAÇÃO E PERFIS
│   │   │   ├── usuario.cpp
│   │   │   ├── usuario.h
│   │   │   ├── profilemanager.cpp
│   │   │   └── profilemanager.h
│   │   │
│   │   ├── hardware/                   🔧 GERENCIAMENTO DE HARDWARE
│   │   │   ├── hardwaremanager.cpp
│   │   │   ├── hardwaremanager.h
│   │   │   ├── devicedatabase.h
│   │   │   ├── driverinstaller.cpp
│   │   │   └── driverinstaller.h
│   │   │
│   │   ├── security/                   🛡️ FIREWALL • ANTIVÍRUS • CVE
│   │   │   ├── fydelisguard.cpp        # Firewall principal
│   │   │   ├── fydelisguard.h
│   │   │   ├── fydelis_usb_monitor.cpp # Monitoramento USB
│   │   │   ├── fydelis_usb_monitor.h
│   │   │   ├── fydelis_usb_alerta.cpp  # Alertas de dispositivos
│   │   │   ├── fydelis_usb_alerta.h
│   │   │   ├── fg_rules.cpp            # Motor de regras
│   │   │   ├── fg_rules.h
│   │   │   ├── fg_packet.cpp           # Estrutura de pacotes
│   │   │   ├── fg_packet.h
│   │   │   ├── fg_reputation.cpp       # Sistema de reputação
│   │   │   ├── fg_reputation.h
│   │   │   ├── fydelisav.cpp           # Motor antivírus
│   │   │   ├── fydelisav.h
│   │   │   ├── fydelisantivirus.cpp     # Interface antivírus
│   │   │   ├── fydelisantivirus.h
│   │   │   ├── cvedb.cpp               # Banco de vulnerabilidades
│   │   │   ├── cvedb.h
│   │   │   ├── cvemonitor.cpp          # Monitoramento CVE em tempo real
│   │   │   ├── cvemonitor.h
│   │   │   ├── cve_check.cpp           # Verificador de vulnerabilidades
│   │   │   └── cve_check.h
│   │   │
│   │   ├── services/                   ⚙️ GERENCIADOR DE SERVIÇOS
│   │   │   ├── fydelisservices.cpp
│   │   │   ├── fydelisservices.h
│   │   │   ├── servicemodel.cpp
│   │   │   └── servicemodel.h
│   │   │
│   │   └── update/                     🔄 SISTEMA DE ATUALIZAÇÃO
│   │       ├── fydelisupdater.cpp
│   │       ├── fydelisupdater.h
│   │       ├── updatepanel.cpp
│   │       └── updatepanel.h
│   │
│   ├── bridge/                         🔗 PONTE Assembly ↔ Qt
│   │   ├── rede_bridge.cpp             # Comunicação rede/kernel
│   │   ├── rede_bridge.h
│   │   ├── bluetooth_bridge.cpp        # Comunicação Bluetooth/kernel
│   │   └── bluetooth_bridge.h
│   │
│   ├── include/                        📄 CABEÇALHOS COMPARTILHADOS
│   │   ├── fydelterm.inc               # Definições do terminal
│   │   └── syscalls/                   # Chamadas de sistema
│   │       ├── rede_syscalls.h
│   │       └── bt_syscalls.h
│   │
│   ├── boot/                           🚀 CARGA INICIAL — Assembly
│   │   ├── bootloader.asm              # Carregador do kernel
│   │   ├── efi_stub.asm                # Suporte EFI
│   │   ├── linker.ld                   # Script de ligação
│   │   ├── gdt.asm                     # Tabela de descritores globais
│   │   ├── idt.asm                     # Tabela de interrupções
│   │   ├── pci.asm                     # Detecção de dispositivos PCI
│   │   ├── interrupts.asm              # Controlador de interrupções
│   │   └── cpu.asm                     # Detecção e configuração da CPU
│   │
│   ├── kernel/                         💻 NÚCLEO — Assembly Nativo
│   │   ├── kernel.asm                  # Ponto de entrada principal
│   │   ├── pmm.asm                     # Gerenciamento de memória física
│   │   ├── paging.asm                  # Paginação e memória virtual
│   │   ├── heap.asm                    # Alocador dinâmico (Buddy System)
│   │   ├── context.asm                 # Troca de contexto de execução
│   │   ├── scheduler.asm               # Escalonador de processos
│   │   ├── exceptions.asm              # Tratamento de falhas e exceções
│   │   ├── fs.asm                      # Sistema de arquivos (FAT32 + VFS)
│   │   ├── buffer.asm                  # Gerenciamento de buffers
│   │   ├── editor.asm                  # Editor de texto nativo
│   │   ├── commands.asm                # Interpretador de comandos
│   │   └── memmap.asm                  # Mapeamento de memória
│   │
│   ├── drivers/                        🛠️ DRIVERS DE HARDWARE
│   │   ├── timer.asm                   # Contador de tempo (PIT/APIC)
│   │   ├── apic.asm                    # Controlador de interrupções avançado
│   │   ├── ata.asm                     # Controlador de disco
│   │   ├── keyboard.asm                # Entrada de teclado
│   │   ├── audio.asm                   # Sistema de som
│   │   ├── video.asm                   # Saída gráfica
│   │   ├── rede.asm                    # Controlador de rede
│   │   ├── wifi.asm                    # Driver Wi-Fi nativo
│   │   └── bluetooth.asm               # Driver Bluetooth
│   │
│   ├── pentest/                        🔬 FERRAMENTAS DE ANÁLISE
│   │   └── pentest.asm                 # Módulo de pentest em nível baixo
│   │
│   ├── apps/                           📦 APLICATIVOS — POR CATEGORIAS
│   │   │
│   │   ├── produtividade/              📝 ESCRITA, PLANILHAS, APRESENTAÇÕES
│   │   │   ├── fydelis_office/         📊 PACOTE DE ESCRITÓRIO ✅
│   │   │   │   ├── compartilhado/      # Estilos e formatos comuns
│   │   │   │   │   ├── formatos.h
│   │   │   │   │   └── estilos.qss
│   │   │   │   ├── writer/             # Editor de Texto — .fydoc
│   │   │   │   │   ├── fydelis_writer.cpp
│   │   │   │   │   └── fydelis_writer.h
│   │   │   │   ├── calc/               # Planilhas — .fysheet
│   │   │   │   │   ├── fydelis_calc.cpp
│   │   │   │   │   └── fydelis_calc.h
│   │   │   │   ├── slide/              # Apresentações — .fyslide
│   │   │   │   │   ├── fydelis_slide.cpp
│   │   │   │   │   └── fydelis_slide.h
│   │   │   │   └── recursos/           # Modelos, fontes, ícones
│   │   │   │       ├── modelos/
│   │   │   │       ├── fontes/
│   │   │   │       └── icones/
│   │   │   │
│   │   │   ├── fydelis_pp/             🗹 Editor de Código Avançado
│   │   │   ├── fydelis_paint/          🎨 Editor de Imagens
│   │   │   └── fydelis_view/           👁️ Visualizador de Arquivos
│   │   │
│   │   ├── internet/                   🌍 NAVEGAÇÃO E COMUNICAÇÃO
│   │   │   ├── fydelis_web/            # Navegador padrão
│   │   │   ├── fydelis_web_pt/         # Navegador modo pentest
│   │   │   └── fydelis_email/          # Cliente de e-mail
│   │   │
│   │   ├── multimidia/                 🎵 ÁUDIO, VÍDEO E CAPTURA
│   │   │   ├── fydelis_player/         # Reprodutor de mídia
│   │   │   ├── fydelis_cam/            # Controle de webcam
│   │   │   └── fydelis_capture/        # Gravação de tela
│   │   │
│   │   ├── sistema/                    ⚙️ FERRAMENTAS DO SISTEMA
│   │   │   ├── disco_tools/            # Gerenciador de partições
│   │   │   └── updater/                # Atualizador de sistema
│   │   │
│   │   └── seguranca/                  🛡️ FERRAMENTAS DE SEGURANÇA
│   │       ├── fydelis_attack/         # Ferramenta de pentest
│   │       ├── fydelisguard_panel/     # Painel do Firewall
│   │       └── fydelis_analyzer/       # Análise de arquivos e ameaças
│   │
│   ├── ui/                             🖥️ INTERFACE GRÁFICA
│   │   ├── splash/                     # Tela de abertura
│   │   │   ├── splashscreen.cpp
│   │   │   └── splashscreen.h
│   │   ├── login/                      # Tela de autenticação
│   │   │   ├── loginscreen.cpp
│   │   │   └── loginscreen.h
│   │   ├── desktop/                    # Área de Trabalho
│   │   │   ├── desktop.cpp
│   │   │   └── desktop.h
│   │   ├── controlpanel.cpp            # Painel de Controle Central
│   │   ├── controlpanel.h
│   │   ├── fileexplorer.cpp            # Explorador de Arquivos
│   │   ├── fileexplorer.h
│   │   ├── fydelterm.cpp               # Terminal do Sistema 💻
│   │   ├── fydelterm.h
│   │   ├── aboutdialog.cpp             # Tela "Sobre"
│   │   ├── aboutdialog.h
│   │   │
│   │   ├── hardware/                   # Painel de Hardware
│   │   │   ├── hardwarepanel.cpp
│   │   │   └── hardwarepanel.h
│   │   │
│   │   ├── services/                   # Painel de Serviços
│   │   │   ├── servicemanagerpanel.cpp
│   │   │   └── servicemanagerpanel.h
│   │   │
│   │   └── security/                   # Painel de Segurança
│   │       ├── cvepanel.cpp
│   │       ├── cvepanel.h
│   │       └── cvepanel.ui
│   │
│   ├── installer/                      💿 PROGRAMA DE INSTALAÇÃO
│   │   ├── installwizard.cpp
│   │   ├── installwizard.h
│   │   ├── partitionmanager.cpp
│   │   ├── partitionmanager.h
│   │   ├── slideshow.cpp
│   │   ├── slideshow.h
│   │   └── pages/                      # Páginas do assistente
│   │       ├── bemvindopage.cpp
│   │       ├── bemvindopage.h
│   │       ├── idiomapage.cpp
│   │       ├── idiomapage.h
│   │       ├── discopartpage.cpp
│   │       ├── discopartpage.h
│   │       ├── userpage.cpp
│   │       ├── userpage.h
│   │       ├── installpage.cpp
│   │       ├── installpage.h
│   │       ├── resumopage.cpp
│   │       ├── resumopage.h
│   │       ├── conclupage.cpp
│   │       └── conclupage.h
│   │
│   ├── shell/                          🖥️ INTERPRETADORES E CONSOLE
│   └── themes/                         🎨 TEMA E ESTILOS VISUAIS
│
├── resources/                          🎨 RECURSOS COMPARTILHADOS
│   ├── icons/                          # Ícones do sistema
│   ├── images/                         # Imagens e ilustrações
│   └── sounds/                         # Efeitos e áudios
│
├── bin/                                📦 SAÍDA DOS EXECUTÁVEIS
│   ├── Produtividade/                  # FydelisOffice + Editores
│   ├── Internet/                       # Navegadores e Email
│   ├── Multimidia/                     # Player, Câmera, Captura
│   ├── Sistema/                        # Ferramentas e Atualizador
│   └── Seguranca/                      # Firewall, Antivírus, Pentest
│
├── FydelisTechOS.pro                   ⚙️ PROJETO QT — Configuração Completa
└── Makefile                            🔨 COMPILAÇÃO DO KERNEL NATIVO
