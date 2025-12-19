# Step-by-Step Guide: Deploy to Vercel via GitHub Import

Follow these steps to deploy your Flutter web app to Vercel using their GitHub import feature.

## Prerequisites ✅

- Your repository is already pushed to GitHub: `alaundryai/ALaundry_Web`
- You have access to the Vercel dashboard

## Step 1: Import Repository in Vercel

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click **"Add New..."** → **"Project"**
3. You should see the "Import Git Repository" page
4. If you see "Install GitHub application", click **"Install"** and authorize Vercel to access your GitHub repositories
5. Search for and select: **`alaundryai/ALaundry_Web`**

## Step 2: Configure Project Settings

After selecting your repository, you'll see the "New Project" configuration page:

### Basic Settings:
- **Project Name**: `a-laundry-web` (or your preferred name)
- **Framework Preset**: Select **"Other"** from the dropdown
- **Root Directory**: Keep as `./` (default)

### Build and Output Settings (IMPORTANT!):

Click to expand **"Build and Output Settings"** and configure:

1. **Build Command**: 
   ```
   chmod +x build.sh && bash build.sh
   ```

2. **Output Directory**: 
   ```
   build/web
   ```

3. **Install Command**: 
   ```
   echo 'Dependencies installed in build script'
   ```
   (or leave empty)

### Environment Variables (Optional):

If you want to use environment variables for Supabase (recommended for production), click **"Environment Variables"** and add:
- `SUPABASE_URL` = `https://xeabnvfxnkooljbqhkce.supabase.co`
- `SUPABASE_ANON_KEY` = `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (your full key)

**Note**: Currently your Supabase credentials are hardcoded in `lib/main.dart`. To use environment variables, you'll need to update the code to read from `String.fromEnvironment()` or use a package like `flutter_dotenv`.

## Step 3: Deploy

1. Click the **"Deploy"** button at the bottom
2. Wait for the build to complete (first build may take 5-10 minutes)
3. You'll see build logs in real-time

## Step 4: Access Your Deployed App

Once deployment completes:
- Your app will be live at: `https://a-laundry-web.vercel.app` (or your custom domain)
- Vercel will automatically deploy on every push to the `main` branch

## Troubleshooting

### Build Fails with "Flutter not found"
- The build script should install Flutter automatically
- Check build logs to see if Flutter installation is progressing
- First build takes longer (5-10 minutes)

### Build Times Out
- Vercel has a 45-minute build timeout
- If it times out, the build script might be too slow
- Consider using GitHub Actions instead (see `VERCEL_DEPLOYMENT.md`)

### "Permission denied" for build.sh
- The `vercel.json` includes `chmod +x build.sh` to fix this
- If it still fails, ensure the file is committed to GitHub

### Build Succeeds but App Shows 404
- Verify Output Directory is set to `build/web`
- Check that `build/web/index.html` exists after build
- Check Vercel build logs for the actual output location

### Assets Not Loading
- The `vercel.json` includes proper cache headers
- Check browser console for 404 errors
- Verify asset paths in `build/web` match your app's expectations

## What Happens During Build?

1. Vercel clones your GitHub repository
2. Runs `build.sh` script which:
   - Installs Flutter SDK (if not present)
   - Runs `flutter pub get` to install dependencies
   - Builds the web app with `flutter build web --release`
3. Outputs files to `build/web`
4. Deploys those files to Vercel's CDN

## Next Steps After Deployment

1. **Custom Domain**: Add your custom domain in Vercel project settings
2. **Environment Variables**: Move Supabase credentials to environment variables for better security
3. **Monitoring**: Set up Vercel Analytics to monitor your app
4. **Automatic Deployments**: Every push to `main` will trigger a new deployment

## Need Help?

- Check build logs in Vercel dashboard for detailed error messages
- Verify all files (`vercel.json`, `build.sh`) are committed to GitHub
- Ensure your repository is accessible to Vercel
