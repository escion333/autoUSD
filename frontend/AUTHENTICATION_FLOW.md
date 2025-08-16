# Authentication Flow - Developer Controlled Wallets

## Important: Email OTP is NOT from Circle

With **Developer Controlled Wallets**, Circle does NOT send authentication emails. The platform (autoUSD) manages the entire authentication flow. Here's how it works:

## Current Development Setup

### 1. User Enters Email
- User provides email address
- Frontend calls `/api/circle/send-otp`

### 2. OTP Generation (Development Mode)
- API generates a 6-digit OTP
- **In Development**: OTP is displayed in:
  - Browser console (check Developer Tools)
  - Server console (terminal running `npm run dev`)
  - API response (for testing only)
- **In Production**: Would send real email via SendGrid/AWS SES

### 3. User Enters OTP
- User enters the 6-digit code
- Frontend calls `/api/circle/verify-otp`
- Session is created

### 4. Wallet Creation
- After authentication, wallet is created on-demand
- Uses Circle Developer Controlled Wallets
- One wallet per email address
- Gasless transactions enabled

## Why No Real Emails?

**Developer Controlled Wallets** means:
- ✅ Platform manages all wallets
- ✅ Platform handles authentication
- ✅ Circle doesn't know user emails
- ✅ No Circle emails sent

**User Controlled Wallets** would:
- ❌ Circle sends emails
- ❌ Users manage their own wallets
- ❌ More complex setup

## Testing Instructions

1. **Enter any email** (e.g., tom@spacebarcreative.com)
2. **Check console for OTP**:
   ```
   ================================
   📧 Email OTP for tom@spacebarcreative.com
   📱 Verification Code: 123456
   ================================
   ```
3. **Enter the OTP** shown in console
4. **Success!** Wallet created automatically

## Production Setup (TODO)

To send real emails in production, integrate an email service:

### Option 1: SendGrid
```typescript
npm install @sendgrid/mail

// In send-otp route:
import sgMail from '@sendgrid/mail';
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

await sgMail.send({
  to: email,
  from: 'noreply@autousd.com',
  subject: 'Your autoUSD verification code',
  html: `Your code is: <strong>${otp}</strong>`
});
```

### Option 2: AWS SES
```typescript
npm install @aws-sdk/client-ses

// Configure and send email via AWS
```

### Option 3: Resend
```typescript
npm install resend

// Simple, modern email API
```

## Current Status

✅ **Authentication works** - Just check console for OTP
✅ **Wallets created** - Real Circle wallets via Developer Controlled
✅ **Gasless ready** - SCA wallets with built-in paymaster
⏳ **Email service** - Needs integration for production

## Quick Test

1. Run the app: `npm run dev`
2. Open browser console (F12)
3. Sign up with any email
4. Look for OTP in console
5. Enter OTP
6. Wallet created!

The system is fully functional - just using console logging instead of real emails for development!