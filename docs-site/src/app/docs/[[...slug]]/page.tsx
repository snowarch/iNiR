import "@/styling/code.css"
import { notFound } from "next/navigation"
import { isValidElement } from "react"
import type { ComponentPropsWithoutRef, ReactElement, ReactNode } from "react"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"
import { Sidebar } from "@/components/sidebar"
import { TableOfContents } from "@/components/table-of-contents"
import { Breadcrumbs } from "@/components/breadcrumbs"
import { DocNav } from "@/components/doc-nav"
import { Footer } from "@/components/footer"
import { BackToTop } from "@/components/back-to-top"
import { CopyButton } from "@/components/copy-button"
import { Search } from "@/components/search"
import { ThemeToggle } from "@/components/theme-toggle"
import { getAllDocs, getDocBySlug, getDocNavigation } from "@/lib/docs"

interface DocPageProps {
  params: Promise<{
    slug: string[]
  }>
}

export async function generateMetadata(props: DocPageProps) {
  const params = await props.params
  const slug = params.slug?.join("/") || ""
  const doc = getDocBySlug(slug)

  if (doc == null) return {}
  return { title: doc.title, description: doc.description }
}

export async function generateStaticParams(): Promise<{ slug: string[] }[]> {
  const docs = getAllDocs()
  return docs.map((doc) => ({
    slug: doc.slug ? doc.slug.split("/") : [],
  }))
}

type HeadingProps = ComponentPropsWithoutRef<"h1">
type ParagraphProps = ComponentPropsWithoutRef<"p">
type AnchorProps = ComponentPropsWithoutRef<"a">
type ListProps = ComponentPropsWithoutRef<"ul">
type ListItemProps = ComponentPropsWithoutRef<"li">
type CodeProps = ComponentPropsWithoutRef<"code">
type PreProps = ComponentPropsWithoutRef<"pre">
type BlockquoteProps = ComponentPropsWithoutRef<"blockquote">
type TableProps = ComponentPropsWithoutRef<"table">
type TableSectionProps = ComponentPropsWithoutRef<"thead">
type TableRowProps = ComponentPropsWithoutRef<"tr">
type TableHeaderProps = ComponentPropsWithoutRef<"th">
type TableCellProps = ComponentPropsWithoutRef<"td">
type StrongProps = ComponentPropsWithoutRef<"strong">
type EmProps = ComponentPropsWithoutRef<"em">
type ReactElementWithChildren = ReactElement<{ children?: ReactNode }>

const components = {
  h1: (props: HeadingProps) => (
    <h1
      id={props.children?.toString().toLowerCase().replace(/\s+/g, "-").replace(/[^\w-]/g, "")}
      className="mb-8 mt-16 border-b-2 border-main pb-4 font-mono text-2xl font-bold text-foreground"
      {...props}
    />
  ),
  h2: (props: HeadingProps) => (
    <h2
      id={props.children?.toString().toLowerCase().replace(/\s+/g, "-").replace(/[^\w-]/g, "")}
      className="mb-4 mt-12 nb-card-header bg-surface"
      {...props}
    />
  ),
  h3: (props: HeadingProps) => (
    <h3
      id={props.children?.toString().toLowerCase().replace(/\s+/g, "-").replace(/[^\w-]/g, "")}
      className="mb-3 mt-8 font-mono text-sm font-bold text-main flex items-center gap-2"
      {...props}
    >
      <span className="text-main">#</span>
      {props.children}
    </h3>
  ),
  h4: (props: HeadingProps) => (
    <h4 className="mb-2 mt-6 font-mono text-xs font-bold uppercase tracking-wide text-text-muted" {...props} />
  ),
  p: (props: ParagraphProps) => (
    <p className="mb-5 font-mono text-[13px] leading-[1.8] text-foreground/90" {...props} />
  ),
  a: (props: AnchorProps) => (
    <a
      className="font-mono text-[13px] font-medium text-main underline decoration-dotted underline-offset-4 hover:decoration-solid"
      {...props}
    />
  ),
  ul: (props: ListProps) => (
    <ul className="mb-5 nb-list" {...props} />
  ),
  ol: (props: ListProps) => (
    <ol className="mb-5 ml-5 list-decimal space-y-2 font-mono text-[13px]" {...props} />
  ),
  li: (props: ListItemProps) => (
    <li className="leading-[1.8] text-foreground/90" {...props} />
  ),
  code: (props: CodeProps) => {
    const { className, children, ...rest } = props
    const isBlock = className?.includes("language-")
    if (!isBlock && !className) {
      return (
        <code
          className="nb-kbd text-xs"
          {...rest}
        >
          {children}
        </code>
      )
    }
    return (
      <code
        className="block overflow-x-auto font-mono text-[13px] leading-relaxed"
        {...rest}
      >
        {children}
      </code>
    )
  },
  pre: (props: PreProps) => {
    const getTextContent = (node: ReactNode): string => {
      if (typeof node === "string" || typeof node === "number") return String(node)
      if (Array.isArray(node)) return node.map(getTextContent).join("")
      if (isValidElement(node)) {
        const el = node as ReactElementWithChildren
        return getTextContent(el.props.children ?? null)
      }
      return ""
    }
    const text = getTextContent(props.children ?? null)
    return (
      <div className="group relative mb-6 nb-code-block">
          <div className="nb-code-header">
            <span className="text-main">~</span>
            <span>code</span>
          </div>
          <pre className="nb-code-body" {...props} />
          <CopyButton text={text} className="absolute top-2 right-2" />
        </div>
    )
  },
  blockquote: (props: BlockquoteProps) => (
    <blockquote
      className="nb-blockquote mb-6"
      {...props}
    />
  ),
  table: (props: TableProps) => (
    <div className="mb-6 nb-terminal">
      <div className="nb-terminal-header">
        <span className="text-main">~</span>
        <span>table</span>
      </div>
      <div className="nb-terminal-body overflow-x-auto">
        <table className="w-full border-collapse font-mono text-[13px] nb-table" {...props} />
      </div>
    </div>
  ),
  thead: (props: TableSectionProps) => (
    <thead className="border-b-2 border-main bg-surface" {...props} />
  ),
  tbody: (props: TableSectionProps) => (
    <tbody {...props} />
  ),
  tr: (props: TableRowProps) => (
    <tr className="border-b border-border transition-colors hover:bg-surface/30" {...props} />
  ),
  th: (props: TableHeaderProps) => (
    <th className="px-4 py-3 text-left font-bold text-main text-xs uppercase tracking-wider" {...props} />
  ),
  td: (props: TableCellProps) => (
    <td className="px-4 py-3 text-foreground/90" {...props} />
  ),
  hr: () => (
    <hr className="nb-divider" />
  ),
  strong: (props: StrongProps) => (
    <strong className="font-bold text-foreground" {...props} />
  ),
  em: (props: EmProps) => (
    <em className="text-secondary" {...props} />
  ),
}

export default async function DocPage(props: DocPageProps) {
  const params = await props.params
  const slug = params.slug?.join("/") || ""
  const doc = getDocBySlug(slug)

  if (doc == null) notFound()

  const { description, title, content } = doc
  const navigation = getDocNavigation(slug)

  const contentWithoutFirstH1 = content.replace(/^#\s+.+$/m, "")

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <Search />
      <div className="flex flex-1">
        <Sidebar />
        <main className="flex-1 lg:ml-64">
          <div className="xl:mr-60">
            <div className="mx-auto max-w-[840px] px-6 py-12 lg:px-10">
              <div className="flex items-center justify-between gap-4 flex-wrap">
                <Breadcrumbs />
                <ThemeToggle />
              </div>
              
              <article className="max-w-none">
                {/* Page Header */}
                <div className="mb-10 nb-box-primary p-6">
                  <h1 className="font-mono text-2xl font-bold tracking-tight">{title}</h1>
                  {description && (
                    <p className="mt-2 font-mono text-sm opacity-90">{description}</p>
                  )}
                </div>
                
                <ReactMarkdown
                  remarkPlugins={[remarkGfm]}
                  components={components}
                >
                  {contentWithoutFirstH1}
                </ReactMarkdown>
                
                <DocNav prev={navigation.prev} next={navigation.next} />
              </article>
            </div>
          </div>
          
          <TableOfContents />
        </main>
      </div>
      
      <Footer />
      <BackToTop />
    </div>
  )
}
