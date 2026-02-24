import Link from "next/link"

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background bg-grid p-8">
      <div className="max-w-lg w-full">
        {/* ASCII Art Error Box */}
        <div className="mb-8 border-2 border-border bg-surface shadow-[6px_6px_0px_0px_#2a2630] overflow-hidden">
          {/* Terminal header */}
          <div className="flex items-center gap-3 border-b border-border bg-background px-4 py-2">
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-full border border-border bg-error/80" />
              <span className="w-3 h-3 rounded-full border border-border bg-main/80" />
              <span className="w-3 h-3 rounded-full border border-border bg-success/80" />
            </div>
            <span className="font-mono text-[10px] text-text-dim uppercase tracking-wider">error</span>
          </div>
          
          {/* ASCII content */}
          <pre className="p-6 font-mono text-main text-xs text-center select-none">
{`╔═══════════════════════════════╗
║                               ║
║      ERROR  ▓▓  4 0 4         ║
║                               ║
║     page not found            ║
║                               ║
╚═══════════════════════════════╝`}
          </pre>
        </div>

        <p className="mb-8 text-center font-mono text-xs text-text-muted">
          The requested path does not exist or has been moved.
        </p>

        {/* Action buttons */}
        <div className="flex justify-center gap-4 mb-10">
          <Link
            href="/"
            className="group flex items-center gap-2 border-2 border-main bg-main px-6 py-2.5 font-mono text-xs font-bold text-main-foreground shadow-[4px_4px_0px_0px_#2a2630] transition-all hover:shadow-[6px_6px_0px_0px_#2a2630] hover:translate-x-[-2px] hover:translate-y-[-2px]"
          >
            <span className="text-border group-hover:text-main-foreground/80">[</span>
            home
            <span className="text-border group-hover:text-main-foreground/80">]</span>
          </Link>
          <Link
            href="/docs"
            className="group flex items-center gap-2 border-2 border-border bg-surface px-6 py-2.5 font-mono text-xs font-bold text-foreground shadow-[4px_4px_0px_0px_#2a2630] transition-all hover:shadow-[6px_6px_0px_0px_#2a2630] hover:border-main hover:text-main hover:translate-x-[-2px] hover:translate-y-[-2px]"
          >
            <span className="text-border group-hover:text-main">[</span>
            docs
            <span className="text-border group-hover:text-main">]</span>
          </Link>
        </div>

        {/* Quick links */}
        <div className="border-2 border-border bg-surface shadow-[4px_4px_0px_0px_#2a2630] overflow-hidden">
          <div className="flex items-center gap-2 border-b border-border bg-background px-4 py-2">
            <span className="w-1.5 h-1.5 bg-main rounded-full animate-pulse" />
            <h2 className="font-mono text-[10px] font-bold uppercase tracking-widest text-text-dim">
              {"//"} try these
            </h2>
          </div>
          <ul className="p-4 space-y-2 font-mono text-xs">
            <li>
              <Link href="/docs/installation" className="group flex items-center gap-2 text-text-muted hover:text-main transition-colors">
                <span className="text-border group-hover:text-main">›</span>
                <span>Installation</span>
              </Link>
            </li>
            <li>
              <Link href="/docs/configuration" className="group flex items-center gap-2 text-text-muted hover:text-main transition-colors">
                <span className="text-border group-hover:text-main">›</span>
                <span>Configuration</span>
              </Link>
            </li>
            <li>
              <Link href="/docs/keybindings" className="group flex items-center gap-2 text-text-muted hover:text-main transition-colors">
                <span className="text-border group-hover:text-main">›</span>
                <span>Keybindings</span>
              </Link>
            </li>
            <li>
              <Link href="/docs/troubleshooting" className="group flex items-center gap-2 text-text-muted hover:text-main transition-colors">
                <span className="text-border group-hover:text-main">›</span>
                <span>Troubleshooting</span>
              </Link>
            </li>
          </ul>
        </div>
      </div>
    </div>
  )
}
