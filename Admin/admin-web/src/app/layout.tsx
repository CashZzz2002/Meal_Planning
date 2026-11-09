import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Meal Planning Admin",
  description: "Township operations and meal planning administration",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
