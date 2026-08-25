import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const INTERNAL_AUTH_URL = process.env.INTERNAL_AUTH_URL || "http://127.0.0.1:9999";

async function proxy(request: NextRequest, { params }: { params: Promise<{ path?: string[] }> }) {
  try {
    const resolvedParams = await params;
    const pathStr = resolvedParams.path ? resolvedParams.path.join("/") : "";
    const search = request.nextUrl.search;
    const targetUrl = `${INTERNAL_AUTH_URL}/${pathStr}${search}`;

    const headers = new Headers(request.headers);
    headers.delete("host");

    const body = request.method !== "GET" && request.method !== "HEAD" ? await request.arrayBuffer() : undefined;

    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body,
      redirect: "manual",
    });

    const resHeaders = new Headers(response.headers);
    resHeaders.delete("content-encoding");

    return new NextResponse(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: resHeaders,
    });
  } catch (error: any) {
    console.error("[supabase-auth-proxy error]:", error);
    return NextResponse.json(
      { error: error.message || "Failed to proxy auth request", details: String(error) },
      { status: 502 }
    );
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
export const OPTIONS = proxy;
export const HEAD = proxy;
