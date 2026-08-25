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
    const authUrl = process.env.INTERNAL_AUTH_URL || "http://zernflow-auth:9999";
    const restUrl = process.env.INTERNAL_REST_URL || "http://zernflow-rest:3000";

    return [
      {
        source: "/supabase-api/auth/v1/:path*",
        destination: `${authUrl}/:path*`,
      },
      {
        source: "/supabase-api/rest/v1/:path*",
        destination: `${restUrl}/:path*`,
      },
    ];
  },
};

export default nextConfig;
