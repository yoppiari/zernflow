import { NextResponse } from "next/server";
import fs from "fs";
import { execSync } from "child_process";

export const dynamic = "force-dynamic";

export async function GET() {
  const result: Record<string, any> = {};

  try {
    const logs = ["/data/logs/gotrue.log", "/data/logs/gotrue-migrate.log", "/data/logs/postgres.log"];
    for (const logPath of logs) {
      if (fs.existsSync(logPath)) {
        result[logPath] = fs.readFileSync(logPath, "utf-8").slice(-1500);
      } else {
        result[logPath] = "File not found";
      }
    }

    try {
      const psqlTables = execSync("su - postgres -c \"psql -d postgres -c '\\dt auth.*'\"", { encoding: "utf-8" });
      result["auth_tables"] = psqlTables;
    } catch (e: any) {
      result["psql_error"] = e.message;
    }

    try {
      const health = execSync("curl -s http://127.0.0.1:9999/health", { encoding: "utf-8" });
      result["gotrue_health"] = health;
    } catch (e: any) {
      result["gotrue_curl_error"] = e.message;
    }
  } catch (err: any) {
    result["error"] = err.message;
  }

  return NextResponse.json(result);
}
