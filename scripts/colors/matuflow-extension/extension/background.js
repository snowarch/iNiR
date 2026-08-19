/**
 * MatuFlow Background Service Worker
 * Handles fetching theme from local bridge to avoid CORS/LocalNetwork CORS popups in content scripts.
 */

const BRIDGE_URL = 'http://localhost:3000/api/theme';
let pollInterval = null;

async function fetchAndStoreTheme() {
  try {
    // Add cache-buster to bypass any middleman caching
    const cacheBuster = `?t=${Date.now()}`;
    const response = await fetch(BRIDGE_URL + cacheBuster);
    const data = await response.json();
    
    if (data.css) {
      // Small optimization: Only set if changed
      chrome.storage.local.get(['matuflow_updated_at'], (result) => {
        if (result.matuflow_updated_at !== data.updatedAt) {
          chrome.storage.local.set({ 
            'matuflow_theme': data.css,
            'matuflow_updated_at': data.updatedAt 
          });
        }
      });
    }
  } catch (e) {
    // Silent fail if bridge is down
  }
}

// MV3 Service Workers hibernate. Using multiple triggers to wake it up.

// 1. Periodic poll (for when browser is active)
setInterval(fetchAndStoreTheme, 2000); 

// 2. Alarm fallback (MV3 recommended for background tasks)
chrome.alarms.create('sync_theme', { periodInMinutes: 1 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'sync_theme') {
    fetchAndStoreTheme();
  }
});

// 3. Activity triggers (Wake up on tab changes/navigation)
chrome.tabs.onActivated.addListener(fetchAndStoreTheme);
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === 'complete') fetchAndStoreTheme();
});
chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.get(['matuflow_enabled', 'matuflow_blacklist', 'disable_site_theming'], (result) => {
    const defaults = {};
    if (result.matuflow_enabled === undefined) defaults.matuflow_enabled = true;
    if (result.matuflow_blacklist === undefined) defaults.matuflow_blacklist = [];
    if (result.disable_site_theming === undefined) defaults.disable_site_theming = false;
    
    if (Object.keys(defaults).length > 0) {
      chrome.storage.local.set(defaults);
    }
  });
  fetchAndStoreTheme();
});
chrome.runtime.onStartup.addListener(fetchAndStoreTheme);
