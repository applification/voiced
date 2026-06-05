import Image from "next/image";
import Link from "next/link";
import { ArrowDownToLine, Lock, Monitor, Sparkles } from "lucide-react";

const waveformBars = [34, 64, 88, 112, 76, 104, 70, 92, 42];
const downloadUrl = "/download";

function GitHubIcon({ className }: { className?: string }) {
  return (
    <svg
      aria-hidden
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
    >
      <path d="M12 2C6.48 2 2 6.58 2 12.23c0 4.52 2.87 8.35 6.84 9.71.5.1.68-.22.68-.49 0-.24-.01-1.04-.01-1.89-2.78.62-3.37-1.21-3.37-1.21-.45-1.18-1.11-1.49-1.11-1.49-.91-.64.07-.63.07-.63 1 .07 1.53 1.06 1.53 1.06.89 1.56 2.34 1.11 2.91.85.09-.66.35-1.11.63-1.37-2.22-.26-4.55-1.14-4.55-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.3.1-2.71 0 0 .84-.28 2.75 1.05A9.31 9.31 0 0 1 12 6.96c.85 0 1.7.12 2.5.34 1.91-1.33 2.75-1.05 2.75-1.05.55 1.41.2 2.45.1 2.71.64.72 1.03 1.63 1.03 2.75 0 3.93-2.34 4.8-4.57 5.05.36.32.68.94.68 1.9 0 1.37-.01 2.48-.01 2.81 0 .27.18.59.69.49A10.07 10.07 0 0 0 22 12.23C22 6.58 17.52 2 12 2Z" />
    </svg>
  );
}

function ApplificationMark({ className }: { className?: string }) {
  return (
    <svg
      aria-hidden
      className={className}
      viewBox="0 0 734 342"
      fill="currentColor"
    >
      <path d="M262 11.7c-9.1 3.2-15.8 9.2-20.8 18.7l-2.7 5.1v271l3.4 6.3c6 11 15.6 17.7 27.9 19.3 9.5 1.2 190 1.1 198.6-.1 12.9-1.9 22.8-9.2 28.5-21l2.6-5.5v-269l-2.9-5.9c-3.6-7.3-9.6-13.5-16.8-17.3l-5.3-2.8-104-.2c-92.6-.2-104.5-.1-108.5 1.4zM455 165v110H283V55h172v110zm-78 122.5c13.5 7 10.5 28.1-4.5 31.5-10.1 2.3-20.4-6.4-20.5-17 0-4.5 3.6-10.8 7.9-13.7 4.1-2.7 12.6-3.1 17.1-.8z" />
      <path d="M357.9 132.4c-23.1 8.9-31.9 36.1-18.2 56.4 15.8 23.3 51.6 20.6 64.1-4.8 2.4-5 2.7-6.6 2.7-16.5 0-10.1-.2-11.4-2.8-16.3-4-7.5-8.7-12.4-15.9-16.3-5.8-3.1-7.1-3.4-16.3-3.6-6.7-.2-11.2.2-13.6 1.1zM89.3 47.2c-19.7 20.3-34.6 47.5-42.2 77.6-14.7 57.3 2.5 124.4 43 167.6l6.2 6.7 8.4-8.3c4.7-4.6 10.3-10.5 12.5-13.1l4.1-4.8-5-5.2c-13.7-14.1-25.8-35.6-31.9-56.7-7.5-25.8-7.5-56.2.1-82.5 5.7-19.6 17.1-40 30.5-54.8l6.2-6.8-12.3-12.7c-6.8-7-12.6-12.8-12.9-13-.3-.1-3.3 2.6-6.7 6zM625.4 54.8l-12.1 11.7 7.9 9.5c24.3 28.9 35 61.7 33.5 102-.9 23-5 39.6-14.5 58.5-6.7 13.4-12.6 21.9-22.5 32.3l-5 5.4 12.4 12.4c6.8 6.8 12.8 12.4 13.4 12.4.6 0 3.3-2.4 6.1-5.3C672.2 265 688.2 228.8 692 186c3.7-40.8-10.4-89-35.8-122.5C650.5 56.1 639 43 638.1 43c-.3.1-6 5.4-12.7 11.8zM175.8 93.2c-17 19.4-26.7 39.1-29.8 60.7-1.8 12.2-.8 30.3 2.4 42.4 2.8 11 10.2 27.3 16.5 36.5 5.8 8.6 13.9 18.2 15.4 18.2 1.3 0 22.7-21 22.7-22.3 0-.4-2.2-3.5-4.9-6.8-6.6-8.1-11.4-17.5-14.7-28.4-3.4-11.5-3.8-28.9-1-39.9 3.9-14.7 10.5-27.3 19.3-36.7l4.5-4.8-11.8-12.6C187.9 92.6 182.3 87 182 87c-.4 0-3.1 2.8-6.2 6.2zM542 100.5 530.6 112l3 3.2c8 8.5 15.2 22.8 18.5 36.5 2.7 11.2 2.2 27.8-1.1 39.3-2.9 10.1-9.8 23.2-16.6 31.4l-5.6 6.8 12.2 12.2 12.1 12.1 6.5-7c21.8-23.6 32.8-55.4 29.5-85-2.7-23.5-12-44.9-28.8-65.8-2.9-3.7-5.7-6.7-6.1-6.7-.4 0-5.9 5.2-12.2 11.5z" />
    </svg>
  );
}

const principles = [
  {
    icon: Monitor,
    title: "macOS only",
    text: "Built for the Mac as a native utility, with the keyboard and menu bar close at hand.",
  },
  {
    icon: GitHubIcon,
    title: "Open source",
    text: "The code is public, inspectable, and ready for the people who want to understand their tools.",
  },
  {
    icon: Lock,
    title: "Privacy first",
    text: "No cloud transcription, no audio uploads, and no transcript history stored on disk.",
  },
];

export default function Home() {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <section className="relative isolate overflow-hidden bg-[#000808] text-[#e8ece8]">
        <div className="absolute inset-x-0 top-0 h-px bg-[#e8ece8]/20" />
        <div className="mx-auto flex min-h-[92vh] w-full max-w-7xl flex-col px-5 py-5 sm:px-8 lg:px-10">
          <header className="flex items-center justify-between gap-4">
            <Link href="/" className="flex items-center gap-3 text-sm font-medium">
              <Image
                src="/voiced-icon.png"
                alt="Voiced app icon"
                width={42}
                height={42}
                priority
                className="rounded-[10px]"
              />
              <span>Voiced</span>
            </Link>
            <nav className="hidden items-center gap-6 text-sm text-[#e8ece8]/72 sm:flex">
              <a className="transition hover:text-[#e8ece8]" href="#privacy">
                Privacy
              </a>
              <a
                className="transition hover:text-[#e8ece8]"
                href="https://github.com/applification/voiced"
              >
                Source
              </a>
            </nav>
          </header>

          <div className="grid flex-1 items-center gap-12 py-16 lg:grid-cols-[minmax(0,1.02fr)_minmax(360px,0.78fr)] lg:py-20">
            <div className="max-w-4xl">
              <div className="mb-8 inline-flex items-center gap-2 rounded-full border border-[#e8ece8]/18 bg-[#101818] px-3 py-1.5 text-sm text-[#80b890]">
                <Sparkles aria-hidden className="size-4" />
                Native dictation for macOS
              </div>
              <h1 className="max-w-4xl text-balance text-5xl font-semibold leading-[0.96] tracking-[-0.025em] sm:text-6xl lg:text-[5.5rem]">
                Speak once. Keep the transcript.
              </h1>
              <p className="mt-7 max-w-2xl text-pretty text-lg leading-8 text-[#e8ece8]/76 sm:text-xl">
                Voiced is a focused Mac app for capturing speech and turning it
                into clean text without turning your day into another dashboard.
              </p>
              <div className="mt-10 flex flex-col gap-3 sm:flex-row">
                <a
                  href={downloadUrl}
                  className="inline-flex h-12 items-center justify-center gap-2 rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground transition hover:bg-[#80b890] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
                >
                  <ArrowDownToLine aria-hidden className="size-4" />
                  Download for macOS
                </a>
                <a
                  href="https://github.com/applification/voiced"
                  className="inline-flex h-12 items-center justify-center gap-2 rounded-full border border-[#e8ece8]/18 bg-[#101818] px-5 text-sm font-semibold text-[#e8ece8] transition hover:bg-[#181c1c] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
                >
                  <GitHubIcon className="size-4" />
                  View source
                </a>
              </div>
            </div>

            <div className="relative mx-auto w-full max-w-[460px] lg:mx-0 lg:justify-self-end">
              <div className="absolute -inset-5 rounded-[28px] bg-[#88d0a0]/10 blur-3xl" />
              <div className="relative rounded-[18px] border border-[#e8ece8]/18 bg-[#101818] p-4 shadow-[0_14px_40px_rgba(0,8,8,0.22)]">
                <div className="rounded-[14px] bg-[#000808] p-5">
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <Image
                        src="/voiced-icon.png"
                        alt=""
                        width={54}
                        height={54}
                        className="rounded-[12px]"
                      />
                      <div>
                        <p className="text-sm font-medium text-[#e8ece8]">
                          Recording
                        </p>
                        <p className="text-sm text-[#80b890]">
                          Menu bar capture
                        </p>
                      </div>
                    </div>
                    <span className="rounded-full bg-[#88d0a0] px-3 py-1 text-xs font-semibold text-[#000808]">
                      Live
                    </span>
                  </div>

                  <div className="mt-12 flex h-32 items-center justify-center gap-3 rounded-full bg-[#181c1c] px-8">
                    {waveformBars.map((height, index) => (
                      <span
                        key={`${height}-${index}`}
                        className="w-4 rounded-full bg-[#88d0a0]"
                        style={{ height }}
                      />
                    ))}
                  </div>

                  <div className="mt-8 rounded-[12px] border border-[#e8ece8]/14 bg-[#101818] p-4">
                    <p className="text-sm leading-6 text-[#e8ece8]/82">
                      “Draft the release note, mention macOS only, open source,
                      and privacy first.”
                    </p>
                    <div className="mt-4 h-px bg-[#e8ece8]/12" />
                    <p className="mt-4 text-sm leading-6 text-[#80b890]">
                      Copied, or pasted automatically.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        id="privacy"
        className="border-y border-border bg-[#f7faf8] px-5 py-16 sm:px-8 lg:px-10"
      >
        <div className="mx-auto grid max-w-7xl gap-10 lg:grid-cols-[0.8fr_1.2fr]">
          <div>
            <h2 className="max-w-xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
              A small tool with clear boundaries.
            </h2>
            <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
              Voiced keeps capture local after the approved model download.
              Transcript text is not logged, audio is not uploaded, and the
              last transcript is kept in memory only for recovery.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-3">
            {principles.map(({ icon: Icon, title, text }) => (
              <section key={title} className="border-t border-border pt-5">
                <Icon aria-hidden className="mb-5 size-5 text-[#385040]" />
                <h3 className="text-lg font-semibold tracking-[-0.01em]">
                  {title}
                </h3>
                <p className="mt-3 text-sm leading-6 text-muted-foreground">
                  {text}
                </p>
              </section>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-background px-5 py-14 sm:px-8 lg:px-10">
        <div className="mx-auto flex max-w-7xl flex-col items-start justify-between gap-6 sm:flex-row sm:items-center">
          <div>
            <p className="text-sm font-medium text-muted-foreground">
              Available for macOS
            </p>
            <h2 className="mt-2 text-2xl font-semibold tracking-[-0.02em]">
              Download Voiced and keep capture close.
            </h2>
          </div>
          <a
            href={downloadUrl}
            className="inline-flex h-12 items-center justify-center gap-2 rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground transition hover:bg-[#80b890] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
          >
            <ArrowDownToLine aria-hidden className="size-4" />
            Download for macOS
          </a>
        </div>
      </section>

      <footer className="border-t border-border bg-background px-5 py-6 sm:px-8 lg:px-10">
        <div className="mx-auto flex max-w-7xl justify-center text-sm text-muted-foreground">
          <a
            href="https://applification.net"
            aria-label="Tuned by Applification"
            className="inline-flex items-center gap-2 transition hover:text-foreground"
          >
            <span>Tuned by</span>
            <ApplificationMark className="h-4 w-9 text-[#385040]" />
            <span className="font-medium text-[#385040]">Applification</span>
          </a>
        </div>
      </footer>
    </main>
  );
}
