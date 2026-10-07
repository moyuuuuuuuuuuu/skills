# Shared Skills

可跨项目复用的 Codex Skills。

| Skill | 用途 |
| --- | --- |
| [api-development](api-development/SKILL.md) | API 行为与合同修改、授权边界、验证和文档同步 |
| [git-publish](git-publish/SKILL.md) | 限定范围的 Git 提交、推送和合并 |
| [show-me](show-me/SKILL.md) | 使用流程图、调用树和 HTML 解释逻辑 |
| [apipost-openapi-docs](apipost-openapi-docs/SKILL.md) | ApiPost 接口文档管理和同步 |
| [qishui-music-reward-loop](qishui-music-reward-loop/SKILL.md) | 循环领取汽水音乐免费听视频奖励，取消自动进入直播间，并按次数或时长停止；支持可操作的手机投屏 |

## 使用

将需要的完整 Skill 目录复制到目标项目的 `.agents/skills/`，或个人的 `~/.codex/skills/`。保留目录中的 `agents`、`references` 和 `scripts` 等配套文件。

各 Skill 遵循目标项目的 `AGENTS.md` 和专项规则。ApiPost 连接配置通过环境变量提供，不在仓库中保存凭据。
