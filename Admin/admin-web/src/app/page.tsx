"use client";

import { useEffect, useState } from "react";
import styles from "./page.module.css";

type ModuleInfo = { code: string; name: string };
type TimeInfo = { now: string; timeZoneId: string };

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:5101";
const demoModules: ModuleInfo[] = [
  { code: "IAM", name: "Identity & Access" },
  { code: "SETUP", name: "Setup" },
  { code: "CATALOG", name: "Food Catalog" },
  { code: "WAREHOUSE", name: "Warehouse" },
  { code: "ORDER", name: "Order Operations" },
];
const navigation = [
  ["⌂", "Dashboard"], ["♙", "Agents"], ["⌘", "Setup"],
  ["▦", "Recipes"], ["▤", "Warehouse"], ["◫", "Orders"], ["⚙", "Settings"],
];

export default function AdminHome() {
  const [modules, setModules] = useState<ModuleInfo[]>(demoModules);
  const [time, setTime] = useState<TimeInfo | null>(null);
  const [status, setStatus] = useState("Static demo mode");
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    Promise.all([
      fetch(`${apiUrl}/api/system/modules`).then((response) => {
        if (!response.ok) throw new Error("Admin modules unavailable");
        return response.json();
      }),
      fetch(`${apiUrl}/api/system/time`).then((response) => {
        if (!response.ok) throw new Error("Admin time unavailable");
        return response.json();
      }),
    ]).then(([moduleData, timeData]) => {
      setModules(moduleData); setTime(timeData); setStatus("System operational");
    }).catch(() => {
      setTime({ now: new Date().toISOString(), timeZoneId: "Asia/Yangon" });
      setStatus("Static demo mode");
    });
  }, []);

  return (
    <div className={styles.shell}>
      <div className={styles.aurora} />
      {sidebarOpen && <button className={styles.backdrop} aria-label="Close sidebar" onClick={() => setSidebarOpen(false)} />}
      <aside className={`${styles.sidebar} ${sidebarOpen ? styles.sidebarOpen : ""}`}>
        <div className={styles.brand}><span className={styles.brandMark}>M</span><div><strong>MealFlow</strong><small>Admin Suite</small></div></div>
        <nav className={styles.sideNav} aria-label="Admin navigation">
          <span className={styles.navLabel}>Workspace</span>
          {navigation.slice(0, 6).map(([icon, label], index) => <button className={index === 0 ? styles.active : ""} key={label}><i>{icon}</i><span>{label}</span>{index === 5 && <b>12</b>}</button>)}
          <span className={styles.navLabel}>System</span>
          <button><i>{navigation[6][0]}</i><span>{navigation[6][1]}</span></button>
        </nav>
        <div className={styles.helpCard}><span>✦</span><strong>Need a hand?</strong><p>Review local setup and system health.</p><button>Open guide</button></div>
        <div className={styles.sideProfile}><div className={styles.avatar}>KT</div><div><strong>Ko Thura</strong><small>Central Admin</small></div><span>⋮</span></div>
      </aside>

      <div className={styles.workspace}>
        <header className={styles.topbar}>
          <button className={styles.menuButton} aria-label="Open sidebar" onClick={() => setSidebarOpen(true)}>☰</button>
          <div className={styles.search}><span>⌕</span><input aria-label="Search" placeholder="Search inventory, orders, agents…" /><kbd>⌘ K</kbd></div>
          <div className={styles.topActions}><div className={styles.live}><span />{status}</div><button aria-label="Notifications">♢<b /></button><div className={styles.miniAvatar}>KT</div></div>
        </header>

        <main className={styles.content}>
          <section className={styles.welcome}>
            <div><span className={styles.eyebrow}>Monday overview</span><h1>မင်္ဂလာပါ, Ko Thura</h1><p>Here is what is happening across your township operations today.</p></div>
            <div className={styles.timeCard}><span>Myanmar local time</span><strong>{time ? new Date(time.now).toLocaleTimeString("en-MM", { hour: "2-digit", minute: "2-digit", timeZone: "Asia/Yangon" }) : "—"}</strong><small>Asia/Yangon · UTC+06:30</small></div>
          </section>

          <section className={styles.stats}>
            <article><div className={styles.statIcon}>▦</div><div><span>Active warehouses</span><strong>18</strong><small className={styles.positive}>↗ 2 this month</small></div><em>•••</em></article>
            <article><div className={styles.statIcon}>◫</div><div><span>Today&apos;s orders</span><strong>284</strong><small className={styles.positive}>↗ 12.8%</small></div><em>•••</em></article>
            <article><div className={`${styles.statIcon} ${styles.gold}`}>△</div><div><span>Low-stock items</span><strong>23</strong><small className={styles.warning}>Needs attention</small></div><em>•••</em></article>
            <article><div className={styles.statIcon}>♙</div><div><span>Active agents</span><strong>46</strong><small>Across 12 townships</small></div><em>•••</em></article>
          </section>

          <section className={styles.mainGrid}>
            <article className={styles.panel}>
              <div className={styles.panelHead}><div><span className={styles.eyebrow}>Quick access</span><h2>Operations</h2></div><button>View all →</button></div>
              <div className={styles.moduleGrid}>{modules.map((module, index) => <button key={module.code}><span>{["♙", "⌘", "▦", "▤", "◫"][index] ?? "◇"}</span><div><strong>{module.name}</strong><small>{module.code}</small></div><b>›</b></button>)}</div>
            </article>
            <article className={`${styles.panel} ${styles.inventory}`}>
              <div className={styles.panelHead}><div><span className={styles.eyebrow}>Inventory health</span><h2>Stock overview</h2></div><button>•••</button></div>
              <div className={styles.donut}><div><strong>87%</strong><span>Healthy</span></div></div>
              <div className={styles.legend}><p><span className={styles.goodDot}/>Healthy stock <b>1,248</b></p><p><span className={styles.warnDot}/>Low stock <b>23</b></p><p><span className={styles.redDot}/>Out of stock <b>8</b></p></div>
            </article>
          </section>

          <section className={`${styles.panel} ${styles.orders}`}>
            <div className={styles.panelHead}><div><span className={styles.eyebrow}>Live activity</span><h2>Recent orders</h2></div><button>View all orders →</button></div>
            <div className={styles.tableWrap}><table><thead><tr><th>Order</th><th>Customer</th><th>Township</th><th>Amount</th><th>Status</th></tr></thead><tbody>
              <tr><td>#MP-2048</td><td><span className={styles.customer}>MS</span>May Sandi</td><td>Bahan</td><td>42,500 MMK</td><td><span className={styles.pill}>Preparing</span></td></tr>
              <tr><td>#MP-2047</td><td><span className={styles.customer}>AK</span>Aung Kyaw</td><td>Hlaing</td><td>31,200 MMK</td><td><span className={`${styles.pill} ${styles.shipped}`}>On delivery</span></td></tr>
              <tr><td>#MP-2046</td><td><span className={styles.customer}>TT</span>Thiri Tun</td><td>Sanchaung</td><td>28,900 MMK</td><td><span className={`${styles.pill} ${styles.done}`}>Completed</span></td></tr>
            </tbody></table></div>
          </section>
        </main>
      </div>
    </div>
  );
}
