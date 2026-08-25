#!/usr/bin/env node
/**
 * ZernFlow Admin User Creator
 *
 * Creates a team member user using the Supabase Admin / Service Role API.
 * The on_auth_user_created database trigger will automatically provision their workspace.
 *
 * Usage:
 *   node scripts/create-user.mjs <email> <password> [full_name]
 *   node scripts/create-user.mjs tim@lumiku.com Rahasia123! "Nama Anggota"
 */

import { createClient } from "@supabase/supabase-js";
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

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://flows.lumiku.com/supabase-api";
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.xdTcldRhvmKPkJMXRTBy4xmKr3XCRpjgRuMjDpjU0fg";

const email = process.argv[2];
const password = process.argv[3];
const fullName = process.argv[4] || email ? email.split("@")[0] : "Team Member";

if (!email || !password) {
  console.log("Usage: node scripts/create-user.mjs <email> <password> [full_name]");
  console.log("Example: node scripts/create-user.mjs admin@lumiku.com Password123! 'Admin Lumiku'");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function main() {
  console.log(`Creating user '${email}' on ${supabaseUrl}...`);

  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: fullName,
      name: fullName
    }
  });

  if (error) {
    console.error("❌ Failed to create user:", error.message);
    process.exit(1);
  }

  console.log("✅ User created successfully!");
  console.log("-----------------------------------------");
  console.log(`ID       : ${data.user.id}`);
  console.log(`Email    : ${data.user.email}`);
  console.log(`Name     : ${fullName}`);
  console.log(`Confirmed: ${data.user.email_confirmed_at ? "Yes" : "No"}`);
  console.log("-----------------------------------------");
  console.log("The user can now sign in at /login.");
}

main().catch(err => {
  console.error("Unexpected error:", err);
  process.exit(1);
});
