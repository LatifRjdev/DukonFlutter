import { NextRequest, NextResponse } from 'next/server';

const API_URL =
  process.env.API_INTERNAL_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  'http://localhost:4455/api';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const upstream = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await upstream.json().catch(() => ({}));
  if (!upstream.ok) {
    return NextResponse.json(data, { status: upstream.status });
  }
  const token = data.accessToken || data.access_token;
  if (!token) {
    return NextResponse.json(
      { message: 'No token in upstream response' },
      { status: 502 },
    );
  }
  const res = NextResponse.json({ user: data.user });
  res.cookies.set('token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/',
    maxAge: 60 * 60 * 24,
  });
  return res;
}
