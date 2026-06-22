# Device Room Mapping

## Naming Convention Template

After scanning with `hub-ctl airplay scan` or `ha_list_entities`, map your devices to rooms:

| Room | Device | Location Notes |
|------|--------|----------------|
| `bedroom` | HomePod mini | Nightstand, for alarms/reminders |
| `study` | HomePod | Desk, daily broadcasts |
| `living` | AirPort Express + amp + speakers | TV cabinet, best audio quality |
| `living` | Smart light | Main ceiling light |
| `front_door` | Smart lock | Entry door |

## mDNS Discovery Names

> pyatv returns auto-generated names that may not match room locations.
> After scanning, map IPs to rooms manually.

| Scan Name Pattern | Likely Device | Protocol |
|-------------------|--------------|----------|
| Generic name (e.g. "Living Room", "Kitchen") | HomePod / HomePod mini | AirPlay/RAOP |
| Serial-style name (device ID string) | Apple TV | AirPlay/Companion |
| Custom name + "AirPort Express" | AirPort Express | AirPlay/RAOP |

## HA entity_id Naming Convention

> Actual entity_ids depend on HA integration. Use `ha_list_entities` to discover yours.

| Device | Common entity_id pattern | domain |
|--------|-------------------------|--------|
| Robot vacuum | `vacuum.robot_vacuum` | vacuum |
| Vacuum map | `image.vacuum_map` | image |
| Vacuum status | `sensor.vacuum_error` | sensor |
| Living room light | `light.living_room` | light |
| Temperature sensor | `sensor.temperature_living` | sensor |
| Humidity sensor | `sensor.humidity_living` | sensor |

## Room Name Reference

Choose your own naming scheme. Common examples:

```
bedroom, study, living, kitchen, dining, hallway, bathroom, storage
```
