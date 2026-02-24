"use client"

import { useState, useEffect } from "react"

export function BackToTop() {
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    const toggleVisibility = () => {
      setIsVisible(window.scrollY > 400)
    }

    window.addEventListener("scroll", toggleVisibility)
    return () => window.removeEventListener("scroll", toggleVisibility)
  }, [])

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  if (!isVisible) return null

  return (
    <button
      onClick={scrollToTop}
      className="fixed bottom-6 right-6 z-50 border border-border bg-surface px-2 py-1 font-mono text-[10px] text-text-muted transition-colors hover:border-main hover:text-main"
      aria-label="Back to top"
    >
      [top]
    </button>
  )
}
