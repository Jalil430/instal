# Instal API Credentials & Usage

## API Endpoints
- **Base URL**: `https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net`
- **Authentication**: API Key in `X-API-Key` header

## API Key
```
05edf99238bc0c342aa0cc48be2363ffcebbbf15b7d0eaca4f31dbd6a03d30be
```

## Rate Limits
- **POST /clients**: 10 requests per minute
- **GET /clients/{id}**: 30 requests per minute

## Example Usage

### Create Client
```bash
curl -X POST https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net/clients \
  -H "Content-Type: application/json" \
  -H "X-API-Key: 05edf99238bc0c342aa0cc48be2363ffcebbbf15b7d0eaca4f31dbd6a03d30be" \
  -d '{
    "user_id": "user123",
    "full_name": "John Doe",
    "contact_number": "+1234567890",
    "passport_number": "AB123456",
    "address": "123 Main St"
  }'
```

### Get Client
```bash
curl -X GET https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net/clients/{client_id} \
  -H "X-API-Key: 05edf99238bc0c342aa0cc48be2363ffcebbbf15b7d0eaca4f31dbd6a03d30be"
```

## Security Features Implemented
- ✅ API Key Authentication
- ✅ Input Validation & Sanitization
- ✅ Rate Limiting
- ✅ Proper Error Handling (no internal details exposed)
- ✅ Request/Response Logging
- ✅ CORS Configuration
- ✅ Minimal Permission Model

## Infrastructure Security
- ✅ YDB Serverless Database with metadata authentication
- ✅ Service accounts with minimal required permissions
- ✅ Secure environment variable handling
- ✅ No hardcoded secrets in code 