import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Privacy details for Voiced, including local captures, local transcription, model downloads, permissions, and clipboard handling.",
  alternates: {
    canonical: "/privacy",
  },
};

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
            Effective 10 August 2026
          </p>
          <h1 className="mt-3 text-balance text-4xl font-semibold leading-tight tracking-[-0.03em] sm:text-6xl">
            Privacy Policy
          </h1>
          <p className="mt-5 text-pretty text-lg leading-8 text-[#c5d6ca]">
            Voiced keeps captures and transcription on your Mac. It has no
            account, telemetry, analytics, cloud storage, or cloud transcription
            service.
          </p>
        </header>

        <Section title="Local captures">
          <p>
            Voice, selected text, and typed input create the same local capture
            item. Captures are saved as readable JSON at
            <code className="mx-1 text-[#88d0a0]">
              ~/Library/Application Support/Voiced/Captures.json
            </code>
            . The file includes capture text, status, timestamps, source type,
            and the source application name and bundle identifier when
            available.
          </p>
          <p>
            Writes are atomic. If the file cannot be decoded, Voiced preserves a
            timestamped recovery copy before starting an empty shelf.
          </p>
        </Section>

        <Section title="Local transcription">
          <p>
            Voiced records only while push-to-talk is active. Audio is processed
            by the local Whisper model and temporary recording data is removed
            after transcription or cancellation. Audio and capture text are not
            uploaded to Applification.
          </p>
        </Section>

        <Section title="Model downloads">
          <p>
            Voiced uses the network only after you explicitly request a speech
            model download. WhisperKit may contact Hugging Face. Downloaded
            models are stored in Application Support and checked against pinned
            size and SHA-256 integrity values before loading.
          </p>
        </Section>

        <Section title="Accessibility and Input Monitoring">
          <p>
            Input Monitoring lets Voiced listen for Right Command, Shift + Right Command, double Shift,
            Option-Space, and Escape. Accessibility lets Voiced read the selected
            text exposed by the focused application and insert a capture after a
            user action. Voiced does not use these permissions to collect
            arbitrary keystrokes or background document content.
          </p>
        </Section>

        <Section title="Clipboard handling">
          <p>
            Some applications do not expose selected text through Accessibility.
            For those applications, Voiced can perform a controlled Command-C
            fallback. Automatic insertion can perform Command-V. Both operations
            snapshot the clipboard and restore it only if the clipboard has not
            changed during the operation. A newer clipboard value is never
            overwritten.
          </p>
        </Section>

        <Section title="On-device review actions">
          <p>
            On compatible Macs, Voiced can use Apple Intelligence through
            Foundation Models to clean a capture, summarize it, or turn tasks
            into a checklist. These actions run on device. Reminders export
            occurs only when you choose it and uses the macOS Reminders
            permission.
          </p>
        </Section>

        <Section title="Logs and data collection">
          <p>
            Voiced does not collect usage diagnostics. Application logs do not
            include audio, capture or transcript text, selected text, clipboard
            contents, source URLs, file names, window titles, or destination
            application names.
          </p>
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
