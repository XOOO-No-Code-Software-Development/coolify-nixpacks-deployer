# Coolify Zip + Nixpacks Deployer

Deploy applications to Coolify from zip URLs while maintaining Nixpacks auto-detection.

## How It Works

1. **Pre-deployment**: `download-source.sh` downloads and extracts your source code
2. **Detection**: Nixpacks auto-detects your project type (Node.js, Python, Go, etc.)
3. **Build**: Nixpacks builds using the appropriate buildpack
4. **Deploy**: Your app runs in a container

## Setup in Coolify

### Via Coolify UI

1. Create new application → Private Repository (Deploy Key)
2. Repository: `github.com/YOUR_USERNAME/coolify-nixpacks-deployer`
3. Build Pack: **Nixpacks** (default)
4. Pre Deployment Command: `bash download-source.sh`
5. Add Environment Variable:
   - Key: `SOURCE_URL`
   - Value: `https://github.com/example/app/archive/main.zip`
   - Type: **Build Time** ✓
6. Deploy!

### Via API (Python)

See the integration in the main application for programmatic deployment.

## Supported Languages

Nixpacks automatically detects and builds:
- Node.js (package.json)
- Python (requirements.txt, pyproject.toml)
- Go (go.mod)
- PHP (composer.json)
- Rust (Cargo.toml)
- Ruby (Gemfile)
- Static sites (HTML/CSS/JS)

## Updating Your App

Change the `SOURCE_URL` environment variable to a new zip URL and redeploy.

### Via Coolify UI
1. Go to application → Environment Variables
2. Update `SOURCE_URL` to new zip URL
3. Click Deploy

### Via API
The main application handles this automatically via the Coolify API.

## Examples

### Deploy Node.js App
```
SOURCE_URL=https://your-app.com/api/download/[token]
```

### Deploy Python App
```
SOURCE_URL=https://your-app.com/api/download/[token]
```

## Customizing Build

Add environment variables in Coolify to customize Nixpacks:

```bash
NIXPACKS_NODE_VERSION=18        # Specific Node version
NIXPACKS_PYTHON_VERSION=3.11    # Specific Python version
NIXPACKS_BUILD_CMD="npm run build"
NIXPACKS_START_CMD="npm run start:prod"
```

Or include `nixpacks.toml` in your source zip.

## Troubleshooting

**"SOURCE_URL not set"**
- Ensure SOURCE_URL is added as **build-time** environment variable

**"download-source.sh: command not found"**
- Ensure script has execute permissions: `chmod +x download-source.sh`
- Check Pre Deployment Command is set to: `bash download-source.sh`

**"No buildpack detected"**
- Verify zip contains recognizable files (package.json, etc.)
- Check that zip extracts correctly

**Build fails**
- Check Coolify deployment logs
- Verify zip URL is accessible: `curl -I SOURCE_URL`
- Ensure zip structure is correct (not double-nested)

## License

MIT
