import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Overpass, Overpass_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const overpass = Overpass({
  variable: "--font-overpass",
  subsets: ["latin"],
});

const overpassMono = Overpass_Mono({
  variable: "--font-overpass-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://voiced.applification.net"),
  title: {
    default: "Voiced - Review-First Dictation for macOS",
    template: "%s - Voiced",
  },
  description:
    "Voiced is a focused Mac dictation app that turns push-to-talk recordings into local transcripts you can review, clean, copy, and drag.",
  applicationName: "Voiced",
  authors: [{ name: "Applification" }],
  creator: "Applification",
  publisher: "Applification",
  keywords: [
    "Voiced",
    "macOS dictation",
    "private transcription",
    "local transcription",
    "push to talk",
    "Apple Intelligence",
    "Foundation Models",
    "Mac productivity app",
  ],
  category: "productivity",
  icons: {
    icon: [
      { url: "/voiced-icon.png", type: "image/png", sizes: "1024x1024" },
      { url: "/icon.png", type: "image/png", sizes: "1024x1024" },
    ],
    apple: [{ url: "/voiced-icon.png", type: "image/png", sizes: "1024x1024" }],
    shortcut: [{ url: "/voiced-icon.png", type: "image/png" }],
  },
  openGraph: {
    title: "Voiced - Review-First Dictation for macOS",
    description:
      "A focused Mac dictation app for turning speech into local transcripts you can review, clean, copy, and drag.",
    url: "/",
    siteName: "Voiced",
    images: [
      {
        url: "/voiced-icon.png",
        width: 1024,
        height: 1024,
        alt: "Voiced app icon",
      },
    ],
    locale: "en_GB",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "Voiced - Review-First Dictation for macOS",
    description:
      "Push-to-talk dictation for Mac, with local transcription and review-window actions.",
    images: ["/voiced-icon.png"],
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Voiced",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#000808",
  colorScheme: "dark",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} ${overpass.variable} ${overpassMono.variable} h-full bg-[#000808] antialiased`}
    >
      <body className="min-h-full flex flex-col bg-[#000808]">{children}</body>
    </html>
  );
}
