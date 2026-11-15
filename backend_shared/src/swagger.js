import swaggerUi from 'swagger-ui-dist';
import { openapi } from './openapi.js';

export const swaggerHtml = `<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>NguyenHoangVu — Swagger UI</title><link rel="stylesheet" href="./assets/swagger-ui.css"></head>
<body style="margin:0"><div id="swagger-ui"></div>
<script src="./assets/swagger-ui-bundle.js"></script><script src="./init.js"></script></body></html>`;

export function swaggerInit({ readOnly = false } = {}) {
  return `window.onload = function () { window.ui = SwaggerUIBundle({
    url: './openapi.json', dom_id: '#swagger-ui', deepLinking: true,
    persistAuthorization: false, validatorUrl: null,
    supportedSubmitMethods: ${JSON.stringify(readOnly ? [] : ['get', 'post', 'patch', 'delete'])},
    presets: [SwaggerUIBundle.presets.apis]
  }); };`;
}

export function mountSwagger(app) {
  app.get(['/', '/v1', '/v1/', '/swagger', '/swagger-ui', '/v1/docs'], (_req, res) => res.redirect('/docs/'));
  app.get(/^\/docs$/, (_req, res) => res.redirect('/docs/'));
  app.get(['/openapi.json', '/docs/openapi.json'], (_req, res) => res.json(openapi));
  app.get('/docs/', (_req, res) => res.type('html').send(swaggerHtml));
  app.get('/docs/init.js', (_req, res) => res.type('js').send(swaggerInit()));
  for (const file of ['swagger-ui.css', 'swagger-ui-bundle.js']) {
    app.get(`/docs/assets/${file}`, (_req, res) => res.sendFile(file, { root: swaggerUi.getAbsoluteFSPath() }));
  }
}
