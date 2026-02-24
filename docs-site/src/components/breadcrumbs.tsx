"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"

export function Breadcrumbs() {
  const pathname = usePathname()

  if (pathname === "/" || pathname === "/docs") return null

  const segments = pathname.split("/").filter(Boolean)

  const breadcrumbs = segments.map((segment, index) => {
    const href = "/" + segments.slice(0, index + 1).join("/")
    const label = segment
      .split("-")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(" ")

    return { href, label }
  })

  return (
    <nav className="mb-6 nb-box inline-flex items-center gap-1.5 px-3 py-2 font-mono text-[10px] text-text-dim">
      <Link href="/" className="hover:text-main font-bold text-main">~</Link>
      {breadcrumbs.map((crumb, index) => (
        <span key={crumb.href} className="flex items-center gap-1.5">
          <span className="text-border">/</span>
          {index === breadcrumbs.length - 1 ? (
            <span className="text-text-muted uppercase tracking-widest">{crumb.label.toLowerCase()}</span>
          ) : (
            <Link href={crumb.href} className="hover:text-main text-foreground">
              {crumb.label.toLowerCase()}
            </Link>
          )}
        </span>
      ))}
    </nav>
  )
}
