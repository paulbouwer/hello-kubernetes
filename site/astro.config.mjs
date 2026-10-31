// The hello-kubernetes website. See .project/roadmap/1.x/site.md.
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import preact from '@astrojs/preact';
import starlightLinksValidator from 'starlight-links-validator';

export default defineConfig({
  site: 'https://paulbouwer.github.io',
  base: '/hello-kubernetes',
  trailingSlash: 'always',
  // The dev toolbar covers the page in screenshots and reviews.
  devToolbar: { enabled: false },
  // No Content Security Policy: tried in #139, Astro's generated hashes don't
  // cover Starlight's inline scripts, and code blocks need inline styles. The
  // Playwright checks block requests to other sites instead.
  integrations: [
    starlight({
      title: 'hello-kubernetes',
      description: 'A small web app to deploy on a Kubernetes cluster. It shows which pod answered.',
      customCss: ['./src/styles/theme.css', './src/styles/code.css'],
      components: {
        Sidebar: './src/components/Sidebar.astro',
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/paulbouwer/hello-kubernetes' },
      ],
      sidebar: [
        { label: 'Start here', items: [{ autogenerate: { directory: 'docs/start-here' } }] },
        { label: 'Deploy', items: [{ autogenerate: { directory: 'docs/deploy' } }] },
        { label: 'Configure', items: [{ autogenerate: { directory: 'docs/configure' } }] },
        { label: 'Guides', items: [{ autogenerate: { directory: 'docs/guides' } }] },
        { label: 'Reference', items: [{ autogenerate: { directory: 'docs/reference' } }] },
        'docs/licences',
      ],
      plugins: [starlightLinksValidator({ errorOnLocalLinks: true })],
    }),
    preact(),
  ],
});
