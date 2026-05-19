// data.jsx — mock data + helpers

const CATEGORIES = [
  { id: 'all',      name: 'All',      hue: 175 },
  { id: 'work',     name: 'Work',     hue:  45, icon: 'briefcase' },
  { id: 'personal', name: 'Personal', hue: 295, icon: 'heart' },
  { id: 'servers',  name: 'Servers',  hue: 175, icon: 'server' },
];

const TEMPLATES = [
  {
    id: 'server-creds', name: 'Server Credentials', icon: 'server',
    category: 'servers', hue: 175,
    desc: 'SSH/admin access details for managed boxes',
    notes: 4,
    fields: [
      { id: 'f1', key: 'server',   label: 'Server name', type: 'text',     required: true },
      { id: 'f2', key: 'ip',       label: 'IP address',  type: 'regex',    pattern: '^(?:\\d{1,3}\\.){3}\\d{1,3}$', hint: 'IPv4 — e.g. 10.0.4.18', mono: true },
      { id: 'f3', key: 'url',      label: 'Admin URL',   type: 'url' },
      { id: 'f4', key: 'username', label: 'Username',    type: 'text' },
      { id: 'f5', key: 'password', label: 'Password',    type: 'password', mono: true },
      { id: 'f6', key: 'os',       label: 'OS type',     type: 'dropdown', options: ['Linux · Ubuntu', 'Linux · Debian', 'Linux · Alpine', 'Windows Server', 'macOS', 'FreeBSD'] },
    ],
  },
  {
    id: 'reading', name: 'Reading Log', icon: 'star',
    category: 'personal', hue: 295,
    desc: 'Books, articles, and what you took away',
    notes: 12,
    fields: [
      { id: 'r1', key: 'title',  label: 'Title',  type: 'text' },
      { id: 'r2', key: 'author', label: 'Author', type: 'text' },
      { id: 'r3', key: 'rating', label: 'Rating', type: 'dropdown', options: ['★', '★★', '★★★', '★★★★', '★★★★★'] },
      { id: 'r4', key: 'finished', label: 'Finished', type: 'date' },
    ],
  },
  {
    id: 'meeting', name: 'Meeting Brief', icon: 'briefcase',
    category: 'work', hue: 45,
    desc: 'Attendees, agenda, follow-ups',
    notes: 7,
    fields: [
      { id: 'm1', key: 'topic',     label: 'Topic',    type: 'text' },
      { id: 'm2', key: 'attendees', label: 'Attendees', type: 'text' },
      { id: 'm3', key: 'when',      label: 'When',     type: 'date' },
    ],
  },
];

const NOTES = [
  {
    id: 'n1', template: 'server-creds', title: 'Production cluster',
    updated: '2 hours ago', favorite: true, category: 'servers',
    tags: ['prod', 'aws', 'critical'],
    records: [
      { name: 'API Gateway', data: {
        server: 'api-gw-prod-01', ip: '10.0.4.18',
        url: 'https://gw.organote.dev:9443',
        username: 'admin', password: 'kx9!Vt2#Lp7@Qm',
        os: 'Linux · Ubuntu',
      }},
      { name: 'Postgres Primary', data: {
        server: 'pg-prod-master', ip: '10.0.4.22',
        url: 'https://pg-1.organote.dev',
        username: 'pg_admin', password: 'rR8&hZ4!Yk2$Sm',
        os: 'Linux · Debian',
      }},
      { name: 'Redis Cache', data: {
        server: 'redis-prod-01', ip: '10.0.4.31',
        url: 'redis://cache.organote.dev:6379',
        username: 'default', password: 'cache!Op92!Mn',
        os: 'Linux · Alpine',
      }},
    ],
  },
  {
    id: 'n2', template: 'server-creds', title: 'EU-West replicas',
    updated: 'yesterday', category: 'servers',
    tags: ['replica', 'eu', 'postgres'],
    records: [
      { name: 'Replica · Frankfurt', data: {
        server: 'pg-replica-euw-3', ip: '10.2.18.4',
        url: 'https://pg-3.organote.dev',
        username: 'pg_admin', password: 'rR8&hZ4!Yk2$Sm',
        os: 'Linux · Debian',
      }},
      { name: 'Replica · Dublin', data: {
        server: 'pg-replica-euw-4', ip: '10.2.18.5',
        url: 'https://pg-4.organote.dev',
        username: 'pg_admin', password: 'eu4!Dx9!Hg77',
        os: 'Linux · Debian',
      }},
    ],
  },
  {
    id: 'n3', template: 'server-creds', title: 'Bastion · Edge Asia',
    updated: '3 days ago', category: 'servers',
    tags: ['ops', 'asia'],
    records: [
      { name: 'Edge Bastion', data: {
        server: 'bastion-asia-1', ip: '10.7.0.2',
        url: 'https://bastion.organote.dev',
        username: 'ops', password: 'aB7#mQ3!Tx5%',
        os: 'Linux · Alpine',
      }},
    ],
  },
  {
    id: 'n4', template: 'server-creds', title: 'Dev Sandbox · macOS',
    updated: 'a week ago', category: 'servers',
    tags: ['dev', 'local'],
    records: [
      { name: 'Mac mini · Dev', data: {
        server: 'macmini-dev-04', ip: '192.168.1.42',
        url: 'vnc://sandbox.local:5900',
        username: 'dev', password: 'sandbox!2026',
        os: 'macOS',
      }},
    ],
  },
  {
    id: 'n5', template: 'reading', title: 'A Pattern Language',
    updated: 'today', favorite: true, category: 'personal',
    tags: ['architecture', 'design'],
    records: [
      { name: 'Book', data: { title: 'A Pattern Language', author: 'Christopher Alexander', rating: '★★★★★', finished: '14 Apr 2026' } },
    ],
  },
  {
    id: 'n6', template: 'reading', title: 'The Design of Everyday Things',
    updated: '4 days ago', category: 'personal',
    tags: ['ux', 'classic'],
    records: [
      { name: 'Book', data: { title: 'The Design of Everyday Things', author: 'Don Norman', rating: '★★★★', finished: '02 Apr 2026' } },
    ],
  },
  {
    id: 'n7', template: 'meeting', title: 'Q2 roadmap sync',
    updated: 'yesterday', category: 'work',
    tags: ['roadmap', 'q2'],
    records: [
      { name: 'Meeting', data: { topic: 'Roadmap review', attendees: 'Sara, Omar, Lin, you', when: '11 May 2026' } },
    ],
  },
];

const FIELD_TYPES = [
  { id: 'text',     name: 'Text',          icon: 'type_text' },
  { id: 'number',   name: 'Number',        icon: 'type_num' },
  { id: 'toggle',   name: 'Boolean',       icon: 'type_toggle' },
  { id: 'dropdown', name: 'Dropdown',      icon: 'type_dropdown' },
  { id: 'password', name: 'Password',      icon: 'type_password' },
  { id: 'url',      name: 'URL',           icon: 'type_url' },
  { id: 'ip',       name: 'IP address',    icon: 'type_ip' },
  { id: 'regex',    name: 'Regex',         icon: 'type_regex' },
  { id: 'date',     name: 'Date (dual)',   icon: 'type_date' },
  { id: 'image',    name: 'Image',         icon: 'type_image' },
  { id: 'label',    name: 'Custom label',  icon: 'type_label' },
];

Object.assign(window, { CATEGORIES, TEMPLATES, NOTES, FIELD_TYPES });
