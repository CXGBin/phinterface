# PHInterface（P8BA6426E）反混淆还原版

本目录是对 `main` 分支中**被混淆的魔兽世界插件代码**的完整还原，版本 10.7.4（`## Interface: 120100, 120105`）。原始文件全部保持不动，还原结果单独放在 `deobfuscated/` 下。

## 1. 原代码做了哪些混淆，还原了哪些

| 混淆手段 | 还原方式 |
|---|---|
| 整个文件压成一行、去掉所有空白 | 用 StyLua 重新排版（4 空格缩进，120 列） |
| 所有局部变量/参数/局部函数改成 `P`、`j`、`Y`、`X`… 这类单字母，并且大量重复复用 | 先基于作用域分析自动起名，再**逐文件人工阅读**，按用途重命名（约 6,000 个局部绑定） |
| 中文字符串全部写成 `"\229\131\143..."` 这样的十进制字节转义 | 解码成 UTF-8 明文（如 `"像素故障回执布局无效"`） |
| 文件名改成 6 位哈希（`8e5207.lua`），插件名改成 `P8BA6426E` | 按功能归类、重新命名，见第 5 节对照表。全局名 `P8BA6426E` 是运行时用到的真实标识，保留未改 |
| 第三方库（LibStub、CallbackHandler、LibSharedMedia、LibRangeCheck）也被混淆 | 同样还原，并按上游开源代码的习惯恢复主要命名 |

**没有改动的东西**：所有全局函数名（如 `P8BA6426E.GetPlayerCastState`）、表字段名、字符串和数字常量、控制流。还原只涉及排版、字符串写法和局部变量名。

### 等价性校验

每个文件都用 `tools/verify.js` 检查过：把原文件和还原文件分别解析成 AST，把每个局部变量替换成它的绑定编号，字符串按字节比较，然后对比两份结构。87 个文件（83 个插件脚本 + 4 个库）**全部一致**。这说明重命名没有造成变量遮蔽或捕获错误，程序语义和原文件相同。

```bash
cd deobfuscated/tools && npm install
node verify.js ../../8e5207.lua ../core/01_Core.lua    # 输出“一致”
```

> 局部变量名是根据代码用途推断出来的，不一定和原作者的命名一样。全局 API 名称是原文，可以放心依赖。

## 2. 插件在做什么（一句话）

这是一个“**像素桥**”插件：它每 20 毫秒把战斗状态（开关、敌人数量、施法、血量、技能冷却、充能、光环、首领时间轴等）编码成屏幕左上角一列 1 像素宽的**彩色色块**。插件外面的程序截屏读取这些颜色，然后按下插件预先绑定好的按键，触发隐藏的 `SecureActionButton` 去施放技能、使用物品或切换焦点。插件内部只负责“输出状态”和“提供按键→动作的绑定”，不做施法决策；决策由外部程序完成。

## 3. 整体架构

```
         ┌──────────── 游戏客户端内（本插件） ─────────────┐
 事件/API │ core/01_Core      数据库、专精装载、施法/冷却采集、按键绑定
 ───────▶ │ healing/*        团队焦点、治疗模式、NPC 指向
          │ timeline/*       首领时间轴 → 技能识别
          │        │ 每 20ms 汇总 frameValues
          │        ▼
          │ pixel/32_PixelBarsMain   逐字段把数值编码为 RGB
          │ pixel/22_FontPixelRoute  像素条带协议：头部/字段行/时间轴/回执/心跳
          │ pixel/19,15,21,20        数字/就绪/存在/姓名板 生产器（原生 UI 对象直接出色）
          └────────┬───────────────────────────────────────────┘
                   │ 屏幕左上角 1 像素宽色条
                   ▼
           外部程序（截屏 → 解码 → 决策）
                   │ 模拟按键（F6~F12、8、9、0、-、=、[ ]…、CTRL-/ALT- 组合）
                   ▼
   SetOverrideBinding → 隐藏 SecureActionButton（MKL_BTN_<动作>）→ /cast 宏
```

### 加载顺序（TOC）
Libs → 核心 `core/01_Core` → 兼容层 → 诊断 → 数据表 → 治疗/团队 → 像素生产器 → 像素合同数据 → 像素路由 → 宏本地化 → CDM/界面 → **像素主循环** → 时间轴 → 自我保护 → 40 个专精文件（`P8BA6426E.RegisterClass(specID, {...})`）。

### 一帧的数据流（`pixel/32_PixelBarsMain.lua` 的 OnUpdate）
1. 检测总开关/爆发/模式切换快捷键（输入框聚焦时忽略）；
2. `scanVisibleHostileEnemies(8)` 扫描敌对姓名板，得到 8 码内敌人数、战斗中敌人数等；
3. 汇总本帧所有字段到 `frameValues`：开关、AOE 模式、距离、饰品/药水/治疗石冷却、GCD、施法状态、最近成功施法、战斗时长、团队/小队血量、各技能可用位图 `action_avail`，再调用专精文件的 `GetExtraValues(values)` 补充专精字段；
4. 对合同里的每个标量字段调用 `renderScalarField`，按类型编码颜色，写到对应物理行；
5. `FontPixelRoute.OnClassicFrame()` 刷新故障回执，把“激活位”写成白色并递增心跳计数，外部程序靠它判断这一帧数据是否完整。

## 4. 像素协议要点（`pixel/22_FontPixelRoute.lua`、`pixel/17_PixelSurface.lua`、`data/18_FontPixelContracts.lua`）

- **位置**：`UIParent` 左上角（可用 `DB.pixelAnchorOffset` 偏移），层级 `TOOLTIP`/9900。每个“格”是 `pixelSize × pixelSize` 个物理像素（4×4 或 1×1，在设置里切换），换算见 `pixel/16_Geometry.lua`。
- **基本编码**：0~16777215 的整数拆成 `R = n>>16, G = (n>>8)&255, B = n&255`（`intToRGB`）。布尔值用红/绿表示，距离按 ×10 存，未知值统一用 `0xFFFFFF`，“不可用”用 601 表示。
- **头部 8 行**：
  - 第 0~2 行：魔数色 `(19,227,149)`、`(241,173,37)`、`(61,109,211)`
  - 第 3 行：尺寸头（协议版本 7/8、像素格大小、条带高度）
  - 第 4 行：布局摘要 `wireLayoutID`（6 位十六进制）
  - 第 5 行：字段计数（经典字段数、存在字段数、文本字段数）
  - 第 6 行：心跳（16 位计数 + 标记）
  - 第 7 行：激活位（本帧写完后置白）
- **字段区**按五组排列：`common`、`exclusive`、`skill`、`aura`、`timeline`。每个专精的字段顺序和行号写在“合同”`P8BA6426E.FontPixelContracts[specID]` 里（`classicKeys`、`classicRows`、`textFields`、`presenceFields`、`nativeFields`、`chargeFields` 等）。
- **时间轴区（8 行）**：一条记录是 `[魔数 3260648, 序号*2, 首领ID*100+难度, 代数, 事件ID, 机制字, 状态字]`。写入时先把序号行清零，最后再写序号，读取方因此不会读到写了一半的记录。
- **尾部**：故障回执位图（每 24 行一个字）加校验和，最后两行是结束标记 `(32,96,224)`、`(61,109,211)`。
- **受保护值（secret value）**：12.x 客户端里很多战斗数值不能直接在 Lua 中读取。插件改用暴雪原生对象（`DurationObject`、`UnitHealthPercent` 颜色曲线、`AuraContainer`、`NumericRuleFormatter`、专用像素字体）**直接输出颜色**，从而绕过 Lua 层的读取限制。这部分在 `pixel/19_NumericProducer.lua`、`pixel/21_PresenceProducer.lua`、`pixel/14_ChargeCodec.lua` 中。

## 5. 文件对照表（原文件 → 还原文件）

插件脚本按 TOC 加载顺序编号：

| # | 原文件 | 还原文件 |
|---|---|---|
| 1 | `8e5207.lua` | `core/01_Core.lua` |
| 2 | `ffb3a6.lua` | `core/02_ClientCompat.lua` |
| 3 | `5205cd.lua` | `diagnostics/03_ResourceMonitor.lua` |
| 4 | `64ed69.lua` | `diagnostics/04_LogicDiagnostics.lua` |
| 5 | `bd39b1.lua` | `data/05_SuccessSpellCatalog.lua` |
| 6 | `63785f.lua` | `core/06_SpellSuccessTracker.lua` |
| 7 | `30bc61.lua` | `healing/07_HealingNpcMouseover.lua` |
| 8 | `552484.lua` | `data/08_LocaleEN.lua` |
| 9 | `d1f0d9.lua` | `core/09_ActionKeys.lua` |
| 10 | `32b0ff.lua` | `healing/10_RaidFocus.lua` |
| 11 | `286686.lua` | `core/11_AutoTarget.lua` |
| 12 | `2fc6ca.lua` | `healing/12_HealingModeSwitch.lua` |
| 13 | `00d496.lua` | `pixel/13_FontPixelSources.lua` |
| 14 | `d97326.lua` | `pixel/14_ChargeCodec.lua` |
| 15 | `096638.lua` | `pixel/15_ReadinessProducer.lua` |
| 16 | `4c2f46.lua` | `pixel/16_Geometry.lua` |
| 17 | `426da6.lua` | `pixel/17_PixelSurface.lua` |
| 18 | `87e16d.lua` | `data/18_FontPixelContracts.lua` |
| 19 | `d825ba.lua` | `pixel/19_NumericProducer.lua` |
| 20 | `9fece1.lua` | `pixel/20_NameplateProducer.lua` |
| 21 | `5991da.lua` | `pixel/21_PresenceProducer.lua` |
| 22 | `2e962d.lua` | `pixel/22_FontPixelRoute.lua` |
| 23 | `cf935d.lua` | `pixel/23_ScalarLayers.lua` |
| 24 | `501261.lua` | `pixel/24_PixelResource.lua` |
| 25 | `b87b4a.lua` | `core/25_SpellCharges.lua` |
| 26 | `0b1dd3.lua` | `data/26_MacroRefs.lua` |
| 27 | `549815.lua` | `core/27_MacroLocalization.lua` |
| 28 | `1e635b.lua` | `ui/28_CooldownManagerProfiles.lua` |
| 29 | `09f267.lua` | `data/29_RotationTalentLoadouts.lua` |
| 30 | `dfbb6a.lua` | `ui/30_MainUI.lua` |
| 31 | `e2be40.lua` | `ui/31_MacroEditor.lua` |
| 32 | `2f2403.lua` | `pixel/32_PixelBarsMain.lua` |
| 33 | `c6142a.lua` | `timeline/33_Encounters_A.lua` |
| 34 | `9bac05.lua` | `timeline/34_Encounters_B.lua` |
| 35 | `735e43.lua` | `timeline/35_Encounters_C.lua` |
| 36 | `a4c483.lua` | `timeline/36_Encounters_D.lua` |
| 37 | `9bf7e6.lua` | `timeline/37_Encounters_E.lua` |
| 38 | `3cc5aa.lua` | `timeline/38_Encounters_F.lua` |
| 39 | `3b9655.lua` | `timeline/39_Encounters_G.lua` |
| 40 | `be4f96.lua` | `timeline/40_Encounters_H.lua` |
| 41 | `39d512.lua` | `timeline/41_TimelinePlanner.lua` |
| 42 | `0aff22.lua` | `timeline/42_TrashCapture.lua` |
| 43 | `bf775c.lua` | `core/43_SelfProtection.lua` |
| 44 | `0c0750.lua` | `specs/264_Shaman_Restoration.lua` |
| 45 | `127748.lua` | `specs/263_Shaman_Enhancement.lua` |
| 46 | `1a5317.lua` | `specs/64_Mage_Frost.lua` |
| 47 | `1c2300.lua` | `specs/581_DemonHunter_Vengeance.lua` |
| 48 | `21c39c.lua` | `specs/102_Druid_Balance.lua` |
| 49 | `21e6a5.lua` | `specs/1480_DemonHunter_Devourer.lua` |
| 50 | `273527.lua` | `specs/269_Monk_Windwalker.lua` |
| 51 | `281448.lua` | `specs/253_Hunter_BeastMastery.lua` |
| 52 | `3552aa.lua` | `specs/257_Priest_Holy.lua` |
| 53 | `37634a.lua` | `specs/105_Druid_Restoration.lua` |
| 54 | `39f566.lua` | `specs/71_Warrior_Arms.lua` |
| 55 | `3c2bd5.lua` | `specs/70_Paladin_Retribution.lua` |
| 56 | `442949.lua` | `specs/262_Shaman_Elemental.lua` |
| 57 | `46c611.lua` | `specs/270_Monk_Mistweaver.lua` |
| 58 | `47d05d.lua` | `specs/254_Hunter_Marksmanship.lua` |
| 59 | `5c0eb8.lua` | `specs/72_Warrior_Fury.lua` |
| 60 | `63cab8.lua` | `specs/258_Priest_Shadow.lua` |
| 61 | `642c87.lua` | `specs/1468_Evoker_Preservation.lua` |
| 62 | `7041c9.lua` | `specs/268_Monk_Brewmaster.lua` |
| 63 | `72728f.lua` | `specs/65_Paladin_Holy.lua` |
| 64 | `7c93b3.lua` | `specs/266_Warlock_Demonology.lua` |
| 65 | `7d37cc.lua` | `specs/62_Mage_Arcane.lua` |
| 66 | `85702a.lua` | `specs/260_Rogue_Outlaw.lua` |
| 67 | `89ab3b.lua` | `specs/250_DeathKnight_Blood.lua` |
| 68 | `96bc77.lua` | `specs/103_Druid_Feral.lua` |
| 69 | `ab288f.lua` | `specs/73_Warrior_Protection.lua` |
| 70 | `b5a193.lua` | `specs/261_Rogue_Subtlety.lua` |
| 71 | `b685a5.lua` | `specs/1473_Evoker_Augmentation.lua` |
| 72 | `b9dc3d.lua` | `specs/1467_Evoker_Devastation.lua` |
| 73 | `bd1dd9.lua` | `specs/104_Druid_Guardian.lua` |
| 74 | `bfe008.lua` | `specs/255_Hunter_Survival.lua` |
| 75 | `c22d2d.lua` | `specs/66_Paladin_Protection.lua` |
| 76 | `c2b3b5.lua` | `specs/267_Warlock_Destruction.lua` |
| 77 | `c45c53.lua` | `specs/252_DeathKnight_Unholy.lua` |
| 78 | `c49d59.lua` | `specs/577_DemonHunter_Havoc.lua` |
| 79 | `d69975.lua` | `specs/259_Rogue_Assassination.lua` |
| 80 | `dc3a68.lua` | `specs/63_Mage_Fire.lua` |
| 81 | `e49775.lua` | `specs/251_DeathKnight_Frost.lua` |
| 82 | `ec2661.lua` | `specs/265_Warlock_Affliction.lua` |
| 83 | `ecd88b.lua` | `specs/256_Priest_Discipline.lua` |

第三方库：`Libs/LibStub`、`Libs/CallbackHandler-1.0`、`Libs/LibSharedMedia-3.0`、`Libs/LibRangeCheck-3.0`（库名被改成 `<插件名>-RangeCheck-3.0`）。

### 目录说明
| 目录 | 内容 |
|---|---|
| `core/` | 核心逻辑：数据库、专精装载、冷却/施法采集、按键绑定、宏本地化、自动选怪、自我保护 |
| `pixel/` | 像素输出：几何、表面、路由协议、各类生产器、主循环 |
| `healing/` | 治疗相关：团队焦点数据包、治疗模式开关、NPC 指向 |
| `timeline/` | 首领时间轴规划器引擎 + 各首领的识别规则 + 大秘境小怪采集 |
| `ui/` | 设置界面、宏编辑、冷却管理器（CDM）配置 |
| `diagnostics/` | 性能剖析与资源采样（`/pmsprofile`） |
| `data/` | 纯数据表：像素合同、宏授权引用、英文本地化、施法成功目录 |
| `specs/` | 40 个专精配置，文件名是 `专精ID_职业_专精` |
| `tools/` | 反混淆与等价校验工具 |

## 6. 常用对外接口与配置

**斜杠命令**：`/pms` 打开设置；`/ON` `/OFF` 总开关；`/bfk` `/bfg` 爆发开/关；`/dan` 单体、`/qun` 群体、`/AUTO`（`/zi`）自动；`/charu` 暂停 0.5 秒（手动插入技能）；`/cdms …` 冷却管理器配置；`/pmsprofile on|off` 性能观测。

**专精文件结构**（`P8BA6426E.RegisterClass(specID, def)`，见 `specs/*.lua`）：
- `talentLoadouts`：推荐天赋导入串
- `DEFAULT_MACROS`：动作键（如 `spell_196277`、`cd_89766`、`item_red_potion`）→ 宏文本
- `ACTION_LABELS`、`ACTION_TO_KEY`：动作显示名，以及外部程序按哪个键触发它
- `testSpells`、`actionAvailSpellIDs`：需要输出“是否可用”的技能
- `consumableItems`、`petSpells`、`cooldownEventAliases`、`forceAvailableRules`、`empowerSpellIDs` 等
- 回调：`OnSpellCast(spellID, consumableID)`、`GetExtraValues(values)`（往像素帧里补专精字段）、`OverrideIsSpellReady(spellID)`、`OverrideChargeDisplayCount(spellID)`

**SavedVariables（`P8BA6426EDB`）主要字段**：`masterSwitch`、`burstSwitch`、`burstAutoCloseSecondsBySpec`、`autoTarget`/`healerAutoTarget`/`protectionPaladinAutoTarget`、`masterKey`/`burstKey`/`aoeKey`、`macroMapBySpec`/`userEditedMacrosBySpec`、`persistentCooldownLedger`、`pixelCellSize`、`pixelAnchorOffset`、`logoSize`/`logoPoint`/`logoHidden`/`showLogoText`、`minimapButtonAngle`、`foreverHealingMode`、`cdmStateSaverDB`、`removedSensitiveBindings`、`timelinePlannerCapture`、`timelinePlannerTrashCapture`、`luaResourceSnapshot`、`addonEnableProtection`、`currentClass/currentSpecID/currentHeroSpecID…`。

## 7. 值得注意的行为

- **自动修改游戏设置**：每次进入世界都会把渲染倍数、伽马、亮度、对比度、姓名板显示等 CVar 改成“推荐值”，并强制关闭“使用 UI 缩放”，以保证色块颜色能被准确读取（`pixel/32_PixelBarsMain.lua`）。
- **移除快捷键**：会删除 CTRL/ALT/SHIFT 组合下的“切换声音/音乐/环境音/界面”绑定，避免被外部程序误触；被删除的绑定备份在 `removedSensitiveBindings`（`core/01_Core.lua`）。
- **屏蔽错误提示**：关闭错误语音（`Sound_EnableErrorSpeech`），并让 `UIErrorsFrame` 不再接收 `UI_ERROR_MESSAGE`。
- **自我保护**：如果其他插件管理器（包括 ACP、RurutiaSuite）或游戏 API 禁用了本插件，它会立即调用 `EnableAddOn` 把自己重新启用，并把自己写进这些管理器的“受保护插件”列表（`core/43_SelfProtection.lua`）。
- **数据采集**：遇到时间轴目录里登记过的首领战时，会自动把时间轴事件记录到 SavedVariables（`timeline/41_TimelinePlanner.lua`，最多保留 3 场）。大秘境小怪采集（`timeline/42_TrashCapture.lua`）默认关闭，插件内部没有地方打开它，只有调用 `P8BA6426E.SetTimelinePlannerTrashCaptureArmed(true)`（例如通过 `/run`）后才会在指定地图里记录姓名板和施法事件。

## 8. 工具（`tools/`）

- `deob.js`：基于 luaparse 的反混淆器，做作用域分析，按启发式规则重命名局部变量，解码字符串。`--keep` 模式会保留现有名字，只应用人工重命名表（重命名时会检查遮蔽冲突，有冲突就报错）。
- `verify.js`：AST 作用域等价校验。
- 排版用的是 StyLua 2.0.2：`stylua --indent-type Spaces --indent-width 4 --column-width 120`。
