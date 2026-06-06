#!/usr/bin/env node

const repo = process.argv[2] ?? "argmaxinc/whisperkit-coreml";
const model = process.argv[3];

if (!model) {
  console.error("usage: generate_model_integrity_manifest.mjs [repo] <model-variant>");
  console.error("example: generate_model_integrity_manifest.mjs argmaxinc/whisperkit-coreml tiny");
  process.exit(2);
}

const folder = `openai_whisper-${model}`;
const url = `https://huggingface.co/api/models/${repo}/tree/main/${folder}?recursive=true`;
const response = await fetch(url);

if (!response.ok) {
  throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
}

const files = await response.json();
const manifestFiles = files
  .filter((file) => {
    if (file.type !== "file" || !file.lfs) return false;
    return (
      file.path.endsWith("/weights/weight.bin") ||
      file.path.endsWith("/model.mlmodel") ||
      file.path.endsWith("/coremldata.bin")
    );
  })
  .sort((a, b) => a.path.localeCompare(b.path));

for (const file of manifestFiles) {
  const relativePath = file.path.replace(`${folder}/`, "");
  console.log(
    `ModelIntegrityFile(relativePath: "${relativePath}", byteCount: ${file.lfs.size}, sha256: "${file.lfs.oid}"),`
  );
}
