# File Descriptor Limit Fix for Turbopack

## Problem
Next.js with Turbopack throws this error:
```
Error [TurbopackInternalError]: Too many open files (os error 24)
```

Even though `ulimit` shows 65536, the container process still hits the limit.

## Root Cause
Docker containers have their own file descriptor limits that are separate from the host system. The limit needs to be set at the **container runtime level** when the container is started.

## Solutions

### Solution 1: Coolify Docker Configuration (Recommended)
Add the following to the **Coolify application's Docker settings**:

In Coolify UI:
1. Go to your application settings
2. Find "Advanced" or "Docker Options"
3. Add custom Docker run arguments:
   ```
   --ulimit nofile=65536:65536
   ```

Or if Coolify supports it via labels, add this label:
```yaml
com.docker.compose.ulimits: "nofile=65536:65536"
```

### Solution 2: Dockerfile Configuration
The Dockerfile already includes system-level limits in `/etc/security/limits.conf` and `/etc/sysctl.conf`, but these don't override Docker's container limits.

### Solution 3: Use prlimit in startup.sh
The startup script now uses `prlimit` to set limits for the Next.js process:
```bash
prlimit --nofile=65536:65536 -- bash -c "npm run dev"
```

However, this may not work if the parent process (container) has a lower limit.

## Current Status

✅ **What's been done:**
- Dockerfile sets system limits (65536)
- startup.sh sets ulimit (65536)
- startup.sh uses prlimit for Next.js process
- Diagnostic output shows current limits

❌ **What's still needed:**
- Configure Coolify to start containers with `--ulimit nofile=65536:65536`

## Verification

After applying the fix, you should see in the logs:
```
📊 Current file descriptor limits:
   Soft limit: 65536
   Hard limit: 65536
   Process limit: 2097152
[Next.js] Process limits - Soft: 65536, Hard: 65536
```

And Next.js should start without the "Too many open files" error.

## Alternative: Reduce File Watching

If container limits cannot be increased, you can reduce Next.js file watching:

Create `.env.local`:
```bash
# Reduce file watching
WATCHPACK_POLLING=true
```

Or in `next.config.ts`:
```typescript
const config = {
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.watchOptions = {
        poll: 1000,
        aggregateTimeout: 300,
      }
    }
    return config
  },
}
```

However, this degrades the development experience.

## Contact Coolify Support

If the issue persists, contact Coolify support with this information:
- Container needs `--ulimit nofile=65536:65536` flag
- Required for Next.js 16 with Turbopack
- Current limit of 1024 (default) is insufficient for large projects
