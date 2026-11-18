"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import styles from "../login/login.module.css";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5201";

export default function VerifyEmail() {
  const [error, setError] = useState(""); const [message, setMessage] = useState(""); const [done, setDone] = useState(false); const [pending, setPending] = useState(false);
  useEffect(() => {
    const input = document.querySelector<HTMLInputElement>("#verification-email");
    if (input) input.value = new URLSearchParams(window.location.search).get("email") ?? "";
  }, []);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setPending(true); setError(""); const form = new FormData(event.currentTarget); const email = String(form.get("email") ?? "");
    try { const response = await fetch(`${apiUrl}/api/auth/verify-email`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, code: form.get("code") }) }); if (!response.ok) { setError("Code မှားနေသည်၊ သက်တမ်းကုန်နေသည် သို့မဟုတ် ကြိုးစားမှုများလွန်းနေသည်။"); return; } setDone(true); }
    catch { setError("User API မရရှိပါ။"); } finally { setPending(false); }
  }
  async function resend() { const input = document.querySelector<HTMLInputElement>("#verification-email"); const email = input?.value ?? ""; setError(""); setMessage(""); await fetch(`${apiUrl}/api/auth/resend-verification`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email }) }); setMessage("Code အသစ်ပို့ထားပါတယ်။"); }
  return <main className={styles.page}><section className={styles.card}><div className={styles.mark}>စ</div><span className={styles.eyebrow}>Email verification</span><h1>6-digit code ထည့်ပါ</h1><p>Registration email သို့ပို့ထားသော code သည် ၁၀ မိနစ်အတွင်း အသုံးပြုရပါမယ်။</p>
    {done ? <><div className={styles.success}>အကောင့် Active ဖြစ်ပါပြီ။</div><div className={styles.links}><Link href="/login">Login ဝင်မယ်</Link></div></> : <><form onSubmit={submit}><label htmlFor="verification-email">Email</label><input id="verification-email" name="email" type="email" required /><label htmlFor="code">Verification code</label><input id="code" name="code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required />{error && <div className={styles.error} role="alert">{error}</div>}{message && <div className={styles.success}>{message}</div>}<button disabled={pending}>{pending ? "စစ်ဆေးနေသည်…" : "Verify email"}</button></form><div className={styles.links}><button type="button" onClick={resend}>Code ပြန်ပို့ပါ</button></div></>}
  </section></main>;
}
