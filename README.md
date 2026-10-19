# Next.js SSR en AWS

Next.js App Router con OpenNext, Lambda, S3 y CloudFront, sin Amplify. Cada PR obtiene un entorno Terraform aislado con URL HTTPS `*.cloudfront.net`; al cerrarlo se destruye.

## Arquitectura

```text
CloudFront -> Lambda servidor (SSR, Server Components, API, Server Actions, middleware)
		   -> S3 privado /_assets (/_next/static/*)
		   -> Lambda de optimizacion (/_next/image*)

Lambda servidor -> S3 /_cache + DynamoDB (cache ISR y etiquetas)
				-> SQS FIFO -> Lambda de revalidacion -> servidor via HTTPS
Lambda inicializadora -> DynamoDB (metadatos del build)
```

El modulo local [infra/modules/nextjs/main.tf](infra/modules/nextjs/main.tf) empaqueta los cuatro bundles Lambda y sube assets y cache inicial. Las paginas, incluso las prerenderizadas, pasan por el servidor OpenNext; no se reescriben rutas a `index.html`. CloudFront conserva cookies, query strings y cabeceras RSC; permite POST para Server Actions y respeta `Cache-Control` de Next.js. `x-forwarded-host` mantiene el host publico para las comprobaciones de origen.

Se usa un modulo local porque TerraNext 3.2.0 requiere dominio propio y ACM, mientras estas previews no los necesitan. El contrato es el build predeterminado de OpenNext 4.1.11, sin funciones separadas por ruta, Lambda@Edge ni streaming. El middleware se integra en el servidor regional. Cambiar esos modos requiere adaptar Terraform al manifiesto `open-next.output.json`.

## Requisitos

- Node.js 22, npm y Terraform 1.10 o posterior.
- Cuenta AWS, rol GitHub Actions con OIDC y secret `AWS_ROLE_ARN`.
- Bucket de estado remoto existente, versionado y cifrado, configurado en [infra/backend.tf](infra/backend.tf).
- Permisos de despliegue adicionales a los del antiguo sitio estatico.

Los roles de ejecucion de Lambda se crean por separado con acceso limitado a sus logs, prefijos S3, tabla DynamoDB o cola SQS. La cola usa cifrado administrado por SQS, reintentos y DLQ; no se necesita KMS personalizado. Los logs caducan a los siete dias. No se activa un warmer; existen cold starts y costes de Lambda, S3, CloudFront, SQS y DynamoDB incluso para previews.

Las Function URLs de servidor e imagenes son publicas (`NONE`) y tambien se pueden invocar directamente, fuera de CloudFront. S3 permanece privado con OAC y acceso CDN limitado a `/_assets/*`. Esto no convierte la preview en un entorno privado: no publiques secretos ni datos sensibles. Autenticacion de previews o restriccion de origen requeririan proteccion adicional.

## Desarrollo Y Pruebas

```sh
npm ci
npm run dev
```

Rutas de comprobacion: `/ssr/` cambia la fecha en cada peticion, `/api/health/` devuelve JSON sin cache y `/isr/` se regenera bajo demanda con `revalidate = 60`.

```sh
npm run lint
npm run opennext:build
npm run start
```

OpenNext ejecuta `next build` y genera `.open-next/`; no hace falta ejecutar ambos builds. `npm run build` sigue disponible para Next.js. La CLI AWS instalada es `open-next build`: no ofrece comandos `preview` o `deploy`; se prueba con Next.js y se despliega con Terraform.

Con el servidor arrancado, en otra terminal:

```sh
npm run test:smoke -- http://localhost:3000
terraform -chdir=infra init -backend=false
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test
```

Los planes de prueba usan AWS simulado, pero empaquetan el build real con el proveedor archive; no crean recursos. Tambien comprueban una configuracion de limpieza sin directorio de build. El smoke test verifica SSR, API y cabeceras/cache inicial de ISR; no demuestra el ciclo distribuido completo. En AWS, consulta `/isr/`, repite antes de 60 segundos, vuelve despues del TTL y comprueba que una peticion posterior obtiene una fecha nueva tras la revalidacion asincrona. Revisa CloudWatch y la DLQ si la fecha no cambia. Tambien puedes ejecutar el smoke test contra la URL de CloudFront.

## Pipeline Reutilizable

El [workflow de la app](.github/workflows/preview.yml) solo selecciona `deploy` o `destroy` y llama al [workflow reusable](.github/workflows/nextjs-preview.yml). La configuracion tipada [nextjs-app.ts](nextjs-app.ts) declara el slug de la app, su directorio, version de Node y comandos de build/prueba; no contiene Terraform ni detalles de Lambda. Un mini-proyecto TypeScript en `.github/actions/read-config` valida y carga la configuracion. El Terraform permanece en este repositorio de plataforma.

Las [composite actions](.github/actions) separan lectura/validacion de config, instalacion de Node, build OpenNext, despliegue e infraestructura. El slug debe ser unico por app, tener hasta 24 caracteres y usar letras minusculas, numeros e hifenes: se usa para nombrar recursos y workspaces. `deploy-aws` conserva los workspaces `pr-N` ya existentes; otras apps usan `<slug>-pr-N`.

Las referencias `@feature/split-actions` permiten probar esta rama. Antes de que otras apps lo consuman, publica una version estable del repositorio y cambia las referencias del workflow y las composite actions a un tag, por ejemplo `@v1`. Cada app consumidora configura su propio secret `AWS_ROLE_ARN`; la trust policy OIDC de ese rol debe permitir el repositorio consumidor y el evento `pull_request`.

Ejemplo para una app consumidora:

```yaml
name: Preview environment

on:
	pull_request:
		types: [opened, synchronize, reopened, closed]

permissions:
	id-token: write
	contents: read
	pull-requests: write

jobs:
	preview:
		if: github.event.pull_request.head.repo.full_name == github.repository
		uses: on-the-edge-cloud/deploy-aws/.github/workflows/nextjs-preview.yml@v1
		with:
			config-path: nextjs-app.ts
			command: ${{ github.event.action == 'closed' && 'destroy' || 'deploy' }}
		secrets:
			AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

El reusable workflow omite PRs desde forks, construye y valida la app, aplica Terraform desde el repositorio de plataforma, invalida CloudFront, ejecuta el smoke test configurado y comenta la URL. Al cerrar el PR, destruye el workspace correspondiente sin requerir un build. El checkout y el build ejecutan codigo del PR, asi que limita el despliegue a colaboradores de confianza.

Los comandos de `nextjs-app.ts` son ejecutables. Configura solo repositorios confiables y deja vacios `test-command` o `build-command` si la app no los necesita. OpenNext ya ejecuta `next build`; para esta app, `build-command` queda vacio y se usa `opennext-build-command`.

El cierre no requiere Node.js ni un build. Los buckets de preview usan `force_destroy`, por lo que Terraform elimina tambien los objetos de cache creados durante la ejecucion. Produccion no permite vaciar el bucket automaticamente.

```sh
terraform -chdir=infra init
terraform -chdir=infra workspace select pr-123
terraform -chdir=infra destroy -var='pr_number=123' -var='deploy_artifacts=false'
terraform -chdir=infra workspace select default
terraform -chdir=infra workspace delete pr-123
```

`deploy_artifacts=false` es exclusivamente para destruir: no lo uses en un apply normal porque eliminaria objetos gestionados.

Para un despliegue manual, construye OpenNext, inicializa el backend y selecciona el workspace antes de planificar:

```sh
terraform -chdir=infra init -reconfigure
terraform -chdir=infra workspace select pr-123 || terraform -chdir=infra workspace new pr-123
terraform -chdir=infra plan -var='pr_number=123' -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output -raw preview_url
```

Sin `pr_number` los nombres son de produccion. Los workspaces no son limites de seguridad: no mezcles un workspace de preview con variables de produccion. El backend de estado existente no cambia.

## Permisos Del Rol De GitHub Actions

`AWS_ROLE_ARN` sigue siendo el ARN del rol OIDC de despliegue, no el de una Lambda. Restringe su trust policy al repositorio y a los eventos previstos (`repo:OWNER/REPO:pull_request` para previews, con audiencia `sts.amazonaws.com`); no uses `pull_request_target` para ejecutar builds no confiables.

El rol necesita lectura/gestion/borrado de los recursos de preview en estos servicios:

- S3: bucket y objetos de la app (incluidos codigo y cache), configuracion de cifrado, public access block y policies.
- Lambda: funciones, codigo, configuracion, Function URLs, permisos, invocacion del inicializador y event source mappings.
- DynamoDB: tabla e indices de cache; SQS: colas, atributos, etiquetas y borrado.
- CloudFront: distribucion, OAC, funcion de host, cache policies e invalidaciones; lectura de policies administradas.
- CloudWatch Logs: grupos, retencion, etiquetas y borrado.
- IAM: crear/leer/eliminar roles, listar politicas adjuntas y perfiles de instancia, gestionar inline policies y etiquetas, y `iam:PassRole` limitado a `<app-slug>-pr-*-*` con `iam:PassedToService = lambda.amazonaws.com`.
- Backend: `s3:ListBucket`, `s3:GetObject`, `s3:PutObject` y permisos de borrado del lock `.tflock` en los prefijos de estado/workspaces.

Limita ARNs y condiciones al prefijo de la app, cuenta y region cuando el servicio lo permita. Algunas operaciones de creacion/listado requieren `Resource: "*"`; no sustituyas esta revision por permisos administrativos globales. `PowerUserAccess` por si solo no permite gestionar los roles IAM. No hacen falta permisos de Amplify, ACM ni Route 53. El repositorio no modifica automaticamente el rol de despliegue ni su trust policy.