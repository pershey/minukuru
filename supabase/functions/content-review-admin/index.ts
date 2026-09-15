import { createClient } from "jsr:@supabase/supabase-js@2";

function splitList(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function responseHeaders(origin: string | null, allowedOrigins: string[]): HeadersInit {
  const allowedOrigin = origin && allowedOrigins.includes(origin) ? origin : allowedOrigins[0];
  return {
    "Access-Control-Allow-Origin": allowedOrigin ?? "https://pershey.github.io",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Cache-Control": "private, no-store",
    "Vary": "Origin",
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  const allowedOrigins = splitList(Deno.env.get("CONTENT_REVIEW_ALLOWED_ORIGINS"));
  const headers = responseHeaders(origin, allowedOrigins);

  if (origin && !allowedOrigins.includes(origin)) {
    return Response.json({ error: "Origin is not allowed." }, { status: 403, headers });
  }
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers });
  }
  if (request.method !== "GET") {
    return Response.json({ error: "Method not allowed." }, { status: 405, headers });
  }

  const allowedEmails = splitList(Deno.env.get("CONTENT_REVIEW_ADMIN_EMAILS"))
    .map((email) => email.toLowerCase());
  if (allowedOrigins.length === 0 || allowedEmails.length === 0) {
    console.error("content-review-admin allowlist is not configured");
    return Response.json({ error: "Admin review is not configured." }, { status: 503, headers });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const accessToken = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  if (!accessToken) {
    return Response.json({ error: "Authentication is required." }, { status: 401, headers });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(accessToken);
  const userEmail = userData.user?.email?.toLowerCase();
  if (userError || !userEmail) {
    return Response.json({ error: "Session is invalid or expired." }, { status: 401, headers });
  }
  if (!allowedEmails.includes(userEmail)) {
    console.warn("content-review-admin denied an authenticated user", userData.user?.id);
    return Response.json({ error: "This account is not an approved reviewer." }, { status: 403, headers });
  }

  const url = new URL(request.url);
  const batchLabel = url.searchParams.get("batchLabel")?.trim();
  if (!batchLabel || batchLabel.length > 120) {
    return Response.json({ error: "A valid batchLabel is required." }, { status: 400, headers });
  }

  const { data, error } = await supabase.rpc("get_content_review_batch", {
    target_batch_label: batchLabel,
  });
  if (error) {
    console.error("content-review-admin failed to load a batch", error.code);
    return Response.json({ error: "Failed to load review data." }, { status: 500, headers });
  }

  return Response.json(data, { status: 200, headers });
});
