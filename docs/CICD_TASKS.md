# GitHub CI/CD 流水线任务拆分

本文档拆分 ClashToSingBox 的 GitHub CI/CD 建设任务。当前只记录计划，不表示任何工作流已经创建、运行或验收。

总览入口：[ClashToSingBox 项目路线图](./PROJECT_ROADMAP.md)

## 目标

- Pull Request 在合并前自动验证核心行为。
- `main` 分支始终保持可测试、可导入、可打包状态。
- 正式版本通过标签生成可追溯的 GitHub Release。
- 发布权限与日常 CI 隔离，默认采用最小权限。
- 优先建设低维护成本、高缺陷拦截收益的任务。

## 总体边界

本任务包含：

- GitHub Actions 工作流。
- Pester 单元测试和集成测试自动执行。
- PSScriptAnalyzer 项目级配置与自动检查。
- 模块清单、模块导入和公开命令检查。
- 跨平台验证。
- 正式版本打包与 GitHub Release。
- 可选的 PowerShell Gallery 发布设计。

本任务暂不包含：

- 自托管 Runner。
- Docker 镜像构建或发布。
- 自动修改源码中的版本号。
- 每次提交自动发布正式版本。
- 自动格式化并向仓库提交修改。
- Nightly 构建、mutation testing 或复杂性能基准。
- 新协议和 WebSocket early-data 功能实现。

## CI-1：静态检查规则基线

状态：基线已完成；GitHub Runner 复用验证归入 CI-2。

### 目标

建立仓库级 PSScriptAnalyzer 配置，让 CI 阻塞真正需要修复的问题，同时明确记录不适用于本项目的规则。

### 实施内容

- 复核并固化仓库已有的 `PSScriptAnalyzerSettings.psd1`。
- 修正确定存在的行尾空格、输出类型或编码问题；当前基线没有此类遗留发现。
- 在 [`STATIC_ANALYSIS.md`](./STATIC_ANALYSIS.md) 中记录以下规则的明确决定和理由：
  - `PSUseSingularNouns` 对公开命令 `Convert-ProxyNodes` 的告警。
  - `PSUseShouldProcessForStateChangingFunctions` 对内部构造函数的告警。
  - `PSUseBOMForUnicodeEncodedFile` 的仓库编码策略。
- 本地检查和后续 CI 均显式使用仓库配置。
- Error、Warning 和 Information 均为阻塞结果，不依赖隐式默认行为。

### 边界

- 不因消除告警而破坏已公开的命令名称。
- 不给纯内存对象构造函数添加没有语义价值的 `ShouldProcess`。
- 不在没有统一编码决策时批量重写所有文件。

### 验收标准

- 本地使用仓库配置且结果为零；GitHub Runner 使用同一配置的验证由 CI-2 完成。
- Analyzer 结果可重复，没有未解释的阻塞告警。
- 规则排除项具有项目级理由，而不是临时隐藏缺陷。

## CI-2：Pull Request 质量门禁

状态：已实施，正在通过 Pull Request #2 完成 GitHub Runner 验收。

### 目标

为 Pull Request、`main` 推送和手工运行建立统一 CI。

### 触发条件

- `pull_request`
- 推送到 `main`
- `workflow_dispatch`

### 实施内容

- 新增 `.github/workflows/ci.yml`。
- 使用 GitHub-hosted Runner。
- 在 Windows 和 Ubuntu 上使用 PowerShell 7 执行：
  - `Test-ModuleManifest`。
  - `Import-Module`。
  - 确认只导出预期公开命令 `Convert-ProxyNodes`。
  - `Invoke-Pester -Path ./tests`。
- 在 Ubuntu 上执行一次 PSScriptAnalyzer，避免重复工作。
- 精确安装模块运行时依赖 `powershell-yaml 0.4.12`，确保干净 Runner 可以验证并导入模块。
- 固定 Pester 与 PSScriptAnalyzer 的版本范围，避免 Runner 预装版本漂移。
- 设置最小权限：`contents: read`。
- 为同一分支设置并发取消，停止已经过时的 CI 运行。

### 边界

- 日常 CI 不需要写入仓库、创建 Release 或读取发布密钥。
- 第一阶段不加入 macOS 矩阵。
- 测试失败时不上传没有诊断价值的大型 artifact。
- 不缓存体积很小且安装快速的依赖，除非真实运行数据证明值得。

### 验收标准

- Windows 和 Ubuntu 均能从干净检出运行全部测试。
- 任一测试失败都会使对应检查失败。
- 模块清单无效、模块无法导入或公开命令异常时 CI 会失败。
- Analyzer 使用 CI-1 确定的项目配置。
- 同一 Pull Request 的旧运行会在新提交到达后取消。
- GitHub 上至少保存一次成功的 Pull Request 或 `main` 运行记录。

## CI-3：真实转换烟雾测试与仓库污染检查

### 目标

除 Pester 外，再以用户入口完成一次轻量验证，并确保验证过程不会污染仓库。

### 实施内容

- 使用受版本控制的公开测试输入执行 `Convert-ProxyNodes`。
- 将输出写入 Runner 临时目录，而不是 `outputs/` 或仓库根目录。
- 解析生成的 JSON，并检查：
  - JSON 可正常读取。
  - 输出节点数量符合测试输入预期。
  - 必填字段 `type`、`tag`、`server`、`server_port` 存在。
- 工作流结束前检查工作树没有生成新的受版本控制变更。

### 边界

- 不读取 `myinputs/`。
- 不使用真实订阅、密码或私人节点作为 CI 输入。
- 不把临时运行结果提交为新的测试基线。

### 验收标准

- Windows 和 Ubuntu 均完成真实公开命令调用。
- 临时结果在 Runner 生命周期结束后自动消失。
- 测试输入不包含真实使用数据或秘密。

## CD-1：版本一致性与干净打包

### 目标

以 `vX.Y.Z` 标签生成与模块清单一致、内容最小化的安装包。

### 触发条件

- 推送符合 `v*` 的版本标签。
- 可选的 `workflow_dispatch` 仅用于打包演练，不发布正式版本。

### 实施内容

- 新增 `.github/workflows/release.yml`。
- 校验标签版本与 `ClashToSingBox.psd1` 的 `ModuleVersion` 完全一致。
- 发布前重新执行完整 CI 验证。
- 在 Runner 临时目录组装模块包，仅包含：
  - `ClashToSingBox.psd1`
  - `ClashToSingBox.psm1`
  - `Classes/`
  - `Private/`
  - `Public/`
  - `License`
  - 必要的 README
- 从组装后的目录重新运行 `Test-ModuleManifest`、`Import-Module` 和公开命令检查。
- 生成 ZIP 和 SHA256 摘要。
- 将包作为工作流 artifact 上传，供发布步骤使用。

### 边界

- 包内不包含 `.git/`、`.github/`、`tests/`、`test-inputs/`、`test-outputs/`、`myinputs/` 或 `outputs/`。
- 标签不负责自动修改 `ModuleVersion`。
- 版本不一致时直接失败，不猜测或修正版本。

### 验收标准

- `v0.1.1` 形式的标签只能打包 `ModuleVersion = 0.1.1` 的模块。
- ZIP 解压后可以直接按标准模块目录导入。
- 包内容符合最小发布清单。
- 同一 Git commit 可重复生成逻辑等价的模块内容。

## CD-2：GitHub Release

### 目标

在 CD-1 全部通过后创建 GitHub Release，并附加经过验证的安装包与摘要。

### 实施内容

- Release job 只在版本标签触发时运行。
- 仅向 Release job 提供 `contents: write`。
- 使用标签创建对应 GitHub Release。
- 上传 ZIP 和 SHA256 文件。
- Release Notes 至少包含版本号、主要变化和安装方式。

### 边界

- Pull Request 和普通 `main` CI 保持只读权限。
- 验证或打包失败时不得创建部分成功的 Release。
- 不覆盖已存在的同名正式 Release。

### 验收标准

- 只有通过全部质量门禁的标签可以创建 Release。
- GitHub Release 中的文件与流水线验证过的 artifact 相同。
- Release 页面提供清楚的安装或手工导入说明。

## CD-3：PowerShell Gallery 发布（可选）

### 目标

在 GitHub Release 流程稳定后，让正式版本可通过 PowerShell 包管理命令安装。

### 前置条件

- CD-1 和 CD-2 已稳定运行。
- PowerShell Gallery 的模块名称和所有权已确认。
- 模块清单中的项目链接、许可证、标签和发布说明满足发布要求。
- 发布密钥已配置为 GitHub Environment Secret。

### 实施内容

- 建立受保护的 `powershell-gallery` Environment。
- 为 Gallery 发布配置人工批准。
- 只发布 CD-1 已验证的同一份模块目录。
- 发布前检查目标版本尚不存在。
- 发布成功后执行安装与导入验证。

### 边界

- 发布密钥不进入普通 CI job。
- 不从 Pull Request 或普通 `main` 推送发布。
- 不覆盖或重发已经存在的 Gallery 版本。
- 第一阶段不要求实施本任务。

### 验收标准

- 未经 Environment 批准无法使用发布密钥。
- Gallery 上的版本、GitHub 标签和模块清单版本一致。
- 发布后能在干净环境通过 `Install-PSResource` 或约定命令安装并导入。

## CI-4：仓库保护与维护自动化

### 目标

让已建立的检查真正成为合并门禁，并降低 GitHub Actions 依赖维护成本。

### 实施内容

- 为 `main` 配置分支保护或 Ruleset。
- 必需检查建议设置为：
  - Ubuntu 测试。
  - Windows 测试。
  - 静态质量检查。
- 禁止 force push。
- 要求 Pull Request 在必需检查通过后才能合并。
- 增加 Dependabot 对 GitHub Actions 的每周版本检查。

### 边界

- 不要求 macOS、Release 或 Gallery 发布作为普通 PR 的必需检查。
- 不自动合并 Dependabot Pull Request。
- 不加入与当前威胁模型和项目规模不匹配的复杂安全流水线。

### 验收标准

- 失败的必需检查会阻止合并。
- Dependabot 只更新工作流依赖，不改变 PowerShell 模块功能。
- 维护者仍可从 GitHub UI 清楚区分测试、质量检查和发布结果。

## 后续候选项

以下项目只有在实际收益明确后再实施：

- macOS 定时或 Release 前测试。
- Pester 覆盖率报告和最低阈值。
- GitHub artifact attestation。
- Release Notes 自动生成增强。
- 测试报告可视化。
- 依赖缓存。

## 推荐施工顺序

1. CI-1：先确定 Analyzer 的真实门禁规则。
2. CI-2：建立 Windows 和 Ubuntu 的基础 CI。
3. CI-3：补真实公开命令烟雾测试和污染检查。
4. CI-4：CI 稳定后再启用合并保护和 Dependabot。
5. CD-1：建立版本一致性和干净打包。
6. CD-2：创建 GitHub Release。
7. CD-3：根据分发需求决定是否发布到 PowerShell Gallery。

## 完成定义

整个 CI/CD 建设只有在以下条件全部满足后才算完成：

- CI 在 Pull Request 和 `main` 上有真实成功记录。
- Windows 与 Ubuntu 的测试、导入和清单验证均通过。
- Analyzer 规则有明确且可复现的项目配置。
- 版本标签能生成经过验证的最小发布包。
- GitHub Release 只在所有前置检查通过后创建。
- 发布权限遵守最小权限原则，普通 CI 无法访问发布密钥。
- README 和路线图已经同步最终使用方式和真实完成状态。
