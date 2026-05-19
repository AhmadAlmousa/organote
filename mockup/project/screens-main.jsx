// screens-main.jsx — Home, Templates, Settings

const fmtAccent = (h) => `oklch(0.82 0.16 ${h})`;
const fmtAccentSoft = (h) => `oklch(0.32 0.07 ${h})`;
const fmtAccentDim = (h, a = 0.18) => `oklch(0.82 0.16 ${h} / ${a})`;

// ───────── shared note card ─────────
function NoteCard({ note, onOpen, onToggleFav, accentHue }) {
  const t = TEMPLATES.find((x) => x.id === note.template);
  const cat = CATEGORIES.find((c) => c.id === note.category) || { hue: accentHue };
  const recCount = note.records?.length || 0;
  return (
    <button className="org-card" onClick={onOpen}
      style={{ '--cat': fmtAccent(cat.hue), '--cat-soft': fmtAccentDim(cat.hue, 0.16) }}>
      <div className="org-card-bg" />
      <div className="org-card-row1">
        <div className="org-card-tpl">
          <span className="org-card-dot" />
          <span>{t.name}</span>
        </div>
        <span className={'org-card-fav' + (note.favorite ? ' on' : '')}
          role="button"
          onClick={(e) => { e.stopPropagation(); onToggleFav && onToggleFav(note.id); }}
          aria-label="Favorite">
          {React.createElement(I.star, { size: 14 })}
        </span>
      </div>
      <div className="org-card-title">{note.title}</div>
      <div className="org-card-row2">
        <span className="org-card-cat">
          {cat.icon && React.createElement(I[cat.icon], { size: 11 })}
          <span>{cat.name}</span>
        </span>
        {recCount > 1 && (
          <span className="org-card-rec">{recCount} records</span>
        )}
        <span className="org-card-time">{note.updated}</span>
      </div>
      {note.tags && note.tags.length > 0 && (
        <div className="org-card-tags">
          {note.tags.map((tg) => (
            <span key={tg} className="org-card-tag">#{tg}</span>
          ))}
        </div>
      )}
    </button>
  );
}

// ───────── HOME ─────────
function HomeScreen({ onOpenNote, onNewNote, accentHue }) {
  const [cat, setCat] = React.useState('all');
  const [search, setSearch] = React.useState('');
  const visible = NOTES.filter((n) => {
    if (cat !== 'all' && n.category !== cat) return false;
    if (search) {
      const q = search.toLowerCase();
      const recHay = (n.records || []).flatMap((r) => [r.name, ...Object.values(r.data || {})]);
      const hay = [n.title, ...(n.tags || []), ...recHay].join(' ').toLowerCase();
      return hay.includes(q);
    }
    return true;
  });

  return (
    <div className="scr">
      <div className="scr-top">
        <div className="scr-greet">
          <div className="scr-greet-row">
            <Wordmark size={20} accent={fmtAccent(accentHue)} />
            <button className="scr-icon-btn" aria-label="Notifications">
              {React.createElement(I.bell, { size: 20 })}
            </button>
          </div>
          <div className="scr-hello">
            Good morning,<br />
            <span style={{ color: fmtAccent(accentHue) }}>Mahmoud</span>
          </div>
        </div>
        <div className="org-search">
          {React.createElement(I.search, { size: 18 })}
          <input type="text" placeholder="Search notes, fields, values…"
                 value={search} onChange={(e) => setSearch(e.target.value)} />
          <button className="org-search-filter"
                  style={{ background: fmtAccent(accentHue) }}>
            {React.createElement(I.filter, { size: 16 })}
          </button>
        </div>
        <div className="chip-row" data-noncommentable="">
          {CATEGORIES.map((c) => {
            const active = c.id === cat;
            return (
              <button key={c.id} className={'chip' + (active ? ' active' : '')}
                onClick={() => setCat(c.id)}
                style={{
                  '--ch': fmtAccent(c.hue),
                  '--ch-soft': fmtAccentDim(c.hue, 0.16),
                }}>
                {c.icon && React.createElement(I[c.icon], { size: 14 })}
                <span>{c.name}</span>
                <span className="chip-count">
                  {c.id === 'all' ? NOTES.length : NOTES.filter((n) => n.category === c.id).length}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="scr-section-h">
        <span>{visible.length} note{visible.length === 1 ? '' : 's'}</span>
        <span className="muted">Recent first</span>
      </div>

      <div className="note-list">
        {visible.map((n) => (
          <NoteCard key={n.id} note={n} onOpen={() => onOpenNote(n.id)} accentHue={accentHue} />
        ))}
        {visible.length === 0 && (
          <div className="empty">
            <div className="empty-emoji">∅</div>
            <div>Nothing matches “{search}” here.</div>
          </div>
        )}
      </div>

      <button className="fab" onClick={onNewNote}
        style={{ background: fmtAccent(accentHue), color: '#062019' }}>
        {React.createElement(I.plus, { size: 24, stroke: 2.4 })}
      </button>
    </div>
  );
}

// ───────── TEMPLATES ─────────
function TemplatesScreen({ onOpenTemplate, onNewTemplate, accentHue }) {
  return (
    <div className="scr">
      <div className="scr-top">
        <div className="scr-greet">
          <div className="scr-greet-row">
            <div className="scr-title">Templates</div>
            <button className="scr-icon-btn" onClick={onNewTemplate}
              style={{ background: fmtAccent(accentHue), color: '#062019', borderColor: 'transparent' }}>
              {React.createElement(I.plus, { size: 18, stroke: 2.4 })}
            </button>
          </div>
          <div className="scr-sub">Schemas that shape your notes.</div>
        </div>
      </div>

      <div className="tpl-summary">
        <div className="tpl-summary-row">
          <div className="tpl-stat">
            <div className="tpl-stat-num" style={{ color: fmtAccent(accentHue) }}>{TEMPLATES.length}</div>
            <div className="tpl-stat-label">templates</div>
          </div>
          <div className="tpl-stat-bar" />
          <div className="tpl-stat">
            <div className="tpl-stat-num">{NOTES.length}</div>
            <div className="tpl-stat-label">notes total</div>
          </div>
          <div className="tpl-stat-bar" />
          <div className="tpl-stat">
            <div className="tpl-stat-num">
              {TEMPLATES.reduce((s, t) => s + t.fields.length, 0)}
            </div>
            <div className="tpl-stat-label">fields</div>
          </div>
        </div>
      </div>

      <div className="scr-section-h">
        <span>Your templates</span>
        <span className="muted">Tap to edit schema</span>
      </div>

      <div className="tpl-list">
        {TEMPLATES.map((t) => (
          <button key={t.id} className="tpl-card" onClick={() => onOpenTemplate(t.id)}
            style={{ '--cat': fmtAccent(t.hue), '--cat-soft': fmtAccentDim(t.hue, 0.20) }}>
            <div className="tpl-icon">
              {React.createElement(I[t.icon], { size: 24 })}
            </div>
            <div className="tpl-card-body">
              <div className="tpl-card-name">{t.name}</div>
              <div className="tpl-card-desc">{t.desc}</div>
              <div className="tpl-card-meta">
                <span className="tpl-pill">{t.fields.length} fields</span>
                <span className="tpl-pill">{t.notes} notes</span>
                <span className="tpl-pill">Cards</span>
              </div>
            </div>
            <span className="tpl-card-arrow">
              {React.createElement(I.chevR, { size: 18 })}
            </span>
          </button>
        ))}
      </div>

      <div className="scr-section-h" style={{ marginTop: 4 }}>
        <span>Suggested</span>
        <span className="muted">From the community</span>
      </div>
      <div className="tpl-suggest">
        {['Recipe', 'Workout', 'API Key', 'Subscription'].map((n, i) => (
          <button key={n} className="tpl-suggest-card"
            style={{ '--hue': [25, 95, 175, 295][i] }}>
            <span className="tpl-suggest-dot" />
            <span>{n}</span>
            <span className="tpl-suggest-plus">+</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ───────── SETTINGS ─────────
function SettingsScreen({ t, setTweak, accentHue }) {
  const ACCENTS = [
    { name: 'Mint',   hue: 175, color: fmtAccent(175) },
    { name: 'Violet', hue: 295, color: fmtAccent(295) },
    { name: 'Coral',  hue:  25, color: fmtAccent( 25) },
    { name: 'Lemon',  hue:  95, color: fmtAccent( 95) },
    { name: 'Azure',  hue: 240, color: fmtAccent(240) },
  ];

  return (
    <div className="scr">
      <div className="scr-top">
        <div className="scr-greet">
          <div className="scr-title">Settings</div>
          <div className="scr-sub">Tune Organote to your taste.</div>
        </div>
      </div>

      <div className="set-profile">
        <div className="set-avatar" style={{ background: fmtAccent(accentHue), color: '#062019' }}>M</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="set-name">Mahmoud</div>
          <div className="set-mail">organote on-device · no sign-in</div>
        </div>
        <button className="set-chev">{React.createElement(I.chevR, { size: 18 })}</button>
      </div>

      <div className="set-section-label">Appearance</div>
      <div className="set-group">
        <div className="set-row">
          <div className="set-row-l">
            <span className="set-ico" style={{ color: fmtAccent(accentHue) }}>
              {React.createElement(I.palette, { size: 20 })}
            </span>
            <div>
              <div className="set-row-title">Accent color</div>
              <div className="set-row-sub">Used for highlights & FAB</div>
            </div>
          </div>
        </div>
        <div className="set-accent-row" data-noncommentable="">
          {ACCENTS.map((a) => {
            const on = t.accentHue === a.hue;
            return (
              <button key={a.hue} className={'set-accent' + (on ? ' on' : '')}
                onClick={() => setTweak('accentHue', a.hue)}
                style={{ '--c': a.color }}>
                <span className="set-accent-dot" />
                <span>{a.name}</span>
              </button>
            );
          })}
        </div>
        <div className="set-divider" />
        <div className="set-row">
          <div className="set-row-l">
            <span className="set-ico" style={{ color: fmtAccent(accentHue) }}>
              {React.createElement(I.sparkles, { size: 20 })}
            </span>
            <div>
              <div className="set-row-title">Theme</div>
              <div className="set-row-sub">{t.dark ? 'Dark · easy on the eyes' : 'Light · bright & airy'}</div>
            </div>
          </div>
          <button className="org-toggle" data-on={t.dark ? '1' : '0'}
                  onClick={() => setTweak('dark', !t.dark)}
                  style={{ '--c': fmtAccent(accentHue) }}>
            <i />
          </button>
        </div>
      </div>

      <div className="set-section-label">Library</div>
      <div className="set-group">
        {[
          { ic: 'cloud',     t: 'Sync & backup', s: 'Local-first · iCloud / Drive optional' },
          { ic: 'download',  t: 'Export library', s: 'Markdown · ZIP archive' },
          { ic: 'lock',      t: 'App lock',       s: 'Biometric on launch' },
        ].map((r, i, a) => (
          <React.Fragment key={r.t}>
            <div className="set-row">
              <div className="set-row-l">
                <span className="set-ico" style={{ color: fmtAccent(accentHue) }}>
                  {React.createElement(I[r.ic], { size: 20 })}
                </span>
                <div>
                  <div className="set-row-title">{r.t}</div>
                  <div className="set-row-sub">{r.s}</div>
                </div>
              </div>
              <span className="set-chev">{React.createElement(I.chevR, { size: 18 })}</span>
            </div>
            {i < a.length - 1 && <div className="set-divider" />}
          </React.Fragment>
        ))}
      </div>

      <div className="set-foot">
        <Wordmark size={16} accent={fmtAccent(accentHue)} />
        <span className="muted">v0.4.2 · build 187</span>
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen, TemplatesScreen, SettingsScreen, NoteCard,
  fmtAccent, fmtAccentSoft, fmtAccentDim });
