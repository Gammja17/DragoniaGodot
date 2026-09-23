// 2D판(_ref2d/src)의 데이터 모듈을 data/*.json 으로 한 번 옮긴다.
//
//   node tools/export_data.mjs
//
// 2D판은 이식이 끝날 때까지 동결이라 계속 맞춰 줄 필요는 없다. 대사·수치를 손으로 옮기면
// 글자 하나씩 어긋나기 쉬워서 기계로 옮긴다.
//
// 데이터 안에 섞인 함수(퀘스트 조건 등)는 JSON 이 담을 수 없다. { "$fn": "원래 소스" } 로 남겨 두고
// GDScript 로 옮긴 쪽(scripts/data/conditions.gd)이 같은 자리를 채운다. 옮기지 않은 것이
// 남아 있으면 게임이 불러올 때 경고한다.
import { readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, '_ref2d', 'src');
const out = join(root, 'data');
mkdirSync(out, { recursive: true });

// 2D판 모듈 가운데 데이터로 쓰는 것들. src/data 전부 + 데이터 표가 들어 있는 몇 개
const modules = readdirSync(join(src, 'data')).filter(f => f.endsWith('.js')).map(f => 'data/' + f);
modules.push('world/biomes.js', 'core/config.js', 'systems/relics.js');

let fnCount = 0;
// at: 모듈 안에서의 경로 (예 'CHAPTERS.0.done'). 같은 소스의 함수라도 클로저가 붙잡은 값이 다를 수 있어
// (chapters.js 의 done('m2')) GDScript 쪽은 경로로도 찾을 수 있게 남긴다
function plain(v, seen = new Set(), at = '') {
    if (typeof v === 'function') { fnCount++; return { $fn: v.toString(), $at: at }; }
    if (v === undefined) return null;
    if (typeof v === 'number' && !Number.isFinite(v)) return null;
    if (v === null || typeof v !== 'object') return v;
    if (seen.has(v)) return { $ref: 'cycle' };
    seen.add(v);
    let r;
    const sub = (k) => at ? at + '.' + k : String(k);
    if (Array.isArray(v) || ArrayBuffer.isView(v)) r = Array.from(v, (x, i) => plain(x, seen, sub(i)));
    else if (v instanceof Set) r = [...v].map((x, i) => plain(x, seen, sub(i)));
    else if (v instanceof Map) r = Object.fromEntries([...v].map(([k, x]) => [k, plain(x, seen, sub(k))]));
    else r = Object.fromEntries(Object.entries(v).map(([k, x]) => [k, plain(x, seen, sub(k))]));
    seen.delete(v);
    return r;
}

// 브라우저 전역을 건드리는 모듈이 있어도 불러올 수 있게 최소한만 흉내 낸다
globalThis.window ??= { innerWidth: 1280, innerHeight: 720 };
globalThis.localStorage ??= { getItem: () => null, setItem() {} };

for (const m of modules) {
    const mod = await import(pathToFileURL(join(src, m)).href);
    const name = m.replace(/\//g, '_').replace(/\.js$/, '').replace(/^data_/, '');
    const before = fnCount;
    const json = {};
    for (const [k, v] of Object.entries(mod)) {
        // 모듈 바로 아래의 함수(헬퍼)는 데이터가 아니라 코드라 GDScript 쪽에서 따로 옮긴다
        if (typeof v === 'function') continue;
        json[k] = plain(v, new Set(), k);
    }
    writeFileSync(join(out, name + '.json'), JSON.stringify(json, null, 1));
    console.log(`${m} → data/${name}.json${fnCount > before ? `  (함수 ${fnCount - before}개)` : ''}`);
}

// 코드로 찍은 픽셀 아이콘(render/pixel.js 의 ICONS)은 모듈 밖으로 나오지 않는 상수라 소스에서 떠 온다
const pixelSrc = readFileSync(join(src, 'render', 'pixel.js'), 'utf8');
const iconsAt = pixelSrc.indexOf('const ICONS = {');
const iconsSrc = pixelSrc.slice(iconsAt + 'const ICONS = '.length, pixelSrc.indexOf('\n};', iconsAt) + 2);
writeFileSync(join(out, 'icons.json'), JSON.stringify({ ICONS: new Function('return ' + iconsSrc)() }, null, 1));
console.log('render/pixel.js ICONS → data/icons.json');

console.log(`끝. 데이터 속 함수 ${fnCount}개는 GDScript 로 옮겨야 한다.`);
