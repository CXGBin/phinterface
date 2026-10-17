--[[
  PixelResource —— 像素资源编码：能量/符文/百分比等资源值转颜色
  原始文件：501261.lua（TOC 第 24 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local MAX_VALUE = 65534
local STEP_CURVE_LIMIT = 256
local MAX_CURVE_VALUE = 32767
local curveCache = {}
local function isReadableNumber(value)
    return not (issecretvalue and issecretvalue(value))
        and (type(value) == "number" and (value == value and (value > -math.huge and value < math.huge)))
end
local function encodeColor(n)
    assert(isReadableNumber(n) and (n >= 0 and n <= MAX_VALUE), "资源数值超出通用编码容量")
    n = math.floor(n + 0.5)
    return CreateColor(0, math.floor(n / 256) / 255, (n % 256) / 255, 1)
end
local function getScaleCurve(powerType, maximum, scale, unmodified)
    local cacheKey = powerType .. (":" .. (scale .. (":" .. tostring(unmodified))))
    local cached = curveCache[cacheKey]
    if cached and cached.maximum == maximum then
        return cached.curve
    end
    local steps = math.floor(maximum * scale + 0.5)
    assert(steps > 0 and steps <= MAX_VALUE, "资源最大值超出通用编码容量")
    assert(steps <= MAX_CURVE_VALUE, "资源最大值超出单条颜色曲线容量")
    local curve = C_CurveUtil.CreateColorCurve()
    if steps < STEP_CURVE_LIMIT then
        curve:SetType(Enum.LuaCurveType.Step)
        for i = 0, steps, 1 do
            curve:AddPoint(i / steps, encodeColor(i))
        end
    else
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0, encodeColor(0))
        local lastStep = 0
        for i = 256, steps, 256 do
            curve:AddPoint((i - 1) / steps, encodeColor(i - 1))
            curve:AddPoint(i / steps, encodeColor(i))
            lastStep = i
        end
        if lastStep < steps then
            curve:AddPoint(1, encodeColor(steps))
        end
    end
    curveCache[cacheKey] = { maximum = maximum, curve = curve }
    return curve
end
-- 读取资源（能量/怒气/符文等）并转换为可直接取 RGB 的颜色对象
function P8BA6426E.ReadPixelResource(source)
    local powerType = assert(Enum.PowerType[source.powerType], "资源类型未登记")
    local unit = source.unit or "player"
    local scale = source.scale or 1
    if source.mode == "percent" then
        local curve = getScaleCurve(powerType, 100, 1, false)
        return UnitPowerPercent(unit, powerType, false, curve)
    end
    if source.mode == "runes" then
        local maxRunes = UnitPowerMax(unit, powerType)
        assert(
            isReadableNumber(maxRunes) and (maxRunes >= 0 and (maxRunes % 1 == 0 and maxRunes <= MAX_VALUE)),
            "符文最大数量不可读"
        )
        local readyRunes = 0
        for i = 1, maxRunes, 1 do
            local _start, _duration, ready = GetRuneCooldown(i)
            assert(
                not (issecretvalue and issecretvalue(ready)) and type(ready) == "boolean",
                "符文就绪状态不可读"
            )
            if ready then
                readyRunes = readyRunes + 1
            end
        end
        return encodeColor(readyRunes)
    end
    local unmodified = source.unmodified == true
    local displayMod = unmodified and UnitPowerDisplayMod(powerType) or 1
    assert(isReadableNumber(displayMod) and displayMod > 0, "资源显示单位不可读")
    local power = UnitPower(unit, powerType, unmodified)
    if isReadableNumber(power) then
        return encodeColor((power * scale) / displayMod)
    end
    assert(issecretvalue and issecretvalue(power), "资源当前数值不可读")
    local powerMax = UnitPowerMax(unit, powerType, unmodified)
    assert(isReadableNumber(powerMax) and powerMax > 0, "资源当前最大值不可读")
    local curve = getScaleCurve(powerType, powerMax / displayMod, scale, unmodified)
    return UnitPowerPercent(unit, powerType, unmodified, curve)
end
