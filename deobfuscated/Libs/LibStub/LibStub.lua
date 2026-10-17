--[[
  第三方开源库 LibStub（同样被混淆过，已还原并按上游源码习惯恢复主要命名）
  原始文件：Libs/LibStub/LibStub.lua

  说明：本文件由混淆代码还原（格式化 + 字符串解码 + 局部变量语义化重命名）。
    · 全局函数名、表字段名、字符串常量均为原文，未作改动；
    · 局部变量/参数/局部函数名为根据用途推断的命名，可能与原作者不同；
    · 已通过 AST 作用域等价校验：与原文件语义完全一致。
]]
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2
local LibStub = _G[LIBSTUB_MAJOR]
if not LibStub or LibStub.minor < LIBSTUB_MINOR then
    LibStub = LibStub or { libs = {}, minors = {} }
    _G[LIBSTUB_MAJOR] = LibStub
    LibStub.minor = LIBSTUB_MINOR
    function LibStub.NewLibrary(self, major, minor)
        assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
        minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")
        local oldminor = self.minors[major]
        if oldminor and oldminor >= minor then
            return nil
        end
        self.minors[major], self.libs[major] = minor, self.libs[major] or {}
        return self.libs[major], oldminor
    end
    function LibStub.GetLibrary(self, major, silent)
        if not self.libs[major] and not silent then
            error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
        end
        return self.libs[major], self.minors[major]
    end
    function LibStub.IterateLibraries(self)
        return pairs(self.libs)
    end
    setmetatable(LibStub, { __call = LibStub.GetLibrary })
end
