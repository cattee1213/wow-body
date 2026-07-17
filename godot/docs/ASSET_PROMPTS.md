# WoW Body · 素材生成提示词

> 给 AI 出图 / 出音效用。生成后按命名放入 `godot/assets/`，即可替换现有素材。  
> 与代码加载约定一致：`assets/vfx/{spell}/{state}_0.png`（见 `scripts/vfx/spell_vfx_library.gd`）。

---

## 1. 统一风格（每条提示词都带上）

### 英文锚点（推荐复制到每条 prompt 末尾）

```text
game VFX sprite, top-down/side 2D magic combat, polished fantasy AAA mobile game quality,
luminous magical energy, high contrast glow, clean silhouette, centered composition,
isolated on pure transparent background, no dark square plate, no UI, no text, no watermark,
PNG with alpha, soft bloom edges, readable at small size
```

### 中文锚点

```text
2D 游戏特效素材，奇幻魔法战斗，高对比发光，轮廓清晰，居中构图，
纯透明背景，不要深色底板/方块背景，不要UI文字水印，PNG透明通道
```

### 技术规格

| 类型 | 推荐尺寸 | 格式 | 命名 |
|------|----------|------|------|
| 基础法术单帧 | **512×512** | PNG RGBA | `{hold,charge,projectile,impact}_0.png` |
| 终极法术单帧 | **512×512**（cast/loop 可 **1024×1024**） | PNG RGBA | `{hold,charge,cast,loop}_0.png` |
| 怪物 | **256×256** 或 **512×512** | PNG RGBA | `monster_basic_0.png` 等 |
| 升级卡图标 | **256×256** | PNG RGBA | `upgrade_{id}.png` |
| UI 图标 | **128×128** / **256×256** | PNG RGBA | 见下文 |

### 落盘目录（与代码一致）

```text
godot/assets/vfx/fire/
godot/assets/vfx/frost/
# 终极无独立目录：暴风雪/火焰雨在运行时用基础 projectile 组合放大
```

### 生成时注意

1. **透明背景**：写死 `transparent background, alpha channel, no black/dark plate`。很多模型会出灰底，需要后处理抠图。
2. **居中 + 留边**：主体约占画布 70%，四周留透明，避免裁切光晕。
3. **元素色板固定**
   - 火：`#FF6A00` → `#FFD060` → 白核
   - 冰：`#3DBBFF` → `#B8F0FF` → 白核
4. **可读性优先于写实**：体感游戏在摄像头画面上叠加，太碎的细节会糊。
5. **同系四态保持同一造型语言**（同一火球/冰晶家族），只改强度与形态。
6. 交付时建议按目录打包：

```text
vfx/fire/{hold,charge,projectile,impact}_0.png
vfx/frost/...
monsters/
ui/
upgrades/
sfx/
```

---

## 2. P0 · 法术 VFX（最优先，约 16 张）

现有图约 500×500，文档提到部分帧带深色底板——请务必 **纯透明背景**。

代码当前每状态 **1 帧**（`FRAME_COUNTS` 均为 1）。多帧时命名为 `{state}_0.png` … `{state}_N.png`，并同步改 `SpellVfxLibrary.FRAME_COUNTS`。

### 2.1 火球 `fire` → `assets/vfx/fire/`

| 文件 | 用途 | 英文提示词 |
|------|------|------------|
| `hold_0.png` | 掌心常驻火球 | `soft floating fire orb in palm, gentle orange-red plasma core, thin flame wisps, calm idle magic sphere, warm amber glow, not explosive` |
| `charge_0.png` | 蓄力变强 | `intensifying fire sphere, swirling solar flames, hotter white-yellow core, rising sparks, denser flame corona, charged magic energy` |
| `projectile_0.png` | 飞行弹体 | `compact fireball projectile, bright yellow-white core, trailing orange flames and embers, motion blur streaks backward, aerodynamic magic missile` |
| `impact_0.png` | 命中爆炸 | `fireball impact burst, radial explosion of flames and sparks, shockwave ring of heat, brief orange-red blast, debris embers flying outward` |

**中文精简：**

- hold：掌心悬浮小火球，橙红等离子体，轻柔火舌，不爆炸
- charge：蓄力大火球，白黄核心，旋转烈焰，火星上涌
- projectile：飞行火球，白黄核心 + 向后拖尾火焰与余烬
- impact：火球命中爆炸，径向火焰冲击波与火星

**完整示例（hold）：**

```text
soft floating fire orb in palm, gentle orange-red plasma core, thin flame wisps, calm idle magic sphere, warm amber glow, not explosive,
game VFX sprite, top-down/side 2D magic combat, polished fantasy AAA mobile game quality,
luminous magical energy, high contrast glow, clean silhouette, centered composition,
isolated on pure transparent background, no dark square plate, no UI, no text, no watermark,
PNG with alpha, soft bloom edges, readable at small size
```

---

### 2.2 寒冰箭 `frost` → `assets/vfx/frost/`

| 文件 | 用途 | 英文提示词 |
|------|------|------------|
| `hold_0.png` | 掌心冰晶球 | `soft floating frost orb, crystalline ice sphere, cyan and ice-blue glow, gentle snow sparkles, cold magical aura, calm idle` |
| `charge_0.png` | 蓄力 | `intensifying ice crystal sphere, sharp frozen shards orbiting, bright cyan-white core, frost mist, charged cryomancy energy` |
| `projectile_0.png` | 飞行 | `ice lance / frost bolt projectile, elongated crystalline spear tip, cyan trail of ice mist and snowflakes, sharp cold missile` |
| `impact_0.png` | 命中 | `frost impact shatter, ice crystals exploding outward, frozen shockwave ring, cyan-white burst, snow particles and shards` |

**中文：** 青色/冰蓝、晶体感、雪雾；projectile 可做成**冰矛/冰箭**更易辨认。

---

### 2.3 终极视觉（无独立素材）

- **暴风雪**：大量放大后的 `frost/projectile` 从天而降  
- **火焰雨**：大量放大后的 `fire/projectile` 从天而降  
- 命中复用对应系 `impact`  

无需再为 `blizzard` / `firestorm` 出独立图集。

---

### 2.4 可选：多帧动画

代码支持改 `FRAME_COUNTS` 后加载多帧。建议每状态 **4–6 帧**，循环播放。

```text
same subject, animation frame N of 6, slight rotation/pulse change, consistent lighting and palette,
identical transparent background, same camera framing
```

命名示例：`hold_0.png` … `hold_5.png`。

---

## 3. P1 · 怪物与状态

当前怪是代码绘制的紫球体 + 金角。若换成图：

### 3.1 小怪 `monster_basic`

```text
cute-scary fantasy demon minion, purple body, golden curved horns, glowing red eyes,
simple 2D game enemy sprite, side/front 3/4 view, thick outline optional,
readable silhouette, isolated transparent background, no ground shadow plate
```

建议路径：`assets/monsters/monster_basic_0.png`（**接入需改代码**，当前未读此路径）。

### 3.2 精英（可选）

```text
larger armored purple demon elite, bigger horns, cracked glowing body veins,
menacing but still cartoony readable for body-tracking game, transparent background
```

### 3.3 状态小图标（可选，叠怪头顶）

| 文件 | 提示词 |
|------|--------|
| `status_burn.png` | `small burn status icon, tiny flame, orange, transparent, UI icon 128px` |
| `status_slow.png` | `small frost slow status icon, snowflake, cyan, transparent, UI icon 128px` |

---

## 4. P1 · 升级卡图标（波末 3 选 1）

统一后缀：

```text
fantasy magic skill icon, circular or rounded square badge, soft inner glow,
clean symbol centered, dark subtle rim optional, transparent outside, 256x256, no text
```

建议路径：`assets/ui/upgrades/upgrade_{id}.png`（当前 UI 多用 emoji，**接入需改代码**）。

| ID | 名称 | 图标提示词核心 |
|----|------|----------------|
| `dmg_c` / `dmg_r` / `dmg_e` | 伤害 | `crossed magical blades / arcane sword glowing, power slash symbol` |
| `spd_c` / `spd_r` / `spd_e` | 攻速 | `swift hand with speed lines / wind streaks around fingers, haste magic` |
| `cd_c` / `cd_r` / `cd_e` | 终极 CD | `hourglass with magical sand / glowing chronomancy crystal clock` |
| `ms_chance_c` / `_r` / `_e` | 连发率 | `echoing spark chain / triple magic bullets in a line` |
| `ms_max_c` / `_r` / `_e` | 连发上限 | `five stacked projectiles / pearl string of spell orbs` |
| `split_c` / `_r` / `_e` | 分裂（若做） | `fan of three diverging magic bolts, split arrow symbol` |

稀有度边框可另做 3 张空框：

| 稀有 | 色 | 提示词 |
|------|-----|--------|
| 普通 | 灰白 | `empty rounded card frame, silver-white subtle rim, transparent center, no text` |
| 稀有 | `#4C9EFF` | `empty rounded card frame, bright blue magical rim #4C9EFF, transparent center` |
| 史诗 | `#B57BFF` | `empty rounded card frame, purple epic magical rim #B57BFF, transparent center` |

---

## 5. P2 · UI / 引导 / 品牌

| 素材 | 建议文件名 | 尺寸 | 提示词要点 |
|------|------------|------|------------|
| Logo | `logo_wow_body.png` | 1024×512 | `title logo fantasy magic hands casting fire and ice, neon glow, transparent background, no unreadable text or omit text` |
| 开始按钮装饰 | `ui_start_banner.png` | 512×128 | `magical glowing start banner, golden arcane frame, transparent` |
| 选系：火 | `school_fire.png` | 256×256 | `fire school emblem, phoenix flame crest, red-orange, transparent` |
| 选系：冰 | `school_frost.png` | 256×256 | `frost school emblem, ice crystal crest, cyan-blue, transparent` |
| 教学：指尖 | `tutorial_point.png` | 512×512 | `simple line-art hand pointing index finger, magic spark at fingertip, tutorial icon, transparent` |
| 教学：高举 | `tutorial_blizzard.png` | 512×512 | `two open hands raised high, snow magic above, tutorial silhouette, transparent` |
| 教学：合掌 | `tutorial_firestorm.png` | 512×512 | `two hands pressed together charging fire, tutorial silhouette, transparent` |
| 生命心 | `hud_heart.png` | 128×128 | `glowing magical heart icon, red-pink, game HUD, transparent` |
| 终极 CD 环 | `hud_cd_ring.png` | 256×256 | `circular cooldown ring frame, empty center, thin magical rim, transparent center` |

建议目录：`assets/ui/`。

---

## 6. 音频提示词

现有：`assets/sfx/fire_hit.wav`、`frost_hit.wav`（终极仍复用 hit）。

| 文件 | 英文音效描述 |
|------|----------------|
| `fire_hit.wav` | `short fireball impact whoosh-burst, magical, punchy, 0.3–0.5s` |
| `frost_hit.wav` | `short ice shatter impact, crystalline crack, magical, 0.3–0.5s` |
| `blizzard_cast.wav` | `deep blizzard wind howl with ice crystals, 1–1.5s` |
| `firestorm_cast.wav` | `infernal firestorm roar and whoosh, epic, 1–1.5s` |
| `ui_select.wav` | `soft magical chime UI confirm` |
| `wave_clear.wav` | `short victory sparkle chime` |
| `bgm_battle.ogg` | `loopable dark fantasy electronic battle ambient, 90–120s loop, no vocals` |

---

## 7. 建议生成顺序

### 最小集（约 16 张，立刻可替换 VFX）

1. `fire` ×4（hold / charge / projectile / impact）
2. `frost` ×4
3. `blizzard` ×4（hold / charge / cast / loop）
4. `firestorm` ×4

### 有余力再做

- 怪物 1–2 张
- 升级图标 6–8 张
- 手势教学 3 张
- 专属终极音效 + BGM

---

## 8. 接入说明

| 素材 | 是否已有加载路径 | 说明 |
|------|------------------|------|
| 法术 VFX | ✅ 已接 | 覆盖 `assets/vfx/{spell}/*_0.png` 后重启场景即可 |
| 命中 SFX | ✅ 已接 | `assets/sfx/*_hit.wav` |
| 怪物图 | ❌ 需改代码 | 当前 `monster.gd` 用 Polygon2D 画 |
| 升级图标 | ❌ 需改代码 | 当前 `upgrade_catalog.gd` 用 emoji |
| UI / 教学 | ❌ 需改代码 | 当前多为 Control 文字 + 色块 |

生成完成后把文件放进对应目录，或发路径告知；VFX 可直接替换，其它类型需要改脚本接入。

---

## 9. 相关文档

- 现状与缺口：[`STATUS.md`](STATUS.md)
- Roguelike 强化 ID：[`ROGUELIKE_UPGRADES.md`](ROGUELIKE_UPGRADES.md)
- 项目说明：[`../README.md`](../README.md)
