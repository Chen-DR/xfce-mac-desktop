#!/usr/bin/env bash
# mac 风格虚拟桌面 一键部署脚本（XFCE + X11，Debian/Kali 系）
# 效果：窗口最大化/全屏 -> 新建虚拟桌面并滑动切换；退出 -> 滑回桌面 1
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PICOM_REV="8f83eb5"   # 已验证可用的 pijulius/picom 版本

echo "==> [1/6] 安装依赖"
sudo apt-get install -y \
    wmctrl python3-xlib xfconf xfce4-docklike-plugin \
    git meson ninja-build cmake pkg-config uthash-dev \
    libev-dev libconfig-dev libpcre2-dev libdbus-1-dev libepoxy-dev \
    libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev \
    libxcb-damage0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev \
    libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev \
    libxcb-shape0-dev libxcb-sync-dev libxcb-util-dev libxcb-xfixes0-dev \
    libegl-dev libgl-dev libxext-dev

echo "==> [2/6] 编译 picom (pijulius 分支，带工作区滑动动画)"
SRC="$HERE/picom-pijulius"
# 源码已随仓库内置（版本 $PICOM_REV）；目录缺失时才从上游克隆兜底
if [ ! -d "$SRC" ]; then
    git clone https://github.com/pijulius/picom.git "$SRC"
    git -C "$SRC" checkout "$PICOM_REV" 2>/dev/null \
        || echo "    (提示: 固定版本 $PICOM_REV 不存在，使用最新版)"
fi
rm -rf "$SRC/build"
meson setup "$SRC/build" "$SRC" --buildtype=release --prefix="$HOME/.local" \
    >/dev/null
ninja -C "$SRC/build" install >/dev/null
echo "    已安装: $HOME/.local/bin/picom ($("$HOME/.local/bin/picom" --version))"

echo "==> [3/6] 安装守护脚本和配置"
install -Dm755 "$HERE/fullscreen-workspace.py" "$HOME/.local/bin/fullscreen-workspace.py"
install -Dm644 "$HERE/picom.conf" "$HOME/.config/picom.conf"

echo "==> [4/6] 配置开机自启"
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

echo "==> [5/6] 面板改造：图标式应用切换 (docklike) + 动效 CSS"
install -Dm644 "$HERE/docklike-gtk.css" "$HOME/.config/xfce4-docklike-plugin/gtk.css"
if [ -n "${DISPLAY:-}" ]; then
    # 在 panel-1 中：任务栏(tasklist)替换为 docklike，工作区按钮(pager)移除
    DOCK_ID=40
    xfconf-query -c xfce4-panel -p "/plugins/plugin-$DOCK_ID" -n -t string -s docklike \
        2>/dev/null || true
    mapfile -t ids < <(xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids \
        | grep -E '^[0-9]+$')
    new_ids=()
    for id in "${ids[@]}"; do
        type=$(xfconf-query -c xfce4-panel -p "/plugins/plugin-$id" 2>/dev/null | head -1)
        case "$type" in
            tasklist) new_ids+=("$DOCK_ID") ;;   # 换成 docklike
            pager)    ;;                          # 移除
            docklike) ;;                          # 已有则去重（稍后统一加回）
            *)        new_ids+=("$id") ;;
        esac
    done
    # 若原面板没有 tasklist，则把 docklike 追加到末尾
    printf '%s\n' "${new_ids[@]}" | grep -qx "$DOCK_ID" || new_ids+=("$DOCK_ID")
    args=()
    for id in "${new_ids[@]}"; do args+=(-t int -s "$id"); done
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids "${args[@]}"
    xfce4-panel -r || true
fi

echo "==> [6/6] 关闭 xfwm4 自带合成器并启动"
if [ -n "${DISPLAY:-}" ]; then
    xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s false \
        2>/dev/null || xfconf-query -c xfwm4 -p /general/use_compositing -s false
    # 应用请求激活别的窗口时：切换到该窗口所在桌面（mac 行为），
    # 而不是把窗口拽到当前桌面（xfwm4 默认的 bring）
    xfconf-query -c xfwm4 -p /general/activate_action -n -t string -s switch \
        2>/dev/null || xfconf-query -c xfwm4 -p /general/activate_action -s switch
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
