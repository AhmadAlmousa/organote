// app.jsx — main shell, routing, tab bar, transitions

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accentHue": 175,
  "dark": true
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [tab, setTab] = React.useState('home'); // home | templates | settings
  const [stack, setStack] = React.useState([]); // overlays: {kind, id}

  const push = (overlay) => setStack((s) => [...s, overlay]);
  const pop  = () => setStack((s) => s.slice(0, -1));

  const accentHue = t.accentHue;
  const dark = t.dark;

  // root css vars
  const cssVars = {
    '--bg':       dark ? 'oklch(0.18 0.012 175)' : 'oklch(0.985 0.005 175)',
    '--bg-2':     dark ? 'oklch(0.16 0.010 175)' : 'oklch(0.96 0.006 175)',
    '--surface':  dark ? 'oklch(0.23 0.014 175)' : 'oklch(1 0 0)',
    '--surface-2':dark ? 'oklch(0.27 0.016 175)' : 'oklch(0.97 0.006 175)',
    '--border':   dark ? 'oklch(1 0 0 / 0.07)'   : 'oklch(0 0 0 / 0.07)',
    '--border-2': dark ? 'oklch(1 0 0 / 0.13)'   : 'oklch(0 0 0 / 0.13)',
    '--text':     dark ? 'oklch(0.95 0.005 175)' : 'oklch(0.18 0.012 175)',
    '--text-2':   dark ? 'oklch(0.72 0.012 175)' : 'oklch(0.40 0.014 175)',
    '--text-3':   dark ? 'oklch(0.52 0.010 175)' : 'oklch(0.55 0.014 175)',
    '--accent':   fmtAccent(accentHue),
    '--accent-soft': fmtAccentDim(accentHue, 0.18),
    '--accent-deep': `oklch(0.32 0.07 ${accentHue})`,
    '--shadow-1': dark ? '0 6px 24px rgba(0,0,0,0.45)' : '0 6px 24px rgba(0,0,0,0.10)',
    '--shadow-2': dark ? '0 22px 50px -10px rgba(0,0,0,0.6)' : '0 22px 50px -10px rgba(0,0,0,0.18)',
  };

  const TABS = [
    { id: 'home',      ic: 'home',     label: 'Home' },
    { id: 'templates', ic: 'template', label: 'Templates' },
    { id: 'settings',  ic: 'settings', label: 'Settings' },
  ];

  let current;
  if (tab === 'home') {
    current = <HomeScreen
      onOpenNote={(id) => push({ kind: 'view', id })}
      onNewNote={() => push({ kind: 'edit', isNew: true })}
      accentHue={accentHue} />;
  } else if (tab === 'templates') {
    current = <TemplatesScreen
      onOpenTemplate={(id) => push({ kind: 'tplBuild', id })}
      onNewTemplate={() => push({ kind: 'tplBuild', isNew: true })}
      accentHue={accentHue} />;
  } else {
    current = <SettingsScreen t={t} setTweak={setTweak} accentHue={accentHue} />;
  }

  return (
    <div className="phone-wrap">
      <AndroidDevice dark={dark} bg={cssVars['--bg']} width={412} height={892}>
        <div className="root" style={cssVars}>
          <div className={'root-fade root-fade-' + tab} key={tab}>
            {current}
          </div>

          {/* Overlay stack — each overlay slides up over the base screens */}
          {stack.map((o, i) => (
            <div key={i} className="overlay">
              {o.kind === 'view' && (
                <NoteViewer noteId={o.id} onBack={pop}
                  onEdit={() => { pop(); push({ kind: 'edit', id: o.id }); }}
                  accentHue={accentHue} />
              )}
              {o.kind === 'edit' && (
                <NoteEditor noteId={o.id} isNew={o.isNew} onClose={pop} accentHue={accentHue} />
              )}
              {o.kind === 'tplBuild' && (
                <TemplateBuilder templateId={o.id} onClose={pop} accentHue={accentHue} />
              )}
            </div>
          ))}

          {/* Bottom tab bar */}
          <div className="tabbar" data-noncommentable="">
            {TABS.map((tb) => {
              const on = tab === tb.id && stack.length === 0;
              return (
                <button key={tb.id} className={'tab' + (on ? ' on' : '')}
                        onClick={() => { setStack([]); setTab(tb.id); }}>
                  <span className="tab-ic">{React.createElement(I[tb.ic], { size: 22, stroke: on ? 2.2 : 1.8 })}</span>
                  <span className="tab-lbl">{tb.label}</span>
                  {on && <span className="tab-pill" />}
                </button>
              );
            })}
          </div>
        </div>
      </AndroidDevice>

      <TweaksPanel title="Tweaks">
        <TweakSection label="Theme">
          <TweakToggle label="Dark mode" value={t.dark} onChange={(v) => setTweak('dark', v)} />
        </TweakSection>
        <TweakSection label="Accent">
          <TweakColor label="Color" value={t.accentHue}
            options={[
              { value: 175, label: 'Mint',   color: fmtAccent(175) },
              { value: 295, label: 'Violet', color: fmtAccent(295) },
              { value: 25,  label: 'Coral',  color: fmtAccent(25) },
              { value: 95,  label: 'Lemon',  color: fmtAccent(95) },
              { value: 240, label: 'Azure',  color: fmtAccent(240) },
            ].map((o) => o.color)}
            onChange={(c) => {
              const map = { [fmtAccent(175)]: 175, [fmtAccent(295)]: 295, [fmtAccent(25)]: 25, [fmtAccent(95)]: 95, [fmtAccent(240)]: 240 };
              setTweak('accentHue', map[c] || 175);
            }} />
        </TweakSection>
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
