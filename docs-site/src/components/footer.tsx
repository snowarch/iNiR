import Link from "next/link"

export function Footer() {
  return (
    <footer className="relative border-t-2 border-border bg-background py-12 lg:ml-64 overflow-hidden">
      {/* Accent line top */}
      <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-main/40 to-transparent" />

      {/* Grid bg */}
      <div className="absolute inset-0 bg-grid opacity-40 pointer-events-none" />

      <div className="xl:mr-56 relative">
        <div className="mx-auto max-w-[720px] px-6 lg:px-10">

          {/* Footer grid */}
          <div className="grid gap-5 md:grid-cols-3">
            {[
              {
                label: "docs",
                links: [
                  { href: "/docs/installation", label: "Installation", internal: true },
                  { href: "/docs/configuration", label: "Configuration", internal: true },
                  { href: "/docs/keybindings", label: "Keybindings", internal: true },
                  { href: "/docs/troubleshooting", label: "Troubleshooting", internal: true },
                ],
              },
              {
                label: "links",
                links: [
                    { href: "https://github.com/snowarch/inir", label: "GitHub", internal: false },
                    { href: "https://github.com/snowarch/inir/issues", label: "Issues", internal: false },
                  { href: "/docs/contributing", label: "Contributing", internal: true },
                ],
              },
              {
                label: "upstream",
                links: [
                  { href: "https://github.com/YaLTeR/niri", label: "Niri", internal: false },
                  { href: "https://quickshell.outfoxxed.me", label: "Quickshell", internal: false },
                ],
              },
            ].map((col) => (
              <div
                key={col.label}
                className="group border-2 border-border bg-surface p-5 shadow-[4px_4px_0px_0px_#000] transition-all hover:border-main hover:shadow-[6px_6px_0px_0px_#000] hover:translate-x-[-1px] hover:translate-y-[-1px]"
              >
                <h4 className="mb-4 font-mono text-[9px] font-bold uppercase tracking-[0.25em] text-main flex items-center gap-1">
                  <span className="text-foreground/30 group-hover:text-main/60 transition-colors">[</span>
                  <span>{col.label}</span>
                  <span className="text-foreground/30 group-hover:text-main/60 transition-colors">]</span>
                </h4>
                <ul className="space-y-2 font-mono text-[11px]">
                  {col.links.map((link) =>
                    link.internal ? (
                      <li key={link.href}>
                        <Link
                          href={link.href}
                          className="flex items-center gap-2 text-text-muted hover:text-main transition-colors no-underline hover:no-underline"
                        >
                          <span className="text-border group-hover:text-main/40 transition-colors">›</span>
                          <span>{link.label}</span>
                        </Link>
                      </li>
                    ) : (
                      <li key={link.href}>
                        <a
                          href={link.href}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-2 text-text-muted hover:text-main transition-colors no-underline hover:no-underline"
                        >
                          <span className="text-border group-hover:text-main/40 transition-colors">›</span>
                          <span>{link.label}</span>
                        </a>
                      </li>
                    )
                  )}
                </ul>
              </div>
            ))}
          </div>

          {/* Bottom bar */}
          <div className="mt-8 border-t-2 border-border pt-6">
            <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
              <div className="font-mono text-xs text-text-muted">
                <span className="font-bold text-foreground/60">[iNiR]</span>
                <span className="text-text-dim mx-2">│</span>
                <span>by{" "}
                  <a
                    href="https://github.com/snowarch"
                    className="font-bold text-main hover:underline"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    snowarch
                  </a>
                </span>
              </div>
              <div className="flex items-center gap-4 font-mono text-[10px] uppercase tracking-wider text-text-dim">
                <span className="flex items-center gap-1.5 px-2 py-1 border border-border bg-background shadow-[2px_2px_0px_0px_#000]">
                  <span className="w-1.5 h-1.5 bg-success rounded-full" />
                  <span>GPL-3.0</span>
                </span>
                <span className="text-border">│</span>
                <span>fork of illogical-impulse</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </footer>
  )
}
