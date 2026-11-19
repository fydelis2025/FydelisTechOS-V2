# Documentação — FydelisTechOS / FydelTerm

Índice da documentação do projeto, reunindo o percurso de desenvolvimento e as notas técnicas de referência para boot, gráficos e estrutura de pastas.

## História e Evolução

* [FydelTerm — Da Ideia à Versão 4.2](fydelterm-v4.2.md): origem do projeto, ciclos de reestruturação e o estado da versão 4.2.
* [FydelTerm — Da Linha de Comando à Interface Gráfica](jornada-visual.md): experiências com Qt e GTK4, desafios de arquitetura e consolidação da interface oficial.
* [Reconstruindo Aplicativos — Da Migração à Estrutura Própria](reconstrucao-aplicativos.md): desacoplamento de bibliotecas externas e adoção de padrões próprios do sistema.

## Arquitetura e Boot

* [Arquitetura do Sistema](architecture.md): visão por camadas (`boot`, `kernel`, `drivers`, `grafico`, `user`, `virtual`, `tools`) e fluxo de inicialização/GPU (`gpu_dispatch` / `virtio_gpu` / fallback genérico).
* [Layout de Disco e Boot](boot-and-disk-layout.md): organização da imagem híbrida (`LBA 0` com MBR `0x55AA`, `LBA 4096` para `kernel.bin` e `LBA 8192+` para boot/ESP).

## Capturas de Referência

* [Desktop](../assets/images/Desktop.png)
* [FyelTerm](../assets/images/FyelTerm.png)
* [Login](../assets/images/Login.png)
