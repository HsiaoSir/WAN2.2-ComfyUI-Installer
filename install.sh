#!/usr/bin/env bash
# =============================================================================
# ComfyUI + Wan2.2-TI2V-5B  通用安裝腳本 (Ubuntu / Intel CPU + NVIDIA RTX GPU)
# -----------------------------------------------------------------------------
# 特性:
#   * 可重複執行 (idempotent):每一步都先偵測,已安裝/已存在就略過
#   * 只補缺少的東西,不會重裝已完成的部分
#   * 不會自動安裝/變更 NVIDIA 驅動 (高風險,需重開機),只偵測並提示
#
# 用法:
#   chmod +x install.sh
#   ./install.sh                 # 完整安裝 (不含模型)
#   ./install.sh --with-models   # 安裝完順便下載模型
#
# 安裝完成後:
#   ./download_models.sh         # 下載 3 個模型檔
#   ./start.sh                   # 啟動 ComfyUI
# =============================================================================
set -euo pipefail

# ----------------------------- 可調整設定 -----------------------------------
# 安裝目錄 (預設:本腳本所在目錄底下的 ComfyUI)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="${COMFY_DIR:-$SCRIPT_DIR/ComfyUI}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/.venv}"

# PyTorch 的 CUDA 版本輪子。
#   cu128 = CUDA 12.8,支援 RTX 30/40/50 全系列 (Ampere/Ada/Blackwell),2026 推薦預設
#   若你的卡較舊或驅動較低,可改成 cu124 / cu121
TORCH_CUDA="${TORCH_CUDA:-cu128}"

# 偏好的 Python 版本。PyTorch cu128 目前已提供 3.10–3.14 的 x86_64 輪子
# (已實測 download.pytorch.org/whl/cu128 有 cp314 輪子),所以 Ubuntu 26.04
# 預設的 python3 (3.14) 也能直接用;這裡只是若系統剛好裝了多版本時的優先序。
PREFERRED_PYTHONS=("python3.12" "python3.13" "python3.14" "python3.11" "python3.10" "python3")

WITH_MODELS=0
[[ "${1:-}" == "--with-models" ]] && WITH_MODELS=1

# ----------------------------- 輸出小工具 -----------------------------------
c_reset=$'\e[0m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_red=$'\e[31m'; c_blu=$'\e[36m'
info() { echo "${c_blu}==>${c_reset} $*"; }
ok()   { echo "${c_grn}  ✓${c_reset} $*"; }
skip() { echo "${c_grn}  ✓ 已存在,略過:${c_reset} $*"; }
add()  { echo "${c_yel}  ⬇ 安裝中:${c_reset} $*"; }
warn() { echo "${c_yel}  ! ${c_reset}$*"; }
die()  { echo "${c_red}✗ 錯誤:${c_reset} $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# 步驟 0:環境檢查
# =============================================================================
info "步驟 0/7:檢查作業系統環境"
[[ "$(uname -s)" == "Linux" ]] || die "這個腳本只能在 Linux (Ubuntu) 上執行。"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|aarch64) : ;;
  *) warn "未測過的 CPU 架構:$ARCH (本腳本在 x86_64 與 aarch64 已驗證)" ;;
esac
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  ok "OS: ${PRETTY_NAME:-unknown} | 架構: $ARCH"
  [[ "${ID:-}" == "ubuntu" ]] || warn "偵測到非 Ubuntu 發行版 (${ID:-?}),腳本仍會嘗試執行。"
  case "${VERSION_ID:-}" in
    22.04|24.04|26.04) ok "Ubuntu $VERSION_ID 在本腳本已驗證可用(amd64 容器測過)。" ;;
    "") warn "讀不到 VERSION_ID,可能不是標準 Ubuntu。" ;;
    *)  warn "未在容器測過 Ubuntu $VERSION_ID,理論上應該也能跑。" ;;
  esac
fi
have sudo || die "找不到 sudo,請先安裝或以具備權限的帳號執行。"

# =============================================================================
# 步驟 1:系統套件 (只裝缺少的)
# =============================================================================
info "步驟 1/7:檢查系統套件"
REQUIRED_PKGS=(git wget curl ca-certificates build-essential
               python3-venv python3-dev python3-pip
               ffmpeg libgl1 libglib2.0-0 aria2)
# 判斷套件是否已安裝。處理 Ubuntu 24.04/26.04 的 t64 改名 (e.g. libglib2.0-0 → libglib2.0-0t64)
# 與「以 Provides 滿足」的情況,避免每次重跑都顯示假性「在裝中」。
pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1 && return 0
  dpkg -s "${1}t64" >/dev/null 2>&1 && return 0     # 直接試 t64 後綴版
  # apt 模擬安裝:若無新增/升級,代表已被 Provides 滿足
  apt-get install -s "$1" 2>/dev/null | grep -qE "^0 (upgraded|newly installed)," && return 0
  return 1
}
MISSING_PKGS=()
for p in "${REQUIRED_PKGS[@]}"; do
  if pkg_installed "$p"; then
    skip "$p"
  else
    MISSING_PKGS+=("$p")
  fi
done
if (( ${#MISSING_PKGS[@]} )); then
  # 用 noninteractive 前端,避免某些套件 (tzdata, libc6-dev 等) 跳出 debconf 對話框卡死
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt-get update -y
  # 逐一確認在此 Ubuntu 版本「真的裝得起來」。
  # 例:Ubuntu 24.04/26.04 把 libglib2.0-0 改名為 libglib2.0-0t64 (time_t 轉換),
  # 舊名仍可經由「虛擬套件 Provides」安裝,但若哪天某個名稱真的消失,
  # 這裡會警告並略過該套件,而不是讓整個安裝中斷。
  INSTALL_PKGS=()
  for p in "${MISSING_PKGS[@]}"; do
    if apt-get install -s "$p" >/dev/null 2>&1; then
      INSTALL_PKGS+=("$p")
    else
      warn "套件 '$p' 在此 Ubuntu 版本找不到可安裝候選,略過 (可能已改名)。"
    fi
  done
  if (( ${#INSTALL_PKGS[@]} )); then
    add "${INSTALL_PKGS[*]}"
    sudo -E apt-get install -y "${INSTALL_PKGS[@]}"
  else
    ok "沒有可安裝的缺漏套件"
  fi
else
  ok "系統套件齊全"
fi

# =============================================================================
# 步驟 2:NVIDIA 驅動 / CUDA 偵測 (只偵測,不自動安裝)
# =============================================================================
info "步驟 2/7:檢查 NVIDIA GPU 驅動"
if have nvidia-smi && nvidia-smi >/dev/null 2>&1; then
  GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)"
  GPU_MEM="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -n1)"
  DRV_VER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
  ok "GPU: ${GPU_NAME} | VRAM: ${GPU_MEM} | Driver: ${DRV_VER}"
else
  warn "偵測不到 nvidia-smi / NVIDIA 驅動。"
  warn "請先安裝驅動再重跑本腳本 (需要重開機):"
  warn "    sudo ubuntu-drivers autoinstall   # 自動挑選建議驅動"
  warn "    sudo reboot"
  warn "PyTorch 仍會安裝,但沒有驅動就無法用 GPU 推論。"
fi

# =============================================================================
# 步驟 3:挑選 Python 直譯器
# =============================================================================
info "步驟 3/7:選擇 Python 直譯器"
PYBIN=""
for cand in "${PREFERRED_PYTHONS[@]}"; do
  if have "$cand"; then PYBIN="$(command -v "$cand")"; break; fi
done
[[ -n "$PYBIN" ]] || die "找不到任何 python3,請先安裝 python3.12。"
PYVER="$("$PYBIN" -c 'import sys;print("%d.%d"%sys.version_info[:2])')"
ok "使用 Python: $PYBIN (版本 $PYVER)"
case "$PYVER" in
  3.10|3.11|3.12|3.13|3.14) : ;;   # PyTorch cu128 皆有對應輪子 (含 Ubuntu 26.04 的 3.14)
  *) warn "Python $PYVER 較少見,PyTorch cu128 不一定有對應輪子。"
     warn "若稍後 torch 安裝失敗,請改裝 3.10–3.14 任一版本,例如:"
     warn "    sudo apt install python3.12 python3.12-venv   # 然後重跑本腳本";;
esac

# =============================================================================
# 步驟 4:取得 ComfyUI 原始碼 (有就更新,沒有就 clone)
# =============================================================================
info "步驟 4/7:取得 ComfyUI"
if [[ -d "$COMFY_DIR/.git" ]]; then
  skip "ComfyUI 已存在於 $COMFY_DIR (執行 git pull 更新)"
  git -C "$COMFY_DIR" pull --ff-only || warn "git pull 失敗,沿用現有版本。"
else
  add "git clone ComfyUI 到 $COMFY_DIR"
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
fi

# =============================================================================
# 步驟 5:建立 / 重用 Python 虛擬環境
# =============================================================================
info "步驟 5/7:Python 虛擬環境 (venv)"
# 健康檢查:只看 bin/activate 不夠 — 必須能實際執行 python (避免半毀的 venv 永久卡住)
venv_healthy() {
  local v="$1"
  [[ -f "$v/bin/activate" ]] || return 1
  [[ -x "$v/bin/python" || -x "$v/bin/python3" ]] || return 1
  "$v/bin/python" -c 'import sys' >/dev/null 2>&1 || return 1
  return 0
}
if venv_healthy "$VENV_DIR"; then
  skip "venv 已存在於 $VENV_DIR"
else
  if [[ -d "$VENV_DIR" ]]; then
    warn "$VENV_DIR 半毀(沒有可執行的 python),刪除重建。"
    rm -rf "$VENV_DIR"
  fi
  add "建立 venv 於 $VENV_DIR"
  "$PYBIN" -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --quiet --upgrade pip wheel setuptools
ok "venv 已啟用 ($(python --version))"

# =============================================================================
# 步驟 6:安裝 PyTorch (已是「正確 CUDA 版本」才略過)
# =============================================================================
info "步驟 6/7:PyTorch (CUDA=$TORCH_CUDA)"
# 從 cuXXY 推導出 MAJOR.MINOR (cu128 → 12.8, cu124 → 12.4, cu121 → 12.1)
CUDA_TAG="${TORCH_CUDA#cu}"
EXPECTED_CUDA="${CUDA_TAG:0:$((${#CUDA_TAG}-1))}.${CUDA_TAG: -1}"
# 判斷:已裝、且 torch.version.cuda 開頭符合 EXPECTED_CUDA (不只看「有 CUDA 版本」,
# 還要看版本對不對 — 避免舊環境的 cu121 殘留被當成 OK 跳過)。
if python -c "import torch,sys; v=torch.version.cuda or ''; sys.exit(0 if v.startswith('$EXPECTED_CUDA') else 1)" 2>/dev/null; then
  TVER="$(python -c 'import torch;print(torch.__version__)')"
  TCU="$(python -c 'import torch;print(torch.version.cuda)')"
  skip "PyTorch 已安裝且 CUDA 版本相符 (torch $TVER, CUDA $TCU)"
else
  # 若已有 torch 但 CUDA 版本不符,先卸載再裝
  if python -c "import torch" 2>/dev/null; then
    EXISTING="$(python -c 'import torch;print(torch.version.cuda)' 2>/dev/null || echo None)"
    warn "偵測到 torch 但 CUDA 版本不符(預期 $EXPECTED_CUDA,實際 $EXISTING),重裝。"
    pip uninstall -y torch torchvision torchaudio >/dev/null 2>&1 || true
  fi
  add "安裝 torch / torchvision / torchaudio ($TORCH_CUDA)"
  pip install torch torchvision torchaudio \
      --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"
fi
# 安裝後做一次資訊性檢查 (有 GPU+驅動才會 True;沒驅動不算錯)
python -c "import torch;print('  torch', torch.__version__, '| CUDA build', torch.version.cuda, '| GPU 可用:', torch.cuda.is_available())" 2>/dev/null || true

# =============================================================================
# 步驟 7:安裝 ComfyUI 相依套件
# =============================================================================
info "步驟 7/7:ComfyUI 相依套件 (requirements.txt)"
pip install -r "$COMFY_DIR/requirements.txt"
ok "ComfyUI 相依套件就緒"

# 建好模型資料夾 (download_models.sh 會用到)
mkdir -p "$COMFY_DIR/models/diffusion_models" \
         "$COMFY_DIR/models/text_encoders" \
         "$COMFY_DIR/models/vae"

deactivate || true

echo
echo "${c_grn}========================================================${c_reset}"
echo "${c_grn} ✅ ComfyUI 安裝完成!${c_reset}"
echo "   安裝位置: $COMFY_DIR"
echo "   venv:     $VENV_DIR"
echo "${c_grn}========================================================${c_reset}"

if (( WITH_MODELS )); then
  info "接著下載模型 (--with-models)"
  bash "$SCRIPT_DIR/download_models.sh"
else
  echo "下一步:"
  echo "   ./download_models.sh    # 下載模型 (約 17GB)"
  echo "   ./start.sh              # 啟動 ComfyUI"
fi
