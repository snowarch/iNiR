import fs from 'fs';
import path from 'path';
import translate from 'translate-google';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const dir = path.join(__dirname, '..'); // translations folder

const args = process.argv.slice(2);
let targetFile = args[0];

if (!targetFile) {
  console.log("Usage: node auto-translate.js <lang_code>");
  console.log("Example: node auto-translate.js pt_BR");
  process.exit(1);
}

if (!targetFile.endsWith('.json')) {
  targetFile += '.json';
}

const filePaths = fs.readdirSync(dir).filter(f => f.endsWith('.json'));

if (!filePaths.includes(targetFile)) {
  console.error(`Error: File ${targetFile} not found in ${dir}`);
  process.exit(1);
}

const langMap = {
  'es_AR.json': 'es', 'he_HE.json': 'iw', 'it_IT.json': 'it',
  'ja_JP.json': 'ja', 'ru_RU.json': 'ru', 'uk_UA.json': 'uk',
  'vi_VN.json': 'vi', 'zh_CN.json': 'zh-cn', 'pt_BR.json': 'pt',
  'hi_IN.json': 'hi', 'fr_FR.json': 'fr', 'de_DE.json': 'de',
  'ko_KR.json': 'ko', 'ar_SA.json': 'ar'
};

const targetLang = langMap[targetFile];

if (!targetLang) {
  console.error(`Error: No google translate code mapped for ${targetFile}`);
  console.error(`Please add it to langMap in auto-translate.js`);
  process.exit(1);
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function run() {
  console.log(`Processing ${targetFile} (to ${targetLang})...`);
  const filePath = path.join(dir, targetFile);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  
  const keysToTranslate = Object.keys(data).filter(k => {
    if (data[k] && data[k].endsWith('/*keep*/')) return false;
    return data[k] === k || !data[k];
  });
  
  console.log(`Found ${keysToTranslate.length} keys to translate.`);
  if (keysToTranslate.length === 0) {
    console.log("Nothing to do.");
    return;
  }
  
  const batchSize = 100;
  for (let i = 0; i < keysToTranslate.length; i += batchSize) {
    const batchKeys = keysToTranslate.slice(i, i + batchSize);
    console.log(` Translating batch ${i} to ${i + batchSize} of ${keysToTranslate.length}...`);
    
    try {
      const batchValues = await translate(batchKeys, { to: targetLang });
      for (let j = 0; j < batchKeys.length; j++) {
        data[batchKeys[j]] = batchValues[j];
      }
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    } catch (err) {
      console.error(`Error on batch ${i}:`, err.message);
      await sleep(5000);
      i -= batchSize;
    }
    
    await sleep(1000);
  }
  
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  console.log(`Finished ${targetFile}.`);
}

run();
