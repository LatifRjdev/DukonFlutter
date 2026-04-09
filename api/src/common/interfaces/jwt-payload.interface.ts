export interface JwtPayload {
  sub: string;
  phone: string;
}

export interface JwtRefreshPayload {
  sub: string;
  jti: string;
}
