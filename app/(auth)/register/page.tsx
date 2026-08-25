"use client";

import Image from "next/image";
import Link from "next/link";

export default function RegisterPage() {
  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6 text-center">
        <Image src="/logo.png" alt="ZernFlow" width={48} height={48} className="mx-auto mb-3" />
        <h1 className="text-2xl font-bold">Registrasi Ditutup</h1>
        <p className="text-sm text-muted-foreground leading-relaxed">
          Pendaftaran mandiri publik dinonaktifkan pada sistem ini. Akses ZernFlow dibatasi khusus untuk anggota tim internal.
        </p>
        <p className="text-xs text-muted-foreground">
          Silakan hubungi administrator sistem untuk pembuatan akun baru.
        </p>
        <div className="pt-2">
          <Link
            href="/login"
            className="inline-flex w-full items-center justify-center rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90"
          >
            Kembali ke Halaman Masuk
          </Link>
        </div>
      </div>
    </div>
  );
}
