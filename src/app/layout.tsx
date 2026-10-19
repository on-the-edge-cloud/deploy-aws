import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Deploy AWS | Preview environments",
  description: "Next.js SSR on AWS with OpenNext, Terraform and GitHub Actions.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}