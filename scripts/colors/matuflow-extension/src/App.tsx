/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState, useEffect, useCallback, useMemo, ReactNode } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Palette, 
  RefreshCw, 
  FileCode, 
  Settings, 
  Layout, 
  Check, 
  Copy, 
  Terminal,
  ExternalLink,
  Info,
  ChevronRight,
  Sun,
  Moon
} from 'lucide-react';

const DEFAULT_CSS = `/* ==UserStyle==
@name           matugen global styles
@namespace      github.com/openstyles/stylus
@version        1.0.0
@description    mine, not yours
@author         bhimio
==/UserStyle== */

:root {
    /* Primary Colors */
    --primary: #C9D5EB;
    --on-primary: #3A4A62;
    --primary-container: #B7C7E5;
    --on-primary-container: #314159;
    --inverse-primary: #506079;
    --primary-fixed: #B7C7E5;
    --primary-fixed-dim: #A9B9D6;
    --on-primary-fixed: #1D2C43;
    --on-primary-fixed-variant: #3A4A62;

    /* Secondary Colors */
    --secondary: #BDC9C0;
    --on-secondary: #38433C;
    --secondary-container: #1E2822;
    --on-secondary-container: #9BA69E;
    --secondary-fixed: #E8F4EA;
    --secondary-fixed-dim: #D9E5DC;
    --on-secondary-fixed: #3F4B43;
    --on-secondary-fixed-variant: #5B675F;

    /* Tertiary Colors */
    --tertiary: #EAFBEB;
    --on-tertiary: #3D664C;
    --tertiary-container: #C2F4D0;
    --on-tertiary-container: #375D45;
    --tertiary-fixed: #C2F4D0;
    --tertiary-fixed-dim: #B4E6C2;
    --on-tertiary-fixed: #2B4A36;
    --on-tertiary-fixed-variant: #3F684D;

    /* Surface & Background */
    --background: #0A0E15;
    --on-background: #E0E5F3;
    --surface: #0A0E15;
    --on-surface: #E0E5F3;
    --surface-variant: #1E2633;
    --on-surface-variant: #A4ABBC;
    --surface-dim: #0A0E15;
    --surface-bright: #242D3B;
    --surface-container-lowest: #000000;
    --surface-container-low: #0F141C;
    --surface-container: #141A23;
    --surface-container-high: #19202B;
    --surface-container-highest: #1E2633;
    --inverse-surface: #FBF9FC;
    --inverse-on-surface: #51555D;
    --surface-tint: #C9D5EB;

    /* Error Colors */
    --error: #DE8680;
    --on-error: #3D1110;
    --error-container: #75312F;
    --on-error-container: #E4A5A1;

    /* Outline & Misc */
    --outline: #6D7585;
    --outline-variant: #404956;
    --shadow: #000000;
    --scrim: #000000;
}`;

export default function App() {
  const [cssCode, setCssCode] = useState(DEFAULT_CSS);
  const [activeTab, setActiveTab] = useState<'preview' | 'editor' | 'settings'>('preview');
  const [copied, setCopied] = useState(false);
  const [lastSync, setLastSync] = useState(new Date().toLocaleTimeString());

  // Parse CSS variables from root
  const variables = useMemo(() => {
    const vars: Record<string, string> = {};
    const regex = /--([\w-]+):\s*([^;]+);/g;
    let match;
    while ((match = regex.exec(cssCode)) !== null) {
      vars[`--${match[1]}`] = match[2].trim();
    }
    return vars;
  }, [cssCode]);

  const fetchThemeFromServer = useCallback(async () => {
    try {
      const response = await fetch('http://localhost:50131/api/theme');
      const data = await response.json();
      if (data.css) {
        setCssCode(data.css);
        setLastSync(new Date(data.updatedAt).toLocaleTimeString());
        
        // Push to extension storage if available so other tabs sync immediately
        if (typeof chrome !== 'undefined' && chrome.storage && chrome.storage.local) {
          chrome.storage.local.set({ 
            'matuflow_theme': data.css,
            'matuflow_updated_at': data.updatedAt 
          });
        }
      }
    } catch (err) {
      console.error("Failed to fetch theme from RAM:", err);
    }
  }, []);

  // Fetch on mount
  useEffect(() => {
    fetchThemeFromServer();
  }, [fetchThemeFromServer]);

  // Inject variables into :root
  useEffect(() => {
    const root = document.documentElement;
    Object.entries(variables).forEach(([name, value]) => {
      root.style.setProperty(name, value as string);
    });
  }, [variables]);

  const handleSync = () => {
    fetchThemeFromServer();
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(cssCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen flex flex-col md:flex-row text-[var(--on-surface)] selection:bg-[var(--primary-container)] selection:text-[var(--on-primary-container)]">
      {/* Dynamic Background */}
      <div className="fixed inset-0 bg-[var(--background)] transition-colors duration-500 -z-10" />

      {/* Navigation (Adaptive: Rail on MD+, Bottom Nav on Mobile/Popup) */}
      <nav className="w-full md:w-24 h-16 md:h-screen flex-shrink-0 flex flex-row md:flex-col items-center justify-around md:justify-center py-0 md:py-6 border-t md:border-t-0 md:border-r border-[var(--outline-variant)] bg-[var(--surface-container)] fixed bottom-0 md:relative z-40">
        <div className="hidden md:flex w-12 h-12 rounded-2xl bg-[var(--primary)] items-center justify-center mb-10 shadow-lg shadow-[var(--primary)]/20">
          <Palette className="text-[var(--on-primary)] w-6 h-6" />
        </div>

        <div className="flex flex-row md:flex-col gap-4 md:gap-4 items-center">
          <NavRailItem 
            active={activeTab === 'preview'} 
            onClick={() => setActiveTab('preview')}
            icon={<Layout className="w-5 h-5 md:w-6 md:h-6" />}
          />
          <NavRailItem 
            active={activeTab === 'editor'} 
            onClick={() => setActiveTab('editor')}
            icon={<FileCode className="w-5 h-5 md:w-6 md:h-6" />}
          />
          <NavRailItem 
            active={activeTab === 'settings'} 
            onClick={() => setActiveTab('settings')}
            icon={<Settings className="w-5 h-5 md:w-6 md:h-6" />}
          />
        </div>

        <div className="hidden md:flex mt-auto mb-4 p-1 rounded-full bg-[var(--primary-container)]">
           <div className="w-2 h-2 rounded-full bg-[var(--primary)] animate-pulse" />
        </div>
      </nav>

      {/* Main Content Area */}
      <main className="flex-grow flex flex-col min-h-0 overflow-hidden pb-16 md:pb-0">
        {/* Header - Narrower for extension popup */}
        <header className="h-14 md:h-20 flex-shrink-0 flex items-center justify-between px-4 md:px-10 bg-transparent">
          <div className="flex items-center gap-2 md:gap-3">
             <div className="status-badge text-[9px] md:text-sm px-2 py-0.5">MatuFlow</div>
             <div className="w-1.5 h-1.5 rounded-full bg-[var(--primary)] animate-pulse md:hidden" />
          </div>
          <div className="flex items-center gap-2 md:gap-4">
            <span className="text-[9px] md:text-xs font-mono tabular-nums opacity-60 bg-[var(--surface-container-highest)] px-2 py-1 rounded-md">{lastSync}</span>
          </div>
        </header>

        {/* Scrollable Body - Responsive margins */}
        <div className="flex-grow overflow-y-auto px-4 md:px-10 pb-10 max-w-7xl w-full mx-auto custom-scrollbar">
          <AnimatePresence mode="wait">
            {activeTab === 'preview' && (
              <motion.div 
                key="preview"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                className="flex flex-col gap-6 md:gap-12"
              >
                {/* Hero Section */}
                <div className="pt-2">
                  <h1 className="text-4xl md:text-6xl font-black uppercase italic tracking-tighter leading-none text-[var(--on-surface)]">
                    Theme<br />Ready.
                  </h1>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
                  {/* Configuration Card */}
                  <div className="md3-card p-6">
                    <h2 className="card-label">Engine Status</h2>
                    <div className="space-y-4">
                      <div className="flex justify-between items-center">
                        <span className="text-xs font-bold uppercase opacity-60">Source File</span>
                        <span className="text-[10px] font-mono opacity-40">wal/colors.css</span>
                      </div>
                      
                      <div className="p-3 rounded-xl bg-[var(--surface-container-highest)] border border-[var(--outline-variant)]">
                         <div className="flex items-center justify-between">
                            <span className="text-[10px] font-bold uppercase opacity-40">Live Sync</span>
                            <div className="w-2 h-2 rounded-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.5)]" />
                         </div>
                      </div>

                      <button 
                         onClick={handleSync}
                         className="w-full md3-button-primary py-3 text-xs"
                      >
                        Force Sync
                      </button>
                    </div>
                  </div>

                  {/* Variables Preview Card - Condensed for popup */}
                  <div className="md3-card p-6">
                    <h2 className="card-label">Variables ({Object.keys(variables).length})</h2>
                    <div className="space-y-1 overflow-y-auto max-h-[200px] pr-2 custom-scrollbar">
                      {Object.entries(variables).slice(0, 8).map(([name, val]) => (
                        <div key={name} className="flex items-center justify-between py-2 border-b border-black/5 last:border-0 contrast-50">
                           <span className="font-mono text-[9px] text-[var(--primary)] font-bold truncate max-w-[120px]">{name}</span>
                           <div 
                             className="w-4 h-4 rounded-full border border-black/10 flex-shrink-0" 
                             style={{ backgroundColor: val }}
                           />
                        </div>
                      ))}
                    </div>
                  </div>

                <div className="md3-card md:col-span-2 flex flex-col gap-6 bg-[var(--primary-container)] text-[var(--on-primary-container)] border-none p-5 md:p-8">
                     <div className="space-y-3 text-center md:text-left">
                        <h3 className="text-xl md:text-2xl font-black uppercase italic tracking-tighter">Container Check</h3>
                        <p className="text-[10px] md:text-xs opacity-80 leading-relaxed max-w-md mx-auto md:mx-0">
                          Secondary and tertiary tones inherited from the system theme via MatuFlow.
                        </p>
                        <div className="flex justify-center md:justify-start gap-4">
                           <button className="bg-[var(--on-primary-container)] text-[var(--primary-container)] px-5 py-2 rounded-full font-bold text-[9px] md:text-[10px] uppercase tracking-widest">
                               Primary
                           </button>
                           <button className="border border-[var(--on-primary-container)] px-5 py-2 rounded-full font-bold text-[9px] md:text-[10px] uppercase tracking-widest">
                               Outline
                           </button>
                        </div>
                     </div>
                  </div>
                </div>

                <footer className="pt-4 text-[9px] font-bold uppercase tracking-widest opacity-30 text-center">
                  Theme Bridge Active • v2.4
                </footer>
              </motion.div>
            )}

            {activeTab === 'editor' && (
              <motion.div 
                key="editor"
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.98 }}
                className="h-full flex flex-col pt-2"
              >
                <div className="md3-card flex-grow min-h-[400px] md:min-h-[600px] flex flex-col p-0 overflow-hidden border-2 border-black/10">
                  <div className="px-4 py-3 bg-white/50 backdrop-blur border-b border-black/5 flex justify-between items-center text-[10px] md:text-xs">
                    <span className="font-bold uppercase tracking-widest opacity-60">Source Editor</span>
                    <div className="flex items-center gap-2">
                       <span className="w-2 h-2 rounded-full bg-green-500" />
                       <span className="font-bold opacity-40">SYNCED</span>
                    </div>
                  </div>
                  <textarea 
                    value={cssCode}
                    onChange={(e) => setCssCode(e.target.value)}
                    className="flex-grow p-4 md:p-8 font-mono text-[10px] md:text-sm bg-transparent focus:outline-none resize-none leading-relaxed"
                    placeholder="Paste CSS variables here..."
                  />
                  <div className="p-4 bg-white/50 backdrop-blur border-t border-black/5 flex justify-end gap-3">
                    <button 
                       onClick={() => setCssCode(DEFAULT_CSS)}
                       className="text-[10px] md:text-xs font-bold uppercase px-3 py-2 hover:bg-black/5 rounded-lg transition-colors"
                    >
                      Reset
                    </button>
                    <button className="md3-button-primary text-[10px] px-4 py-2">Push</button>
                  </div>
                </div>
              </motion.div>
            )}

            {activeTab === 'settings' && (
              <motion.div 
                key="settings"
                initial={{ opacity: 0, x: 40 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 40 }}
                className="pt-4 grid grid-cols-1 md:grid-cols-2 gap-8"
              >
                <div className="md3-card col-span-full">
                   <h2 className="card-label">Global Web Injection</h2>
                   <div className="bg-[var(--primary-container)] text-[var(--on-primary-container)] p-6 rounded-2xl border-none flex flex-col md:flex-row gap-6 items-center">
                      <div className="flex-grow">
                         <h3 className="text-xl font-black uppercase mb-2">Extension Active</h3>
                         <p className="text-sm opacity-80 mb-4">
                            You are currently viewing the MatuFlow dashboard directly from your browser extension. 
                            Injection is active on all open tabs.
                         </p>
                         <div className="flex gap-4">
                            <div className="flex items-center gap-2 text-xs font-bold bg-white/20 px-3 py-2 rounded-lg">
                               <Check className="w-4 h-4" /> manifest.json ready
                            </div>
                            <div className="flex items-center gap-2 text-xs font-bold bg-white/20 px-3 py-2 rounded-lg">
                               <Check className="w-4 h-4" /> inject.js ready
                            </div>
                         </div>
                      </div>
                      <div className="flex-shrink-0 w-full md:w-auto">
                         <ol className="text-xs space-y-2 font-medium opacity-90 list-decimal list-inside">
                            <li>Download project ZIP</li>
                            <li>Go to <code>chrome://extensions</code></li>
                            <li>Enable <b>Developer Mode</b></li>
                            <li>Click <b>Load Unpacked</b></li>
                            <li>Select the <code>/extension</code> folder</li>
                         </ol>
                      </div>
                   </div>
                </div>

                <div className="md3-card col-span-full">
                  <h2 className="card-label">Python Bridge Service</h2>
                  <div className="bg-[var(--surface-container-highest)] p-6 rounded-2xl border border-black/5">
                    <p className="text-sm opacity-70 mb-4">
                      Download <strong>bridge.py</strong> and run it locally to sync your system theme. 
                      It uses the standard library for zero dependencies.
                    </p>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                       <div className="bg-black/20 p-4 rounded-xl font-mono text-xs overflow-x-auto selection:bg-white/10">
                          <p className="text-[var(--primary)] mb-2"># Post-theme (Matugen)</p>
                          <pre className="text-[var(--on-surface-variant)]">
                             python3 bridge.py --reload --file path/to/css
                          </pre>
                       </div>
                       <div className="bg-black/20 p-4 rounded-xl font-mono text-xs overflow-x-auto selection:bg-white/10">
                          <p className="text-[var(--primary)] mb-2"># Background Service</p>
                          <pre className="text-[var(--on-surface-variant)]">
                             python3 bridge.py --watch
                          </pre>
                       </div>
                    </div>
                    <div className="flex items-center gap-2 text-xs font-bold text-[var(--primary)]">
                       <Terminal className="w-4 h-4" />
                       ROOT API: http://localhost:50131/api/bridge/reload
                    </div>
                  </div>
                </div>

                <div className="md3-card">
                  <h2 className="card-label">App Behavior</h2>
                  <div className="space-y-4">
                    <ToggleItem label="Force Root Proxy" />
                    <ToggleItem label="Bypass CSP" active />
                    <ToggleItem label="Silent Syncing" />
                  </div>
                </div>

                <div className="md3-card border-red-500/10 bg-red-500/5">
                  <h2 className="card-label text-red-500">Danger Zone</h2>
                  <p className="text-sm font-medium mb-6 opacity-70">
                    Irreversible actions related to the local filesystem bridge.
                  </p>
                  <button className="w-full bg-red-500 text-white font-bold py-3 rounded-2xl hover:bg-red-600 transition-colors shadow-lg shadow-red-500/20">
                     Kill Theme Bridge [PID: 4812]
                  </button>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </main>

      {/* Persistent Copy Action - Adjusted for visibility */}
      <div className="fixed bottom-20 md:bottom-6 right-6 z-50 group">
        <button 
          onClick={handleCopy}
          className="w-10 h-10 md:w-14 md:h-14 rounded-2xl bg-[var(--primary)] text-[var(--on-primary)] shadow-2xl flex items-center justify-center hover:scale-110 active:scale-95 transition-transform"
        >
          {copied ? <Check className="w-4 h-4 md:w-6 md:h-6" /> : <Copy className="w-4 h-4 md:w-6 md:h-6" />}
          <div className="absolute right-full mr-4 px-3 py-1 rounded-lg bg-[var(--on-surface)] text-[var(--surface)] text-[9px] font-bold whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none uppercase">
             Copy CSS
          </div>
        </button>
      </div>
    </div>
  );
}

function NavRailItem({ active, icon, onClick }: { active: boolean; icon: ReactNode; onClick: () => void }) {
  return (
    <button 
      onClick={onClick}
      className={`w-14 h-14 rounded-3xl flex items-center justify-center transition-all duration-300 relative group
        ${active ? 'text-[var(--primary)]' : 'hover:bg-[var(--primary)]/10 text-[var(--on-surface)] opacity-40 hover:opacity-100'}
      `}
    >
      {active && (
        <motion.div 
          layoutId="rail-indicator"
          className="absolute inset-0 bg-[var(--primary-container)] rounded-3xl -z-10"
          initial={false}
          transition={{ type: 'spring', stiffness: 300, damping: 30 }}
        />
      )}
      <div className={`transition-transform duration-300 ${active ? 'scale-110' : 'group-hover:scale-105'}`}>
        {icon}
      </div>
    </button>
  );
}

function SettingsBlock({ title, value }: { title: string, value: string }) {
  return (
    <div className="p-4 rounded-2xl bg-[var(--surface-container-highest)] border border-black/5">
      <p className="text-[10px] font-bold opacity-40 uppercase tracking-widest mb-1">{title}</p>
      <p className="text-xl font-black">{value}</p>
    </div>
  );
}

function ToggleItem({ label, active = false }: { label: string, active?: boolean }) {
  return (
    <div className="flex items-center justify-between py-2 border-b border-black/5 last:border-0 hover:bg-black/[0.02] px-2 -mx-2 rounded-lg transition-colors">
      <span className="text-sm font-semibold">{label}</span>
      <Toggle active={active} />
    </div>
  );
}

function Toggle({ active = false }: { active?: boolean }) {
  const [isOn, setIsOn] = useState(active);
  return (
    <button 
      onClick={() => setIsOn(!isOn)}
      className={`w-13 h-8 rounded-full p-1 transition-colors duration-300 relative
        ${isOn ? 'bg-[var(--primary)]' : 'bg-black/10'}
      `}
    >
      <div className={`w-6 h-6 rounded-full bg-white shadow-sm transition-transform duration-300 ${isOn ? 'translate-x-5' : 'translate-x-0'}`} />
    </button>
  );
}
