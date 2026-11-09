import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "စားမယ် — Weekly Meal Planner",
  description: "Healthy Myanmar weekly meal planning",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="my">
      <body>{children}</body>
    </html>
  );
}
