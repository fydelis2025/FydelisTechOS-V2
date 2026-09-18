#!/bin/bash
# ==========================================
# COMPILADOR RÁPIDO — FYDELIS TECH OS v2.0
# ==========================================
clear
echo "╔══════════════════════════════════════════════════╗"
echo "║   🚀 COMPILANDO FYDELIS TECH OS v2.0             ║"
echo "║   Salvador • Bahia 🇧🇷                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Verificar dependências
echo "🔍 Verificando dependências..."
command -v nasm >/dev/null 2>&1 || { echo "❌ nasm não instalado! sudo apt install nasm"; exit 1; }
command -v gcc >/dev/null 2>&1 || { echo "❌ gcc não instalado! sudo apt install gcc"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "❌ g++ não instalado! sudo apt install g++"; exit 1; }
command -v qmake >/dev/null 2>&1 || { echo "⚠️ Qt não encontrado — interface não será compilada"; }
echo "✅ Dependências OK!"
echo ""

# Compilar tudo
echo "🔨 Iniciando compilação..."
make clean
make -j$(nproc)

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 ==============================================="
    echo "🎉   COMPILAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "🎉 ==============================================="
    echo ""
    echo "📁 Arquivos gerados:"
    echo "   • Kernel:      build/kernel.bin"
    echo "   • FydelisWin:  bin/libfydeliswin.so"
    echo "   • FydelisShell: bin/fydelishell"
    echo "   • Interface:   bin/FydelisTechOS"
    echo ""
    echo "▶️  Para rodar a interface: ./bin/FydelisTechOS"
    echo "▶️  Para rodar o shell:     ./bin/fydelishell"
    echo ""
else
    echo ""
    echo "❌ ERRO na compilação — verifique as mensagens acima."
    exit 1
fi