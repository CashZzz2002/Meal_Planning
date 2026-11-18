"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import styles from "./login.module.css";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5201";

export default function UserLogin() {
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
        setError(response.status === 429 ? "ခဏစောင့်ပြီး ပြန်လည်ကြိုးစားပါ။" : "အသုံးပြုသူအမည် သို့မဟုတ် စကားဝှက် မမှန်ပါ။");
        return;
      }
      router.replace("/");
      router.refresh();
    } catch {
      setError("User API မရရှိပါ။ Docker နှင့် /health/ready ကိုစစ်ဆေးပါ။");
    } finally {
      setPending(false);
    }
  }

  return <main className={styles.page}>
    <section className={styles.card}>
      <div className={styles.mark}>စ</div>
      <span className={styles.eyebrow}>စားမယ် · Smart meal planner</span>
      <h1>အကောင့်ဝင်ရန်</h1>
      <p>User API က Neon child branch ရှိ credential ကို လုံခြုံစွာ စစ်ဆေးပေးပါမယ်။</p>
      <form onSubmit={submit}>
        <label htmlFor="username">အသုံးပြုသူအမည်</label>
        <input id="username" name="username" autoComplete="username" required maxLength={200} />
        <label htmlFor="password">စကားဝှက်</label>
        <input id="password" name="password" type="password" autoComplete="current-password" required />
        {error && <div className={styles.error} role="alert">{error}</div>}
        <button disabled={pending}>{pending ? "စစ်ဆေးနေသည်…" : "အကောင့်ဝင်မယ်"}</button>
      </form>
      <div className={styles.links}><Link href="/register">အကောင့်အသစ်ဖွင့်မယ်</Link></div>
      <small>User role လိုအပ်ပြီး session သက်တမ်း ၈ နာရီဖြစ်ပါတယ်။</small>
    </section>
  </main>;
}
