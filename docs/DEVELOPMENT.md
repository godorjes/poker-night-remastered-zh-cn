# 开发与重新构建

玩家直接下载 Releases 的 Windows ZIP；本页仅供维护者。

## 环境与输入

- Windows 10/11，自带 Windows PowerShell 5.1；维护工具还需 Python 3.10+。
- 自有的 Steam 重制版游戏，当前 build 25257439；原版资源指纹见 compatibility/base-game.json。
- 另外准备 TTG Tools v1.16.1，工具不随本项目分发：https://github.com/HeitorSpectre/TTG-Tools
- Noto Sans SC Regular/Bold 构建字体已位于 assets/fonts，许可见 licenses。

## 修改译文并构建资源

编辑 translations/catalog.tsv 的 chinese 列，保留 file、id、actor、english、source_sha256；不要修改占位符、动画/表情、字体标记及屏蔽星号。translations/review 是本次初译和复核的历史快照，不会自动覆盖之后人工修订的主表。

```powershell
python tools/build_mod.py --game-dir "F:/SteamLibrary/steamapps/common/Poker Night at the Inventory Remastered" --ttg-dir "F:/Tools/TTG Tools v1.16.1"
```

上面的两个路径是示例，请替换为本机目录。也可用 --work-dir 指定独立工作区；默认在仓库 .work 中构建。脚本只读取自有游戏资源，不安装模组或改写原版归档。

开发脚本需要从固定的 TTG Tools 官方源码提交读取资源格式参数，首次运行会下载 MainMenu.cs 并验证 SHA256，仅将其作为数据解析，不执行下载内容。离线构建可通过 --key-source 指定相同版本的本地 MainMenu.cs。固定提交及哈希见 compatibility/ttg-source.json，参数不会写到日志。

依次执行：核对原版 16 个文件指纹 → 导出 27 份非空文字库和特殊对白源 → 回填当前译文 → 校验标记和字形 → 构建 Common/Boot 资源包 → 重读全部 37 个资源及 Lua 描述文件。27 份文字库导入后会再导出逐项比较，56 条特殊对白也会单独回读。

输出资源在 .work/Probes/F_FullTextDraft/Package/Archives，构建报告在同一阶段的 build-verification.json。showdown_english.landb 原文为空，不另行生成汉化内容。default.font 为位图字体，本次不替换。

## 打包玩家 ZIP

```powershell
python build_release.py --payload-dir .work/Probes/F_FullTextDraft/Package/Archives --output-dir dist --font-license licenses/OFL.txt --font-notice licenses/Noto-Copyright.txt --known-manifest compatibility/known-mods.json
```

发布前重新运行安装器测试，并在独立目录测试最终解压包的安装、重复安装和卸载；随后在游戏中验收。未来修改版本时同步更新 manifest 支持的 build、兼容指纹和发布说明，不能仅放宽版本检查。

## 安装器测试

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Installer.Tests.ps1 -TestRoot F:/tmp/pn-cn-tests
```

TestRoot 选择本机可写且较短的临时路径；测试只生成独立假 Steam 库，不安装或启动真实游戏。覆盖中文/空格/方括号/& 路径、重复安装、资源损坏、同名冲突、版本拒绝、升级、回滚、Steam 多库识别、占用配置容错及并发互斥。

游戏原始归档、解包资源、工具安装包、个人日志和缓存不进 Git；维护源码、译文、字体许可及校验元数据在仓库，预构建玩家包通过 Releases 分发。
