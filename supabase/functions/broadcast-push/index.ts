// 전체 device_tokens 로 공지 FCM 발송 (관리자 전용 - 서비스 롤 키로만 호출 가능). 무효 토큰 정리.
import { createClient } from "jsr:@supabase/supabase-js@2";

interface Payload {
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

// 서비스계정으로 OAuth 액세스 토큰 발급 (FCM HTTP v1 인증) - send-push 와 동일
async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc({ alg: "RS256", typ: "JWT" })}.${enc(claim)}`;

  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  return (await res.json()).access_token;
}

Deno.serve(async (req) => {
  try {
    // 관리자만: 서비스 롤 키로만 호출 가능 (anon 키로는 차단)
    const auth = req.headers.get("Authorization")?.replace("Bearer ", "");
    if (auth !== Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")) {
      return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
    }

    const { title, body, data }: Payload = await req.json();
    if (!title || !body) {
      return new Response(JSON.stringify({ error: "title/body required" }), { status: 400 });
    }

    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: rows } = await supabase.from("device_tokens").select("token");
    const tokens = [...new Set((rows ?? []).map((r) => r.token).filter(Boolean))];
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, failed: 0, total: 0 }), { status: 200 });
    }

    const accessToken = await getAccessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const strData: Record<string, string> = {};
    for (const [k, v] of Object.entries(data ?? {})) strData[k] = String(v ?? "");

    let sent = 0;
    let failed = 0;
    for (const token of tokens) {
      const r = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: strData,
          },
        }),
      });
      if (r.ok) {
        sent++;
      } else {
        failed++;
        if (r.status === 404 || r.status === 400) {
          await supabase.from("device_tokens").delete().eq("token", token); // 무효 토큰 정리
        }
      }
    }

    return new Response(JSON.stringify({ sent, failed, total: tokens.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
