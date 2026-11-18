"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import styles from "../login/login.module.css";

type AdminRequest = { id: string; username: string; displayName: string; email: string; requestedAt: string };
const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5101";

export default function AdminRequests() {
  const [requests, setRequests] = useState<AdminRequest[]>([]); const [error, setError] = useState(""); const [pendingId, setPendingId] = useState("");
  const load = useCallback(async () => {
    try {
      const response = await fetch(`${apiUrl}/api/auth/admin-requests`, { credentials: "include" });
      if (response.status === 403) { setError("SUPER_ADMIN role is required to approve requests."); return; }
      if (response.status === 401) { window.location.replace("/login"); return; }
      if (!response.ok) throw new Error(); setRequests(await response.json());
    } catch { setError("Admin API or request data is unavailable."); }
  }, []);
  useEffect(() => {
    void fetch(`${apiUrl}/api/auth/admin-requests`, { credentials: "include" }).then(async response => {
      if (response.status === 403) { setError("SUPER_ADMIN role is required to approve requests."); return; }
      if (response.status === 401) { window.location.replace("/login"); return; }
      if (!response.ok) throw new Error(); setRequests(await response.json());
    }).catch(() => setError("Admin API or request data is unavailable."));
  }, []);
  async function approve(id: string) {
    setPendingId(id); setError("");
    try { const response = await fetch(`${apiUrl}/api/auth/admin-requests/${id}/approve`, { method: "POST", credentials: "include" }); if (!response.ok) throw new Error(); await load(); }
    catch { setError("Approval failed. Check Resend delivery logs and the API runtime log."); } finally { setPendingId(""); }
  }
  return <main className={styles.page}><section className={styles.card}><div className={styles.mark}>M</div><span className={styles.eyebrow}>Maker / Checker</span><h1>Pending Admin requests</h1><p>Approval creates an INVITED Admin account and sends a one-time password setup link.</p>
    {error && <div className={styles.error} role="alert">{error}</div>}
    <div className={styles.list}>{requests.length === 0 && !error ? <div className={styles.success}>No pending requests.</div> : requests.map(request => <article className={styles.request} key={request.id}><strong>{request.displayName}</strong><span>{request.username} · {request.email}</span><span>{new Date(request.requestedAt).toLocaleString("en-MM", { timeZone: "Asia/Yangon" })}</span><button onClick={() => approve(request.id)} disabled={pendingId === request.id}>{pendingId === request.id ? "Approving…" : "Approve & send invitation"}</button></article>)}</div>
    <div className={styles.links}><Link href="/">Back to dashboard</Link></div>
  </section></main>;
}
