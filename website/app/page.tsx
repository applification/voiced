import Image from "next/image";
import Link from "next/link";
import {
  ArrowDownToLine,
  Check,
  HardDriveDownload,
  Keyboard,
  ListTodo,
  Lock,
  Mic,
  Monitor,
  Radio,
  ScanText,
  Search,
  ShieldCheck,
  Sparkles,
  Undo2,
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

const shortcuts = [
  {
    keys: ["Right ⌘"],
    title: "Dictate and insert",
    text: "Release to place the transcript in the editor you were using.",
  },
  {
    keys: ["⇧", "Right ⌘"],
    title: "Save voice to Inbox",
    text: "Keep the capture for later without opening the shelf.",
  },
  {
    keys: ["⇧", "⇧"],
    title: "Save a selection",
    text: "Capture selected text from the app already in front of you.",
  },
  {
    keys: ["⌥", "Space"],
    title: "Toggle the shelf",
    text: "Search, type, edit, refine, copy, drag, finish, or remove.",
  },
];

const shelfActions = [
  "Search capture text or its source app",
  "Edit voice, selection, and typed captures",
  "Move items between Inbox and Done",
  "Copy or drag text back into your work",
  "Remove a capture with immediate Undo",
];

const modelFacts = [
  "Download starts only when you ask",
  "Pinned size and SHA-256 verification",
  "WhisperKit transcription on your Mac",
  "Reveal or remove downloaded models",
];

const privacyFacts = [
  "No account, telemetry, or analytics",
  "No cloud transcription or capture upload",
  "Temporary audio deleted after use",
  "Captures stored as readable local JSON",
];

function StatusDot() {
  return (
    <span
      aria-hidden
      className="inline-block size-2 rounded-full bg-[#88d0a0]"
    />
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
        className="h-auto w-full"
      />
    </div>
  );
}

function FactList({ items, dark = false }: { items: string[]; dark?: boolean }) {
  return (
    <ul className="space-y-3">
      {items.map((item) => (
        <li
          key={item}
          className={`flex gap-3 text-sm leading-6 ${
            dark ? "text-[#d2ddd5]" : "text-[#385040]"
          }`}
        >
          <Check
            aria-hidden
            className={`mt-0.5 size-4 shrink-0 ${
              dark ? "text-[#88d0a0]" : "text-[#101818]"
            }`}
          />
          <span className={item.includes("SHA-256") ? monoLabel : undefined}>
            {item}
          </span>
        </li>
      ))}
    </ul>
  );
}

function Hero() {
  return (
    <section className="relative isolate overflow-hidden bg-[#000808] text-[#e8ece8]">
      <div className="absolute inset-x-0 top-0 h-px bg-[#e8ece8]/20" />
      <div className="mx-auto flex min-h-[92vh] w-full max-w-[1760px] flex-col px-5 py-5 sm:px-8 lg:px-10">
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
          <nav className="hidden items-center gap-6 text-sm text-[#c5d6ca] sm:flex">
            <a className="transition hover:text-[#e8ece8]" href="#shortcuts">
              Shortcuts
            </a>
            <a className="transition hover:text-[#e8ece8]" href="#shelf">
              Shelf
            </a>
            <a className="transition hover:text-[#e8ece8]" href="#local">
              Local-first
            </a>
            <Link className="transition hover:text-[#e8ece8]" href="/support">
              Support
            </Link>
          </nav>
        </header>

        <div className="hero-grid grid flex-1 items-center gap-12 py-12 lg:gap-14 lg:py-16">
          <div className="hero-copy max-w-6xl">
            <div
              className={`mb-8 inline-flex items-center gap-2 rounded-full border border-[#e8ece8]/18 bg-[#101818] px-3 py-1.5 text-sm text-[#a6dcb8] ${brandLabel}`}
            >
              <Radio aria-hidden className="size-4" />
              Private dictation for macOS
            </div>
            <h1 className="hero-title max-w-6xl text-balance font-semibold leading-[0.96] tracking-[-0.025em]">
              Capture the thought. Keep your place.
            </h1>
            <p className="mt-7 max-w-2xl text-pretty text-lg leading-8 text-[#d2ddd5] sm:text-xl">
              Hold Right Command to dictate into the app you are already using.
              Add Shift to save a voice capture to your local shelf instead.
              Selected text and typed notes live there too.
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
                Read the privacy policy
              </Link>
            </div>
            <div className="mt-10 flex flex-wrap gap-2 text-sm text-[#c5d6ca]">
              <span
                className={`inline-flex items-center gap-2 rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}
              >
                <StatusDot />
                Local transcription
              </span>
              <span className={`rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}>
                Inbox and Done
              </span>
              <span className={`rounded-full bg-[#101818] px-3 py-1.5 ${brandLabel}`}>
                No telemetry
              </span>
            </div>
          </div>

          <ScreenshotFrame
            src="/screenshots/shelf-current.png"
            alt="The current Voiced shelf with Inbox and Done, shortcut hints, typed captures, a text editor, refinement, copy, drag, remove, and permission recovery controls."
            width={2024}
            height={1452}
            priority
            className="hero-shot mx-auto w-full max-w-[980px]"
          />
        </div>
      </div>
    </section>
  );
}

function ShortcutSection() {
  return (
    <section id="shortcuts" className="bg-[#f7faf8] px-5 py-16 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-7xl">
        <div className="grid gap-6 border-b border-border pb-10 lg:grid-cols-[0.82fr_1.18fr] lg:items-end">
          <h2 className="max-w-2xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            One gesture decides where the words go.
          </h2>
          <p className="max-w-2xl text-pretty text-base leading-7 text-muted-foreground lg:justify-self-end">
            Insert a transcript immediately or keep it in Inbox. Voiced confirms
            the result in the notch, then gets out of the way.
          </p>
        </div>

        <div className="divide-y divide-border lg:grid lg:grid-cols-2 lg:divide-x lg:divide-y-0">
          {shortcuts.map((shortcut, index) => (
            <section
              key={shortcut.title}
              className={`py-7 lg:px-8 ${index % 2 === 0 ? "lg:pl-0" : "lg:pr-0"}`}
            >
              <div className="flex flex-wrap items-center gap-2">
                {shortcut.keys.map((key) => (
                  <kbd
                    key={key}
                    className={`rounded-[8px] bg-[#101818] px-2.5 py-1.5 text-xs text-[#e8ece8] ${monoLabel}`}
                  >
                    {key}
                  </kbd>
                ))}
                <span className="ml-1 text-sm font-semibold">{shortcut.title}</span>
              </div>
              <p className="mt-3 max-w-xl text-sm leading-6 text-muted-foreground">
                {shortcut.text}
              </p>
            </section>
          ))}
        </div>
      </div>
    </section>
  );
}

function ShelfSection() {
  return (
    <section id="shelf" className="bg-[#e7efea] px-5 py-18 sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-7xl gap-12 xl:grid-cols-[0.88fr_1.12fr] xl:items-center">
        <div>
          <div className="flex size-11 items-center justify-center rounded-[10px] bg-[#101818] text-[#88d0a0]">
            <ListTodo aria-hidden className="size-5" />
          </div>
          <h2 className="mt-7 max-w-2xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            A shelf for text that still needs somewhere to go.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-muted-foreground">
            Voice, selections, and typed notes become the same editable capture.
            Keep active work in Inbox, move finished items to Done, and pick up
            exactly where you left off after a relaunch.
          </p>
          <div className="mt-8 max-w-lg">
            <FactList items={shelfActions} />
          </div>
        </div>

        <div className="rounded-[18px] bg-[#000808] p-5 text-[#e8ece8] sm:p-7">
          <div className="flex items-center justify-between gap-4 border-b border-[#e8ece8]/14 pb-5">
            <div className="flex items-center gap-3">
              <Search aria-hidden className="size-5 text-[#88d0a0]" />
              <div>
                <p className="font-semibold">One local capture library</p>
                <p className="mt-1 text-sm text-[#b8c9bd]">Inbox stays focused. Done stays searchable.</p>
              </div>
            </div>
            <span className={`rounded-full bg-[#181c1c] px-3 py-1.5 text-xs text-[#c5d6ca] ${monoLabel}`}>
              ⌥ Space
            </span>
          </div>
          <div className="grid gap-0 sm:grid-cols-[0.72fr_1.28fr]">
            <div className="border-b border-[#e8ece8]/14 py-6 sm:border-r sm:border-b-0 sm:pr-6">
              <p className={`text-xs text-[#80b890] ${brandLabel}`}>Capture sources</p>
              <div className="mt-5 space-y-5">
                <div className="flex items-center gap-3">
                  <Mic aria-hidden className="size-4 text-[#88d0a0]" />
                  <span className="text-sm">Voice</span>
                </div>
                <div className="flex items-center gap-3">
                  <ScanText aria-hidden className="size-4 text-[#88d0a0]" />
                  <span className="text-sm">Selection</span>
                </div>
                <div className="flex items-center gap-3">
                  <Keyboard aria-hidden className="size-4 text-[#88d0a0]" />
                  <span className="text-sm">Typed</span>
                </div>
              </div>
            </div>
            <div className="py-6 sm:pl-6">
              <div className="flex items-center justify-between gap-4">
                <p className="text-sm font-semibold">Capture detail</p>
                <span className={`rounded-full bg-[#88d0a0] px-2.5 py-1 text-xs text-[#000808] ${brandLabel}`}>
                  Inbox
                </span>
              </div>
              <p className="mt-5 text-base leading-7 text-[#d2ddd5]">
                Outline the settings walkthrough and verify the permission
                recovery links.
              </p>
              <div className="mt-7 flex flex-wrap gap-2 text-xs">
                {["Refine", "Copy", "Drag", "Remove"].map((action) => (
                  <span
                    key={action}
                    className={`rounded-full bg-[#181c1c] px-3 py-1.5 text-[#d2ddd5] ${brandLabel}`}
                  >
                    {action}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function RefinementSection() {
  return (
    <section className="bg-[#000808] px-5 py-18 text-[#e8ece8] sm:px-8 lg:px-10">
      <div className="mx-auto grid max-w-7xl gap-12 xl:grid-cols-[1.08fr_0.92fr] xl:items-center">
        <div className="rounded-[18px] bg-[#101818] p-5 sm:p-7">
          <div className="flex flex-wrap items-center justify-between gap-4 border-b border-[#e8ece8]/14 pb-5">
            <div className="flex items-center gap-3">
              <Sparkles aria-hidden className="size-5 text-[#88d0a0]" />
              <div>
                <p className="font-semibold">Review clean transcript</p>
                <p className="mt-1 text-sm text-[#b8c9bd]">Nothing changes until you apply it.</p>
              </div>
            </div>
            <div className="flex rounded-[8px] bg-[#181c1c] p-1 text-xs">
              <span className={`rounded-[6px] bg-[#384840] px-3 py-1.5 ${brandLabel}`}>Proposed</span>
              <span className={`px-3 py-1.5 text-[#b8c9bd] ${brandLabel}`}>Original</span>
            </div>
          </div>
          <div className="min-h-44 py-7 text-base leading-8 text-[#dce6df]">
            Today I need to make the bed, go for a walk, cook tea, and watch the football.
          </div>
          <div className="flex flex-col-reverse gap-3 border-t border-[#e8ece8]/14 pt-5 sm:flex-row sm:justify-end">
            <span className={`inline-flex h-10 items-center justify-center rounded-full bg-[#181c1c] px-4 text-sm ${brandLabel}`}>
              Keep Original
            </span>
            <span className={`inline-flex h-10 items-center justify-center rounded-full bg-[#88d0a0] px-4 text-sm text-[#000808] ${brandLabel}`}>
              Apply Clean Transcript
            </span>
          </div>
        </div>

        <div>
          <div className="flex size-11 items-center justify-center rounded-[10px] bg-[#181c1c] text-[#88d0a0]">
            <Undo2 aria-hidden className="size-5" />
          </div>
          <h2 className="mt-7 max-w-2xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Refine only after you review the result.
          </h2>
          <p className="mt-5 max-w-xl text-pretty text-base leading-7 text-[#c5d6ca]">
            On compatible Macs, Apple Intelligence can propose a cleaned
            transcript, executive summary, or to-do list. Compare the proposal
            with the original, then apply it or keep your words unchanged.
          </p>
          <ul className="mt-8 space-y-3 text-sm leading-6 text-[#d2ddd5]">
            <li className="flex gap-3"><Check aria-hidden className="mt-0.5 size-4 shrink-0 text-[#88d0a0]" />Applied refinements can be undone.</li>
            <li className="flex gap-3"><Check aria-hidden className="mt-0.5 size-4 shrink-0 text-[#88d0a0]" />Checklist items can be sent to a chosen Reminders list.</li>
            <li className="flex gap-3"><Check aria-hidden className="mt-0.5 size-4 shrink-0 text-[#88d0a0]" />The raw capture remains ready when Apple Intelligence is unavailable.</li>
          </ul>
        </div>
      </div>
    </section>
  );
}

function LocalSection() {
  return (
    <section id="local" className="bg-[#f7faf8] px-5 py-18 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-7xl">
        <div className="grid gap-8 lg:grid-cols-[0.82fr_1.18fr] lg:items-end">
          <h2 className="max-w-3xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Setup is explicit because trust should be visible.
          </h2>
          <p className="max-w-2xl text-pretty text-base leading-7 text-muted-foreground lg:justify-self-end">
            Voiced explains why each permission is needed, offers a recovery
            action wherever it matters, and waits for approval before
            downloading a speech model.
          </p>
        </div>

        <div className="mt-12 grid gap-10 xl:grid-cols-[1.08fr_0.92fr] xl:items-center">
          <ScreenshotFrame
            src="/screenshots/onboarding-current.png"
            alt="The current Voiced setup window showing local speech model choices, microphone access, Accessibility, and Input Monitoring with direct recovery actions."
            width={1452}
            height={1396}
            className="mx-auto w-full max-w-[760px]"
          />

          <div className="grid gap-6 sm:grid-cols-2 xl:grid-cols-1">
            <section className="rounded-[12px] bg-[#e7efea] p-6">
              <div className="flex items-center gap-3">
                <HardDriveDownload aria-hidden className="size-5 text-[#101818]" />
                <h3 className="text-lg font-semibold tracking-[-0.01em]">Local speech models</h3>
              </div>
              <div className="mt-6"><FactList items={modelFacts} /></div>
            </section>
            <section className="rounded-[12px] bg-[#101818] p-6 text-[#e8ece8]">
              <div className="flex items-center gap-3">
                <ShieldCheck aria-hidden className="size-5 text-[#88d0a0]" />
                <h3 className="text-lg font-semibold tracking-[-0.01em]">Local by design</h3>
              </div>
              <div className="mt-6"><FactList items={privacyFacts} dark /></div>
            </section>
          </div>
        </div>
      </div>
    </section>
  );
}

function TrustSection() {
  const trustPoints = [
    {
      icon: Monitor,
      title: "A Mac utility, not a web account",
      text: "Voiced runs from the menu bar and stores its shelf in Application Support on this Mac.",
    },
    {
      icon: Lock,
      title: "Clipboard changes are handled carefully",
      text: "Insertion restores the previous clipboard only when nothing else changed it during the operation.",
    },
    {
      icon: ShieldCheck,
      title: "Sensitive content stays out of logs",
      text: "Audio, transcripts, selections, clipboard contents, file names, window titles, and destination apps are not logged.",
    },
  ];

  return (
    <section className="border-y border-border bg-[#e7efea] px-5 py-16 sm:px-8 lg:px-10">
      <div className="mx-auto max-w-7xl">
        <div className="grid gap-10 lg:grid-cols-[0.7fr_1.3fr]">
          <div>
            <h2 className="max-w-xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
              Clear boundaries, all the way through.
            </h2>
            <Link
              href="/privacy"
              className={`mt-7 inline-flex items-center gap-2 text-sm text-[#101818] underline decoration-[#80b890] decoration-2 underline-offset-4 transition hover:text-[#385040] ${brandLabel}`}
            >
              Read the full privacy policy
            </Link>
          </div>
          <div className="grid gap-7 md:grid-cols-3">
            {trustPoints.map(({ icon: Icon, title, text }) => (
              <section key={title} className="border-t border-[#aebdb3] pt-5">
                <Icon aria-hidden className="mb-5 size-5 text-[#385040]" />
                <h3 className="text-lg font-semibold tracking-[-0.01em]">{title}</h3>
                <p className="mt-3 text-sm leading-6 text-muted-foreground">{text}</p>
              </section>
            ))}
          </div>
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
          <p className={`text-sm text-[#a6dcb8] ${brandLabel}`}>macOS 14 or newer</p>
          <h2 className="mt-3 max-w-3xl text-balance text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-5xl">
            Put your next thought where it belongs.
          </h2>
          <p className="mt-5 max-w-xl text-base leading-7 text-[#c5d6ca]">
            Download Voiced directly, choose a local speech model, and finish the
            guided permission setup on your Mac.
          </p>
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
          <Link className="transition hover:text-foreground" href="/privacy">Privacy</Link>
          <Link className="transition hover:text-foreground" href="/support">Support</Link>
        </nav>
      </div>
    </footer>
  );
}

export default function Home() {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <Hero />
      <ShortcutSection />
      <ShelfSection />
      <RefinementSection />
      <LocalSection />
      <TrustSection />
      <DownloadCta />
      <Footer />
    </main>
  );
}
