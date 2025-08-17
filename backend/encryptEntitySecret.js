const crypto = require('crypto');
const forge = require('node-forge');

// Circle's public key for sandbox (this is from their documentation)
const CIRCLE_SANDBOX_PUBLIC_KEY = `-----BEGIN RSA PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxV/AmJsqvHfq3EGLsxUy
4bZg1pBrMZiEnKsO2TjbmGyp+JigyYceqfSqLfhYL7h8O3g8hMsXNgqVoVlL3Xwg
L/LXBvujzqvbYjoHhDocrKKZvJJ9C2c8aeUvd7N1TpZMBA8VHr8vDNgp9NJ14qVB
CpAYe7mJqpQy3s7jGmQvpxIULQpD2lQkU9ISIMIsM4bHhPkH++VLOkTkU4jMZCaF
9TJ7u/pHqr7ANOiL5jIqgRh3oddZdQU7HjFNdTcV5ogII3lSwBiGLLtnhxw1lqGC
LJZ0sFJNbBpqwcY6XqSwjmBHxXuGtNHmZW1Kf4T8oCNXjZR5UhQF+tKvUVLTBh3d
I8MjETCeHe9xTzOsBES7H7VHqKBPZ8OWhmI7kcFTnPUKJCMqiZ6Un7EFrhzuR+cM
7VGLSmM0v8pMOWgLAgKxncQoKLNLIcFZTAUyk0yF/HCp3XLDiGcPUE0qG5+Gl3pH
/s8KogTW6KTZg2rxMNks6XMWGmQKLgmrPn8DAjpYjlKRXRKlFyD2mohxLvEIf9kW
dMnMQA0x6unpfPefXWmzfAm5Sta7j0F4tJCkPeDEH6eWYZLUqRqTN7Jjk+lfzwqM
3EfB6Q6fGAoTloHUShF1krQPJq2KHqMCQVZbiNdVaLzNsSLBMQq8BI2668/Buhoh
kteDHC5pJ4HaBaAmTlVJGXsCAwEAAQ==
-----END RSA PUBLIC KEY-----`;

function encryptEntitySecret(entitySecret) {
  // Parse the public key
  const publicKey = forge.pki.publicKeyFromPem(CIRCLE_SANDBOX_PUBLIC_KEY);
  
  // Generate AES key and IV
  const aesKey = forge.random.getBytesSync(32);
  const iv = forge.random.getBytesSync(12);
  
  // Encrypt entity secret with AES-GCM
  const cipher = forge.cipher.createCipher('AES-GCM', aesKey);
  cipher.start({ iv: iv });
  cipher.update(forge.util.createBuffer(entitySecret));
  cipher.finish();
  
  const encrypted = cipher.output.getBytes();
  const tag = cipher.mode.tag.getBytes();
  
  // Encrypt AES key with RSA
  const encryptedKey = publicKey.encrypt(aesKey, 'RSA-OAEP', {
    md: forge.md.sha256.create(),
    mgf1: {
      md: forge.md.sha256.create()
    }
  });
  
  // Combine: encryptedKey + iv + tag + encrypted
  const combined = forge.util.encode64(
    encryptedKey + iv + tag + encrypted
  );
  
  return combined;
}

// Your entity secret
const entitySecret = 'ff0c9a1386d75da8e9ec4d160d2a797760e77613b4a7e61da92a6674f8f533d7';

try {
  const encrypted = encryptEntitySecret(entitySecret);
  console.log('Encrypted entity secret:');
  console.log(encrypted);
} catch (error) {
  console.error('Error:', error);
  console.log('\nNote: You may need to install node-forge first:');
  console.log('npm install node-forge');
}