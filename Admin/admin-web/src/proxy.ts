import { NextResponse, type NextRequest } from "next/server";

const cookieName = "mealplanning.admin.session";

export function proxy(request: NextRequest) {
  const publicRoutes = ["/login", "/request-admin", "/accept-invitation"];
  const isPublic = publicRoutes.includes(request.nextUrl.pathname);
  const hasSessionCookie = request.cookies.has(cookieName);

  if (!isPublic && !hasSessionCookie) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
