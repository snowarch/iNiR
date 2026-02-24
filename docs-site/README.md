# iNiR Documentation

Modern documentation site for iNiR built with Next.js 15, Velite, and Neobrutalism design.

## Tech Stack

- **Next.js 15** - React framework with App Router
- **Velite** - Content layer for MDX processing
- **Tailwind CSS 4** - Utility-first CSS
- **Neobrutalism Design** - Bold, high-contrast aesthetic
- **TypeScript** - Type safety

## Development

Install dependencies:

```bash
npm install
```

Start development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## Build

Build for production:

```bash
npm run build
```

Start production server:

```bash
npm start
```

## Structure

```
docs-site/
├── src/
│   ├── app/              # Next.js App Router pages
│   │   ├── layout.tsx    # Root layout
│   │   ├── page.tsx      # Home page
│   │   └── docs/         # Documentation pages
│   ├── components/       # React components
│   │   ├── sidebar.tsx   # Navigation sidebar
│   │   └── mdx-components.tsx  # MDX component overrides
│   ├── lib/              # Utilities
│   ├── markdown/         # MDX content
│   │   └── docs/         # Documentation MDX files
│   └── styling/          # CSS files
├── public/               # Static assets
├── velite.config.ts      # Velite configuration
├── next.config.mjs       # Next.js configuration
└── package.json
```

## Adding Documentation

1. Create a new `.mdx` file in `src/markdown/docs/`
2. Add frontmatter:
   ```mdx
   ---
   title: Page Title
   description: Page description
   ---
   ```
3. Write content using Markdown
4. Update navigation in `src/components/sidebar.tsx`

## Deployment

### GitHub Pages (automatic)

Push to `main` branch triggers automatic deployment via GitHub Actions.

1. Go to repo **Settings → Pages**
2. Set Source to **GitHub Actions**
3. Push changes to `main`

Site will be available at `https://snowarch.github.io/inir/`

### Custom domain (optional)

1. Create `public/CNAME` with your domain (e.g., `inir.dev`)
2. Configure DNS at your registrar:
   - **CNAME**: `inir.dev` → `snowarch.github.io`
3. In GitHub repo Settings → Pages, add custom domain

### Local preview

```bash
npm run build
npx serve out
```

## License

GPL-3.0 — same as iNiR project.
