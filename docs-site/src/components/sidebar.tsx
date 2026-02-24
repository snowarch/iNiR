"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { useState } from "react"
import { ThemeToggle } from "./theme-toggle"

const navigation = [
  {
    title: "start",
    items: [
      { title: "Introduction", href: "/docs" },
      { title: "Quick Reference", href: "/docs/quick-reference" },
      { title: "Installation", href: "/docs/installation" },
      { title: "Requirements", href: "/docs/requirements" },
      { title: "First Steps", href: "/docs/first-steps" },
    ],
  },
  {
    title: "guides",
    items: [
      { title: "Configuration", href: "/docs/configuration" },
      { title: "Keybindings", href: "/docs/keybindings" },
      { title: "Theming", href: "/docs/theming" },
      { title: "Panel Families", href: "/docs/panel-families" },
      { title: "Features", href: "/docs/features" },
      { title: "Workflows", href: "/docs/workflows" },
    ],
  },
  {
    title: "reference",
    items: [
      { title: "Config Options", href: "/docs/config-options" },
      { title: "IPC Commands", href: "/docs/ipc" },
      { title: "Modules", href: "/docs/modules" },
      { title: "Changelog", href: "/docs/changelog" },
    ],
  },
  {
    title: "advanced",
    items: [
      { title: "Architecture", href: "/docs/architecture" },
      { title: "Contributing", href: "/docs/contributing" },
    ],
  },
  {
    title: "help",
    items: [
      { title: "FAQ", href: "/docs/faq" },
      { title: "Troubleshooting", href: "/docs/troubleshooting" },
      { title: "Limitations", href: "/docs/limitations" },
      { title: "iNiR vs illogical-impulse", href: "/docs/comparison" },
    ],
  },
]

export function Sidebar() {
  const pathname = usePathname()
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <>
      {/* Mobile Toggle */}
      <button
        onClick={() => setMobileOpen(!mobileOpen)}
        className="fixed left-4 top-3 z-50 lg:hidden border-2 border-border bg-background px-3 py-1.5 font-mono text-sm font-bold shadow-[3px_3px_0px_0px_#000] transition-all hover:border-main hover:text-main hover:shadow-[4px_4px_0px_0px_#000] hover:translate-x-[-1px] hover:translate-y-[-1px]"
        aria-label="Toggle menu"
      >
        <span className="text-main font-mono text-base">{mobileOpen ? "×" : "≡"}</span>
      </button>

      {/* Mobile Overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-background/95 backdrop-blur-sm lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed left-0 top-0 z-40 h-screen w-64 border-r-2 border-border bg-background transition-transform duration-200 lg:translate-x-0 ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex h-full flex-col">

          {/* Header */}
          <div className="flex items-center justify-between border-b-2 border-border px-4 py-3 bg-surface">
            <Link
              href="/"
              className="group flex items-center gap-0 font-mono text-base font-bold text-main no-underline hover:no-underline hover:opacity-80 transition-opacity"
            >
              <span className="text-foreground/30 group-hover:text-main/60 transition-colors">[</span>
              <span>iNiR</span>
              <span className="text-foreground/30 group-hover:text-main/60 transition-colors">]</span>
            </Link>
            <div className="flex items-center gap-2">
              <ThemeToggle />
            </div>
          </div>

            {/* Navigation */}
          <nav className="flex-1 overflow-y-auto px-0 py-3">
            <div className="space-y-5">
              {navigation.map((section) => (
                <div key={section.title}>
                  {/* Section header — raw bracket label */}
                  <div className="flex items-center gap-0 px-4 mb-1">
                    <span className="font-mono text-[9px] font-bold uppercase tracking-[0.25em] text-text-dim">{section.title}</span>
                    <div className="ml-2 h-px flex-1 bg-border/60" />
                  </div>
                  <ul className="space-y-0">
                    {section.items.map((item) => {
                      const isActive = pathname === item.href
                      return (
                        <li key={item.href}>
                          <Link
                            href={item.href}
                            onClick={() => setMobileOpen(false)}
                            className={`group relative flex items-center px-4 py-2 font-mono text-[12px] transition-all ${
                              isActive
                                ? "text-main bg-main/8 border-l-2 border-main font-bold"
                                : "text-text-muted border-l-2 border-transparent hover:text-main hover:bg-main/4 hover:border-main"
                            }`}
                          >
                            <span className="flex items-center gap-2">
                              {isActive ? (
                                <span className="text-main text-[8px]">█</span>
                              ) : (
                                <span className="text-border group-hover:text-main/60 transition-colors text-[10px]">›</span>
                              )}
                              <span>{item.title}</span>
                            </span>
                          </Link>
                        </li>
                      )
                    })}
                  </ul>
                </div>
              ))}
            </div>
          </nav>

          {/* Footer */}
          <div className="border-t-2 border-border px-4 py-3 bg-surface">
            <div className="flex items-center justify-between font-mono text-[10px]">
              <div className="flex items-center gap-1.5 border border-main/30 bg-main/8 px-2 py-1">
                <span className="w-1.5 h-1.5 bg-main rounded-full animate-pulse" />
                <span className="font-bold text-main">v2.11.1</span>
              </div>
              <div className="text-text-dim flex items-center gap-1 text-[9px]">
                <span>qs + niri</span>
              </div>
            </div>
          </div>
        </div>
      </aside>
    </>
  )
}
