# mac 风格桌面 for XFCE

在 XFCE (X11) 上复刻 macOS 的桌面交互，一键部署。

## 效果

- **窗口最大化或全屏** → 自动新建一个虚拟桌面，窗口移过去，整屏向左滑动切换
- **退出最大化/全屏（或关闭窗口）** → 滑回桌面 1，多余桌面自动删除
- **面板图标式应用切换**（docklike）：每个运行中的应用一个图标 ≈ 一个工作区，
  点击图标滑动切换到该应用的桌面；支持右键固定常用应用
- **图标动效**：悬停放大 1.3 倍、按下缩回、切换时弹跳（mac 程序坞手感）
- **跨桌面激活跳转**：应用请求打开别的窗口时（如终端调起浏览器），
  滑动切换过去而不是把窗口拽到当前桌面
- 支持多窗口同时全屏，各占一个桌面，自动整理编号

## 部署

```bash
git clone https://github.com/Chen-DR/xfce-mac-desktop
cd xfce-mac-desktop
./install.sh
```

需要 sudo 权限装依赖。适用于 Debian/Kali/Ubuntu 系 + XFCE + X11（Wayland 不适用）。

## 组成

| 文件 | 说明 | 安装位置 |
|---|---|---|
| `fullscreen-workspace.py` | 守护进程：监听窗口全屏/最大化状态（X11 事件，非轮询），用 wmctrl 增删/切换工作区，用 xfconf 改工作区名 | `~/.local/bin/` |
| `picom.conf` | 合成器配置：方向感知的工作区滑动动画（0.3s）+ 阴影 + 淡入淡出 + AMD/Mesa 流畅性调优 | `~/.config/` |
| `docklike-gtk.css` | docklike 图标动效：悬停放大 / 按下缩回 / 激活弹跳 | `~/.config/xfce4-docklike-plugin/gtk.css` |
| `install.sh` | 一键部署：装依赖 → 编译 picom → 装文件 → 面板改造 → 配自启 → 立即生效 | — |

## 依赖

- **随仓库内置**：[pijulius/picom](https://github.com/pijulius/picom) 分支源码
  （`picom-pijulius/`，版本 `8f83eb5`，主线 picom 没有 `workspace-in/out` 动画触发器）。
  克隆本仓库即获得全部代码，编译**不需要再联网**，装到 `~/.local/bin/picom`，不污染系统目录
- **目标系统软件包**（install.sh 通过 apt 自动安装，这类系统库无法打包进 git）：
  `wmctrl`、`python3-xlib`、`xfconf`、`xfce4-docklike-plugin`，
  以及编译 picom 所需的 meson/ninja/cmake 和各 xcb/gl 开发库

## install.sh 对系统的改动

1. xfwm4 自带合成器关闭（`/general/use_compositing = false`），由 picom 接管
2. xfwm4 `activate_action` 从默认 `bring` 改为 `switch`（跨桌面激活时切换过去）
3. 面板 panel-1：`tasklist`（窗口按钮）替换为 `docklike`，`pager`（工作区按钮）移除
4. 新增自启动项：`fullscreen-workspace.desktop`、`picom.desktop`

## 常用调整

- **动画时长**：`~/.config/picom.conf` 里的 `duration = 0.3`，改完 `pkill -x picom` 再运行 `~/.local/bin/picom -b`
- **图标放大倍率/弹跳幅度**：`~/.config/xfce4-docklike-plugin/gtk.css` 里的 `scale(1.3)` 和 `-5px`，改完 `xfce4-panel -r`
- **只想 F11 全屏触发、最大化不触发**：删掉 `fullscreen-workspace.py` 中 `is_fullscreen()` 里
  `NET_WM_STATE_MAX_VERT/HORZ` 那两行判断
- **重启守护进程**：`pkill -f '^python3 .*/fullscreen-workspace.py'` 后重新运行
  （注意 pkill 模式要带 `^python3` 前缀，否则会误杀调用它的终端）

## 卸载

1. 删除 `~/.local/bin/{fullscreen-workspace.py,picom}`、`~/.config/picom.conf`、
   `~/.config/xfce4-docklike-plugin/gtk.css`、`~/.config/autostart/{fullscreen-workspace,picom}.desktop`
2. `xfconf-query -c xfwm4 -p /general/use_compositing -s true`（恢复 xfwm4 合成器）
3. `xfconf-query -c xfwm4 -p /general/activate_action -s bring`
4. 面板右键 → 面板首选项 → 项目，把 docklike 换回"窗口按钮"，按需加回"工作区切换器"

## 致谢与许可

- `picom-pijulius/` 目录是 [pijulius/picom](https://github.com/pijulius/picom) 的源码副本
  （基于 [yshui/picom](https://github.com/yshui/picom)），遵循其原有协议
  **MPL-2.0 / MIT**（见目录内 `COPYING` 与 `LICENSES/`），本仓库原样分发、未做修改
- 图标 dock 使用 [xfce4-docklike-plugin](https://gitlab.xfce.org/panel-plugins/xfce4-docklike-plugin)
  （GPL-3.0），由系统包管理器安装，本仓库不包含其代码
- 其余文件（守护脚本、install.sh、配置、CSS）为本仓库原创

## 已知限制

- 多个桌面间跳跃切换（跨度 >1）时，滑动方向偶尔会判断反（picom 按 ±1 和首尾循环推断方向）
- 图标悬停放大被限制在面板高度内（面板插件无法像独立 dock 那样溢出渲染）
