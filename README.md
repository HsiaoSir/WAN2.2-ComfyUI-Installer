# WAN2.2-ComfyUI-Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04%20%7C%2026.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Arch](https://img.shields.io/badge/Arch-x86__64%20%7C%20aarch64-blue)](https://github.com/HsiaoSir/WAN2.2-ComfyUI-Installer)
[![Python](https://img.shields.io/badge/Python-3.10--3.14-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![PyTorch](https://img.shields.io/badge/PyTorch-cu128-EE4C2C?logo=pytorch&logoColor=white)](https://pytorch.org/)
[![ComfyUI](https://img.shields.io/badge/ComfyUI-native-1A1A1A?logo=github&logoColor=white)](https://github.com/comfyanonymous/ComfyUI)
[![HF Models Verified](https://img.shields.io/badge/HF%20URLs-75%2F75%20verified-FFD21E?logo=huggingface&logoColor=black)](模型清單.md)
[![Last commit](https://img.shields.io/github/last-commit/HsiaoSir/WAN2.2-ComfyUI-Installer)](https://github.com/HsiaoSir/WAN2.2-ComfyUI-Installer/commits/main)
[![Stars](https://img.shields.io/github/stars/HsiaoSir/WAN2.2-ComfyUI-Installer?style=social)](https://github.com/HsiaoSir/WAN2.2-ComfyUI-Installer/stargazers)

> Wan2.2-TI2V-5B × ComfyUI 一鍵安裝包 —— Ubuntu **22.04 / 24.04 / 26.04** (**x86_64** 或 **aarch64**) + **NVIDIA RTX**
>
> 為新手寫的腳本與文件:全程冪等(可重複執行),所有 HuggingFace 網址與安裝邏輯都已實測驗證。

---

## 目錄

- [這個專案是什麼](#這個專案是什麼)
- [系統需求](#系統需求)
- [安裝(從這裡開始)](#安裝從這裡開始)
- [啟動 ComfyUI](#啟動-comfyui)
- [在介面裡產生第一支影片](#在介面裡產生第一支影片)
- [專案檔案說明](#專案檔案說明)
- [完整資料夾架構(每個資料夾放什麼)](#完整資料夾架構每個資料夾放什麼)
- [下載更多模型(可選)](#下載更多模型可選)
- [進階選項](#進階選項)
- [可重複執行(idempotent)說明](#可重複執行idempotent說明)
- [已驗證項目](#已驗證項目)
- [常見問題](#常見問題)
- [更多文件](#更多文件)
- [來源與致謝](#來源與致謝)
- [授權](#授權)

---

## 這個專案是什麼

- 把 [Wan2.2-TI2V-5B](https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B)(50 億參數的影片生成模型)
  自動部署到本機 [ComfyUI](https://github.com/comfyanonymous/ComfyUI),從零環境到能跑只要一條指令。
- TI2V-5B 同時支援**文字→影片(T2V)** 與 **圖片→影片(I2V)**,輸出 **720p @ 24fps、約 5 秒**,
  官方稱 **8GB VRAM** 就跑得動;12GB 卡跑起來相當輕鬆。
- 內建多個 14B 變體選項(t2v / i2v / animate / s2v / Fun control/inpaint/camera/vace / ChronoEdit / 4-step 閃電 LoRA),
  以及完整的 **75 個官方 HuggingFace 檔案目錄**(全部 HTTP 驗證過;另有 21 個 Kijai/lightx2v/RIFE/upscaler/GFPGAN 等社群相依模型,用 ./download_models.sh --list 看完整列表)。

---

## 系統需求

| 項目 | 需求 |
|---|---|
| 作業系統 | **Ubuntu 22.04 / 24.04 / 26.04** (三個版本都在 amd64 容器實測過) |
| CPU 架構 | **x86_64** 或 **aarch64** (PyTorch cu128 兩種架構都有 manylinux 輪子) |
| GPU | NVIDIA RTX,VRAM ≥ 8GB(12GB 充裕);驅動 ≥ 550 |
| 硬碟 | 預留 **30GB+**(主程式 + 17GB 模型),裝 14B 變體要更多 |
| Python | 系統預設 `python3` 即可(腳本相容 3.10–3.14) |
| 網路 | 下載模型約 17GB(可續傳) |

> 想跑 14B 變體要更多 VRAM(fp8 量化版 12GB 可勉強);純 5B 在 8–12GB 都順。

---

## 安裝(從這裡開始)

### 0. 先確認有 git(沒有就裝一下)

新裝好的 Ubuntu 預設**沒有 git**,要先用 apt 裝:

```bash
sudo apt update && sudo apt install -y git
```

> 想確認有沒有裝:`git --version`,印出版本號(例如 `git version 2.43.0`)就 OK。
> 如果你的機器其實已經有 git,這步可以跳過。

### 1. Clone 這個 repo

```bash
git clone https://github.com/HsiaoSir/WAN2.2-ComfyUI-Installer.git
cd WAN2.2-ComfyUI-Installer
```

### 2. 給腳本執行權限(只需一次)

```bash
chmod +x *.sh
```

### 3. 一鍵安裝 + 下載模型

```bash
./setup.sh
```

`setup.sh` 會依序:
1. 偵測 Ubuntu 版本與 CPU 架構
2. 安裝系統相依套件(`git`, `ffmpeg`, `build-essential`, `python3-venv`, `aria2`, …)
3. clone ComfyUI 主程式
4. 建立 Python 虛擬環境(`ComfyUI/.venv/`)
5. 安裝對應架構/版本的 PyTorch CUDA 輪子(預設 cu128)
6. 安裝 ComfyUI 的 Python 相依套件
7. 下載 Wan2.2-TI2V-5B 三個模型檔(主模型 + 文字編碼器 + VAE,共約 17GB)

裝完最後會印:
```
✅ 全部就緒!
啟動 ComfyUI:
    ./start.sh
然後瀏覽器開:http://127.0.0.1:8188
```

> **如果有任何一步失敗**:直接重跑 `./setup.sh`,已完成的會自動略過,只補沒完成的部分。

### 其他安裝模式

```bash
./setup.sh --no-models                 # 只裝環境,先不下載 17GB 模型
./setup.sh --start                     # 裝完直接啟動 ComfyUI
./setup.sh --14b-t2v                   # 預設 5B + 加裝 14B 文生影片 (~28GB)
./setup.sh --all                       # 5B + 14B t2v + 14B i2v + 4-step LoRA
./install.sh                           # 只跑安裝,不下載模型
./download_models.sh --list            # 列出所有可下載的模型旗標
```

---

## 啟動 ComfyUI

### 第一次啟動(剛裝完)

```bash
./start.sh
```

### 第二次以後(重開機 / 關掉終端後想再開)

```bash
cd ~/WAN2.2-ComfyUI-Installer    # 回到專案資料夾
./start.sh                       # 直接啟動,不需要再裝
```

> **不用再跑 `./setup.sh` 或 `./install.sh`** —— 那些只是裝環境,裝過就好。
> 每次要用就 `./start.sh` 一條指令。

終端機會看到:
```
==> 啟動 ComfyUI:http://127.0.0.1:8188
    (Ctrl+C 結束)
```

打開瀏覽器進 [http://127.0.0.1:8188](http://127.0.0.1:8188) 即可開始用。
**要結束**:回終端機按 **Ctrl+C**;下次想用再 `./start.sh`。

| 啟動選項 | 用途 |
|---|---|
| `./start.sh` | 一般啟動 |
| `./start.sh --lowvram` | 顯存吃緊時(自動把權重 offload 到 RAM/磁碟) |
| `./start.sh --novram` | 極省 VRAM(很慢,通常用不到) |
| `./start.sh --listen` | 開放區網其他電腦/手機從本機 IP 連入 |
| `PORT=9000 ./start.sh` | 換 port |
| `./start.sh --use-sage-attention` | 啟用 Sage Attention 加速(需先 `pip install sageattention`) |

---

## 在介面裡產生第一支影片

1. 左上選單 **Workflow → Browse Templates → Video**
2. 點 **「Wan2.2 5B」**(或對應你裝的模型)載入範本
3. 確認三個載入節點對到正確檔案:
   - **Load Diffusion Model** → `wan2.2_ti2v_5B_fp16.safetensors`
   - **Load CLIP**(type: `wan`) → `umt5_xxl_fp8_e4m3fn_scaled.safetensors`
   - **Load VAE** → `wan2.2_vae.safetensors`
4. **文生影片**:在正向提示詞欄輸入英文描述(可加鏡頭運動關鍵字,例如 `slow dolly in`)
   **圖生影片**:把起始圖放到 `ComfyUI/input/`,在 `Load Image` 節點選它
5. 點 **Queue / Run** → 等進度條跑完 → 影片在 `ComfyUI/output/`

完整提示詞公式、風格關鍵字、三組參數配方(測試/平衡/高畫質)請看
[風格與參數預設.md](風格與參數預設.md)。

---

## 專案檔案說明

| 檔案 | 作用 |
|---|---|
| `setup.sh` | **總入口**:一鍵跑完安裝 + 下載 + 顯示啟動方式 |
| `install.sh` | 安裝環境:系統套件 + ComfyUI + venv + PyTorch CUDA |
| `download_models.sh` | 下載模型:清單驅動,支援 15 種旗標(5B/14B 全變體) |
| `start.sh` | 啟動 ComfyUI 伺服器 |
| `README.md` | 本檔:總覽、安裝、使用 |
| [安裝手冊.md](安裝手冊.md) | 詳細逐步教學 + 疑難排解 + 冪等原理 |
| [模型清單.md](模型清單.md) | 75 個官方 Wan2.2/2.1 模型完整目錄(HTTP 驗證過) |
| [風格與參數預設.md](風格與參數預設.md) | 提示詞公式、風格關鍵字、參數配方 |

---

## 完整資料夾架構(每個資料夾放什麼)

安裝後會多出 `ComfyUI/` 子資料夾,結構如下(★ = 跑 TI2V-5B 必備):

```
WAN2.2-ComfyUI-Installer/
├── setup.sh                ← 你執行這個
├── install.sh
├── download_models.sh
├── start.sh
├── README.md / 安裝手冊.md / 模型清單.md / 風格與參數預設.md
└── ComfyUI/                ← install.sh 建立
    ├── main.py             ← ComfyUI 主程式
    ├── .venv/              ← Python 虛擬環境
    ├── input/              ← 「圖生影片」要用的輸入圖片放這
    ├── output/             ← ★ 產出的影片/圖片在這
    ├── custom_nodes/       ← 第三方擴充節點 (e.g. ComfyUI-Manager)
    ├── user/               ← 你的工作流 JSON、UI 設定
    └── models/
        ├── diffusion_models/  ← ★ 主模型 (UNet/DiT 權重)
        │   └── wan2.2_ti2v_5B_fp16.safetensors
        ├── text_encoders/     ← ★ 文字編碼器 (umT5-XXL)
        │   └── umt5_xxl_fp8_e4m3fn_scaled.safetensors
        ├── vae/               ← ★ VAE (像素↔潛空間 轉換)
        │   └── wan2.2_vae.safetensors
        ├── loras/             ← LoRA 微調權重(預設空,跑 5B 用不到)
        ├── clip_vision/       ← Wan2.1 部分 I2V 工作流需要
        └── audio_encoders/    ← S2V 聲音→影片才需要
```

ComfyUI 靠 `models/` 底下的**子資料夾名稱**自動分類,放錯資料夾在介面上會找不到。
`download_models.sh` 會自動放到正確位置。

---

## 下載更多模型(可選)

預設只裝 5B (~17GB)。想加裝 14B 變體或其他模型?照下面三步走,**已下載且完整的會自動略過**(不會重抓):

### 步驟 1:回到專案資料夾

```bash
cd ~/WAN2.2-ComfyUI-Installer    # 換成你 clone 的實際路徑
```

> 不確定在哪?用 `pwd` 看當下位置;找不到資料夾就 `cd ~ && find . -name "WAN2.2-ComfyUI-Installer" -type d`。

### 步驟 2:看一下有哪些可選(可以先試這個確認環境 OK)

```bash
./download_models.sh --list
```

會印出全部旗標 + 每個檔案大小。

### 步驟 3 (新手推薦):用 **Recipe** 一鍵裝整套工作流相依

不熟悉哪個 tag 對哪個工作流?直接挑一個 recipe,它會把該工作流的所有相依(diffusion + LoRA + clip_vision + VAE + upscaler + 補幀模型 ... )一起裝好:

```bash
./download_models.sh --list-recipes            # 先看有哪些 recipe
./download_models.sh --recipe wan22-i2v-with-upscale  # 一鍵裝 I2V + 4x 升頻 + RIFE 補幀
```

**24 個內建 recipe**(全部 URL 已 HTTP HEAD 驗證 200 + Content-Length>0):

#### Wan2.2 基礎(常用)
| Recipe | 內含 tags | 適用情境 |
|---|---|---|
| `wan22-5b-fast` | `5b 5b-fast-fastwan` | 5B + 4-step 加速 LoRA(**5B 唯一的 fast LoRA**) |
| `wan22-5b-upscale-interp` | 5b + fast + 2 upscalers + RIFE | 5B + HD 升頻 + 補幀完整流水線 |
| `wan22-i2v-with-upscale` | 14B I2V + fast + ultrasharp + realesrgan + RIFE | I2V 完整 pipeline (生成+升頻+補幀) |
| `wan22-i2v-face-restore` | 14B I2V + fast + face-* + ultrasharp + RIFE | I2V + 臉部修復後處理 |
| `wan22-t2v-fast-interp` | 14B T2V + fast + RIFE + FILM | T2V + 雙補幀模型 |
| `wan22-animate-native` | 14B Animate bf16 + lightx2v + clip_vision + wan21-vae | 官方 ComfyUI Animate workflow |
| `wan22-animate-kijai-lowvram` | Kijai fp8 Animate + lightx2v + clip_vision + wan21-vae | Kijai fp8 Animate (16–24GB VRAM) |

#### Wan2.2 特殊變體
| Recipe | 用途 |
|---|---|
| `wan22-s2v-talking-head` | Wan2.2 S2V 音訊驅動口型同步影片 |
| `wan22-chrono-edit` | NVIDIA ChronoEdit 14B 影像/影片編輯 |
| `wan22-fun-control` | Fun-Control 14B(pose / depth / edge condition) |
| `wan22-fun-inpaint-fflf` | Fun-Inpaint 首末幀 / 局部修補 |
| `wan22-fun-camera` | Fun-Camera 鏡頭軌跡控制 |
| `wan22-fun-vace` | Fun-VACE 主體驅動影片編輯 |

#### Lightning / 加速替代版
| Recipe | 用途 |
|---|---|
| `wan22-t2v-lightning-alt` | T2V + Seko V1.1 (lightx2v 替代) |
| `wan22-t2v-fast-seko-v2` | T2V + **Seko V2.0**(2026 最新) + RIFE |
| `wan22-i2v-lightx2v-1022` | I2V + 2025-10-22 版 lightx2v LoRA |
| `wan22-i2v-lightx2v-260412` | I2V + **2026-04-12 版 720p lightx2v** + 升頻 + 補幀 |
| `wan22-blackwell-nvfp4` | **RTX 50 / Blackwell 專用**:NVFP4 sparse t2v+i2v(~16GB 主模型,只在 sm_100+ 可用) |

#### 進階 / Kijai WanVideoWrapper 系列
| Recipe | 用途 |
|---|---|
| `wan22-ovi-i2v-audio` | **Wan2.2 5B Ovi**(同時生影片+音訊,Kijai 版) |
| `wan22-fun-control-pose-depth-kijai` | Kijai Fun-Control fp8 + DepthAnythingV2 |
| `wan21-infinitetalk-i2v` | Wan2.1 InfiniteTalk(多人對嘴影片)+ 中文 wav2vec2 |

#### 工具包(只裝一類)
| Recipe | 用途 |
|---|---|
| `wan22-upscale-pack` | 9 個 upscaler(RealESRGAN/UltraSharp/Remacri/NMKD/SwinIR) |
| `wan22-interp-pack` | 7 個 RIFE/FILM 補幀模型 |
| `wan22-faces-postprocess` | GFPGAN + CodeFormer + face detect + ultrasharp |

### 步驟 3 (進階):直接選 tag

```bash
# Wan2.2 主模型
./download_models.sh --14b-t2v              # 14B 文生影片 fp8 (~28GB)
./download_models.sh --14b-i2v              # 14B 圖生影片 fp8 (~28GB)
./download_models.sh --14b-fast             # 14B 4-step 閃電 LoRA (~5GB)
./download_models.sh --14b-animate          # 14B 角色動畫 bf16 (~35GB)
./download_models.sh --14b-animate-kijai    # Kijai fp8 Animate (~18GB)
./download_models.sh --14b-s2v              # 14B 聲音→影片 (~16GB)
./download_models.sh --14b-fun-{control,inpaint,camera,vace}
./download_models.sh --chrono-edit          # ChronoEdit 影片編輯 (~32GB)

# 進階 Lightning / Distill LoRAs(2025-Q4 新版)
./download_models.sh --5b-fast-fastwan      # 5B 唯一的 4-step LoRA
./download_models.sh --14b-fast-lightx2v-t2v-v1217   # 2025-12-17 版
./download_models.sh --14b-fast-lightx2v-i2v-v1022   # 2025-10-22 版
./download_models.sh --14b-fast-seko-v11             # Seko V1.1
./download_models.sh --14b-fast-kijai                # Kijai 重打包

# 升頻 (4x/2x,放到 ComfyUI/models/upscale_models/)
./download_models.sh --upscale-ultrasharp / -ultrasharp-v2 / -remacri
./download_models.sh --upscale-realesrgan-x4 / -x2 / -anime
./download_models.sh --upscale-nmkd-siax / -nmkd-superscale / -swinir-x4

# 影格插補 (RIFE + FILM,放到 ComfyUI/models/interpolation/)
./download_models.sh --interp-rife-426 / -426-heavy / -425 / -49 / -film

# 臉部修復 (放到 facerestore_models/ 與 facedetection/)
./download_models.sh --face-gfpgan / --face-codeformer / --face-restoreformer
./download_models.sh --face-detect --face-parsing  # 偵測 + parsing 模型 (前兩者必備)

# 工具
./download_models.sh --list                 # 列出所有可用 tag + 檔案大小
./download_models.sh --list-recipes         # 列出所有 recipe + 內含 tags
./download_models.sh --menu                 # 交互式選單 (新手友善)
./download_models.sh --all                  # 5B + 14B t2v + 14B i2v + 4-step (常用組合)
./download_models.sh --everything           # 所有 Wan2.2 主模型 (>150GB,慎用)
./download_models.sh --no-5b                # 不裝 5B (只裝 14B 時用)
```

### 步驟 4:裝完直接用,不用重啟

下載期間 ComfyUI 不用關;**裝完後在瀏覽器介面右上 Refresh 一下,新模型就出現在 Load 節點的下拉選單裡**。
或者在終端機按 `Ctrl+C` 停掉 ComfyUI,再 `./start.sh` 重啟也行。

> 完整 75 個官方 Comfy-Org repo 檔案看 [模型清單.md](模型清單.md)(全部 HTTP 驗證過;另有 21 個 Kijai/lightx2v/RIFE/upscaler/GFPGAN 等社群相依模型,用 ./download_models.sh --list 看完整列表);
> 32 個新增的工作流相依模型(含 Kijai / lightx2v / RealESRGAN / RIFE / GFPGAN 等)的完整網址與大小,
> 用 `./download_models.sh --list` 查。

---

## 進階選項

| 想做什麼 | 怎麼做 |
|---|---|
| 換 CUDA 版本(舊驅動) | `TORCH_CUDA=cu124 ./install.sh`(預設 `cu128`) |
| 改 ComfyUI 安裝位置 | `COMFY_DIR=/data/ComfyUI ./install.sh` |
| 安裝缺失節點 / 第三方擴充 | 裝 [ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) 到 `ComfyUI/custom_nodes/` |
| 加速生成 | `pip install sageattention` → `./start.sh --use-sage-attention` |
| 影片放大 / 補幀 | 透過 ComfyUI-Manager 裝 upscale / RIFE 類節點 |

---

## 可重複執行(idempotent)說明

所有腳本都設計成**可放心重跑**:

- `install.sh` 用 `dpkg -s` + `apt-get install -s` 雙重檢查(處理 Ubuntu 24.04+ 的 `*t64` 改名);ComfyUI 有就 `git pull`,venv 健康才重用,PyTorch 用 `torch.version.cuda` 比對「實際的 CUDA 版本」是否與你要的相符。
- `download_models.sh` 對每個檔案比對「存在 + 大小 ≥ 門檻」,完整則略過;否則 `hf` > `aria2c` > `wget` **續傳**而非重抓。
- `setup.sh` 只是依序呼叫上面兩支,本身無狀態。

中斷或想更新?直接重跑 `./setup.sh` 即可。

---

## 已驗證項目

| 驗證內容 | 方法 | 結果 |
|---|---|---|
| HuggingFace 模型 URL | HTTP HEAD(200 + Content-Length>0) | **75 / 75 通過** |
| Ubuntu 22.04 安裝 | docker amd64 容器端到端 RUN#1 + RUN#2 | 通過 |
| Ubuntu 24.04 安裝 | docker amd64 容器端到端 | 通過(t64 自動處理) |
| Ubuntu 26.04 安裝 | docker amd64 容器三輪測試(冪等 + torch skip) | 通過 |
| PyTorch cu128 輪子矩陣 | curl 索引頁 | cp310–cp314 × {x86_64, aarch64, Windows} 全部存在 |
| 腳本 bash 語法 | `bash 5 -n` + `shellcheck` (severity=warning) | 全部 OK |

---

## 常見問題

| 症狀 | 解法 |
|---|---|
| `nvidia-smi` 找不到 | `sudo ubuntu-drivers autoinstall && sudo reboot`,再重跑 `./setup.sh` |
| `CUDA OOM` 顯存不足 | 降解析度 → 縮短 frames → `./start.sh --lowvram` |
| 模型下載中斷 | 直接重跑 `./download_models.sh`,會自動續傳 |
| ComfyUI 介面找不到 Wan2.2 範本 | 重跑 `./install.sh`(會 `git pull` 更新 ComfyUI) |
| 輸出全黑 / 雜訊 | 檢查 VAE 是否載對 `wan2.2_vae.safetensors`、CFG/Shift 不要太極端 |
| port 8188 被占用 | `PORT=9000 ./start.sh` |
| venv 半毀(`python: not found`) | 已自動處理,但若要手動:`rm -rf ComfyUI/.venv && ./install.sh` |

更多疑難排解見 [安裝手冊.md 第 10 節](安裝手冊.md#10-疑難排解)。

---

## 更多文件

- **[安裝手冊.md](安裝手冊.md)** —— 詳細逐步教學、NVIDIA 驅動安裝、疑難排解、冪等原理
- **[模型清單.md](模型清單.md)** —— 75 個官方 Wan2.2 / 2.1 模型的完整目錄(全部 HTTP 驗證)
- **[風格與參數預設.md](風格與參數預設.md)** —— 提示詞公式、風格關鍵字、三組參數配方

---

## 來源與致謝

- **ComfyUI**:[comfyanonymous/ComfyUI](https://github.com/comfyanonymous/ComfyUI) — 節點式 UI
- **Wan2.2**:[Wan-Video/Wan2.2](https://github.com/Wan-Video/Wan2.2) — 模型作者
- **HuggingFace repo**:
  - [Comfy-Org/Wan_2.2_ComfyUI_Repackaged](https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged)
  - [Comfy-Org/Wan_2.1_ComfyUI_repackaged](https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged)
- **官方教學**:[ComfyUI Docs: Wan2.2](https://docs.comfy.org/tutorials/video/wan/wan2_2)
- **社群參考**:
  - [ComfyUI Wiki: Wan2.2 Workflow Guide](https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2)
  - [Next Diffusion: Wan2.2 GGUF 低顯存](https://www.nextdiffusion.ai/tutorials/how-to-run-wan22-image-to-video-gguf-models-in-comfyui-low-vram)

---

## 授權

腳本與文件採 [MIT License](https://opensource.org/licenses/MIT)。
模型本身的授權請依各 HuggingFace 模型頁面為準(主要是 Apache-2.0)。
