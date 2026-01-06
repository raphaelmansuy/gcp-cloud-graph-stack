# OpenAI API Key Setup Guide

## 🔑 Critical: API Key Required

EdgeQuake requires a valid OpenAI API key for LLM operations. **Deployment will fail without a properly configured API key.**

---

## ⚠️ Error: Incorrect API Key

If you see this error:
```
LLM error: API error: Incorrect API key provided: placehol***-key. 
You can find your API key at https://platform.openai.com/account/api-keys.
```

**This means:**
- The `TF_VAR_openai_api_key` environment variable is not set, OR
- It contains a placeholder/invalid value

---

## 🚀 Quick Setup (5 minutes)

### Step 1: Get Your OpenAI API Key

1. Go to: https://platform.openai.com/account/api-keys
2. Sign in or create an account
3. Click **"Create new secret key"**
4. Copy the key (starts with `sk-proj-...` or `sk-...`)
5. **Save it securely** - you won't see it again!

### Step 2: Set Environment Variable

#### For Current Terminal Session:
```bash
export TF_VAR_openai_api_key="sk-proj-YOUR-ACTUAL-KEY-HERE"
```

#### For Permanent Setup (Recommended):

**macOS/Linux (zsh):**
```bash
echo 'export TF_VAR_openai_api_key="sk-proj-YOUR-ACTUAL-KEY-HERE"' >> ~/.zshrc
source ~/.zshrc
```

**macOS/Linux (bash):**
```bash
echo 'export TF_VAR_openai_api_key="sk-proj-YOUR-ACTUAL-KEY-HERE"' >> ~/.bashrc
source ~/.bashrc
```

### Step 3: Verify Setup

```bash
make check-openai-key
```

**Expected Output:**
```
✅ OpenAI API key is SET and appears VALID
   Format: sk-proj-ab...xyz
   Length: 64 characters
```

---

## 🔒 Security Best Practices

### ✅ DO:
- Store API key in environment variables
- Add to your shell profile (~/.zshrc or ~/.bashrc)
- Use Secret Manager for production
- Rotate keys regularly
- Set usage limits in OpenAI dashboard

### ❌ DON'T:
- Commit API keys to git
- Share keys in chat/email
- Use placeholder values
- Store in plain text files
- Hard-code in source code

---

## 🛠️ Validation Rules

The Makefile validates that:

1. **Key is Set**: `TF_VAR_openai_api_key` environment variable exists
2. **Not Placeholder**: Doesn't contain words like "placeholder", "example", "test", "dummy", "xxx"
3. **Minimum Length**: At least 40 characters
4. **Valid Format**: Starts with `sk-` or `sk-proj-`

---

## 🚢 Deployment Integration

### Automatic Validation

All deployment targets automatically check the API key:

```bash
make edgequake-full       # Full deployment (validates key first)
make edgequake-deploy     # Deploy via Terraform (validates key)
make edgequake-redeploy   # Force redeploy (validates key)
make plan                 # Terraform plan (validates key)
make apply                # Terraform apply (validates key)
```

### Manual Validation

```bash
make check-openai-key     # Check API key only
make validate-env         # Validate all environment variables
```

---

## 📋 Troubleshooting

### Problem: Key Not Found
```
❌ ERROR: TF_VAR_openai_api_key is NOT set
```

**Solution:**
```bash
export TF_VAR_openai_api_key="sk-proj-YOUR-KEY"
```

### Problem: Placeholder Detected
```
❌ ERROR: API key appears to be a PLACEHOLDER
```

**Solution:**
Replace with your real OpenAI API key from https://platform.openai.com/account/api-keys

### Problem: Key Too Short
```
❌ ERROR: API key is too SHORT (< 40 characters)
```

**Solution:**
Verify you copied the complete key. OpenAI keys are typically 50-80 characters.

### Problem: Invalid Format
```
❌ ERROR: API key format INVALID
```

**Solution:**
OpenAI keys must start with `sk-` or `sk-proj-`. Check you copied the correct key.

---

## 🧪 Testing Your API Key

### Test with curl:
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $TF_VAR_openai_api_key" \
  | jq '.data[0].id'
```

**Expected Output:**
```json
"gpt-4-turbo"
```

### Test with EdgeQuake Health Check:
```bash
# After deployment
curl https://edgequake-api-wszhkynzxa-uc.a.run.app/health | jq
```

**Expected Output:**
```json
{
  "status": "healthy",
  "components": {
    "llm_provider": true,
    ...
  }
}
```

---

## 🔄 Updating API Key

### For Running Services:

```bash
# Set new key
export TF_VAR_openai_api_key="sk-proj-NEW-KEY"

# Redeploy with new key
make edgequake-redeploy
```

### Via gcloud CLI:

```bash
gcloud run services update edgequake-api \
  --region=us-central1 \
  --project=saas-app-001 \
  --update-env-vars=OPENAI_API_KEY="sk-proj-NEW-KEY"
```

---

## 📚 Related Documentation

- [EdgeQuake Quick Start](17-edgequake-quick-start.md)
- [Deployment Guide](16-edgequake-deployment-complete-guide.md)
- [Security Checklist](25-security-checklist.md)
- [Environment Configuration](10-environment-configuration-examples.md)

---

## 💰 Cost Management

### Set OpenAI Usage Limits:

1. Go to: https://platform.openai.com/account/billing/limits
2. Set monthly budget limit
3. Enable email alerts
4. Monitor usage dashboard

### Typical EdgeQuake Costs:

- **Light use** (< 100 queries/day): $5-10/month
- **Medium use** (100-1000 queries/day): $20-50/month
- **Heavy use** (> 1000 queries/day): $50-200/month

---

## 🆘 Support

### If deployment still fails after setting API key:

1. **Verify environment variable:**
   ```bash
   echo $TF_VAR_openai_api_key | head -c 15
   ```

2. **Check Makefile validation:**
   ```bash
   make check-openai-key
   ```

3. **Test API key directly:**
   ```bash
   curl https://api.openai.com/v1/models \
     -H "Authorization: Bearer $TF_VAR_openai_api_key"
   ```

4. **Check Cloud Run environment:**
   ```bash
   gcloud run services describe edgequake-api \
     --region=us-central1 \
     --format='value(spec.template.spec.containers[0].env[?(@.name=="OPENAI_API_KEY")].value)'
   ```

5. **View service logs:**
   ```bash
   make edgequake-logs
   ```

---

## ✅ Success Checklist

Before deploying EdgeQuake, verify:

- [ ] OpenAI account created
- [ ] API key generated
- [ ] Environment variable set: `TF_VAR_openai_api_key`
- [ ] Key validated: `make check-openai-key` passes
- [ ] Key tested: `curl` request to OpenAI API succeeds
- [ ] Added to shell profile for persistence
- [ ] Usage limits configured in OpenAI dashboard

---

**Last Updated:** 2026-01-06
