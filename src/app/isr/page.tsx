export const revalidate = 60;

export default function ISRPage() {
  return (
    <main>
      <h1>ISR funcionando</h1>
      <p>Generado en el servidor: {new Date().toISOString()}</p>
    </main>
  );
}