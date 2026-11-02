// The live preview's templates and assets: the app's Handlebars templates,
// its CSS, its font and its logo, imported from src/app and inlined as data
// URLs. They are about 300 KB, so the landing page imports this module only
// when its mock-up comes into view.
import * as preview from './preview.mjs';
import layout from '../../../src/app/views/layouts/main.handlebars?raw';
import home from '../../../src/app/views/home.handlebars?raw';
import css from '../../../src/app/static/css/main.css?raw';
import logo from '../../../src/app/static/images/kubernetes.png?inline';
import cyrillicExt from '../../../src/app/static/fonts/ubuntu/ubuntu-cyrillic-ext-300-normal.woff2?inline';
import cyrillic from '../../../src/app/static/fonts/ubuntu/ubuntu-cyrillic-300-normal.woff2?inline';
import greekExt from '../../../src/app/static/fonts/ubuntu/ubuntu-greek-ext-300-normal.woff2?inline';
import greek from '../../../src/app/static/fonts/ubuntu/ubuntu-greek-300-normal.woff2?inline';
import latinExt from '../../../src/app/static/fonts/ubuntu/ubuntu-latin-ext-300-normal.woff2?inline';
import latin from '../../../src/app/static/fonts/ubuntu/ubuntu-latin-300-normal.woff2?inline';

const render = preview.createRenderer({ layout, home });
const assets = {
  css,
  logo,
  fonts: {
    'ubuntu-cyrillic-ext-300-normal.woff2': cyrillicExt,
    'ubuntu-cyrillic-300-normal.woff2': cyrillic,
    'ubuntu-greek-ext-300-normal.woff2': greekExt,
    'ubuntu-greek-300-normal.woff2': greek,
    'ubuntu-latin-ext-300-normal.woff2': latinExt,
    'ubuntu-latin-300-normal.woff2': latin,
  } as Record<string, string>,
};

// The page the preview shows, for the settings the app would see.
export function previewPage(settings: Parameters<typeof preview.pageContext>[0]) {
  return preview.inlineAssets(render(preview.pageContext(settings)), assets);
}
