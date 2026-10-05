// 전체 슬로프 주소 → 좌표 일괄 재보정 (네이버 Geocoding). 관리자 전용.
// body: { apply?: boolean }  (apply=false 면 dry-run: DB 미변경, 제안만 반환)
// 필요한 시크릿: NAVER_GEOCODE_KEY_ID, NAVER_GEOCODE_KEY
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

async function geocode(
  address: string,
  keyId: string,
  key: string,
): Promise<{ lat: number; lng: number } | null> {
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
  if (!res.ok) return null;
  const body = await res.json();
  const first = body?.addresses?.[0];
  if (!first) return null;
  return { lat: Number(first.y), lng: Number(first.x) };
}

// 두 좌표간 거리(m) - 이동량 확인용
function distMeters(a: number, b: number, c: number, d: number): number {
  const R = 6371000;
  const dLat = ((c - a) * Math.PI) / 180;
  const dLng = ((d - b) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a * Math.PI) / 180) *
      Math.cos((c * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s)));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 관리자 확인
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

    const keyId = Deno.env.get("NAVER_GEOCODE_KEY_ID");
    const key = Deno.env.get("NAVER_GEOCODE_KEY");
    if (!keyId || !key) return json({ error: "geocode_key_missing" }, 500);

    const { apply = false } = await req.json().catch(() => ({}));

    const { data: slopes } = await admin
      .from("slopes")
      .select("id, name, address, lat, lng");

    const changes: unknown[] = [];
    const failed: unknown[] = [];
    let updated = 0;

    for (const s of slopes ?? []) {
      const g = await geocode(s.address, keyId, key);
      if (!g) {
        failed.push({ id: s.id, name: s.name, address: s.address });
        continue;
      }
      const moved =
        s.lat != null && s.lng != null
          ? distMeters(s.lat, s.lng, g.lat, g.lng)
          : null;
      changes.push({
        id: s.id,
        name: s.name,
        oldLat: s.lat,
        oldLng: s.lng,
        newLat: g.lat,
        newLng: g.lng,
        movedMeters: moved,
      });
      if (apply) {
        await admin
          .from("slopes")
          .update({ lat: g.lat, lng: g.lng })
          .eq("id", s.id);
        updated++;
      }
      // 네이버 rate limit 여유
      await new Promise((r) => setTimeout(r, 120));
    }

    return json({
      apply,
      total: slopes?.length ?? 0,
      geocoded: changes.length,
      updated,
      failedCount: failed.length,
      failed,
      // 이동량 큰 순 정렬 (검토용)
      changes: changes.sort(
        (a: any, b: any) => (b.movedMeters ?? 0) - (a.movedMeters ?? 0),
      ),
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
