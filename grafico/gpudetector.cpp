#include "gpudetector.h"
#include <QDebug>

GPUDetector& GPUDetector::instancia() {
    static GPUDetector inst;
    return inst;
}

GPUDetector::GPUDetector() = default;

bool GPUDetector::inicializar() {
    qDebug() << "[GPUDetector] Varredura PCI iniciada...";

    if (!pci_gpu_varrer_barramento()) {
        qDebug() << "[GPUDetector] Nenhuma GPU dedicada — usando VESA/GOP";
        m_info.presente = false;
        m_info.tipo = GPUTipo::VesaGenerica;
        m_info.nomeVendedor = "Genérico";
        m_info.nomeDispositivo = "Framebuffer VESA/GOP";
        m_info.aceleracaoDisponivel = false;
        return true; // ✅ Sistema continua funcionando!
    }

    // Preencher detalhes da GPU detectada
    struct RawGPUInfo {
        int presente;
        quint16 vendedor;
        quint16 dispositivo;
        quint64 bar0;
        int tipo;
    } raw;
    pci_gpu_obter_info(&raw);

    m_info.presente = raw.presente != 0;
    m_info.nomeVendedor = traduzirVendedor(raw.vendedor);
    m_info.idCompleta = QString("%1:%2")
        .arg(raw.vendedor, 4, 16, QChar('0'))
        .arg(raw.dispositivo, 4, 16, QChar('0'));

    switch (raw.tipo) {
        case 1: m_info.tipo = GPUTipo::Intel; break;
        case 2: m_info.tipo = GPUTipo::AMD; break;
        case 3: m_info.tipo = GPUTipo::NVIDIA; break;
        case 4: m_info.tipo = GPUTipo::VirtioQEMU; break;
        default: m_info.tipo = GPUTipo::NaoDetectada;
    }

    m_info.mmioBase = raw.bar0;
    m_info.aceleracaoDisponivel = (m_info.tipo != GPUTipo::NaoDetectada);

    qDebug() << "[GPUDetector] ✅ Detectada:" << m_info.nomeVendedor;
    emit gpuDetectada(m_info);
    return true;
}

QString GPUDetector::traduzirVendedor(quint16 id) {
    switch (id) {
        case 0x8086: return "Intel Corporation";
        case 0x1002: return "Advanced Micro Devices";
        case 0x10DE: return "NVIDIA Corporation";
        case 0x1AF4: return "Virtio / QEMU";
        case 0x1234: return "QEMU Padrão";
        default: return QString("Desconhecido (0x%1)").arg(id, 4, 16, QChar('0'));
    }
}

QString GPUDetector::resumo() const {
    if (!m_info.presente) {
        return "🖥️ Modo Genérico — Framebuffer Linear VESA/GOP ativo";
    }
    return QString("⚡ %1 — Aceleração: %2")
        .arg(m_info.nomeVendedor)
        .arg(m_info.aceleracaoDisponivel ? "✅ Pronta" : "⏳ Em desenvolvimento");
}