import Image from "next/image";
import Link from "next/link";
import {
  ArrowDownToLine,
  Check,
  Clipboard,
  FileText,
  HardDriveDownload,
  Keyboard,
  Lock,
  Mic,
  Monitor,
  Radio,
  ShieldCheck,
} from "lucide-react";

const downloadUrl = "/download";
const brandLabel =
  "font-[family-name:var(--font-overpass)] font-semibold tracking-[0.01em]";
const monoLabel =
  "font-[family-name:var(--font-overpass-mono)] font-medium tracking-[0.005em]";

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
    icon: FileText,
    title: "Review the result",
    text: "The transcript appears in a floating review panel before you copy, drag, or reshape it.",
  },
  {
    icon: Clipboard,
    title: "Use it anywhere",
    text: "Copy to the clipboard, drag into another app, or run an Apple Intelligence action when available.",
  },
];

const trustPoints = [
  {
    icon: Monitor,
    title: "Mac utility, not a web account",
    text: "Runs from the menu bar with macOS permissions you can see and change.",
  },
  {
    icon: ShieldCheck,
    title: "Sensitive permissions explained",
    text: "Microphone, model downloads, and any hotkey privacy permission are explained before they matter.",
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
  "Recent transcripts stay memory-only",
  "No synthetic paste keystrokes",
];

const ctaFacts = [
  "macOS 14 or newer",
  "Default hotkey: Right Command",
  "Review-first output",
];

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

function ScreenshotFrame({
  src,
  alt,
  width,
  height,
  priority = false,
  className = "",
}: {
  src: string;
  alt: string;
  width: number;
  height: number;
  priority?: boolean;
  className?: string;
}) {
  return (
    <div className={`relative ${className}`}>
      <Image
        src={src}
        alt={alt}
        width={width}
        height={height}
        priority={priority}
        className="h-auto w-full rounded-[18px]"
      />
    </div>
  );
}

function ModelPanel() {
  return (
    <div className="grid gap-6 min-[960px]:grid-cols-2">
      <section className="rounded-[18px] bg-[#e7efea] p-5 sm:p-6">
        <div className="flex items-center justify-between gap-4">
          <HardDriveDownload aria-hidden className="size-6 text-[#101818]" />
          <span
            className={`rounded-full bg-[#101818] px-3 py-1 text-xs text-[#e8ece8] ${brandLabel}`}
          >
            one-time setup
          </span>
        </div>
        <h3 className="mt-7 max-w-md text-2xl font-semibold tracking-[-0.02em]">
          Models are downloaded deliberately.
        </h3>
        <p className="mt-4 max-w-lg text-sm leading-6 text-[#385040]">
          Voiced asks before loading the local transcription model. It shows
          progress, verifies downloaded files, and exposes model storage
          controls in settings.
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
        <h3 className="mt-7 max-w-md text-2xl font-semibold tracking-[-0.02em]">
          Capture and review have visible limits.
        </h3>
        <p className="mt-4 max-w-lg text-sm leading-6 text-[#e8ece8]/74">
          After setup, speech is recorded locally, transcribed locally, then
          shown for review. Temporary audio is cleaned up, and recent
          transcripts are kept in memory only.
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

function IntelligenceSection() {
  return (
    <section className="bg-[#e7efea] px-5 py-16 sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-7xl gap-10 xl:grid-cols-[0.9fr_1.1fr] xl:items-center">
        <div>
          <h2 className="max-w-2xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Clean up the transcript before it leaves Voiced.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
            On compatible Macs, Voiced can use Apple Intelligence through
            Foundation Models to tidy spoken text, summarize a capture, or turn
            tasks into a checklist. If Apple Intelligence is unavailable,
            Voiced keeps the raw transcript ready to use.
          </p>
        </div>

        <ScreenshotFrame
          src="/screenshots/review-todo-reminders.png"
          alt="Voiced review window showing a to-do list created from speech, plus clean, summarize, to-do, reminders, copy, and drag controls."
          width={1340}
          height={910}
          className="mx-auto w-full max-w-[760px]"
        />
      </div>
    </section>
  );
}

function Hero() {
  return (
    <section className="relative isolate overflow-hidden bg-[#000808] text-[#e8ece8]">
      <div className="absolute inset-x-0 top-0 h-px bg-[#e8ece8]/20" />
      <div className="mx-auto flex min-h-[86vh] w-full max-w-[1760px] flex-col px-5 py-5 sm:px-8 lg:px-10">
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
            <Link className="transition hover:text-[#e8ece8]" href="/support">
              Support
            </Link>
          </nav>
        </header>

        <div className="hero-grid grid flex-1 items-center gap-12 py-10 lg:gap-14 lg:py-12">
          <div className="hero-copy max-w-6xl">
            <div
              className={`mb-8 inline-flex items-center gap-2 rounded-full border border-[#e8ece8]/18 bg-[#101818] px-3 py-1.5 text-sm text-[#80b890] ${brandLabel}`}
            >
              <Radio aria-hidden className="size-4" />
              Review-first dictation for macOS
            </div>
            <h1 className="hero-title max-w-6xl text-balance font-semibold leading-[0.96] tracking-[-0.025em]">
              Turn speech into text you can trust.
            </h1>
            <p className="mt-7 max-w-2xl text-pretty text-lg leading-8 text-[#e8ece8]/76 sm:text-xl">
              Voiced records while you hold a key, transcribes locally with
              WhisperKit, then opens a review window where you can check,
              clean, copy, or drag the text into your work.
            </p>
            <div className="mt-10 flex flex-col gap-3 sm:flex-row">
              <a
                href={downloadUrl}
                className="inline-flex h-12 items-center justify-center gap-2 whitespace-nowrap rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground transition hover:bg-[#80b890] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
              >
                <ArrowDownToLine aria-hidden className="size-4" />
                Download for macOS
              </a>
              <Link
                href="/privacy"
                className="inline-flex h-12 items-center justify-center gap-2 whitespace-nowrap rounded-full border border-[#e8ece8]/18 bg-[#101818] px-5 text-sm font-semibold text-[#e8ece8] transition hover:bg-[#181c1c] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
              >
                <ShieldCheck aria-hidden className="size-4" />
                Read privacy notes
              </Link>
            </div>
            <div className="mt-10 flex flex-wrap gap-2 text-sm text-[#e8ece8]/72">
              <span
                className={`inline-flex items-center gap-2 rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}
              >
                <StatusDot />
                Local transcription
              </span>
              <span className={`rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}>
                Review window
              </span>
              <span className={`rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}>
                Apple Intelligence actions
              </span>
            </div>
          </div>

          <ScreenshotFrame
            src="/screenshots/review-panel.png"
            alt="Voiced review window with transcript text, clean, summarize, to-do, copy, and drag controls."
            width={1340}
            height={838}
            priority
            className="hero-shot mx-auto w-full max-w-[960px]"
          />
        </div>
      </div>
    </section>
  );
}

function WorkflowSection() {
  return (
    <section id="workflow" className="bg-background px-5 py-18 sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-7xl gap-10 xl:grid-cols-[0.92fr_1.08fr] xl:items-center">
        <div>
          <h2 className="max-w-2xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Dictation that stays out of the way.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
            The whole loop is designed for the moment between thinking and
            typing: hold a key, speak, release, then review the text before it
            enters another app.
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
        <ScreenshotFrame
          src="/screenshots/setup-guide.png"
          alt="Voiced setup guide showing local speech model choices and microphone readiness."
          width={1584}
          height={1288}
          className="mx-auto w-full max-w-[740px]"
        />
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
        <div className="grid gap-8 xl:grid-cols-[minmax(0,1fr)_minmax(300px,0.56fr)] xl:items-center">
          <ScreenshotFrame
            src="/screenshots/menu-model.png"
            alt="Voiced menu bar status menu with selected local model, download size, approval state, recent transcripts, and settings."
            width={1222}
            height={588}
            className="mx-auto w-full max-w-[520px] xl:order-2 xl:justify-self-end"
          />
          <ModelPanel />
        </div>
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
      <div className="mx-auto grid max-w-7xl gap-10 xl:grid-cols-[0.8fr_1.2fr]">
        <div>
          <h2 className="max-w-xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            A small tool with explicit boundaries.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
            Voiced is built around a simple bargain: record only while
            push-to-talk is active, transcribe locally after model setup, and
            keep the output path visible until you choose what happens next.
          </p>
          <div className="mt-8 max-w-lg overflow-hidden rounded-[18px] border border-border bg-[#000808]">
            <Image
              src="/screenshots/settings-general.png"
              alt="Voiced Settings window with push-to-talk, launch at login, activation sound, and deactivation sound controls."
              width={1344}
              height={1468}
              className="h-auto w-full -translate-y-[1%] scale-[1.02]"
            />
          </div>
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
            Download Voiced and keep your words under review.
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
          className="inline-flex h-12 items-center justify-center gap-2 whitespace-nowrap rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground transition hover:bg-[#80b890] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
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
      <IntelligenceSection />
      <TrustSection />
      <DownloadCta />
      <Footer />
    </main>
  );
}
