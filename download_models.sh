#!/usr/bin/env bash
# =============================================================================
# Wan2.2 / Wan2.1 模型下載 (ComfyUI 用,清單驅動)
# -----------------------------------------------------------------------------
# 預設只下載「跑 TI2V-5B 必要的 3 個檔案」(約 17GB):
#   ./download_models.sh
#
# 可疊加旗標(各種 5B / 14B / 特殊變體;每旗標都會把對應檔案加入下載列表):
#   --14b-t2v          14B 文生影片 fp8 (高+低噪雙專家,~28GB)
#   --14b-i2v          14B 圖生影片 fp8 (~28GB)
#   --14b-fast         14B Lightning 4-step 加速 LoRA (t2v+i2v,~5GB)
#   --14b-animate      14B 角色動畫 bf16 + relight LoRA (~35GB)
#   --14b-s2v          14B 聲音→影片 fp8 + wav2vec2 音訊編碼器 (~16GB)
#   --14b-fun-control  14B Fun ControlNet 風格 fp8 (~28GB)
#   --14b-fun-inpaint  14B Fun 局部重繪 fp8 (~28GB)
#   --14b-fun-camera   14B Fun 攝影機運鏡 fp8 (~30GB)
#   --14b-fun-vace     14B Fun VACE 影片編輯 fp8 (~33GB)
#   --chrono-edit      14B ChronoEdit 影片編輯 fp16 + distill LoRA (~32GB)
#   --textenc-fp16     文字編碼器升級為 fp16 (取代 fp8,品質↑;+5GB)
#   --clip-vision      clip_vision_h (某些 Wan2.1 I2V 工作流需要;~1.2GB)
#   --wan21-vae        Wan2.1 VAE (相容性備援;~250MB)
#   --rgba-lora        Wan2.1 RGBA 透明影片 LoRA (~300MB)
#   --no-5b            不下載 5B (只裝 14B 時用)
#   --all              5B + 14B t2v + 14B i2v + 14B fast (最常用的綜合包)
#   --everything       全部上面 (注意:可能 >150GB,非常大)
#   --list             印出可用旗標與每個檔案大小後離開
#   -h | --help        顯示這段說明後離開
#
# 全部可重複執行:已存在且大小達標的會略過;未完成的會續傳。
# 下載方式自動擇優:hf (官方 CLI,有完整性校驗) → aria2c → wget。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="${COMFY_DIR:-$SCRIPT_DIR/ComfyUI}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/.venv}"
MODELS_DIR="$COMFY_DIR/models"

R22="Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
R21="Comfy-Org/Wan_2.1_ComfyUI_repackaged"

# ---- 模型清單 (manifest) ----
# 格式:tags(逗號分隔) | repo | remote_path | dest_subdir | filename | min_bytes
# tags=shared 表示「永遠下載」(無論旗標,跑任何 Wan2.2 都要)。
# 所有 URL 已在 2026-05-29 用 HTTP HEAD 強驗證回 200 + Content-Length>0。
MANIFEST=(
  # ---- 共用 (永遠裝) ----
  "shared|$R21|split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|text_encoders|umt5_xxl_fp8_e4m3fn_scaled.safetensors|6669434880"
  "shared|$R22|split_files/vae/wan2.2_vae.safetensors|vae|wan2.2_vae.safetensors|1392508928"

  # ---- 5B TI2V (預設) ----
  "5b|$R22|split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|diffusion_models|wan2.2_ti2v_5B_fp16.safetensors|9930506240"

  # ---- 14B T2V (文生影片,fp8 雙專家) ----
  "14b-t2v|$R22|split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-t2v|$R22|split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|14227079168"

  # ---- 14B I2V (圖生影片,fp8 雙專家) ----
  "14b-i2v|$R22|split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-i2v|$R22|split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|14227079168"

  # ---- 14B Lightning 4-step 加速 LoRA (僅 14B 適用,5B 用不到) ----
  "14b-fast|$R22|split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|loras|wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|1209814656"
  "14b-fast|$R22|split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|loras|wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|1209814656"
  "14b-fast|$R22|split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|loras|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|1209814656"
  "14b-fast|$R22|split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|loras|wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|1209814656"

  # ---- 14B Animate (角色動畫) ----
  "14b-animate|$R22|split_files/diffusion_models/wan2.2_animate_14B_bf16.safetensors|diffusion_models|wan2.2_animate_14B_bf16.safetensors|34481176192"
  "14b-animate|$R22|split_files/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors|loras|wan2.2_animate_14B_relight_lora_bf16.safetensors|1419685888"

  # ---- 14B S2V (聲音→影片) ----
  "14b-s2v|$R22|split_files/diffusion_models/wan2.2_s2v_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_s2v_14B_fp8_scaled.safetensors|16327049216"
  "14b-s2v|$R22|split_files/audio_encoders/wav2vec2_large_english_fp16.safetensors|audio_encoders|wav2vec2_large_english_fp16.safetensors|622854144"

  # ---- 14B Fun 變體 (fp8) ----
  "14b-fun-control|$R22|split_files/diffusion_models/wan2.2_fun_control_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_control_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-control|$R22|split_files/diffusion_models/wan2.2_fun_control_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_control_low_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-inpaint|$R22|split_files/diffusion_models/wan2.2_fun_inpaint_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_inpaint_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-inpaint|$R22|split_files/diffusion_models/wan2.2_fun_inpaint_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_inpaint_low_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-camera|$R22|split_files/diffusion_models/wan2.2_fun_camera_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_camera_high_noise_14B_fp8_scaled.safetensors|15237267456"
  "14b-fun-camera|$R22|split_files/diffusion_models/wan2.2_fun_camera_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_camera_low_noise_14B_fp8_scaled.safetensors|15237267456"
  "14b-fun-vace|$R22|split_files/diffusion_models/wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors|17280040960"
  "14b-fun-vace|$R22|split_files/diffusion_models/wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors|17280040960"

  # ---- ChronoEdit (影片編輯) ----
  "chrono-edit|$R22|split_files/diffusion_models/chrono_edit_14B_fp16.safetensors|diffusion_models|chrono_edit_14B_fp16.safetensors|32721567744"
  "chrono-edit|$R22|split_files/loras/chronoedit_distill_lora.safetensors|loras|chronoedit_distill_lora.safetensors|367001600"

  # ---- 文字編碼器 fp16 升級 ----
  "textenc-fp16|$R22|split_files/text_encoders/umt5_xxl_fp16.safetensors|text_encoders|umt5_xxl_fp16.safetensors|11332321280"

  # ---- clip_vision (Wan2.1 I2V 工作流) ----
  "clip-vision|$R21|split_files/clip_vision/clip_vision_h.safetensors|clip_vision|clip_vision_h.safetensors|1209814656"

  # ---- Wan2.1 VAE (相容性備援) ----
  "wan21-vae|$R22|split_files/vae/wan_2.1_vae.safetensors|vae|wan_2.1_vae.safetensors|245366784"

  # ---- Wan2.1 RGBA 透明影片 LoRA ----
  "rgba-lora|$R21|split_files/loras/wan_alpha_2.1_rgba_lora.safetensors|loras|wan_alpha_2.1_rgba_lora.safetensors|303038464"
)
ALL_TAGS=(5b 14b-t2v 14b-i2v 14b-fast 14b-animate 14b-s2v 14b-fun-control 14b-fun-inpaint 14b-fun-camera 14b-fun-vace chrono-edit textenc-fp16 clip-vision wan21-vae rgba-lora)

# ---- 解析旗標 ----
declare -A WANT; WANT[5b]=1  # 預設下載 5B
for a in "$@"; do
  case "$a" in
    --no-5b)         WANT[5b]=0 ;;
    --14b-t2v|--14b-i2v|--14b-fast|--14b-animate|--14b-s2v|--14b-fun-control|--14b-fun-inpaint|--14b-fun-camera|--14b-fun-vace|--chrono-edit|--textenc-fp16|--clip-vision|--wan21-vae|--rgba-lora)
                     WANT["${a#--}"]=1 ;;
    --all)           for t in 5b 14b-t2v 14b-i2v 14b-fast; do WANT[$t]=1; done ;;
    --everything)    for t in "${ALL_TAGS[@]}"; do WANT[$t]=1; done ;;
    --list)
        echo "可用旗標 (旗標名 → 大小):"
        for line in "${MANIFEST[@]}"; do
          IFS='|' read -r tags _ _ _ name minb <<<"$line"
          mb=$(( minb / 1024 / 1024 ))
          printf "  --%-18s %6d MB  %s\n" "$tags" "$mb" "$name"
        done; exit 0 ;;
    -h|--help)       grep -E '^#' "$0" | head -34; exit 0 ;;
    *) echo "未知選項:$a (用 --help 看可用旗標)"; exit 1 ;;
  esac
done

c_reset=$'\e[0m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_blu=$'\e[36m'
info() { echo "${c_blu}==>${c_reset} $*"; }
ok()   { echo "${c_grn}  ✓${c_reset} $*"; }
have() { command -v "$1" >/dev/null 2>&1; }
filesize() { stat -c%s "$1" 2>/dev/null || echo 0; }

[[ -d "$COMFY_DIR" ]] || { echo "找不到 ComfyUI ($COMFY_DIR),請先執行 ./install.sh"; exit 1; }

DL_METHOD="wget"
if [[ -f "$VENV_DIR/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  have hf || pip install -q -U "huggingface_hub" >/dev/null 2>&1 || true
fi
if have hf; then DL_METHOD="hf"; elif have aria2c; then DL_METHOD="aria2c"; else DL_METHOD="wget"; fi

selected="shared"
for t in "${!WANT[@]}"; do (( WANT[$t] )) && selected+=" $t"; done
info "下載目錄:$MODELS_DIR"
info "下載方式:$DL_METHOD"
info "啟用標籤:$selected"

fetch() {
  local repo="$1" remote="$2" dir="$3" name="$4" min="$5"
  local dest="$dir/$name"
  local url="https://huggingface.co/$repo/resolve/main/$remote"
  mkdir -p "$dir"
  if [[ -f "$dest" ]] && (( $(filesize "$dest") >= min )); then
    ok "已存在且完整,略過:$name ($(( $(filesize "$dest") / 1024 / 1024 )) MB)"
    return 0
  fi
  echo "${c_yel}  ⬇ 下載中 ($DL_METHOD):${c_reset} $name → $dir"
  case "$DL_METHOD" in
    hf)     local stage="$dir/.hf_stage"; hf download "$repo" "$remote" --local-dir "$stage"; mv -f "$stage/$remote" "$dest"; rm -rf "$stage" ;;
    aria2c) aria2c -x 16 -s 16 -c -k 1M --dir="$dir" --out="$name" "$url" ;;
    wget)   wget -c -O "$dest" "$url" ;;
  esac
  ok "完成:$name ($(( $(filesize "$dest") / 1024 / 1024 )) MB)"
}

# 逐筆檢查 manifest;tag=shared 或 tag 在 WANT 中(且 WANT[tag]=1)就抓
for line in "${MANIFEST[@]}"; do
  IFS='|' read -r tags repo remote subdir name minb <<<"$line"
  do_fetch=0
  for t in ${tags//,/ }; do
    [[ "$t" == "shared" ]] && do_fetch=1
    [[ -n "${WANT[$t]:-}" && "${WANT[$t]}" == "1" ]] && do_fetch=1
  done
  (( do_fetch )) && fetch "$repo" "$remote" "$MODELS_DIR/$subdir" "$name" "$minb"
done

echo
ok "全部模型就緒。目錄結構:"
for d in diffusion_models text_encoders vae loras clip_vision audio_encoders model_patches; do
  if [[ -d "$MODELS_DIR/$d" ]] && [[ -n "$(ls -A "$MODELS_DIR/$d" 2>/dev/null)" ]]; then
    echo "   $MODELS_DIR/$d/"
    ls -lh "$MODELS_DIR/$d" 2>/dev/null | awk 'NR>1 && $9!~/^\./{printf "      %8s  %s\n", $5, $9}'
  fi
done
echo
echo "下一步:./start.sh  → 瀏覽器開 http://127.0.0.1:8188"
echo "       Workflow → Browse Templates → Video → 選對應的 Wan2.2 範本"
