# File Uploads Module — Active Storage

> Status: Placeholder — not yet implemented.
> Add this module when the app needs file uploads.

## When to use this module
When the app needs user avatars, document uploads,
image attachments, or any file storage.

## Recommended approach
- Active Storage (built into Rails, already present)
- Local disk in development (already configured)
- S3-compatible storage in production via
  config/storage.yml and the aws-sdk-s3 gem
- Image variants via libvips (faster than ImageMagick)

## Installation steps
<!-- To be documented when first implemented -->

## Key files to create/modify
<!-- To be documented when first implemented -->

## Decisions to make per app
- Storage backend (S3, GCS, Azure, Cloudflare R2)
- Direct upload vs server-side upload
- Image processing library (vips vs ImageMagick)
- File size and type validation approach

