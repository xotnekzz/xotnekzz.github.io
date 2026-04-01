export const prerender = false;

import type { APIRoute } from 'astro';

export const POST: APIRoute = async ({ cookies, redirect }) => {
  cookies.delete('admin_session', { path: '/' });
  return redirect('/admin/login', 302);
};
