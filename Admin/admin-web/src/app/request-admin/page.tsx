"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import styles from "../login/login.module.css";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5101";

export default function RequestAdmin() {
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setPending(true); setError(""); setMessage("");
    const form = new FormData(event.currentTarget);
    try {
      const response = await fetch(`${apiUrl}/api/auth/admin-requests`, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username: form.get("username"), displayName: form.get("displayName"), email: form.get("email") }),
      });
      if (!response.ok) { setError(response.status === 409 ? "That username or email is already in use." : "Please check the form and try again."); return; }
      event.currentTarget.reset(); setMessage("Request submitted. A Master Admin must approve it before an invitation is emailed.");
    } catch { setError("Admin API is unavailable."); } finally { setPending(false); }
  }

  return <main className={styles.page}><section className={styles.card}>
    <div className={styles.mark}>M</div><span className={styles.eyebrow}>Admin access request</span>
    <h1>Request an account</h1><p>Your request remains pending until a Master Admin approves it.</p>
    <form onSubmit={submit}>
      <label htmlFor="username">Username</label><input id="username" name="username" minLength={3} maxLength={200} required />
      <label htmlFor="displayName">Display name</label><input id="displayName" name="displayName" maxLength={1000} required />
      <label htmlFor="email">Email</label><input id="email" name="email" type="email" maxLength={1000} required />
      {error && <div className={styles.error} role="alert">{error}</div>}{message && <div className={styles.success}>{message}</div>}
      <button disabled={pending}>{pending ? "Submitting…" : "Submit request"}</button>
    </form><div className={styles.links}><Link href="/login">Back to login</Link></div>
  </section></main>;
}
