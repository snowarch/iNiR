"use client"

import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"

interface SearchResult {
  title: string
  slug: string
  excerpt: string
  section?: string
  sectionAnchor?: string
  type: "page" | "section"
}

interface IndexEntry {
  type: "page" | "section"
  slug: string
  title: string
  description?: string
  content?: string
  section?: string
  sectionAnchor?: string
  excerpt?: string
  level?: number
}

let searchIndex: IndexEntry[] | null = null

async function loadIndex(): Promise<IndexEntry[]> {
  if (searchIndex) return searchIndex
  const res = await fetch("/search-index.json")
  searchIndex = await res.json()
  return searchIndex!
}

function searchDocs(index: IndexEntry[], q: string): SearchResult[] {
  const query = q.toLowerCase()
  const scored: (SearchResult & { score: number })[] = []

  for (const entry of index) {
    if (entry.type === "page") {
      const titleHit = entry.title.toLowerCase().includes(query)
      const descHit = (entry.description || "").toLowerCase().includes(query)
      const contentHit = (entry.content || "").includes(query)
      if (titleHit || descHit || contentHit) {
        scored.push({
          type: "page",
          title: entry.title,
          slug: entry.slug,
          excerpt: entry.description || "",
          score: titleHit ? 20 : descHit ? 8 : 3,
        })
      }
    } else {
      const sectionHit = (entry.section || "").toLowerCase().includes(query)
      if (sectionHit) {
        scored.push({
          type: "section",
          title: entry.title,
          slug: entry.slug,
          section: entry.section,
          sectionAnchor: entry.sectionAnchor,
          excerpt: entry.excerpt || "",
          score: entry.level === 2 ? 15 : 10,
        })
      }
    }
  }

  scored.sort((a, b) => b.score - a.score)
  const seen = new Set<string>()
  const deduped: SearchResult[] = []
  for (const r of scored) {
    const key = r.slug + (r.sectionAnchor || "")
    if (!seen.has(key)) {
      seen.add(key)
      deduped.push({ type: r.type, title: r.title, slug: r.slug, excerpt: r.excerpt, section: r.section, sectionAnchor: r.sectionAnchor })
    }
  }
  return deduped.slice(0, 12)
}

export function Search() {
  const [isOpen, setIsOpen] = useState(false)
  const [query, setQuery] = useState("")
  const [results, setResults] = useState<SearchResult[]>([])
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const router = useRouter()

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault()
        setIsOpen(true)
      }
      if (e.key === "Escape") {
        setIsOpen(false)
        setQuery("")
      }
    }
    window.addEventListener("keydown", handleKeyDown)
    return () => window.removeEventListener("keydown", handleKeyDown)
  }, [])

  useEffect(() => {
    if (isOpen && inputRef.current) inputRef.current.focus()
  }, [isOpen])

  useEffect(() => {
    setSelectedIndex(0)
    if (query.length < 2) { setResults([]); return }
    loadIndex().then((idx) => setResults(searchDocs(idx, query))).catch(() => setResults([]))
  }, [query])

  const close = () => { setIsOpen(false); setQuery("") }

  const handleSelect = (result: SearchResult) => {
    close()
    const base = result.slug ? `/docs/${result.slug}` : "/docs"
    const href = result.sectionAnchor ? `${base}#${result.sectionAnchor}` : base
    router.push(href)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "ArrowDown") {
      e.preventDefault()
      setSelectedIndex((i) => Math.min(i + 1, results.length - 1))
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      setSelectedIndex((i) => Math.max(i - 1, 0))
    } else if (e.key === "Enter" && results[selectedIndex]) {
      e.preventDefault()
      handleSelect(results[selectedIndex])
    }
  }

  return (
    <>
      {/* ── Floating search trigger bar — fixed top-center ── */}
      <div className="fixed top-0 left-0 right-0 z-40 pointer-events-none flex items-center justify-center h-12">
        <button
          onClick={() => setIsOpen(true)}
          className="pointer-events-auto flex items-center gap-2.5 px-4 py-1.5 border border-border/60 bg-background/70 backdrop-blur-xl text-text-dim font-mono text-[11px] transition-all hover:border-main/60 hover:text-main hover:bg-background/90 shadow-[0_2px_12px_rgba(0,0,0,0.4)]"
          aria-label="Search docs"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="flex-shrink-0">
            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
          </svg>
          <span className="hidden sm:inline">search docs...</span>
          <span className="ml-1 flex items-center gap-1 opacity-50">
            <kbd className="font-mono text-[9px] border border-border px-1 py-px bg-surface">ctrl</kbd>
            <kbd className="font-mono text-[9px] border border-border px-1 py-px bg-surface">k</kbd>
          </span>
        </button>
      </div>

      {/* ── Full-screen modal ── */}
      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-[100] bg-background/70 backdrop-blur-md"
            onClick={close}
          />
          <div className="fixed left-1/2 top-[15%] z-[101] w-full max-w-2xl -translate-x-1/2 px-4">
            <div
              className="overflow-hidden border-2 border-main/50 bg-background/90 backdrop-blur-2xl shadow-[0_0_80px_rgba(0,0,0,0.7),8px_8px_0px_0px_var(--color-border)] ring-1 ring-main/10"
              style={{ WebkitBackdropFilter: "blur(32px)" }}
            >
              {/* Input row */}
              <div className="flex items-center gap-3 border-b border-border/50 px-4 py-3">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-main flex-shrink-0">
                  <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
                </svg>
                <input
                  ref={inputRef}
                  type="text"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder="search docs..."
                  className="flex-1 bg-transparent font-mono text-sm text-foreground outline-none placeholder:text-text-dim/50"
                />
                <button
                  onClick={close}
                  className="font-mono text-[10px] text-text-dim hover:text-main border border-border px-1.5 py-0.5 transition-colors"
                >
                  esc
                </button>
              </div>

              {/* Results */}
              <div className="max-h-[360px] overflow-y-auto">
                {query.length < 2 ? (
                  <div className="py-8 flex flex-col items-center gap-1">
                    <span className="font-mono text-[10px] text-text-dim/40 uppercase tracking-widest">type to search pages and sections</span>
                    <span className="font-mono text-[9px] text-text-dim/25 uppercase tracking-widest">21 pages · installation · theming · ipc · modules…</span>
                  </div>
                ) : results.length === 0 ? (
                  <div className="py-8 flex flex-col items-center gap-1">
                    <span className="font-mono text-[10px] text-text-dim/40 uppercase tracking-widest">no results for &quot;{query}&quot;</span>
                  </div>
                ) : (
                  results.map((result, index) => {
                    const isActive = index === selectedIndex
                    return (
                      <button
                        key={`${result.slug}-${result.sectionAnchor || "page"}`}
                        onClick={() => handleSelect(result)}
                        className={`group w-full border-b border-border/30 px-4 py-3 text-left font-mono transition-all ${
                          isActive
                            ? "bg-main/10 border-l-2 border-l-main"
                            : "hover:bg-surface/50 border-l-2 border-l-transparent"
                        }`}
                      >
                        {/* Row: type badge + breadcrumb */}
                        <div className="flex items-center gap-2 mb-1">
                          <span className={`text-[9px] font-bold uppercase tracking-widest px-1.5 py-px border ${
                            result.type === "section"
                              ? "border-main/30 text-main/60 bg-main/5"
                              : "border-border text-text-dim/50 bg-surface/50"
                          }`}>
                            {result.type === "section" ? "§" : "doc"}
                          </span>
                          <span className="text-[10px] text-text-dim/40 truncate">
                            {result.title}
                            {result.section && (
                              <span className="text-text-dim/25"> › {result.section}</span>
                            )}
                          </span>
                        </div>
                        {/* Main title */}
                        <div className={`text-[12px] font-bold truncate transition-colors ${isActive ? "text-main" : "text-foreground/80 group-hover:text-main"}`}>
                          {result.section || result.title}
                        </div>
                        {/* Excerpt */}
                        {result.excerpt && (
                          <div className="mt-0.5 text-[11px] text-text-dim/50 truncate">
                            {result.excerpt}
                          </div>
                        )}
                      </button>
                    )
                  })
                )}
              </div>

              {/* Footer */}
              <div className="flex items-center justify-between border-t border-border/40 bg-surface/30 px-4 py-2 font-mono text-[10px] text-text-dim/50">
                <div className="flex gap-4">
                  <span><span className="text-main">↑↓</span> navigate</span>
                  <span><span className="text-main">↵</span> open</span>
                  <span><span className="text-main">esc</span> close</span>
                </div>
                <span className="text-text-dim/30">iNiR docs</span>
              </div>
            </div>
          </div>
        </>
      )}
    </>
  )
}
