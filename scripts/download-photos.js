const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const PUBLIC_DIR = path.join(__dirname, '..', 'public');
const DEALERS_DIR = path.join(PUBLIC_DIR, 'dealers');
const AVATARS_DIR = path.join(PUBLIC_DIR, 'avatars');

[DEALERS_DIR, AVATARS_DIR].forEach(d => {
  if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
});

function fetchText(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      },
      timeout: 15000,
    }, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
  });
}

function downloadFile(url, outPath) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http;
    const req = mod.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/*,*/*',
      },
      timeout: 30000,
    }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        const newUrl = res.headers.location.startsWith('http') ? res.headers.location : new URL(res.headers.location, url).href;
        downloadFile(newUrl, outPath).then(resolve).catch(reject);
        return;
      }
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        if (buf.length < 5000) {
          reject(new Error(`image too small: ${buf.length}B`));
          return;
        }
        fs.writeFileSync(outPath, buf);
        resolve();
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
  });
}

// Extract image URLs from Bing image search HTML
function extractBingImages(html) {
  const urls = [];
  // murl pattern in Bing image search results
  const regex = /murl&quot;:&quot;(https?:[^&]+)&quot;/g;
  let match;
  while ((match = regex.exec(html)) !== null) {
    const url = match[1].replace(/\\u002f/g, '/').replace(/\\/g, '');
    if (url.match(/\.(jpg|jpeg|png|webp)/i) && !urls.includes(url)) {
      urls.push(url);
    }
  }
  // Also try mediaurl pattern
  if (urls.length === 0) {
    const regex2 = /mediaurl=(https?[^&"']+)/g;
    while ((match = regex2.exec(html)) !== null) {
      const url = decodeURIComponent(match[1]);
      if (url.match(/\.(jpg|jpeg|png|webp)/i)) urls.push(url);
    }
  }
  // Also try src pattern
  if (urls.length === 0) {
    const regex3 = /src="(https?:\/\/[^"]+\.(?:jpg|jpeg|png)[^"]*)"/gi;
    while ((match = regex3.exec(html)) !== null) {
      urls.push(match[1]);
    }
  }
  return urls;
}

async function searchAndDownload(query, fileName, outDir) {
  const searchUrl = `https://cn.bing.com/images/search?q=${encodeURIComponent(query)}&form=HDRSC2&first=1`;
  try {
    const html = await fetchText(searchUrl);
    const imgUrls = extractBingImages(html);
    if (imgUrls.length === 0) {
      console.log(`FAIL: ${fileName} (no images found)`);
      return false;
    }
    // Try up to 5 URLs
    for (let i = 0; i < Math.min(5, imgUrls.length); i++) {
      const imgUrl = imgUrls[i];
      const ext = imgUrl.match(/\.(jpg|jpeg|png|webp)/i) ? imgUrl.match(/\.(jpg|jpeg|png|webp)/i)[1].toLowerCase().replace('jpeg', 'jpg') : 'jpg';
      const outPath = path.join(outDir, `${fileName}.${ext}`);
      try {
        await downloadFile(imgUrl, outPath);
        const size = fs.statSync(outPath).size;
        console.log(`OK: ${fileName} (${(size / 1024).toFixed(0)}KB) from ${imgUrl.substring(0, 60)}...`);
        return true;
      } catch (e) {
        // Try next URL
      }
    }
    console.log(`FAIL: ${fileName} (all ${imgUrls.length} URLs failed)`);
    return false;
  } catch (e) {
    console.log(`FAIL: ${fileName} (${e.message})`);
    return false;
  }
}

const dealers = [
  ['刘亦菲 写真', 'liuyifei'],
  ['金晨 写真', 'jinchen'],
  ['Sydney Sweeney 写真', 'sydney_sweeney'],
  ['迪丽热巴 写真', 'dilraba'],
  ['杨幂 写真', 'yangmi'],
  ['赵丽颖 写真', 'zhaoliying'],
  ['佟丽娅 写真', 'tongliya'],
  ['高圆圆 写真', 'gaoyuanyuan'],
  ['刘诗诗 写真', 'liushishi'],
  ['倪妮 写真', 'nini'],
  ['江疏影 写真', 'jiangshuying'],
  ['王鸥 写真', 'wangou'],
  ['秦岚 写真', 'qinlan'],
  ['宋茜 写真', 'songqian'],
  ['李一桐 写真', 'liyitong'],
  ['白鹿 演员 写真', 'bailu'],
  ['赵露思 写真', 'zhaolusi'],
  ['虞书欣 写真', 'yushuxin'],
  ['张婧仪 写真', 'zhangjingyi'],
  ['程潇 写真', 'chengxiao'],
];

const avatars = [
  ['周星驰 写真', 'zhouxingchi'],
  ['周润发 写真', 'zhouyunfa'],
  ['刘德华 写真', 'liudehua'],
  ['张家辉 写真', 'zhangjiahui'],
  ['谢霆锋 写真', 'xietingfeng'],
  ['Daniel Negreanu poker', 'daniel_negreanu'],
  ['Phil Ivey poker', 'phil_ivey'],
  ['Tom Dwan poker', 'tom_dwan'],
  ['Doyle Brunson poker', 'doyle_brunson'],
  ['Phil Hellmuth poker', 'phil_hellmuth'],
];

async function main() {
  let okD = 0, failD = 0, okA = 0, failA = 0;

  console.log('=== Downloading dealers (Bing Images) ===');
  for (const [query, fileName] of dealers) {
    const success = await searchAndDownload(query, fileName, DEALERS_DIR);
    if (success) okD++; else failD++;
    await new Promise(r => setTimeout(r, 1500));
  }

  console.log('\n=== Downloading avatars (Bing Images) ===');
  for (const [query, fileName] of avatars) {
    const success = await searchAndDownload(query, fileName, AVATARS_DIR);
    if (success) okA++; else failA++;
    await new Promise(r => setTimeout(r, 1500));
  }

  console.log(`\n=== DONE: dealers ${okD}ok/${failD}fail, avatars ${okA}ok/${failA}fail ===`);

  // List all files
  console.log('\n--- Dealers ---');
  fs.readdirSync(DEALERS_DIR).forEach(f => {
    if (f.endsWith('.jpg') || f.endsWith('.png') || f.endsWith('.jpeg') || f.endsWith('.webp')) {
      const s = fs.statSync(path.join(DEALERS_DIR, f)).size;
      console.log(`  ${f} (${(s/1024).toFixed(0)}KB)`);
    }
  });
  console.log('\n--- Avatars ---');
  fs.readdirSync(AVATARS_DIR).forEach(f => {
    const s = fs.statSync(path.join(AVATARS_DIR, f)).size;
    console.log(`  ${f} (${(s/1024).toFixed(0)}KB)`);
  });
}

main().catch(console.error);
