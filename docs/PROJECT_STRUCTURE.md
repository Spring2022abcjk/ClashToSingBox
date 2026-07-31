# ClashToSingBox 项目结构标准

这个仓库是一个 PowerShell 模块项目，整理标准优先保证三件事：源码边界清晰、测试数据可追踪、生成产物不污染仓库根目录。

## 推荐目录职责

- `ClashToSingBox.psd1`：模块清单，声明版本、RootModule、导出函数和 PSResource 元数据
- `ClashToSingBox.psm1`：模块入口，只负责加载顺序和导出公开命令
- `Classes/`：共享类型定义，例如配置对象和结果对象
- `Private/`：内部实现，包含 Parser、Validator 路由、共享校验、协议 validator、Converter 等核心逻辑
- `Public/`：对外导出的命令入口
- `tests/unit/`：单元测试，直接验证私有函数和核心逻辑
- `tests/integration/`：集成测试，验证完整输入到输出链路
- `test-inputs/`：稳定的测试输入样例
- `test-outputs/`：测试期望输出或快照基线
- `outputs/`：手工运行或临时生成的结果文件
- `docs/`：架构、重构计划、目录说明和维护规则

## 当前仓库的整理原则

1. 运行时源码只保留在模块相关目录，不把实现分散到根目录。
2. 文档统一归到 `docs/`，根目录只保留少量入口文件。
3. 测试输入和测试输出分开管理，避免把“样例”和“生成物”混在一起。
4. `outputs/` 只作为临时结果区使用，不作为主要文档区。
5. 新增协议时，优先新增 `Private/Validators/` 下的协议 validator，接入 `Private/Validator.ps1` 路由，再修改 `Private/Converter.ps1` 和对应测试。

## 建议的长期目标结构

```text
ClashToSingBox/
├── Classes/
├── Private/
├── Public/
├── tests/
│   ├── unit/
│   └── integration/
├── test-inputs/
├── test-outputs/
├── outputs/
├── docs/
├── ClashToSingBox.psd1
└── ClashToSingBox.psm1
```

## 维护建议

- 新增说明文档时，优先放进 `docs/`，不要继续在根目录堆新的 markdown。
- 新增测试样例时，输入放 `test-inputs/`，期望输出放 `test-outputs/`。
- 手工转换结果如果只是临时验证，放 `outputs/`，验证完可以清理。
- 如果某个目录长期只放过渡文件，后续应考虑并入 `docs/` 或 `tests/`。
