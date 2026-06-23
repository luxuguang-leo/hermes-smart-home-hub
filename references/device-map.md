# 设备房间映射

## 命名约定模板

用 `hub-ctl airplay scan` 或 `ha_list_entities` 扫描后，将设备映射到房间：

| 房间 | 设备 | 位置说明 |
|------|------|---------|
| `bedroom` | HomePod mini | 床头柜，用于闹钟/提醒 |
| `study` | HomePod | 书桌，日常广播 |
| `living` | AirPort Express + 功放 + 音箱 | 电视柜，最佳音质 |
| `living` | 智能灯 | 主吊灯 |
| `front_door` | 智能门锁 | 入户门 |

## mDNS 发现名称

> pyatv 返回自动生成的名字，不一定匹配房间位置。
> 扫描后需手动将 IP 映射到房间。

| 扫描名称模式 | 可能的设备 | 协议 |
|-------------|-----------|------|
| 通用名称（如 "Living Room", "Kitchen"） | HomePod / HomePod mini | AirPlay/RAOP |
| 序列号风格名称（设备 ID 字符串） | Apple TV | AirPlay/Companion |
| 自定义名称 + "AirPort Express" | AirPort Express | AirPlay/RAOP |

## HA entity_id 命名约定

> 实际 entity_id 取决于 HA 集成方式。用 `ha_list_entities` 查看你的设备。

| 设备 | 常见 entity_id 模式 | domain |
|------|--------------------|--------|
| 扫地机器人 | `vacuum.robot_vacuum` | vacuum |
| 扫地机地图 | `image.vacuum_map` | image |
| 扫地机状态 | `sensor.vacuum_error` | sensor |
| 客厅灯 | `light.living_room` | light |
| 温度传感器 | `sensor.temperature_living` | sensor |
| 湿度传感器 | `sensor.humidity_living` | sensor |

## 房间名参考

自定义命名，常见示例：

```
bedroom, study, living, kitchen, dining, hallway, bathroom, storage
```
