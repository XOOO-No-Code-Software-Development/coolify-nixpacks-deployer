# XOOO AI Platform - Empty Template

This is the default empty template used when a new container is created in the XOOO AI Platform.

## What's Included

- **Next.js 16** - React framework for production
- **TypeScript** - Type-safe development
- **Tailwind CSS v4** - Utility-first CSS framework
- **Radix UI Components** - Accessible component library
- **shadcn/ui** - Beautiful, reusable components

## Default Page

When this template is deployed, it shows a simple "Frontend Not Created Yet" message, indicating that the container is ready to receive the actual application deployment.

## Purpose

This template serves as:
1. A placeholder for new deployments
2. A minimal working Next.js application
3. A foundation with all necessary dependencies pre-installed
4. A quick health check to ensure the deployment infrastructure is working

## Deployment Flow

1. Container is created with this empty template
2. Application files are downloaded from Vercel deployment
3. Frontend is built and served on port 3000
4. Backend (if present) is served on port 8000

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## Structure

```
empty_template/
├── app/              # Next.js app directory
│   ├── globals.css   # Global styles
│   ├── layout.tsx    # Root layout
│   └── page.tsx      # Home page (shows "Frontend Not Created Yet")
├── components/       # React components
│   ├── ui/          # shadcn/ui components
│   └── theme-provider.tsx
├── lib/             # Utility functions
├── public/          # Static assets
└── styles/          # Additional styles
```

## Notes

- This template is automatically used when `startup.sh` doesn't find downloaded deployment files
- All UI components from shadcn/ui are included for future use
- The template is kept minimal but production-ready
