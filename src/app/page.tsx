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
          <div className="step"><span className="step-index">03</span><strong>Preview listo</strong><small>OpenNext + AWS</small></div>
        </div>
      </section>

      <footer className="footer">
        <span>DEPLOY-AWS <span className="footer-separator">/</span> NEXT.JS SSR + OPENNEXT</span>
        <span>EU-NORTH-1 <span className="region-dot" /></span>
      </footer>
    </main>
  );
}