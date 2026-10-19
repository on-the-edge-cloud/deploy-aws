export const dynamic = "force-dynamic";

export default function SSRPage() {
  return (
    <main>
      <h1>SSR funcionando</h1>
      <p>Renderizado en el servidor: {new Date().toISOString()}</p>
    </main>
  );
}