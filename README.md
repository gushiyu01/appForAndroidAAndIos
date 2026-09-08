# appForAndroidAAndIos

[![Build Android and iOS](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml/badge.svg)](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml)

一个 Flutter 应用：启动后调用系统指纹识别，验证通过后进入功能页；功能页提供水平测试和打开系统相机。

## 云端构建

本项目完全使用 GitHub Actions 在云端构建，本地无需安装 Flutter、Android SDK 或 Xcode。

> [!IMPORTANT]
> 本项目会在推送到 `codex/gravity-maze-game`、提交针对 `codex/gravity-maze-game` 的 Pull Request 时自动构建，也支持在 **Actions > Build Android and iOS > Run workflow** 中手动构建。构建完成后，在 Workflow 页面的 **Artifacts** 区域下载产物。

[打开 GitHub Actions 构建页面](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml)

### Fork 后指定分支手动构建

Fork 仓库后，进入 **Actions > Build Android and iOS > Run workflow**，在 **Use workflow from** 下拉框中选择目标分支，再点击 **Run workflow**。当前 Workflow 只启用 `workflow_dispatch`，因此任何包含它的分支都可以手动触发，但不会因推送自动触发。

### 切换手动构建与自动构建

当前 `.github/workflows/build.yml` 已配置为推送到 `codex/gravity-maze-game`、提交针对 `codex/gravity-maze-game` 的 Pull Request 时自动构建，同时保留手动触发：

```yaml
on:
  push:
    branches:
      - codex/gravity-maze-game
  pull_request:
    branches:
      - codex/gravity-maze-game
  workflow_dispatch:
```

其中 `workflow_dispatch` 必须保留；删除它会导致 Actions 页面不再显示 **Run workflow** 按钮。如果只需要为其他分支增加自动构建，把分支名加入 `push.branches` 即可。

```yaml
on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main
  workflow_dispatch:
```

如果要一次复制源仓库的所有分支，fork 时取消勾选 **Copy the main branch only**；已完成的 fork 可以在 fork 仓库中从源仓库分支手动创建同名分支。

## 功能

- 登录页默认触发系统生物识别，成功后自动进入首页。
- 水平测试读取加速度计计算俯仰与横滚角度，并同步显示陀螺仪数据。
- 重力迷宫使用加速度计控制小球，随机生成迷宫路线，入口固定在左上角、出口固定在右下角，并提供高速模式开关调节移动速度。
- 相机页调用系统相机拍照，并在页面内预览结果。

## 云端构建流程

推送到 `codex/gravity-maze-game`、提交 Pull Request 或手动触发 Workflow 后，GitHub Actions 会执行以下任务：

1. 在云端安装 Flutter 3.44.9。
2. 生成 Android 和 iOS 平台工程。
3. 注入 Android 生物识别权限与 iOS 相机、Face ID 用途说明。
4. 运行 `flutter analyze`、`flutter test`。
5. 构建 Android release APK 和未签名 iOS `.app`。
6. 上传构建产物到该次 Workflow 的 **Artifacts** 区域。

Android 产物名为 `app-release-apk`，可直接安装测试。iOS 产物名为 `runner-ios-unsigned`；未签名包不能直接安装到普通 iPhone，如需真机安装或上架 TestFlight，请在本地或 CI 中补充 Apple 开发者签名配置。
