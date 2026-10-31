// Expressive Code, the code block renderer in Starlight. The colours and
// frame styles are in src/styles/code.css.
import { defineEcConfig } from '@astrojs/starlight/expressive-code';

const shells = new Set(['bash', 'sh', 'shell', 'zsh', 'console']);

// A command block with no title is titled "Terminal", which code.css shows
// with a terminal icon. A block marked `output`, such as ```text output, is
// shown as the quieter output of the command above it.
function blockKinds() {
  return {
    name: 'block-kinds',
    hooks: {
      preprocessMetadata: ({ codeBlock }) => {
        if (shells.has(codeBlock.language) && !codeBlock.props.title) {
          codeBlock.props.title = 'Terminal';
        }
      },
      postprocessRenderedBlock: ({ codeBlock, renderData }) => {
        if (codeBlock.metaOptions.getBoolean('output')) {
          const props = renderData.blockAst.properties;
          props.className = [...(props.className ?? []), 'output'];
        }
      },
    },
  };
}

export default defineEcConfig({
  themes: ['github-dark-default', 'github-light-default'],
  plugins: [blockKinds()],
  defaultProps: {
    // Commands show no window dots; src/styles/code.css adds a terminal icon.
    frame: 'auto',
  },
  styleOverrides: {
    borderRadius: '0.75rem',
    borderColor: 'var(--hk-code-border)',
    codeFontFamily: "'JetBrains Mono', ui-monospace, monospace",
    uiFontFamily: "'Inter', ui-sans-serif, system-ui, sans-serif",
    codeBackground: 'var(--hk-code-background)',
    frames: {
      editorTabBarBackground: 'var(--hk-code-header)',
      editorActiveTabBackground: 'var(--hk-code-header)',
      editorActiveTabIndicatorBottomColor: 'var(--sl-color-accent)',
      editorActiveTabIndicatorTopColor: 'transparent',
      editorTabBarBorderBottomColor: 'var(--hk-code-border)',
      terminalTitlebarBackground: 'var(--hk-code-header)',
      terminalTitlebarBorderBottomColor: 'var(--hk-code-border)',
      terminalTitlebarDotsOpacity: '0',
      terminalBackground: 'var(--hk-code-background)',
      frameBoxShadowCssValue: 'none',
      inlineButtonBackground: 'var(--hk-code-header)',
    },
  },
});
