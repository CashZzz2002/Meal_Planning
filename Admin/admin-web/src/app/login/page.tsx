"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import styles from "./login.module.css";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5101";

export default function AdminLogin() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setError("");
    const form = new FormData(event.currentTarget);
    try {
      const response = await fetch(`${apiUrl}/api/auth/login`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username: form.get("username"), password: form.get("password") }),
      });
      if (!response.ok) {
        setError(response.status === 429 ? "Too many attempts. Please wait one minute." : "Username or password is incorrect.");
        return;
      }
      router.replace("/");
      router.refresh();
    } catch {
      setError("Admin API is unavailable. Check Docker and /health/ready.");
    } finally {
      setPending(false);
    }
  }

  return <main className={styles.page}>
    <section className={styles.card}>
      <div className={styles.mark}>M</div>
      <span className={styles.eyebrow}>MealFlow Admin Suite</span>
      <h1>Sign in to operations</h1>
      <p>Credentials are verified by the Admin API against the Neon child branch.</p>
      <form onSubmit={submit}>
        <label htmlFor="username">Username</label>
        <input id="username" name="username" autoComplete="username" required maxLength={200} />
        <label htmlFor="password">Password</label>
        <input id="password" name="password" type="password" autoComplete="current-password" required />
        {error && <div className={styles.error} role="alert">{error}</div>}
        <button disabled={pending}>{pending ? "Signing in…" : "Sign in"}</button>
      </form>
      <div className={styles.links}><Link href="/request-admin">Request an Admin account</Link></div>
      <small>Admin role is required. Session expires after 8 hours.</small>
    </section>
  </main>;
}
