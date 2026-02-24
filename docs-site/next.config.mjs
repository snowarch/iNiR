/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
  pageExtensions: ["js", "jsx", "ts", "tsx", "md", "mdx"],
  experimental: {
    mdxRs: false,
  },
  // basePath is set via env var in CI for GitHub Pages subdirectory deploys
  // For custom domain (inir.dev), leave empty
  ...(process.env.NEXT_PUBLIC_BASE_PATH && {
    basePath: process.env.NEXT_PUBLIC_BASE_PATH,
    assetPrefix: process.env.NEXT_PUBLIC_BASE_PATH,
  }),
}

export default nextConfig
