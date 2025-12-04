export default function HomePage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="text-center space-y-4 p-8">
        <div className="space-y-2">
          <h1 className="text-4xl font-bold tracking-tighter sm:text-5xl md:text-6xl">
            Frontend Not Created Yet
          </h1>
          <p className="text-muted-foreground text-lg sm:text-xl max-w-[600px] mx-auto">
            This is the default template. Your frontend application will appear here once it's deployed.
          </p>
        </div>
        <div className="mt-8 flex flex-col gap-2 text-sm text-muted-foreground">
          <p>🚀 Ready to deploy your application</p>
          <p>📦 All dependencies are configured</p>
          <p>✨ Start building something amazing</p>
        </div>
      </div>
    </div>
  )
}
