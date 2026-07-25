import fs from 'fs';
import path from 'path';
import { execFileSync } from 'child_process';

const repoRoot = '/Users/hua/Documents/project/Reference/LookHealthClient';
const sourceRoot = path.join(repoRoot, 'SparkClient/SparkClient/Projects/App/Resources/Assets.xcassets/AI');
const targetRoot = path.join(repoRoot, 'SparkClientHarmonyOS/entry/src/main/resources/base/media');

function sanitizeName(name) {
  if (/^defaulticon$/i.test(name.replace(/\.imageset$/i, ''))) {
    return 'default_icon';
  }
  return name
    .replace(/\.imageset$/i, '')
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();
}

function pickSourceFile(imagesetDir) {
  const contentsPath = path.join(imagesetDir, 'Contents.json');
  if (fs.existsSync(contentsPath)) {
    try {
      const contents = JSON.parse(fs.readFileSync(contentsPath, 'utf8'));
      if (Array.isArray(contents.images)) {
        for (const entry of contents.images) {
          if (entry && typeof entry.filename === 'string' && entry.filename.length > 0) {
            const candidate = path.join(imagesetDir, entry.filename);
            if (fs.existsSync(candidate)) {
              return candidate;
            }
          }
        }
      }
    } catch (_e) {
      // fall through to file scan
    }
  }
  const files = fs.readdirSync(imagesetDir)
    .filter((name) => name !== 'Contents.json')
    .map((name) => path.join(imagesetDir, name))
    .filter((candidate) => fs.statSync(candidate).isFile());
  if (files.length === 0) {
    return undefined;
  }
  files.sort((a, b) => {
    const aBase = path.basename(a);
    const bBase = path.basename(b);
    return aBase.localeCompare(bBase);
  });
  return files[0];
}

function exportImageset(imagesetDir) {
  const sourceFile = pickSourceFile(imagesetDir);
  if (!sourceFile) {
    return null;
  }
  const resourceName = sanitizeName(path.basename(imagesetDir));
  const targetFile = path.join(targetRoot, `${resourceName}.png`);
  execFileSync('/usr/bin/sips', ['-s', 'format', 'png', sourceFile, '--out', targetFile], {
    stdio: 'ignore'
  });
  return { resourceName, sourceFile, targetFile };
}

fs.mkdirSync(targetRoot, { recursive: true });

const imagesets = fs.readdirSync(sourceRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && entry.name.endsWith('.imageset'))
  .map((entry) => path.join(sourceRoot, entry.name))
  .sort((a, b) => path.basename(a).localeCompare(path.basename(b)));

const exported = [];
for (const imagesetDir of imagesets) {
  const item = exportImageset(imagesetDir);
  if (item) {
    exported.push(item);
  }
}

console.log(`Exported ${exported.length} imagesets to ${targetRoot}`);
for (const item of exported) {
  console.log(`${item.resourceName}.png <- ${path.basename(path.dirname(item.sourceFile))}/${path.basename(item.sourceFile)}`);
}
