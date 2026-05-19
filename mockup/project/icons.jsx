// icons.jsx — Organote icon set. Stroke-based, currentColor.

const Icon = ({ size = 22, stroke = 1.8, children, style }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
       stroke="currentColor" strokeWidth={stroke}
       strokeLinecap="round" strokeLinejoin="round" style={style}>
    {children}
  </svg>
);

const I = {
  home: (p) => <Icon {...p}><path d="M3 11.5 12 4l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/></Icon>,
  template: (p) => <Icon {...p}><rect x="3" y="3" width="7" height="9" rx="1.6"/><rect x="14" y="3" width="7" height="5" rx="1.6"/><rect x="14" y="12" width="7" height="9" rx="1.6"/><rect x="3" y="16" width="7" height="5" rx="1.6"/></Icon>,
  settings: (p) => <Icon {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></Icon>,
  search: (p) => <Icon {...p}><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></Icon>,
  plus: (p) => <Icon {...p}><path d="M12 5v14M5 12h14"/></Icon>,
  back: (p) => <Icon {...p}><path d="M15 18l-6-6 6-6"/></Icon>,
  share: (p) => <Icon {...p}><path d="M4 12v8a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-8M16 6l-4-4-4 4M12 2v13"/></Icon>,
  edit: (p) => <Icon {...p}><path d="M12 20h9M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/></Icon>,
  more: (p) => <Icon {...p}><circle cx="12" cy="5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="12" cy="19" r="1.4"/></Icon>,
  trash: (p) => <Icon {...p}><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></Icon>,
  drag: (p) => <Icon {...p}><circle cx="9" cy="6" r="1.2"/><circle cx="15" cy="6" r="1.2"/><circle cx="9" cy="12" r="1.2"/><circle cx="15" cy="12" r="1.2"/><circle cx="9" cy="18" r="1.2"/><circle cx="15" cy="18" r="1.2"/></Icon>,
  copy: (p) => <Icon {...p}><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></Icon>,
  check: (p) => <Icon {...p}><path d="M20 6 9 17l-5-5"/></Icon>,
  close: (p) => <Icon {...p}><path d="M18 6 6 18M6 6l12 12"/></Icon>,
  // category & template icons
  briefcase: (p) => <Icon {...p}><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></Icon>,
  heart: (p) => <Icon {...p}><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></Icon>,
  server: (p) => <Icon {...p}><rect x="2" y="3" width="20" height="8" rx="2"/><rect x="2" y="13" width="20" height="8" rx="2"/><path d="M6 7h.01M6 17h.01"/></Icon>,
  // field-type icons (Template builder)
  type_text: (p) => <Icon {...p}><path d="M4 7V5h16v2M9 19h6M12 5v14"/></Icon>,
  type_num: (p) => <Icon {...p}><path d="M4 9h16M4 15h16M10 3 8 21M16 3l-2 18"/></Icon>,
  type_toggle: (p) => <Icon {...p}><rect x="2" y="7" width="20" height="10" rx="5"/><circle cx="8" cy="12" r="3" fill="currentColor"/></Icon>,
  type_dropdown: (p) => <Icon {...p}><rect x="3" y="4" width="18" height="16" rx="2"/><path d="m9 11 3 3 3-3"/></Icon>,
  type_password: (p) => <Icon {...p}><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></Icon>,
  type_url: (p) => <Icon {...p}><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1"/></Icon>,
  type_ip: (p) => <Icon {...p}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a13.5 13.5 0 0 1 0 18M12 3a13.5 13.5 0 0 0 0 18"/></Icon>,
  type_regex: (p) => <Icon {...p}><path d="M3 12h6M6 6v12M14 16a2 2 0 1 0 .01 0M18 6l-4 8M14 6l4 8"/></Icon>,
  type_date: (p) => <Icon {...p}><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 11h18"/></Icon>,
  type_image: (p) => <Icon {...p}><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-5-5-9 9"/></Icon>,
  type_label: (p) => <Icon {...p}><path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.2" fill="currentColor"/></Icon>,
  sparkles: (p) => <Icon {...p}><path d="m12 3 1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8zM19 14l.9 2.1L22 17l-2.1.9L19 20l-.9-2.1L16 17l2.1-.9zM5 14l.7 1.6L7.5 16l-1.8.4L5 18l-.7-1.6L2.5 16l1.8-.4z"/></Icon>,
  bell: (p) => <Icon {...p}><path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0"/></Icon>,
  cloud: (p) => <Icon {...p}><path d="M18 10h-1.3a7 7 0 1 0-13.4 3A5 5 0 0 0 7 21h11a5 5 0 0 0 0-10z"/></Icon>,
  download: (p) => <Icon {...p}><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></Icon>,
  lock: (p) => <Icon {...p}><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></Icon>,
  palette: (p) => <Icon {...p}><circle cx="13.5" cy="6.5" r="1.5"/><circle cx="17.5" cy="10.5" r="1.5"/><circle cx="8.5" cy="7.5" r="1.5"/><circle cx="6.5" cy="12.5" r="1.5"/><path d="M12 2a10 10 0 1 0 0 20 2 2 0 0 0 1.4-3.4 2 2 0 0 1 1.4-3.4H17a5 5 0 0 0 5-5 10 10 0 0 0-10-9z"/></Icon>,
  filter: (p) => <Icon {...p}><path d="M22 3H2l8 9.5V19l4 2v-8.5z"/></Icon>,
  chevR: (p) => <Icon {...p}><path d="m9 18 6-6-6-6"/></Icon>,
  chevD: (p) => <Icon {...p}><path d="m6 9 6 6 6-6"/></Icon>,
  chevU: (p) => <Icon {...p}><path d="m18 15-6-6-6 6"/></Icon>,
  star: (p) => <Icon {...p}><path d="M12 2 15 9l7 1-5.5 4.6 1.8 7L12 18l-6.3 3.6 1.8-7L2 10l7-1z"/></Icon>,
  globe: (p) => <Icon {...p}><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/></Icon>,
};

// Organote wordmark — playful "O" mark + name
function Wordmark({ size = 22, color = 'currentColor', accent = '#5eead4', showName = true }) {
  const s = size;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: s * 0.34, color }}>
      <svg width={s * 1.15} height={s * 1.15} viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" strokeWidth="2.4"/>
        <circle cx="12" cy="12" r="4.2" fill={accent}/>
        <circle cx="17.5" cy="6.5" r="2.2" fill={accent}/>
      </svg>
      {showName && (
        <span style={{
          fontFamily: '"Plus Jakarta Sans", system-ui, sans-serif',
          fontWeight: 800, fontSize: s, letterSpacing: '-0.025em', lineHeight: 1,
        }}>Organote</span>
      )}
    </div>
  );
}

Object.assign(window, { I, Wordmark });
