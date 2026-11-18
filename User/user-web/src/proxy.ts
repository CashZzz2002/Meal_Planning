import { NextResponse, type NextRequest } from "next/server";

const cookieName = "mealplanning.user.session";

export function proxy(request: NextRequest) {
  const publicRoutes = ["/login", "/register", "/verify-email"];
  const isPublic = publicRoutes.includes(request.nextUrl.pathname);
  const hasSessionCookie = request.cookies.has(cookieName);

  if (!isPublic && !hasSessionCookie) return NextResponse.redirect(new URL("/login", request.url));
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
