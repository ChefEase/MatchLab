export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center gap-5 px-6 py-12">
      <p className="text-sm font-semibold uppercase tracking-widest text-slate-500">MatchLab</p>
      <h1 className="text-4xl font-semibold tracking-tight text-slate-900">Development scaffold</h1>
      <p className="max-w-2xl text-lg leading-relaxed text-slate-700">
        The web app is running. Fixtures, forecasts, and account features will be added in later tasks.
      </p>
      <p className="text-sm text-slate-500">
        Health check: <code>/api/health</code>
      </p>
    </main>
  );
}
