# 貢獻指南 / Contributing

歡迎 issue、PR、新手回報問題。這份文件說明怎麼做最有效率。

---

## 回報問題 (Issue)

開 [issue](https://github.com/HsiaoSir/WAN2.2-ComfyUI-Installer/issues) 時請帶以下資訊,我才能快速判斷:

```
- OS:Ubuntu 24.04(`cat /etc/os-release | grep PRETTY` 的結果)
- 架構:x86_64 / aarch64(`uname -m`)
- GPU:RTX 4090 12GB(`nvidia-smi` 第一行)
- 步驟:跑到哪一步爆掉(setup.sh / install.sh 哪一個步驟?)
- 完整錯誤訊息:把終端機輸出貼上來(最重要)
- 是不是第一次跑?還是重跑時才壞?
```

---

## 提交 PR

### 改腳本前的本地檢查(必跑)

```bash
# bash 5 語法
bash -n install.sh download_models.sh setup.sh start.sh

# 靜態分析 (任何 warning+ 等級的問題都要修)
shellcheck --shell=bash --severity=warning install.sh download_models.sh setup.sh start.sh
```

兩個都過了再 push。CI(GitHub Actions)沒設,但這份規矩你自己跑一下就行。

### 改 download_models.sh 加新模型

加任何新檔案前,**必須先 HTTP HEAD 驗證 URL 存在且可下載**(不靠記憶或猜測):

```bash
curl -sIL "https://huggingface.co/<REPO>/resolve/main/<PATH>" \
  -o /dev/null -w "%{http_code} | %{size_download}\n"
# 必須:200 + Content-Length>0 才算通過
```

確認後再加進 `MANIFEST` 陣列,大小門檻設「實際大小 − 32~64MB」(避免「卡在門檻之上但檔案不完整」)。

### 設計原則(看過 README 就懂)

- **冪等 (idempotent)**:腳本可被重跑;已完成的步驟自動偵測並略過。
- **不亂猜 URL / 版本**:任何網址都要 curl 驗證;套件名稱用 `apt-cache policy` 或 `apt-get install -s` 確認。
- **跨 Ubuntu 通用**:22.04 / 24.04 / 26.04 都要能跑;處理 t64 改名與 Python 預設版本差異。
- **新手友善**:錯誤訊息要可讀、`info`/`warn`/`die` 用 `c_blu`/`c_yel`/`c_red` 區分。
- **不加 emoji 到腳本/文件**(README 的 badge 例外)。
- **不要把 `ComfyUI/` 或 `*.safetensors` 加進 git**(`.gitignore` 已排除)。

### Commit message 風格

```
動詞起頭: 簡短描述 (50 字內)

(若有需要) 較詳細的內容說明。
- 為什麼要改
- 改了什麼
- 驗證方式
```

範例:
```
Add --14b-vace-fp16 flag to download_models.sh

- Verified URL via HTTP HEAD (200 + 33069MB)
- min_bytes set to 33037MB (32MB safety margin)
- Manifest entry follows existing 14b-fun-vace pattern
```

---

## 加新功能的常見路徑

| 想做什麼 | 改哪 |
|---|---|
| 加新模型下載選項 | `download_models.sh` 的 `MANIFEST` 陣列 + 旗標解析 + README §下載更多模型 |
| 支援新 Ubuntu 版本 | `install.sh` 的步驟 0(VERSION_ID case)+ 在新 docker 容器測 e2e |
| 加新的啟動選項 | `start.sh`(直接傳給 ComfyUI 主程式即可) |
| 加新的風格 / 參數配方 | `風格與參數預設.md` |
| 新的疑難排解條目 | `安裝手冊.md` 第 10 節 + `README.md` 「常見問題」 |

---

## 行為準則 (Code of Conduct)

請保持基本尊重:對人不對事,提供具體可重現的步驟。
帶有人身攻擊、騷擾、歧視內容的 issue/PR 會直接關閉。

---

## 授權

提交 PR 視為同意以本專案的 [MIT License](LICENSE) 授權你的貢獻。
