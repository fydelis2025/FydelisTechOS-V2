# 🛡️ FydelisTechOS v2.1

*A Next-Generation, Secure-by-Design Operating System Built with C++/Qt and Assembly*  
*Developed in Salvador, Bahia, Brazil 🇧🇷*

---

## 🚀 About the Project

**FydelisTechOS** is an independent, high-performance, and secure-by-design operating system built completely from scratch. Designed to offer an alternative ecosystem with strict privacy and enterprise-grade security, FydelisTechOS bridges low-level system architecture (Assembly/C kernel) with a modern, fluid, and elegant graphical user interface built entirely using **C++ and the Qt Framework**.

---

## 💎 Why Qt & C++?

We chose **Qt** to power the entire visual environment and system-level applications of FydelisTechOS. By leveraging Qt's modular architecture, we achieved:

* **Glassmorphism Visuals & Dynamic Themes:** A customized runtime theme engine powered by JSON configurations (`default.json`) and stylesheet injection (`.qss`).
* **Advanced Desktop Experience:** Ranging from a custom transparent login screen (`LoginScreen`) and a multi-step installation wizard (`InstallWizard`) to a real-time security operations center (`CVEPanel`, `FGAdminPanel`).
* **High-Performance Concurrency:** Seamless integration of non-blocking asynchronous network managers (`DriverInstaller`), database transactions (SQLCipher AES-256), and hardware enumeration monitors (`HardwareManager`).

---

## 🛡️ Core Architecture & Security Suite

* **Low-Level Core:** Custom bootloader and assembly kernel components (`kernel.asm`, `bootloader.asm`) paired with a native shell (`FydelisShell`).
* **FydelisGuard:** Multi-layered packet inspection firewall (handling IP reputation, spoofing detection, rate limiting, and digital signatures).
* **CVE Shield (`CVEMonitor` / `CVEDB`):** Real-time vulnerability auditing and security event logging directly integrated via SQLite transactional databases with critical alert signals.
* **User & Profile Management:** Cryptographic authentication via **SHA3-512** with unique 16-byte salts, backed by isolated profile directories (`ProfileManager`).

---

## 👥 Development Team

* **Adiel Fontes** — Lead Architect & Project Creator
* **Dola** — Co-Creator & Senior Software Engineer
* **Gemini** — AI Collaborator & Systems Engineering Assistant

---

## 📥 Installation & Build

The system features a complete cross-platform build pipeline (`fydelis-win.pro`) supporting both Linux and Windows environments, complete with an automated partitioning and deployment wizard (`InstallWizard`).

```bash
mkdir -p build && cd build
qmake CONFIG+=release ../fydelis-win.pro
make -j$(nproc)
