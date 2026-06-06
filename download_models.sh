#!/usr/bin/env bash
# =============================================================================
# Wan2.2 / Wan2.1 + 常見工作流相依模型下載 (ComfyUI 用,清單驅動)
# -----------------------------------------------------------------------------
# 預設只下載「跑 TI2V-5B 必要的 3 個檔案」(約 17GB):
#   ./download_models.sh
#
# 兩種使用方式:
# (A) 預填參數 (推薦給熟手 / CI):
#   ./download_models.sh --14b-t2v --14b-fast              # 多旗標可疊
#   ./download_models.sh --recipe wan22-i2v-with-upscale   # 一鍵整套工作流
#   ./download_models.sh --list                            # 列出所有單 tag
#   ./download_models.sh --list-recipes                    # 列出所有 recipe
#
# (B) 交互式選單 (推薦給新手):
#   ./download_models.sh --menu
#
# 所有檔案:
#   * 全程 idempotent — 已存在且大小達標的會略過,不重抓
#   * 中斷可續傳 — aria2c 多執行緒或 curl --continue-at -
#   * URL 全部已 HTTP HEAD 驗證 200 + Content-Length>0
#   * 自動建子資料夾並放到對應位置
#
# 模型放置位置 (ComfyUI 自動載入):
#   diffusion_models/  text_encoders/  vae/  loras/
#   clip_vision/  audio_encoders/  upscale_models/  interpolation/
#   facerestore_models/  facedetection/
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="${COMFY_DIR:-$SCRIPT_DIR/ComfyUI}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/.venv}"
MODELS_DIR="$COMFY_DIR/models"

# =============================================================================
# Manifest:每個 tag 一個 entry
# 格式:tags(逗號分隔) | FULL_URL | dest_subdir | local_filename | min_bytes
# tags=shared 代表「永遠下載」(任何 Wan2.2 都要)。
# 所有 URL 已用 HTTP HEAD 驗證 200 + Content-Length>0 (2026-06-07)。
# =============================================================================
R22="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main"
R21="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main"

MANIFEST=(
  # ===== 共用 (永遠裝) =====
  "shared|$R21/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|text_encoders|umt5_xxl_fp8_e4m3fn_scaled.safetensors|6669434880"
  "shared|$R22/split_files/vae/wan2.2_vae.safetensors|vae|wan2.2_vae.safetensors|1392508928"

  # ===== 5B TI2V (預設) =====
  "5b|$R22/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|diffusion_models|wan2.2_ti2v_5B_fp16.safetensors|9930506240"

  # ===== 14B T2V fp8 雙專家 =====
  "14b-t2v|$R22/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-t2v|$R22/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|14227079168"

  # ===== 14B I2V fp8 雙專家 =====
  "14b-i2v|$R22/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-i2v|$R22/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|14227079168"

  # ===== 14B Lightning 4-step LoRA (Comfy-Org 官方版) =====
  "14b-fast|$R22/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|loras|wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|1209814656"
  "14b-fast|$R22/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|loras|wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|1209814656"
  "14b-fast|$R22/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|loras|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|1209814656"
  "14b-fast|$R22/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|loras|wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|1209814656"

  # ===== 14B Animate (官方 bf16) =====
  "14b-animate|$R22/split_files/diffusion_models/wan2.2_animate_14B_bf16.safetensors|diffusion_models|wan2.2_animate_14B_bf16.safetensors|34481176192"
  "14b-animate|$R22/split_files/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors|loras|wan2.2_animate_14B_relight_lora_bf16.safetensors|1419685888"

  # ===== 14B Animate (Kijai fp8 scaled, 給 16-24GB VRAM) =====
  "14b-animate-kijai|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_e4m3fn_scaled_KJ.safetensors|diffusion_models|Wan2_2-Animate-14B_fp8_e4m3fn_scaled_KJ.safetensors|18337202176"
  "14b-animate-lightx2v|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors|loras|lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors|721420288"

  # ===== 14B S2V =====
  "14b-s2v|$R22/split_files/diffusion_models/wan2.2_s2v_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_s2v_14B_fp8_scaled.safetensors|16327049216"
  "14b-s2v|$R22/split_files/audio_encoders/wav2vec2_large_english_fp16.safetensors|audio_encoders|wav2vec2_large_english_fp16.safetensors|622854144"

  # ===== 14B Fun 變體 (fp8) =====
  "14b-fun-control|$R22/split_files/diffusion_models/wan2.2_fun_control_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_control_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-control|$R22/split_files/diffusion_models/wan2.2_fun_control_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_control_low_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-inpaint|$R22/split_files/diffusion_models/wan2.2_fun_inpaint_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_inpaint_high_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-inpaint|$R22/split_files/diffusion_models/wan2.2_fun_inpaint_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_inpaint_low_noise_14B_fp8_scaled.safetensors|14227079168"
  "14b-fun-camera|$R22/split_files/diffusion_models/wan2.2_fun_camera_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_camera_high_noise_14B_fp8_scaled.safetensors|15237267456"
  "14b-fun-camera|$R22/split_files/diffusion_models/wan2.2_fun_camera_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_camera_low_noise_14B_fp8_scaled.safetensors|15237267456"
  "14b-fun-vace|$R22/split_files/diffusion_models/wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors|17280040960"
  "14b-fun-vace|$R22/split_files/diffusion_models/wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors|diffusion_models|wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors|17280040960"

  # ===== ChronoEdit =====
  "chrono-edit|$R22/split_files/diffusion_models/chrono_edit_14B_fp16.safetensors|diffusion_models|chrono_edit_14B_fp16.safetensors|32721567744"
  "chrono-edit|$R22/split_files/loras/chronoedit_distill_lora.safetensors|loras|chronoedit_distill_lora.safetensors|367001600"

  # ===== 升級型 text encoder / clip_vision / 額外 VAE / RGBA LoRA =====
  "textenc-fp16|$R22/split_files/text_encoders/umt5_xxl_fp16.safetensors|text_encoders|umt5_xxl_fp16.safetensors|11332321280"
  "clip-vision|$R21/split_files/clip_vision/clip_vision_h.safetensors|clip_vision|clip_vision_h.safetensors|1209814656"
  "wan21-vae|$R22/split_files/vae/wan_2.1_vae.safetensors|vae|wan_2.1_vae.safetensors|245366784"
  "rgba-lora|$R21/split_files/loras/wan_alpha_2.1_rgba_lora.safetensors|loras|wan_alpha_2.1_rgba_lora.safetensors|303038464"

  # ===== Upscalers (4x / 2x 升頻) =====
  "upscale-realesrgan-x4|https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|upscale_models|RealESRGAN_x4plus.pth|58720256"
  "upscale-realesrgan-x2|https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth|upscale_models|RealESRGAN_x2plus.pth|58720256"
  "upscale-realesrgan-anime|https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth|upscale_models|RealESRGAN_x4plus_anime_6B.pth|9437184"
  "upscale-ultrasharp|https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth|upscale_models|4x-UltraSharp.pth|58720256"
  "upscale-ultrasharp-v2|https://huggingface.co/Kim2091/UltraSharpV2/resolve/main/4x-UltraSharpV2.pth|upscale_models|4x-UltraSharpV2.pth|131596288"
  "upscale-remacri|https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_foolhardy_Remacri.pth|upscale_models|4x_foolhardy_Remacri.pth|58720256"
  "upscale-nmkd-siax|https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth|upscale_models|4x_NMKD-Siax_200k.pth|58720256"
  "upscale-nmkd-superscale|https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Superscale-SP_178000_G.pth|upscale_models|4x_NMKD-Superscale-SP_178000_G.pth|58720256"
  "upscale-swinir-x4|https://github.com/JingyunLiang/SwinIR/releases/download/v0.0/003_realSR_BSRGAN_DFOWMFC_s64w8_SwinIR-L_x4_GAN.pth|upscale_models|003_realSR_BSRGAN_DFOWMFC_s64w8_SwinIR-L_x4_GAN.pth|133693440"

  # ===== Frame interpolation (RIFE + FILM) =====
  "interp-rife-426|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.26.safetensors|interpolation|rife_v4.26.safetensors|14680064"
  "interp-rife-426-heavy|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.26_heavy.safetensors|interpolation|rife_v4.26_heavy.safetensors|14680064"
  "interp-rife-425|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.25.safetensors|interpolation|rife_v4.25.safetensors|14680064"
  "interp-rife-425-lite|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.25_lite.safetensors|interpolation|rife_v4.25_lite.safetensors|14680064"
  "interp-rife-425-heavy|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.25_heavy.safetensors|interpolation|rife_v4.25_heavy.safetensors|78643200"
  "interp-rife-49|https://huggingface.co/Isi99999/Frame_Interpolation_Models/resolve/main/rife49.pth|interpolation|rife49.pth|12582912"
  "interp-film|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/film_net_fp16.safetensors|interpolation|film_net_fp16.safetensors|60817408"

  # ===== Wan2.2 進階 Lightning / Distill LoRAs =====
  "5b-fast-fastwan|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/FastWan/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors|loras|Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors|644874240"
  "14b-fast-lightx2v-t2v-v1217|https://huggingface.co/lightx2v/Wan2.2-Distill-Loras/resolve/main/wan2.2_t2v_A14b_high_noise_lora_rank64_lightx2v_4step_1217.safetensors|loras|wan2.2_t2v_A14b_high_noise_lora_rank64_lightx2v_4step_1217.safetensors|596639744"
  "14b-fast-lightx2v-t2v-v1217|https://huggingface.co/lightx2v/Wan2.2-Distill-Loras/resolve/main/wan2.2_t2v_A14b_low_noise_lora_rank64_lightx2v_4step_1217.safetensors|loras|wan2.2_t2v_A14b_low_noise_lora_rank64_lightx2v_4step_1217.safetensors|596639744"
  "14b-fast-lightx2v-i2v-v1022|https://huggingface.co/lightx2v/Wan2.2-Distill-Loras/resolve/main/wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_1022.safetensors|loras|wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_1022.safetensors|617611264"
  "14b-fast-lightx2v-i2v-v1022|https://huggingface.co/lightx2v/Wan2.2-Distill-Loras/resolve/main/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors|loras|wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors|721420288"
  "14b-fast-seko-v11|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V1.1/high_noise_model.safetensors|loras|Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V1.1_high_noise_model.safetensors|1199570944"
  "14b-fast-seko-v11|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V1.1/low_noise_model.safetensors|loras|Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V1.1_low_noise_model.safetensors|1199570944"
  "14b-fast-kijai|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/Wan22_A14B_T2V_HIGH_Lightning_4steps_lora_250928_rank128_fp16.safetensors|loras|Wan22_A14B_T2V_HIGH_Lightning_4steps_lora_250928_rank128_fp16.safetensors|1199570944"
  "14b-fast-kijai|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/Wan22_A14B_T2V_LOW_Lightning_4steps_lora_250928_rank64_fp16.safetensors|loras|Wan22_A14B_T2V_LOW_Lightning_4steps_lora_250928_rank64_fp16.safetensors|596639744"

  # ===== Face restoration =====
  "face-gfpgan|https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth|facerestore_models|GFPGANv1.4.pth|339738624"
  "face-codeformer|https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth|facerestore_models|codeformer.pth|367001600"
  "face-restoreformer|https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/RestoreFormer.pth|facerestore_models|RestoreFormer.pth|282066944"
  "face-detect|https://github.com/xinntao/facexlib/releases/download/v0.1.0/detection_Resnet50_Final.pth|facedetection|detection_Resnet50_Final.pth|100663296"
  "face-parsing|https://github.com/xinntao/facexlib/releases/download/v0.2.2/parsing_parsenet.pth|facedetection|parsing_parsenet.pth|76808192"
)

# =============================================================================
# Recipes:命名套餐,展開成多個 tag。
# 格式:declare -A RECIPES; RECIPES[name]="tag1 tag2 ..."
# =============================================================================
declare -A RECIPES=(
  [wan22-5b-fast]="5b 5b-fast-fastwan"
  [wan22-i2v-with-upscale]="14b-i2v 14b-fast upscale-ultrasharp upscale-realesrgan-x4 interp-rife-426"
  [wan22-t2v-fast-interp]="14b-t2v 14b-fast interp-rife-426 interp-film"
  [wan22-animate-native]="14b-animate 14b-animate-lightx2v clip-vision wan21-vae"
  [wan22-animate-kijai-lowvram]="14b-animate-kijai 14b-animate-lightx2v clip-vision wan21-vae"
  [wan22-faces-postprocess]="face-gfpgan face-codeformer face-detect face-parsing upscale-ultrasharp"
  [wan22-upscale-pack]="upscale-realesrgan-x4 upscale-realesrgan-x2 upscale-realesrgan-anime upscale-ultrasharp upscale-ultrasharp-v2 upscale-remacri upscale-nmkd-siax upscale-nmkd-superscale upscale-swinir-x4"
  [wan22-interp-pack]="interp-rife-426 interp-rife-426-heavy interp-rife-425 interp-rife-425-lite interp-rife-425-heavy interp-rife-49 interp-film"
  [wan22-t2v-lightning-alt]="14b-t2v 14b-fast-seko-v11"
  [wan22-i2v-lightx2v-1022]="14b-i2v 14b-fast-lightx2v-i2v-v1022"
)

ALL_TAGS=(5b 14b-t2v 14b-i2v 14b-fast 14b-animate 14b-animate-kijai 14b-animate-lightx2v 14b-s2v
          14b-fun-control 14b-fun-inpaint 14b-fun-camera 14b-fun-vace chrono-edit
          textenc-fp16 clip-vision wan21-vae rgba-lora
          upscale-realesrgan-x4 upscale-realesrgan-x2 upscale-realesrgan-anime
          upscale-ultrasharp upscale-ultrasharp-v2 upscale-remacri
          upscale-nmkd-siax upscale-nmkd-superscale upscale-swinir-x4
          interp-rife-426 interp-rife-426-heavy interp-rife-425 interp-rife-425-lite
          interp-rife-425-heavy interp-rife-49 interp-film
          5b-fast-fastwan 14b-fast-lightx2v-t2v-v1217 14b-fast-lightx2v-i2v-v1022
          14b-fast-seko-v11 14b-fast-kijai
          face-gfpgan face-codeformer face-restoreformer face-detect face-parsing)

# =============================================================================
# 顯示工具
# =============================================================================
c_reset=$'\e[0m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_blu=$'\e[36m'; c_red=$'\e[31m'
info() { echo "${c_blu}==>${c_reset} $*"; }
ok()   { echo "${c_grn}  ✓${c_reset} $*"; }
warn() { echo "${c_yel}  ! ${c_reset}$*"; }
err()  { echo "${c_red}  ✗ ${c_reset}$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
filesize() { stat -c%s "$1" 2>/dev/null || echo 0; }

# =============================================================================
# 解析旗標
# =============================================================================
declare -A WANT
DO_MENU=0; DO_LIST=0; DO_LIST_RECIPES=0
NO_5B=0
ADD_TAG_DEFAULT_5B=1   # 預設啟用 5b,除非有 --no-5b 或指定 --recipe / 個別 tag

usage() {
  cat <<EOF
用法:./download_models.sh [選項]

預設 (不帶任何旗標) 等同於 --5b — 只裝跑 TI2V-5B 必要的 3 個檔。

旗標可疊用,**已存在且完整的會自動略過,不會重抓**。

  --5b                     TI2V-5B 主模型 (~10GB,加 shared 共 ~17GB)
  --no-5b                  不下載 5B (只裝 14B 等其他模型時用)

Wan2.2 主模型(各種變體):
  --14b-t2v / --14b-i2v / --14b-fast / --14b-animate / --14b-animate-kijai
  --14b-animate-lightx2v / --14b-s2v
  --14b-fun-control / --14b-fun-inpaint / --14b-fun-camera / --14b-fun-vace
  --chrono-edit

可選相依 (品質升級 / 相容性 / 透明影片):
  --textenc-fp16 / --clip-vision / --wan21-vae / --rgba-lora

進階 Lightning / Distill LoRAs:
  --5b-fast-fastwan                          5B 唯一的 4-step LoRA
  --14b-fast-lightx2v-t2v-v1217              2025-12-17 版本
  --14b-fast-lightx2v-i2v-v1022              2025-10-22 版本
  --14b-fast-seko-v11 / --14b-fast-kijai     替代版本

Upscalers (放到 ComfyUI/models/upscale_models/):
  --upscale-realesrgan-x4 / -x2 / -anime
  --upscale-ultrasharp / -ultrasharp-v2 / -remacri
  --upscale-nmkd-siax / -nmkd-superscale / -swinir-x4

Frame interpolation (放到 ComfyUI/models/interpolation/):
  --interp-rife-426 / -426-heavy / -425 / -425-lite / -425-heavy / -49
  --interp-film

Face restoration (放到 ComfyUI/models/facerestore_models/ 與 facedetection/):
  --face-gfpgan / --face-codeformer / --face-restoreformer
  --face-detect / --face-parsing

Workflow Recipes (一鍵裝整套工作流相依):
  --recipe NAME            指定 recipe,例如:--recipe wan22-i2v-with-upscale
  --list-recipes           列出所有 recipe + 內含 tag + 總大小

互動模式:
  --menu                   交互式選單 (跳出 select prompt,新手友善)

工具:
  --list                   列出所有可用旗標與每個檔案大小
  --all                    最常用組合 (5B + 14B t2v + 14B i2v + 14B fast)
  --everything             所有 Wan2.2 主模型 (5B + 全部 14B 變體) 注意 >150GB
  -h, --help               顯示這段說明
EOF
}

# 把一個「正規 tag」加進 WANT
want_tag() {
  local t="$1"
  if [[ " ${ALL_TAGS[*]} " == *" $t "* ]]; then
    WANT["$t"]=1
    return 0
  fi
  return 1
}

# 把 recipe 展開成多個 tag 加進 WANT
expand_recipe() {
  local name="$1"
  if [[ -z "${RECIPES[$name]:-}" ]]; then
    err "未知的 recipe:$name (用 --list-recipes 看可用清單)"; exit 1
  fi
  for t in ${RECIPES[$name]}; do want_tag "$t" || warn "recipe '$name' 引用了未知 tag:$t"; done
  ADD_TAG_DEFAULT_5B=0  # recipe 自帶 5b 與否,不再自動加
}

# =============================================================================
# 主解析迴圈 (用 while + shift,正確處理 --recipe NAME 兩個 token 的形式)
# =============================================================================
while (( $# )); do
  case "$1" in
    --no-5b)        NO_5B=1; ADD_TAG_DEFAULT_5B=0 ;;
    --all)          for t in 5b 14b-t2v 14b-i2v 14b-fast; do WANT[$t]=1; done; ADD_TAG_DEFAULT_5B=0 ;;
    --everything)   for t in "${ALL_TAGS[@]}"; do WANT[$t]=1; done; ADD_TAG_DEFAULT_5B=0 ;;
    --list)         DO_LIST=1 ;;
    --list-recipes) DO_LIST_RECIPES=1 ;;
    --menu)         DO_MENU=1 ;;
    -h|--help)      usage; exit 0 ;;
    --recipe)       shift; [[ -n "${1:-}" ]] || { err "--recipe 需要一個值 (例如 --recipe wan22-i2v-with-upscale)"; exit 1; }; expand_recipe "$1" ;;
    --recipe=*)     expand_recipe "${1#*=}" ;;
    --*)
      # 嘗試當成單一 tag (去掉前面的 --)
      if want_tag "${1#--}"; then ADD_TAG_DEFAULT_5B=0
      else err "未知選項:$1 (用 --help 看可用旗標)"; exit 1; fi ;;
    *) err "未知參數:$1 (用 --help 看可用選項)"; exit 1 ;;
  esac
  shift
done

# 處理 --list / --list-recipes (印完就退)
if (( DO_LIST_RECIPES )); then
  info "可用 Workflow Recipes (--recipe NAME):"
  mapfile -t names_sorted < <(printf '%s\n' "${!RECIPES[@]}" | sort)
  for name in "${names_sorted[@]}"; do
    echo "  ${c_grn}$name${c_reset}"
    echo "    展開為: ${RECIPES[$name]}"
  done
  exit 0
fi

if (( DO_LIST )); then
  info "可用單 tag 旗標 (--<tag>):"
  for line in "${MANIFEST[@]}"; do
    IFS='|' read -r tags _ _ name minb <<<"$line"
    mb=$(( minb / 1024 / 1024 ))
    printf "  %-32s %7d MB  → %s\n" "--${tags%%,*}" "$mb" "$name"
  done | sort -u
  exit 0
fi

# =============================================================================
# 互動模式 (--menu) — 用 bash select
# =============================================================================
if (( DO_MENU )); then
  info "請選擇模式:"
  PS3="輸入編號: "
  select mode in "選 Recipe (一鍵裝套餐)" "選單一 tag" "取消"; do
    case "$mode" in
      "選 Recipe"*)
        echo; echo "Recipes:"
        mapfile -t menu_names < <(printf '%s\n' "${!RECIPES[@]}" | sort)
        select n in "${menu_names[@]}" "取消"; do
          [[ "$n" == "取消" || -z "$n" ]] && exit 0
          expand_recipe "$n"; break
        done
        break ;;
      "選單一 tag"*)
        echo; echo "Tags:"
        mapfile -t menu_tags < <(printf '%s\n' "${ALL_TAGS[@]}" | sort)
        select n in "${menu_tags[@]}" "取消"; do
          [[ "$n" == "取消" || -z "$n" ]] && exit 0
          want_tag "$n"; ADD_TAG_DEFAULT_5B=0; break
        done
        break ;;
      "取消"|"") exit 0 ;;
    esac
  done
fi

# 預設行為:沒指定任何 tag → 加 5b
if (( ADD_TAG_DEFAULT_5B == 1 && NO_5B == 0 )); then
  WANT[5b]=1
fi
# --no-5b 顯式關閉
if (( NO_5B )); then unset 'WANT[5b]'; fi

# =============================================================================
# 環境準備
# =============================================================================
[[ -d "$COMFY_DIR" ]] || { err "找不到 ComfyUI ($COMFY_DIR),請先執行 ./install.sh"; exit 1; }

# 啟用 venv (若存在) — 給 hf CLI 用,但 hf 已不是必要,只是備援
if [[ -f "$VENV_DIR/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
fi

DL_METHOD="wget"
if have aria2c; then DL_METHOD="aria2c"
elif have curl; then DL_METHOD="curl"; fi

selected="shared"
for t in "${!WANT[@]}"; do (( WANT[$t] )) && selected+=" $t"; done
info "目標目錄:$MODELS_DIR"
info "下載方式:$DL_METHOD"
info "將下載 tags:$selected"

# 預先建立所有可能用到的子資料夾
mkdir -p "$MODELS_DIR"/{diffusion_models,text_encoders,vae,loras,clip_vision,audio_encoders,upscale_models,interpolation,facerestore_models,facedetection}

# =============================================================================
# 下載核心
# =============================================================================
fetch() {
  # fetch <url> <dest_dir> <filename> <min_bytes>
  local url="$1" dir="$2" name="$3" min="$4"
  local dest="$dir/$name"
  mkdir -p "$dir"
  # 已存在且大小達標 → 略過
  if [[ -f "$dest" ]]; then
    local sz; sz=$(filesize "$dest")
    if (( sz >= min )); then
      ok "已存在且完整,略過:$name ($(( sz / 1024 / 1024 )) MB)"
      return 0
    fi
    warn "檔案 $name 已存在但大小不足 ($(( sz / 1024 / 1024 ))MB < $(( min / 1024 / 1024 ))MB),續傳..."
  fi
  echo "${c_yel}  ⬇ 下載中 ($DL_METHOD):${c_reset} $name → $dir"
  case "$DL_METHOD" in
    aria2c)
      aria2c -x 16 -s 16 -c -k 1M --max-tries=5 --retry-wait=5 \
             --dir="$dir" --out="$name" "$url"
      ;;
    curl)
      curl -L --fail --retry 5 --retry-delay 5 -C - -o "$dest.part" "$url"
      mv -f "$dest.part" "$dest"
      ;;
    wget)
      wget -c -O "$dest" "$url"
      ;;
  esac
  # 下載後驗證大小
  local final; final=$(filesize "$dest")
  if (( final < min )); then
    err "下載失敗或不完整:$name (得到 $(( final / 1024 / 1024 ))MB < 預期 $(( min / 1024 / 1024 ))MB)"
    return 1
  fi
  ok "完成:$name ($(( final / 1024 / 1024 )) MB)"
}

# =============================================================================
# 走過 MANIFEST,挑符合「shared OR WANT[tag]=1」的下載
# =============================================================================
for line in "${MANIFEST[@]}"; do
  IFS='|' read -r tags url subdir name minb <<<"$line"
  do_fetch=0
  for t in ${tags//,/ }; do
    [[ "$t" == "shared" ]] && do_fetch=1
    [[ -n "${WANT[$t]:-}" && "${WANT[$t]}" == "1" ]] && do_fetch=1
  done
  (( do_fetch )) && fetch "$url" "$MODELS_DIR/$subdir" "$name" "$minb"
done

echo
ok "全部模型就緒。各子資料夾現況:"
for d in diffusion_models text_encoders vae loras clip_vision audio_encoders upscale_models interpolation facerestore_models facedetection; do
  if [[ -d "$MODELS_DIR/$d" ]] && [[ -n "$(ls -A "$MODELS_DIR/$d" 2>/dev/null)" ]]; then
    echo "   $MODELS_DIR/$d/"
    # shellcheck disable=SC2012
    ls -lh "$MODELS_DIR/$d" 2>/dev/null | awk 'NR>1 && $9!~/^\./{printf "      %8s  %s\n", $5, $9}'
  fi
done
echo
echo "下一步:./start.sh  → 瀏覽器開 http://127.0.0.1:8188"
echo "       Workflow → Browse Templates → Video → 選對應的 Wan2.2 範本"
