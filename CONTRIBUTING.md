# 贡献指南 (Contributing)

感谢你愿意为「鹿了么」贡献代码！本指南帮你快速上手。

## 项目简介

- **平台**：HarmonyOS NEXT（API 24 / 6.1.1），ArkTS + ArkUI 声明式（Stage 模型）
- **定位**：本地私密健康记录工具。**零网络权限**，所有数据仅存设备本地
- **许可**：MIT

## 环境准备

1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（5.x，含 HarmonyOS 6.1.1 SDK）
2. 克隆仓库并打开工程
3. 本地签名：`File > Project Structure > Signing Configs` 勾选「自动生成签名」（开源版 `build-profile.json5` 不含签名配置，这是刻意的）
4. 连接真机（API 24）或模拟器，点击 Run

## 报告 Issue

- 先搜索是否已有相同 Issue
- 标题简要描述问题，正文包含：
  - 设备型号与系统版本
  - 复现步骤
  - 期望行为 / 实际行为
  - 截图或日志（`hilog` 输出，标签 `luleme`）

## 提交 Pull Request

1. **Fork** 本仓库，从 `main` 新建分支：`git checkout -b fix/xxx`
2. 分支命名建议：`feat/`（功能）、`fix/`（修复）、`docs/`（文档）、`refactor/`（重构）
3. 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：
   ```
   feat: 新增年度回顾视图
   fix: 修复日历跨月时热力图错位
   ```
4. 推送并创建 PR，描述里说明改动目的与验证方式

## 代码规范

- **ArkTS 严格模式**：不用 `any`/`unknown`（可显式 cast）、对象字面量必须对应已声明类型、回调参数写类型
- 数据访问走 `data/RecordRepository.ets` / `data/SettingsStore.ets` 单例，页面不直接碰 SQL
- 统计/日历计算放 `logic/` 纯函数（**必须可单测**），新增逻辑同步补 `entry/src/test/LocalUnit.test.ets` 用例
- 颜色等资源放 `resources/base|dark/element/`，UI 代码用 `$r('app.color.xxx')` 引用，不硬编码色值
- 隐私红线：**不得新增任何网络权限**（`module.json5` 不声明 `ohos.permission.INTERNET`），不得上传用户数据

## 运行测试

本地单元测试（统计/日历纯函数）在 DevEco Studio 中运行 `entry/src/test`，或命令行：

```bat
hvigorw --mode module -p product=default test --no-daemon
```

## 许可

提交代码即表示同意以 [MIT License](LICENSE) 授权你的贡献。
