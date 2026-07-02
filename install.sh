#!/usr/bin/env bash
# mac 风格虚拟桌面 一键部署脚本（XFCE + X11，Debian/Kali 系）
# 效果：窗口最大化/全屏 -> 新建虚拟桌面并滑动切换；退出 -> 滑回桌面 1
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PICOM_REV="8f83eb5"   # 已验证可用的 pijulius/picom 版本

echo "==> [1/5] 安装依赖"
sudo apt-get install -y \
    wmctrl python3-xlib xfconf \
    git meson ninja-build cmake pkg-config uthash-dev \
    libev-dev libconfig-dev libpcre2-dev libdbus-1-dev libepoxy-dev \
    libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev \
    libxcb-damage0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev \
    libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev \
    libxcb-shape0-dev libxcb-sync-dev libxcb-util-dev libxcb-xfixes0-dev \
    libegl-dev libgl-dev libxext-dev

echo "==> [2/5] 编译 picom (pijulius 分支，带工作区滑动动画)"
SRC="$HERE/picom-pijulius"
if [ ! -d "$SRC" ]; then
    git clone https://github.com/pijulius/picom.git "$SRC"
    git -C "$SRC" checkout "$PICOM_REV" 2>/dev/null \
        || echo "    (提示: 固定版本 $PICOM_REV 不存在，使用最新版)"
fi
meson setup "$SRC/build" "$SRC" --buildtype=release --prefix="$HOME/.local" \
    >/dev/null
ninja -C "$SRC/build" install >/dev/null
echo "    已安装: $HOME/.local/bin/picom ($("$HOME/.local/bin/picom" --version))"

echo "==> [3/5] 安装守护脚本和配置"
install -Dm755 "$HERE/fullscreen-workspace.py" "$HOME/.local/bin/fullscreen-workspace.py"
install -Dm644 "$HERE/picom.conf" "$HOME/.config/picom.conf"

echo "==> [4/5] 配置开机自启"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/fullscreen-workspace.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Fullscreen Workspace
Comment=macOS-style: fullscreen windows get their own workspace
Exec=python3 $HOME/.local/bin/fullscreen-workspace.py
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
EOF
cat > "$HOME/.config/autostart/picom.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=picom
GenericName=X compositor
Comment=picom (pijulius fork) with workspace slide animations
TryExec=$HOME/.local/bin/picom
Exec=$HOME/.local/bin/picom
StartupNotify=false
Terminal=false
Icon=picom
EOF

echo "==> [5/5] 关闭 xfwm4 自带合成器并启动"
if [ -n "${DISPLAY:-}" ]; then
    xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s false \
        2>/dev/null || xfconf-query -c xfwm4 -p /general/use_compositing -s false
    pkill -f '^python3 .*/fullscreen-workspace.py' 2>/dev/null || true
    pkill -x picom 2>/dev/null || true
    sleep 1
    nohup python3 "$HOME/.local/bin/fullscreen-workspace.py" \
        >/dev/null 2>&1 & disown
    nohup "$HOME/.local/bin/picom" >/dev/null 2>&1 & disown
    echo "    已启动。最大化一个窗口试试！"
else
    echo "    (当前无图形会话，登录 XFCE 后自动生效)"
fi

echo "完成。"
