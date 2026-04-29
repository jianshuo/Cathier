---
name: baixing-agent-cli
description: Installs baixing-agent-cli from the npm registry only (command `baixing`), then runs Baixing HTTP APIs—init UUID, post, posts, search, detail—and parses stdout/stderr and exit codes per the CLI contract. Does not assume a private source checkout. Use when integrating agents or scripts with baixing-agent-cli, BX_CONFIG_PATH, or Baixing neo/search/fabu APIs from the terminal.
---

# baixing-agent-cli 使用说明（Agent）

百姓网 HTTP API 的薄 CLI，入口命令为 **`baixing`**（npm 包名 **`baixing-agent-cli`**）。若环境中还有 PHP 站内 CLI（如 `cli.php`），与本 npm 包**无关**——本包只调对外 HTTP 接口。

## 前置条件

- **Node.js 18+**（`fetch`、`crypto.randomUUID`）

## 安装

**唯一对外安装方式**：从 **[npm](https://www.npmjs.com/package/baixing-agent-cli)** 安装（勿假定存在私有源码仓库）。

全局安装后命令名为 **`baixing`**：

```bash
npm install -g baixing-agent-cli
baixing --help
```

不需要全局安装时可用 **`npx`**（同样调用 **`baixing`**）：

```bash
npx baixing-agent-cli --help
```

## Agent 必须遵守的契约

### 调用形式

```text
baixing [全局选项] <子命令> [子命令选项] [子命令参数]
```

- 全局选项：**`-v` / `--verbose`**（调试信息打到 **stderr**，不改变 stdout JSON）。
- **API 根 URL**：内置默认 **`https://www.baixing.com`**。一般用法**不要**要求用户设置环境变量；仅在对接镜像/预发等场景才需要 **`BX_API_BASE_URL`** 或 **`init --base-url`**。优先级：**环境变量 `BX_API_BASE_URL` > 配置文件 `baseUrl` > 默认**。

### stdout / stderr

| 流 | 用途 |
|----|------|
| **stdout** | 成功时的主结果：`init` 成功时为一行 uuid；其余成功子命令多为 **格式化 JSON**（`JSON.stringify(..., null, 2)`），可对**整段 stdout** `JSON.parse`。`post --dry-run` 亦为 JSON（含 `_baseUrl`）。 |
| **stderr** | 人类可读提示与错误；**`-v`** 时含 HTTP 方法与大致 URL。**不要**把 stderr 当 API 响应解析。 |

**建议**：成功路径只解析 **stdout**；失败时读 **stderr** 文本。

### 退出码

| 码 | 含义 |
|----|------|
| **0** | 成功（含「已有 uuid 未 force 仍打印已有 uuid」）。 |
| **1** | 失败：参数、网络、非 2xx、JSON 解析失败，或业务 JSON 中 `code !== 0`。 |

**必须**用退出码判断成败，不能仅凭 stdout 是否非空。

### 稳定性与容错

- 优先使用**长选项**（如 `--dry-run`、`--base-url`）作为稳定契约。
- 响应 JSON 结构由服务端决定；解析时应容错未知字段。

## 推荐自动化流程

1. **`baixing init`**（覆盖旧 uuid：**`baixing init --force`**）；从 stdout 取 uuid 或依赖写入后的配置。
2. **`baixing post -t "<标题>" -c "<正文>"`**；对接前可用 **`baixing post ... --dry-run`**。
3. **`baixing posts`** 或 **`baixing posts --uuid <id>`**。
4. **`baixing search <关键词...>`**（多词空格分隔；整句含空格时对参数加引号）。
5. 从 **`search` / `posts`** 的 **`data.items[].adId`** 取 ID，执行 **`baixing detail <adId>`**。

多进程/多租户：为不同进程设置不同 **`BX_CONFIG_PATH`**，避免互相覆盖 uuid 配置。

## 子命令速查

| 子命令 | 作用 | 要点 |
|--------|------|------|
| **`init`** | 生成 UUID v4 写入配置 | **`--base-url` 可选**（默认即生产根 URL）；**`--force`**；已有 uuid 且无 `-f` 时 stderr 提示、stdout 仍为 uuid、退出 0 |
| **`post`** | `POST /neo/fabu/neoPost` | **`-t`、`-c` 必填**；`--uuid`、`--dry-run` |
| **`posts`** | `GET /neo/queryByUuid` | `--uuid`、`-p/--page`、`-s/--size`（页码从 1） |
| **`search`** | `GET /neo/search` | 关键词为参数；无关键词则退出 1 |
| **`detail`** | `GET /neo/detail/<adId>` | `adId` 为非空数字串，来自列表里的 **`adId`** |

## 环境变量

| 变量 | 说明 |
|------|------|
| **`BX_API_BASE_URL`** | **可选**。未设置时使用默认 **`https://www.baixing.com`**。只有需要指向非生产根地址时才设置；设置后覆盖配置文件里的 `baseUrl`。Agent 默认流程中**不应**向用户索要此项。 |
| **`BX_CONFIG_PATH`** | **可选**（多实例/CI 时用）。配置文件**绝对路径**；未设置时默认 `~/.config/baixing-agent/config.json`（Windows 路径见 npm 包 README）。 |

## 完整文档

选项表、边界行为与发布说明见 [reference.md](reference.md)。
