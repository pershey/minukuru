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
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: metadata, error: metadataError } = await supabase
      .rpc("get_published_manifest_metadata");

    if (metadataError) {
      throw metadataError;
    }

    const published = metadata?.[0];
    if (!published) {
      return Response.json(
        { error: "No published manifest found." },
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
      },
    });
  } catch (error) {
    return Response.json(
      { error: "Failed to load manifest.", details: `${error}` },
      { status: 500, headers: corsHeaders }
    );
  }
});
