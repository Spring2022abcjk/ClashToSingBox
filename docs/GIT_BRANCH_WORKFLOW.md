# Git 分支合并流程

这个仓库当前建议按下面的顺序处理功能分支：

1. 切到主干。
2. 合并目标分支到 `main`。
3. 确认没有冲突并跑一次必要测试。
4. 删除已经完成且已合并的分支。

## 常用命令

```powershell
git switch main
git merge --no-ff dev-vless
git merge --no-ff dev-trojan
git branch -d dev-vless
git branch -d dev-trojan
```

## 处理原则

- 如果分支已经包含在主干里，优先删除分支，不再重复合并。
- 如果分支有冲突，先解决冲突再提交合并结果。
- 如果某个分支只是临时试验分支，合并后应尽快删除，保持主干清晰。