(function() {
  let currentState = {
    enabled: true,
    blacklist: [],
    themeCss: '',
    disable_site_theming: false
  };

  function isBlacklisted(hostname, blacklist) {
    return blacklist.some(pattern => {
      if (pattern.trim() === '') return false;
      return hostname.includes(pattern) || pattern.includes(hostname);
    });
  }

  function matchMozDocument(rule, currentUrl) {
    const conditions = rule.split(',').map(s => s.trim());
    for (let cond of conditions) {
      if (cond.startsWith('domain(')) {
        const match = cond.match(/domain\(['"]?([^'"\)]+)['"]?\)/);
        if (match && window.location.hostname.includes(match[1])) return true;
      } else if (cond.startsWith('url-prefix(')) {
        const match = cond.match(/url-prefix\(['"]?([^'"\)]+)['"]?\)/);
        if (match && currentUrl.startsWith(match[1])) return true;
      } else if (cond.startsWith('url(')) {
        const match = cond.match(/url\(['"]?([^'"\)]+)['"]?\)/);
        if (match && currentUrl === match[1]) return true;
      } else if (cond.startsWith('regexp(')) {
        const match = cond.match(/regexp\(['"]?([^'"\)]+)['"]?\)/);
        if (match) {
           try {
             if (new RegExp(match[1]).test(currentUrl)) return true;
           } catch(e) {}
        }
      }
    }
    return false;
  }

  function removeAllInjectedStyles() {
    const bridgeVars = document.getElementById('matuflow-bridge-vars');
    if (bridgeVars) bridgeVars.remove();
    document.querySelectorAll('style[id^="matuflow-baked-"]').forEach(el => el.remove());
  }

  function applyStyles() {
    removeAllInjectedStyles();

    if (!currentState.enabled) return;

    const hostname = window.location.hostname;
    if (isBlacklisted(hostname, currentState.blacklist)) return;

    // Apply global root variables
    if (currentState.themeCss) {
      let styleTag = document.createElement('style');
      styleTag.id = 'matuflow-bridge-vars';
      document.documentElement.appendChild(styleTag);
      const rootMatch = currentState.themeCss.match(/:root\s*{[\s\S]*?}/);
      if (rootMatch) {
        styleTag.textContent = rootMatch[0];
      }
    }

    // Apply baked themes if site theming is not disabled
    if (!currentState.disable_site_theming && window.MATUFLOW_BAKED_THEMES) {
      window.MATUFLOW_BAKED_THEMES.forEach((themeStr, index) => {
        const blocks = themeStr.split('@-moz-document');
        let injectedCss = '';
        
        for (let i = 1; i < blocks.length; i++) {
          const block = blocks[i];
          const openBraceIdx = block.indexOf('{');
          if (openBraceIdx === -1) continue;
          
          const ruleCondition = block.substring(0, openBraceIdx).trim();
          
          let braceCount = 1;
          let closeBraceIdx = -1;
          for (let j = openBraceIdx + 1; j < block.length; j++) {
            if (block[j] === '{') braceCount++;
            if (block[j] === '}') braceCount--;
            if (braceCount === 0) {
              closeBraceIdx = j;
              break;
            }
          }
          
          if (closeBraceIdx !== -1) {
            const innerCss = block.substring(openBraceIdx + 1, closeBraceIdx);
            if (matchMozDocument(ruleCondition, window.location.href)) {
              injectedCss += innerCss + '\\n';
            }
          }
        }
        
        if (injectedCss) {
          let themeStyle = document.createElement('style');
          themeStyle.id = `matuflow-baked-${index}`;
          themeStyle.textContent = injectedCss;
          document.documentElement.appendChild(themeStyle);
        }
      });
    }
  }

  // Initial Load
  chrome.storage.local.get(['matuflow_enabled', 'matuflow_blacklist', 'matuflow_theme', 'disable_site_theming'], (result) => {
    currentState.enabled = result.matuflow_enabled !== false;
    currentState.blacklist = result.matuflow_blacklist || [];
    currentState.themeCss = result.matuflow_theme || '';
    currentState.disable_site_theming = result.disable_site_theming || false;
    applyStyles();
  });

  // Listen for background updates
  chrome.storage.onChanged.addListener((changes) => {
    let shouldUpdate = false;
    if (changes.matuflow_enabled) {
      currentState.enabled = changes.matuflow_enabled.newValue !== false;
      shouldUpdate = true;
    }
    if (changes.matuflow_blacklist) {
      currentState.blacklist = changes.matuflow_blacklist.newValue || [];
      shouldUpdate = true;
    }
    if (changes.matuflow_theme) {
      currentState.themeCss = changes.matuflow_theme.newValue || '';
      shouldUpdate = true;
    }
    if (changes.disable_site_theming) {
      currentState.disable_site_theming = changes.disable_site_theming.newValue || false;
      shouldUpdate = true;
    }
    if (shouldUpdate) applyStyles();
  });
})();
