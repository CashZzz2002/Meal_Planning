import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  allowedDevOrigins: ["127.0.0.1", "localhost"],
  cacheComponents: true,
  partialPrefetching: true,
};

export default nextConfig;
