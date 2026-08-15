import { NextResponse } from "next/server";

interface GitHubAsset {
  name: string;
  browser_download_url: string;
}

const GITHUB_RELEASES_URL =
  "https://github.com/applification/voiced/releases/latest";
const GITHUB_API_URL =
  "https://api.github.com/repos/applification/voiced/releases/latest";

async function fetchLatestPackage(): Promise<GitHubAsset | null> {
  try {
    const res = await fetch(GITHUB_API_URL, {
      headers: { Accept: "application/vnd.github+json" },
      next: { revalidate: 300 },
    });

    if (!res.ok) return null;

    const data = (await res.json()) as { assets?: GitHubAsset[] };
    return (
      data.assets?.find((asset) => asset.name.endsWith(".dmg")) ??
      data.assets?.find((asset) => asset.name.endsWith(".zip")) ??
      null
    );
  } catch {
    return null;
  }
}

export async function GET(req: Request) {
  const asset = await fetchLatestPackage();
  const resolved = {
    os: "macos",
    resolution: asset ? "auto" : "fallback",
    url: asset?.browser_download_url ?? GITHUB_RELEASES_URL,
    assetName: asset?.name,
  };

  if (req.headers.get("accept")?.includes("application/json")) {
    return NextResponse.json(resolved);
  }

  return NextResponse.redirect(resolved.url, 302);
}
