export const SITE = {
  title: "이름고민중",
  name: "tskim.dev",
  description: "",
  url: "https://xotnekzz.github.io",
  author: {
    name: "김태수",
    email: "xotnekzz@gmail.com",
    github: "https://github.com/xotnekzz",
  },
  nav: [
    { href: '/blog/', label: 'Posts' },
    { href: '/resume/', label: '이력서' },
    { href: 'https://www.linkedin.com/in/%ED%83%9C%EC%88%98-%EA%B9%80-9734b3213/', label: 'LinkedIn' },
    { href: 'https://github.com/xotnekzz', label: 'GitHub' },
  ],
  footer: {
    links: [
      { href: '/tags/', label: 'Tags' },
      { href: '/rss.xml', label: 'RSS' },
    ],
  },
  home: {
    headline: "김태수의 개발 블로그",
    tagline: "공부한 내용을 기록합니다.",
  },
} as const;
