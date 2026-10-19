# deploy-aws

Aplicación demo Next.js con SSR en AWS. Este repositorio contiene solo la app y su configuración de preview; el workflow reutilizable y Terraform viven en `on-the-edge-cloud/github-actions-nextjs` y `on-the-edge-cloud/terraform-aws-nextjs`.

## Desarrollo local

```sh
npm ci
npm run dev
```

Rutas de muestra: `/ssr/` renderiza dinámicamente, `/api/health/` verifica una API route y `/isr/` demuestra revalidación incremental.

```sh
npm run lint
npm run opennext:build
npm run start
npm run test:smoke -- http://localhost:3000
```

OpenNext ejecuta `next build` y genera `.open-next/`; el pipeline publica ese artefacto con el módulo Terraform indicado en [nextjs-app.yml](nextjs-app.yml).

## Preview

[preview.yml](.github/workflows/preview.yml) llama al reusable workflow con el tag `v1`. Configura el secret `AWS_ROLE_ARN` y una trust policy OIDC restringida a este repositorio. El workflow omite pull requests desde forks.

`deployment-type` acepta `ssr` o `static`. `terraform-module-version` fija el tag de `terraform-aws-nextjs`. La app no contiene Terraform ni credenciales AWS.
