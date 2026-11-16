// One command from the repo root:
//   node tool/generate_app_icons.mjs
//
// Rasterizes design/app_icon.svg into the Android, iOS, macOS, Windows, and
// Linux icon files. The first run installs the rasterizer under tool/.

import { spawnSync } from 'node:child_process'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const toolDir = dirname(fileURLToPath(import.meta.url))
const root = dirname(toolDir)

const androidLegacy = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
]

const androidForeground = [
  ['mipmap-mdpi', 108],
  ['mipmap-hdpi', 162],
  ['mipmap-xhdpi', 216],
  ['mipmap-xxhdpi', 324],
  ['mipmap-xxxhdpi', 432],
]

const ios = [
  ['Icon-App-20x20@1x.png', 20],
  ['Icon-App-20x20@2x.png', 40],
  ['Icon-App-20x20@3x.png', 60],
  ['Icon-App-29x29@1x.png', 29],
  ['Icon-App-29x29@2x.png', 58],
  ['Icon-App-29x29@3x.png', 87],
  ['Icon-App-40x40@1x.png', 40],
  ['Icon-App-40x40@2x.png', 80],
  ['Icon-App-40x40@3x.png', 120],
  ['Icon-App-60x60@2x.png', 120],
  ['Icon-App-60x60@3x.png', 180],
  ['Icon-App-76x76@1x.png', 76],
  ['Icon-App-76x76@2x.png', 152],
  ['Icon-App-83.5x83.5@2x.png', 167],
  ['Icon-App-1024x1024@1x.png', 1024],
]

const macos = [16, 32, 64, 128, 256, 512, 1024]
const windows = [16, 24, 32, 48, 64, 128, 256]

async function loadResvg() {
  try {
    return await import('@resvg/resvg-js')
  } catch {
    const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm'
    const install = spawnSync(npm, ['install'], {
      cwd: toolDir,
      stdio: 'inherit',
      shell: true,
    })
    if (install.status !== 0) {
      process.exit(install.status ?? 1)
    }
    return import('@resvg/resvg-js')
  }
}

function renderPng(Resvg, svg, size) {
  const png = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
  })
    .render()
    .asPng()
  return Buffer.from(png)
}

function writePng(path, png) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, png)
}

function ico(images) {
  const header = 6
  const entry = 16
  let offset = header + entry * images.length
  const dir = Buffer.alloc(offset)
  dir.writeUInt16LE(0, 0)
  dir.writeUInt16LE(1, 2)
  dir.writeUInt16LE(images.length, 4)
  const parts = [dir]
  for (const [index, image] of images.entries()) {
    const at = header + index * entry
    const side = image.size >= 256 ? 0 : image.size
    dir.writeUInt8(side, at)
    dir.writeUInt8(side, at + 1)
    dir.writeUInt16LE(1, at + 4)
    dir.writeUInt16LE(32, at + 6)
    dir.writeUInt32LE(image.png.length, at + 8)
    dir.writeUInt32LE(offset, at + 12)
    offset += image.png.length
    parts.push(image.png)
  }
  return Buffer.concat(parts)
}

const { Resvg } = await loadResvg()
const svg = readFileSync(join(root, 'design', 'app_icon.svg'), 'utf8')
const cache = new Map()

function pngAt(size) {
  const cached = cache.get(size)
  if (cached) return cached
  const png = renderPng(Resvg, svg, size)
  cache.set(size, png)
  return png
}

const androidRes = join(root, 'android', 'app', 'src', 'main', 'res')
for (const [folder, size] of androidLegacy) {
  writePng(join(androidRes, folder, 'ic_launcher.png'), pngAt(size))
}
for (const [folder, size] of androidForeground) {
  writePng(join(androidRes, folder, 'ic_launcher_foreground.png'), pngAt(size))
}

const iosDir = join(root, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
for (const [name, size] of ios) {
  writePng(join(iosDir, name), pngAt(size))
}

const macDir = join(root, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
for (const size of macos) {
  writePng(join(macDir, `app_icon_${size}.png`), pngAt(size))
}

const windowsIco = ico(windows.map((size) => ({ size, png: pngAt(size) })))
writeFileSync(join(root, 'windows', 'runner', 'resources', 'app_icon.ico'), windowsIco)

writePng(
  join(root, 'linux', 'runner', 'resources', 'app_icon.png'),
  pngAt(256),
)

console.log(`Wrote icons from design/app_icon.svg (${cache.size} sizes).`)
