import Image from "next/image";
import Link from "next/link";
import {
  ArrowDownToLine,
  Check,
  Clipboard,
  Command,
  HardDriveDownload,
  Keyboard,
  Lock,
  Mic,
  Monitor,
  MousePointer2,
  Radio,
  ShieldCheck,
} from "lucide-react";

const waveformBars = [34, 64, 88, 112, 76, 104, 70, 92, 42, 68, 96, 52];
const downloadUrl = "/download";
const brandLabel =
  "font-[family-name:var(--font-overpass)] font-semibold tracking-[0.01em]";
const monoLabel =
  "font-[family-name:var(--font-overpass-mono)] font-medium tracking-[0.005em]";

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

const workflow = [
  {
    icon: Keyboard,
    title: "Hold the hotkey",
    text: "Press and hold Right Command, or choose another push-to-talk key in settings.",
  },
  {
    icon: Mic,
    title: "Speak in place",
    text: "A small indicator follows the recording state, with optional sounds for start and stop.",
  },
  {
    icon: Clipboard,
    title: "Paste or copy",
    text: "Voiced can paste into the focused app or leave the transcript on your clipboard.",
  },
];

const trustPoints = [
  {
    icon: Monitor,
    title: "Mac utility, not a web account",
    text: "Runs from the menu bar with macOS permissions you can see and change.",
  },
  {
    icon: GitHubIcon,
    title: "Open source",
    text: "The code, privacy model, release scripts, and local build notes are public.",
  },
  {
    icon: Lock,
    title: "Transcript text stays out of logs",
    text: "Logs use counts and state changes, not audio content, transcript text, file names, or window titles.",
  },
];

const modelFacts = [
  "Explicit model download approval",
  "SHA-256 integrity verification",
  "Local WhisperKit transcription",
  "Delete or reveal downloaded models",
];

const privacyFacts = [
  "No cloud transcription path",
  "Temporary audio deleted after transcription",
  "Last transcript recovery is memory-only",
  "Copy-only mode avoids Accessibility paste",
];

const ctaFacts = ["macOS 14 or newer", "Default hotkey: Right Command", "MIT licensed"];

function StatusDot({ className = "" }: { className?: string }) {
  return (
    <span
      aria-hidden
      className={`inline-block size-2 rounded-full bg-[#88d0a0] ${className}`}
    />
  );
}

function FactList({ items }: { items: string[] }) {
  return (
    <ul className="space-y-3">
      {items.map((item) => (
        <li key={item} className="flex gap-3 text-sm leading-6 text-[#385040]">
          <Check aria-hidden className="mt-0.5 size-4 shrink-0 text-[#101818]" />
          <span className={item.includes("SHA-256") ? monoLabel : undefined}>
            {item}
          </span>
        </li>
      ))}
    </ul>
  );
}

function RecorderPreview() {
  return (
    <div className="relative mx-auto w-full max-w-[500px] lg:mx-0 lg:justify-self-end">
      <div className="absolute -inset-5 rounded-[18px] bg-[#88d0a0]/10 blur-3xl" />
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
                <p className={`text-sm text-[#e8ece8] ${brandLabel}`}>Voiced</p>
                <p className="text-sm text-[#80b890]">Menu bar capture</p>
              </div>
            </div>
            <span
              className={`inline-flex items-center gap-2 rounded-full bg-[#88d0a0] px-3 py-1 text-xs text-[#000808] ${brandLabel}`}
            >
              <StatusDot className="bg-[#000808]" />
              Recording
            </span>
          </div>

          <div className="mt-10 flex h-32 items-center justify-center gap-2 rounded-full bg-[#181c1c] px-7 sm:gap-3">
            {waveformBars.map((height, index) => (
              <span
                key={`${height}-${index}`}
                className="w-3 rounded-full bg-[#88d0a0] sm:w-4"
                style={{ height }}
              />
            ))}
          </div>

          <div className="mt-7 grid gap-3 sm:grid-cols-[0.9fr_1.1fr]">
            <div className="rounded-[12px] border border-[#e8ece8]/14 bg-[#101818] p-4">
              <p className="text-xs text-[#80b890]">Output mode</p>
              <p className="mt-2 text-sm font-medium text-[#e8ece8]">
                Paste, then restore clipboard
              </p>
            </div>
            <div className="rounded-[12px] border border-[#e8ece8]/14 bg-[#101818] p-4">
              <p className="text-xs text-[#80b890]">Model</p>
              <p className="mt-2 text-sm font-medium text-[#e8ece8]">
                WhisperKit tiny, verified
              </p>
            </div>
          </div>

          <div className="mt-3 rounded-[12px] border border-[#e8ece8]/14 bg-[#101818] p-4">
            <p className="text-sm leading-6 text-[#e8ece8]/84">
              &quot;Draft the release note. Mention macOS only, local
              transcription, and that copy-only mode is available.&quot;
            </p>
            <div className="mt-4 h-px bg-[#e8ece8]/12" />
            <p className="mt-4 text-sm leading-6 text-[#80b890]">
              Transcribed locally, ready for the focused app.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

function WorkflowDiagram() {
  return (
    <div className="rounded-[18px] bg-[#000808] p-4 text-[#e8ece8]">
      <div className="rounded-[14px] border border-[#e8ece8]/14 bg-[#101818] p-4">
        <div className="flex items-center justify-between gap-4">
          <span
            className={`inline-flex items-center gap-2 rounded-full bg-[#181c1c] px-3 py-1.5 text-sm text-[#e8ece8] ${monoLabel}`}
          >
            <Command aria-hidden className="size-4 text-[#88d0a0]" />
            Right Command
          </span>
          <span className="text-sm text-[#80b890]">held</span>
        </div>
        <div className="mt-5 h-2 rounded-full bg-[#181c1c]">
          <div className="h-full w-2/3 rounded-full bg-[#88d0a0]" />
        </div>
      </div>

      <div className="my-3 flex justify-center">
        <div className="h-8 w-px bg-[#e8ece8]/18" />
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <div className="rounded-[14px] border border-[#e8ece8]/14 bg-[#101818] p-4">
          <Radio aria-hidden className="size-5 text-[#88d0a0]" />
          <p className="mt-4 text-sm font-medium">Floating indicator</p>
          <p className="mt-2 text-sm leading-6 text-[#e8ece8]/70">
            Recording, transcribing, model loading, and error states stay
            visible without opening a window.
          </p>
        </div>
        <div className="rounded-[14px] border border-[#e8ece8]/14 bg-[#101818] p-4">
          <MousePointer2 aria-hidden className="size-5 text-[#88d0a0]" />
          <p className="mt-4 text-sm font-medium">Focused-app output</p>
          <p className="mt-2 text-sm leading-6 text-[#e8ece8]/70">
            Paste mode sends Cmd+V with Accessibility permission. Copy-only
            mode skips synthetic keystrokes.
          </p>
        </div>
      </div>
    </div>
  );
}

function ModelPanel() {
  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_1fr]">
      <section className="rounded-[18px] bg-[#e7efea] p-5 sm:p-6">
        <div className="flex items-center justify-between gap-4">
          <HardDriveDownload aria-hidden className="size-6 text-[#101818]" />
          <span
            className={`rounded-full bg-[#101818] px-3 py-1 text-xs text-[#e8ece8] ${brandLabel}`}
          >
            one-time setup
          </span>
        </div>
        <h3 className="mt-8 max-w-md text-2xl font-semibold tracking-[-0.02em]">
          Models are downloaded deliberately.
        </h3>
        <p className="mt-4 max-w-lg text-sm leading-6 text-[#385040]">
          Voiced asks before loading the local transcription model. It shows
          progress, verifies downloaded files against pinned hashes, and exposes
          model storage controls in settings.
        </p>
        <div className="mt-7">
          <FactList items={modelFacts} />
        </div>
      </section>

      <section className="rounded-[18px] bg-[#101818] p-5 text-[#e8ece8] sm:p-6">
        <div className="flex items-center justify-between gap-4">
          <ShieldCheck aria-hidden className="size-6 text-[#88d0a0]" />
          <span
            className={`rounded-full bg-[#88d0a0] px-3 py-1 text-xs text-[#000808] ${brandLabel}`}
          >
            local-first
          </span>
        </div>
        <h3 className="mt-8 max-w-md text-2xl font-semibold tracking-[-0.02em]">
          Capture has visible limits.
        </h3>
        <p className="mt-4 max-w-lg text-sm leading-6 text-[#e8ece8]/74">
          After setup, speech is recorded locally, transcribed locally, then
          emitted as text. Temporary audio is cleaned up, and transcript content
          is not stored as history.
        </p>
        <ul className="mt-7 space-y-3">
          {privacyFacts.map((item) => (
            <li
              key={item}
              className="flex gap-3 text-sm leading-6 text-[#e8ece8]/76"
            >
              <Check aria-hidden className="mt-0.5 size-4 shrink-0 text-[#88d0a0]" />
              <span>{item}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function Hero() {
  return (
    <section className="relative isolate overflow-hidden bg-[#000808] text-[#e8ece8]">
      <div className="absolute inset-x-0 top-0 h-px bg-[#e8ece8]/20" />
      <div className="mx-auto flex min-h-[86vh] w-full max-w-7xl flex-col px-5 py-5 sm:px-8 lg:px-10">
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
            <span className={`text-[15px] ${brandLabel}`}>Voiced</span>
          </Link>
          <nav className="hidden items-center gap-6 text-sm text-[#e8ece8]/72 sm:flex">
            <a className="transition hover:text-[#e8ece8]" href="#workflow">
              Workflow
            </a>
            <a className="transition hover:text-[#e8ece8]" href="#models">
              Models
            </a>
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

        <div className="grid flex-1 items-center gap-12 py-10 lg:grid-cols-[minmax(0,1.02fr)_minmax(360px,0.78fr)] lg:py-12">
          <div className="max-w-4xl">
            <div
              className={`mb-8 inline-flex items-center gap-2 rounded-full border border-[#e8ece8]/18 bg-[#101818] px-3 py-1.5 text-sm text-[#80b890] ${brandLabel}`}
            >
              <Radio aria-hidden className="size-4" />
              Push-to-talk dictation for macOS
            </div>
            <h1 className="max-w-4xl text-balance text-5xl font-semibold leading-[0.96] tracking-[-0.025em] sm:text-6xl lg:text-[5.5rem]">
              Dictate anywhere your Mac can type.
            </h1>
            <p className="mt-7 max-w-2xl text-pretty text-lg leading-8 text-[#e8ece8]/76 sm:text-xl">
              Voiced records while you hold a key, transcribes locally with
              WhisperKit, then copies or pastes clean text back into your Mac.
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
            <div className="mt-10 flex flex-wrap gap-2 text-sm text-[#e8ece8]/72">
              <span
                className={`inline-flex items-center gap-2 rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}
              >
                <StatusDot />
                Local transcription
              </span>
              <span className={`rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}>
                Clipboard-preserving paste
              </span>
              <span className={`rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}>
                Open source
              </span>
            </div>
          </div>

          <RecorderPreview />
        </div>
      </div>
    </section>
  );
}

function WorkflowSection() {
  return (
    <section id="workflow" className="bg-background px-5 py-18 sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-7xl gap-10 lg:grid-cols-[0.92fr_1.08fr] lg:items-center">
        <div>
          <h2 className="max-w-2xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Dictation that stays out of the way.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
            The whole loop is designed for the moment between thinking and
            typing: hold a key, speak, release, then let Voiced put the text
            where you need it.
          </p>
          <div className="mt-9 grid gap-6">
            {workflow.map(({ icon: Icon, title, text }) => (
              <section key={title} className="grid grid-cols-[auto_1fr] gap-4">
                <div className="flex size-10 items-center justify-center rounded-[10px] bg-[#e7efea]">
                  <Icon aria-hidden className="size-5 text-[#101818]" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold tracking-[-0.01em]">
                    {title}
                  </h3>
                  <p className="mt-2 max-w-xl text-sm leading-6 text-muted-foreground">
                    {text}
                  </p>
                </div>
              </section>
            ))}
          </div>
        </div>
        <WorkflowDiagram />
      </div>
    </section>
  );
}

function ModelSection() {
  return (
    <section id="models" className="bg-[#f7faf8] px-5 py-16 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-7xl">
        <div className="mb-10 flex max-w-4xl flex-col gap-4">
          <h2 className="max-w-3xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Local transcription without pretending setup is invisible.
          </h2>
          <p className="max-w-2xl text-pretty text-base leading-7 text-muted-foreground">
            Voiced uses WhisperKit and Argmax OSS models on your Mac. The first
            approved download can contact Hugging Face, then the model is used
            from the local cache.
          </p>
        </div>
        <ModelPanel />
      </div>
    </section>
  );
}

function TrustSection() {
  return (
    <section
      id="privacy"
      className="border-y border-border bg-[#f7faf8] px-5 py-16 sm:px-8 lg:px-10"
    >
      <div className="mx-auto grid max-w-7xl gap-10 lg:grid-cols-[0.8fr_1.2fr]">
        <div>
          <h2 className="max-w-xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            A small tool with explicit boundaries.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
            Voiced is built around a simple bargain: record only while
            push-to-talk is active, transcribe locally after model setup, and
            keep the output path under your control.
          </p>
        </div>
        <div className="grid gap-6 md:grid-cols-3">
          {trustPoints.map(({ icon: Icon, title, text }) => (
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
  );
}

function DownloadCta() {
  return (
    <section className="bg-[#000808] px-5 py-16 text-[#e8ece8] sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-7xl gap-10 lg:grid-cols-[1fr_auto] lg:items-end">
        <div>
          <p className={`text-sm text-[#80b890] ${brandLabel}`}>
            Ready when your model is
          </p>
          <h2 className="mt-3 max-w-3xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Download Voiced and keep dictation close to the work.
          </h2>
          <div className="mt-7 flex flex-wrap gap-2">
            {ctaFacts.map((fact) => (
              <span
                key={fact}
                className={`rounded-full border border-[#e8ece8]/16 bg-[#101818] px-3 py-1 text-[11px] leading-5 text-[#e8ece8]/72 ${monoLabel}`}
              >
                {fact}
              </span>
            ))}
          </div>
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
  );
}

function Footer() {
  return (
    <footer className="border-t border-border bg-background px-5 py-6 sm:px-8 lg:px-10">
      <div className="mx-auto flex max-w-7xl flex-col items-center justify-center gap-4 text-sm text-muted-foreground sm:flex-row sm:justify-between">
        <a
          href="https://applification.net"
          aria-label="Tuned by Applification"
          className="inline-flex items-center gap-2 transition hover:text-foreground"
        >
          <span>Tuned by</span>
          <ApplificationMark className="h-4 w-9 text-[#385040]" />
          <span className="font-medium text-[#385040]">Applification</span>
        </a>
        <nav aria-label="Footer" className="flex gap-5">
          <Link className="transition hover:text-foreground" href="/privacy">
            Privacy
          </Link>
          <Link className="transition hover:text-foreground" href="/support">
            Support
          </Link>
        </nav>
      </div>
    </footer>
  );
}

export default function Home() {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <Hero />
      <WorkflowSection />
      <ModelSection />
      <TrustSection />
      <DownloadCta />
      <Footer />
    </main>
  );
}
