import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'XOOO AI Platform - Empty Template',
  description: 'Empty template for XOOO AI Platform deployments',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body className={`font-sans antialiased`}>
        {children}
      </body>
    </html>
  )
}
