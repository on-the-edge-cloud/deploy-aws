export default function Home() {
  return (
    <main className="shell">
      <header className="topbar">
        <a className="wordmark" href="#inicio" aria-label="Deploy AWS, inicio">
          <span className="mark" aria-hidden="true">D</span>
          <span>deploy<span className="wordmark-light">/aws</span></span>
        </a>
        <span className="topbar-note">PLATAFORMA DE PREVIEWS</span>
      </header>

      <section className="intro" id="inicio">
        <div className="eyebrow"><span className="pulse" /> SISTEMA LISTO</div>
        <h1>Una URL nueva.<br /><span>Con cada pull request.</span></h1>
        <p className="lead">
          Next.js con SSR en Lambda, S3 y CloudFront. Terraform prepara un entorno
          aislado para revisar cada cambio antes de integrarlo.
        </p>
        <div className="architecture" aria-label="Flujo de despliegue">
          <div className="step"><span className="step-index">01</span><strong>Pull request</strong><small>GitHub Actions</small></div>
          <span className="connector" aria-hidden="true" />
          <div className="step"><span className="step-index">02</span><strong>Infraestructura</strong><small>Terraform</small></div>
          <span className="connector" aria-hidden="true" />
          <div className="step"><span className="step-index">03</span><strong>Preview listo</strong><small>Next.js + AWS</small></div>
        </div>

        <section className="demos" aria-labelledby="demos-title">
          <div className="demos-heading">
            <span className="eyebrow">RUTAS DE DEMOSTRACIÓN</span>
            <h2 id="demos-title">Explora la app</h2>
          </div>
          <div className="demo-grid">
            <a className="demo-link" href="/isr/">
              <span className="demo-meta"><span className="demo-kind">ISR</span><code>/isr/</code></span>
              <strong>Revalidación incremental</strong>
              <span className="demo-description">Contenido regenerado cada 60 segundos.</span>
            </a>
            <a className="demo-link" href="/ssr/">
              <span className="demo-meta"><span className="demo-kind">SSR</span><code>/ssr/</code></span>
              <strong>Renderizado dinámico</strong>
              <span className="demo-description">Contenido renderizado en cada solicitud.</span>
            </a>
            <a className="demo-link" href="/api/health/">
              <span className="demo-meta"><span className="demo-kind">GET</span><code>/api/health/</code></span>
              <strong>Health check</strong>
              <span className="demo-description">Estado del servicio y marca temporal en JSON.</span>
            </a>
          </div>
        </section>
      </section>

      <footer className="footer">
        <span>DEPLOY-AWS <span className="footer-separator">/</span> NEXT.JS SSR + AWS</span>
        <span>EU-NORTH-1 <span className="region-dot" /></span>
      </footer>
    </main>
  );
}