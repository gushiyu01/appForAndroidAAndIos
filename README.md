# appForAndroidAAndIos

[![Build Android and iOS](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml/badge.svg)](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml)

一个 Flutter 应用：启动后调用系统指纹识别，验证通过后进入功能页；功能页提供水平测试和打开系统相机。

## 云端构建

本项目完全使用 GitHub Actions 在云端构建，本地无需安装 Flutter、Android SDK 或 Xcode。

> [!IMPORTANT]
> 本项目会在推送到 `codex/gravity-maze-game`、提交针对 `codex/gravity-maze-game` 的 Pull Request 时自动构建，也支持在 **Actions > Build Android and iOS > Run workflow** 中手动构建。构建完成后，在 Workflow 页面的 **Artifacts** 区域下载产物。

[打开 GitHub Actions 构建页面](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml)

### Fork 后指定分支手动构建

Fork 仓库后，进入 **Actions > Build Android and iOS > Run workflow**，在 **Use workflow from** 下拉框中选择目标分支，再点击 **Run workflow**。当前 Workflow 同时启用手动触发，以及面向 `codex/gravity-maze-game` 的 push / pull_request 自动构建；其他分支不会因推送自动触发。

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
- 水平测试读取两端统一的重力向量计算俯仰与横滚角度，并同步显示陀螺仪数据；等待、超时或传感器异常时不会显示“水平”。
- 重力迷宫使用加速度计控制小球，随机生成迷宫路线，入口固定在左上角、出口固定在右下角，并提供普通、高速、极速三档速度，以及重力/手动触控两种控制模式；进入游戏先在设置弹框中选择，游戏中可通过右上角设置按钮再次调整。
- 相机页调用系统相机拍照，并在页面内预览结果；Android 因 Activity 被回收而丢失的拍照结果会在启动时恢复，并在生物识别通过后展示。取消重新拍摄会保留上一张照片。

## 云端构建流程

推送到 `codex/gravity-maze-game`、提交 Pull Request 或手动触发 Workflow 后，GitHub Actions 会执行以下任务：

1. 在云端安装 Flutter 3.44.9。
2. 生成 Android 和 iOS 平台工程。
3. 注入 Android 生物识别权限、iOS 相机/Face ID/运动用途说明，以及 UIScene 引擎初始化和原生运动通道。
4. 校验生成工程、运行 Python 平台脚本测试，以 `pubspec.lock` 锁定依赖并检查 Dart 格式，运行 `flutter analyze`、`flutter test`。
5. 构建 Android release APK 和未签名 iOS `.app`。
6. 上传构建产物到该次 Workflow 的 **Artifacts** 区域。

Android 产物名为 `app-release-apk`，可直接安装测试。iOS 产物名为 `runner-ios-unsigned`；未签名包不能直接安装到普通 iPhone，如需真机安装或上架 TestFlight，请在本地或 CI 中补充 Apple 开发者签名配置。


## 稳定性约定与验证

- `pubspec.lock` 纳入版本控制；CI 使用 `flutter pub get --enforce-lockfile`，依赖升级需显式更新锁文件并重新验证两端。
- 原生 `accelerometer` 通道保留名称，但统一返回物理重力向量（m/s²）：X 向设备右侧、Y 向设备顶部、Z 向屏幕外，屏幕朝上平放约为 `(0, 0, -9.80665)`。Android 优先使用重力传感器，无此传感器时对加速度计低通滤波。
- 游戏暂停、打开设置或进入后台时不计时、不移动；返回前台或关闭设置不会解除用户主动暂停。
- 生物识别仍是启动门禁，不新增后台超时重新解锁策略。恢复照片只在登录后的页面显示；图片位于临时缓存，不作为永久相册保存。

无需 Flutter 的检查：

```sh
python tool/validate_templates.py
python -m unittest discover -s tool/tests -v
```

CI 生成工程后额外执行 `python tool/validate_templates.py --generated`。有 Flutter 3.44.9 的环境可执行：

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

真机回归重点：iOS 冷启动后的生物识别和运动通道；两端平放及四方向倾斜；极速墙角碰撞；暂停/设置/后台计时；Android 开启“不保留活动”后的拍照恢复。
