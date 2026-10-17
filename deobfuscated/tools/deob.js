// Lua 反混淆器：作用域分析 + 启发式重命名局部变量 + 解码字符串转义
// 用法: node deob.js [--keep] <in.lua> <out.lua> [renames.json]
//   默认模式：对所有局部变量按启发式自动命名，并把十进制转义字符串解码为 UTF-8
//   --keep 模式：保留现有名字，只应用 renames.json 中的人工重命名（冲突时报错）
//   renames.json: [{line, name, to}]  —— 对输入文件第 line 行声明的局部变量 name 改名为 to
// 输出后需再用 StyLua 排版：stylua --indent-type Spaces --indent-width 4 --column-width 120 out.lua
'use strict';
const fs = require('fs');
const luaparse = require('luaparse');

const KEYWORDS = new Set(('and break do else elseif end false for function goto if in local nil not or repeat return then true until while').split(' '));

// ---------- 字符串解码 ----------
function decodeLuaString(raw) {
  const q = raw[0];
  if (q !== '"' && q !== "'") return null;
  const body = raw.slice(1, -1);
  const bytes = [];
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (c !== '\\') { bytes.push(...Buffer.from(c, 'utf8')); continue; }
    const n = body[++i];
    const simple = { a: 7, b: 8, f: 12, n: 10, r: 13, t: 9, v: 11, '\\': 92, '"': 34, "'": 39, '\n': 10 };
    if (n in simple) { bytes.push(simple[n]); continue; }
    if (/[0-9]/.test(n)) {
      let d = n;
      while (d.length < 3 && /[0-9]/.test(body[i + 1])) d += body[++i];
      bytes.push(parseInt(d, 10));
      continue;
    }
    return null; // 未知转义，保持原样
  }
  const buf = Buffer.from(bytes);
  const str = buf.toString('utf8');
  if (Buffer.compare(Buffer.from(str, 'utf8'), buf) !== 0) return null; // 非合法 UTF-8
  let out = '"';
  for (const ch of str) {
    const cp = ch.codePointAt(0);
    if (ch === '\\') out += '\\\\';
    else if (ch === '"') out += '\\"';
    else if (ch === '\n') out += '\\n';
    else if (ch === '\t') out += '\\t';
    else if (ch === '\r') out += '\\r';
    else if (cp < 32 || cp === 127) out += '\\' + cp;
    else out += ch;
  }
  return out + '"';
}

// ---------- 命名工具 ----------
function lowerCamel(s) {
  if (!s) return s;
  if (/^[A-Z0-9_]+$/.test(s) && s.length > 1) return s.toLowerCase().replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
  let m = s.match(/^([A-Z]+)([A-Z][a-z].*)$/);
  if (m) return m[1].toLowerCase() + m[2];
  if (/^[A-Z]+$/.test(s)) return s.toLowerCase();
  return s[0].toLowerCase() + s.slice(1);
}
function singular(s) {
  if (!s) return null;
  if (/ies$/.test(s)) return s.slice(0, -3) + 'y';
  if (/(ss|us|is)$/.test(s)) return null;
  if (/ses$|xes$|ches$|shes$/.test(s)) return s.slice(0, -2);
  if (/s$/.test(s) && s.length > 2) return s.slice(0, -1);
  return null;
}
const GLOBAL_ALIAS = { error: 'err', type: 'kind', string: 'str', table: 'tbl', next: 'nextValue', select: 'selected', time: 'timeValue', format: 'fmt', print: 'printFn', math: 'mathLib', date: 'dateValue', unpack: 'unpacked', pairs: 'pairsFn', tostring: 'str', tonumber: 'num', end: 'endValue', function: 'fn', and: 'andValue', or: 'orValue', not: 'notValue', nil: 'nilValue', true: 'trueValue', false: 'falseValue', repeat: 'repeatValue', return: 'returnValue', local: 'localValue', in: 'inValue', for: 'forValue', if: 'ifValue', then: 'thenValue', else: 'elseValue', while: 'whileValue', do: 'doValue', break: 'breakValue', until: 'untilValue', elseif: 'elseifValue', goto: 'gotoValue', wipe: 'wipeFn', min: 'minValue', max: 'maxValue', abs: 'absValue', floor: 'floorValue', strsplit: 'parts', _G: 'globals', assert: 'assertFn', rawget: 'raw', ipairs: 'ipairsFn', bit: 'bitLib', C_Timer: 'timer', UIParent: 'uiParent', GetTime: 'getTime', CreateFrame: 'createFrame', P8BA6426E: 'addon' };
function aliasName(s) { return Object.prototype.hasOwnProperty.call(GLOBAL_ALIAS, s) ? GLOBAL_ALIAS[s] : s; }
function validName(s) {
  return typeof s === 'string' && /^[A-Za-z_][A-Za-z0-9_]*$/.test(s) && !KEYWORDS.has(s);
}

const API_ARG_HINTS = [
  [/^Unit[A-Z]/, ['unit']],
  [/^(C_Spell\.|GetSpell|IsSpell|IsUsableSpell|IsPlayerSpell|C_SpellBook\.IsSpellKnown|FindSpell)/, ['spellID']],
  [/^(C_Item\.|GetItem|IsUsableItem|GetInventoryItem)/, ['itemID']],
  [/^(C_EventUtils\.IsEventValid)$/, ['event']],
  [/^(RegisterEvent|UnregisterEvent)$/, ['event']],
  [/^(string\.format|format)$/, ['fmt']],
  [/^(SetBinding|SetBindingClick|SetOverrideBinding|SetOverrideBindingClick|SetOverrideBindingMacro)$/, null],
  [/^(GetSpecializationInfo|GetSpecializationInfoByID)$/, ['specIndex']],
  [/^(GetInventoryItemID|GetInventoryItemCooldown)$/, ['unit', 'slot']],
];
const METHOD_KIND = {
  SetPoint: 'frame', SetSize: 'frame', Show: 'frame', Hide: 'frame', SetScript: 'frame', RegisterEvent: 'frame', CreateTexture: 'frame', CreateFontString: 'frame', SetAllPoints: 'frame', SetBackdrop: 'frame',
  SetText: 'label', SetFont: 'label', SetTextColor: 'label', SetJustifyH: 'label',
  SetTexture: 'texture', SetColorTexture: 'texture', SetVertexColor: 'texture', SetTexCoord: 'texture',
};
const SCRIPT_PARAMS = {
  OnEvent: ['self', 'event'], OnUpdate: ['self', 'elapsed'], OnClick: ['self', 'button', 'down'], OnEnter: ['self'], OnLeave: ['self'],
  OnShow: ['self'], OnHide: ['self'], OnMouseDown: ['self', 'button'], OnMouseUp: ['self', 'button'], OnDragStart: ['self', 'button'], OnDragStop: ['self'],
  OnValueChanged: ['self', 'value', 'userInput'], OnTextChanged: ['self', 'userInput'], OnKeyDown: ['self', 'key'], OnKeyUp: ['self', 'key'],
  OnEnterPressed: ['self'], OnEscapePressed: ['self'], OnEditFocusLost: ['self'], OnEditFocusGained: ['self'], OnSizeChanged: ['self', 'width', 'height'],
  OnMouseWheel: ['self', 'delta'], OnReceiveDrag: ['self'], OnTabPressed: ['self'], OnChar: ['self', 'text'], PostClick: ['self', 'button', 'down'], PreClick: ['self', 'button', 'down'],
};

function calleeName(node) {
  if (!node) return null;
  if (node.type === 'Identifier') return node.name;
  if (node.type === 'MemberExpression') {
    const b = calleeName(node.base);
    return b ? b + '.' + node.identifier.name : '?.' + node.identifier.name;
  }
  return null;
}
function lastSeg(name) { return name ? name.split('.').pop() : null; }

function nameFromCallee(fname, callNode) {
  const seg = lastSeg(fname);
  if (!seg) return null;
  const args = callNode.arguments || [];
  if (seg === 'CreateFrame') {
    const t = args[0] && args[0].type === 'StringLiteral' ? decodeVal(args[0]) : null;
    if (t === 'Button' || t === 'CheckButton') return 'button';
    if (t === 'EditBox') return 'editBox';
    if (t === 'ScrollFrame') return 'scrollFrame';
    if (t === 'Slider') return 'slider';
    if (t === 'StatusBar') return 'statusBar';
    if (t === 'Cooldown') return 'cooldown';
    return 'frame';
  }
  if (seg === 'CreateTexture' || seg === 'CreateMaskTexture') return 'texture';
  if (seg === 'CreateFontString') return 'label';
  if (seg === 'CreateAnimationGroup') return 'animGroup';
  if (seg === 'CreateAnimation') return 'anim';
  if (seg === 'GetTime' || seg === 'GetTimePreciseSec') return 'now';
  if (seg === 'pcall' || seg === 'xpcall') return ['ok', 'result'];
  if (seg === 'tostring') return 'str';
  if (seg === 'tonumber') { const h = args[0] && exprHint(args[0]); return h ? h : 'num'; }
  if (seg === 'type') return 'valueType';
  if (seg === 'select') return args[0] && args[0].type === 'StringLiteral' ? 'count' : 'value';
  if (seg === 'setmetatable') return 'obj';
  if (seg === 'assert') { return args[0] ? exprHint(args[0]) : null; }
  if (seg === 'floor' || seg === 'ceil' || seg === 'max' || seg === 'min' || seg === 'abs') { const h = args[0] && exprHint(args[0]); return h && typeof h === 'string' ? h : 'n'; }
  if (seg === 'format') return 'text';
  if (seg === 'gsub') return 'replaced';
  if (seg === 'match') return 'matched';
  if (seg === 'find') return ['startPos', 'endPos'];
  if (seg === 'sub' || seg === 'upper' || seg === 'lower' || seg === 'trim' || seg === 'strtrim') return 'str';
  if (seg === 'concat') return 'joined';
  if (seg === 'remove') return 'removed';
  if (seg === 'next') return ['nextKey', 'nextValue'];
  if (seg === 'unpack') return null;
  if (seg === 'getmetatable') return 'mt';
  if (seg === 'rawget') return 'value';
  if (seg === 'GetName') return 'name';
  if (seg === 'GetParent') return 'parent';
  if (seg === 'GetSpecialization') return 'specIndex';
  if (seg === 'GetSpecializationInfo') return ['specID', 'specName', 'specDesc', 'specIcon', 'specRole'];
  if (seg === 'UnitClass') return ['className', 'classFile', 'classID'];
  if (seg === 'GetNumGroupMembers') return 'groupSize';
  if (seg === 'IsInRaid') return 'inRaid';
  if (seg === 'IsInGroup') return 'inGroup';
  if (seg === 'InCombatLockdown') return 'inCombat';
  if (seg === 'GetInstanceInfo') return ['instanceName', 'instanceType', 'difficultyID'];
  if (seg === 'UnitGUID') return 'guid';
  if (seg === 'UnitExists') return 'exists';
  if (seg === 'GetSpellBaseCooldown') return 'baseCooldownMs';
  let s = seg;
  if (/^Get[A-Z]/.test(s)) s = s.slice(3);
  else if (/^Unit[A-Z]/.test(s)) s = s.slice(4);
  else if (/^(Is|Has|Can|Should)[A-Z]/.test(s)) return lowerCamel(seg);
  else if (/^(Create|Build|Make|New|Ensure|Resolve|Read|Load|Find|Lookup|Compute|Calc|Normalize|Parse|Collect|Decode|Encode)[A-Z]/.test(s)) s = s.replace(/^(Create|Build|Make|New|Ensure|Resolve|Read|Load|Find|Lookup|Compute|Calc|Normalize|Parse|Collect|Decode|Encode)/, '');
  if (!s || s.length < 2) return null;
  if (/^[a-z]+$/.test(seg) && seg.length <= 4) return null; // 小写 Lua 内建，如 sort/len
  return lowerCamel(s);
}

function decodeVal(node) {
  if (node.type !== 'StringLiteral') return null;
  const d = decodeLuaString(node.raw);
  if (d === null) return null;
  try { return JSON.parse(d.replace(/\\(\d{1,3})/g, (m, x) => '\\u' + Number(x).toString(16).padStart(4, '0'))); } catch (e) { return null; }
}

function exprHint(e) {
  if (!e) return null;
  switch (e.type) {
    case 'MemberExpression': {
      const n = e.identifier.name;
      if (n === 'DB') return 'db';
      return lowerCamel(n);
    }
    case 'IndexExpression':
      if (e.index.type === 'StringLiteral') { const v = decodeVal(e.index); if (validName(v)) return lowerCamel(v); }
      { const b = exprHint(e.base); const s = typeof b === 'string' ? singular(b) : null; return s || 'entry'; }
    case 'CallExpression': case 'StringCallExpression': case 'TableCallExpression': {
      const fname = calleeName(e.base);
      const args = e.type === 'CallExpression' ? e.arguments : e.type === 'StringCallExpression' ? [e.argument] : [e.arguments];
      return nameFromCallee(fname, { arguments: args });
    }
    case 'TableConstructorExpression': return 'tbl';
    case 'StringLiteral': return 'str';
    case 'NumericLiteral': return null;
    case 'BooleanLiteral': return 'enabled';
    case 'FunctionDeclaration': return 'fn';
    case 'BinaryExpression':
      if (e.operator === '..') return 'text';
      if (e.operator === '#') return 'count';
      if (['==', '~=', '<', '>', '<=', '>='].includes(e.operator)) return 'matches';
      return null;
    case 'UnaryExpression':
      if (e.operator === '#') return 'count';
      if (e.operator === 'not') return 'isNot';
      return null;
    case 'LogicalExpression':
      return exprHint(e.left) || exprHint(e.right);
    default: return null;
  }
}

// ---------- 作用域分析 ----------
function analyze(src) {
  const ast = luaparse.parse(src, { luaVersion: '5.1', ranges: true, comments: false, scope: false, locations: true });
  const bindings = [];
  const globalRefs = new Map(); // name -> [pos]
  const strings = [];
  let scopes = [];
  const funcStack = [];

  function declare(idNode, kind, regionStart, regionEnd, extra) {
    const b = { id: bindings.length, orig: idNode.name, decl: idNode, kind, region: [regionStart, regionEnd], refs: [], hints: [], usage: [], line: idNode.loc.start.line, ...extra };
    bindings.push(b);
    scopes[scopes.length - 1].set(idNode.name, b);
    idNode._binding = b;
    return b;
  }
  function lookup(name) {
    for (let i = scopes.length - 1; i >= 0; i--) { const b = scopes[i].get(name); if (b) return b; }
    return null;
  }
  function ref(idNode) {
    const b = lookup(idNode.name);
    if (b) { b.refs.push(idNode); idNode._binding = b; }
    else { if (!globalRefs.has(idNode.name)) globalRefs.set(idNode.name, []); globalRefs.get(idNode.name).push(idNode.range[0]); }
    return b;
  }
  function addHint(b, name, score) {
    if (!b) return;
    if (Array.isArray(name)) return;
    if (typeof name === 'string') name = aliasName(name);
    if (validName(name)) b.hints.push({ name, score });
  }

  function walkBlock(body, blockEnd) {
    scopes.push(new Map());
    for (const st of body) walkStat(st, blockEnd);
    scopes.pop();
  }

  function bindingOf(e) { return e && e.type === 'Identifier' ? e._binding || null : null; }

  function walkFunction(fn, selfHints) {
    const [s, e] = fn.range;
    scopes.push(new Map());
    funcStack.push(fn);
    fn.parameters.forEach((p, i) => {
      if (p.type === 'Identifier') {
        const b = declare(p, 'param', s, e, { paramIndex: i, fn });
        if (selfHints && selfHints[i]) addHint(b, selfHints[i], 50);
      }
    });
    walkBlock(fn.body, e);
    funcStack.pop();
    scopes.pop();
  }

  function walkStat(st, blockEnd) {
    switch (st.type) {
      case 'LocalStatement': {
        st.init.forEach(walkExpr);
        st.variables.forEach((v, i) => {
          const b = declare(v, 'local', st.range[1], blockEnd, { initNode: st.init[i], stat: st });
          const init = st.init[i];
          if (init) {
            const h = exprHint(init);
            if (Array.isArray(h)) {} else addHint(b, h, init.type === 'MemberExpression' || init.type === 'IndexExpression' ? 30 : 20);
            if (init.type === 'VarargLiteral' && scopes.length === 2 && funcStack.length === 0) addHint(b, i === 0 ? 'addonName' : 'ns', 60);
          } else if (st.init.length && i >= st.init.length) {
            const last = st.init[st.init.length - 1];
            const h = exprHint(last);
            if (Array.isArray(h)) addHint(b, h[i - st.init.length + 1], 20);
            if (last.type === 'VarargLiteral' && funcStack.length === 0 && scopes.length === 2) addHint(b, 'ns', 60);
          }
          if (init) {
            const h = exprHint(init);
            if (Array.isArray(h) && i === st.init.length - 1) addHint(b, h[0], 20);
          }
        });
        return;
      }
      case 'FunctionDeclaration': {
        if (st.isLocal) {
          const b = declare(st.identifier, 'localfunc', st.identifier.range[0], blockEnd, { fnNode: st });
          walkFunction(st);
          return;
        }
        let selfHints = null;
        if (st.identifier) {
          walkExpr(st.identifier);
          if (st.identifier.type === 'MemberExpression') {
            const base = st.identifier.base;
            const bb = bindingOf(base);
            if (bb) selfHints = ['self'];
            st.identifier._isMethodDef = true;
          } else if (st.identifier.type === 'Identifier' && st.identifier._binding) {
            // f = function 形式给已声明局部赋值
          }
        }
        walkFunction(st, selfHints && false ? selfHints : null);
        if (st.identifier && st.identifier.type === 'MemberExpression' && bindingOf(st.identifier.base)) {
          const p0 = st.parameters[0];
          if (p0 && p0._binding) p0._binding.methodSelfCandidate = true;
        }
        return;
      }
      case 'AssignmentStatement': {
        st.init.forEach(walkExpr);
        st.variables.forEach(walkExpr);
        st.variables.forEach((v, i) => {
          const init = st.init[i];
          const tb = bindingOf(v);
          const ib = bindingOf(init);
          // T.field = local
          if (ib && (v.type === 'MemberExpression')) addHint(ib, lowerCamel(v.identifier.name), 25);
          if (ib && v.type === 'IndexExpression' && v.index.type === 'StringLiteral') { const n = decodeVal(v.index); if (validName(n)) addHint(ib, lowerCamel(n), 25); }
          // local = T.field
          if (tb && init) { const h = exprHint(init); if (!Array.isArray(h)) addHint(tb, h, 10); }
          if (init && init.type === 'FunctionDeclaration' && v.type === 'MemberExpression') {
            const p0 = init.parameters[0];
            if (p0 && p0._binding && bindingOf(v.base)) p0._binding.methodSelfCandidate = true;
          }
        });
        return;
      }
      case 'CallStatement': walkExpr(st.expression); return;
      case 'IfStatement':
        for (const c of st.clauses) { if (c.condition) walkExpr(c.condition); walkBlock(c.body, c.range[1]); }
        return;
      case 'WhileStatement': walkExpr(st.condition); walkBlock(st.body, st.range[1]); return;
      case 'DoStatement': walkBlock(st.body, st.range[1]); return;
      case 'RepeatStatement': {
        scopes.push(new Map());
        for (const s of st.body) walkStat(s, st.range[1]);
        walkExpr(st.condition);
        scopes.pop();
        return;
      }
      case 'ReturnStatement': st.arguments.forEach(walkExpr); return;
      case 'ForNumericStatement': {
        walkExpr(st.start); walkExpr(st.end); if (st.step) walkExpr(st.step);
        scopes.push(new Map());
        const b = declare(st.variable, 'fornum', st.range[0], st.range[1]);
        addHint(b, 'i', 15); b.loopIndex = true;
        walkBlock(st.body, st.range[1]);
        scopes.pop();
        return;
      }
      case 'ForGenericStatement': {
        st.iterators.forEach(walkExpr);
        scopes.push(new Map());
        const it = st.iterators[0];
        const fname = it && it.type === 'CallExpression' ? calleeName(it.base) : null;
        const tblHint = it && it.type === 'CallExpression' && it.arguments[0] ? exprHint(it.arguments[0]) : null;
        st.variables.forEach((v, i) => {
          const b = declare(v, 'forin', st.range[0], st.range[1]);
          if (fname === 'ipairs') {
            if (i === 0) addHint(b, 'i', 15);
            if (i === 1) { const s = typeof tblHint === 'string' ? singular(tblHint) : null; addHint(b, s || 'entry', s ? 25 : 12); }
          } else if (fname === 'pairs' || fname === 'next') {
            let keyName = 'key', valName = 'value', sc = 12;
            if (typeof tblHint === 'string') {
              let m = tblHint.match(/^(.*)By([A-Z][A-Za-z]*)$/);
              if (m) { keyName = lowerCamel(m[2]); if (/^(Spec|Spell|Item|Unit|Class|Action|Slot)$/.test(m[2])) keyName += 'ID'; if (m[2]==='Id'||m[2]==='ID') keyName='id'; valName = lowerCamel(m[1]); sc = 22; }
              else { const s = singular(tblHint); if (s) { valName = s; keyName = s + 'Key'; sc = 22; } }
            }
            if (i === 0) addHint(b, keyName, sc);
            if (i === 1) addHint(b, valName, sc);
          } else if (fname && /gmatch$/.test(fname)) {
            addHint(b, i === 0 ? 'token' : 'capture' + (i + 1), 12);
          } else {
            addHint(b, ['k', 'v', 'extra'][i] || 'x', 5);
          }
        });
        walkBlock(st.body, st.range[1]);
        scopes.pop();
        return;
      }
      case 'BreakStatement': case 'LabelStatement': case 'GotoStatement': return;
      default: throw new Error('unknown stat ' + st.type);
    }
  }

  function noteArgUsage(fname, args) {
    if (!fname) return;
    for (const [re, names] of API_ARG_HINTS) {
      if (re.test(fname) && names) {
        args.forEach((a, i) => { const b = bindingOf(a); if (b && names[i]) addHint(b, names[i], 18); });
        break;
      }
    }
    const seg = lastSeg(fname);
    if ((seg === 'pairs' || seg === 'ipairs') && bindingOf(args[0])) addHint(bindingOf(args[0]), 'tbl', 3);
    if ((seg === 'insert' && fname.startsWith('table')) && bindingOf(args[0])) addHint(bindingOf(args[0]), 'list', 8);
    if ((seg === 'CreateFrame') && bindingOf(args[3 - 1])) addHint(bindingOf(args[2]), 'parent', 15);
    if ((seg === 'pcall' || seg === 'xpcall') && bindingOf(args[0])) addHint(bindingOf(args[0]), 'func', 5);
    if (seg === 'wipe' && bindingOf(args[0])) addHint(bindingOf(args[0]), 'tbl', 5);
    if (seg === 'tostring' && bindingOf(args[0])) addHint(bindingOf(args[0]), 'value', 2);
    if (seg === 'type' && bindingOf(args[0])) addHint(bindingOf(args[0]), 'value', 2);
  }

  function walkExpr(e) {
    if (!e) return;
    switch (e.type) {
      case 'Identifier': ref(e); return;
      case 'StringLiteral': strings.push(e); return;
      case 'NumericLiteral': case 'BooleanLiteral': case 'NilLiteral': case 'VarargLiteral': return;
      case 'TableConstructorExpression':
        for (const f of e.fields) {
          if (f.type === 'TableKey') { walkExpr(f.key); walkExpr(f.value); if (f.key.type === 'StringLiteral' && bindingOf(f.value)) { const n = decodeVal(f.key); if (validName(n)) addHint(bindingOf(f.value), lowerCamel(n), 22); } }
          else if (f.type === 'TableKeyString') { walkExpr(f.value); if (bindingOf(f.value)) addHint(bindingOf(f.value), lowerCamel(f.key.name), 22); if (f.value.type==='FunctionDeclaration'){ const p0=f.value.parameters[0]; } }
          else walkExpr(f.value);
        }
        return;
      case 'BinaryExpression': case 'LogicalExpression':
        walkExpr(e.left); walkExpr(e.right);
        if ((e.operator === '==' || e.operator === '~=')) {
          const pair = [[e.left, e.right], [e.right, e.left]];
          for (const [a, c] of pair) {
            const b = bindingOf(a);
            if (b && c.type === 'StringLiteral') { const v = decodeVal(c); if (v && /^[A-Z][A-Z_]{4,}$/.test(v)) addHint(b, 'event', 14); }
          }
        }
        return;
      case 'UnaryExpression': walkExpr(e.argument); if (e.operator === '#' && bindingOf(e.argument)) addHint(bindingOf(e.argument), 'list', 4); return;
      case 'MemberExpression': {
        walkExpr(e.base);
        const b = bindingOf(e.base);
        if (b) { b.usage.push(e.identifier.name); if (e.indexer === ':' && METHOD_KIND[e.identifier.name]) addHint(b, METHOD_KIND[e.identifier.name], 6); }
        return;
      }
      case 'IndexExpression': walkExpr(e.base); walkExpr(e.index); return;
      case 'CallExpression': case 'StringCallExpression': case 'TableCallExpression': {
        walkExpr(e.base);
        const args = e.type === 'CallExpression' ? e.arguments : e.type === 'StringCallExpression' ? [e.argument] : [e.arguments];
        const fname = calleeName(e.base);
        // SetScript / HookScript 处理器参数
        if (e.base.type === 'MemberExpression' && (e.base.identifier.name === 'SetScript' || e.base.identifier.name === 'HookScript') && args[0] && args[0].type === 'StringLiteral' && args[1] && args[1].type === 'FunctionDeclaration') {
          const sname = decodeVal(args[0]);
          args[1]._scriptParams = SCRIPT_PARAMS[sname] || ['self'];
        }
        if (fname && /(^|\.)(C_Timer\.After|C_Timer\.NewTimer|C_Timer\.NewTicker)$/.test(fname) && args[1] && args[1].type === 'FunctionDeclaration') {
          args[1]._scriptParams = fname.endsWith('After') ? [] : ['timer'];
        }
        if (fname === 'hooksecurefunc') {}
        for (const a of args) {
          if (a.type === 'FunctionDeclaration') walkFunctionExpr(a);
          else walkExpr(a);
        }
        noteArgUsage(fname, args);
        // 被调用的局部函数：调用者传的实参名可作为形参提示（在后处理阶段完成）
        const cb = bindingOf(e.base);
        if (cb) cb.calls = (cb.calls || 0) + 1, (cb.callSites = cb.callSites || []).push(args);
        return;
      }
      case 'FunctionDeclaration': walkFunctionExpr(e); return;
      default: throw new Error('unknown expr ' + e.type);
    }
  }
  function walkFunctionExpr(fn) {
    walkFunction(fn, fn._scriptParams || null);
  }

  scopes.push(new Map()); // 全局
  walkBlock(ast.body, src.length + 1);
  return { ast, bindings, globalRefs, strings };
}

// 局部函数命名：查看被赋给哪个字段
function inferFunctionNames(bindings) {
  for (const b of bindings) {
    if (b.kind === 'localfunc' || (b.initNode && b.initNode.type === 'FunctionDeclaration')) {
      b.isFunc = true;
    }
  }
}

function chooseNames(bindings, globalRefs, overrides) {
  // 计算未使用参数
  const byName = new Map();
  const finalName = new Map();
  const ordered = bindings.slice().sort((a, b) => a.decl.range[0] - b.decl.range[0]);
  function conflicts(b, name) {
    if (KEYWORDS.has(name)) return true;
    const g = globalRefs.get(name);
    if (g && g.some(p => p >= b.region[0] && p <= b.region[1])) return true;
    // 名字与全局冲突的另一种情况：b 的引用处不受影响；但若 b 的作用域内有同名全局引用则冲突（已检查）
    const others = byName.get(name) || [];
    for (const o of others) {
      if (o === b) continue;
      const [bs, be] = b.region, [os, oe] = o.region;
      const bInO = bs >= os && be <= oe;
      const oInB = os >= bs && oe <= be;
      if (!bInO && !oInB) continue;
      if (bInO) { // b 更内层：o 在 b 区域内的引用会被遮蔽
        if (o.refs.some(r => r.range[0] >= bs && r.range[0] <= be)) return true;
        if (bs === os && be === oe) { // 同一区域（如同一函数的参数）
          return true;
        }
      }
      if (oInB) {
        if (b.refs.some(r => r.range[0] >= os && r.range[0] <= oe)) return true;
      }
    }
    return false;
  }
  function assign(b, name) {
    finalName.set(b, name);
    if (!byName.has(name)) byName.set(name, []);
    byName.get(name).push(b);
  }
  const counters = {};
  for (const b of ordered) {
    let cands = [];
    const ov = overrides && overrides.get(b.line + ':' + b.orig);
    if (KEEP_MODE) {
      const want = ov || b.orig;
      if (want !== '_' && conflicts(b, want)) throw new Error(`重命名冲突: 第${b.line}行 ${b.orig} -> ${want}`);
      assign(b, want); if (ov) overrides.delete(b.line + ':' + b.orig); continue;
    }
    if (ov) cands.push({ name: ov, score: 1000 });
    if (b.kind === 'param' && b.refs.length === 0) cands.push({ name: '_', score: 900 });
    if (b.kind === 'forin' && b.refs.length === 0) cands.push({ name: '_', score: 900 });
    if (b.kind === 'param' && b.paramIndex === 0 && b.methodSelfCandidate && (b.refs.length === 0)) cands.push({ name: 'self', score: 95 });
    // 汇总 hints
    const agg = new Map();
    for (const h of b.hints) agg.set(h.name, Math.max(agg.get(h.name) || 0, h.score) + (agg.has(h.name) ? 1 : 0));
    for (const [name, score] of agg) cands.push({ name, score });
    cands.sort((x, y) => y.score - x.score);
    let chosen = null;
    for (const c of cands) {
      if (c.name === '_' ) { chosen = '_'; break; }
      if (!conflicts(b, c.name)) { chosen = c.name; break; }
    }
    if (!chosen && b.loopIndex) for (const n of ['j', 'k', 'n', 'idx']) if (!conflicts(b, n)) { chosen = n; break; }
    if (!chosen && cands.length) {
      const base = cands[0].name;
      for (let i = 2; i < 100; i++) if (!conflicts(b, base + i)) { chosen = base + i; break; }
    }
    if (!chosen) {
      let base = b.kind === 'param' ? 'arg' : (b.kind === 'localfunc' || (b.initNode && b.initNode.type === 'FunctionDeclaration')) ? 'helper' : b.kind === 'forin' ? 'item' : 'value';
      if (b.kind === 'local' && b.initNode && b.initNode.type === 'NumericLiteral') base = 'CONST';
      for (let i = 1; i < 10000; i++) {
        const n = base === 'arg' ? base + (b.paramIndex + 1) + (i > 1 ? '_' + i : '') : base + i;
        if (base !== 'arg' && counters[base + '#' + n]) continue;
        if (!conflicts(b, n)) { chosen = n; break; }
      }
    }
    assign(b, chosen);
  }
  return finalName;
}

function run(inFile, outFile, renameFile) {
  const src = fs.readFileSync(inFile, 'utf8');
  const { bindings, globalRefs, strings } = analyze(src);
  inferFunctionNames(bindings);
  let overrides = null;
  if (renameFile && fs.existsSync(renameFile)) {
    overrides = new Map();
    for (const r of JSON.parse(fs.readFileSync(renameFile, 'utf8'))) overrides.set(r.line + ':' + r.name, r.to);
  }
  const names = chooseNames(bindings, globalRefs, overrides);
  if (KEEP_MODE && overrides && overrides.size) throw new Error('未匹配的重命名: ' + [...overrides.keys()].join(', '));
  const edits = [];
  for (const b of bindings) {
    const n = names.get(b);
    if (n === b.orig) continue;
    edits.push([b.decl.range[0], b.decl.range[1], n]);
    for (const r of b.refs) edits.push([r.range[0], r.range[1], n]);
  }
  for (const s of strings) {
    const d = decodeLuaString(s.raw);
    if (d !== null && d !== s.raw) edits.push([s.range[0], s.range[1], d]);
  }
  edits.sort((a, b) => b[0] - a[0]);
  let out = src;
  let last = Infinity;
  for (const [s, e, t] of edits) {
    if (e > last) throw new Error('overlapping edits at ' + s);
    out = out.slice(0, s) + t + out.slice(e);
    last = s;
  }
  fs.writeFileSync(outFile, out);
  const unnamed = [...names.values()].filter(n => /^(value|helper|arg|item)\d/.test(n)).length;
  return { bindings: bindings.length, unnamed };
}

let KEEP_MODE = false;
if (require.main === module) {
  const argv = process.argv.slice();
  if (argv.includes('--keep')) { KEEP_MODE = true; argv.splice(argv.indexOf('--keep'), 1); }
  const [, , inF, outF, ren] = argv;
  const r = run(inF, outF, ren);
  console.error(`${inF}: ${r.bindings} 个局部绑定, ${r.unnamed} 个使用兜底名`);
}
module.exports = { run, analyze, decodeLuaString };
