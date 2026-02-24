import Link from "next/link"
import { AnimatedTerminal } from "@/components/animated-terminal"
import { ThemeToggle } from "@/components/theme-toggle"

const features = [
  {
    title: "Two panel families",
    desc: "ii is floating Material Design. waffle is a taskbar layout inspired by Windows 11. Switch with a keybind, no restart.",
    icon: "◫",
    tag: "01",
  },
  {
    title: "Five visual styles",
    desc: "Material (solid), Cards (subtle shadows), Aurora (glass blur), iNiR (TUI borders), Angel (neo-brutalism). Switch at runtime.",
    icon: "◈",
    tag: "02",
  },
  {
    title: "Settings GUI",
    desc: "Both families have their own settings window. Every config option has a control. JSON is optional.",
    icon: "⚙",
    tag: "03",
  },
  {
    title: "Wallpaper theming",
    desc: "matugen extracts Material You colors from your wallpaper. Terminals, GTK, and the shell update together.",
    icon: "◉",
    tag: "04",
  },
  {
    title: "IPC control",
    desc: "Every panel and action is callable via IPC.Bind from Niri config, scripts, or the terminal.",
    icon: "⌗",
    tag: "05",
  },
  {
    title: "Built for Niri",
    desc: "Designed around scrolling workspaces. Multi-monitor aware, per-screen wallpapers, Niri-native overview.",
    icon: "⊞",
    tag: "06",
  },
]

const modules = [
  { name: "bar", desc: "Workspaces, tray, clock, weather, media, utility buttons" },
  { name: "dock", desc: "Pinned apps, running indicators, drag to reorder" },
  { name: "overview", desc: "Niri-native workspace view with app icons" },
  { name: "notifications", desc: "Popups, history, do not disturb, per-app rules" },
  { name: "media", desc: "MPRIS controls, album art, multi-player support" },
  { name: "sidebars", desc: "Left for app launcher, right for quick toggles" },
  { name: "settings", desc: "Dedicated GUI for ii and waffle families" },
  { name: "lock screen", desc: "Auth, clock, media controls while locked" },
  { name: "clipboard", desc: "Searchable history with image preview via cliphist" },
]

const screenshots = [
  { src: "https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8", alt: "iNiR bar, dock, and settings" },
  { src: "https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8", alt: "iNiR sidebar widgets and wallpaper browser" },
  { src: "https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7", alt: "iNiR sidebar and media controls" },
  { src: "https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc", alt: "iNiR overview with calendar and notifications" },
]

/* ── Unified CTA button — same style everywhere ── */
function CtaButton({
  href,
  children,
  primary = false,
  external = false,
}: {
  href: string
  children: React.ReactNode
  primary?: boolean
  external?: boolean
}) {
  const cls = primary ? "glass-btn glass-btn-primary" : "glass-btn glass-btn-secondary"
  if (external) {
    return <a href={href} target="_blank" rel="noopener noreferrer" className={cls}>{children}</a>
  }
  return <Link href={href} className={cls}>{children}</Link>
}

/* ── Section label — raw TUI style ── */
function SectionLabel({ index, label }: { index: string; label: string }) {
  return (
    <div className="flex items-center gap-0 mb-3">
      <span className="font-mono text-[10px] font-bold text-main border border-main px-2 py-0.5 mr-3">{index}</span>
      <span className="font-mono text-[10px] font-bold uppercase tracking-[0.25em] text-foreground/40">{label}</span>
      <div className="h-px flex-1 ml-4 bg-border" />
    </div>
  )
}

/* ── Section number decoration (top-right big number) ── */
function SectionNumber({ n }: { n: string }) {
  return (
    <div
      className="absolute top-8 right-8 font-mono font-bold select-none pointer-events-none leading-none"
      style={{ fontSize: "clamp(60px,8vw,96px)", color: "var(--color-border)", opacity: 0.35 }}
    >
      {n}
    </div>
  )
}

/* ── ASCII logo — compact FIGlet iNiR ── */
const asciiLogo = `
 ██╗ ███╗  ██╗ ██╗ ██████╗
 ██║ ████╗ ██║ ██║ ██╔══██╗
 ██║ ██╔██╗██║ ██║ ██████╔╝
 ██║ ██║╚████║ ██║ ██╔══██╗
 ██║ ██║ ╚███║ ██║ ██║  ██║
 ╚═╝ ╚═╝  ╚══╝ ╚═╝ ╚═╝  ╚═╝`.trim()

/* ── Arrow icon ── */
function ArrowRight() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M2.5 6h7M7 3.5L9.5 6 7 8.5" />
    </svg>
  )
}

export default function HomePage() {
  return (
    <div className="min-h-screen bg-background text-foreground">

      {/* ── NAVBAR ── */}
      <nav className="fixed top-0 left-0 right-0 z-50 border-b-2 border-border">
        <div className="absolute inset-0 bg-background/90 backdrop-blur-xl" />
        <div className="relative mx-auto max-w-6xl flex items-center justify-between px-6 h-12">
          <Link
            href="/"
            className="flex items-center gap-0 font-mono text-sm font-bold text-main no-underline hover:no-underline"
          >
            <span className="text-foreground/30 mr-0.5">[</span>
            <span>iNiR</span>
            <span className="text-foreground/30 ml-0.5">]</span>
          </Link>

          <div className="flex items-center gap-1 font-mono text-[11px] uppercase tracking-widest">
            {[
              { href: "#get-started", label: "install" },
              { href: "#preview", label: "preview" },
              { href: "#features", label: "features" },
              { href: "/docs", label: "docs" },
            ].map((item) => {
              const classes = "px-3 py-1.5 text-foreground/40 hover:text-main hover:bg-main/5 border border-transparent hover:border-border transition-all no-underline hover:no-underline"
              const isHash = item.href.startsWith("#")
              if (isHash) {
                return (
                  <a key={item.href} href={item.href} className={classes}>
                    {item.label}
                  </a>
                )
              }
              return (
                <Link key={item.href} href={item.href} className={classes}>
                  {item.label}
                </Link>
              )
            })}
            <ThemeToggle />
            <a
              href="https://github.com/snowarch/inir"
              target="_blank"
              rel="noopener noreferrer"
              className="ml-1 flex items-center gap-1.5 px-3 py-1.5 border-2 border-border bg-surface text-foreground/60 hover:border-main hover:text-main font-mono text-[10px] uppercase tracking-widest transition-all shadow-[3px_3px_0px_0px_var(--color-border)] hover:shadow-[5px_5px_0px_0px_var(--color-border-strong)] hover:translate-x-[-1px] hover:translate-y-[-1px]"
            >
              <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21.5c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0012 2z"/>
              </svg>
              <span>github</span>
            </a>
          </div>
        </div>
      </nav>

      {/* ── HERO ── */}
      <div className="relative overflow-hidden">
        <div className="absolute inset-0 z-0">
          <img
            src={`${process.env.NEXT_PUBLIC_BASE_PATH || ""}/hero-bg.jpg`}
            alt=""
            className="h-full w-full object-cover opacity-30"
            aria-hidden="true"
          />
        </div>
        <div className="absolute inset-0 z-[1] bg-gradient-to-b from-background/60 via-background/40 to-background" aria-hidden="true" />
        <div className="absolute inset-0 z-[1] bg-radial-vignette" aria-hidden="true" />
        <div className="absolute inset-0 z-[2] scanlines pointer-events-none" aria-hidden="true" />

        <section className="relative z-10 min-h-[100dvh] flex flex-col items-center justify-center px-6 py-24 pt-20">
          <div className="w-full max-w-4xl text-center">

            {/* Version badge */}
            <div className="mb-8 flex items-center justify-center">
              <div className="glass-pill flex items-center gap-3">
                <span className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 bg-main rounded-full animate-pulse" />
                  <span className="border border-main/40 bg-main/10 text-main px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-widest">v2.11.1</span>
                </span>
                <span className="font-mono text-[10px] text-foreground/40 uppercase tracking-widest">latest</span>
              </div>
            </div>

            {/* ASCII Logo — compact */}
            <div className="mb-6 flex justify-center">
              <pre
                className="font-mono text-main text-[7px] sm:text-[10px] md:text-[13px] lg:text-[16px] leading-[1.15] tracking-[0.02em] title-glow select-none whitespace-pre"
                aria-label="iNiR"
              >{asciiLogo}</pre>
            </div>

            {/* Subtitle */}
            <p className="mx-auto mb-12 max-w-lg font-mono text-xs leading-relaxed text-foreground/40">
              Bar · dock · sidebars · overview · notifications · clipboard · media · lock screen · settings
            </p>

            {/* CTA buttons — all use glass style */}
            <div className="flex flex-wrap items-center justify-center gap-4 mb-16">
              <CtaButton href="/docs" primary>
                <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M2 3h12v10H2z" /><path d="M5 7l2.5 2L5 11" /><path d="M9 11h3" />
                </svg>
                <span>read the docs</span>
              </CtaButton>
              <CtaButton href="https://github.com/snowarch/inir" external>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21.5c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0012 2z"/>
                </svg>
                <span>github</span>
              </CtaButton>
            </div>

            {/* Stats — TUI inline row */}
            <div className="inline-flex items-center border border-border/60 bg-background/40 backdrop-blur-sm font-mono text-[11px] md:text-[13px]">
              {[
                { value: "2", label: "panels" },
                { value: "5", label: "styles" },
                { value: "41", label: "presets" },
                { value: "59+", label: "services" },
              ].map((stat, i) => (
                <span key={stat.label} className="flex items-center">
                  {i > 0 && <span className="text-border/60 select-none px-0">│</span>}
                  <span className="px-4 py-3 md:px-6 md:py-4 flex items-baseline gap-1.5 hover:bg-main/5 transition-colors">
                    <span className="font-bold text-main">{stat.value}</span>
                    <span className="text-foreground/30 uppercase tracking-wider text-[8px] md:text-[9px]">{stat.label}</span>
                  </span>
                </span>
              ))}
            </div>
          </div>

        </section>
      </div>

      {/* ── GET STARTED (01) ── */}
      <section id="get-started" className="relative border-t-2 border-border py-28 px-6 bg-background overflow-hidden">
        <div className="absolute inset-0 bg-grid opacity-100 pointer-events-none" />
        <div className="absolute top-0 left-0 w-16 h-16 border-r-2 border-b-2 border-main/30 pointer-events-none" />
        <div className="absolute bottom-0 right-0 w-16 h-16 border-l-2 border-t-2 border-main/30 pointer-events-none" />
        <SectionNumber n="01" />

        <div className="relative mx-auto max-w-3xl">
          <SectionLabel index="01" label="get started" />
          <h2 className="font-mono text-3xl font-bold leading-tight md:text-4xl mb-2 mt-4">
            Three commands.
          </h2>
          <p className="mb-10 max-w-xl font-mono text-[12px] leading-relaxed text-foreground/35 uppercase tracking-wider">
            Arch Linux + Niri. The setup script handles everything.
          </p>

          <div className="relative group">
            <div className="border-2 border-border bg-surface overflow-hidden shadow-[5px_5px_0px_0px_var(--color-border)] group-hover:shadow-[8px_8px_0px_0px_var(--color-border)] group-hover:border-main group-hover:-translate-x-[2px] group-hover:-translate-y-[2px] transition-all duration-150">
              <AnimatedTerminal />
            </div>
          </div>

          <p className="mt-5 font-mono text-[11px] text-foreground/25">
            Other distros:{" "}
            <Link href="/docs/installation" className="text-main hover:underline">
              full install guide
            </Link>
            {" "}for manual steps.
          </p>

          {/* Buttons matching hero style */}
          <div className="mt-8 flex flex-wrap gap-4">
            <CtaButton href="/docs/installation" primary>
              <span>install guide</span>
              <ArrowRight />
            </CtaButton>
            <CtaButton href="/docs/requirements">
              <span>requirements</span>
              <ArrowRight />
            </CtaButton>
          </div>
        </div>
      </section>

      {/* ── SCREENSHOTS (02) ── */}
      <section id="preview" className="py-24 border-t-2 border-border bg-secondary-background relative overflow-hidden">
        <SectionNumber n="02" />
        <div className="relative mx-auto max-w-6xl px-8">
          <SectionLabel index="02" label="preview" />
          <h2 className="font-mono text-3xl font-bold leading-tight md:text-4xl mb-2 mt-4">See it in action.</h2>
          <p className="mb-10 font-mono text-[12px] text-foreground/30 uppercase tracking-wider">
            Five visual styles. Runtime switching. No restart.
          </p>

          <div className="grid gap-6 md:grid-cols-2">
            {screenshots.map((shot, i) => (
              <div key={i} className="group transition-all duration-150">
                <div className="border-2 border-border bg-background overflow-hidden shadow-[5px_5px_0px_0px_var(--color-border)] group-hover:shadow-[8px_8px_0px_0px_var(--color-border)] group-hover:border-main group-hover:-translate-x-[2px] group-hover:-translate-y-[2px] transition-all duration-150">
                  <div className="flex items-center justify-between px-3 py-2 bg-surface border-b-2 border-border font-mono text-[9px]">
                    <div className="flex items-center gap-2">
                      <div className="flex gap-1">
                        <span className="w-2 h-2 bg-error" />
                        <span className="w-2 h-2 bg-main" />
                        <span className="w-2 h-2 bg-success" />
                      </div>
                      <span className="text-text-dim">{shot.alt}</span>
                    </div>
                    <span className="text-main font-bold">[{String(i + 1).padStart(2, "0")}/{String(screenshots.length).padStart(2, "0")}]</span>
                  </div>
                  <img
                    src={shot.src}
                    alt={shot.alt}
                    className="w-full h-auto object-cover"
                    loading="lazy"
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── FEATURES (03) ── */}
      <section id="features" className="py-24 border-t-2 border-border relative overflow-hidden">
        <div className="absolute inset-0 bg-grid pointer-events-none" />
        <SectionNumber n="03" />

        <div className="relative mx-auto max-w-5xl px-8">
          <SectionLabel index="03" label="features" />
          <h2 className="font-mono text-3xl font-bold leading-tight md:text-4xl mb-2 mt-4">
            One config. Full desktop.
          </h2>
          <p className="mb-10 max-w-xl font-mono text-[12px] leading-relaxed text-foreground/35 uppercase tracking-wider">
            Single Quickshell process. Replaces bar, dock, notifs, launcher, clipboard, lock screen, settings.
          </p>

          <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {features.map((feature) => (
              <div key={feature.title} className="group transition-all duration-150 h-full">
                <div className="border-2 border-border bg-surface p-6 shadow-[5px_5px_0px_0px_var(--color-border)] group-hover:shadow-[8px_8px_0px_0px_var(--color-border)] group-hover:border-main group-hover:-translate-x-[2px] group-hover:-translate-y-[2px] transition-all duration-150 overflow-hidden relative flex flex-col h-full gap-4">
                  {/* Top accent bar */}
                  <div className="absolute top-0 left-0 right-0 h-[2px] bg-main scale-x-0 group-hover:scale-x-100 transition-transform origin-left" />
                  {/* Tag */}
                  <div className="absolute top-4 right-4 font-mono text-[9px] font-bold text-border group-hover:text-main/50 transition-colors">
                    {feature.tag}
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-main font-mono text-lg">{feature.icon}</span>
                  </div>
                  <h3 className="font-mono text-[13px] font-bold text-foreground/90 uppercase tracking-wide">
                    {feature.title}
                  </h3>
                  <p className="font-mono text-[12px] leading-[1.7] text-foreground/40 mt-auto">
                    {feature.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── MODULES (04) ── */}
      <section id="modules" className="py-24 border-t-2 border-border bg-secondary-background relative overflow-hidden">
        <SectionNumber n="04" />
        <div className="relative mx-auto max-w-5xl px-8">
          <SectionLabel index="04" label="modules" />
          <h2 className="font-mono text-3xl font-bold leading-tight md:text-4xl mb-2 mt-4">
            Everything ships together.
          </h2>
          <p className="mb-10 font-mono text-[12px] text-foreground/30 uppercase tracking-wider">
            No piecemeal setup. Install once.
          </p>

          <div className="group">
            <div className="border-2 border-border bg-background overflow-hidden shadow-[5px_5px_0px_0px_var(--color-border)] group-hover:shadow-[8px_8px_0px_0px_var(--color-border)] group-hover:border-main group-hover:-translate-x-[2px] group-hover:-translate-y-[2px] transition-all duration-150">
              <div className="flex flex-col sm:flex-row border-b-2 border-border">
                <div className="w-full sm:w-40 lg:w-48 flex-shrink-0 px-5 py-2 border-r border-border">
                  <span className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-main">module</span>
                </div>
                <div className="flex-1 px-5 py-2">
                  <span className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-text-dim">description</span>
                </div>
              </div>
              <div className="grid gap-0 sm:grid-cols-1">
                {modules.map((mod, i) => (
                  <div
                    key={mod.name}
                    className="group/item flex flex-col sm:flex-row transition-all duration-150 hover:bg-main/[0.03] relative overflow-hidden border-b border-border last:border-b-0"
                  >
                    <div className="absolute left-0 top-0 bottom-0 w-[3px] bg-main scale-y-0 group-hover/item:scale-y-100 transition-transform origin-bottom" />
                    <div className="w-full sm:w-40 lg:w-48 flex-shrink-0 px-5 py-4 border-r border-border">
                      <span className="font-mono text-[11px] font-bold text-main uppercase tracking-wide">
                        {String(i + 1).padStart(2, "0")} {mod.name}
                      </span>
                    </div>
                    <div className="flex-1 px-5 py-4">
                      <span className="font-mono text-[11px] text-foreground/35 leading-relaxed">
                        {mod.desc}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="mt-10">
            <CtaButton href="/docs/modules">
              <span>all modules</span>
              <ArrowRight />
            </CtaButton>
          </div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="border-t-2 border-border py-10 bg-background">
        <div className="mx-auto max-w-5xl px-8">
          <div className="flex flex-col items-center justify-between gap-6 md:flex-row">
            <div className="font-mono text-xs text-foreground/40">
              <span className="font-bold text-foreground/60">[iNiR]</span>
              <span className="text-border mx-2">│</span>
              fork of{" "}
              <a href="https://github.com/end-4/dots-hyprland" className="text-main hover:underline" target="_blank" rel="noopener noreferrer">
                illogical-impulse
              </a>
              {" "}by{" "}
              <a href="https://github.com/snowarch" className="font-bold text-main hover:underline" target="_blank" rel="noopener noreferrer">
                snowarch
              </a>
            </div>
            <div className="flex items-center gap-4 font-mono text-[10px] uppercase tracking-wider text-foreground/20">
              <span className="flex items-center gap-1.5 px-2 py-1 border border-border bg-surface">
                <span className="w-1.5 h-1.5 bg-success rounded-full" />
                GPL-3.0
              </span>
              <a href="https://github.com/snowarch/inir" className="text-foreground/30 hover:text-main transition-colors" target="_blank" rel="noopener noreferrer">
                github
              </a>
              <Link href="/docs" className="text-foreground/30 hover:text-main transition-colors">
                docs
              </Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
