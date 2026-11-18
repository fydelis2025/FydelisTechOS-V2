#ifndef GPUDETECTOR_H
#define GPUDETECTOR_H

#include <QObject>
#include <QString>

// ==========================================
// 🔍 DETECTOR DE PLACA DE VÍDEO — CAMADA C++
// FydelisTech OS v2.2 · Salvador • Bahia 🇧🇷
// ==========================================

enum class GPUTipo {
    NaoDetectada,
    VesaGenerica,
    Intel,
    AMD,
    NVIDIA,
    VirtioQEMU
};

struct GPUInfo {
    bool presente;
    QString nomeVendedor;
    QString nomeDispositivo;
    QString idCompleta;
    GPUTipo tipo;
    quint64 mmioBase;
    quint64 vramBase;
    bool aceleracaoDisponivel;
};

class GPUDetector : public QObject {
    Q_OBJECT
public:
    static GPUDetector& instancia();

    bool inicializar();
    const GPUInfo& info() const { return m_info; }

    QString resumo() const;
    bool usaFramebufferGenerico() const {
        return m_info.tipo == GPUTipo::VesaGenerica || !m_info.presente;
    }

signals:
    void gpuDetectada(const GPUInfo& info);

private:
    GPUDetector();
    GPUInfo m_info;
    QString traduzirVendedor(quint16 id);
};

// ========== Assembly ↔ C++ ==========
extern "C" {
    int  pci_gpu_varrer_barramento();
    void pci_gpu_obter_info(void* estrutura);
}

#endif // GPUDETECTOR_H