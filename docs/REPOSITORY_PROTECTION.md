# 仓库保护配置

本文档记录 GitHub 上不随源码检出保存的仓库保护状态。实际配置以 GitHub
Ruleset 为准，修改时必须同步更新本文档。

## `main` Ruleset

- 名称：`main-quality-gate`
- ID：`20184240`
- 状态：`active`
- 地址：[main-quality-gate](https://github.com/Spring2022abcjk/ClashToSingBox/rules/20184240)
- 目标：默认分支 `main`
- 禁止删除和 force push。
- 所有更新必须经过 Pull Request。
- 允许 merge、squash 和 rebase 三种合并方式，不要求人工审批。
- PR 必须基于最新 `main` 通过以下 GitHub Actions 检查：
  - `Test (ubuntu-latest)`
  - `Test (windows-latest)`
  - `Static analysis`
- 管理员 `Spring2022abcjk` 只能在 Pull Request 中显式绕过，不能直接推送。

修改 CI job 名称时，必须同时调整 Ruleset 的必需检查。否则新 job 名称不会满足
旧检查名，Pull Request 将无法正常合并。

## Dependabot

`.github/dependabot.yml` 每周一 09:00（`Asia/Taipei`）检查 GitHub Actions
依赖，只创建 Pull Request，不自动合并。Dependabot 已创建
[PR #5](https://github.com/Spring2022abcjk/ClashToSingBox/pull/5)，证明配置已经生效。

## 门禁验收

Pull Request #6 的临时失败测试使 Windows 和 Ubuntu 必需检查失败；
[运行 30700689856](https://github.com/Spring2022abcjk/ClashToSingBox/actions/runs/30700689856)
完成后，Pull Request 的合并状态为 `BLOCKED`。这证明失败的必需检查会阻止常规
合并，验收过程没有使用管理员绕过。

临时失败测试仅用于门禁探针，已在后续提交中删除，不进入 `main`。
