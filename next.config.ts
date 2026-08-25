import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  typescript: {
    ignoreBuildErrors: true,
  },
  eslint: {
    ignoreDuringBuilds: true,
  },
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**" },
    ],
  },
  async rewrites() {
    const authUrl = process.env.INTERNAL_AUTH_URL || "http://127.0.0.1:9999";
    const restUrl = process.env.INTERNAL_REST_URL || "http://127.0.0.1:3001";

    return [
      {
        source: "/supabase-api/rest/v1/:path*",
        destination: `${restUrl}/:path*`,
      },
    ];
  },
};

export default nextConfig;
