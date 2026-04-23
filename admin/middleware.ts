import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';

const JWT_SECRET = process.env.JWT_ACCESS_SECRET;

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Skip auth for Next internals, our own auth routes, and the login page.
  if (
    pathname.startsWith('/api') ||
    pathname.startsWith('/_next') ||
    pathname === '/login' ||
    pathname === '/favicon.ico'
  ) {
    return NextResponse.next();
  }

  const token = req.cookies.get('token')?.value;
  if (!token || !JWT_SECRET) {
    return NextResponse.redirect(new URL('/login', req.url));
  }

  try {
    const { payload } = await jwtVerify(
      token,
      new TextEncoder().encode(JWT_SECRET),
    );
    if (!payload.isAdmin) {
      // Authenticated but not an admin — reject at the edge so non-admin
      // JWTs never reach the admin UI (Admin #3).
      return NextResponse.redirect(new URL('/login', req.url));
    }
    return NextResponse.next();
  } catch {
    // Bad signature, expired, or malformed.
    return NextResponse.redirect(new URL('/login', req.url));
  }
}

export const config = {
  matcher: ['/((?!api|_next|login|favicon.ico).*)'],
};
