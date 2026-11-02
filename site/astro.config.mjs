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
  // The config builder imports the app's templates, CSS, font and logo, and the
  // chart's schema, from outside site/, so the dev server must serve the repo.
  vite: { server: { fs: { allow: ['..'] } } },
  integrations: [
    starlight({
      title: 'hello-kubernetes',
      description: 'A small web app to deploy on a Kubernetes cluster. It shows which pod answered.',
      // The Open Graph image for every page (make og-image draws it). Starlight
      // already sets each page's title and description.
      head: [
        { tag: 'meta', attrs: { property: 'og:image', content: 'https://paulbouwer.github.io/hello-kubernetes/og.png' } },
        { tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
        { tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
        {
          tag: 'meta',
          attrs: { property: 'og:image:alt', content: "hello-kubernetes: the app's page, which shows the pod that answered" },
        },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
      ],
      customCss: ['./src/styles/theme.css', './src/styles/code.css'],
      components: {
        PageTitle: './src/components/PageTitle.astro',
        SocialIcons: './src/components/SocialIcons.astro',
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
        'docs/agents',
        'docs/licences',
      ],
      // The files for agents are written after the build (scripts/build-markdown.mjs),
      // so the validator can't see them. The Playwright checks load every one.
      plugins: [
        starlightLinksValidator({
          errorOnLocalLinks: true,
          exclude: ['/hello-kubernetes/llms.txt', '/hello-kubernetes/llms-full.txt', '/hello-kubernetes/values.schema.json'],
        }),
      ],
    }),
    preact(),
  ],
});
