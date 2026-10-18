# 怪诞扑克夜 重制版中文汉化 · Poker Night at the Inventory Remastered

**《怪诞扑克夜》简体中文汉化补丁**，适用于 Steam 重制版 **Poker Night at the Inventory Remastered**。

Poker Night Remastered Chinese translation / Simplified Chinese localization mod / zh-CN patch.

[下载 Windows 汉化安装包 v0.2.1](https://github.com/godorjes/poker-night-remastered-zh-cn/releases/download/v0.2.1/PokerNight-CN-v0.2.1-Windows.zip) · [查看最新版本](https://github.com/godorjes/poker-night-remastered-zh-cn/releases/latest) · [报告问题](https://github.com/godorjes/poker-night-remastered-zh-cn/issues/new/choose)

## 下载哪个文件？

玩家请下载 Releases 中的 **`PokerNight-CN-v0.2.1-Windows.zip`**。

GitHub 的 **Code → Download ZIP**、**Source code (zip)** 以及名称带 **Source** 的文件都是源码，不能直接完成汉化安装。玩家安装包已经包含中文资源和字体，不需要 Python、TTG Tools 或 Git。

## 如何把游戏英文替换成中文？

1. **完全退出游戏**。
2. 下载 Windows 汉化包，将 **整个 ZIP 完整解压**到一个文件夹。不要只从压缩包里拖出单个 CMD。
3. 双击 **`Install.cmd`**。
4. 安装器会自动寻找 Steam 游戏目录；找不到或有多个位置时，手动选择包含 **`CelebrityPoker.exe`** 和 **`Archives`** 的游戏文件夹。
5. 看到“汉化安装成功”后，从 **Steam 正常启动游戏**。在设置里开启 **字幕（Subtitles）**。

**只需安装一次。以后直接从 Steam 启动游戏，不用每次运行 CMD。**

不清楚游戏目录时：在 Steam 库右键《怪诞扑克夜》→ **管理 → 浏览本地文件**。

安装器会向游戏 `Archives` 放入四个汉化模组文件，游戏加载这些资源后显示中文；原版游戏归档和存档不需要覆盖或删除。

## 卸载和更新

- **恢复英文**：退出游戏，运行解压目录中的 **`Uninstall.cmd`**。
- **更新汉化**：退出游戏，下载并解压新版本，运行新包的 **`Install.cmd`**。
- 已安装相同版本时，会提示无需重复安装。
- 检测到来源未知或自己修改过的同名文件时会停止，避免覆盖个人修改。

卸载脚本仅删除本项目已知的四个模组文件；原版游戏文件、其他模组和存档保持不变。

## 适用版本

| 项目 | 当前支持情况 |
| --- | --- |
| 游戏 | Poker Night at the Inventory Remastered／怪诞扑克夜 重制版 |
| 平台 | Windows 10/11，Steam 版 |
| Steam AppID | `3897800` |
| 已验证 build | `25257439` |
| 汉化包 | `v0.2.1` |
| 2010 年原版、其他平台 | 未验证，请勿套用 |

游戏更新后不一定立即失效，但需要重新确认文字资源和加载方式是否兼容。当前安装器仅接受上表 build；卸载旧汉化不受这个版本限制。

## 汉化范围与当前状态

- 文字主表共 **4,614 条记录**，包括对白、菜单、牌型、统计、解锁项目和特殊粗口对白。
- 其中 4,553 条为中文初译，51 条专名、符号或引擎注记有意保留，10 条原文为空；不等于 4,614 条独立对白。
- 保留文本 ID、角色、动画/表情标记、替换参数、换行及粗口屏蔽星号。
- 包含中文字体，已验证菜单中文字形、字幕显示和样例长句自动换行。
- 完整资源包已有本机启动测试反馈；全部对白语境、各页面及不同分辨率仍欢迎校对反馈。
- 安装器通过 17 项行为测试，并对最终解压包执行完整安装、重复安装、卸载和重复卸载校验。

**仍为英文的内容**：`Play Game`、`Continue`、`New Game` 按钮及标题 Logo 属于贴图，目前尚未汉化。原语音不变。替换字体后，英文笔画风格可能与原版不同。

## 常见问题

**提示“游戏运行中”**：完全退出游戏后重试；不要只切回桌面。

**没有找到游戏**：通过 Steam“浏览本地文件”确定目录，再手动选择游戏文件夹。选择游戏根目录即可，不需要选择 Steam 主目录。

**提示资源缺失或校验失败**：重新下载 Windows 安装包并完整解压，保留 `Install.cmd`、`scripts`、`manifest.json` 和 `Archives` 的相对位置。

**没有写入权限**：通常直接运行即可；确实提示拒绝访问时，右键 `Install.cmd`（卸载时为 `Uninstall.cmd`）→ **以管理员身份运行**。

**重复双击安装器**：同一游戏目录同时只允许一个安装或卸载进程运行，等待前一个结束即可。

**版本不匹配**：请等待对应版本的汉化，不要仅修改版本号绕过检查。

**脚本被系统策略阻止**：可以使用下面的手动安装方式。无需永久修改系统 PowerShell 执行策略。

## 手动安装或卸载

先退出游戏，并确认游戏版本与本包匹配。将安装包 `Archives` 内以下四个文件 **一起复制**到游戏的 `Archives` 文件夹。如果已有不明来源的同名文件，请先核对归属。

```text
CP_pc_Boot_CNProbeBoot.ttarch2
CP_pc_Common_CNProbe.ttarch2
_resdesc_50_Boot_CNProbeBoot.lua
_resdesc_50_Common_CNProbe.lua
```

手动恢复英文时，仅删除这四个汉化文件，**不要删除整个 Archives 文件夹，也不要删除原版归档**。

## 项目内容与维护

| 位置 | 内容 |
| --- | --- |
| `translations/catalog.tsv` | 英文／中文主表、文件名、真实 ID、角色、原文哈希和状态 |
| `translations/GLOSSARY.md` | 用词和翻译风格约定 |
| `translations/review/` | 本次初译分批结果、复核修订与结构审计快照 |
| `scripts/` | 玩家通用安装器与卸载逻辑 |
| `tests/` | 安装器行为测试，不依赖 Pester |
| `tools/` | 从自有游戏资源导出文字、回填译文和构建模组的开发脚本 |
| `assets/fonts/`、`licenses/` | 构建所用中文字体、字体许可与版权声明 |
| `compatibility/` | 已知模组哈希、原版资源指纹和工具源码校验信息 |
| `docs/` | 玩家指南、开发流程、发布记录和校验范围 |
| GitHub Releases | 玩家安装 ZIP、源码快照及 SHA256 校验文件 |

[玩家安装说明](docs/INSTALL.md) · [开发与重新构建](docs/DEVELOPMENT.md) · [版本记录](CHANGELOG.md) · [第三方声明](THIRD-PARTY-NOTICES.txt)

## 反馈和参与校对

发现问题请提交 Issue，附上汉化版本、游戏 build、所在页面或说话角色、问题文字／截图，以及是否启用其他模组。请勿上传存档、认证信息或个人文件。

这是《怪诞扑克夜》的社区中文汉化项目。游戏名称、角色、原始对白及其他原作内容归相应权利人所有；中文字体遵循对应 OFL 许可，第三方材料不因收录于本项目而改变许可。

相关名称与检索关键词：**怪诞扑克夜 中文汉化、怪诞扑克夜汉化补丁、怪诞扑克夜重制版汉化、Poker Night at the Inventory 汉化、Poker Night Remastered 中文、Poker Night at the Inventory Remastered Chinese translation、Simplified Chinese patch、zh-CN localization**。
