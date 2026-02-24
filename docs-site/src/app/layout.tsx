import type { Metadata } from "next"
import "@/styling/globals.css"
import "@/styling/hero.css"

export const metadata: Metadata = {
  title: {
    default: "iNiR docs",
    template: "%s | iNiR",
  },
  description: "Quickshell configuration for Niri. Two panel families, five visual styles, 41 theme presets. Arch Linux.",
  keywords: ["iNiR", "Quickshell", "Niri", "Wayland", "Linux", "QML", "shell", "bar", "dock"],
  authors: [{ name: "snowarch", url: "https://github.com/snowarch" }],
  creator: "snowarch",
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://inir.dev",
    title: "iNiR",
    description: "Quickshell configuration for Niri compositor",
    siteName: "iNiR",
  },
  twitter: {
    card: "summary_large_image",
    title: "iNiR",
    description: "Quickshell configuration for Niri compositor",
  },
  robots: {
    index: true,
    follow: true,
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
        <link
          href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700;800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="bg-background text-foreground">{children}</body>
    </html>
  )
}
