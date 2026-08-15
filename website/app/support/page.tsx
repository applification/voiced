import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Support for Voiced, including capture shortcuts, local transcription, shelf recovery, permissions, and refinement actions.",
  alternates: {
    canonical: "/support",
  },
};

const supportTopics = [
  {
    title: "Voice shortcuts",
    text: "Hold Right Command to dictate into the previously focused editor. Hold Shift + Right Command to save a voice capture quietly to Inbox. Release either gesture to finish recording, or press Escape to cancel.",
  },
  {
    title: "Microphone permission",
    text: "Voiced needs microphone access to record while push-to-talk is active. You can review this in macOS System Settings under Privacy & Security.",
  },
  {
    title: "Capture permissions",
    text: "Accessibility lets Voiced read an explicit selection and insert a capture. Input Monitoring listens for Right Command, Shift + Right Command, double Shift, and Option-Space. The shelf and Settings provide recovery buttons.",
  },
  {
    title: "Model downloads",
    text: "The first local transcription model download can be large. After download and verification, Voiced uses the cached model from Application Support.",
  },
  {
    title: "Local shelf storage",
    text: "Voice, selection, and typed captures are stored at ~/Library/Application Support/Voiced/Captures.json. Inbox and Done persist across launches. If the file is corrupt, Voiced preserves a timestamped recovery copy before opening an empty shelf.",
  },
  {
    title: "Refinement actions",
    text: "Clean transcript, executive summary, and to-do list actions use Apple Intelligence on compatible Macs. Voiced shows the proposed and original text before anything changes. Applied refinements can be undone, and checklist items can be exported to Reminders.",
  },
  {
    title: "Insertion and clipboard recovery",
    text: "Automatic insertion temporarily uses the clipboard to post Command-V. Selected-text fallback can use Command-C when Accessibility does not expose a selection. Voiced restores the previous clipboard only if nothing else changed it during the operation.",
  },
];

export default function SupportPage() {
  return (
    <main className="min-h-screen bg-[#000808] px-5 py-12 text-[#e8ece8] sm:px-8 lg:px-10">
      <section className="mx-auto max-w-3xl">
        <Link
          href="/"
          className="text-sm font-medium text-[#88d0a0] transition hover:text-[#e8ece8]"
        >
          Back to Voiced
        </Link>

        <header className="py-12">
          <h1 className="text-balance text-4xl font-semibold leading-tight tracking-[-0.03em] sm:text-6xl">
            Support
          </h1>
          <p className="mt-5 text-pretty text-lg leading-8 text-[#c5d6ca]">
            If Voiced is not recording, saving a selection, inserting text,
            opening the shelf, or downloading a model, start with the relevant
            permission or recovery action below.
          </p>
        </header>

        <div className="space-y-8 border-y border-[#e8ece8]/14 py-8">
          {supportTopics.map((topic) => (
            <section key={topic.title}>
              <h2 className="text-2xl font-semibold tracking-[-0.02em]">
                {topic.title}
              </h2>
              <p className="mt-3 text-base leading-7 text-[#c5d6ca]">
                {topic.text}
              </p>
            </section>
          ))}
        </div>

        <section className="py-8">
          <h2 className="text-2xl font-semibold tracking-[-0.02em]">
            Report an issue
          </h2>
          <p className="mt-3 text-base leading-7 text-[#c5d6ca]">
            Send support requests to{" "}
            <a
              className="text-[#88d0a0] transition hover:text-[#e8ece8]"
              href="mailto:voiced@applification.net?subject=Voiced%20Support"
            >
              voiced@applification.net
            </a>
            . Include your macOS version, Voiced version, selected model, the
            shortcut you used, and whether the issue happens during recording,
            transcription, insertion, or in the shelf.
          </p>
        </section>

        <section className="border-t border-[#e8ece8]/14 py-8">
          <h2 className="text-2xl font-semibold tracking-[-0.02em]">Privacy</h2>
          <p className="mt-3 text-base leading-7 text-[#c5d6ca]">
            Read the Voiced privacy policy at{" "}
            <Link className="text-[#88d0a0] hover:text-[#e8ece8]" href="/privacy">
              voiced.applification.net/privacy
            </Link>
            .
          </p>
        </section>
      </section>
    </main>
  );
}
