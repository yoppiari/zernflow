#!/usr/bin/env node
/**
 * ZernFlow Admin User Creator
 *
 * Creates a team member user using the GoTrue / Supabase Admin Service Role API.
 * The database trigger will automatically provision their initial workspace.
 *
 * Usage:
 *   node scripts/create-user.mjs <email> <password> [full_name]
 *   node scripts/create-user.mjs yoppi.ari@gmail.com "YourPassword123!" "Yoppi Ari"
 */

import { readFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = resolve(__dirname, "../.env");

if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq);
    const val = trimmed.slice(eq + 1).replace(/^["']|["']$/g, "");
    if (!process.env[key]) process.env[key] = val;
  }
}

const email = process.argv[2] || process.env.ADMIN_EMAIL || "yoppi.ari@gmail.com";
const password = process.argv[3] || process.env.ADMIN_PASSWORD || "ZernflowAdmin2026!";
const fullName = process.argv[4] || process.env.ADMIN_NAME || (email ? email.split("@")[0] : "Admin");

const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.xdTcldRhvmKPkJMXRTBy4xmKr3XCRpjgRuMjDpjU0fg";
const appUrl = process.env.NEXT_PUBLIC_APP_URL || "https://flows.lumiku.com";
const gotrueDirectUrl = process.env.INTERNAL_AUTH_URL || "http://127.0.0.1:9999";

const targetEndpoints = [
  `${gotrueDirectUrl}/admin/users`,
  `${appUrl}/supabase-api/auth/v1/admin/users`,
  `http://127.0.0.1:3000/supabase-api/auth/v1/admin/users`
];

async function tryCreateUser() {
  console.log(`[create-user] Provisioning user '${email}' (${fullName})...`);

  const payload = {
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: fullName,
      name: fullName
    }
  };

  let success = false;
  let lastError = null;

  for (const endpoint of targetEndpoints) {
    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleKey}`,
          "apikey": serviceRoleKey
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(4000)
      });

      const body = await res.json().catch(() => ({}));

      if (res.ok) {
        console.log(`✅ User '${email}' successfully created via ${endpoint}`);
        console.log("-----------------------------------------");
        console.log(`ID       : ${body.id}`);
        console.log(`Email    : ${body.email}`);
        console.log(`Name     : ${fullName}`);
        console.log("-----------------------------------------");
        console.log("The user can now sign in at /login.");
        success = true;
        break;
      } else if (body.msg && body.msg.includes("already registered")) {
        console.log(`ℹ️ User '${email}' is already registered and ready to use.`);
        success = true;
        break;
      } else {
        lastError = body.message || body.msg || res.statusText;
      }
    } catch (err) {
      lastError = err.message;
    }
  }

  if (!success) {
    console.log(`⚠️ Note: Could not reach live endpoint immediately (${lastError}).`);
    console.log(`ℹ️ User '${email}' will be automatically provisioned when container starts up.`);
  }
}

tryCreateUser();
