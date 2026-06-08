import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Privacy details for Voiced Dictation, including local transcription, model downloads, and optional diagnostics.",
  alternates: {
    canonical: "/privacy",
  },
};

const diagnosticsIncluded = [
  "app opens and anonymous install activity",
  "app version, build number, macOS version, processor count, and architecture",
  "recording starts and cancellations",
  "transcription success or failure",
  "model load success or failure",
  "output failures and broad error categories",
];

const diagnosticsExcluded = [
  "audio recordings",
  "transcript text",
  "clipboard contents",
  "screen recordings or session replay",
  "file names, file paths, and window titles",
  "the apps or text fields you dictate into",
];

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="border-t border-[#e8ece8]/14 py-8">
      <h2 className="text-2xl font-semibold tracking-[-0.02em]">{title}</h2>
      <div className="mt-4 space-y-4 text-base leading-7 text-[#c5d6ca]">
        {children}
      </div>
    </section>
  );
}

function BulletList({ items }: { items: string[] }) {
  return (
    <ul className="space-y-2">
      {items.map((item) => (
        <li key={item} className="flex gap-3">
          <span aria-hidden className="mt-3 size-1.5 shrink-0 rounded-full bg-[#88d0a0]" />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-[#000808] px-5 py-12 text-[#e8ece8] sm:px-8 lg:px-10">
      <article className="mx-auto max-w-3xl">
        <Link
          href="/"
          className="text-sm font-medium text-[#88d0a0] transition hover:text-[#e8ece8]"
        >
          Back to Voiced
        </Link>

        <header className="py-12">
          <p className="text-sm font-medium text-[#80b890]">
            Effective 7 June 2026
          </p>
          <h1 className="mt-3 text-balance text-4xl font-semibold leading-tight tracking-[-0.03em] sm:text-6xl">
            Privacy Policy
          </h1>
          <p className="mt-5 text-pretty text-lg leading-8 text-[#c5d6ca]">
            Voiced Dictation is built for local speech transcription on your
            Mac. Audio and transcript text are not uploaded to Applification or
            to a cloud transcription service.
          </p>
        </header>

        <Section title="Local transcription">
          <p>
            Voiced records only while push-to-talk is active. Temporary audio is
            used for local transcription, then deleted after processing,
            including error paths. Transcript text is copied or pasted according
            to your output setting and is not stored by Voiced after that flow.
          </p>
        </Section>

        <Section title="Model downloads">
          <p>
            On first run, Voiced asks you to choose a local transcription model
            and shows the approximate download size before downloading. Model
            downloads use the network and may contact Hugging Face through
            WhisperKit. Downloaded model files are stored in the app container
            and verified before loading.
          </p>
        </Section>

        <Section title="Clipboard and Accessibility">
          <p>
            Clipboard Only mode places the transcript on the clipboard for you
            to paste manually. Auto Paste mode temporarily writes the transcript
            to the clipboard and sends Command-V to the focused app after you
            grant macOS Accessibility permission. Voiced restores the previous
            clipboard contents when possible and does not collect clipboard
            contents.
          </p>
        </Section>

        <Section title="Basic diagnostics">
          <p>
            Voiced can share basic usage and crash diagnostics through PostHog
            to help us understand whether the app is working. Diagnostics can be
            turned off in Settings.
          </p>
          <div className="grid gap-6 md:grid-cols-2">
            <div>
              <h3 className="mb-3 text-lg font-semibold">Included</h3>
              <BulletList items={diagnosticsIncluded} />
            </div>
            <div>
              <h3 className="mb-3 text-lg font-semibold">Not included</h3>
              <BulletList items={diagnosticsExcluded} />
            </div>
          </div>
        </Section>

        <Section title="Contact">
          <p>
            For privacy questions, contact Applification through the support
            page at{" "}
            <Link className="text-[#88d0a0] hover:text-[#e8ece8]" href="/support">
              voiced.applification.net/support
            </Link>
            .
          </p>
        </Section>
      </article>
    </main>
  );
}
