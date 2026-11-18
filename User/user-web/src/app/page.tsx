"use client";

import { useEffect, useState } from "react";
import styles from "./page.module.css";

type ModuleInfo = { code: string; name: string };
type TimeInfo = { now: string; timeZoneId: string };
type MealTypeInfo = { id: string; code: string; nameMm: string; sortOrder: number };
type CurrentUser = { displayName: string };
type MealTypeStatus = "loading" | "ready" | "empty" | "error";
const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5201";
const demoModules: ModuleInfo[] = [
  { code: "HOUSEHOLD", name: "အိမ်ထောင်စု" },
  { code: "MEAL_PLAN", name: "ဟင်းလျာအစီအစဉ်" },
  { code: "SHOPPING", name: "စျေးဝယ်စာရင်း" },
  { code: "ORDER", name: "မှာယူထားမှုများ" },
];

class AuthenticationRequiredError extends Error {}

async function authenticatedJson<T>(path: string): Promise<T> {
  const response = await fetch(`${apiUrl}${path}`, { credentials: "include" });
  if (response.status === 401) {
    window.location.replace("/login");
    throw new AuthenticationRequiredError();
  }
  if (!response.ok) throw new Error(`${path} unavailable`);
  return response.json();
}

export default function UserHome() {
  const [modules, setModules] = useState<ModuleInfo[]>(demoModules);
  const [time, setTime] = useState<TimeInfo | null>(null);
  const [mealTypes, setMealTypes] = useState<MealTypeInfo[]>([]);
  const [mealTypeStatus, setMealTypeStatus] = useState<MealTypeStatus>("loading");
  const [apiConnected, setApiConnected] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [currentUser, setCurrentUser] = useState("Meal Planner");

  useEffect(() => {
    Promise.all([
      authenticatedJson<ModuleInfo[]>("/api/system/modules"),
      authenticatedJson<TimeInfo>("/api/system/time"),
      authenticatedJson<MealTypeInfo[]>("/api/reference/meal-types"),
      authenticatedJson<CurrentUser>("/api/auth/me"),
    ]).then(([moduleData, timeData, mealTypeData, user]) => {
      setModules(moduleData);
      setTime(timeData);
      setMealTypes(mealTypeData);
      setCurrentUser(user.displayName);
      setMealTypeStatus(mealTypeData.length > 0 ? "ready" : "empty");
      setApiConnected(true);
    }).catch((error: unknown) => {
      if (error instanceof AuthenticationRequiredError) return;
      setTime({ now: new Date().toISOString(), timeZoneId: "Asia/Yangon" });
      setMealTypes([]);
      setMealTypeStatus("error");
      setApiConnected(false);
    });
  }, []);

  async function logout() {
    await fetch(`${apiUrl}/api/auth/logout`, { method: "POST", credentials: "include" }).catch(() => undefined);
    window.location.replace("/login");
  }

  return (
    <div className={styles.shell}>
      <div className={styles.glow} />
      {sidebarOpen && <button className={styles.backdrop} aria-label="Close menu" onClick={() => setSidebarOpen(false)} />}
      <aside className={`${styles.sidebar} ${sidebarOpen ? styles.open : ""}`}>
        <div className={styles.brand}><span>စ</span><div><strong>စားမယ်</strong><small>Smart meal planner</small></div></div>
        <nav aria-label="User navigation">
          <button className={styles.active}><i>⌂</i><span>မူလစာမျက်နှာ</span></button>
          <button><i>▦</i><span>တစ်ပတ်စာဟင်းလျာ</span></button>
          <button><i>◫</i><span>စျေးဝယ်စာရင်း</span><b>8</b></button>
          <button><i>▤</i><span>မှာယူထားမှုများ</span></button>
          <button><i>♡</i><span>ကြိုက်နှစ်သက်မှု</span></button>
        </nav>
        <div className={styles.planCard}><span>✦</span><strong>ဒီအပတ် 72% ပြီးပါပြီ</strong><div><i /></div><small>ဟင်းလျာ ၅ မျိုး စီစဉ်ပြီး</small></div>
        <nav className={styles.bottomNav}><button><i>?</i><span>အကူအညီ</span></button><button><i>⚙</i><span>ဆက်တင်များ</span></button></nav>
        <div className={styles.profile}><div className={styles.avatar}>MP</div><div><strong>{currentUser}</strong><small>Meal planning user</small></div><button className={styles.logoutButton} onClick={logout}>ထွက်မယ်</button></div>
      </aside>

      <div className={styles.workspace}>
        <header className={styles.topbar}>
          <button className={styles.menu} onClick={() => setSidebarOpen(true)} aria-label="Open menu">☰</button>
          <div className={styles.search}><span>⌕</span><input aria-label="Search recipes" placeholder="ဟင်းလျာ၊ ပါဝင်ပစ္စည်း ရှာရန်…" /></div>
          <div className={styles.location}><span>⌖</span><div><small>ပို့ဆောင်မည့်နေရာ</small><strong>ဗဟန်းမြို့နယ်⌄</strong></div></div>
          <button className={styles.notification} aria-label="Notifications">♢<i /></button><div className={styles.topAvatar}>MS</div>
        </header>

        <main className={styles.content}>
          <section className={styles.hero}>
            <div className={styles.heroCopy}><span className={styles.kicker}>ကျန်းမာ • အဆင်ပြေ • မြန်မာအရသာ</span><h1>မင်္ဂလာနံနက်ခင်းပါ၊<br/><em>{currentUser}</em></h1><p>ဒီနေ့မိသားစုအတွက် အရသာရှိပြီး ကျန်းမာရေးနဲ့ညီညွတ်တဲ့ ဟင်းလျာတွေ စီစဉ်လိုက်ရအောင်။</p><div className={styles.heroActions}><button>တစ်ပတ်စာ စီစဉ်မယ် <span>→</span></button><button className={styles.secondary}>ဟင်းလျာများ ကြည့်မယ်</button></div></div>
            <div className={styles.glassPlate}><span className={styles.leaf}>✦</span><div className={styles.plate}><div>ထမင်း</div><i>ဟင်း</i><b>အသီးအရွက်</b><span>ဟင်းချို</span></div><div className={styles.today}><small>ဒီနေ့အတွက်</small><strong>၄ ဟင်းလျာ</strong></div></div>
          </section>

          <section className={styles.quickStats}>
            <article><span className={styles.quickIcon}>▦</span><div><small>စီစဉ်ပြီးသောရက်</small><strong>၅ / ၇ ရက်</strong></div><em>72%</em></article>
            <article><span className={styles.quickIcon}>◫</span><div><small>စျေးဝယ်ရန်</small><strong>ပစ္စည်း ၈ မျိုး</strong></div><em>ကြည့်မယ် →</em></article>
            <article><span className={styles.quickIcon}>◎</span><div><small>အပတ်စဉ်ဘတ်ဂျက်</small><strong>86,500 MMK</strong></div><em>64%</em></article>
            <article><span className={styles.quickIcon}>♨</span><div><small>ပျမ်းမျှချက်ချိန်</small><strong>၃၅ မိနစ်</strong></div><em>−8 min</em></article>
          </section>

          <section className={styles.dashboardGrid}>
            <article className={styles.panel}>
              <div className={styles.panelHead}><div><span className={styles.kicker}>ဒီနေ့အတွက်</span><h2>ဟင်းလျာအစီအစဉ်</h2></div><button>အားလုံးကြည့်မယ် →</button></div>
              <div className={styles.meals}>
                <div><span className={styles.mealArt}>☀</span><div><small>မနက်စာ · 7:30 AM</small><strong>မုန့်ဟင်းခါး</strong><p>420 kcal · 25 min</p></div><button>•••</button></div>
                <div><span className={`${styles.mealArt} ${styles.lunch}`}>◉</span><div><small>နေ့လယ်စာ · 12:30 PM</small><strong>ကြက်သားဆီပြန်၊ ချဉ်ရည်ဟင်း</strong><p>610 kcal · 45 min</p></div><button>•••</button></div>
                <div><span className={`${styles.mealArt} ${styles.dinner}`}>☾</span><div><small>ညစာ · 7:00 PM</small><strong>ငါးပေါင်းနှင့် အရွက်စုံသုပ်</strong><p>380 kcal · 35 min</p></div><button>•••</button></div>
              </div>
            </article>
            <article className={`${styles.panel} ${styles.nutrition}`}>
              <div className={styles.panelHead}><div><span className={styles.kicker}>အာဟာရ</span><h2>ယနေ့အကျဉ်းချုပ်</h2></div><button>•••</button></div>
              <div className={styles.ring}><div><strong>1,410</strong><span>/ 1,800 kcal</span></div></div>
              <div className={styles.nutrients}><p><span>Protein</span><b>68g</b><i><em style={{width:"76%"}} /></i></p><p><span>Carbs</span><b>184g</b><i><em style={{width:"62%"}} /></i></p><p><span>Vegetables</span><b>4/5</b><i><em style={{width:"80%"}} /></i></p></div>
            </article>
          </section>

          <section className={styles.referencePanel} aria-live="polite">
            <div><span className={styles.kicker}>Neon reference data</span><h2>အသုံးပြုနိုင်သော စားချိန်များ</h2><p>ဒီစာရင်းကို User API container က Neon child branch ရှိ <code>MEAL_TYPES</code> table မှ ဖတ်ထားပါတယ်။</p></div>
            <div className={styles.mealTypeList}>
              {mealTypeStatus === "loading" && <span className={styles.dataMessage}>Database data ရယူနေသည်…</span>}
              {mealTypeStatus === "error" && <span className={`${styles.dataMessage} ${styles.dataError}`}>Neon data မရရှိပါ—demo dashboard ကိုသာပြထားသည်။</span>}
              {mealTypeStatus === "empty" && <span className={styles.dataMessage}>Active meal type မရှိသေးပါ။</span>}
              {mealTypes.map((mealType) => <span className={styles.mealTypeChip} key={mealType.id}><strong>{mealType.nameMm}</strong><small>{mealType.code}</small></span>)}
            </div>
          </section>

          <section className={styles.moduleRow}>{modules.map((module, index) => <button key={module.code}><span>{["♙", "▦", "◫", "▤"][index] ?? "◇"}</span><div><strong>{module.name}</strong><small>{module.code.replaceAll("_", " ")}</small></div><b>›</b></button>)}</section>
          <footer><span>{apiConnected ? "● Docker API + Neon ချိတ်ဆက်ပြီး" : "◉ Static demo data"}</span><span>{time ? new Date(time.now).toLocaleString("en-MM", { timeZone: "Asia/Yangon" }) : "Asia/Yangon"}</span></footer>
        </main>
      </div>
    </div>
  );
}
