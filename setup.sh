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
DL_ARGS=()  # 額外的下載模型旗標,轉發給 download_models.sh
for a in "$@"; do
  case "$a" in
    --no-models) DO_MODELS=0 ;;
    --start)     DO_START=1 ;;
    --14b-*|--no-5b|--all|--everything|--chrono-edit|--textenc-fp16|--clip-vision|--wan21-vae|--rgba-lora)
                 DL_ARGS+=("$a") ;;
    -h|--help)
      echo "用法:./setup.sh [選項]"
      echo "  --no-models   只裝環境,不下載模型"
      echo "  --start       裝完直接啟動 ComfyUI"
      echo "  --14b-t2v / --14b-i2v / --14b-fast / --14b-animate / --14b-s2v / ..."
      echo "                轉發給 download_models.sh 的模型選項 (./download_models.sh --list 看全部)"
      echo "  --all         5B + 14B t2v + 14B i2v + 14B fast (綜合包)"
      echo "  --everything  全部變體 (>150GB,慎用)"
      exit 0 ;;
    *) echo "未知參數:$a (用 --help 看可用選項)"; exit 1 ;;
  esac
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
