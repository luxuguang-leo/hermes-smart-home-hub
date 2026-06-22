---
name: home-hub
description: "Unified smart home hub — control Home Assistant, Apple devices (HomePod/Apple TV/AirPort Express), smart lights, robot vacuum, and door locks from a single skill. 智能家居统一控制入口。Also: 开灯, 关灯, 扫地, 广播, 查状态, 智能门锁, 智能家居中枢"
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [smart-home, home-assistant, homepod, apple-tv, smart-lights, robot-vacuum, automation]
    related_skills: [home-assistant, apple-homepod-control, apple-home-media]
---

# Home Hub — 智能家居统一控制

## Overview

整合三类智能家居系统到统一入口：

```
┌─────────────────────────────────────────────────────┐
│                     Home Hub                         │
│            (Hermes Agent + home-hub skill)           │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌──────────────┐  ┌───────────────┐  ┌───────────┐ │
│  │  HA Toolset   │  │  Apple pyatv  │  │  REST API │ │
│  │  (内置工具)    │  │  (本地发现)    │  │  (fallback)│ │
│  ├──────────────┤  ├───────────────┤  ├───────────┤ │
│  │ ha_list_     │  │  HomePod TTS  │  │ 扫地机器人│ │
│  │ entities     │  │  Apple TV     │  │ 智能灯    │ │
│  │ ha_call_     │  │  AirPort Expr │  │ 智能门锁  │ │
│  │ service      │  │  (RAOP音频)   │  │ 传感器    │ │
│  └──────┬───────┘  └───────┬───────┘  └─────┬─────┘ │
│         │                  │                │        │
│    ┌────┴──────────────────┴────────────────┴───┐   │
│    │              局域网 (同一子网)               │   │
│    └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 支持的设备类型

| 设备类别 | 控制方式 | 依赖 |
|---------|---------|------|
| **智能灯/开关** | HA `light` / `switch` domain | HA + HASS_TOKEN |
| **扫地机器人** | HA `vacuum` domain | HA (cloud integration) |
| **智能门锁** | HA `lock` / `binary_sensor` domain | HA |
| **传感器（温湿度等）** | HA `sensor` domain | HA |
| **HomePod / HomePod mini** | pyatv AirPlay/RAOP | macOS + pyatv |
| **AirPort Express** | pyatv RAOP (接音响时音质最佳) | macOS + pyatv |
| **Apple TV（配对后）** | pyatv Companion protocol | pyatv + tvOS 兼容 |
| **Apple TV 3（AirPlay 只读）** | pyatv AirPlay | pyatv |

## When to Use

- 用户说 **"开灯/关灯/调暗"** → HA `ha_call_service` with `light` domain
- 用户说 **"扫地/开始清扫/回充"** → HA `vacuum` domain
- 用户说 **"广播/播放到XX/通知"** → Apple TTS via pyatv RAOP
- 用户说 **"查状态/室温/湿度"** → HA `ha_list_entities` filter by domain
- 用户说 **"门口有没有人/门锁状态"** → HA `lock` / `binary_sensor` domain
- 用户说 **"全部设备状态"** → HA list + pyatv scan 聚合
- 用户说 **"XX灯/XX在哪个房间"** → `ha_list_entities` with area filter
- 用户说 **"智能家居" / "家电" / "home" / "房子"** → 加载本 skill

## Quick Start

### 0. Copy env config

```bash
cp .env.example .env
# Edit .env with your HA URL, token, and device IDs
```

Available env vars (see `.env.example`):

| Var | Purpose |
|-----|---------|
| `HASS_URL` / `HASS_TOKEN` | HA connection |
| `HASS_AUTH_STORAGE` | HA auth file path (auto-refresh) |
| `VACUUM_ENTITY` | Default vacuum entity_id |
| `HUB_TTS_SCRIPT` | TTS broadcast script path |

### 1. 启用内置 HA 工具集

```bash
hermes tools enable homeassistant
```

配置 `.env`:
```env
HASS_URL=http://homeassistant.local:8123
HASS_TOKEN=<your long-lived access token>
```

> `/reset` 后生效。

### 2. 配置 HA Token

生成 long-lived token: HA Web UI → 左下角用户名 → **安全** → **长期访问令牌** → 创建。

或在已有 HA 实例中从 auth storage 读取 refresh token：
```bash
python3 -c "
import json
with open('$HOME/homeassistant/config/.storage/auth') as f:
    auth = json.load(f)
for t in auth['data']['refresh_tokens']:
    if t.get('token_type') == 'normal':
        print(t['token'])
"
```

然后用 refresh token 换 access token（30 分钟有效）：
```bash
curl -s -X POST http://homeassistant.local:8123/auth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&client_id=http://homeassistant.local:8123/&refresh_token=<REFRESH_TOKEN>"
```

### 3. 广播到 HomePod / AirPort Express

> **重要：** 用 `tts_to_homepod.py`（来自 `apple-homepod-control` skill），**不要用** `atvremote --protocol raop stream_file`——CLI 有已知 bug。

```bash
# 广播到卧室 HomePod
python3 ~/.hermes/skills/smart-home/apple-homepod-control/scripts/tts_to_homepod.py '该起床了' 卧室

# 广播到客厅音响（重复3次）
python3 ~/.hermes/skills/smart-home/apple-homepod-control/scripts/tts_to_homepod.py '来客人了' 客厅 3
```

## Architecture

### 设备网络拓扑

```
                    ┌──────────────────────┐
                    │    路由器/网关         │
                    │  (DHCP, <gateway>)  │
                    └────────┬─────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                    │
    ┌─────┴─────┐    ┌──────┴──────┐    ┌───────┴──────┐
    │  HA 主机   │    │  Hermes主机  │    │ 其他设备     │
    │  Docker   │    │  (本机)      │    │ 扫地机器人   │
    │  HA容器   │    │  pyatv      │    │ 智能灯       │
    │           │    │  hub-ctl    │    │ 门锁         │
    └─────┬─────┘    └──────┬──────┘    └──────────────┘
          │                 │
    ┌─────┴─────┐    ┌──────┴──────┐
    │ HomePod   │    │ AirPort Exp │
    │ 卧室      │    │ 客厅(接功放) │
    │ 书房      │    │ → 书架箱    │
    └───────────┘    └─────────────┘
```

### 控制流

```
用户 → Hermes Agent → home-hub skill loaded
                        │
            ┌───────────┼────────────┐
            │           │            │
         HA工具集    Apple pyatv   REST API
         (内置)      (本地发现)    (fallback)
            │           │            │
            ▼           ▼            ▼
          HA容器    AirPlay设备    HA集成设备
                    (HomePod/ATV/  (扫地机/灯/
                     AirPort Expr)  门锁/传感器)
```

### 房间设备映射

用户需要建立自己的房间→设备映射表。推荐结构：

| 房间 | 设备 | AirPlay | HA entity |
|------|------|---------|-----------|
| **卧室** | HomePod | ✅ RAOP | — |
| **书房** | HomePod / 智能灯 | ✅ RAOP | `light.study` |
| **客厅** | AirPort Express / 扫地机器人 | ✅ RAOP | `vacuum.robot` |
| **客厅** | Apple TV / 智能灯 | ✅ AirPlay | `light.living` |
| **门口** | 智能门锁 | — | `lock.front_door` |
| **厨房** | 智能灯/传感器 | — | `sensor.temperature` |

> 具体 entity_id 以 `ha_list_entities` 实际返回为准。

## Workflows

### 场景 1：日常扫地 [硬约束]

扫地指令走 HA REST API，不要直连设备（云端集成更可靠）。

```bash
# 开始清扫
curl -X POST http://homeassistant.local:8123/api/services/vacuum/start \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"entity_id":"vacuum.<your_vacuum>"}'

# 回充（两步法更可靠）
# Step 1: 停止
curl -X POST .../vacuum/stop -d '{"entity_id":"vacuum.<your_vacuum>"}'
# Step 2: 命令充电
curl -X POST .../vacuum/send_command \
  -d '{"entity_id":"vacuum.<your_vacuum>","command":"app_charge"}'
```

### 场景 2：语音广播 [硬约束]

广播走三步骤管道：`say` 生成 AIFF → `ffmpeg` 转 WAV + 3x 音量 → `pyatv stream.stream_file()` 并发投送。

```python
import asyncio, subprocess, tempfile, os
from pyatv import scan, connect

async def broadcast(text, room_ips):
    # 1. TTS via macOS say
    aiff = tempfile.NamedTemporaryFile(suffix=".aiff", delete=False).name
    subprocess.run(["say", "-o", aiff, text])
    # 2. Convert to WAV + volume boost (3x)
    wav = aiff.replace(".aiff", ".wav")
    subprocess.run(["ffmpeg", "-y", "-i", aiff,
        "-af", "volume=3.0",
        "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2", wav])
    os.unlink(aiff)
    # 3. Concurrent streaming to all target devices
    async def to_device(ip):
        for _ in range(5):
            for d in await scan(asyncio.get_event_loop(), timeout=10):
                if d.address == ip:
                    atv = await connect(d, asyncio.get_event_loop())
                    await atv.stream.stream_file(wav)
                    atv.close(); return
            await asyncio.sleep(1)
    await asyncio.gather(*[to_device(ip) for ip in room_ips])
    os.unlink(wav)

# Usage: asyncio.run(broadcast("早上好", ["target_ips_from_pyatv_scan"]))
```

### 场景 3：全屋状态查询

```python
# 1. HA 状态：列出关键设备
# ha_list_entities(domain="vacuum")  + (domain="light") + (domain="lock") + (domain="sensor")

# 2. AirPlay 设备状态
from pyatv import scan
import asyncio
async def get_airplay():
    devices = await scan(asyncio.get_event_loop(), timeout=10)
    for d in devices:
        print(f"{d.name} ({d.address}): {d.model}")
asyncio.run(get_airplay())
```

## Triggers (中文命令映射)

| 用户说 | 执行 | 模块 |
|--------|------|------|
| "扫地/开始扫" | `ha_call_service(vacuum/start, entity_id)` | HA |
| "停/回来/回充" | `vacuum/stop` + `send_command(app_charge)` | HA |
| "吸力调到XX" | `vacuum/set_fan_speed` | HA |
| "找到机器人/叫一下" | `vacuum/locate` | HA |
| "开XX灯" | `ha_call_service(light/turn_on, entity_id)` | HA |
| "关XX灯" | `ha_call_service(light/turn_off, entity_id)` | HA |
| "全部灯关了" | `ha_list_entities(domain=light)` + 逐关 | HA |
| "调暗XX到50%" | `ha_call_service(light/turn_on, brightness=127)` | HA |
| "门锁了没/门口状态" | `ha_get_state(lock.*)` / `(binary_sensor.door*)` | HA |
| "室温/温度/湿度" | `ha_get_state(sensor.temperature*)` | HA |
| "广播 [内容]" | `say → ffmpeg → RAOP stream` | Apple |
| "播放到XX [内容]" | 同上，指定房间 | Apple |
| "叫醒/闹钟" | 广播到卧室 HomePod | Apple |
| "查XX状态" | `ha_get_state(entity_id)` | HA |
| "我家有什么设备" | `ha_list_entities()` | HA |
| "查看设备清单" | `hub-ctl status` | All |

## Common Pitfalls

1. **[硬约束] Docker 无法 mDNS 发现** — HA 在 Docker Desktop 中收不到 mDNS 广播。Apple 设备发现和控制必须在宿主机上运行，不要在 Docker 内执行。
2. **[硬约束] pyatv stream_file CLI 有 bug** — `atvremote --protocol raop stream_file` 报 `IndexError`。永远用 Python API（`scripts/tts_to_homepod.py`）。
3. **[硬约束] HA token 30分钟过期** — 每次 batch 操作前刷新。用 refresh token 换 access token，不要存 hardcoded access token。
4. **[推荐] 广播用 macOS `say` 命令** — 比 text_to_speech 工具更可靠，不受网络影响。
5. **[推荐] RAOP 广播音量需 3x 增益** — 默认音量在 HomePod 上太小，用 ffmpeg `-af volume=3.0`。
6. **[发挥] mDNS 扫描有 ~50% 失败率** — 至少重试 3-5 次，间隔 1s。
7. **扫地机回充用 `app_charge` 更可靠** — `return_to_base` 可能不触发充电，`send_command(app_charge)` 更稳定。
8. **pyatv 设备名 ≠ 房间名** — mDNS 返回的名称可能是自动生成的（如 "Living Room"），跟实际位置不匹配。需要扫描后手动映射 IP→房间。
9. **HomePod 不需要配对** — AirPlay/RAOP 配对状态为 NotNeeded，无需额外配。
10. **AirPort Express 接音响时音质最佳** — 有源音响/AirPort + 功放 + 书架箱通常是客厅广播首选。
11. **Apple TV (新款) + tvOS 18 不可配对** — pyatv 0.17.0 与 tvOS 18 存在 SRP M4 协议不兼容，等待 pyatv 更新。
12. **扫地机在勿扰时段可能不响应** — 部分品牌默认 22:00-07:00 禁止远程指令。

## Verification Checklist

- [ ] `hermes tools enable homeassistant` 已执行
- [ ] `HASS_URL` 和 `HASS_TOKEN` 已配在 `.env`
- [ ] HA 可访问：`curl http://homeassistant.local:8123/api/states -H "Authorization: Bearer <token>"`
- [ ] 至少一台 AirPlay 设备可接收广播
- [ ] `tts_to_homepod.py` 脚本在 `apple-homepod-control` skill 中存在
- [ ] `hub-ctl` 可执行：`bash scripts/hub-ctl help`
- [ ] ROOMS 数组已配置（编辑 `scripts/hub-ctl` 顶部）
- [ ] 已建立房间→设备→IP 映射表
- [ ] `/reset` 后 `ha_list_entities` 可用
