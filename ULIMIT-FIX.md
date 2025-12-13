# Fix for "Too many open files" Error

## Problem
Next.js with Turbopack watches many files simultaneously and hits the default file descriptor limit (1024) in Docker containers, causing crashes:

```
FATAL: An unexpected Turbopack error occurred
Error: Too many open files (os error 24)
```

## Root Cause
- Docker containers inherit the host's `ulimit` but may restrict changes
- `ulimit` commands in shell scripts don't always work in containerized environments
- The default limit (1024) is too low for Next.js/Turbopack development mode

## Solution

### Option 1: Configure Coolify (Recommended)
Add this to your Coolify resource's Docker run settings:

```bash
--ulimit nofile=65536:65536
```

**Steps:**
1. Go to your Coolify resource settings
2. Find "Docker Run Arguments" or "Extra Docker Arguments"
3. Add: `--ulimit nofile=65536:65536`
4. Redeploy the container

### Option 2: Manual Docker Run
If running manually, include the ulimit flag:

```bash
docker run --ulimit nofile=65536:65536 your-image
```

### Option 3: Docker Compose
Add to your `docker-compose.yml`:

```yaml
services:
  app:
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
```

## Verification
After applying the fix, check the logs on container startup:

```
📊 Current file descriptor limit: 65536
```

If you see:
```
⚠️  WARNING: File descriptor limit is too low (1024)
```

Then the Docker-level ulimit configuration is needed.

## Why 65536?
- Sufficient for large Next.js projects with many files
- Well below system maximum (typically 1048576)
- Commonly used in production Node.js environments
- Prevents file watcher exhaustion

## Technical Details
The `startup.sh` script attempts three methods:
1. `ulimit -n 65536` - Standard shell command
2. `prlimit --pid=$$ --nofile=65536:65536` - Process-level limit
3. Warning message if both fail

However, **Docker-level configuration is required** for reliable operation.

## Related Issues
- Next.js Turbopack file watching
- Node.js `fs.watch()` limits
- Development mode file watchers
- Large monorepo projects
