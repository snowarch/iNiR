"use client"

import { useState, useEffect } from "react"

interface TocItem {
  id: string
  text: string
  level: number
}

export function TableOfContents() {
  const [headings, setHeadings] = useState<TocItem[]>([])
  const [activeId, setActiveId] = useState<string>("")

  useEffect(() => {
    const elements = Array.from(document.querySelectorAll("article h2, article h3"))
    const items: TocItem[] = elements.map((elem) => ({
      id: elem.id,
      text: elem.textContent || "",
      level: parseInt(elem.tagName[1]),
    }))
    setHeadings(items)

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setActiveId(entry.target.id)
          }
        })
      },
      { rootMargin: "-60px 0px -70% 0px" }
    )

    elements.forEach((elem) => observer.observe(elem))
    return () => observer.disconnect()
  }, [])

  if (headings.length === 0) return null

  return (
    <nav
      aria-label="On this page"
      className="hidden xl:block fixed right-0 top-0 bottom-0 w-60 pointer-events-none"
      style={{ paddingTop: "48px" /* navbar h-12 */ }}
    >
      <div className="pointer-events-auto flex flex-col h-full border-l-2 border-border bg-background overflow-hidden">
        {/* Header */}
        <div className="flex-shrink-0 flex items-center gap-2 border-b border-border bg-surface px-4 py-2.5">
          <span className="w-1.5 h-1.5 rounded-full bg-main animate-pulse flex-shrink-0" />
          <h4 className="font-mono text-[10px] font-bold uppercase tracking-widest text-main">
            on this page
          </h4>
        </div>

        {/* Scrollable list */}
        <ul className="flex-1 overflow-y-auto font-mono text-[11px] py-2 scrollbar-thin">
          {headings.map((heading, idx) => {
            const isActive = activeId === heading.id
            const pl = heading.level === 3 ? "pl-7" : "pl-4"

            return (
              <li key={heading.id || `heading-${idx}`}>
                <a
                  href={`#${heading.id}`}
                  className={`group flex items-center gap-2 py-1.5 pr-3 border-l-2 transition-all ${pl} ${
                    isActive
                      ? "border-main text-main font-semibold bg-main/8"
                      : "border-transparent text-text-muted hover:text-main hover:border-main/50 hover:bg-main/4"
                  }`}
                >
                  <span
                    className={`flex-shrink-0 transition-colors leading-none ${
                      isActive ? "text-main" : "text-border group-hover:text-main/50"
                    }`}
                  >
                    {isActive ? "●" : "›"}
                  </span>
                  <span className="truncate leading-snug">{heading.text}</span>
                </a>
              </li>
            )
          })}
        </ul>

        {/* Bottom accent line */}
        <div className="flex-shrink-0 h-px bg-gradient-to-r from-transparent via-main/30 to-transparent" />
      </div>
    </nav>
  )
}
