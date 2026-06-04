# Wan2.2-TI2V-5B × ComfyUI 完整入門指南

> 給**完全新手**的詳細手冊:在 Ubuntu (Intel CPU + NVIDIA RTX,VRAM ≤ 12GB) 上,
> 用 [ComfyUI](https://github.com/comfyanonymous/ComfyUI) 跑
> [Wan2.2-TI2V-5B](https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B) 產生 AI 影片。
> 所有腳本**可重複執行**(已裝/已下載的自動略過),所有網址都**實際驗證過存在**。

---

## 0. 先搞懂幾個名詞 (新手必讀)

| 名詞 | 白話解釋 |
|---|---|
| **ComfyUI** | 一個用「節點連線」方式操作 AI 繪圖/影片的工具。你在網頁上把方塊接起來就能生成。 |
| **模型 / Diffusion Model** | AI 的「大腦」,真正畫出畫面的核心權重檔。我們用的是 `wan2.2_ti2v_5B_fp16.safetensors`。 |
| **文字編碼器 / Text Encoder** | 把你打的文字 (prompt) 翻譯成模型看得懂的數字。我們用 `umt5_xxl_fp8_...`。 |
| **VAE** | 負責「壓縮/還原畫面」的轉換器。沒有它畫面出不來。我們用 `wan2.2_vae.safetensors`。 |
| **LoRA** | 一種「外掛微調」,可加風格或加速。**TI2V-5B 預設不需要**。 |
| **工作流 / Workflow** | 一張「節點接線圖」,決定生成流程。ComfyUI 內建官方範本可直接載入。 |
| **VRAM (顯存)** | 顯卡的記憶體。影片模型很吃 VRAM,你的 ≤12GB 對 5B 來說夠用。 |
| **OOM** | Out Of Memory,顯存不夠用的錯誤。解法:降解析度、縮短影片長度。 |
| **safetensors** | 模型檔的安全格式,副檔名 `.safetensors`,直接放進對應資料夾即可。 |

> 看到不懂的節點或名詞,可直接查 **[ComfyUI 官方文件](https://docs.comfy.org/)** 或本檔最後的[社群資源](#10-找不到答案官方文件--社群資源)。

---

## 1. 這個模型是什麼 (Wan2.2-TI2V-5B)

- **TI2V = Text & Image to Video**:同一個模型,可以「文字→影片」也可以「圖片→影片」。
- **5B** = 50 億參數,是 Wan2.2 系列裡**最輕量**的版本,專為消費級顯卡設計。
- 用**高壓縮 Wan2.2-VAE**,所以小顯卡也能輸出 **720p @ 24fps、約 5 秒 (121 格)**。
- 官方針對 720p 調校,**不支援 480p** (低解析度只建議拿來「測試跑不跑得動」)。
- 它是**單一模型**,不像 14B 版那種「高噪 + 低噪」雙專家結構 —— 這點很重要,影響你能不能用某些 LoRA (見[第 9 節](#9-lora-放哪--用途-進階))。

---

## 2. 你需要準備什麼

| 項目 | 需求 |
|---|---|
| 作業系統 | Ubuntu 24.04 / 26.04 (64-bit) |
| 顯卡 | NVIDIA RTX,建議 ≥ 8GB;你的 ≤12GB **夠用** |
| 驅動 | NVIDIA 驅動 (建議 ≥ 550)。用 `nvidia-smi` 確認;沒裝看 [安裝手冊.md](安裝手冊.md) 第 2 節 |
| 硬碟空間 | 模型 ~17GB + ComfyUI/套件 ~8GB,**預留 30GB** |
| 網路 | 下載模型約 17GB |

### 架構與版本相容性 (已在 Ubuntu 26.04 實測)

- **CPU 架構**:本安裝包針對 **x86_64 (Intel/AMD)**。PyTorch 的 CUDA 輪子 (cu128) 只有 x86_64 版,
  ARM Linux 沒有 —— 所以這套**要跑在 x86_64 機器**上(你的 Intel 主機 ✓)。
- **apt 套件名稱**與 CPU 架構無關 (Ubuntu multiarch),x86 與 ARM 用同樣的套件名。
- **Python**:Ubuntu 26.04 預設是 **Python 3.14**,而 PyTorch cu128 已有 3.14 (cp314) 的 x86_64 輪子,
  所以**直接能用**,腳本不需要你另外裝舊版 Python。
- **顯卡**:`cu128` 支援 RTX 30/40/50 全系列;若卡較舊可在安裝時用 `TORCH_CUDA=cu124 ./install.sh`。

---

## 3. 快速開始

### 最簡單:一鍵全自動 (推薦新手)

```bash
cd ~/WAN2.2          # 進到放腳本的資料夾
chmod +x *.sh        # 給腳本執行權限 (只需做一次)
./setup.sh           # 自動完成:安裝環境 → 下載模型 → 顯示啟動方式
./start.sh           # 啟動,然後瀏覽器開 http://127.0.0.1:8188
```

`setup.sh` 會依序跑 `install.sh` 與 `download_models.sh`,全程**可重複執行**(已裝/已下載的自動略過)。
中途斷掉?直接再跑一次 `./setup.sh` 即可續做。

### 想分步驟跑

```bash
./install.sh          # 1. 安裝 ComfyUI + PyTorch(CUDA) + 相依套件
./download_models.sh  # 2. 下載 3 個模型檔 (約 17GB,可續傳)
./start.sh            # 3. 啟動 ComfyUI
```

> 其他用法:`./setup.sh --no-models`(只裝環境)、`./setup.sh --start`(裝完直接啟動)、`./install.sh --with-models`(裝完順便下載)。

---

## 3.1 啟動與使用 ComfyUI (新手必讀)

裝完之後(或之後每一次要用),只要這兩個動作:

```bash
cd ~/WAN2.2
./start.sh                  # 啟動伺服器
```

終端機會出現類似:
```
==> 啟動 ComfyUI:http://127.0.0.1:8188
    (Ctrl+C 結束)
```

**接著**:
1. **開瀏覽器** → 進 `http://127.0.0.1:8188` → 看到 ComfyUI 介面。
2. 左上 **Workflow → Browse Templates → Video** → 選 **「Wan2.2 5B」**(或對應你裝的模型)。
3. 點 **Queue** / **Run** 按鈕 → 等進度條跑完。
4. 影片會在 `ComfyUI/output/` 出現,瀏覽器介面也會預覽。

要結束:回終端機按 **Ctrl+C**。

| 啟動小技巧 | 指令 |
|---|---|
| 一般啟動 | `./start.sh` |
| 顯存吃緊(自動把權重 offload 到 RAM/磁碟) | `./start.sh --lowvram` |
| 開放區網其他電腦/手機連入 | `./start.sh --listen` → 用本機 IP + `:8188` 連 |
| 換 port (例如 9000) | `PORT=9000 ./start.sh` |
| 啟用 Sage Attention 加速 | `./start.sh --use-sage-attention` (要先 `pip install sageattention`) |

---

## 3.2 這個安裝包有哪些檔案 (每個檔案在幹嘛)

| 檔案 | 作用 | 你需要做什麼 |
|---|---|---|
| **setup.sh** | 總入口,一鍵跑完安裝+下載 | **新手執行這個就好** |
| **install.sh** | 安裝 ComfyUI、PyTorch(CUDA)、系統相依套件;可重複執行 | 由 setup.sh 呼叫,或單獨跑 |
| **download_models.sh** | 下載模型(支援 5B / 14B 多種變體與 LoRA;hf/aria2/wget 自動擇優,可續傳) | 由 setup.sh 呼叫,或單獨跑 |
| **start.sh** | 啟動 ComfyUI 伺服器 (支援 `--lowvram` / `--listen`) | **每次要用時執行** |
| **README.md** | 本檔:總覽、資料夾結構、模型/LoRA 說明 | 先看這個 |
| **安裝手冊.md** | 最詳細的逐步教學 + 疑難排解 + 驅動安裝 | 卡關時看 |
| **模型清單.md** | 75 個官方 Wan2.2/2.1 模型/LoRA/VAE 完整目錄(全 URL 驗證過) | 想裝更多模型時查 |
| **風格與參數預設.md** | 照抄就能用的提示詞與參數配方 | 生成時參考 |

> 執行後會多出一個 `ComfyUI/` 資料夾(主程式與模型都在裡面),結構見下一節。

---

## 4. 完整資料夾架構 (每個資料夾放什麼)

ComfyUI 靠 `models/` 底下的**子資料夾名稱**分類模型,**放錯資料夾在介面上就找不到**。
★ = 跑 TI2V-5B 必備:

```
ComfyUI/
├── main.py                     # ComfyUI 主程式 (start.sh 會啟動它)
├── .venv/                      # Python 虛擬環境 (install.sh 建立)
├── input/                      # 放「圖生影片」要用的輸入圖片
├── output/                     # ★ 生成的影片/圖片會存在這裡
├── custom_nodes/               # 第三方擴充節點 (例如 ComfyUI-Manager)
├── user/                       # 你的工作流 (.json)、介面設定
└── models/
    ├── diffusion_models/       # ★ 主模型。介面 "Load Diffusion Model" 讀這裡
    │   └── wan2.2_ti2v_5B_fp16.safetensors
    ├── text_encoders/          # ★ 文字編碼器。介面 "Load CLIP" 讀這裡
    │   └── umt5_xxl_fp8_e4m3fn_scaled.safetensors
    ├── vae/                    # ★ VAE。介面 "Load VAE" 讀這裡
    │   └── wan2.2_vae.safetensors
    ├── loras/                  # LoRA (選用,5B 預設空的)。"LoraLoader" 讀這裡
    ├── clip_vision/            # 影像編碼器 (某些 I2V 用;TI2V-5B 不需要)
    └── audio_encoders/         # 音訊編碼器 (只有 S2V 語音生影片才用)
```

`download_models.sh` 會自動把 3 個必備檔放到正確位置,其餘資料夾預設留空。

---

## 5. 用哪個模型 + 哪個 VAE?(一句話版)

**只要這三個檔,不多不少:**

| 角色 | 檔名 | 放這個資料夾 |
|---|---|---|
| 主模型 | `wan2.2_ti2v_5B_fp16.safetensors` | `models/diffusion_models/` |
| 文字編碼器 | `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | `models/text_encoders/` |
| **VAE** | `wan2.2_vae.safetensors` | `models/vae/` |

> VAE 一定要用 **`wan2.2_vae.safetensors`** (Wan2.2 專用高壓縮 VAE)。
> **不要**用 Wan2.1 的舊 VAE 或 SD/SDXL 的 VAE —— 會輸出黑畫面或雜訊。

---

## 6. 每個檔案的用途 + 實際下載網址 (皆驗證回應 200)

| 檔案 | 大小 | 用途 |
|---|---|---|
| `wan2.2_ti2v_5B_fp16.safetensors` | ~10GB | **主模型**:真正生成每一格畫面。官方只提供 fp16,無 fp8。 |
| `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | ~6.7GB | **文字編碼器**:把 prompt 轉成向量。fp8 量化省記憶體,與 Wan2.1 共用。 |
| `wan2.2_vae.safetensors` | ~0.5GB | **VAE**:潛空間↔像素轉換。高壓縮,讓小顯卡能出 720p。 |

```
# 主模型 → models/diffusion_models/
https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors

# 文字編碼器 → models/text_encoders/
https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

# VAE → models/vae/
https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
```

來源 repo:[Comfy-Org/Wan_2.2_ComfyUI_Repackaged](https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged)(官方為 ComfyUI 重新打包的版本)

---

## 7. 最小驗證架構 (先確認「跑得起來」)

新手第一步**不要追求畫質**,先用最小組合確認整條流程通了。最小組合只需要:

```
✅ ComfyUI 已安裝        (./install.sh)
✅ 上面那 3 個模型檔     (./download_models.sh)
✅ 官方 "Wan2.2 5B" 範本工作流
✅ 一次小設定的測試生成
```

**這四項就能驗證成功,以下東西「現在都不需要」**:
ComfyUI-Manager、LoRA、Sage Attention、clip_vision、audio_encoders、放大/補幀外掛。

### 怎麼算「驗證成功」?
1. 瀏覽器打開 `http://127.0.0.1:8188` 看得到 ComfyUI 介面。
2. 載入官方 5B 範本,按 **Queue / Run** 後**沒有紅色錯誤框**。
3. 跑完後 `ComfyUI/output/` 出現一個 `.mp4` 或 `.webp` 影片檔。

做到這 3 點 = 環境完全 OK,之後就能放心調畫質、加東西。

### 第一次測試建議用「省記憶體」設定 (見[第 8 節](#8-在-comfyui-產生第一支影片) 表格右欄)
解析度 832×480、長度 49 格、Steps 20 —— 先求快、求成功,再放大。

---

## 8. 在 ComfyUI 產生第一支影片

1. 啟動後,左上選單 → **Workflow → Browse Templates → Video**。
2. 點 **「Wan2.2 5B video generation」**(或寫 5B TI2V 的那個)載入。
3. 確認 3 個載入節點對到正確檔案:
   - **Load Diffusion Model** → `wan2.2_ti2v_5B_fp16.safetensors`
   - **Load CLIP** (type 選 `wan`) → `umt5_xxl_fp8_e4m3fn_scaled.safetensors`
   - **Load VAE** → `wan2.2_vae.safetensors`
4. **文字生影片**:在正向提示詞框輸入描述 (英文通常效果較好,可加鏡頭運動關鍵字)。
   **圖片生影片**:把起始圖放到 `ComfyUI/input/`,在 Load Image 節點選它,接到對應輸入。
5. 按 **Queue / Run**,等進度條跑完。影片在 `ComfyUI/output/`。

> 第一次跑較慢 (要把模型載進記憶體);同一次開著的 session,之後會快很多。

### 建議生成參數

| 參數 | 正式輸出 (720p) | 第一次測試 (求成功) |
|---|---|---|
| 解析度 | 1280×704 (橫) / 704×1280 (直) | 832×480 或 640×640 |
| 長度 (frames) | 121 (=5 秒) | 49–81 |
| FPS | 24 | 24 |
| Steps | 30 | 20 |
| CFG | 5.0 | 5.0 |
| Sampler / Scheduler | uni_pc / simple | euler / simple |
| Shift (ModelSamplingSD3) | 8.0 | 5–8 |

調參鐵則:**一次只改一個數值**,看效果再改下一個。
**OOM 時**:先降解析度 → 再縮短長度 → 最後 `./start.sh --lowvram`。

---

## 9. 跑起來之後「可以加什麼」(選用加值)

### 9.0 加裝更大/更多模型 (download_models.sh 旗標)

`download_models.sh` 預設只裝 5B (~17GB);要加裝其他變體,加旗標即可。
旗標可疊用,且**已下載/已完整的檔案會自動略過,不會重抓**。

```bash
./download_models.sh --14b-t2v             # +14B 文生影片 fp8 雙專家 (~28GB)
./download_models.sh --14b-i2v             # +14B 圖生影片 fp8 雙專家 (~28GB)
./download_models.sh --14b-fast            # +14B 4-step 閃電 LoRA (~5GB,大幅加速 14B)
./download_models.sh --14b-animate         # +14B 角色動畫 (~35GB)
./download_models.sh --14b-s2v             # +14B 聲音→影片 + 音訊編碼器 (~16GB)
./download_models.sh --14b-fun-control     # +14B Fun ControlNet 風格控制 (~28GB)
./download_models.sh --14b-fun-inpaint     # +14B Fun 局部重繪 (~28GB)
./download_models.sh --14b-fun-camera      # +14B Fun 攝影機運鏡 (~30GB)
./download_models.sh --14b-fun-vace        # +14B Fun VACE 影片編輯 (~33GB)
./download_models.sh --chrono-edit         # +ChronoEdit 影片編輯 (~32GB)
./download_models.sh --textenc-fp16        # 文字編碼器升級為 fp16 (+5GB,品質微升)
./download_models.sh --clip-vision         # +clip_vision_h (Wan2.1 I2V 部分工作流需要)
./download_models.sh --wan21-vae           # +Wan2.1 VAE (相容性備援)
./download_models.sh --rgba-lora           # +Wan2.1 RGBA 透明影片 LoRA
./download_models.sh --all                 # 5B + 14B t2v + 14B i2v + 14B fast (綜合包)
./download_models.sh --everything          # 全部變體 (>150GB,慎用)
./download_models.sh --list                # 列出所有可用旗標與檔案大小
```

> **12GB VRAM 建議**:預設 5B + 想加速 14B 時加 `--14b-t2v` 或 `--14b-i2v` + `--14b-fast`。
> 14B 必須用 fp8 量化版才放得進 12GB;fp16 版要 24GB 以上的卡才合理。
>
> 完整 75 個檔案的目錄、用途、URL 看 **[模型清單.md](模型清單.md)**(全部驗證過存在且可下載)。

### 9.1 其他加值(由易到難)

| 加值項目 | 做什麼 | 怎麼加 |
|---|---|---|
| **ComfyUI-Manager** | 一鍵安裝缺失節點/擴充,新手強烈建議 | 把 [Comfy-Org/ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) clone 到 `ComfyUI/custom_nodes/`,重啟 |
| **Sage Attention** | 明顯加速生成 | `source ComfyUI/.venv/bin/activate && pip install sageattention`,再 `./start.sh --use-sage-attention` |
| **更高解析度 / 更長影片** | 衝畫質 (吃更多 VRAM) | 在工作流調大解析度/frames,搭配 `--lowvram` |
| **GGUF 量化版** | 給 6–8GB 更小顯卡用 (你 12GB 用不到) | 參考社群教學 [Next Diffusion: Wan2.2 GGUF 低顯存](https://www.nextdiffusion.ai/tutorials/how-to-run-wan22-image-to-video-gguf-models-in-comfyui-low-vram) |
| **影片放大 / 補幀** | 提高解析度或補到 60fps | 透過 ComfyUI-Manager 裝 upscale / RIFE 類節點 |
| **5B 專屬加速工作流** | distill/lightning 少步數加速 | 找**標明 5B** 的工作流 (見下方 LoRA 警告) |

---

## 9.1 LoRA 放哪 + 用途 (進階)

- **放置位置**:`ComfyUI/models/loras/`,工作流中用 **LoraLoader** 節點載入。
- **TI2V-5B 預設不需要 LoRA** 就能生影片;它只是選用的風格/加速外掛。

### ⚠️ 官方現有的 Wan2.2 LoRA 全部是 14B 用的,不是 5B!

我查了官方 [Comfy-Org/Wan_2.2_ComfyUI_Repackaged](https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged) 的 `loras/` 資料夾,
裡面**沒有 5B 專屬 LoRA**。以下都是 **14B 雙專家 (high/low noise)** 用的,**套到 5B 不會正確運作**:

| LoRA 檔名 | 適用 | 用途 |
|---|---|---|
| `wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors` | 14B T2V | 4 步加速,high-noise |
| `wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors` | 14B T2V | 4 步加速,low-noise |
| `wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors` | 14B I2V | 4 步加速,high-noise |
| `wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors` | 14B I2V | 4 步加速,low-noise |
| `wan2.2_animate_14B_relight_lora_bf16.safetensors` | 14B Animate | 角色動畫重打光 |
| `chronoedit_distill_lora.safetensors` | 14B ChronoEdit | 影片編輯蒸餾加速 |

> **結論**:你跑 5B 時 `loras/` 保持空的即可。要加速請找**檔名/說明標明「5B」或「TI2V-5B」**的權重,
> **不要**直接拿上面這些 14B LoRA。下載任何 LoRA 前,先確認它對應的是 5B 還是 14B。

---

## 10. 找不到答案?官方文件 & 社群資源

**遇到不懂的節點、參數、錯誤,先查這些 (全部驗證過存在):**

### 官方
- [ComfyUI 官方 Wan2.2 教學](https://docs.comfy.org/tutorials/video/wan/wan2_2) — 最權威,含 5B 設定
- [ComfyUI 官方文件首頁](https://docs.comfy.org/) — 查任何節點/功能
- [ComfyUI 5B TI2V 範本工作流](https://www.comfy.org/workflows/video_wan2_2_5B_ti2v-f83ee3caa04e/)
- [ComfyUI_examples：Wan2.2](https://comfyanonymous.github.io/ComfyUI_examples/wan22/) — 作者親自寫的範例
- [ComfyUI 原始碼 (GitHub)](https://github.com/comfyanonymous/ComfyUI)
- [Wan2.2 官方 repo (GitHub)](https://github.com/Wan-Video/Wan2.2) — 模型作者
- [Wan-AI/Wan2.2-TI2V-5B (Hugging Face)](https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B) — 原始模型卡

### 社群 (別人怎麼做)
- [ComfyUI Wiki：Wan2.2 完整工作流指南](https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2) — 官方+社群 (Kijai/GGUF) 比較
- [Next Diffusion：Wan2.2 GGUF 低顯存教學](https://www.nextdiffusion.ai/tutorials/how-to-run-wan22-image-to-video-gguf-models-in-comfyui-low-vram)
- [ComfyUI-Manager (擴充管理器)](https://github.com/Comfy-Org/ComfyUI-Manager)

### 工具
- 想自己加擴充/補缺失節點 → 先裝 **ComfyUI-Manager**,介面上搜尋安裝最省事。

---

## 11. 延伸文件

- **[安裝手冊.md](安裝手冊.md)** — 驅動安裝、Python 版本、疑難排解、加速設定的完整逐步版。
- **[風格與參數預設.md](風格與參數預設.md)** — 照抄就能用的提示詞公式、風格關鍵字、三組參數配方 (測試/平衡/高畫質)。
