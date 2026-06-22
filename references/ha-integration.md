# Home Assistant Integration

## 内置工具集

Hermes 自带 `homeassistant` 工具集（4个 LLM 可用工具）：

| 工具 | 功能 | 参数 |
|------|------|------|
| `ha_list_entities` | 列出/筛选设备 | `domain` (opt), `area` (opt) |
| `ha_get_state` | 查单个设备详情 | `entity_id` (req) |
| `ha_list_services` | 列出可用服务 | — |
| `ha_call_service` | 调用服务 | `domain`, `service`, `entity_id`, `data` |

### 启用

```bash
hermes tools enable homeassistant
```

### 配置（.env）

```env
HASS_URL=http://homeassistant.local:8123
HASS_TOKEN=*** long-lived>
```

> `/reset` 后生效。

### 生成 Long-Lived Token

HA Web UI → 左下角用户名 → `安全` → `长期访问令牌` → 创建。

## REST API（Fallback / 高级操作）

当内置工具集未启用或需要 HA 不直接暴露的操作时，直接 curl HA API：

### Token 管理

HA access token 30 分钟过期。用 refresh token 换新的：

```bash
# 从 .storage/auth 取 refresh token
python3 -c "
import json
with open('<ha-config-dir>/.storage/auth') as f:
    auth = json.load(f)
for t in auth['data']['refresh_tokens']:
    if t.get('token_type') == 'normal':
        print(t['token'])
        break
"

# 换 access token
curl -s -X POST http://homeassistant.local:8123/auth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&client_id=http://homeassistant.local:8123/&refresh_token=TOKEN"
```

### 常用 API

```bash
# 列出所有设备
curl -s http://homeassistant.local:8123/api/states -H "Authorization: Bearer $TOKEN"

# vacuum 相关
curl -s http://homeassistant.local:8123/api/states/vacuum.your_vacuum -H "Authorization: Bearer $TOKEN"

# 调用服务
curl -s -X POST http://homeassistant.local:8123/api/services/vacuum/start \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id":"vacuum.your_vacuum"}'
```

### 扫地机器人

**entity_id:** `vacuum.your_vacuum`

| Service | 作用 | 额外参数 |
|---------|------|---------|
| `vacuum/start` | 开始清扫 | — |
| `vacuum/pause` | 暂停 | — |
| `vacuum/stop` | 停止 | — |
| `vacuum/return_to_base` | 回充（可能不触发） | — |
| `vacuum/send_command` | 自定义命令 | `command: app_charge` (更可靠的回充) |
| `vacuum/locate` | 发出蜂鸣声 | — |
| `vacuum/set_fan_speed` | 调吸力 | `fan_speed: turbo` |

吸力等级：`quiet`, `balanced`, `turbo`, `max`, `max_plus`, `smart_mode`

**回充推荐方法（两步）：**
1. `vacuum/stop` → 等待 2s
2. `vacuum/send_command` with `{"command": "app_charge"}`

## 已知限制

- **Docker mDNS 不可达** — HA 在 Docker Desktop 中无法发现 Apple 设备。Apple 集成必须在 Mac 宿主机上用 pyatv
- **HA token 30 分钟过期** — 每次 batch 操作前刷新
- **本地端口可能闲置时关闭** — 只能走 HA cloud 集成，不能本地直连
- **部分机型在勿扰时段 (22:00-07:00) 不接受指令**
