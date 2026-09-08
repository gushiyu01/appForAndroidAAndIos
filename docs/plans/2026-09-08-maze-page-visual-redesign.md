# 重力迷宫页面视觉重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 将重力迷宫页面重构为参考图中的柔和玻璃拟态、木框立体迷宫风格，同时保留随机迷宫、计时、暂停、速度档位和重力/触控控制功能。

**架构：** 保持现有 `MazeGamePage` 的游戏状态与运动循环不变，仅重做页面布局、交互控件和迷宫 `CustomPainter`。背景装饰、木质棋盘、凸起墙体、球体高光和控制面板全部使用 Flutter 原生绘制/渐变，避免新增插件和资源依赖。

**技术栈：** Flutter/Dart、Material 3、`CustomPainter`、`Ticker`、现有原生运动通道。

---

### 任务 1：重构页面布局与视觉组件

**文件：**
- 修改：`lib/pages/maze_game_page.dart`

**步骤：**
1. 保留现有运动、碰撞、计时和模式切换逻辑。
2. 使用淡紫白渐变背景和几何线条装饰替换默认 Scaffold/AppBar 布局。
3. 增加参考图风格的圆形返回/刷新按钮、木框迷宫、计时暂停卡片、速度选择条、手动控制开关和底部说明条。
4. 为重力模式与手动模式保留清晰的文字提示、传感器错误提示和完成状态。
5. 用 `CustomPainter` 绘制立体墙体、入口/出口光晕、金属质感小球与手动方向指示。

### 任务 2：验证与交付

**文件：**
- 检查：`tool/validate_templates.py`
- 检查：`README.md`

**步骤：**
1. 运行模板校验与 `git diff --check`。
2. 若本机存在 Flutter SDK，运行 `flutter analyze` 和 `flutter test`；否则记录 CI 负责完整验证。
3. 提交页面重构并推送当前功能分支，触发 GitHub Actions 自动构建。
