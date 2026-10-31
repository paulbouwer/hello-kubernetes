// Copies the licence of each bundled font package into public/, so the
// licence ships with the font files in the built site, as the SIL Open Font
// Licence and the Ubuntu Font Licence require. Runs before dev and build.
import { copyFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

const require = createRequire(import.meta.url);
const out = new URL('../public/licences/fonts/', import.meta.url).pathname;
mkdirSync(out, { recursive: true });

for (const font of ['archivo', 'inter', 'jetbrains-mono', 'ubuntu']) {
  const dir = dirname(require.resolve(`@fontsource/${font}/package.json`));
  copyFileSync(join(dir, 'LICENSE'), join(out, `${font}.txt`));
}
