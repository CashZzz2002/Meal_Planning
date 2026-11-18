"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import styles from "../login/login.module.css";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5101";

export default function AcceptInvitation() {
  const [error, setError] = useState(""); const [done, setDone] = useState(false); const [pending, setPending] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setPending(true); setError(""); const form = new FormData(event.currentTarget); const token = new URLSearchParams(window.location.search).get("token") ?? "";
    if (!token) { setError("Invitation token is missing."); setPending(false); return; }
    if (form.get("password") !== form.get("confirmPassword")) { setError("Passwords do not match."); setPending(false); return; }
    try {
      const response = await fetch(`${apiUrl}/api/auth/admin-invitations/accept`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token, password: form.get("password") }) });
      if (!response.ok) { setError("Invitation is invalid or expired. Password must contain at least 12 characters."); return; }
      setDone(true);
    } catch { setError("Admin API is unavailable."); } finally { setPending(false); }
  }
  return <main className={styles.page}><section className={styles.card}><div className={styles.mark}>M</div><span className={styles.eyebrow}>Admin invitation</span><h1>Set your password</h1>
    {done ? <><div className={styles.success}>Your account is active. You can now sign in.</div><div className={styles.links}><Link href="/login">Go to login</Link></div></> : <form onSubmit={submit}>
      <label htmlFor="password">Password</label><input id="password" name="password" type="password" minLength={12} autoComplete="new-password" required />
      <label htmlFor="confirmPassword">Confirm password</label><input id="confirmPassword" name="confirmPassword" type="password" minLength={12} autoComplete="new-password" required />
      {error && <div className={styles.error} role="alert">{error}</div>}<button disabled={pending}>{pending ? "Activating…" : "Activate account"}</button>
    </form>}
  </section></main>;
}
