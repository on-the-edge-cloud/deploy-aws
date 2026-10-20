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
npm run build
npm run start
```

El build de producción usa `next build`. La configuración de preview está en [nextjs-app.yml](nextjs-app.yml) y se ejecuta mediante el workflow reutilizable.

## Preview

[preview.yml](.github/workflows/preview.yml) llama al reusable workflow con el tag `v1`. Configura el secret `AWS_ROLE_ARN` y una trust policy OIDC restringida a este repositorio. El workflow omite pull requests desde forks.

`deployment-type` acepta `ssr` o `static`. `terraform-module-version` fija el tag de `terraform-aws-nextjs`. La app no contiene Terraform ni credenciales AWS.
