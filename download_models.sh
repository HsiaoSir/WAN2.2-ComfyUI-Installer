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

  # ===== 2026-Q4 新增:更新版 Lightning / Distill LoRA =====
  "14b-fast-seko-v20|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V2.0/high_noise_model.safetensors|loras|Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V2.0_high_noise_model.safetensors|1193422992"
  "14b-fast-seko-v20|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V2.0/low_noise_model.safetensors|loras|Wan2.2-T2V-A14B-4steps-lora-rank64-Seko-V2.0_low_noise_model.safetensors|1193422992"
  "14b-fast-lightx2v-i2v-260412|https://huggingface.co/obsxrver/wan2.2-i2v-lightx2v-260412/resolve/main/wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_720p_260412.safetensors|loras|wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_720p_260412.safetensors|582842404"
  "14b-fast-lightx2v-i2v-260412|https://huggingface.co/obsxrver/wan2.2-i2v-lightx2v-260412/resolve/main/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_720p_260412.safetensors|loras|wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_720p_260412.safetensors|582842404"

  # ===== NVFP4 Sparse (Blackwell / RTX 50 系列專用) =====
  "14b-t2v-nvfp4-sparse|https://huggingface.co/lightx2v/Wan2.2-NVFP4-Sparse/resolve/main/Wan2.2-T2V-A14B_NVFP4_Sparse_high_comfy.safetensors|diffusion_models|Wan2.2-T2V-A14B_NVFP4_Sparse_high_comfy.safetensors|8345545192"
  "14b-t2v-nvfp4-sparse|https://huggingface.co/lightx2v/Wan2.2-NVFP4-Sparse/resolve/main/Wan2.2-T2V-A14B_NVFP4_Sparse_low_comfy.safetensors|diffusion_models|Wan2.2-T2V-A14B_NVFP4_Sparse_low_comfy.safetensors|8345545192"
  "14b-i2v-nvfp4-sparse|https://huggingface.co/lightx2v/Wan2.2-NVFP4-Sparse/resolve/main/Wan2.2-I2V-A14B_NVFP4_Sparse_high_comfy.safetensors|diffusion_models|Wan2.2-I2V-A14B_NVFP4_Sparse_high_comfy.safetensors|8346364392"
  "14b-i2v-nvfp4-sparse|https://huggingface.co/lightx2v/Wan2.2-NVFP4-Sparse/resolve/main/Wan2.2-I2V-A14B_NVFP4_Sparse_low_comfy.safetensors|diffusion_models|Wan2.2-I2V-A14B_NVFP4_Sparse_low_comfy.safetensors|8346364392"

  # ===== Wan2.2 5B Ovi (TI2V + Audio,Kijai 重打包) =====
  "5b-ovi-video|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/TI2V/Ovi/Wan2_2-5B-Ovi_960x960_10s_fp8_e4m3fn_scaled_KJ.safetensors|diffusion_models|Wan2_2-5B-Ovi_960x960_10s_fp8_e4m3fn_scaled_KJ.safetensors|12341119544"
  "ovi-mmaudio-vae|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Ovi/mmaudio_vae_16k_bf16.safetensors|vae|mmaudio_vae_16k_bf16.safetensors|326154893"
  "ovi-mmaudio-vocoder|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Ovi/mmaudio_vocoder_bigvgan_best_netG_bf16.safetensors|vae|mmaudio_vocoder_bigvgan_best_netG_bf16.safetensors|213323484"

  # ===== Kijai 版 Fun-Control (與既有 Comfy-Org 版並存,不同來源) =====
  "14b-fun-control-kijai|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Fun/Wan2_2-Fun-Control-A14B-HIGH_fp8_e4m3fn_scaled_KJ_fixed.safetensors|diffusion_models|Wan2_2-Fun-Control-A14B-HIGH_fp8_e4m3fn_scaled_KJ_fixed.safetensors|14496941346"
  "14b-fun-control-kijai|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Fun/Wan2_2-Fun-Control-A14B-LOW_fp8_e4m3fn_scaled_KJ_fixed.safetensors|diffusion_models|Wan2_2-Fun-Control-A14B-LOW_fp8_e4m3fn_scaled_KJ_fixed.safetensors|14496941346"

  # ===== Depth Anything V2 (Fun-Control 用的 depth conditioning) =====
  "depth-anything-v2-vitl|https://huggingface.co/Kijai/DepthAnythingV2-safetensors/resolve/main/depth_anything_v2_vitl_fp16.safetensors|depthanything|depth_anything_v2_vitl_fp16.safetensors|637141069"

  # ===== InfiniteTalk (Wan2.1 base, 多人講話對嘴影片) =====
  "infinitetalk-single|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors|diffusion_models|Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors|2679993778"
  "infinitetalk-multi|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Multi_fp8_e4m3fn_scaled_KJ.safetensors|diffusion_models|Wan2_1-InfiniteTalk-Multi_fp8_e4m3fn_scaled_KJ.safetensors|2679174658"
  "wav2vec2-chinese|https://huggingface.co/Kijai/wav2vec2_safetensors/resolve/main/wav2vec2-chinese-base_fp16.safetensors|wav2vec2|wav2vec2-chinese-base_fp16.safetensors|180609599"
  "melband-roformer|https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors|diffusion_models|MelBandRoformer_fp16.safetensors|433655118"

  # ===== Kijai bf16 text encoder (Kijai wrapper workflow 指定版) =====
  "umt5-bf16-kijai|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors|text_encoders|umt5-xxl-enc-bf16.safetensors|11328291032"

  # ===== Kijai 版 S2V + LongCat Avatar =====
  "14b-s2v-kijai|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/S2V/Wan2_2-S2V-14B_fp8_e4m3fn_scaled_KJ.safetensors|diffusion_models|Wan2_2-S2V-14B_fp8_e4m3fn_scaled_KJ.safetensors|16619776188"
  "longcat-avatar-single|https://huggingface.co/Kijai/LongCat-Video_comfy/resolve/main/Avatar/LongCat-Avatar-single_fp8_e4m3fn_scaled_mixed_KJ.safetensors|diffusion_models|LongCat-Avatar-single_fp8_e4m3fn_scaled_mixed_KJ.safetensors|16862843224"
  # ============================================================================
  # === 2026-Q2 多家族擴充:LTX / Hunyuan / Mochi / CogVideoX / SVD / AnimateDiff / Cosmos /
  # === Sonic / Hallo / EchoMimic / MagicAnimate / MusePose / AnimateAnyone / Champ /
  # === V-Express / LivePortrait / FollowYourEmoji / MimicMotion / PyramidFlow / SkyReels /
  # === Kandinsky / DynamiCrafter / ControlNet / IPAdapter / SAM / DWPose / DepthAnything /
  # === MMAudio / BiRefNet / SUPIR / DepthFM / Lotus / VEnhancer / Framer / GIMM-VFI ...
  # === 180 個檔案全部 HTTP HEAD 200 + Content-Length>0 驗證 (2026-06-07)
  # ============================================================================

  # ----- LTX-Video (17) -----
  "ltx-video-13b-097-dev|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.7-dev.safetensors|diffusion_models|ltxv-13b-0.9.7-dev.safetensors|28007599674"
  "ltx-video-13b-097-dev-fp8|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.7-dev-fp8.safetensors|diffusion_models|ltxv-13b-0.9.7-dev-fp8.safetensors|15380394318"
  "ltx-video-13b-097-distilled|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.7-distilled.safetensors|diffusion_models|ltxv-13b-0.9.7-distilled.safetensors|28007599776"
  "ltx-video-13b-097-distilled-fp8|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.7-distilled-fp8.safetensors|diffusion_models|ltxv-13b-0.9.7-distilled-fp8.safetensors|15380394420"
  "ltx-video-13b-097-distilled-lora|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.7-distilled-lora128.safetensors|loras|ltxv-13b-0.9.7-distilled-lora128.safetensors|1299153206"
  "ltx-vae|https://huggingface.co/Lightricks/LTX-Video/resolve/main/vae/diffusion_pytorch_model.safetensors|vae|ltx-video-vae.safetensors|1643262562"
  "ltx-spatial-upscaler-097|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-spatial-upscaler-0.9.7.safetensors|diffusion_models|ltxv-spatial-upscaler-0.9.7.safetensors|488247216"
  "ltx-temporal-upscaler-097|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-temporal-upscaler-0.9.7.safetensors|diffusion_models|ltxv-temporal-upscaler-0.9.7.safetensors|507117552"
  "ltx-lora-squish|https://huggingface.co/Lightricks/LTX-Video-Squish-LoRA/resolve/main/ltxv_095_squish_lora.safetensors|loras|ltxv_095_squish_lora.safetensors|453044528"
  "ltx-lora-cakeify|https://huggingface.co/Lightricks/LTX-Video-Cakeify-LoRA/resolve/main/ltxv_095_cakeify_lora.safetensors|loras|ltxv_095_cakeify_lora.safetensors|453044528"
  "ltx-2-3-22b-distilled-fp8|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/diffusion_models/ltx-2.3-22b-distilled_transformer_only_fp8_scaled.safetensors|diffusion_models|ltx-2.3-22b-distilled_transformer_only_fp8_scaled.safetensors|23000961409"
  "ltx-2-3-video-vae|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors|vae|LTX23_video_vae_bf16.safetensors|1423213407"
  "ltx-2-3-text-projection|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors|text_encoders|ltx-2.3_text_projection_bf16.safetensors|2265906091"
  "ltx-2-gemma3-fp8|https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp8_scaled.safetensors|text_encoders|gemma_3_12B_it_fp8_scaled.safetensors|12941326131"
  "ltx-video-0-9-6-dev-gguf-q4|https://huggingface.co/city96/LTX-Video-0.9.6-dev-gguf/resolve/main/ltxv-2b-0.9.6-dev-04-25-Q4_K_M.gguf|unet_gguf|ltxv-2b-0.9.6-dev-04-25-Q4_K_M.gguf|1303448546"
  "ltx-video-0-9-6-dev-gguf-q6|https://huggingface.co/city96/LTX-Video-0.9.6-dev-gguf/resolve/main/ltxv-2b-0.9.6-dev-04-25-Q6_K.gguf|unet_gguf|ltxv-2b-0.9.6-dev-04-25-Q6_K.gguf|1600169339"
  "ltx-video-0-9-6-distilled-gguf-q4|https://huggingface.co/city96/LTX-Video-0.9.6-distilled-gguf/resolve/main/ltxv-2b-0.9.6-distilled-04-25-Q4_K_M.gguf|unet_gguf|ltxv-2b-0.9.6-distilled-04-25-Q4_K_M.gguf|1303448546"
  # ----- Hunyuan-Video (23) -----
  "hunyuan-video-t2v-bf16|https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/diffusion_models/hunyuan_video_t2v_720p_bf16.safetensors|diffusion_models|hunyuan_video_t2v_720p_bf16.safetensors|25129288804"
  "hunyuan-video-t2v-fp8|https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_720_cfgdistill_fp8_e4m3fn.safetensors|diffusion_models|hunyuan_video_720_cfgdistill_fp8_e4m3fn.safetensors|12921334630"
  "hunyuan-video-i2v-bf16|https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/diffusion_models/hunyuan_video_image_to_video_720p_bf16.safetensors|diffusion_models|hunyuan_video_image_to_video_720p_bf16.safetensors|25109637099"
  "hunyuan-video-i2v-fp8|https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_I2V_720_fixed_fp8_e4m3fn.safetensors|diffusion_models|hunyuan_video_I2V_720_fixed_fp8_e4m3fn.safetensors|12921334630"
  "hunyuan-vae|https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/vae/hunyuan_video_vae_bf16.safetensors|vae|hunyuan_video_vae_bf16.safetensors|476206982"
  "hunyuan-clip-l|https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/clip_l.safetensors|text_encoders|clip_l.safetensors|229366936"
  "hunyuan-llava-fp8|https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/llava_llama3_fp8_scaled.safetensors|text_encoders|llava_llama3_fp8_scaled.safetensors|8909564634"
  "hunyuan-llava-vision|https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/clip_vision/llava_llama3_vision.safetensors|clip_vision|llava_llama3_vision.safetensors|632245160"
  "hunyuan-fastvideo-lora|https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hyvideo_FastVideo_LoRA-fp8.safetensors|loras|hyvideo_FastVideo_LoRA-fp8.safetensors|157249800"
  "hunyuan-accvid-lora|https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_accvid_5_steps_lora_rank16_fp8_e4m3fn.safetensors|loras|hunyuan_video_accvid_5_steps_lora_rank16_fp8_e4m3fn.safetensors|157249800"
  "hunyuan-foley|https://huggingface.co/tencent/HunyuanVideo-Foley/resolve/main/hunyuanvideo_foley.pth|audio_encoders|hunyuanvideo_foley.pth|10095180586"
  "hunyuan-foley-synchformer|https://huggingface.co/tencent/HunyuanVideo-Foley/resolve/main/synchformer_state_dict.pth|audio_encoders|synchformer_state_dict.pth|931057008"
  "hunyuan-foley-vae|https://huggingface.co/tencent/HunyuanVideo-Foley/resolve/main/vae_128d_48k.pth|audio_encoders|vae_128d_48k.pth|1456736646"
  "hunyuanvideo15-i2v-fp8|https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/diffusion_models/hunyuanvideo1.5_720p_i2v_cfg_distilled_fp8_scaled.safetensors|diffusion_models|hunyuanvideo1.5_720p_i2v_cfg_distilled_fp8_scaled.safetensors|8163791752"
  "hunyuanvideo15-t2v-fp8|https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/diffusion_models/hunyuanvideo1.5_480p_t2v_cfg_distilled_fp8_scaled.safetensors|diffusion_models|hunyuanvideo1.5_480p_t2v_cfg_distilled_fp8_scaled.safetensors|8163791752"
  "hunyuanvideo15-vae|https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/vae/hunyuanvideo15_vae_fp16.safetensors|vae|hunyuanvideo15_vae_fp16.safetensors|2470866903"
  "hunyuanvideo15-qwen25vl-fp8|https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors|text_encoders|qwen_2.5_vl_7b_fp8_scaled.safetensors|9196977267"
  "hunyuanvideo15-lightx2v-lora|https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/resolve/main/split_files/loras/hunyuanvideo1.5_t2v_480p_lightx2v_4step_lora_rank_32_bf16.safetensors|loras|hunyuanvideo1.5_t2v_480p_lightx2v_4step_lora_rank_32_bf16.safetensors|324288466"
  "framepack-i2v-hy-fp8|https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/FramePackI2V_HY_fp8_e4m3fn.safetensors|diffusion_models|FramePackI2V_HY_fp8_e4m3fn.safetensors|16005212977"
  "hunyuan-video-t2v-gguf-q4|https://huggingface.co/city96/HunyuanVideo-gguf/resolve/main/hunyuan-video-t2v-720p-Q4_K_M.gguf|unet_gguf|hunyuan-video-t2v-720p-Q4_K_M.gguf|7726006902"
  "hunyuan-video-t2v-gguf-q6|https://huggingface.co/city96/HunyuanVideo-gguf/resolve/main/hunyuan-video-t2v-720p-Q6_K.gguf|unet_gguf|hunyuan-video-t2v-720p-Q6_K.gguf|10734640144"
  "hunyuan-video-i2v-gguf-q4|https://huggingface.co/city96/HunyuanVideo-I2V-gguf/resolve/main/hunyuan-video-i2v-720p-Q4_K_M.gguf|unet_gguf|hunyuan-video-i2v-720p-Q4_K_M.gguf|7726006902"
  "fast-hunyuan-video-gguf-q4|https://huggingface.co/city96/FastHunyuan-gguf/resolve/main/fast-hunyuan-video-t2v-720p-Q4_K_M.gguf|unet_gguf|fast-hunyuan-video-t2v-720p-Q4_K_M.gguf|7726006902"
  # ----- Mochi (3) -----
  "mochi-preview-bf16|https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/split_files/diffusion_models/mochi_preview_bf16.safetensors|diffusion_models|mochi_preview_bf16.safetensors|19654358413"
  "mochi-preview-fp8|https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/split_files/diffusion_models/mochi_preview_fp8_scaled.safetensors|diffusion_models|mochi_preview_fp8_scaled.safetensors|9827522477"
  "mochi-vae|https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/split_files/vae/mochi_vae.safetensors|vae|mochi_vae.safetensors|901153808"
  # ----- CogVideoX (5) -----
  "cogvideox-1-0-5b-i2v|https://huggingface.co/Kijai/CogVideoX-comfy/resolve/main/CogVideoX_1_0_5b_I2V_bf16.safetensors|diffusion_models|CogVideoX_1_0_5b_I2V_bf16.safetensors|11025286247"
  "cogvideox-1-5-5b-t2v|https://huggingface.co/Kijai/CogVideoX-comfy/resolve/main/CogVideoX_1_5_5b_T2V_bf16.safetensors|diffusion_models|CogVideoX_1_5_5b_T2V_bf16.safetensors|10918640130"
  "cogvideox-1-5-5b-i2v|https://huggingface.co/Kijai/CogVideoX-comfy/resolve/main/CogVideoX_1_5_5b_I2V_bf16.safetensors|diffusion_models|CogVideoX_1_5_5b_I2V_bf16.safetensors|10920440821"
  "cogvideox-fun-1-1-5b-control-fp8|https://huggingface.co/Kijai/CogVideoX-comfy/resolve/main/CogVideoX_Fun_1_1_5b_Control_fp8_e4m3fn.safetensors|diffusion_models|CogVideoX_Fun_1_1_5b_Control_fp8_e4m3fn.safetensors|5474097085"
  "cogvideox-vae|https://huggingface.co/Kijai/CogVideoX-comfy/resolve/main/cogvideox_vae_bf16.safetensors|vae|cogvideox_vae_bf16.safetensors|414443926"
  # ----- SVD (5) -----
  "svd|https://huggingface.co/stabilityai/stable-video-diffusion-img2vid/resolve/main/svd.safetensors|checkpoints|svd.safetensors|9368433461"
  "svd-xt|https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors|checkpoints|svd_xt.safetensors|9368433461"
  "animatelcm-svd-xt|https://huggingface.co/Kijai/AnimateLCM-SVD-Comfy/resolve/main/AnimateLCM-SVD-xt-1-1_fp16_comfy.safetensors|diffusion_models|AnimateLCM-SVD-xt-1-1_fp16_comfy.safetensors|4419045007"
  "controlnext-svd|https://huggingface.co/Kijai/ControlNeXt-SVD-V2-Comfy/resolve/main/controlnext-svd_v2-unet-fp16.safetensors|controlnext|controlnext-svd_v2-unet-fp16.safetensors|2988447151"
  "controlnext-svd-cnet|https://huggingface.co/Kijai/ControlNeXt-SVD-V2-Comfy/resolve/main/controlnext-svd_v2-controlnet-fp16.safetensors|controlnext|controlnext-svd_v2-controlnet-fp16.safetensors|1024"
  # ----- AnimateDiff (17) -----
  "animatediff-mm-v2|https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|animatediff_models|mm_sd_v15_v2.ckpt|1781530663"
  "animatediff-v3-mm|https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt|animatediff_models|v3_sd15_mm.ckpt|1639797332"
  "animatediff-v3-adapter|https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_adapter.ckpt|loras|v3_sd15_adapter.ckpt|85356881"
  "animatediff-sdxl-beta|https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt|animatediff_models|mm_sdxl_v10_beta.ckpt|931140668"
  "animatediff-sparsectrl-rgb|https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_sparsectrl_rgb.ckpt|controlnet|v3_sd15_sparsectrl_rgb.ckpt|1948279527"
  "animatediff-sparsectrl-scribble|https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_sparsectrl_scribble.ckpt|controlnet|v3_sd15_sparsectrl_scribble.ckpt|1952488984"
  "animatediff-motion-lora-zoom-in|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomIn.ckpt|animatediff_motion_lora|v2_lora_ZoomIn.ckpt|60697283"
  "animatediff-motion-lora-zoom-out|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomOut.ckpt|animatediff_motion_lora|v2_lora_ZoomOut.ckpt|60697283"
  "animatediff-motion-lora-pan-left|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_PanLeft.ckpt|animatediff_motion_lora|v2_lora_PanLeft.ckpt|60697283"
  "animatediff-motion-lora-pan-right|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_PanRight.ckpt|animatediff_motion_lora|v2_lora_PanRight.ckpt|60697283"
  "animatediff-motion-lora-tilt-up|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_TiltUp.ckpt|animatediff_motion_lora|v2_lora_TiltUp.ckpt|60697283"
  "animatediff-motion-lora-tilt-down|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_TiltDown.ckpt|animatediff_motion_lora|v2_lora_TiltDown.ckpt|60697283"
  "animatediff-motion-lora-rolling-cw|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_RollingClockwise.ckpt|animatediff_motion_lora|v2_lora_RollingClockwise.ckpt|60697283"
  "animatediff-motion-lora-rolling-ccw|https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_RollingAnticlockwise.ckpt|animatediff_motion_lora|v2_lora_RollingAnticlockwise.ckpt|60697283"
  "animatelcm-mm|https://huggingface.co/wangfuyun/AnimateLCM/resolve/main/AnimateLCM_sd15_t2v.ckpt|animatediff_models|AnimateLCM_sd15_t2v.ckpt|1776781091"
  "animatelcm-lora|https://huggingface.co/wangfuyun/AnimateLCM/resolve/main/AnimateLCM_sd15_t2v_lora.safetensors|loras|AnimateLCM_sd15_t2v_lora.safetensors|117844340"
  "magictime-mm|https://huggingface.co/Kijai/MagicTime-merged-fp16/resolve/main/v3_sd15_mm_magictime_fp16.safetensors|animatediff_models|v3_sd15_mm_magictime_fp16.safetensors|819840816"
  # ----- SkyReels (5) -----
  "skyreels-v1-hunyuan-t2v-fp8|https://huggingface.co/Kijai/SkyReels-V1-Hunyuan_comfy/resolve/main/skyreels_hunyuan_t2v_fp8_e4m3fn.safetensors|diffusion_models|skyreels_hunyuan_t2v_fp8_e4m3fn.safetensors|12902645065"
  "skyreels-v1-hunyuan-i2v-fp8|https://huggingface.co/Kijai/SkyReels-V1-Hunyuan_comfy/resolve/main/skyreels_hunyuan_i2v_fp8_e4m3fn.safetensors|diffusion_models|skyreels_hunyuan_i2v_fp8_e4m3fn.safetensors|12903030417"
  "skyreels-v2-t2v-14b-540p-gguf|https://huggingface.co/wsbagnsv1/SkyReels-V2-T2V-14B-540P-GGUF/resolve/main/Skywork-SkyReels-V2-T2V-14B-540P-Q4_K_M.gguf|unet_gguf|Skywork-SkyReels-V2-T2V-14B-540P-Q4_K_M.gguf|9466732639"
  "skyreels-v2-i2v-14b-540p-gguf|https://huggingface.co/wsbagnsv1/SkyReels-V2-I2V-14B-540P-GGUF/resolve/main/Skywork-SkyReels-V2-I2V-14B-540P-Q4_K_M.gguf|unet_gguf|Skywork-SkyReels-V2-I2V-14B-540P-Q4_K_M.gguf|10642947142"
  "skyreels-v2-df-14b-540p-gguf|https://huggingface.co/wsbagnsv1/SkyReels-V2-DF-14B-540P-GGUF/resolve/main/Skywork-SkyReels-V2-DF-14B-540P-Q4_K_M.gguf|unet_gguf|Skywork-SkyReels-V2-DF-14B-540P-Q4_K_M.gguf|9466732639"
  # ----- PyramidFlow (3) -----
  "pyramid-flow-miniflux-fp8|https://huggingface.co/Kijai/pyramid-flow-comfy/resolve/main/pyramid_flow_miniflux_fp8_e4m3fn_v2.safetensors|diffusion_models|pyramid_flow_miniflux_fp8_e4m3fn_v2.safetensors|1932687346"
  "pyramid-flow-miniflux-768-fp8|https://huggingface.co/Kijai/pyramid-flow-comfy/resolve/main/pyramid_flow_miniflux_768_fp8_e4m3fn.safetensors|diffusion_models|pyramid_flow_miniflux_768_fp8_e4m3fn.safetensors|1933483262"
  "pyramid-flow-vae|https://huggingface.co/Kijai/pyramid-flow-comfy/resolve/main/pyramid_flow_vae_bf16.safetensors|vae|pyramid_flow_vae_bf16.safetensors|654057438"
  # ----- Cosmos (3) -----
  "cosmos1-7b-video2world|https://huggingface.co/Kijai/Cosmos1_ComfyUI/resolve/main/Cosmos_1_0_Diffusion_7B_Video2World_bf16.safetensors|diffusion_models|Cosmos_1_0_Diffusion_7B_Video2World_bf16.safetensors|14183042607"
  "cosmos-predict2-2b-720p|https://huggingface.co/Comfy-Org/Cosmos_Predict2_repackaged/resolve/main/cosmos_predict2_2B_video2world_720p_16fps.safetensors|diffusion_models|cosmos_predict2_2B_video2world_720p_16fps.safetensors|3834652386"
  "cosmos-predict2-14b-720p|https://huggingface.co/Comfy-Org/Cosmos_Predict2_repackaged/resolve/main/cosmos_predict2_14B_video2world_720p_16fps.safetensors|diffusion_models|cosmos_predict2_14B_video2world_720p_16fps.safetensors|27960066672"
  # ----- Kandinsky (2) -----
  "kandinsky5-pro-i2v-fp8|https://huggingface.co/Kijai/Kandinsky5_comfy/resolve/main/fp8_scaled/Pro/I2V/kandinsky5-I2V-pro-5s-distill_fp8_scaled_KJ.safetensors|diffusion_models|kandinsky5-I2V-pro-5s-distill_fp8_scaled_KJ.safetensors|18929697074"
  "kandinsky5-pro-t2v-fp8|https://huggingface.co/Kijai/Kandinsky5_comfy/resolve/main/fp8_scaled/Pro/T2V/kandinsky5-T2V-pro-5s-distill_fp8_scaled_KJ.safetensors|diffusion_models|kandinsky5-T2V-pro-5s-distill_fp8_scaled_KJ.safetensors|18929697074"
  # ----- DynamiCrafter (2) -----
  "dynamicrafter-1024|https://huggingface.co/Kijai/DynamiCrafter_pruned/resolve/main/dynamicrafter_1024_fp16_pruned.safetensors|diffusion_models|dynamicrafter_1024_fp16_pruned.safetensors|3080012943"
  "tooncrafter-512-interp|https://huggingface.co/Kijai/DynamiCrafter_pruned/resolve/main/tooncrafter_512_interp-pruned-fp16.safetensors|diffusion_models|tooncrafter_512_interp-pruned-fp16.safetensors|3111957031"
  # ----- Sonic (5) -----
  "sonic-unet|https://huggingface.co/LeonJoe13/Sonic/resolve/main/Sonic/unet.pth|sonic|unet.pth|6177563631"
  "sonic-audio2bucket|https://huggingface.co/LeonJoe13/Sonic/resolve/main/Sonic/audio2bucket.pth|sonic|audio2bucket.pth|70273782"
  "sonic-audio2token|https://huggingface.co/LeonJoe13/Sonic/resolve/main/Sonic/audio2token.pth|sonic|audio2token.pth|200428868"
  "sonic-yoloface|https://huggingface.co/LeonJoe13/Sonic/resolve/main/yoloface_v5m.pt|sonic|yoloface_v5m.pt|67797543"
  "sonic-rife|https://huggingface.co/LeonJoe13/Sonic/resolve/main/RIFE/flownet.pkl|sonic|flownet.pkl|1024"
  # ----- Hallo (4) -----
  "hallo-net|https://huggingface.co/fudan-generative-ai/hallo/resolve/main/hallo/net.pth|hallo|net.pth|4753529893"
  "hallo-wav2vec|https://huggingface.co/fudan-generative-ai/hallo/resolve/main/wav2vec/wav2vec2-base-960h/model.safetensors|hallo|wav2vec2-base-960h.safetensors|360830685"
  "hallo2-net|https://huggingface.co/fudan-generative-ai/hallo2/resolve/main/hallo2/net.pth|hallo|hallo2_net.pth|4753752250"
  "hallo2-net-g|https://huggingface.co/fudan-generative-ai/hallo2/resolve/main/hallo2/net_g.pth|hallo|hallo2_net_g.pth|886638321"
  # ----- EchoMimic (8) -----
  "echomimic-denoising|https://huggingface.co/BadToBest/EchoMimic/resolve/main/denoising_unet.pth|echomimic|denoising_unet.pth|3332035019"
  "echomimic-reference|https://huggingface.co/BadToBest/EchoMimic/resolve/main/reference_unet.pth|echomimic|reference_unet.pth|3197075757"
  "echomimic-motion|https://huggingface.co/BadToBest/EchoMimic/resolve/main/motion_module.pth|echomimic|motion_module.pth|1781542801"
  "echomimic-face-locator|https://huggingface.co/BadToBest/EchoMimic/resolve/main/face_locator.pth|echomimic|face_locator.pth|1024"
  "echomimicv2-denoising|https://huggingface.co/BadToBest/EchoMimicV2/resolve/main/denoising_unet.pth|echomimic|v2_denoising_unet.pth|1668148746"
  "echomimicv2-reference|https://huggingface.co/BadToBest/EchoMimicV2/resolve/main/reference_unet.pth|echomimic|v2_reference_unet.pth|1598654609"
  "echomimicv2-motion|https://huggingface.co/BadToBest/EchoMimicV2/resolve/main/motion_module.pth|echomimic|v2_motion_module.pth|890772879"
  "echomimicv2-pose|https://huggingface.co/BadToBest/EchoMimicV2/resolve/main/pose_encoder.pth|echomimic|v2_pose_encoder.pth|1668007118"
  # ----- MagicAnimate (3) -----
  "magicanimate-appearance|https://huggingface.co/zcxu-eric/MagicAnimate/resolve/main/appearance_encoder/diffusion_pytorch_model.safetensors|magicanimate|appearance_encoder.safetensors|3359779974"
  "magicanimate-densepose-cnet|https://huggingface.co/zcxu-eric/MagicAnimate/resolve/main/densepose_controlnet/diffusion_pytorch_model.safetensors|magicanimate|densepose_controlnet.safetensors|1416253978"
  "magicanimate-temporal|https://huggingface.co/zcxu-eric/MagicAnimate/resolve/main/temporal_attention/temporal_attention.ckpt|magicanimate|temporal_attention.ckpt|5008396251"
  # ----- MusePose (4) -----
  "musepose-denoising|https://huggingface.co/TMElyralab/MusePose/resolve/main/MusePose/denoising_unet.pth|musepose|denoising_unet.pth|3334703637"
  "musepose-motion|https://huggingface.co/TMElyralab/MusePose/resolve/main/MusePose/motion_module.pth|musepose|motion_module.pth|897878330"
  "musepose-pose-guider|https://huggingface.co/TMElyralab/MusePose/resolve/main/MusePose/pose_guider.pth|musepose|pose_guider.pth|3334562001"
  "musepose-reference|https://huggingface.co/TMElyralab/MusePose/resolve/main/MusePose/reference_unet.pth|musepose|reference_unet.pth|3371594595"
  # ----- AnimateAnyone (4) -----
  "animateanyone-denoising|https://huggingface.co/patrolli/AnimateAnyone/resolve/main/denoising_unet.pth|animateanyone|denoising_unet.pth|3369606808"
  "animateanyone-reference|https://huggingface.co/patrolli/AnimateAnyone/resolve/main/reference_unet.pth|animateanyone|reference_unet.pth|3369557341"
  "animateanyone-motion|https://huggingface.co/patrolli/AnimateAnyone/resolve/main/motion_module.pth|animateanyone|motion_module.pth|1781542223"
  "animateanyone-pose-guider|https://huggingface.co/patrolli/AnimateAnyone/resolve/main/pose_guider.pth|animateanyone|pose_guider.pth|1024"
  # ----- Champ (5) -----
  "champ-denoising|https://huggingface.co/fudan-generative-ai/champ/resolve/main/champ/denoising_unet.pth|champ|denoising_unet.pth|3369606808"
  "champ-reference|https://huggingface.co/fudan-generative-ai/champ/resolve/main/champ/reference_unet.pth|champ|reference_unet.pth|3369557341"
  "champ-motion|https://huggingface.co/fudan-generative-ai/champ/resolve/main/champ/motion_module.pth|champ|motion_module.pth|1781542801"
  "champ-guide-dwpose|https://huggingface.co/fudan-generative-ai/champ/resolve/main/champ/guidance_encoder_dwpose.pth|champ|guidance_encoder_dwpose.pth|1024"
  "champ-guide-depth|https://huggingface.co/fudan-generative-ai/champ/resolve/main/champ/guidance_encoder_depth.pth|champ|guidance_encoder_depth.pth|1024"
  # ----- V-Express (5) -----
  "vexpress-denoising|https://huggingface.co/tk93/V-Express/resolve/main/denoising_unet.bin|vexpress|denoising_unet.bin|2673012284"
  "vexpress-motion|https://huggingface.co/tk93/V-Express/resolve/main/motion_module.bin|vexpress|motion_module.bin|890872745"
  "vexpress-reference|https://huggingface.co/tk93/V-Express/resolve/main/reference_net.bin|vexpress|reference_net.bin|1684882669"
  "vexpress-audio-proj|https://huggingface.co/tk93/V-Express/resolve/main/audio_projection.bin|vexpress|audio_projection.bin|42286831"
  "vexpress-kps-guider|https://huggingface.co/tk93/V-Express/resolve/main/v_kps_guider.bin|vexpress|v_kps_guider.bin|1024"
  # ----- LivePortrait (6) -----
  "liveportrait-appearance|https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/appearance_feature_extractor.safetensors|liveportrait|appearance_feature_extractor.safetensors|1024"
  "liveportrait-motion-extractor|https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/motion_extractor.safetensors|liveportrait|motion_extractor.safetensors|95719040"
  "liveportrait-spade|https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/spade_generator.safetensors|liveportrait|spade_generator.safetensors|204994552"
  "liveportrait-warping|https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/warping_module.safetensors|liveportrait|warping_module.safetensors|165381348"
  "liveportrait-stitching|https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/stitching_retargeting_module.safetensors|liveportrait|stitching_retargeting_module.safetensors|1024"
  "liveportrait-landmark|https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/landmark.onnx|liveportrait|landmark.onnx|97889275"
  # ----- FollowYourEmoji (3) -----
  "followyouremoji-unet|https://huggingface.co/Kijai/FollowYourEmoji-safetensors/resolve/main/FYE_unet-fp16.safetensors|followyouremoji|FYE_unet-fp16.safetensors|2577038036"
  "followyouremoji-refnet|https://huggingface.co/Kijai/FollowYourEmoji-safetensors/resolve/main/FYE_referencenet-fp16.safetensors|followyouremoji|FYE_referencenet-fp16.safetensors|1681673885"
  "followyouremoji-motion|https://huggingface.co/Kijai/FollowYourEmoji-safetensors/resolve/main/fye_motion_module-fp16.safetensors|followyouremoji|fye_motion_module-fp16.safetensors|890751103"
  # ----- MimicMotion (2) -----
  "mimicmotion-fp16|https://huggingface.co/Kijai/MimicMotion_pruned/resolve/main/MimicMotion-fp16.safetensors|mimicmotion|MimicMotion-fp16.safetensors|2988858769"
  "mimicmotion-merged-v11|https://huggingface.co/Kijai/MimicMotion_pruned/resolve/main/MimicMotionMergedUnet_1-1-fp16.safetensors|mimicmotion|MimicMotionMergedUnet_1-1-fp16.safetensors|2988447151"
  # ----- ControlNet (7) -----
  "sd15-cn-depth|https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11f1p_sd15_depth_fp16.safetensors|controlnet|control_v11f1p_sd15_depth_fp16.safetensors|705823884"
  "sd15-cn-openpose|https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors|controlnet|control_v11p_sd15_openpose_fp16.safetensors|705823884"
  "sd15-cn-canny|https://huggingface.co/lllyasviel/sd-controlnet-canny/resolve/main/diffusion_pytorch_model.safetensors|controlnet|control_sd15_canny.safetensors|1416253982"
  "sd15-cn-lineart|https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_lineart_fp16.safetensors|controlnet|control_v11p_sd15_lineart_fp16.safetensors|705823884"
  "sd15-cn-softedge|https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_softedge_fp16.safetensors|controlnet|control_v11p_sd15_softedge_fp16.safetensors|705823884"
  "sd15-cn-tile|https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11f1e_sd15_tile_fp16.safetensors|controlnet|control_v11f1e_sd15_tile_fp16.safetensors|705823888"
  "sd15-cn-lineart-anime|https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15s2_lineart_anime_fp16.safetensors|controlnet|control_v11p_sd15s2_lineart_anime_fp16.safetensors|705823884"
  # ----- IPAdapter (4) -----
  "ipadapter-plus-sd15|https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors|ipadapter|ip-adapter-plus_sd15.safetensors|81406072"
  "ipadapter-plus-face-sd15|https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus-face_sd15.safetensors|ipadapter|ip-adapter-plus-face_sd15.safetensors|81406072"
  "ipadapter-plus-sdxl|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors|ipadapter|ip-adapter-plus_sdxl_vit-h.safetensors|830567162"
  "ipadapter-faceid-plusv2-sd15|https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sd15.bin|ipadapter|ip-adapter-faceid-plusv2_sd15.bin|139781293"
  # ----- SAM (3) -----
  "sam2-1-large-safetensors|https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_large.safetensors|sams|sam2.1_hiera_large.safetensors|879935932"
  "sam2-1-base-plus|https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_base_plus.safetensors|sams|sam2.1_hiera_base_plus.safetensors|306697104"
  "sam2-1-small|https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_small.safetensors|sams|sam2.1_hiera_small.safetensors|167526656"
  # ----- Annotator (8) -----
  "dwpose-onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384.onnx|controlnet_aux|dw-ll_ucoco_384.onnx|117621900"
  "dwpose-yolox|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx|controlnet_aux|yolox_l.onnx|199969517"
  "openpose-body|https://huggingface.co/lllyasviel/Annotators/resolve/main/body_pose_model.pth|controlnet_aux|body_pose_model.pth|192490379"
  "openpose-hand|https://huggingface.co/lllyasviel/Annotators/resolve/main/hand_pose_model.pth|controlnet_aux|hand_pose_model.pth|130563833"
  "openpose-face|https://huggingface.co/lllyasviel/Annotators/resolve/main/facenet.pth|controlnet_aux|facenet.pth|136941576"
  "midas-depth|https://huggingface.co/lllyasviel/Annotators/resolve/main/dpt_hybrid-midas-501f0c75.pt|controlnet_aux|dpt_hybrid-midas-501f0c75.pt|475980575"
  "zoe-depth|https://huggingface.co/lllyasviel/Annotators/resolve/main/ZoeD_M12_N.pt|controlnet_aux|ZoeD_M12_N.pt|1414537978"
  "vitpose-h|https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin|controlnet_aux|vitpose_h_wholebody_data.bin|2497979566"
  # ----- DepthAnything (2) -----
  "depth-anything-v2-vitb|https://huggingface.co/depth-anything/Depth-Anything-V2-Base/resolve/main/depth_anything_v2_vitb.pth|depthanything|depth_anything_v2_vitb.pth|373184002"
  "depth-anything-v2-vits|https://huggingface.co/depth-anything/Depth-Anything-V2-Small/resolve/main/depth_anything_v2_vits.pth|depthanything|depth_anything_v2_vits.pth|82441218"
  # ----- DepthFM (1) -----
  "depthfm|https://huggingface.co/Kijai/depth-fm-pruned/resolve/main/depthfm-v1_fp16.safetensors|depthanything|depthfm-v1_fp16.safetensors|1697927340"
  # ----- Lotus (1) -----
  "lotus-depth|https://huggingface.co/Kijai/lotus-comfyui/resolve/main/lotus-depth-g-v2-1-disparity-fp16.safetensors|depthanything|lotus-depth-g-v2-1-disparity-fp16.safetensors|1700515992"
  # ----- MMAudio (4) -----
  "mmaudio-large-v2-fp16|https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/mmaudio_large_44k_v2_fp16.safetensors|mmaudio|mmaudio_large_44k_v2_fp16.safetensors|2019974456"
  "mmaudio-vae-44k-fp16|https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/mmaudio_vae_44k_fp16.safetensors|mmaudio|mmaudio_vae_44k_fp16.safetensors|594188844"
  "mmaudio-synchformer-fp16|https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/mmaudio_synchformer_fp16.safetensors|mmaudio|mmaudio_synchformer_fp16.safetensors|458203882"
  "mmaudio-clip-vit-h|https://huggingface.co/Kijai/MMAudio_safetensors/resolve/main/apple_DFN5B-CLIP-ViT-H-14-384_fp16.safetensors|mmaudio|apple_DFN5B-CLIP-ViT-H-14-384_fp16.safetensors|1934039261"
  # ----- BiRefNet (4) -----
  "birefnet-general|https://huggingface.co/ZhengPeng7/BiRefNet/resolve/main/model.safetensors|birefnet|BiRefNet_general.safetensors|427696380"
  "birefnet-portrait|https://huggingface.co/ZhengPeng7/BiRefNet-portrait/resolve/main/model.safetensors|birefnet|BiRefNet_portrait.safetensors|867181279"
  "birefnet-lite|https://huggingface.co/ZhengPeng7/BiRefNet_lite/resolve/main/model.safetensors|birefnet|BiRefNet_lite.safetensors|160857176"
  "rmbg-14|https://huggingface.co/briaai/RMBG-1.4/resolve/main/model.safetensors|rembg|RMBG-1.4.safetensors|159604768"
  # ----- SUPIR (2) -----
  "supir-v0q|https://huggingface.co/Kijai/SUPIR_pruned/resolve/main/SUPIR-v0Q_fp16.safetensors|upscale_models|SUPIR-v0Q_fp16.safetensors|2611561295"
  "ccsr|https://huggingface.co/Kijai/ccsr-safetensors/resolve/main/real-world_ccsr-fp16.safetensors|upscale_models|real-world_ccsr-fp16.safetensors|3368310661"
  # ----- BrushNet (1) -----
  "brushnet-powerpaint|https://huggingface.co/Kijai/BrushNet-fp16/resolve/main/powerpaint_v2_brushnet_fp16.safetensors|inpaint|powerpaint_v2_brushnet_fp16.safetensors|1736783174"
  # ----- GIMM-VFI (2) -----
  "gimm-vfi|https://huggingface.co/Kijai/GIMM-VFI_safetensors/resolve/main/gimmvfi_f_arb_lpips_fp32.safetensors|interpolation|gimmvfi_f_arb_lpips_fp32.safetensors|105855152"
  "gimm-vfi-flow|https://huggingface.co/Kijai/GIMM-VFI_safetensors/resolve/main/flowformer_sintel_fp32.safetensors|interpolation|flowformer_sintel_fp32.safetensors|48154884"
  # ----- SpatialTracker (1) -----
  "spatial-tracker|https://huggingface.co/Kijai/SpatialTracer/resolve/main/spaT_final_fp32.safetensors|spatialtracker|spaT_final_fp32.safetensors|119404940"
  # ----- VEnhancer (1) -----
  "venhancer|https://huggingface.co/Kijai/VEnhancer-fp16/resolve/main/venhancer_v2-fp16.safetensors|venhancer|venhancer_v2-fp16.safetensors|4008091605"
  # ----- Framer (1) -----
  "framer-unet|https://huggingface.co/Kijai/Framer_comfy/resolve/main/Framer_unet_fp16.safetensors|framer|Framer_unet_fp16.safetensors|2988452890"
  # ----- shared (4) -----
  "t5xxl-fp16|https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/split_files/text_encoders/t5xxl_fp16.safetensors|text_encoders|t5xxl_fp16.safetensors|9592084204"
  "t5xxl-fp8|https://huggingface.co/Comfy-Org/mochi_preview_repackaged/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors|text_encoders|t5xxl_fp8_e4m3fn_scaled.safetensors|5054201715"
  "clip-vision-h-laion-safetensors|https://huggingface.co/Comfy-Org/CLIP-ViT-H-14-laion2B-s32B-b79K_repackaged/resolve/main/split_files/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors|clip_vision|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors|2477805980"
  "sigclip-vision-384|https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors|clip_vision|sigclip_vision_patch14_384.safetensors|839375528"
)

# =============================================================================
# Recipes:命名套餐,展開成多個 tag。
# 格式:declare -A RECIPES; RECIPES[name]="tag1 tag2 ..."
# =============================================================================
declare -A RECIPES=(
  # 既有 10 個
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

  # 2026-Q4 新增 8 個 (純既有 tag,不依賴新模型)
  [wan22-s2v-talking-head]="14b-s2v 14b-fast wan21-vae"
  [wan22-chrono-edit]="chrono-edit wan21-vae"
  [wan22-fun-control]="14b-fun-control 14b-fast wan21-vae"
  [wan22-fun-inpaint-fflf]="14b-fun-inpaint 14b-fast wan21-vae"
  [wan22-fun-camera]="14b-fun-camera 14b-fast wan21-vae"
  [wan22-fun-vace]="14b-fun-vace 14b-fast wan21-vae"
  [wan22-5b-upscale-interp]="5b 5b-fast-fastwan upscale-realesrgan-x4 upscale-realesrgan-x2 interp-rife-426"
  [wan22-i2v-face-restore]="14b-i2v 14b-fast face-gfpgan face-codeformer face-detect face-parsing upscale-ultrasharp interp-rife-426"

  # 2026-Q4 新增 6 個 (用到新增的 tag)
  [wan22-t2v-fast-seko-v2]="14b-t2v 14b-fast-seko-v20 interp-rife-426"
  [wan22-i2v-lightx2v-260412]="14b-i2v 14b-fast-lightx2v-i2v-260412 interp-rife-426 upscale-ultrasharp"
  [wan22-blackwell-nvfp4]="14b-t2v-nvfp4-sparse 14b-i2v-nvfp4-sparse 14b-fast interp-rife-426"
  [wan22-ovi-i2v-audio]="5b-ovi-video ovi-mmaudio-vae ovi-mmaudio-vocoder umt5-bf16-kijai"
  [wan22-fun-control-pose-depth-kijai]="14b-fun-control-kijai depth-anything-v2-vitl 14b-fast wan21-vae umt5-bf16-kijai"
  [wan21-infinitetalk-i2v]="infinitetalk-single wav2vec2-chinese melband-roformer 14b-fast-lightx2v-i2v-v1022 clip-vision wan21-vae umt5-bf16-kijai"
  # ============================================================================
  # === 2026-Q2 多家族 recipe (38 family × 各自常用組合)
  # ============================================================================
  [ltx-video-097-fp8]="ltx-video-13b-097-dev-fp8 ltx-vae ltx-spatial-upscaler-097 t5xxl-fp8"
  [ltx-video-097-distilled]="ltx-video-13b-097-distilled-fp8 ltx-vae ltx-spatial-upscaler-097 t5xxl-fp8"
  [ltx-video-23-distilled]="ltx-2-3-22b-distilled-fp8 ltx-2-3-video-vae ltx-2-3-text-projection ltx-2-gemma3-fp8"
  [ltx-video-096-gguf-lowvram]="ltx-video-0-9-6-dev-gguf-q4 ltx-vae t5xxl-fp8"
  [hunyuan-t2v-basic]="hunyuan-video-t2v-bf16 hunyuan-vae hunyuan-clip-l hunyuan-llava-fp8"
  [hunyuan-t2v-fast]="hunyuan-video-t2v-fp8 hunyuan-vae hunyuan-clip-l hunyuan-llava-fp8 hunyuan-fastvideo-lora"
  [hunyuan-i2v-fast]="hunyuan-video-i2v-fp8 hunyuan-vae hunyuan-clip-l hunyuan-llava-fp8 hunyuan-llava-vision hunyuan-accvid-lora"
  [hunyuan-foley]="hunyuan-foley hunyuan-foley-synchformer hunyuan-foley-vae"
  [hunyuan15-i2v-fast]="hunyuanvideo15-i2v-fp8 hunyuanvideo15-vae hunyuanvideo15-qwen25vl-fp8 hunyuanvideo15-lightx2v-lora"
  [hunyuan15-t2v-fast]="hunyuanvideo15-t2v-fp8 hunyuanvideo15-vae hunyuanvideo15-qwen25vl-fp8 hunyuanvideo15-lightx2v-lora"
  [hunyuan-gguf-lowvram]="hunyuan-video-t2v-gguf-q4 hunyuan-vae hunyuan-clip-l hunyuan-llava-fp8"
  [framepack-i2v]="framepack-i2v-hy-fp8 hunyuan-vae hunyuan-clip-l hunyuan-llava-fp8 hunyuan-llava-vision"
  [mochi-basic]="mochi-preview-fp8 mochi-vae t5xxl-fp8"
  [mochi-quality]="mochi-preview-bf16 mochi-vae t5xxl-fp16"
  [cogvideox-15-i2v]="cogvideox-1-5-5b-i2v cogvideox-vae t5xxl-fp8"
  [cogvideox-15-t2v]="cogvideox-1-5-5b-t2v cogvideox-vae t5xxl-fp8"
  [cogvideox-fun-control]="cogvideox-fun-1-1-5b-control-fp8 cogvideox-vae t5xxl-fp8"
  [svd-basic]="svd-xt clip-vision-h-laion-safetensors"
  [svd-animatelcm]="animatelcm-svd-xt clip-vision-h-laion-safetensors"
  [animatediff-v3]="animatediff-v3-mm animatediff-v3-adapter"
  [animatediff-v2-camera]="animatediff-mm-v2 animatediff-motion-lora-zoom-in animatediff-motion-lora-zoom-out animatediff-motion-lora-pan-left animatediff-motion-lora-pan-right animatediff-motion-lora-tilt-up animatediff-motion-lora-tilt-down animatediff-motion-lora-rolling-cw animatediff-motion-lora-rolling-ccw"
  [animatediff-sparsectrl]="animatediff-v3-mm animatediff-sparsectrl-rgb animatediff-sparsectrl-scribble"
  [animatediff-lcm]="animatelcm-mm animatelcm-lora"
  [animatediff-magictime]="magictime-mm animatediff-v3-mm"
  [cosmos-predict2-14b]="cosmos-predict2-14b-720p t5xxl-fp16"
  [skyreels-v1-hy-i2v]="skyreels-v1-hunyuan-i2v-fp8 hunyuan-vae hunyuan-clip-l hunyuan-llava-fp8 hunyuan-llava-vision"
  [skyreels-v2-540p]="skyreels-v2-i2v-14b-540p-gguf skyreels-v2-t2v-14b-540p-gguf"
  [sonic-talking-head]="sonic-unet sonic-audio2bucket sonic-audio2token sonic-yoloface sonic-rife svd-xt"
  [hallo-talking-head]="hallo-net hallo-wav2vec animatediff-mm-v2"
  [hallo2-long-talking]="hallo2-net hallo2-net-g hallo-wav2vec animatediff-mm-v2"
  [echomimic-v1]="echomimic-denoising echomimic-reference echomimic-motion echomimic-face-locator"
  [echomimic-v2-halfbody]="echomimicv2-denoising echomimicv2-reference echomimicv2-motion echomimicv2-pose"
  [magicanimate-pose]="magicanimate-appearance magicanimate-densepose-cnet magicanimate-temporal"
  [musepose-character]="musepose-denoising musepose-motion musepose-pose-guider musepose-reference"
  [animateanyone]="animateanyone-denoising animateanyone-reference animateanyone-motion animateanyone-pose-guider"
  [champ-multimodal]="champ-denoising champ-reference champ-motion champ-guide-dwpose champ-guide-depth"
  [vexpress-audio-portrait]="vexpress-denoising vexpress-motion vexpress-reference vexpress-audio-proj vexpress-kps-guider"
  [liveportrait]="liveportrait-appearance liveportrait-motion-extractor liveportrait-spade liveportrait-warping liveportrait-stitching liveportrait-landmark"
  [followyouremoji]="followyouremoji-unet followyouremoji-refnet followyouremoji-motion"
  [mimicmotion-v11]="mimicmotion-merged-v11 svd-xt"
  [controlnet-sd15-basic]="sd15-cn-depth sd15-cn-openpose sd15-cn-canny sd15-cn-softedge sd15-cn-tile"
  [ipadapter-sd15]="ipadapter-plus-sd15 ipadapter-plus-face-sd15 ipadapter-faceid-plusv2-sd15 clip-vision-h-laion-safetensors"
  [sam2-segmentation]="sam2-1-large-safetensors sam2-1-base-plus sam2-1-small"
  [dwpose-detect]="dwpose-onnx dwpose-yolox openpose-body openpose-hand openpose-face"
  [depth-suite]="depth-anything-v2-vitb depth-anything-v2-vits depthfm lotus-depth midas-depth zoe-depth"
  [mmaudio-v2a]="mmaudio-large-v2-fp16 mmaudio-vae-44k-fp16 mmaudio-synchformer-fp16 mmaudio-clip-vit-h"
  [bg-removal]="birefnet-general birefnet-portrait birefnet-lite rmbg-14"
  [video-restore-upscale]="supir-v0q ccsr venhancer"
  [frame-interp-gimm]="gimm-vfi gimm-vfi-flow"
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
          face-gfpgan face-codeformer face-restoreformer face-detect face-parsing
          # 2026-Q4 新增
          14b-fast-seko-v20 14b-fast-lightx2v-i2v-260412
          14b-t2v-nvfp4-sparse 14b-i2v-nvfp4-sparse
          5b-ovi-video ovi-mmaudio-vae ovi-mmaudio-vocoder
          14b-fun-control-kijai depth-anything-v2-vitl
          infinitetalk-single infinitetalk-multi wav2vec2-chinese melband-roformer
          umt5-bf16-kijai 14b-s2v-kijai longcat-avatar-single
          # 2026-Q2 多家族擴充 (180 個檔案 / 38 個 family)
          animateanyone-denoising animateanyone-motion animateanyone-pose-guider
          animateanyone-reference animatediff-mm-v2 animatediff-motion-lora-pan-left
          animatediff-motion-lora-pan-right animatediff-motion-lora-rolling-ccw
          animatediff-motion-lora-rolling-cw animatediff-motion-lora-tilt-down
          animatediff-motion-lora-tilt-up animatediff-motion-lora-zoom-in
          animatediff-motion-lora-zoom-out animatediff-sdxl-beta animatediff-sparsectrl-rgb
          animatediff-sparsectrl-scribble animatediff-v3-adapter animatediff-v3-mm
          animatelcm-lora animatelcm-mm animatelcm-svd-xt birefnet-general birefnet-lite
          birefnet-portrait brushnet-powerpaint ccsr champ-denoising champ-guide-depth
          champ-guide-dwpose champ-motion champ-reference clip-vision-h-laion-safetensors
          cogvideox-1-0-5b-i2v cogvideox-1-5-5b-i2v cogvideox-1-5-5b-t2v
          cogvideox-fun-1-1-5b-control-fp8 cogvideox-vae controlnext-svd controlnext-svd-cnet
          cosmos-predict2-14b-720p cosmos-predict2-2b-720p cosmos1-7b-video2world
          depth-anything-v2-vitb depth-anything-v2-vits depthfm dwpose-onnx dwpose-yolox
          dynamicrafter-1024 echomimic-denoising echomimic-face-locator echomimic-motion
          echomimic-reference echomimicv2-denoising echomimicv2-motion echomimicv2-pose
          echomimicv2-reference fast-hunyuan-video-gguf-q4 followyouremoji-motion
          followyouremoji-refnet followyouremoji-unet framepack-i2v-hy-fp8 framer-unet
          gimm-vfi gimm-vfi-flow hallo-net hallo-wav2vec hallo2-net hallo2-net-g
          hunyuan-accvid-lora hunyuan-clip-l hunyuan-fastvideo-lora hunyuan-foley
          hunyuan-foley-synchformer hunyuan-foley-vae hunyuan-llava-fp8 hunyuan-llava-vision
          hunyuan-vae hunyuan-video-i2v-bf16 hunyuan-video-i2v-fp8 hunyuan-video-i2v-gguf-q4
          hunyuan-video-t2v-bf16 hunyuan-video-t2v-fp8 hunyuan-video-t2v-gguf-q4
          hunyuan-video-t2v-gguf-q6 hunyuanvideo15-i2v-fp8 hunyuanvideo15-lightx2v-lora
          hunyuanvideo15-qwen25vl-fp8 hunyuanvideo15-t2v-fp8 hunyuanvideo15-vae
          ipadapter-faceid-plusv2-sd15 ipadapter-plus-face-sd15 ipadapter-plus-sd15
          ipadapter-plus-sdxl kandinsky5-pro-i2v-fp8 kandinsky5-pro-t2v-fp8
          liveportrait-appearance liveportrait-landmark liveportrait-motion-extractor
          liveportrait-spade liveportrait-stitching liveportrait-warping lotus-depth
          ltx-2-3-22b-distilled-fp8 ltx-2-3-text-projection ltx-2-3-video-vae ltx-2-gemma3-fp8
          ltx-lora-cakeify ltx-lora-squish ltx-spatial-upscaler-097 ltx-temporal-upscaler-097
          ltx-vae ltx-video-0-9-6-dev-gguf-q4 ltx-video-0-9-6-dev-gguf-q6
          ltx-video-0-9-6-distilled-gguf-q4 ltx-video-13b-097-dev ltx-video-13b-097-dev-fp8
          ltx-video-13b-097-distilled ltx-video-13b-097-distilled-fp8
          ltx-video-13b-097-distilled-lora magicanimate-appearance magicanimate-densepose-cnet
          magicanimate-temporal magictime-mm midas-depth mimicmotion-fp16
          mimicmotion-merged-v11 mmaudio-clip-vit-h mmaudio-large-v2-fp16
          mmaudio-synchformer-fp16 mmaudio-vae-44k-fp16 mochi-preview-bf16 mochi-preview-fp8
          mochi-vae musepose-denoising musepose-motion musepose-pose-guider musepose-reference
          openpose-body openpose-face openpose-hand pyramid-flow-miniflux-768-fp8
          pyramid-flow-miniflux-fp8 pyramid-flow-vae rmbg-14 sam2-1-base-plus
          sam2-1-large-safetensors sam2-1-small sd15-cn-canny sd15-cn-depth sd15-cn-lineart
          sd15-cn-lineart-anime sd15-cn-openpose sd15-cn-softedge sd15-cn-tile
          sigclip-vision-384 skyreels-v1-hunyuan-i2v-fp8 skyreels-v1-hunyuan-t2v-fp8
          skyreels-v2-df-14b-540p-gguf skyreels-v2-i2v-14b-540p-gguf
          skyreels-v2-t2v-14b-540p-gguf sonic-audio2bucket sonic-audio2token sonic-rife
          sonic-unet sonic-yoloface spatial-tracker supir-v0q svd svd-xt t5xxl-fp16 t5xxl-fp8
          tooncrafter-512-interp venhancer vexpress-audio-proj vexpress-denoising
          vexpress-kps-guider vexpress-motion vexpress-reference vitpose-h zoe-depth)

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
mkdir -p "$MODELS_DIR"/{diffusion_models,text_encoders,vae,loras,clip_vision,audio_encoders,upscale_models,interpolation,facerestore_models,facedetection,depthanything,wav2vec2,checkpoints,controlnet,controlnet_aux,ipadapter,sams,mmaudio,birefnet,rembg,unet_gguf,inpaint,sonic,hallo,echomimic,magicanimate,musepose,animateanyone,champ,vexpress,liveportrait,followyouremoji,mimicmotion,controlnext,framer,spatialtracker,venhancer,animatediff_models,animatediff_motion_lora}

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
for d in "$MODELS_DIR"/*/; do
  d="${d%/}"; name="${d##*/}"
  if [[ -n "$(ls -A "$d" 2>/dev/null)" ]]; then
    echo "   $d/"
    # shellcheck disable=SC2012
    ls -lh "$d" 2>/dev/null | awk 'NR>1 && $9!~/^\./{printf "      %8s  %s\n", $5, $9}'
  fi
done
echo
echo "下一步:./start.sh  → 瀏覽器開 http://127.0.0.1:8188"
echo "       Workflow → Browse Templates → Video → 選對應的 Wan2.2 範本"
