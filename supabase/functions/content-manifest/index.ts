import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(request.url);
    const requestedChannel = url.searchParams.get("channel");
    const channel = requestedChannel === "free" || requestedChannel === "premium" || requestedChannel === "full"
      ? requestedChannel
      : "full";

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const metadataCall = channel === "full"
      ? supabase.rpc("get_published_manifest_metadata")
      : supabase.rpc("get_published_manifest_metadata", { target_channel: channel });
    const { data: metadata, error: metadataError } = await metadataCall;

    if (metadataError) {
      throw metadataError;
    }

    const published = metadata?.[0];
    if (!published) {
      return Response.json(
        { error: `No published manifest found for channel '${channel}'.` },
        { status: 404, headers: corsHeaders }
      );
    }

    const { data: fileData, error: fileError } = await supabase.storage
      .from(published.storage_bucket)
      .download(published.storage_path);

    if (fileError) {
      throw fileError;
    }

    const body = await fileData.text();

    return new Response(body, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=300",
        "X-Minukuru-Content-Version": published.content_version,
        "X-Minukuru-Distribution-Channel": channel,
      },
    });
  } catch (error) {
    console.error("content-manifest failed", error);
    return Response.json(
      { error: "Failed to load manifest." },
      { status: 500, headers: corsHeaders }
    );
  }
});
