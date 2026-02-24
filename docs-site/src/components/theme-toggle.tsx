"use client"

import { useEffect, useState } from "react"

export function ThemeToggle() {
  const [theme, setTheme] = useState<"light" | "dark">("dark")

  useEffect(() => {
    const stored = localStorage.getItem("theme") as "light" | "dark" | null
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const initialTheme = stored || (prefersDark ? "dark" : "light")
    setTheme(initialTheme)
    document.documentElement.classList.toggle("light", initialTheme === "light")
  }, [])

  const toggleTheme = () => {
    const newTheme = theme === "dark" ? "light" : "dark"
    setTheme(newTheme)
    localStorage.setItem("theme", newTheme)
    document.documentElement.classList.toggle("light", newTheme === "light")
  }

  return (
    <button
      onClick={toggleTheme}
      className="border border-border px-2 py-1 font-mono text-[10px] text-text-muted transition-colors hover:border-main hover:text-main"
      aria-label="Toggle theme"
    >
      {theme === "dark" ? "[light]" : "[dark]"}
    </button>
  )
}
