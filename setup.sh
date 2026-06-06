#!/usr/bin/env bash
# =============================================================================
# Wan2.2-TI2V-5B × ComfyUI 一鍵全自動安裝 (Ubuntu 24.04 / 26.04, Intel + RTX)
# -----------------------------------------------------------------------------
# 這支是「總入口」:依序執行 install.sh → download_models.sh,最後告訴你怎麼啟動。
# 全程可重複執行:已安裝的套件、已下載的模型都會自動略過。
#
# 用法:
#   chmod +x *.sh
#   ./setup.sh              # 安裝環境 + 下載模型 (最常用)
#   ./setup.sh --no-models  # 只裝環境,先不下載模型
#   ./setup.sh --start      # 安裝 + 下載 + 直接啟動 ComfyUI
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

c_grn=$'\e[32m'; c_blu=$'\e[36m'; c_reset=$'\e[0m'
step() { echo; echo "${c_blu}######################################################${c_reset}"; echo "${c_blu}# $*${c_reset}"; echo "${c_blu}######################################################${c_reset}"; }

DO_MODELS=1; DO_START=0
DL_ARGS=()  # 任何 setup.sh 不認得的旗標都會原封轉發給 download_models.sh
# 用 while + shift 才能正確處理 `--recipe NAME` 這種兩-token 形式
while (( $# )); do
  case "$1" in
    --no-models) DO_MODELS=0 ;;
    --start)     DO_START=1 ;;
    -h|--help)
      cat <<EOF
用法:./setup.sh [選項]
  --no-models       只裝環境,不下載模型
  --start           裝完直接啟動 ComfyUI

任何其他旗標都原樣轉發給 ./download_models.sh,例如:
  ./setup.sh --14b-t2v --14b-fast            # 5B + 14B T2V + 4-step LoRA
  ./setup.sh --recipe wan22-i2v-with-upscale # 一鍵裝整套工作流
  ./setup.sh --recipe wan22-5b-fast          # 5B + FastWan 4-step LoRA
  ./setup.sh --all                           # 5B + 14B t2v + 14B i2v + fast
  ./setup.sh --everything                    # 所有變體 (>150GB,慎用)
  ./setup.sh --no-5b                         # 只裝 14B,不抓 5B
  ./setup.sh --list                          # 列出所有可下載 tag (印完即退)
  ./setup.sh --list-recipes                  # 列出所有 recipe

完整旗標清單請看 ./download_models.sh --help
EOF
      exit 0 ;;
    # `--recipe NAME` 兩-token 形式:整對轉發
    --recipe)
      DL_ARGS+=("$1")
      shift
      [[ -n "${1:-}" ]] || { echo "✗ --recipe 需要一個值"; exit 1; }
      DL_ARGS+=("$1") ;;
    # 其他所有 -- 開頭的旗標一律轉發 (download_models.sh 自己會驗證合法性)
    --*) DL_ARGS+=("$1") ;;
    *) echo "✗ 未知參數:$1 (用 --help 看可用選項)"; exit 1 ;;
  esac
  shift
done

chmod +x install.sh download_models.sh start.sh 2>/dev/null || true

step "1/3 安裝 ComfyUI 環境 (install.sh)"
./install.sh

if (( DO_MODELS )); then
  step "2/3 下載 Wan2.2 模型 (download_models.sh ${DL_ARGS[*]})"
  ./download_models.sh "${DL_ARGS[@]}"
else
  echo "(已略過模型下載,之後可手動執行 ./download_models.sh)"
fi

step "3/3 完成"
echo "${c_grn}✅ 全部就緒!${c_reset}"
echo
echo "啟動 ComfyUI:"
echo "    ./start.sh"
echo "然後瀏覽器開:http://127.0.0.1:8188"
echo "載入工作流:Workflow → Browse Templates → Video → 「Wan2.2 5B」"
echo "參數/風格建議請看:風格與參數預設.md  與  安裝手冊.md"

if (( DO_START )); then
  step "啟動 ComfyUI (start.sh)"
  exec ./start.sh
fi
