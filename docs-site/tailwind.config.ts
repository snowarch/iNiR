import type { Config } from "tailwindcss"

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        main: "var(--color-main)",
        "main-foreground": "var(--color-main-foreground)",
        background: "var(--color-background)",
        foreground: "var(--color-foreground)",
        "secondary-background": "var(--color-secondary-background)",
        surface: "var(--color-surface)",
        "surface-high": "var(--color-surface-high)",
        border: "var(--color-border)",
        "border-accent": "var(--color-border-accent)",
        text: "var(--color-text)",
        "text-muted": "var(--color-text-muted)",
        "text-dim": "var(--color-text-dim)",
        accent: "var(--color-accent)",
        success: "var(--color-success)",
        warning: "var(--color-warning)",
        error: "var(--color-error)",
        tertiary: "var(--color-tertiary)",
        secondary: "var(--color-secondary)",
      },
      boxShadow: {
        shadow: "var(--shadow-shadow)",
        "shadow-sm": "var(--shadow-shadow-sm)",
        "shadow-hard": "var(--shadow-shadow-hard)",
      },
      borderRadius: {
        base: "var(--radius-base)",
      },
      fontFamily: {
        mono: ["'JetBrains Mono'", "'Fira Code'", "'Cascadia Code'", "monospace"],
      },
    },
  },
  plugins: [],
}

export default config
