# mac 风格虚拟桌面 for XFCE

在 XFCE (X11) 上复刻 macOS 的全屏/最大化行为：

- **窗口最大化或全屏** → 自动新建一个虚拟桌面，窗口移过去，整屏向左滑动切换
- **退出最大化/全屏（或关闭窗口）** → 滑回桌面 1，多余桌面自动删除
- 工作区切换器上显示应用名（如 `1 | Clash | Chrome`）而不是数字
- 支持多个窗口同时全屏，各占一个桌面，自动整理编号

## 部署

```bash
./install.sh
```

需要 sudo 权限装依赖。适用于 Debian/Kali/Ubuntu 系 + XFCE + X11（Wayland 不适用）。

## 组成

| 文件 | 说明 | 安装位置 |
|---|---|---|
| `fullscreen-workspace.py` | 守护进程：监听窗口全屏/最大化状态（X11 事件，非轮询），用 wmctrl 增删/切换工作区，用 xfconf 改工作区名 | `~/.local/bin/` |
| `picom.conf` | 合成器配置：方向感知的工作区滑动动画（0.3s）+ 阴影 + 淡入淡出 | `~/.config/` |
| `install.sh` | 一键部署：装依赖 → 编译 picom → 装文件 → 配自启 → 立即生效 | — |

滑动动画依赖 [pijulius/picom](https://github.com/pijulius/picom) 分支（主线 picom 没有
`workspace-in/out` 动画触发器），install.sh 会自动克隆编译，装到 `~/.local/bin/picom`，
不污染系统目录。xfwm4 自带合成器会被关闭（`xfconf-query -c xfwm4 -p /general/use_compositing`）。

## 常用调整

- **动画时长**：`~/.config/picom.conf` 里的 `duration = 0.3`，改完 `pkill -x picom` 再运行 `~/.local/bin/picom -b`
- **只想 F11 全屏触发、最大化不触发**：删掉 `fullscreen-workspace.py` 中 `is_fullscreen()` 里
  `NET_WM_STATE_MAX_VERT/HORZ` 那两行判断
- **重启守护进程**：`pkill -f '^python3 .*/fullscreen-workspace.py'` 后重新运行
  （注意 pkill 模式要带 `^python3` 前缀，否则会误杀调用它的终端）
- **卸载**：删除上表中安装位置的文件和 `~/.config/autostart/{fullscreen-workspace,picom}.desktop`，
  然后 `xfconf-query -c xfwm4 -p /general/use_compositing -s true` 恢复 xfwm4 合成器

## 已知限制

- 多个桌面间跳跃切换（跨度 >1）时，滑动方向偶尔会判断反（picom 按 ±1 和首尾循环推断方向）
- 工作区名字只在切换器的"按钮"外观下显示，缩略图模式看不到
