# Coolify v0 API + Nixpacks Deployer

Deploy applications to Coolify directly from v0 API while maintaining Nixpacks auto-detection.

## How It Works

1. **Build-time Fetch**: `download-source.sh` fetches your source code directly from v0 API
2. **Detection**: Nixpacks auto-detects your project type (Node.js, Python, Go, etc.)
3. **Build**: Nixpacks builds using the appropriate buildpack
4. **Deploy**: Your app runs in a container

## Setup in Coolify

### Via Coolify UI

1. Create new application → Private Repository (Deploy Key)
2. Repository: `github.com/XOOO-No-Code-Software-Development/coolify-nixpacks-deployer`
3. Build Pack: **Nixpacks** (default)
4. Add Environment Variables (all as **Build Time**):
   - Key: `CHAT_ID`
   - Value: Your chat ID from v0
   - Type: **Build Time** ✓
   
   - Key: `VERSION_ID`
   - Value: `latest` (or specific version ID)
   - Type: **Build Time** ✓
   
   - Key: `V0_API_KEY`
   - Value: Your v0 API key
   - Type: **Build Time** ✓
   
   - Key: `V0_API_URL` (optional)
   - Value: `https://api.v0.dev/v1` (default)
   - Type: **Build Time** ✓
5. Deploy!

### Via API

See the integration in the main application for programmatic deployment via `/api/coolify/deploy`.

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

The deployment automatically fetches the latest version when `VERSION_ID=latest` is set.

### Via Coolify UI
1. Go to application → Deployments
2. Click "Restart" or "Redeploy" - it will automatically fetch the latest version from v0 API
3. No need to change environment variables!

### Via API
The main application handles this automatically via `/api/coolify/deploy` endpoint.

## Examples

### Deploy Latest Version (Recommended)
```bash
CHAT_ID=abc123xyz
VERSION_ID=latest
V0_API_KEY=your_api_key
```

### Deploy Specific Version
```bash
CHAT_ID=abc123xyz
VERSION_ID=b_xyz123abc
V0_API_KEY=your_api_key
```

## Customizing Build

Add environment variables in Coolify to customize Nixpacks:

```bash
NIXPACKS_NODE_VERSION=18        # Specific Node version
NIXPACKS_PYTHON_VERSION=3.11    # Specific Python version
NIXPACKS_BUILD_CMD="npm run build"
NIXPACKS_START_CMD="npm run start:prod"
```

Or include `nixpacks.toml` in your v0 project files.

## Troubleshooting

**"CHAT_ID not set" or "VERSION_ID not set"**
- Ensure CHAT_ID, VERSION_ID, and V0_API_KEY are added as **build-time** environment variables
- Check that all three variables are properly configured

**"V0_API_KEY not set"**
- Verify your v0 API key is correctly set in environment variables
- Ensure the API key has proper permissions to access the chat

**"Could not resolve latest version ID"**
- Check that the CHAT_ID is valid
- Verify the chat exists in v0 and has at least one version

**"download-source.sh: command not found"**
- The script runs automatically during Nixpacks install phase
- Check build logs for any errors during the download phase

**"No buildpack detected"**
- Verify your v0 version contains recognizable files (package.json, requirements.txt, etc.)
- Check that files are being extracted correctly in build logs

**Build fails**
- Check Coolify deployment logs for detailed error messages
- Verify v0 API is accessible from your Coolify server
- Ensure your v0 chat/version contains valid application files

## License

MIT
