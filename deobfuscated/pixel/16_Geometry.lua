--[[
  Geometry —— 像素几何：读取物理屏幕尺寸/UI 缩放，计算像素格实际大小
  原始文件：4c2f46.lua（TOC 第 16 个加载的插件脚本）

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local fontPixelGeometry = {}
P8BA6426E.FontPixelGeometry = fontPixelGeometry
-- 读取物理分辨率与 UI 缩放，换算出 1 物理像素对应的 UI 单位
function fontPixelGeometry.Read()
    local width, height = GetPhysicalScreenSize()
    assert(
        type(width) == "number" and (width > 0 and (type(height) == "number" and height > 0)),
        "屏幕物理尺寸不可读"
    )
    local parentScale = UIParent:GetEffectiveScale()
    assert(type(parentScale) == "number" and parentScale > 0, "界面缩放不可读")
    local unit = (768 / height) / parentScale
    local visibleHeight = height
    if UIParent.GetHeight then
        local uiHeight = UIParent:GetHeight()
        if type(uiHeight) == "number" and uiHeight > 0 then
            visibleHeight = math.min(height, uiHeight / unit)
        end
    end
    return { width = width, height = height, parentScale = parentScale, unit = unit, visibleHeight = visibleHeight }
end
function fontPixelGeometry.Changed(previous, current)
    return not previous
        or previous.width ~= current.width
        or previous.height ~= current.height
        or previous.visibleHeight ~= current.visibleHeight
        or previous.pixelSize ~= current.pixelSize
        or math.abs(previous.parentScale - current.parentScale) > 1e-009
end
function fontPixelGeometry.EffectivePixelSize(stripHeight, requestedSize, snapshot, anchorY)
    local usableHeight = (snapshot.visibleHeight or snapshot.height) + math.min(anchorY or 0, 0)
    assert(stripHeight <= usableHeight, "游戏窗口高度不足以完整显示字体条")
    if requestedSize == 4 and stripHeight * 4 > usableHeight then
        return 1
    end
    return requestedSize
end
function fontPixelGeometry.Commit(snapshot, previous, reason)
    snapshot.revision = (previous and previous.revision or 0) + 1
    snapshot.reason = reason
    return snapshot
end
if P8BA6426E.LogicDiagnostics then
    local logicDiagnostics = P8BA6426E.LogicDiagnostics
    logicDiagnostics.Declare("geometry.read", "sampled", function()
        return fontPixelGeometry.Read
    end, function(read)
        fontPixelGeometry.Read = read
    end)
end
