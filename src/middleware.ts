import { defineMiddleware } from 'astro:middleware';
import { ADMIN_SECRET } from 'astro:env/server';

export const onRequest = defineMiddleware(async (context, next) => {
  const { pathname } = context.url;
  if (pathname.startsWith('/admin') && pathname !== '/admin/login') {
    const session = context.cookies.get('admin_session')?.value;
    if (session !== ADMIN_SECRET) {
      return context.redirect('/admin/login');
    }
  }
  return next();
});
