export const prerender = false;

import type { APIRoute } from 'astro';
import { ADMIN_PASSWORD, ADMIN_SECRET } from 'astro:env/server';

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
  const formData = await request.formData();
  const password = formData.get('password');

  if (typeof password !== 'string' || password !== ADMIN_PASSWORD) {
    return new Response(
      JSON.stringify({ error: '비밀번호가 올바르지 않습니다.' }),
      {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  cookies.set('admin_session', ADMIN_SECRET, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 60 * 60 * 24 * 7, // 7일
    path: '/',
  });

  return redirect('/admin/', 302);
};
