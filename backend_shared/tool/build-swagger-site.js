import { mkdir, writeFile, copyFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import swaggerUi from 'swagger-ui-dist';
import { openapi } from '../src/openapi.js';
import { swaggerHtml, swaggerInit } from '../src/swagger.js';

const target = resolve(process.argv[2] ?? '../dist/swagger-site');
await mkdir(join(target, 'assets'), { recursive: true });
const spec = structuredClone(openapi);
spec.servers = [{ url: 'https://nguyen-hoai-nam-2380601398-api.onrender.com/v1', description: 'API chung đang được APK sử dụng' }];
spec.info.description = 'TRANG TÀI LIỆU SOURCE. Try it out tắt trên GitHub Pages vì API chung chưa hỗ trợ CORS. Muốn gọi trực tiếp trong Swagger, chủ API cần deploy backend có /docs/ cùng host.\n\n' + spec.info.description;
await writeFile(join(target, 'index.html'), swaggerHtml);
await writeFile(join(target, 'init.js'), swaggerInit({ readOnly: true }));
await writeFile(join(target, 'openapi.json'), JSON.stringify(spec, null, 2) + '\n');
for (const file of ['swagger-ui.css', 'swagger-ui-bundle.js']) await copyFile(join(swaggerUi.getAbsoluteFSPath(), file), join(target, 'assets', file));
await writeFile(join(target, '.nojekyll'), '');
console.log(target);
