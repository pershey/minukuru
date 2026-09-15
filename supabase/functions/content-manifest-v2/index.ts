import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  EntitlementConfigurationError,
  EntitlementServiceError,
  EntitlementVerificationError,
  verifyPremiumTransaction,
} from "./entitlement.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-minukuru-storekit-jws",
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

    if (channel !== "free") {
      const transactionJWS = request.headers.get("x-minukuru-storekit-jws") ?? "";
      await verifyPremiumTransaction(transactionJWS);
    }

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
        { status: 404, headers: corsHeaders },
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
        "Cache-Control": channel === "free" ? "public, max-age=300" : "private, no-store",
        "X-Minukuru-Content-Version": published.content_version,
        "X-Minukuru-Distribution-Channel": channel,
      },
    });
  } catch (error) {
    if (error instanceof EntitlementVerificationError) {
      return Response.json(
        { error: "A verified premium purchase is required." },
        { status: 401, headers: { ...corsHeaders, "Cache-Control": "no-store" } },
      );
    }
    if (error instanceof EntitlementConfigurationError || error instanceof EntitlementServiceError) {
      console.error("content-manifest-v2 entitlement verification is temporarily unavailable");
      return Response.json(
        { error: "Premium content is temporarily unavailable." },
        { status: 503, headers: { ...corsHeaders, "Cache-Control": "no-store" } },
      );
    }
    console.error("content-manifest-v2 failed", error);
    return Response.json(
      { error: "Failed to load manifest." },
      { status: 500, headers: corsHeaders },
    );
  }
});
