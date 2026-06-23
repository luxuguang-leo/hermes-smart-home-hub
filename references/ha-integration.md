# Home Assistant Integration

## Built-in Toolset

Hermes ships with the `homeassistant` toolset (4 LLM-available tools):

| Tool | Function | Parameters |
|------|----------|------------|
| `ha_list_entities` | List / filter entities | `domain` (opt), `area` (opt) |
| `ha_get_state` | Get a single entity state | `entity_id` (req) |
| `ha_list_services` | List available services | — |
| `ha_call_service` | Call a service | `domain`, `service`, `entity_id`, `data` |

### Enable

```bash
hermes tools enable homeassistant
```

### Configuration (.env)

```env
HASS_URL=http://homeassistant.local:8123
HASS_TOKEN=<your long-lived token>
```

> Takes effect after `/reset`.

### Generate a Long-Lived Token

HA Web UI → bottom-left user menu → **Security** → **Long-Lived Access Tokens** → Create.

## REST API (Fallback / Advanced)

When the built-in toolset is unavailable or you need direct HA API access:

### Token Management

HA access tokens expire every 30 minutes. Use a refresh token to renew:

```bash
# Extract refresh token from .storage/auth
python3 -c "
import json
with open('<ha-config-dir>/.storage/auth') as f:
    auth = json.load(f)
for t in auth['data']['refresh_tokens']:
    if t.get('token_type') == 'normal':
        print(t['token'])
        break
"

# Exchange for an access token
curl -s -X POST http://homeassistant.local:8123/auth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&client_id=http://homeassistant.local:8123/&refresh_token=TOKEN"
```

### Common API Calls

```bash
# List all entities
curl -s http://homeassistant.local:8123/api/states -H "Authorization: Bearer *** vacuum state
curl -s http://homeassistant.local:8123/api/states/vacuum.your_vacuum -H "Authorization: Bearer *** call a service
curl -s -X POST http://homeassistant.local:8123/api/services/vacuum/start \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  -d '{"entity_id":"vacuum.your_vacuum"}'
```

### Robot Vacuum

**entity_id:** `vacuum.your_vacuum`

| Service | Action | Extra params |
|---------|--------|-------------|
| `vacuum/start` | Start cleaning | — |
| `vacuum/pause` | Pause | — |
| `vacuum/stop` | Stop | — |
| `vacuum/return_to_base` | Return to dock (may not trigger) | — |
| `vacuum/send_command` | Custom command | `command: app_charge` (more reliable return) |
| `vacuum/locate` | Beep to locate | — |
| `vacuum/set_fan_speed` | Set suction power | `fan_speed: turbo` |

Fan speed levels: `quiet`, `balanced`, `turbo`, `max`, `max_plus`, `smart_mode`

**Recommended return-to-dock sequence (two steps):**
1. `vacuum/stop` → wait 2s
2. `vacuum/send_command` with `{"command": "app_charge"}`

## Known Limitations

- **Docker mDNS unreachable** — HA inside Docker Desktop cannot discover Apple devices. Apple integration must run on host macOS via pyatv
- **HA token expires every 30 min** — Refresh before each batch operation
- **Local port may be closed when idle** — Fall back to HA cloud integration only, no direct local connection
- **Some devices reject commands during do-not-disturb hours (22:00-07:00)**
