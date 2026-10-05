// 주소 → 좌표 지오코딩 (네이버 Geocoding). 관리자만 호출 가능.
// 필요한 시크릿:
//   NAVER_GEOCODE_KEY_ID  (NCP Maps Geocoding API - Key ID)
//   NAVER_GEOCODE_KEY     (NCP Maps Geocoding API - Key Secret)
// 설정: supabase secrets set NAVER_GEOCODE_KEY_ID=... NAVER_GEOCODE_KEY=...
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 1) 호출자 인증 + 관리자 확인 (지오코딩 키 남용 방지)
    const authHeader = req.headers.get("Authorization") ?? "";
    const authed = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
    } = await authed.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: profile } = await admin
      .from("users")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    if (!profile || profile.role !== "admin") {
      return json({ error: "forbidden" }, 403);
    }

    // 2) 요청 파싱
    const { address } = await req.json().catch(() => ({}));
    if (!address || typeof address !== "string") {
      return json({ error: "address required" }, 400);
    }

    // 3) 네이버 지오코딩 호출
    const keyId = Deno.env.get("NAVER_GEOCODE_KEY_ID");
    const key = Deno.env.get("NAVER_GEOCODE_KEY");
    if (!keyId || !key) {
      return json({ error: "geocode_key_missing" }, 500);
    }
    const url =
      "https://maps.apigw.ntruss.com/map-geocode/v2/geocode?query=" +
      encodeURIComponent(address);
    const res = await fetch(url, {
      headers: {
        "X-NCP-APIGW-API-KEY-ID": keyId,
        "X-NCP-APIGW-API-KEY": key,
        Accept: "application/json",
      },
    });
    if (!res.ok) {
      const detail = await res.text();
      return json({ error: "geocode_failed", status: res.status, detail }, 502);
    }
    const body = await res.json();
    const first = body?.addresses?.[0];
    if (!first) {
      return json({ lat: null, lng: null, matched: 0 });
    }
    // 네이버: x=경도(lng), y=위도(lat)
    return json({
      lat: Number(first.y),
      lng: Number(first.x),
      matched: body.addresses.length,
      roadAddress: first.roadAddress ?? null,
      jibunAddress: first.jibunAddress ?? null,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
