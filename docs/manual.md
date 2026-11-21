# 📘 FydelTerm — Referência de Comandos

> 
> **Manual Oficial • Versão 2.2**
> Projeto FydelisTechos — Salvador, Bahia

---

## 📑 Sumário

- [Introdução](#introdu%C3%A7%C3%A3o)
- [🔧 Comandos do Sistema](#-comandos-do-sistema)
- [📂 Arquivos e Pastas](#-comandos-de-arquivos-e-pastas)
- [💾 Disco e Sistema de Arquivos](#-comandos-de-disco-e-sistema-de-arquivos)
- [🛡️ Segurança e Diagnóstico](#-comandos-de-seguran%C3%A7a-e-diagn%C3%B3stico)
- [🌐 Rede e Conectividade](#-comandos-de-rede-e-conectividade)
- [📌 Resumo Rápido](#-resumo-r%C3%A1pido)

---

## ✍️ Introdução

Esta é a referência oficial de todos os comandos disponíveis no **FydelTerm**. Cada comando é nativo ao sistema — sem dependências externas. Digite o nome seguido de parâmetros quando necessário. Use `ajuda [comando]` para ver detalhes de qualquer um deles.

> 
> 💡 **Dica:** Comandos não diferenciam maiúsculas de minúsculas. `DIR` e `dir` funcionam da mesma forma.

---

## 🔧 Comandos do Sistema


| Comando | Função | Uso |
| --- | --- | --- |
| `cls` / `limpar` | Limpa a tela do terminal | `cls` ou `limpar` |
| `dizer` | Exibe uma mensagem na tela | `dizer Olá, Fydelis!` |
| `ajuda` | Mostra ajuda geral ou de um comando específico | `ajuda` ou `ajuda listar` |
| `versao` | Exibe a versão do FydelTerm e do sistema | `versao` |
| `sair` | Encerra a sessão atual do terminal | `sair` |
| `reiniciar` | Reinicia o sistema imediatamente | `reiniciar` |
| `desligar` | Encerra e desliga o computador | `desligar` |
| `login` | Inicia uma nova sessão de usuário | `login` |
| `desktop` | Sai do terminal e abre a interface gráfica | `desktop` |

---

## 📂 Comandos de Arquivos e Pastas

Tabela

| Comando | Função | Uso |
| --- | --- | --- |
| `listar` / `dir` | Lista arquivos e pastas do diretório atual | `listar` ou `dir` |
| `estrutura` | Mostra a árvore de pastas de forma hierárquica | `estrutura` |
| `criar_pasta` | Cria uma nova pasta | `criar_pasta projetos` |
| `remover` | Remove um arquivo ou pasta vazia | `remover arquivo.txt` |
| `copiar` | Copia um arquivo para outro local | `copiar origem.txt destino.txt` |

---

## 💾 Comandos de Disco e Sistema de Arquivos

Tabela

| Comando | Função | Uso |
| --- | --- | --- |
| `mkpart` | Cria uma nova partição no disco | `mkpart /dev/sda 2048M` |
| `rmpart` | Remove uma partição existente | `rmpart /dev/sda2` |
| `format` | Formata uma partição com o sistema de arquivos padrão | `format /dev/sda1` |
| `fstype` | Mostra ou altera o tipo de sistema de arquivos de uma partição | `fstype /dev/sda1` |
| `bootmode` | Consulta ou altera o modo de inicialização | `bootmode` ou `bootmode legado` |
| `blkid` | Exibe o identificador único de cada dispositivo de bloco | `blkid` |
| `df` | Mostra espaço usado e livre em cada partição montada | `df` |
| `fsinfo` | Exibe informações detalhadas sobre um sistema de arquivos | `fsinfo /dev/sda1` |

---

## 🛡️ Comandos de Segurança e Diagnóstico

Tabela

| Comando | Função | Uso |
| --- | --- | --- |
| `cve` | Verifica vulnerabilidades conhecidas no sistema | `cve` |
| `fydlog` | Exibe ou filtra os logs do sistema Fydelis | `fydlog` ou `fydlog --erros` |
| `pentest` | Executa testes de segurança no sistema local | `pentest` |
| `fydel` | Painel de controle central do sistema Fydelis | `fydel` |

---

## 🌐 Comandos de Rede e Conectividade

Tabela

| Comando | Função | Uso |
| --- | --- | --- |
| `bt` | Gerencia conexões Bluetooth — lista, conecta ou desconecta dispositivos | `bt listar` ou `bt conectar` |
| `usb` | Lista e gerencia dispositivos USB conectados | `usb` ou `usb ejetar /dev/sdb` |
| `ipconfig` | Mostra ou configura endereço IP, máscara e gateway das interfaces | `ipconfig` |
| `ping` | Testa conectividade com um endereço de rede | `ping 8.8.8.8` |
| `traceroute` | Rastreia o caminho até um destino na rede | `traceroute google.com` |
| `dhcp` | Obtém um endereço IP automaticamente via DHCP | `dhcp eth0` |
| `status_rede` | Exibe o estado geral das interfaces de rede | `status_rede` |
| `arp` | Visualiza ou gerencia a tabela de endereços MAC resolvidos | `arp` |
| `netstat` | Mostra conexões ativas, portas em escuta e estatísticas de rede | `netstat` |
| `wifi` | Gerencia redes Wi-Fi disponíveis — lista, conecta ou desconecta | `wifi listar` ou `wifi conectar Casa` |
| `limpar_rede` | Reseta configurações de rede e libera endereços IP | `limpar_rede` |
| `dhcp_servidor` | Inicia ou para o serviço de servidor DHCP interno | `dhcp_servidor iniciar` |

---

## 📌 Resumo Rápido

```
FydelTerm v2.2 — Comandos Disponíveis

SISTEMA:    cls, limpar, dizer, ajuda, versao, sair, reiniciar, desligar, login, desktop
ARQUIVOS:   listar, dir, estrutura, criar_pasta, remover, copiar
DISCO:      mkpart, rmpart, format, fstype, bootmode, blkid, df, fsinfo
SEGURANÇA:  cve, fydlog, pentest, fydel
REDE:       bt, usb, ipconfig, ping, traceroute, dhcp, status_rede, arp, netstat, wifi, limpar_rede, dhcp_servidor
```

> 
> *"Conhecer seus comandos é conhecer seu sistema. Não decore — entenda o que cada um faz."*
> — FydelisTechos, 2026
