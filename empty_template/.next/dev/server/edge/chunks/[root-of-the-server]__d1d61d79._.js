(globalThis.TURBOPACK || (globalThis.TURBOPACK = [])).push(["chunks/[root-of-the-server]__d1d61d79._.js",
"[externals]/node:buffer [external] (node:buffer, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("node:buffer", () => require("node:buffer"));

module.exports = mod;
}),
"[externals]/node:async_hooks [external] (node:async_hooks, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("node:async_hooks", () => require("node:async_hooks"));

module.exports = mod;
}),
"[project]/lib/constants.ts [middleware-edge] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "DEPLOY_URL",
    ()=>DEPLOY_URL,
    "DUMMY_PASSWORD",
    ()=>DUMMY_PASSWORD,
    "guestRegex",
    ()=>guestRegex,
    "isDevelopmentEnvironment",
    ()=>isDevelopmentEnvironment
]);
const DUMMY_PASSWORD = '$2b$10$k7L3lUJhDLKBGbz4Yf8ZJe9Yk6j5Qz1Xr2Wv8Ts7Nq9Mp3Lk4Jh6Fg';
const guestRegex = /^guest-[a-zA-Z0-9_-]+@example\.com$/;
const isDevelopmentEnvironment = ("TURBOPACK compile-time value", "development") === 'development';
const DEPLOY_URL = 'https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fvercel%2Fv0-sdk%2Ftree%2Fmain%2Fexamples%2Fv0-clone&env=V0_API_KEY,AUTH_SECRET&envDescription=Get+your+v0+API+key&envLink=https%3A%2F%2Fv0.app%2Fchat%2Fsettings%2Fkeys&products=%255B%257B%2522type%2522%253A%2522integration%2522%252C%2522protocol%2522%253A%2522storage%2522%252C%2522productSlug%2522%253A%2522neon%2522%252C%2522integrationSlug%2522%253A%2522neon%2522%257D%255D&project-name=v0-clone&repository-name=v0-clone&demo-title=v0+Clone&demo-description=A+full-featured+v0+clone+built+with+Next.js%2C+AI+Elements%2C+and+the+v0+SDK&demo-url=https%3A%2F%2Fclone-demo.v0-sdk.dev';
}),
"[project]/middleware.ts [middleware-edge] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "config",
    ()=>config,
    "middleware",
    ()=>middleware
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$api$2f$server$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/coolify-nixpacks-deployer/empty_template/node_modules/next/dist/esm/api/server.js [middleware-edge] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/coolify-nixpacks-deployer/empty_template/node_modules/next/dist/esm/server/web/exports/index.js [middleware-edge] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2d$auth$2f$jwt$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/node_modules/next-auth/jwt.js [middleware-edge] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$auth$2f$core$2f$jwt$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/@auth/core/jwt.js [middleware-edge] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$constants$2e$ts__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/constants.ts [middleware-edge] (ecmascript)");
;
;
;
async function middleware(request) {
    const { pathname } = request.nextUrl;
    /*
   * Playwright starts the dev server and requires a 200 status to
   * begin the tests, so this ensures that the tests can start
   */ if (pathname.startsWith('/ping')) {
        return new Response('pong', {
            status: 200
        });
    }
    if (pathname.startsWith('/api/auth')) {
        return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
    }
    // Check for required environment variables
    if (!process.env.AUTH_SECRET) {
        console.error('❌ Missing AUTH_SECRET environment variable. Please check your .env file.');
        return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next() // Let the app handle the error with better UI
        ;
    }
    const token = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$auth$2f$core$2f$jwt$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["getToken"])({
        req: request,
        secret: process.env.AUTH_SECRET,
        secureCookie: !__TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$constants$2e$ts__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["isDevelopmentEnvironment"]
    });
    if (!token) {
        // Allow API routes to proceed without authentication for anonymous chat creation
        if (pathname.startsWith('/api/')) {
            return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
        }
        // Allow homepage for anonymous users
        if (pathname === '/') {
            return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
        }
        // Redirect protected pages to login
        if ([
            '/chats',
            '/projects'
        ].some((path)=>pathname.startsWith(path))) {
            return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].redirect(new URL('/login', request.url));
        }
        // Allow login and register pages
        if ([
            '/login',
            '/register'
        ].includes(pathname)) {
            return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
        }
        // For any other protected routes, redirect to login
        return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].redirect(new URL('/login', request.url));
    }
    const isGuest = __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$constants$2e$ts__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["guestRegex"].test(token?.email ?? '');
    if (token && !isGuest && [
        '/login',
        '/register'
    ].includes(pathname)) {
        return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].redirect(new URL('/', request.url));
    }
    return __TURBOPACK__imported__module__$5b$project$5d2f$coolify$2d$nixpacks$2d$deployer$2f$empty_template$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
}
const config = {
    matcher: [
        '/',
        '/chats/:path*',
        '/projects/:path*',
        '/api/:path*',
        '/login',
        '/register',
        /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico, sitemap.xml, robots.txt (metadata files)
     */ '/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)'
    ]
};
}),
]);

//# sourceMappingURL=%5Broot-of-the-server%5D__d1d61d79._.js.map