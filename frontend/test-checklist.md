# Circle Integration Test Checklist

## Pre-Test Setup
- [ ] Development server running on http://localhost:3000
- [ ] Browser console open (F12)
- [ ] Circle API keys in `.env.local`
- [ ] Valid email address ready for testing

## Test Flow

### 1. Email Authentication
- [ ] Click "Connect Wallet" button
- [ ] Enter email address
- [ ] Click "Send Verification Code"
- [ ] Check console for errors
- [ ] Verify email received within 1-2 minutes

**Common Issues:**
- "Failed to initialize challenge" → Check Circle App ID format
- Network errors → Verify API keys are correct
- No email received → Check spam folder

### 2. OTP Verification
- [ ] Enter 6-digit code from email
- [ ] Click "Verify"
- [ ] Watch console for PIN status check
- [ ] Verify redirect behavior

**Expected Console Logs:**
```
Challenge initialization successful
OTP verification successful
PIN status check: [true/false]
```

### 3. PIN Setup (First Time Users)
- [ ] Enter 6-digit PIN
- [ ] Re-enter PIN to confirm
- [ ] Click "Set PIN"
- [ ] Verify wallet creation

### 4. Wallet Creation Verification
- [ ] Check localStorage for session data
- [ ] Verify wallet address displayed
- [ ] Check Circle Console for new wallet

## Debug Commands

Open browser console and run:

```javascript
// Check if Circle SDK loaded
window.CircleSDK

// Check stored session
localStorage.getItem('circle_user_session')

// Check current auth state
sessionStorage.getItem('pending_email')
```

## Common Error Solutions

### Error: "Circle SDK not initialized"
**Solution**: Refresh page and try again

### Error: "Invalid APP ID"
**Solution**: Check `.env.local` format:
- Should be: `appId:secretKey` format
- No spaces or quotes

### Error: "Failed to get wallets"
**Solution**: User might not have wallet access. Check Circle Console.

### Error: "PIN setup failed"
**Solution**: PIN might already be set. Try logging in again.

## Fallback to Mock Mode

If Circle API is having issues, the app will automatically fall back to mock mode in development. You'll see:
```
Circle SDK failed, using mock: [error]
```

This allows testing the UI flow without real API calls.

## Success Criteria
- [ ] Can authenticate with email
- [ ] Receive and verify OTP
- [ ] Set up PIN (new users)
- [ ] Create wallet successfully
- [ ] See wallet address in dashboard
- [ ] Session persists on refresh