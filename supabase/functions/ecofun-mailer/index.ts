// ecofun-mailer — sends EcoFun's app emails (welcome, password changed, streak, goodbye) through Gmail.
//
// Postgres queues emails in public.email_outbox and pings this function (pg_net). The function claims
// pending emails, renders them, sends them over SMTP and reports back. Failed sends are retried by cron.
//
// Secrets (Supabase → Edge Functions → Secrets, or `supabase secrets set`):
//   SMTP_USER        Gmail address, e.g. you@gmail.com
//   SMTP_PASS        Gmail app password (16 letters, spaces optional)
//   MAILER_SECRET    shared secret; must equal the Vault secret `mailer_secret`
//   ECOFUN_DB_KEY    the project's publishable (anon) key, used to call the mailer RPCs
//   MAIL_FROM_NAME   optional sender name (default "EcoFun")
//
// Deploy with JWT verification off (the shared secret is the authentication):
//   supabase functions deploy ecofun-mailer --no-verify-jwt
//
// Preview: POST {"preview_to": "you@example.com", "lang": "rw"} with the x-mailer-secret header sends one
// sample of every template to that address.

import nodemailer from "npm:nodemailer@6.9.16";
import { EMAIL_KINDS, renderEmail } from "./templates.ts";

const SMTP_USER = (Deno.env.get("SMTP_USER") ?? "").trim();
const SMTP_PASS = (Deno.env.get("SMTP_PASS") ?? "").replace(/\s+/g, "");
const MAILER_SECRET = Deno.env.get("MAILER_SECRET") ?? "";
const DB_KEY = Deno.env.get("ECOFUN_DB_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const FROM_NAME = Deno.env.get("MAIL_FROM_NAME") ?? "EcoFun";

// Gmail on port 465 (implicit TLS). Edge Functions block ports 25 and 587.
const transport = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 465,
  secure: true,
  auth: { user: SMTP_USER, pass: SMTP_PASS },
  connectionTimeout: 15_000,
  greetingTimeout: 15_000,
  socketTimeout: 30_000,
});

interface OutboxRow {
  id: number;
  to_email: string;
  kind: string;
  data: Record<string, unknown>;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function sameSecret(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: DB_KEY, Authorization: `Bearer ${DB_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${fn} failed (${res.status}): ${text.slice(0, 300)}`);
  return (text ? JSON.parse(text) : null) as T;
}

async function send(to: string, kind: string, data: Record<string, unknown>) {
  const mail = renderEmail(kind, data);
  await transport.sendMail({
    from: { name: FROM_NAME, address: SMTP_USER },
    replyTo: SMTP_USER,
    to,
    subject: mail.subject,
    html: mail.html,
    text: mail.text,
    headers: { "X-EcoFun-Email": kind },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  if (!sameSecret(req.headers.get("x-mailer-secret") ?? "", MAILER_SECRET)) return json({ error: "unauthorized" }, 401);
  if (!SMTP_USER || !SMTP_PASS) return json({ error: "SMTP_USER / SMTP_PASS are not set" }, 500);

  const body = await req.json().catch(() => ({})) as { preview_to?: string; lang?: string };

  // Preview mode: one sample of every template.
  if (body.preview_to) {
    const sample = {
      name: "Aline Uwase",
      lang: body.lang === "rw" ? "rw" : "en",
      email: body.preview_to,
      at: new Date().toISOString(),
      streak: 7,
      points: 145,
      title: body.lang === "rw" ? "Umuganda wo kuwa Gatandatu" : "Umuganda clean-up this Saturday",
      body: body.lang === "rw"
        ? "Twifatanye kuri uyu wa Gatandatu saa tatu za mu gitondo.\nZana uturindantoki n'amazi."
        : "Join us this Saturday at 9 am.\nBring gloves and water.",
    };
    const results: Record<string, string> = {};
    for (const kind of EMAIL_KINDS) {
      try {
        await send(body.preview_to, kind, sample);
        results[kind] = "sent";
      } catch (e) {
        results[kind] = `failed: ${e instanceof Error ? e.message : String(e)}`;
      }
    }
    return json({ preview: results });
  }

  // Normal mode: drain the outbox.
  if (!DB_KEY || !SUPABASE_URL) return json({ error: "ECOFUN_DB_KEY is not set" }, 500);
  let sent = 0;
  let failed = 0;
  for (let round = 0; round < 5; round++) {
    const jobs = await rpc<OutboxRow[]>("mailer_claim", { p_secret: MAILER_SECRET, p_limit: 20 });
    if (!jobs?.length) break;
    for (const job of jobs) {
      try {
        await send(job.to_email, job.kind, job.data ?? {});
        await rpc("mailer_done", { p_secret: MAILER_SECRET, p_id: job.id, p_error: null });
        sent++;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(`email ${job.id} (${job.kind}) failed: ${msg}`);
        await rpc("mailer_done", { p_secret: MAILER_SECRET, p_id: job.id, p_error: msg }).catch(() => {});
        failed++;
      }
    }
    if (jobs.length < 20) break;
  }
  return json({ sent, failed });
});
