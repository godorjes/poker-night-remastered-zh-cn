# 怪诞扑克夜 重制版简体中文汉化 v0.2.1

适用于 Steam《Poker Night at the Inventory Remastered》（怪诞扑克夜 重制版），AppID 3897800，build 25257439，Windows 10/11。

## 安装：把英文界面和字幕替换为中文

1. 完全退出游戏。
2. 完整解压 PokerNight-CN-v0.2.1-Windows.zip，不要直接在压缩包预览里运行单个 CMD。
3. 双击 Install.cmd。
4. 程序自动查找 Steam 游戏；找不到或有多个安装目录时，选择包含 CelebrityPoker.exe 和 Archives 的游戏根目录。
5. 提示安装成功后，从 Steam 正常启动游戏，在设置里开启“字幕／Subtitles”。

只需安装一次，以后直接从 Steam 启动即可。玩家不需要 Python、TTG Tools、Git，也不需要额外安装字体。

查看游戏目录：Steam 库右键游戏 → 管理 → 浏览本地文件。

## 恢复英文、重复安装与更新

退出游戏后双击 Uninstall.cmd，即可移除本包的已知模组文件。原版游戏归档、其他模组和存档保持不变。

相同版本重复安装不会重复复制；更新汉化时下载新包，退出游戏后运行新包的 Install.cmd。遇到同名未知文件会停止，避免覆盖自己的修改。

## 常见问题

- 游戏仍在运行：完全退出后重试。
- 文件校验失败：重新下载并完整解压，保留整个文件夹结构。
- 提示拒绝访问：右键 Install.cmd（卸载为 Uninstall.cmd），以管理员身份运行。通常无需管理员权限。
- 另一个安装器正在运行：等待它结束，不要反复双击。
- 游戏版本不匹配：等待对应版本的汉化；旧汉化仍可正常卸载。
- 路径过深导致读写失败：把解压目录放到较短的路径后重试。
- 系统策略阻止脚本：可以采用下方手动复制方法，无需永久更改系统执行策略。

## 手动安装和卸载

确认版本匹配并退出游戏，把本包 Archives 内四个文件一起复制到游戏 Archives 中。已有同名文件时，先确认它们是否为本项目旧版本。

只删除下面四个文件可手动恢复英文：

CP_pc_Boot_CNProbeBoot.ttarch2
CP_pc_Common_CNProbe.ttarch2
_resdesc_50_Boot_CNProbeBoot.lua
_resdesc_50_Common_CNProbe.lua

不要删除整个 Archives 文件夹或任何原版归档。

## 当前覆盖与已知问题

已处理 4,614 条文本记录，覆盖对白、菜单、牌型、统计和解锁等；部分专名和引擎注记保留原文。Play Game、Continue、New Game 按钮和 Logo 是贴图，目前保留英文，语音未修改。

已有本机启动测试反馈，完整剧情语境、各界面布局和不同分辨率仍欢迎校对。字体替换会改变部分英文外观。

## 下载、反馈与字体许可

项目：https://github.com/godorjes/poker-night-remastered-zh-cn
下载：https://github.com/godorjes/poker-night-remastered-zh-cn/releases/latest
反馈：https://github.com/godorjes/poker-night-remastered-zh-cn/issues

反馈时请附汉化版本、游戏 build、页面／角色及问题文字或截图，不要上传存档、认证信息或个人文件。

字体声明和 SIL Open Font License 1.1 见 licenses 目录。原始游戏内容归相应权利人所有，本包为社区简体中文汉化。
