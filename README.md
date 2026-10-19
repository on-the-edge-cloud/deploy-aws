# Next.js en AWS

Aplicación Next.js exportada como sitio estático y desplegada en S3 detrás de CloudFront. Cada pull request obtiene un entorno aislado con Terraform; al cerrar el PR, el workflow lo destruye.

## Requisitos

- Node.js 22 y npm.
- Terraform 1.10 o posterior (`use_lockfile` del backend S3 requiere esta versión).
- Una cuenta AWS y un rol de GitHub Actions configurado con OIDC.
- Un bucket S3 existente para el estado remoto de Terraform.
- Un secret de repositorio `AWS_ROLE_ARN` con el ARN del rol asumible por GitHub Actions.

Antes de ejecutar el workflow, configura el bucket y la región del backend en `infra/backend.tf`. El bucket de estado debe existir previamente y tener versionado y cifrado habilitados. El rol necesita permisos para administrar S3 y CloudFront, además de leer/escribir el bucket de estado. CloudFront proporciona una URL HTTPS `*.cloudfront.net`, por lo que no necesitas un dominio propio, Route 53 ni un certificado ACM.

## Desarrollo local

```sh
npm ci
npm run dev
```

Para generar y comprobar la exportación estática:

```sh
npm run build
```

Next.js escribe el sitio listo para subir en `out/`.

## Entornos de preview

El workflow `.github/workflows/preview.yml` crea/actualiza un preview en cada apertura o push a un PR, sube `out/` a S3, invalida CloudFront y publica la URL como comentario. Al cerrar o fusionar el PR, destruye sus recursos. Pull requests desde forks pueden no tener acceso al secret de AWS y, por tanto, no podrán desplegar con este workflow sin un flujo de confianza adicional.

Los workspaces de Terraform aíslan el estado por PR, pero no son límites de seguridad. Revisa cuidadosamente los permisos del rol de GitHub Actions y limita su trust policy al repositorio y a la rama/eventos previstos.