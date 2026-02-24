import fs from "fs"
import path from "path"
import matter from "gray-matter"

const docsDirectory = path.join(process.cwd(), "src/content/docs")

// Define the order of documentation pages
const docsOrder = [
  "index",
  "installation",
  "requirements",
  "first-steps",
  "quick-reference",
  "configuration",
  "keybindings",
  "theming",
  "panel-families",
  "features",
  "modules",
  "config-options",
  "ipc",
  "workflows",
  "architecture",
  "contributing",
  "troubleshooting",
  "faq",
  "limitations",
  "comparison",
  "changelog",
]

export interface DocMeta {
  slug: string
  title: string
  description?: string
}

export interface Doc extends DocMeta {
  content: string
}

export interface DocNavigation {
  prev?: { title: string; href: string }
  next?: { title: string; href: string }
}

export function getAllDocs(): DocMeta[] {
  const fileNames = fs.readdirSync(docsDirectory)
  const allDocs = fileNames
    .filter((fileName) => fileName.endsWith(".mdx"))
    .map((fileName) => {
      const slug = fileName.replace(/\.mdx$/, "")
      const fullPath = path.join(docsDirectory, fileName)
      const fileContents = fs.readFileSync(fullPath, "utf8")
      const { data } = matter(fileContents)

      return {
        slug: slug === "index" ? "" : slug,
        title: data.title || slug,
        description: data.description,
      }
    })

  return allDocs
}

export function getAllDocsWithContent(): Doc[] {
  const fileNames = fs.readdirSync(docsDirectory)
  return fileNames
    .filter((fileName) => fileName.endsWith(".mdx"))
    .map((fileName) => {
      const slug = fileName.replace(/\.mdx$/, "")
      const fullPath = path.join(docsDirectory, fileName)
      const fileContents = fs.readFileSync(fullPath, "utf8")
      const { data, content } = matter(fileContents)

      return {
        slug: slug === "index" ? "" : slug,
        title: data.title || slug,
        description: data.description,
        content,
      }
    })
}

export function getDocBySlug(slug: string): Doc | null {
  try {
    const realSlug = slug || "index"
    const fullPath = path.join(docsDirectory, `${realSlug}.mdx`)
    const fileContents = fs.readFileSync(fullPath, "utf8")
    const { data, content } = matter(fileContents)

    return {
      slug: slug,
      title: data.title || realSlug,
      description: data.description,
      content,
    }
  } catch {
    return null
  }
}

export function getDocNavigation(slug: string): DocNavigation {
  const realSlug = slug || "index"
  const currentIndex = docsOrder.indexOf(realSlug)

  if (currentIndex === -1) return {}

  const navigation: DocNavigation = {}

  if (currentIndex > 0) {
    const prevSlug = docsOrder[currentIndex - 1]
    const prevDoc = getDocBySlug(prevSlug === "index" ? "" : prevSlug)
    if (prevDoc) {
      navigation.prev = {
        title: prevDoc.title,
        href: prevSlug === "index" ? "/docs" : `/docs/${prevSlug}`,
      }
    }
  }

  if (currentIndex < docsOrder.length - 1) {
    const nextSlug = docsOrder[currentIndex + 1]
    const nextDoc = getDocBySlug(nextSlug === "index" ? "" : nextSlug)
    if (nextDoc) {
      navigation.next = {
        title: nextDoc.title,
        href: nextSlug === "index" ? "/docs" : `/docs/${nextSlug}`,
      }
    }
  }

  return navigation
}
