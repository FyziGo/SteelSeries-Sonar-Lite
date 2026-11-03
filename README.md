# 🎧 SteelSeries Sonar Lite

> **Run SteelSeries Sonar as a lightweight, headless audio engine with minimal memory footprint (~240 MB instead of ~1.2 GB), without Moments, 3D Aim Trainer, and heavy Electron bloat.**
>
> *Запуск звукового движка SteelSeries Sonar в ультра-легком фоновом режиме с экономией до 1 ГБ оперативной памяти и отключением всех лишних сервисов.*

---

## ⚡ Comparison & Benchmarks / Сравнение производительности

| Metric / Параметр | Stock SteelSeries GG | 🎧 Sonar Lite (Pure) | 🚀 Improvement |
| :--- | :--- | :--- | :--- |
| **Active Processes** | 10–12 processes | **2 processes** | **-80% processes** |
| **RAM Usage** | ~1,100 MB – 1,300 MB | **~240 MB** | **~1 GB RAM saved** |
| **Electron UI Bloat** | ~800 MB (8 instances) | **0 MB (Terminated)** | **100% eliminated** |
| **Video Capture (Moments)**| Active in background | **Disabled** | **0% GPU load** |
| **Audio Processing (EQ / VAD)**| Fully working | **Fully working** | **Identical quality** |
| **ClearCast AI Noise Removal** | Fully working | **Fully working** | **Identical quality** |

---

## 💡 How It Works / Как это работает

SteelSeries GG is built on a multi-service architecture:
1. **The Audio Engine (`SteelSeriesSonar.exe`)**: Written in .NET 8, controls the virtual audio devices (VAD) and audio processing objects (APO). It runs completely independently in the background and **does NOT need the graphical interface** to process sound.
2. **The Heavy Bloatware (`SteelSeriesGGClient.exe`)**: An Electron (Chromium) wrapper running 7–8 sub-processes that consumes ~800–1000 MB RAM simply to display web UI, ads, and store news.
3. **Extra Background Services**: Moments (`SteelSeriesCaptureSvc.exe` + FFmpeg), 3D Aim Trainer, and GameSense CV.

**Sonar Lite** configures SteelSeries GG's internal database (`ggez.db`) and Windows autorun so that:
* On Windows startup, only the headless supervisor and `SteelSeriesSonar` are launched.
* Moments, 3D Aim Trainer, and automatic game scanning are disabled.
* If you have no SteelSeries mouse/keyboard, the Engine module can also be disabled for maximum lightness.
* **When you need to adjust EQ or devices**, you run `Open_Settings.bat`. Tweak your settings in the normal GG window, close it, and Sonar Lite automatically purges the heavy Electron processes while keeping your sound running!

---

## 🚀 Quick Start / Быстрый запуск

1. Download or clone this repository:
   ```bash
   git clone https://github.com/FyziGo/SteelSeries-Sonar-Lite.git
   ```
2. Right-click **`Setup_SonarLite.bat`** and select **Run as Administrator** (or just double-click it; it will prompt for elevation).
3. Choose an option:
   * **`[1] Enable Pure Sonar Mode`**: For users who only care about Sonar (headset only). Maximum lightness (~240 MB RAM).
   * **`[2] Enable Sonar + Engine`**: Keeps SteelSeries Engine active if you also use a SteelSeries mouse, keyboard, or Prism RGB.
   * **`[3] Open Settings`**: Launches the GG UI for configuration, then cleans up memory after you close it.
   * **`[4] Check Status`**: Displays active processes, memory usage, and listening ports.
   * **`[6] Restore Defaults`**: Reverts all changes back to factory SteelSeries GG settings at any time.

---

## 🛠 Script Components / Состав проекта

* **`Setup_SonarLite.bat`**: Interactive console menu for one-click configuration.
* **`SonarLite.ps1`**: Main PowerShell engine that controls processes, Windows autorun, and orchestrates the setup.
* **`sonar_lite.py`**: Safe SQLite database configurator that toggles `sub_apps` and handles automatic backups (`.bak`).
* **`Open_Settings.bat`**: Fast shortcut to open settings and auto-purge Electron memory when finished.
* **`Clean_GUI.bat`**: Instant one-click memory cleaner to purge any leftover `SteelSeriesGGClient.exe` processes.

---

## 📖 CLI Usage (for Advanced Users / PowerShell)

You can run `SonarLite.ps1` directly from an elevated PowerShell prompt:

```powershell
# Apply Pure Sonar mode (Headset only)
.\SonarLite.ps1 debloat

# Apply Sonar mode but keep Engine active (for SS mice/keyboards)
.\SonarLite.ps1 keep-engine

# View active processes and RAM consumption
.\SonarLite.ps1 status

# Open Settings and purge GUI after closing
.\SonarLite.ps1 config

# Restore factory settings from backup
.\SonarLite.ps1 restore
```

---

## ❓ FAQ / Частые вопросы

#### Will my equalizer presets, ClearCast AI, and virtual channels still work?
**Yes.** All virtual channels (*Gaming, Chat, Media, Aux, Mic*), EQ profiles, spatial audio, and ClearCast AI noise cancellation are handled by `SteelSeriesSonar.exe` and the Windows APO driver. They continue working normally.

#### How do I change sound settings or EQ curves?
Run **`Open_Settings.bat`**. It will open the official SteelSeries GG interface. Make any changes you want, then close the GG window and press Enter in the terminal to clean up the ~800 MB Electron memory.

#### Can I undo the changes?
**Yes.** Every time Sonar Lite makes a change, it creates automatic backups of `ggez.db` and `database.db`. You can select **`[6] Restore Factory Defaults`** in the menu at any time to return to stock behavior.

---

## 📄 License
This project is licensed under the [MIT License](LICENSE).
*Disclaimer: This project is an independent optimization tool and is not affiliated with, endorsed by, or associated with SteelSeries ApS.*
