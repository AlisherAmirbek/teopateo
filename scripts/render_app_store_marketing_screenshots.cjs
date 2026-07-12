#!/usr/bin/env node

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_MODULE,
    "playwright",
    path.join(
      os.homedir(),
      ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright"
    ),
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      return require(candidate);
    } catch (_) {
      // Try the next known installation location.
    }
  }

  throw new Error(
    "Playwright was not found. Install it with `npm install playwright` or set PLAYWRIGHT_MODULE."
  );
}

const { chromium } = loadPlaywright();
const root = path.resolve(__dirname, "..");
const rawRoot = path.join(root, "AppStore", "screenshots-raw");
const outputRoot = path.join(root, "AppStore", "screenshots");

const stories = [
  {
    file: "01-today.png",
    label: "TODAY",
    title: "Your quit plan starts today",
    subtitle: "See the next risk, one clear action, and the progress that matters.",
    background: "#f7f4ed",
    ink: "#3d2a1f",
    muted: "#7c6656",
    glow: "#f8d7aa",
    badge: "#b2c4a4",
    border: "#3f281b",
  },
  {
    file: "02-craving-rescue.png",
    label: "10-MINUTE RESCUE",
    title: "Beat the next craving",
    subtitle: "One tap starts a focused rescue before you decide.",
    background: "#f8d7aa",
    ink: "#3d2a1f",
    muted: "#5b3b29",
    glow: "#fffef9",
    badge: "#b2c4a4",
    border: "#3f281b",
  },
  {
    file: "03-plan.png",
    label: "PERSONAL QUIT PLAN",
    title: "Know exactly what to do next",
    subtitle: "Turn coffee, meals, and stress into specific replacement actions.",
    background: "#eaf0e4",
    ink: "#3d2a1f",
    muted: "#7c6656",
    glow: "#f8d7aa",
    badge: "#b2c4a4",
    border: "#3f281b",
  },
  {
    file: "04-insights.png",
    label: "PERSONAL INSIGHTS",
    title: "See risk before it repeats",
    subtitle: "Learn from your cravings, slips, and high-risk windows.",
    background: "#f7f4ed",
    ink: "#3d2a1f",
    muted: "#7c6656",
    glow: "#b2c4a4",
    badge: "#f8d7aa",
    border: "#3f281b",
  },
  {
    file: "05-ai-coach.png",
    label: "AI QUIT COACH",
    title: "Get help before you smoke",
    subtitle: "Consent-first AI support grounded in your quit plan.",
    background: "#3f281b",
    ink: "#fffef9",
    muted: "#f8d7aa",
    glow: "#b2c4a4",
    badge: "#f8d7aa",
    border: "#f8d7aa",
  },
];

const devices = [
  {
    folder: "iphone-6.9",
    width: 1320,
    height: 2868,
    copyX: 110,
    copyY: 120,
    copyWidth: 1100,
    titleSize: 106,
    titleLine: 112,
    subtitleSize: 42,
    hardware: "iphone",
    deviceX: 230,
    deviceY: 790,
    deviceWidth: 860,
    deviceHeight: 1834,
    deviceRadius: 122,
    screenInset: 18,
    screenRadius: 104,
    glowSize: 720,
    glowX: 760,
    glowY: 70,
    dotSize: 170,
    dotX: 70,
    dotY: 610,
  },
  {
    folder: "ipad-13",
    width: 2064,
    height: 2752,
    copyX: 140,
    copyY: 130,
    copyWidth: 1784,
    titleSize: 112,
    titleLine: 120,
    subtitleSize: 42,
    hardware: "ipad",
    deviceX: 307,
    deviceY: 710,
    deviceWidth: 1450,
    deviceHeight: 1920,
    deviceRadius: 90,
    screenInset: 24,
    screenRadius: 66,
    glowSize: 900,
    glowX: 1450,
    glowY: -120,
    dotSize: 220,
    dotX: 70,
    dotY: 620,
  },
];

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function pageMarkup(device, story, imageData) {
  const isPhone = device.hardware === "iphone";
  const hardwareDetails = isPhone
    ? '<span class="dynamic-island"></span><span class="side-button volume-up"></span><span class="side-button volume-down"></span><span class="side-button action-button"></span>'
    : '<span class="tablet-camera"></span>';

  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; }
  html, body { margin: 0; width: ${device.width}px; height: ${device.height}px; overflow: hidden; }
  body { background: ${story.background}; font-family: "SF Pro Rounded", ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif; }
  .canvas { position: relative; width: 100%; height: 100%; overflow: hidden; background: ${story.background}; }
  .glow, .dot { position: absolute; border-radius: 50%; z-index: 0; }
  .glow { width: ${device.glowSize}px; height: ${device.glowSize}px; left: ${device.glowX}px; top: ${device.glowY}px; background: ${story.glow}; opacity: .72; }
  .dot { width: ${device.dotSize}px; height: ${device.dotSize}px; left: ${device.dotX}px; top: ${device.dotY}px; background: ${story.badge}; opacity: .92; }
  .copy { position: absolute; z-index: 3; left: ${device.copyX}px; top: ${device.copyY}px; width: ${device.copyWidth}px; }
  .label { display: inline-flex; align-items: center; min-height: ${device.folder === "iphone-6.9" ? 72 : 76}px; padding: 16px 30px; border-radius: 999px; background: ${story.badge}; color: #3d2a1f; font-size: ${device.folder === "iphone-6.9" ? 26 : 28}px; line-height: 1; font-weight: 600; letter-spacing: 3.5px; }
  h1 { margin: 28px 0 20px; max-width: ${device.copyWidth}px; color: ${story.ink}; font-size: ${device.titleSize}px; line-height: ${device.titleLine}px; letter-spacing: -2.2px; font-weight: 800; }
  p { margin: 0; max-width: ${device.folder === "iphone-6.9" ? 1040 : 1500}px; color: ${story.muted}; font-size: ${device.subtitleSize}px; line-height: 56px; font-weight: 400; }
  .device { position: absolute; z-index: 2; left: ${device.deviceX}px; top: ${device.deviceY}px; width: ${device.deviceWidth}px; height: ${device.deviceHeight}px; padding: ${device.screenInset}px; border: 4px solid rgba(255, 255, 255, .20); border-radius: ${device.deviceRadius}px; box-shadow: 0 36px 64px rgba(31, 18, 10, .28), inset 0 0 0 3px rgba(7, 5, 4, .34); background: linear-gradient(135deg, #563d2b 0%, #211813 44%, #3d2a1f 100%); }
  .device::after { content: ""; position: absolute; inset: 7px; pointer-events: none; border: 2px solid rgba(255, 255, 255, .18); border-radius: ${device.deviceRadius - 10}px; }
  .screen { position: relative; width: 100%; height: 100%; overflow: hidden; border-radius: ${device.screenRadius}px; background: #fff; }
  .screen img { display: block; width: 100%; height: 100%; object-fit: cover; }
  .dynamic-island { position: absolute; z-index: 4; top: ${device.screenInset + 34}px; left: 50%; width: 214px; height: 58px; transform: translateX(-50%); border-radius: 999px; background: #080808; box-shadow: inset 0 1px 1px rgba(255, 255, 255, .16); }
  .side-button { position: absolute; z-index: 1; display: block; width: 9px; border-radius: 99px; background: #271b15; box-shadow: 1px 0 1px rgba(255, 255, 255, .24); }
  .volume-up { height: 118px; left: -11px; top: 360px; }
  .volume-down { height: 118px; left: -11px; top: 508px; }
  .action-button { height: 178px; right: -11px; top: 426px; }
  .tablet-camera { position: absolute; z-index: 4; top: 14px; left: 50%; width: 18px; height: 18px; transform: translateX(-50%); border: 4px solid #513b2c; border-radius: 50%; background: #111; box-shadow: 0 0 0 2px rgba(255, 255, 255, .16); }
</style>
</head>
<body>
  <main class="canvas">
    <div class="glow"></div>
    <div class="dot"></div>
    <section class="copy">
      <div class="label">${escapeHtml(story.label)}</div>
      <h1>${escapeHtml(story.title)}</h1>
      <p>${escapeHtml(story.subtitle)}</p>
    </section>
    <div class="device ${device.hardware}">
      <div class="screen"><img src="data:image/png;base64,${imageData}" alt=""></div>
      ${hardwareDetails}
    </div>
  </main>
</body>
</html>`;
}

async function main() {
  const systemChrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  const executablePath = process.env.PLAYWRIGHT_CHROMIUM_PATH
    || (fs.existsSync(systemChrome) ? systemChrome : undefined);
  const browser = await chromium.launch({ headless: true, executablePath });

  try {
    for (const device of devices) {
      const outputDir = path.join(outputRoot, device.folder);
      fs.mkdirSync(outputDir, { recursive: true });

      for (const story of stories) {
        const rawPath = path.join(rawRoot, device.folder, story.file);
        if (!fs.existsSync(rawPath)) {
          throw new Error(`Missing raw capture: ${rawPath}`);
        }

        const imageData = fs.readFileSync(rawPath).toString("base64");
        const page = await browser.newPage({
          viewport: { width: device.width, height: device.height },
          deviceScaleFactor: 1,
        });

        await page.setContent(pageMarkup(device, story, imageData), { waitUntil: "load" });
        await page.evaluate(() => document.fonts.ready);
        await page.screenshot({
          path: path.join(outputDir, story.file),
          type: "png",
          clip: { x: 0, y: 0, width: device.width, height: device.height },
        });
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }

  console.log(`Marketing screenshots exported to ${outputRoot}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
