// 语义等价校验：将两个文件规范化（局部变量按绑定编号替换、字符串按解码值、去位置信息）后比较
'use strict';
function strBytes(raw) {
  const body = raw.slice(1, -1); const bytes = [];
  const simple = { a: 7, b: 8, f: 12, n: 10, r: 13, t: 9, v: 11, '\\': 92, '"': 34, "'": 39, '\n': 10 };
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (c !== '\\') { bytes.push(...Buffer.from(c, 'utf8')); continue; }
    const n = body[++i];
    if (n in simple) { bytes.push(simple[n]); continue; }
    let d = n; while (d.length < 3 && /[0-9]/.test(body[i + 1])) d += body[++i];
    if (!/^[0-9]+$/.test(d)) throw new Error('bad escape ' + raw);
    bytes.push(+d);
  }
  return Buffer.from(bytes).toString('hex');
}
const fs = require('fs');
const { analyze } = require('./deob.js');
function norm(file) {
  const src = fs.readFileSync(file, 'utf8');
  const { ast, bindings } = analyze(src);
  const ids = new Map(); bindings.forEach((b, i) => ids.set(b, i));
  const seen = new WeakSet();
  function walk(n) {
    if (Array.isArray(n)) return n.map(walk);
    if (!n || typeof n !== 'object') return n;
    const o = {};
    for (const k of Object.keys(n).sort()) {
      if (['range', 'loc', 'raw', '_binding', '_scriptParams', '_isMethodDef', 'isLocal' ].includes(k)) continue;
      o[k] = walk(n[k]);
    }
    if (n.type === 'Identifier' && n._binding) o.name = '#' + ids.get(n._binding);
    if (n.type === 'StringLiteral') { const s=n.raw; o.value = strBytes(s); }
    if (n.type === 'NumericLiteral') o.value = Number(n.raw);
    if (n.type === 'Identifier' && n._binding === undefined) o.global = true;
    return o;
  }
  return JSON.stringify(walk(ast.body));
}
const [, , a, b] = process.argv;
const na = norm(a), nb = norm(b);
if (na !== nb) {
  let i = 0; while (na[i] === nb[i]) i++;
  console.log('不一致', a, b, '\n', na.slice(Math.max(0,i-200), i+200), '\n---\n', nb.slice(Math.max(0,i-200), i+200));
  process.exit(1);
}
console.log('一致', b);
