# appForAndroidAAndIos

[![Build Android and iOS](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml/badge.svg)](https://github.com/gushiyu01/appForAndroidAAndIos/actions/workflows/build.yml)

一个 Flutter 应用：启动后调用系统指纹识别，验证通过后进入功能页；功能页提供水平测试和打开系统相机。

## 功能

- 登录页默认触发系统生物识别，成功后自动进入首页。
- 水平测试读取加速度计计算俯仰与横滚角度，并同步显示陀螺仪数据。
- 相机页调用系统相机拍照，并在页面内预览结果。

## 构建与产物

仓库已配置 GitHub Actions：推送到 `main`、提交 PR 或手动触发时，会自动执行以下任务。

1. 安装 Flutter 稳定版。
2. 生成 Android 和 iOS 平台工程。
3. 注入 Android 生物识别权限与 iOS 相机、Face ID 用途说明。
4. 运行 `flutter analyze`、`flutter test`。
5. 构建 Android release APK 和未签名 iOS `.app`。
6. 上传构建产物到该次 Workflow 的 **Artifacts** 区域。

Android 产物名为 `app-release-apk`，可直接安装测试。iOS 产物名为 `runner-ios-unsigned`；未签名包不能直接安装到普通 iPhone，如需真机安装或上架 TestFlight，请在本地或 CI 中补充 Apple 开发者签名配置。
