# 更新日志

## v1.0.0 — 2026-07-02

完整的 mac 风格桌面体验：虚拟桌面 + 动画 + 图标 dock。

### 新增
- **面板图标式应用切换**：`xfce4-docklike-plugin` 替换面板的窗口按钮任务栏，
  每个应用一个图标 ≈ 一个工作区，点击滑动切换（install.sh 第 5 步自动完成面板改造）
- **图标动效 CSS**（`docklike-gtk.css`）：悬停放大 1.3x、按下缩回、
  切换激活时弹跳，基于 docklike 的用户 CSS 钩子和 GTK `-gtk-icon-transform` 动画
- **跨桌面激活跳转**：xfwm4 `activate_action` 设为 `switch`——
  修复"终端调起浏览器时，浏览器被拽到当前桌面而不是切换过去"的问题
- 面板的工作区文字按钮（pager）移除，切换职能完全由图标区承担

### 变更
- install.sh 扩展为 6 步，新增依赖 `xfce4-docklike-plugin`
- README 补全依赖清单、系统改动说明、卸载步骤

## v0.1.0 — 2026-07-02

初始版本。

### 新增
- **虚拟桌面守护进程**（`fullscreen-workspace.py`）：窗口最大化/全屏时自动新建
  虚拟桌面并移入，退出时回到桌面 1 并清理；工作区以应用名命名（WM_CLASS，
  反域名格式自动取末段）；支持多窗口各占一桌面；守护进程重启不会膨胀桌面数
- **工作区滑动动画**：编译 [pijulius/picom](https://github.com/pijulius/picom) 分支
  （方向感知的 `workspace-in/out(-inverse)` 触发器），往右切左滑、往左切右滑，
  0.3s；含 AMD/Mesa 流畅性调优（`use-damage = false`、`no-frame-pacing = true`）
- **一键部署脚本**（`install.sh`）：装依赖 → 编译 picom（固定验证版本 `8f83eb5`）→
  安装文件 → 生成自启动项 → 关闭 xfwm4 合成器 → 立即生效
