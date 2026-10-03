export async function GET() {
  return Response.json({ status: "ok", service: "web", mode: "scaffold" });
}
