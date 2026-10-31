// Browser checks for the built site. Run them in the Playwright image pinned in
// the Makefile (make site-test), so the browsers match @playwright/test.
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  reporter: [['list']],
  // Port 4322, so the checks can run while make site-dev serves on 4321.
  use: { baseURL: 'http://127.0.0.1:4322' },
  webServer: {
    command: 'npx astro preview --host 127.0.0.1 --port 4322',
    url: 'http://127.0.0.1:4322/hello-kubernetes/',
    reuseExistingServer: false,
  },
});
