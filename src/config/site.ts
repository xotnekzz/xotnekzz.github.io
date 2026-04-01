export const SITE = {
  title: "tskim's dev blog",
  name: "tskim.dev",
  description: "데이터 엔지니어링, 백엔드 개발, 클라우드 인프라에 대한 개발 블로그입니다.",
  url: "https://xotnekzz.github.io",
  author: {
    name: "김태수",
    email: "xotnekzz@gmail.com",
    github: "https://github.com/xotnekzz",
  },
  nav: [
    { href: '/', label: '홈' },
    { href: '/blog/', label: '블로그' },
    { href: '/tags/', label: '태그' },
    { href: '/resume/', label: '이력서' },
  ],
  footer: {
    links: [
      { href: '/rss.xml', label: 'RSS' },
      { href: 'https://github.com/xotnekzz', label: 'GitHub' },
    ],
  },
  home: {
    headline: "tskim.dev",
    tagline: "데이터 엔지니어링 · 백엔드 · 클라우드에 대해 씁니다.",
  },
} as const;
