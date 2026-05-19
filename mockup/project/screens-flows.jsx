// screens-flows.jsx — NoteViewer, NoteEditor, TemplateBuilder

// ───────── Tap-to-copy ripple field ─────────
function CopyField({ label, value, mono, mask, accentHue }) {
  const [copied, setCopied] = React.useState(false);
  const [ripples, setRipples] = React.useState([]);
  const [reveal, setReveal] = React.useState(false);
  const idRef = React.useRef(0);

  const onTap = (e) => {
    const r = e.currentTarget.getBoundingClientRect();
    const id = ++idRef.current;
    const x = e.clientX - r.left;
    const y = e.clientY - r.top;
    setRipples((rs) => [...rs, { id, x, y }]);
    setTimeout(() => setRipples((rs) => rs.filter((p) => p.id !== id)), 650);
    setCopied(true);
    setTimeout(() => setCopied(false), 1400);
  };

  return (
    <div className="cf" onClick={onTap}
         style={{ '--c': fmtAccent(accentHue), '--c-soft': fmtAccentDim(accentHue, 0.18) }}>
      <div className="cf-head">
        <span className="cf-label">{label}</span>
        <div className="cf-actions">
          {mask && (
            <button className="cf-eye" onClick={(e) => { e.stopPropagation(); setReveal((v) => !v); }}>
              {reveal ? 'hide' : 'show'}
            </button>
          )}
          <span className={'cf-copy ' + (copied ? 'on' : '')}>
            {copied ? (
              <>
                {React.createElement(I.check, { size: 14, stroke: 2.6 })}
                <span>copied</span>
              </>
            ) : (
              <>
                {React.createElement(I.copy, { size: 14 })}
                <span>tap to copy</span>
              </>
            )}
          </span>
        </div>
      </div>
      <div className={'cf-val' + (mono ? ' mono' : '')}>
        {mask && !reveal ? '•'.repeat(Math.min(14, String(value).length)) : value}
      </div>
      <div className="cf-ripples">
        {ripples.map((p) => (
          <span key={p.id} className="cf-ripple" style={{ left: p.x, top: p.y }} />
        ))}
      </div>
    </div>
  );
}

// ───────── NOTE VIEWER ─────────
function NoteViewer({ noteId, onBack, onEdit, accentHue }) {
  const note = NOTES.find((n) => n.id === noteId) || NOTES[0];
  const t = TEMPLATES.find((x) => x.id === note.template);
  const cat = CATEGORIES.find((c) => c.id === note.category) || { hue: accentHue };
  const [shared, setShared] = React.useState(false);

  return (
    <div className="scr">
      <div className="nv-top" style={{ '--cat': fmtAccent(cat.hue), '--cat-soft': fmtAccentDim(cat.hue, 0.25) }}>
        <div className="nv-top-grad" />
        <div className="nv-bar">
          <button className="scr-icon-btn" onClick={onBack}>
            {React.createElement(I.back, { size: 20 })}
          </button>
          <div className="nv-bar-actions">
            <button className="scr-icon-btn" onClick={() => { setShared(true); setTimeout(() => setShared(false), 1500); }}>
              {React.createElement(I.share, { size: 18 })}
            </button>
            <button className="scr-icon-btn" onClick={onEdit}>
              {React.createElement(I.edit, { size: 18 })}
            </button>
            <button className="scr-icon-btn">
              {React.createElement(I.more, { size: 18 })}
            </button>
          </div>
        </div>
        <div className="nv-header">
          <div className="nv-tpl-chip">
            {React.createElement(I[t.icon], { size: 14 })}
            <span>{t.name}</span>
          </div>
          <div className="nv-title">{note.title}</div>
          <div className="nv-meta">
            <span>Updated {note.updated}</span>
            <span className="dot">·</span>
            <span>{t.fields.length} fields</span>
            {note.favorite && (<>
              <span className="dot">·</span>
              <span style={{ color: fmtAccent(accentHue) }}>★ favorite</span>
            </>)}
          </div>
        </div>
      </div>

      <div className="nv-body">
        <div className="nv-hint">
          {React.createElement(I.sparkles, { size: 14 })}
          <span>Tap any field to copy its value</span>
        </div>
        {(note.records || []).map((rec, ri) => (
          <div key={ri} className="rec-card">
            <div className="rec-card-head">
              <div className="rec-card-name">
                <span className="rec-card-index">#{ri + 1}</span>
                <span>{rec.name}</span>
              </div>
              <button className="rec-card-copy" aria-label="Copy all">
                {React.createElement(I.copy, { size: 14 })}
              </button>
            </div>
            <div className="rec-card-fields">
              {t.fields.map((f, fi) => (
                <CopyRow key={f.id} label={f.label}
                  value={rec.data[f.key]} mono={f.mono}
                  mask={f.type === 'password'} accentHue={accentHue}
                  last={fi === t.fields.length - 1} />
              ))}
            </div>
          </div>
        ))}

        <div className="nv-share-row">
          <button className="nv-share-btn" onClick={() => { setShared(true); setTimeout(() => setShared(false), 1500); }}
                  style={{ background: fmtAccent(accentHue), color: '#062019' }}>
            {React.createElement(I.share, { size: 16 })}
            <span>Share as plain text</span>
          </button>
          <div className="nv-share-hint">
            Frontmatter & schema get stripped automatically.
          </div>
        </div>
      </div>

      {shared && (
        <div className="toast">
          {React.createElement(I.check, { size: 16, stroke: 2.6 })}
          <span>Copied clean text to share sheet</span>
        </div>
      )}
    </div>
  );
}

// ───────── NOTE EDITOR ─────────
function NoteEditor({ noteId, isNew, onClose, accentHue }) {
  const seedNote = noteId ? NOTES.find((n) => n.id === noteId) : null;
  const templateId = seedNote ? seedNote.template : 'server-creds';
  const t = TEMPLATES.find((x) => x.id === templateId);
  const seedRec = seedNote && seedNote.records && seedNote.records[0];
  const [values, setValues] = React.useState(() =>
    seedRec ? { ...seedRec.data } :
    t.fields.reduce((acc, f) => ({ ...acc, [f.key]: '' }), {})
  );
  const [title, setTitle] = React.useState(seedNote ? seedNote.title : '');
  const [saved, setSaved] = React.useState('saved');

  // simulate debounced autosave
  React.useEffect(() => {
    setSaved('typing');
    const id = setTimeout(() => {
      setSaved('saving');
      setTimeout(() => setSaved('saved'), 400);
    }, 1100);
    return () => clearTimeout(id);
  }, [values, title]);

  return (
    <div className="scr">
      <div className="ne-top">
        <div className="nv-bar">
          <button className="scr-icon-btn" onClick={onClose}>
            {React.createElement(I.close, { size: 20 })}
          </button>
          <div className="ne-save" data-state={saved}>
            <span className="ne-save-dot" />
            <span>
              {saved === 'typing' ? 'editing…' :
               saved === 'saving' ? 'auto-saving…' : 'saved · 2s ago'}
            </span>
          </div>
          <button className="scr-icon-btn">
            {React.createElement(I.more, { size: 18 })}
          </button>
        </div>
        <div className="ne-tpl-row">
          <div className="ne-tpl-chip">
            {React.createElement(I[t.icon], { size: 14 })}
            <span>{t.name}</span>
            <span className="dot">·</span>
            <span>{t.fields.length} fields</span>
          </div>
        </div>
        <input className="ne-title" placeholder="Untitled note"
               value={title} onChange={(e) => setTitle(e.target.value)} />
      </div>

      <div className="ne-body">
        {t.fields.map((f) => (
          <FormField key={f.id} field={f} value={values[f.key] || ''}
                     onChange={(v) => setValues((s) => ({ ...s, [f.key]: v }))}
                     accentHue={accentHue} />
        ))}

        <div className="ne-frontmatter">
          <div className="ne-fm-head">
            <span>generated frontmatter</span>
            <span className="muted">read-only preview</span>
          </div>
          <pre className="ne-fm-pre">
{`---
template: ${t.id}
updated: 2026-05-12T09:30:00Z
title: ${title || '(empty)'}
---

\`\`\`organote-data
${t.fields.map((f) => `${f.key}: ${values[f.key] ? (f.type === 'password' ? '••••••••' : values[f.key]) : '~'}`).join('\n')}
\`\`\``}
          </pre>
        </div>
      </div>
    </div>
  );
}

// ───────── FormField (in editor) ─────────
function FormField({ field, value, onChange, accentHue }) {
  const f = field;
  const ic = I[FIELD_TYPES.find((t) => t.id === f.type)?.icon] || I.type_text;

  // Regex validation
  let regexState = null;
  if (f.type === 'regex' && f.pattern) {
    try {
      const re = new RegExp(f.pattern);
      regexState = value === '' ? 'idle' : re.test(value) ? 'ok' : 'fail';
    } catch (e) { regexState = 'idle'; }
  }

  const baseInput = (
    <input
      className={'ff-input' + (f.mono ? ' mono' : '')}
      type={f.type === 'password' ? 'password' : 'text'}
      placeholder={f.hint || `Enter ${f.label.toLowerCase()}`}
      value={value} onChange={(e) => onChange(e.target.value)}
    />
  );

  return (
    <div className={'ff' + (regexState ? ' regex-' + regexState : '')}
         style={{ '--c': fmtAccent(accentHue), '--c-soft': fmtAccentDim(accentHue, 0.18) }}>
      <div className="ff-head">
        <span className="ff-icon">{React.createElement(ic, { size: 14 })}</span>
        <span className="ff-label">{f.label}</span>
        {f.required && <span className="ff-req">required</span>}
        {f.type === 'regex' && regexState === 'ok' && (
          <span className="ff-ok">{React.createElement(I.check, { size: 12, stroke: 3 })} valid</span>
        )}
        {f.type === 'regex' && regexState === 'fail' && (
          <span className="ff-bad">doesn't match</span>
        )}
      </div>
      {f.type === 'dropdown' ? (
        <div className="ff-select-wrap">
          <select className="ff-input" value={value} onChange={(e) => onChange(e.target.value)}>
            <option value="">— choose —</option>
            {f.options.map((o) => <option key={o} value={o}>{o}</option>)}
          </select>
          <span className="ff-chev">{React.createElement(I.chevD, { size: 14 })}</span>
        </div>
      ) : baseInput}
      {f.type === 'regex' && (
        <div className="ff-regex-meta">
          <code>{f.pattern}</code>
          <span className="muted">{f.hint}</span>
        </div>
      )}
    </div>
  );
}

// ───────── TEMPLATE BUILDER (with reorder) ─────────
function TemplateBuilder({ templateId, onClose, accentHue }) {
  const seed = templateId ? TEMPLATES.find((t) => t.id === templateId) : null;
  const [name, setName] = React.useState(seed ? seed.name : '');
  const [fields, setFields] = React.useState(
    seed ? seed.fields.map((f) => ({ ...f })) :
           [{ id: 'new1', key: 'server', label: 'Server name', type: 'text' }]
  );
  const [openPicker, setOpenPicker] = React.useState(false);
  const [shifted, setShifted] = React.useState({}); // id -> direction
  const listRef = React.useRef(null);

  const reorder = (idx, dir) => {
    const j = idx + dir;
    if (j < 0 || j >= fields.length) return;
    const a = fields[idx], b = fields[j];
    // play spring on both
    setShifted({ [a.id]: dir * 1, [b.id]: -dir * 1 });
    setTimeout(() => {
      setFields((arr) => {
        const next = arr.slice();
        next[idx] = b; next[j] = a; return next;
      });
      setShifted({});
    }, 230);
  };

  const removeField = (id) => setFields((arr) => arr.filter((f) => f.id !== id));
  const addField = (type) => {
    const t = FIELD_TYPES.find((x) => x.id === type);
    setFields((arr) => [...arr, {
      id: 'new' + Date.now(), key: type + (arr.length + 1),
      label: t.name + ' field', type,
      ...(type === 'regex' ? { pattern: '.*', hint: 'Any value' } : {}),
      ...(type === 'dropdown' ? { options: ['Option A', 'Option B'] } : {}),
    }]);
    setOpenPicker(false);
  };

  return (
    <div className="scr">
      <div className="ne-top">
        <div className="nv-bar">
          <button className="scr-icon-btn" onClick={onClose}>
            {React.createElement(I.close, { size: 20 })}
          </button>
          <div className="ne-save" data-state="saved">
            <span className="ne-save-dot" />
            <span>{seed ? 'editing template' : 'new template'}</span>
          </div>
          <button className="scr-icon-btn"
                  style={{ background: fmtAccent(accentHue), color: '#062019', borderColor: 'transparent' }}>
            {React.createElement(I.check, { size: 18, stroke: 2.6 })}
          </button>
        </div>
        <input className="ne-title" placeholder="Template name"
               value={name} onChange={(e) => setName(e.target.value)} />
        <div className="tb-render-row">
          <span className="muted">Renders notes as</span>
          <div className="tb-seg" data-noncommentable="">
            <span className="tb-seg-th" style={{ background: fmtAccentDim(accentHue, 0.22) }} />
            <button className="on">Cards</button>
            <button>Table</button>
            <button>Grid</button>
          </div>
        </div>
      </div>

      <div className="ne-body">
        <div className="scr-section-h" style={{ paddingLeft: 0, paddingRight: 0 }}>
          <span>Fields · {fields.length}</span>
          <span className="muted">Drag handle to reorder</span>
        </div>

        <div className="tb-list" ref={listRef}>
          {fields.map((f, idx) => (
            <FieldRow key={f.id} field={f} idx={idx}
              total={fields.length}
              shifted={shifted[f.id]}
              onUp={() => reorder(idx, -1)}
              onDown={() => reorder(idx, 1)}
              onRemove={() => removeField(f.id)}
              accentHue={accentHue} />
          ))}
        </div>

        <button className="tb-add" onClick={() => setOpenPicker(true)}
                style={{ '--c': fmtAccent(accentHue), '--c-soft': fmtAccentDim(accentHue, 0.18) }}>
          <span className="tb-add-plus">{React.createElement(I.plus, { size: 16, stroke: 2.4 })}</span>
          <span>Add field</span>
        </button>
      </div>

      {openPicker && (
        <div className="picker-veil" onClick={() => setOpenPicker(false)}>
          <div className="picker" onClick={(e) => e.stopPropagation()}>
            <div className="picker-handle" />
            <div className="picker-title">Add a field</div>
            <div className="picker-sub">Choose a field type</div>
            <div className="picker-grid">
              {FIELD_TYPES.map((ft) => (
                <button key={ft.id} className="picker-card" onClick={() => addField(ft.id)}
                  style={{ '--c': fmtAccent(accentHue), '--c-soft': fmtAccentDim(accentHue, 0.18) }}>
                  <span className="picker-icon">{React.createElement(I[ft.icon], { size: 18 })}</span>
                  <span>{ft.name}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function FieldRow({ field, idx, total, shifted, onUp, onDown, onRemove, accentHue }) {
  const f = field;
  const ic = I[FIELD_TYPES.find((t) => t.id === f.type)?.icon] || I.type_text;
  const [open, setOpen] = React.useState(f.type === 'regex');

  return (
    <div className={'tbr' + (shifted ? ' shift-' + (shifted > 0 ? 'down' : 'up') : '')}
         style={{ '--c': fmtAccent(accentHue), '--c-soft': fmtAccentDim(accentHue, 0.18) }}>
      <div className="tbr-main">
        <button className="tbr-grip" aria-label="Drag">
          {React.createElement(I.drag, { size: 16 })}
        </button>
        <div className="tbr-icon" style={{ color: fmtAccent(accentHue) }}>
          {React.createElement(ic, { size: 16 })}
        </div>
        <div className="tbr-body">
          <div className="tbr-label">{f.label}</div>
          <div className="tbr-key">
            <span className="muted">{f.key}</span>
            <span className="tbr-type">{FIELD_TYPES.find((t) => t.id === f.type)?.name || f.type}</span>
            {f.required && <span className="tbr-req">req</span>}
          </div>
        </div>
        <div className="tbr-arrows">
          <button onClick={onUp} disabled={idx === 0} aria-label="Move up">
            {React.createElement(I.chevU, { size: 14, stroke: 2.4 })}
          </button>
          <button onClick={onDown} disabled={idx === total - 1} aria-label="Move down">
            {React.createElement(I.chevD, { size: 14, stroke: 2.4 })}
          </button>
        </div>
      </div>
      {f.type === 'regex' && (
        <div className="tbr-regex">
          <div className="tbr-regex-row">
            <span className="tbr-regex-l">Pattern</span>
            <code className="tbr-regex-code">{f.pattern}</code>
          </div>
          <div className="tbr-regex-row">
            <span className="tbr-regex-l">Hint</span>
            <span className="tbr-regex-hint">{f.hint}</span>
          </div>
          <div className="tbr-regex-tester">
            <span className="tbr-regex-l">Live test</span>
            <RegexTester pattern={f.pattern} sample="10.0.4.18" accentHue={accentHue} />
          </div>
        </div>
      )}
    </div>
  );
}

function RegexTester({ pattern, sample, accentHue }) {
  const [val, setVal] = React.useState(sample);
  let state = 'idle';
  try {
    const re = new RegExp(pattern);
    state = val === '' ? 'idle' : re.test(val) ? 'ok' : 'fail';
  } catch (e) { state = 'idle'; }
  return (
    <div className={'rt rt-' + state}>
      <input className="rt-in mono" value={val} onChange={(e) => setVal(e.target.value)} />
      <span className="rt-state">
        {state === 'ok' && (<>
          {React.createElement(I.check, { size: 12, stroke: 3 })} matches
        </>)}
        {state === 'fail' && 'no match'}
        {state === 'idle' && 'idle'}
      </span>
    </div>
  );
}

// CopyRow — borderless variant of CopyField for use inside a record card
function CopyRow({ label, value, mono, mask, accentHue, last }) {
  const [copied, setCopied] = React.useState(false);
  const [ripples, setRipples] = React.useState([]);
  const [reveal, setReveal] = React.useState(false);
  const idRef = React.useRef(0);
  const onTap = (e) => {
    const r = e.currentTarget.getBoundingClientRect();
    const id = ++idRef.current;
    const x = e.clientX - r.left, y = e.clientY - r.top;
    setRipples((rs) => [...rs, { id, x, y }]);
    setTimeout(() => setRipples((rs) => rs.filter((p) => p.id !== id)), 650);
    setCopied(true);
    setTimeout(() => setCopied(false), 1200);
  };
  return (
    <div className={'cr' + (last ? ' last' : '') + (copied ? ' copied' : '')} onClick={onTap}
         style={{ '--c': fmtAccent(accentHue), '--c-soft': fmtAccentDim(accentHue, 0.18) }}>
      <div className="cr-l">
        <div className="cr-label">{label}</div>
        <div className={'cr-val' + (mono ? ' mono' : '')}>
          {mask && !reveal ? '•'.repeat(Math.min(14, String(value).length)) : value}
        </div>
      </div>
      <div className="cr-r">
        {mask && (
          <button className="cr-eye" onClick={(e) => { e.stopPropagation(); setReveal((v) => !v); }}>
            {reveal ? 'hide' : 'show'}
          </button>
        )}
        <span className={'cr-copy ' + (copied ? 'on' : '')}>
          {copied ? React.createElement(I.check, { size: 14, stroke: 2.6 })
                  : React.createElement(I.copy, { size: 13 })}
        </span>
      </div>
      <div className="cr-ripples">
        {ripples.map((p) => (
          <span key={p.id} className="cr-ripple" style={{ left: p.x, top: p.y }} />
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { NoteViewer, NoteEditor, TemplateBuilder, CopyField, CopyRow, FormField });
