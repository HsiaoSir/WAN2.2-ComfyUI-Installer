#!/usr/bin/env bash
# =============================================================================
# 啟動 ComfyUI (Wan2.2-TI2V-5B)
# -----------------------------------------------------------------------------
# 用法:
#   ./start.sh                 # 一般啟動 (12GB VRAM 建議,自動 offload)
#   ./start.sh --lowvram       # VRAM 吃緊時 (8GB 左右)
#   ./start.sh --novram        # 幾乎全部丟 CPU/RAM (極省 VRAM,很慢)
#   ./start.sh --listen        # 開放區網其他機器連入 (0.0.0.0)
#   任何額外參數都會直接傳給 ComfyUI main.py
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="${COMFY_DIR:-$SCRIPT_DIR/ComfyUI}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/.venv}"
PORT="${PORT:-8188}"

[[ -f "$VENV_DIR/bin/activate" ]] || { echo "找不到 venv,請先執行 ./install.sh"; exit 1; }
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "==> 啟動 ComfyUI:http://127.0.0.1:${PORT}"
echo "    (Ctrl+C 結束)"
cd "$COMFY_DIR"
exec python main.py --port "$PORT" "$@"
