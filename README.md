# 🦌 鹿了么

本地私密健康记录 App（HarmonyOS NEXT / ArkTS）。

对标「月经记录」类 App 的交互模式，用于**本地记录**个人自慰/性健康数据。
所有数据仅保存在设备本地，**应用不申请任何网络权限，不上传任何数据**。

## 功能

- **记录**：一键快速记录 + 详细记录（日期 / 时间 / 心情 5 档 / 备注），支持编辑与删除
- **日历热力图**：按日记录次数着色的月历（5 档深浅），点击日期查看当天详情
- **统计**：今日 / 本月 / 总次数、当前连续天数、最长与平均间隔、距上次记录、近 6 个月趋势柱状图（Canvas 自绘）
- **应用锁**：PIN（4-6 位，加盐 SHA-256 存储）+ 生物识别（指纹 / 人脸），退到后台自动重新锁定
- **备份**：JSON 导出 / 导入（导入替换现有数据）、清空全部记录
- **主题**：浅色 / 深色自动适配，粉色系 UI

## 技术要点

| 项目 | 方案 |
| --- | --- |
| 语言 / UI | ArkTS + ArkUI 声明式（Stage 模型） |
| 本地存储 | RelationalStore（SQLite，`records` 表）+ Preferences（设置） |
| 路由 | Navigation + NavPathStack（NavDestination） |
| 安全 | `@kit.CryptoArchitectureKit`（SHA-256）、`@kit.UserAuthenticationKit`（生物识别） |
| 文件 | `@kit.CoreFileKit`（DocumentViewPicker 导出 / 导入） |
| 测试 | hypium 单元测试（`entry/src/test`，覆盖统计与日历纯函数） |

## 目录结构

```
entry/src/main/ets/
├── entryability/       Ability 入口（初始化数据层、后台置锁）
├── common/             常量（路由名、热力色板）
├── model/              数据模型（Record / 心情）
├── data/               RecordRepository（RDB）、SettingsStore（Preferences）
├── logic/              纯函数：StatsCalculator、CalendarUtil、SecurityUtil
├── components/         CalendarHeatmap、TrendChart
└── pages/              Index（首页）、RecordEdit、Stats、Settings、Lock
```

## 构建

DevEco Studio 5.x（API 24 / HarmonyOS 6.1.1）直接打开工程，连接真机或模拟器运行。

命令行构建（需 DevEco Studio 自带工具链）：

```bat
set DEVECO_SDK_HOME=D:\Program Files\DevEco Studio\sdk
"D:\Program Files\DevEco Studio\tools\node\node.exe" ^
  "D:\Program Files\DevEco Studio\tools\hvigor\hvigor\bin\hvigor.js" ^
  --mode module -p product=default assembleHap --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`（未签名，真机调试请在 DevEco Studio 中配置自动签名）。

## 隐私与合规

- 全程无网络权限（`module.json5` 未声明 `ohos.permission.INTERNET`）
- 上架材料清单见 [`docs/上架准备.md`](docs/上架准备.md)

## 更新记录

### v1.2.0（2026-10-31）

- **提醒**：新增每日定时提醒（默认 21:00，可改时间与文案）与「葛神模式」（记录后 8 小时提醒一次），走系统 `reminderAgentManager`
- **隐私**：新增防截屏保护（窗口隐私模式，默认开启）
- **撤销**：删除记录后 3 秒内可撤销
- **滑动切页**：移除与横向位移打架的淡入/上浮装饰，切页不再抖动
- **导出**：修复 `.json` 后缀重复追加；文件名改为带时间戳的 `luleme_backup_YYYYMMDD-HHmm.json`
- **降级**：后台提醒在不支持提醒能力的设备上自动降级为「打开应用时提醒」
- **版本号**：1.1.0 → 1.2.0

详细说明见 [`docs/版本更新说明-v1.2.0.md`](docs/版本更新说明-v1.2.0.md)。

### v1.1.0（2026-10-25）

- **底栏**：移除 `HdsTabs` 的 `miniBar`，修复浮动胶囊被挤压截断、出现重复设置入口
- **切换手感**：Tab 点击即时高亮 + 220ms 淡入上浮转场，120ms 防连点，页面驻留
- **日历**：修复换月单向（右箭头失效）、跨月高亮残留、热力图撑高把「记一笔」顶出屏幕
- **统计**：修复指标卡恒为 0（`@Builder` 按值传参），趋势图配色跟随深色主题
- **首页**：补记历史日期的记录后立即刷新（写库广播），不再需要重启
- **编辑**：修复日期栏显示成「今天当前时刻」
- **设置**：新增沉浸光感材质档位（自适应 / 精致 / 均衡 / 柔和），版本号自动读取

详细说明见 [`docs/版本更新说明-v1.1.0.md`](docs/版本更新说明-v1.1.0.md)。

## 开源许可

本项目基于 [MIT License](LICENSE) 开源，欢迎 Fork、提 Issue 与 PR。
开源版已剥离本地签名配置（`build-profile.json5` 的 `signingConfigs` 为空）；
如需在本地运行调试，请在 DevEco Studio 中重新勾选「自动生成签名」，或参考 `build-profile.signed.json5`（该文件已被 `.gitignore` 忽略，不会进入仓库）。

> 注意：本项目为个人健康记录工具，所有数据仅保存在用户设备本地。请在转载、宣传时保持内容健康化，并自行确认应用名称与第三方商标的兼容性。

## 贡献

欢迎任何形式的贡献：Bug 报告、功能建议、代码与文档。

- 提交 Issue 或 PR 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)
- 首次贡献者可先找标有 `good first issue` 的 Issue
- 贡献者名单会自动展示在仓库右侧 Contributors 区域（通过 PR 合入后自动出现）
