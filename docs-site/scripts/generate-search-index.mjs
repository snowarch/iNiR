#!/usr/bin/env node
/**
 * Generate static search index for client-side search
 * Run: node scripts/generate-search-index.mjs
 * Output: public/search-index.json
 */

import fs from "fs"
import path from "path"
import matter from "gray-matter"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const docsDir = path.join(__dirname, "../src/content/docs")
const outFile = path.join(__dirname, "../public/search-index.json")

function extractHeadings(content) {
  const lines = content.split("\n")
  const headings = []
  for (const line of lines) {
    const m = line.match(/^(#{2,3})\s+(.+)$/)
    if (m) {
      const text = m[2].replace(/[*_`]/g, "").trim()
      const anchor = text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
      headings.push({ text, level: m[1].length, anchor })
    }
  }
  return headings
}

function getHeadingExcerpt(content, heading, maxLen = 110) {
  const lines = content.split("\n")
  const idx = lines.findIndex((l) => l.replace(/^#{2,3}\s+/, "").replace(/[*_`]/g, "").trim() === heading)
  if (idx === -1) return ""
  for (let i = idx + 1; i < Math.min(idx + 6, lines.length); i++) {
    const line = lines[i].trim()
    if (line && !line.startsWith("#") && !line.startsWith("```") && !line.startsWith("|")) {
      return line.replace(/[*_`[\]]/g, "").slice(0, maxLen) + (line.length > maxLen ? "…" : "")
    }
  }
  return ""
}

function buildIndex() {
  const files = fs.readdirSync(docsDir).filter((f) => f.endsWith(".mdx"))
  const index = []

  for (const file of files) {
    const slug = file.replace(/\.mdx$/, "")
    const realSlug = slug === "index" ? "" : slug
    const raw = fs.readFileSync(path.join(docsDir, file), "utf8")
    const { data, content } = matter(raw)

    // Page entry
    index.push({
      type: "page",
      slug: realSlug,
      title: data.title || slug,
      description: data.description || "",
      content: content.toLowerCase().slice(0, 8000), // truncate for size
    })

    // Section entries
    const headings = extractHeadings(content)
    for (const h of headings) {
      index.push({
        type: "section",
        slug: realSlug,
        title: data.title || slug,
        section: h.text,
        sectionAnchor: h.anchor,
        excerpt: getHeadingExcerpt(content, h.text),
        level: h.level,
      })
    }
  }

  fs.writeFileSync(outFile, JSON.stringify(index), "utf8")
  console.log(`✓ Generated search index: ${index.length} entries → ${outFile}`)
}

buildIndex()
