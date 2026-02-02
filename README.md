# 🚀 Shell-Batch-Downloader (Shell下載助手)

一個基於 Bash 與 Wget 的輕量級、互動式批量下載工具。
無需安裝複雜的環境（如 Python/Node.js），只需一個腳本即可在 Linux/macOS 終端機中實現強大的爬蟲與下載功能。

## ✨ 主要功能 (Features)

* **🛠️ 三種模式**：
    1.  **單檔下載**：快速下載單個連結。
    2.  **目錄抓取 (Spider Mode)**：自動分析網頁目錄 (Apache/Nginx Index)，支援遞迴抓取。
    3.  **列表下載**：讀取 `url_list.txt` 進行批量處理。
* **🔍 智能過濾**：
    * 支援指定 **副檔名** (如 `.mp3`, `.mp4`)。
    * 支援 **關鍵字/正則屏蔽** (排除不需要的檔案)。
    * 支援 **檔案大小閾值** (自動跳過超過 X MB 的檔案)。
* **⚡ 互動體驗**：
    * **預先探測**：下載前自動取得遠端檔案大小並列表展示。
    * **優雅跳過**：下載過程中按下 `Ctrl+C` 僅跳過「當前檔案」，不會中斷整個任務。
* **📊 詳細日誌**：自動生成下載報告與 Log 文件。

## 📦 依賴 (Dependencies)

本腳本僅依賴標準工具，大多數 Linux 發行版已內建：
* `bash`
* `wget` (核心下載工具)
* `awk`, `sed`, `grep`

## 🚀 快速開始 (Quick Start)

你可以直接使用 curl 下載並執行 (詳見下方說明)，或手動執行：

```bash
# 1. 下載腳本
wget [https://github.com/MikuLab39/Shell-Batch-Downloader/main/download.sh](https://github.com/MikuLab39/Shell-Batch-Downloader/main/download.sh)

# 2. 給予執行權限
chmod +x download.sh

# 3. 執行
./download.sh
