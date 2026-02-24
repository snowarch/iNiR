"use client"

import Link from "next/link"

interface DocNavProps {
  prev?: { title: string; href: string }
  next?: { title: string; href: string }
}

export function DocNav({ prev, next }: DocNavProps) {
  if (!prev && !next) return null

  return (
    <div className="mt-14 grid gap-4 border-t-2 border-border pt-8 md:grid-cols-2">
      {prev ? (
        <Link
          href={prev.href}
          className="nb-card p-4 group"
        >
          <div className="nb-tag mb-3 inline-flex">
            <span className="text-main">‹</span>
            <span className="ml-2">prev</span>
          </div>
          <div className="font-mono text-sm font-bold text-foreground group-hover:text-main">
            {prev.title}
          </div>
        </Link>
      ) : (
        <div />
      )}
      {next && (
        <Link
          href={next.href}
          className="nb-card p-4 text-right group"
        >
          <div className="nb-tag mb-3 inline-flex">
            <span>next</span>
            <span className="ml-2 text-main">›</span>
          </div>
          <div className="font-mono text-sm font-bold text-foreground group-hover:text-main">
            {next.title}
          </div>
        </Link>
      )}
    </div>
  )
}
