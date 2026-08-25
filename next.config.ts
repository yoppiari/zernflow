import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**" },
    ],
  },
  async rewrites() {
    return [
      {
        source: "/supabase-api/:path*",
        destination: process.env.INTERNAL_SUPABASE_URL
          ? `${process.env.INTERNAL_SUPABASE_URL}/:path*`
          : "http://kong:8000/:path*",
      },
    ];
  },
};

export default nextConfig;
