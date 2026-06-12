#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const sharp = require(path.join(
  __dirname,
  "..",
  "website",
  "node_modules",
  "sharp"
));

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "dist", "app-store", "screenshots");

const width = 2880;
const height = 1800;

const shots = [
  {
    file: path.join(root, "website/public/screenshots/setup-guide.png"),
    output: "01-onboarding-review-setup.png",
    title: "Set up local dictation",
    subtitle:
      "Choose a speech model, grant microphone access, and start with a review-first workflow.",
    maxImageWidth: 1680,
    maxImageHeight: 1040,
  },
  {
    file: path.join(root, "website/public/screenshots/review-panel.png"),
    output: "02-review-window.png",
    title: "Review every transcript",
    subtitle:
      "Check the text, copy it, or drag it into another Mac app.",
    maxImageWidth: 1840,
    maxImageHeight: 1040,
  },
  {
    file: path.join(root, "website/public/screenshots/review-todo-reminders.png"),
    output: "03-apple-intelligence-actions.png",
    title: "Turn speech into action",
    subtitle:
      "Use Apple Intelligence actions when available to clean, summarize, or make tasks.",
    maxImageWidth: 1840,
    maxImageHeight: 1040,
  },
  {
    file: path.join(root, "website/public/screenshots/menu-model.png"),
    output: "04-model-status-menu.png",
    title: "Know what is running",
    subtitle:
      "See the selected local model, download approval, and recent transcripts from the menu bar.",
    maxImageWidth: 1840,
    maxImageHeight: 900,
  },
  {
    file: path.join(root, "website/public/screenshots/settings-general.png"),
    output: "05-settings-general.png",
    title: "Tune capture to your voice",
    subtitle:
      "Pick your push-to-talk key, startup behavior, and completion sounds.",
    maxImageWidth: 1220,
    maxImageHeight: 1040,
  },
];

function escapeXml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function backgroundSvg(title, subtitle, index) {
  const safeTitle = escapeXml(title);
  const safeSubtitle = escapeXml(subtitle);
  const number = String(index + 1).padStart(2, "0");

  return Buffer.from(`
<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="mint" cx="28%" cy="12%" r="70%">
      <stop offset="0%" stop-color="#274836"/>
      <stop offset="42%" stop-color="#071111"/>
      <stop offset="100%" stop-color="#000808"/>
    </radialGradient>
    <linearGradient id="panel" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#101818"/>
      <stop offset="100%" stop-color="#050C0C"/>
    </linearGradient>
    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="44" stdDeviation="38" flood-color="#000808" flood-opacity="0.42"/>
    </filter>
  </defs>
  <rect width="${width}" height="${height}" fill="url(#mint)"/>
  <path d="M0 1430 C480 1320 850 1510 1260 1400 C1740 1270 2040 1190 2880 1330 L2880 1800 L0 1800 Z" fill="#E7EFEA" opacity="0.055"/>
  <g opacity="0.22">
    <rect x="198" y="190" width="8" height="72" rx="4" fill="#88D0A0"/>
    <rect x="216" y="160" width="8" height="132" rx="4" fill="#88D0A0"/>
    <rect x="234" y="208" width="8" height="36" rx="4" fill="#88D0A0"/>
    <rect x="252" y="176" width="8" height="100" rx="4" fill="#88D0A0"/>
    <rect x="270" y="148" width="8" height="156" rx="4" fill="#88D0A0"/>
    <rect x="288" y="196" width="8" height="60" rx="4" fill="#88D0A0"/>
    <rect x="306" y="168" width="8" height="116" rx="4" fill="#88D0A0"/>
  </g>
  <text x="220" y="365" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', Helvetica, Arial, sans-serif" font-size="96" font-weight="720" letter-spacing="0" fill="#F7FAF8">${safeTitle}</text>
  <text x="224" y="452" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', Helvetica, Arial, sans-serif" font-size="36" font-weight="430" fill="#B9CABE">${safeSubtitle}</text>
  <text x="220" y="1575" font-family="ui-monospace, SFMono-Regular, Menlo, Monaco, monospace" font-size="28" font-weight="560" fill="#88D0A0">Voiced Dictation</text>
  <text x="2558" y="1575" text-anchor="end" font-family="ui-monospace, SFMono-Regular, Menlo, Monaco, monospace" font-size="28" font-weight="560" fill="#80B890">${number}</text>
  <rect x="184" y="586" width="2512" height="850" rx="34" fill="url(#panel)" opacity="0.34"/>
</svg>`);
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true });

  for (const [index, shot] of shots.entries()) {
    const image = sharp(shot.file);
    const metadata = await image.metadata();
    const scale = Math.min(
      shot.maxImageWidth / metadata.width,
      shot.maxImageHeight / metadata.height
    );
    const imageWidth = Math.round(metadata.width * scale);
    const imageHeight = Math.round(metadata.height * scale);
    const left = Math.round((width - imageWidth) / 2);
    const top = Math.round(650 + (690 - imageHeight) / 2);

    const resized = await image
      .resize(imageWidth, imageHeight, {
        kernel: sharp.kernel.lanczos3,
      })
      .png()
      .toBuffer();

    const shadow = await sharp({
      create: {
        width: imageWidth + 120,
        height: imageHeight + 150,
        channels: 4,
        background: "#00000000",
      },
    })
      .composite([
        {
          input: Buffer.from(
            `<svg width="${imageWidth + 120}" height="${imageHeight + 150}" xmlns="http://www.w3.org/2000/svg"><filter id="s"><feGaussianBlur stdDeviation="30"/></filter><rect x="60" y="28" width="${imageWidth}" height="${imageHeight}" rx="34" fill="#000808" opacity="0.46" filter="url(#s)"/></svg>`
          ),
          left: 0,
          top: 0,
        },
      ])
      .png()
      .toBuffer();

    await sharp(backgroundSvg(shot.title, shot.subtitle, index))
      .composite([
        { input: shadow, left: left - 60, top: top - 28 },
        { input: resized, left, top },
      ])
      .png({ compressionLevel: 9 })
      .toFile(path.join(outDir, shot.output));
  }

  console.log(`Wrote ${shots.length} screenshots to ${outDir}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
