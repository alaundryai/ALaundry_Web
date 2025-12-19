# Deploying AILaundry_Web to Vercel

This guide will help you deploy your Flutter web application to Vercel.

## Option 1: Direct Vercel Deployment (Recommended)

### Step 1: Configure Vercel Project Settings

When setting up your project in Vercel (as shown in your screenshots), use these settings:

1. **Framework Preset**: Select "Other" (or leave as default)
2. **Root Directory**: `./` (keep as default)
3. **Build and Output Settings**:
   - **Build Command**: `bash build.sh`
   - **Output Directory**: `build/web`
   - **Install Command**: Leave empty or use `echo 'Skipping install'`

### Step 2: Deploy

Click "Deploy" and Vercel will:
1. Run the build script which installs Flutter SDK
2. Build your Flutter web app
3. Deploy the output from `build/web`

**Note**: The first build may take longer (5-10 minutes) as it installs Flutter SDK. Subsequent builds will be faster.

## Option 2: GitHub Actions + Vercel (More Reliable)

This approach uses GitHub Actions to build your Flutter app and then deploys to Vercel.

### Step 1: Get Vercel Credentials

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Go to your project settings
3. Navigate to "General" → Copy your:
   - **Project ID**
   - **Org ID**
4. Go to [Vercel Account Settings](https://vercel.com/account/tokens) → Create a new token → Copy the **Token**

### Step 2: Add GitHub Secrets

1. Go to your GitHub repository: `alaundryai/ALaundry_Web`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:
   - `VERCEL_TOKEN`: Your Vercel token
   - `VERCEL_ORG_ID`: Your Vercel organization ID
   - `VERCEL_PROJECT_ID`: Your Vercel project ID

### Step 3: Push to GitHub

The GitHub Actions workflow (`.github/workflows/deploy-vercel.yml`) will automatically:
1. Build your Flutter web app on every push to `main`
2. Deploy to Vercel

Just push your code and the workflow will handle the rest!

## Troubleshooting

### Build Timeout
If the build times out (Vercel has a 45-minute limit), use Option 2 (GitHub Actions) instead.

### Flutter SDK Not Found
Make sure the `build.sh` script is executable:
```bash
chmod +x build.sh
```

### Build Output Not Found
Verify that:
- Build command outputs to `build/web`
- Output directory in Vercel is set to `build/web`
- The build completes successfully

### Environment Variables
If you need to use environment variables for Supabase (recommended for production):
1. Go to Vercel project settings → Environment Variables
2. Add your variables
3. Update `lib/main.dart` to read from environment variables instead of hardcoded values

## Current Configuration

- **Build Command**: `bash build.sh`
- **Output Directory**: `build/web`
- **Framework**: Flutter Web
- **Web Renderer**: CanvasKit (for better performance)

## Next Steps

1. Complete the Vercel project setup in the dashboard
2. Click "Deploy"
3. Wait for the build to complete
4. Your app will be live at `https://your-project.vercel.app`
