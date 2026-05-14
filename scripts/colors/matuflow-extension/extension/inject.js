(function() {
  function applyCss(css) {
    if (!css) return;

    // Create or update a style tag at the top of the head
    let styleTag = document.getElementById('matuflow-bridge-vars');
    if (!styleTag) {
      styleTag = document.createElement('style');
      styleTag.id = 'matuflow-bridge-vars';
      document.documentElement.appendChild(styleTag);
    }

    // We only care about the :root block from the CSS
    const rootMatch = css.match(/:root\s*{[\s\S]*?}/);
    if (rootMatch) {
      styleTag.textContent = rootMatch[0];
    }
  }

  // Load initial theme from storage
  chrome.storage.local.get(['matuflow_theme'], (result) => {
    applyCss(result.matuflow_theme);
  });

  // Listen for background updates
  chrome.storage.onChanged.addListener((changes) => {
    if (changes.matuflow_theme) {
      applyCss(changes.matuflow_theme.newValue);
    }
  });
})();
