"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import styles from "../login/login.module.css";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5201";

export default function Register() {
  const router = useRouter(); const [error, setError] = useState(""); const [pending, setPending] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setPending(true); setError(""); const form = new FormData(event.currentTarget);
    try {
      const email = String(form.get("email") ?? "");
      const response = await fetch(`${apiUrl}/api/auth/register`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ username: form.get("username"), displayName: form.get("displayName"), email, password: form.get("password") }) });
      if (!response.ok) { setError(response.status === 409 ? "ဒီ username သို့မဟုတ် email ကို အသုံးပြုပြီးပါပြီ။" : "အချက်အလက်များနှင့် အနည်းဆုံး ၁၂ လုံးရှိ password ကို စစ်ဆေးပါ။"); return; }
      router.push(`/verify-email?email=${encodeURIComponent(email)}`);
    } catch { setError("User API မရရှိပါ။"); } finally { setPending(false); }
  }
  return <main className={styles.page}><section className={styles.card}><div className={styles.mark}>စ</div><span className={styles.eyebrow}>စားမယ် · Registration</span><h1>အကောင့်အသစ်ဖွင့်မယ်</h1><p>Email သို့ပို့မည့် 6-digit code ဖြင့် အကောင့်ကို activate လုပ်ပါမယ်။</p>
    <form onSubmit={submit}><label htmlFor="username">အသုံးပြုသူအမည်</label><input id="username" name="username" minLength={3} maxLength={200} required />
      <label htmlFor="displayName">အမည်</label><input id="displayName" name="displayName" maxLength={1000} required />
      <label htmlFor="email">Email</label><input id="email" name="email" type="email" maxLength={1000} required />
      <label htmlFor="password">စကားဝှက်</label><input id="password" name="password" type="password" minLength={12} autoComplete="new-password" required />
      {error && <div className={styles.error} role="alert">{error}</div>}<button disabled={pending}>{pending ? "ပို့နေသည်…" : "Register & send code"}</button>
    </form><div className={styles.links}><Link href="/login">Login သို့ပြန်မယ်</Link></div>
  </section></main>;
}
