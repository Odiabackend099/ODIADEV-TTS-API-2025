# ODIADEV TTS API - Integration Guide

## Quick Start

The ODIADEV TTS API is a production-ready, self-hosted Text-to-Speech service built with FastAPI and Coqui TTS.

**Local Development:** `http://localhost:8080`  
**Production URL:** `https://[YOUR_DOMAIN]` (to be configured)

## 🔑 Authentication

All API requests (except `/health` and `/v1/voices`) require authentication using API keys.

### Getting an API Key

```bash
# Issue a new API key (requires admin token)
curl -X POST http://localhost:8080/admin/keys/issue \
  -H "x-admin-token: YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "my-app-key",
    "rate_limit_per_min": 60
  }'
```

### Response
```json
{
  "plaintext_key": "your-generated-api-key-here",
  "record": {
    "id": "uuid-here",
    "label": "my-app-key",
    "rate_limit_per_min": 60,
    "status": "active"
  }
}
```

**⚠️ Important:** Store the `plaintext_key` securely - it cannot be retrieved again!

## 🚀 Basic Usage

### 1. Check API Health

```bash
curl http://localhost:8080/health
```

### 2. List Available Voices

```bash
curl http://localhost:8080/v1/voices
```

### 3. Generate Speech from Text

```bash
curl -X POST http://localhost:8080/v1/tts \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello! Welcome to ODIADEV TTS service.",
    "voice": "naija_female",
    "format": "mp3",
    "speed": 1.0
  }' \
  --output speech.mp3

### 4. Response Formats

#### JSON Response (with S3 URL)
```json
{
  "url": "https://s3.af-south-1.amazonaws.com/bucket/tts-cache/abc123.mp3",
  "format": "mp3",
  "cache_hit": false,
  "ms": 2847
}
```

#### Binary Audio Response
If S3 is not configured, the API returns the audio file directly as `audio/mpeg` or `audio/wav`.

#### Health Response
```json
{
  "status": "ok",
  "engine": "coqui"
}
```

#### Voices Response
```json
{
  "voices": ["naija_female", "naija_male"],
  "engine": "coqui"
}
```

## 💻 Code Examples

### JavaScript/React Integration

```javascript
import React, { useState } from 'react';

const TTSComponent = () => {
  const [text, setText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [audioUrl, setAudioUrl] = useState(null);
  const [apiKey] = useState('YOUR_API_KEY'); // Store securely

  const generateSpeech = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('http://localhost:8080/v1/tts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey
        },
        body: JSON.stringify({
          text: text,
          voice: 'naija_female',
          format: 'mp3',
          speed: 1.0
        })
      });

      if (response.ok) {
        const contentType = response.headers.get('content-type');
        
        if (contentType.includes('application/json')) {
          // S3 URL response
          const result = await response.json();
          setAudioUrl(result.url);
        } else if (contentType.includes('audio')) {
          // Binary audio response
          const audioBlob = await response.blob();
          const url = URL.createObjectURL(audioBlob);
          setAudioUrl(url);
        }
      } else {
        console.error('TTS request failed:', response.status);
      }
    } catch (error) {
      console.error('TTS Error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div>
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Enter text to convert to speech..."
        rows={4}
        cols={50}
      />
      <br />
      <button onClick={generateSpeech} disabled={isLoading || !text}>
        {isLoading ? 'Generating...' : 'Generate Speech'}
      </button>
      
      {audioUrl && (
        <div>
          <h3>Generated Audio:</h3>
          <audio controls src={audioUrl} />
        </div>
      )}
    </div>
  );
};

export default TTSComponent;
```

### Python Integration

```python
import requests
import json
from typing import Optional, Union

class ODIADEVTTSClient:
    def __init__(self, base_url: str = "http://localhost:8080", api_key: Optional[str] = None):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.session = requests.Session()
    
    def set_api_key(self, api_key: str):
        """Set API key for authenticated requests"""
        self.api_key = api_key
    
    def health_check(self) -> dict:
        """Check API health status"""
        response = self.session.get(f"{self.base_url}/health")
        return response.json()
    
    def get_voices(self) -> dict:
        """Get available voices"""
        response = self.session.get(f"{self.base_url}/v1/voices")
        return response.json()
    
    def generate_speech(self, 
                       text: str, 
                       voice: str = "naija_female", 
                       format: str = "mp3",
                       speed: float = 1.0,
                       save_path: Optional[str] = None) -> Union[dict, bytes, None]:
        """Generate speech from text"""
        
        if not self.api_key:
            raise ValueError("API key is required for TTS generation")
        
        url = f"{self.base_url}/v1/tts"
        
        headers = {
            "Content-Type": "application/json",
            "x-api-key": self.api_key
        }
        
        data = {
            "text": text,
            "voice": voice,
            "format": format,
            "speed": speed
        }
        
        try:
            response = self.session.post(url, json=data, headers=headers, timeout=30)
            
            if response.status_code == 200:
                content_type = response.headers.get('content-type', '')
                
                if 'application/json' in content_type:
                    # S3 URL response
                    result = response.json()
                    
                    if save_path:
                        # Download from S3 URL and save
                        audio_response = requests.get(result['url'])
                        with open(save_path, 'wb') as f:
                            f.write(audio_response.content)
                        print(f"Audio saved to: {save_path}")
                    
                    return result
                    
                elif 'audio' in content_type:
                    # Binary audio response
                    audio_bytes = response.content
                    
                    if save_path:
                        with open(save_path, 'wb') as f:
                            f.write(audio_bytes)
                        print(f"Audio saved to: {save_path}")
                    
                    return audio_bytes
            else:
                print(f"Error {response.status_code}: {response.text}")
                return None
                
        except Exception as e:
            print(f"Request failed: {e}")
            return None
    
    def play_audio_from_bytes(self, audio_bytes: bytes):
        """Play audio from bytes (requires pydub)"""
        try:
            from pydub import AudioSegment
            from pydub.playback import play
            import io
            
            audio_io = io.BytesIO(audio_bytes)
            audio = AudioSegment.from_file(audio_io, format="mp3")
            play(audio)
        except ImportError:
            print("pydub required for audio playback: pip install pydub")
        except Exception as e:
            print(f"Playback failed: {e}")

# Usage Example
if __name__ == "__main__":
    # Initialize client
    client = ODIADEVTTSClient()
    
    # Check API health
    health = client.health_check()
    print(f"API Status: {health}")
    
    # Get available voices
    voices = client.get_voices()
    print(f"Available voices: {voices['voices']}")
    
    # Set API key (get this from admin/keys/issue endpoint)
    client.set_api_key("YOUR_API_KEY_HERE")
    
    # Generate speech
    text = "Hello! This is ODIADEV TTS service in action."
    result = client.generate_speech(text, voice="naija_female", save_path="output.mp3")
    
    if isinstance(result, dict) and 'url' in result:
        print(f"Audio available at: {result['url']}")
        print(f"Generation time: {result['ms']}ms")
    elif isinstance(result, bytes):
        print(f"Generated {len(result)} bytes of audio data")
        # client.play_audio_from_bytes(result)  # Uncomment to play
```

### Node.js/Express Integration

```javascript
const express = require('express');
const axios = require('axios');
const fs = require('fs');

const app = express();
app.use(express.json());

class ODIADEVTTSService {
  constructor(baseURL = 'http://localhost:8080', apiKey = null) {
    this.baseURL = baseURL;
    this.apiKey = apiKey;
  }

  setApiKey(apiKey) {
    this.apiKey = apiKey;
  }

  async healthCheck() {
    try {
      const response = await axios.get(`${this.baseURL}/health`);
      return response.data;
    } catch (error) {
      return { error: error.message };
    }
  }

  async getVoices() {
    try {
      const response = await axios.get(`${this.baseURL}/v1/voices`);
      return response.data;
    } catch (error) {
      return { error: error.message };
    }
  }

  async generateSpeech(text, voice = 'naija_female', format = 'mp3', speed = 1.0) {
    if (!this.apiKey) {
      return { success: false, error: 'API key is required' };
    }

    try {
      const response = await axios.post(`${this.baseURL}/v1/tts`, {
        text: text,
        voice: voice,
        format: format,
        speed: speed
      }, {
        headers: {
          'x-api-key': this.apiKey,
          'Content-Type': 'application/json'
        },
        responseType: 'arraybuffer',
        timeout: 30000
      });

      const contentType = response.headers['content-type'];
      
      if (contentType.includes('application/json')) {
        // S3 URL response
        const jsonData = JSON.parse(response.data.toString());
        return {
          success: true,
          url: jsonData.url,
          format: jsonData.format,
          cacheHit: jsonData.cache_hit,
          ms: jsonData.ms
        };
      } else if (contentType.includes('audio')) {
        // Binary audio response
        return {
          success: true,
          audioBuffer: response.data,
          format: format
        };
      }
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  saveAudioToFile(audioBuffer, filename) {
    fs.writeFileSync(filename, audioBuffer);
    return filename;
  }

  async downloadFromUrl(url, filename) {
    try {
      const response = await axios.get(url, { responseType: 'arraybuffer' });
      fs.writeFileSync(filename, response.data);
      return filename;
    } catch (error) {
      throw new Error(`Download failed: ${error.message}`);
    }
  }
}

// API endpoints
app.get('/health', async (req, res) => {
  const ttsService = new ODIADEVTTSService();
  const health = await ttsService.healthCheck();
  res.json(health);
});

app.get('/voices', async (req, res) => {
  const ttsService = new ODIADEVTTSService();
  const voices = await ttsService.getVoices();
  res.json(voices);
});

app.post('/generate-speech', async (req, res) => {
  const { text, voice, apiKey } = req.body;
  
  if (!text) {
    return res.status(400).json({ error: 'Text is required' });
  }
  
  if (!apiKey) {
    return res.status(400).json({ error: 'API key is required' });
  }

  const ttsService = new ODIADEVTTSService();
  ttsService.setApiKey(apiKey);
  
  const result = await ttsService.generateSpeech(text, voice);

  if (result.success) {
    if (result.url) {
      // S3 URL - optionally download and save locally
      res.json({
        success: true,
        url: result.url,
        format: result.format,
        cacheHit: result.cacheHit,
        ms: result.ms
      });
    } else if (result.audioBuffer) {
      // Binary audio - save to file
      const filename = `speech_${Date.now()}.${result.format}`;
      ttsService.saveAudioToFile(result.audioBuffer, filename);
      
      res.json({
        success: true,
        filename: filename,
        format: result.format
      });
    }
  } else {
    res.status(500).json({ error: result.error });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

## 🔑 API Key Management

### Admin Key Issuance

```bash
# Issue a new API key
curl -X POST http://localhost:8080/admin/keys/issue \
  -H "x-admin-token: YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "production-app",
    "rate_limit_per_min": 100,
    "tenant_id": "optional-tenant-uuid"
  }'
```

### Python Admin Client

```python
import requests
import hashlib
import secrets

class ODIADEVAdmin:
    def __init__(self, base_url, admin_token):
        self.base_url = base_url.rstrip('/')
        self.admin_token = admin_token
    
    def issue_api_key(self, label, rate_limit_per_min=60, tenant_id=None):
        """Issue a new API key"""
        url = f"{self.base_url}/admin/keys/issue"
        headers = {
            "x-admin-token": self.admin_token,
            "Content-Type": "application/json"
        }
        data = {
            "label": label,
            "rate_limit_per_min": rate_limit_per_min
        }
        if tenant_id:
            data["tenant_id"] = tenant_id
        
        response = requests.post(url, json=data, headers=headers)
        return response.json() if response.status_code in [200, 201] else None

# Usage
admin = ODIADEVAdmin("http://localhost:8080", "YOUR_ADMIN_TOKEN")
key_info = admin.issue_api_key("mobile-app", rate_limit_per_min=120)
if key_info:
    print(f"New API Key: {key_info['plaintext_key']}")
    print(f"Key ID: {key_info['record']['id']}")
```

### Using API Keys in Requests

```javascript
// JavaScript
const headers = {
  'Content-Type': 'application/json',
  'x-api-key': 'your_api_key_here'
};

fetch('http://localhost:8080/v1/tts', {
  method: 'POST',
  headers: headers,
  body: JSON.stringify({
    text: 'Authenticated request',
    voice: 'naija_female'
  })
});
```

```python
# Python
headers = {
    'Content-Type': 'application/json',
    'x-api-key': 'your_api_key_here'
}

requests.post('http://localhost:8080/v1/tts', json={
    'text': 'Authenticated request',
    'voice': 'naija_female'
}, headers=headers)
```
```

## 🎯 Use Cases

### 1. Conversational AI Agents
```python
def create_ai_response_with_voice(user_message):
    # Generate AI response (using your AI model)
    ai_response = generate_ai_response(user_message)
    
    # Convert to speech
    tts_client = ODIADEVTTSClient()
    audio_data = tts_client.generate_speech(ai_response)
    
    return {
        'text': ai_response,
        'audio': audio_data
    }
```

### 2. Content Narration
```javascript
async function narrateArticle(articleText) {
  const paragraphs = articleText.split('\n\n');
  const audioSegments = [];
  
  for (const paragraph of paragraphs) {
    const result = await generateSpeech(paragraph);
    if (result.success) {
      audioSegments.push(result.audioBase64);
    }
  }
  
  return audioSegments;
}
```

### 3. Accessibility Features
```python
def make_content_accessible(text_content):
    """Convert text content to audio for accessibility"""
    tts_client = ODIADEVTTSClient()
    
    # Break long content into chunks
    chunks = split_text_into_chunks(text_content, max_length=1000)
    audio_files = []
    
    for i, chunk in enumerate(chunks):
        audio_data = tts_client.generate_speech(chunk)
        filename = f"accessibility_audio_{i}.mp3"
        
        with open(filename, 'wb') as f:
            f.write(audio_data)
        
        audio_files.append(filename)
    
    return audio_files
```

## 📱 Mobile Integration

### React Native Example

```javascript
import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, Alert } from 'react-native';
import { Audio } from 'expo-av';

const TTSScreen = () => {
  const [text, setText] = useState('');
  const [sound, setSound] = useState();

  const generateAndPlaySpeech = async () => {
    try {
      const response = await fetch('https://kkh7ikcydv7d.manus.space/api/tts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: text,
          voice: 'alloy'
        })
      });

      const result = await response.json();
      
      if (result.success) {
        // Convert base64 to audio and play
        const audioUri = `data:audio/mp3;base64,${result.data.audio_base64}`;
        const { sound } = await Audio.Sound.createAsync({ uri: audioUri });
        setSound(sound);
        await sound.playAsync();
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to generate speech');
    }
  };

  return (
    <View style={{ padding: 20 }}>
      <TextInput
        value={text}
        onChangeText={setText}
        placeholder="Enter text to speak..."
        multiline
        style={{ borderWidth: 1, padding: 10, marginBottom: 20 }}
      />
      <TouchableOpacity onPress={generateAndPlaySpeech}>
        <Text>Generate Speech</Text>
      </TouchableOpacity>
    </View>
  );
};
```

## 🔧 Error Handling

```python
def robust_tts_request(text, max_retries=3):
    """Make TTS request with retry logic"""
    for attempt in range(max_retries):
        try:
            response = requests.post(
                'https://kkh7ikcydv7d.manus.space/api/tts',
                json={'text': text, 'voice': 'alloy'},
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('success'):
                    return result['data']['audio_base64']
            
            print(f"Attempt {attempt + 1} failed: {response.status_code}")
            
        except requests.exceptions.RequestException as e:
            print(f"Request error on attempt {attempt + 1}: {e}")
        
        if attempt < max_retries - 1:
            time.sleep(2 ** attempt)  # Exponential backoff
    
    return None
```

## 📊 Monitoring & Analytics

```python
import time
import logging

class TTSAnalytics:
    def __init__(self):
        self.request_count = 0
        self.total_characters = 0
        self.response_times = []
    
    def track_request(self, text, response_time):
        self.request_count += 1
        self.total_characters += len(text)
        self.response_times.append(response_time)
    
    def get_stats(self):
        avg_response_time = sum(self.response_times) / len(self.response_times)
        return {
            'total_requests': self.request_count,
            'total_characters': self.total_characters,
            'avg_response_time': avg_response_time,
            'avg_characters_per_request': self.total_characters / self.request_count
        }

# Usage
analytics = TTSAnalytics()

def monitored_tts_request(text):
    start_time = time.time()
    
    # Make TTS request
    result = make_tts_request(text)
    
    response_time = time.time() - start_time
    analytics.track_request(text, response_time)
    
    return result
```

## 🚀 Production Deployment

### Endpoints

- **Local Development:** `http://localhost:8080`
- **Production:** `https://[YOUR_DOMAIN]` (configure after deployment)

### Available Voices

- `naija_female` - Nigerian English female voice
- `naija_male` - Nigerian English male voice

### Supported Formats

- `mp3` (default) - Most compatible
- `wav` - High quality, larger files
- `ogg` - Open source format

### Rate Limits

- Default: 60 requests/minute per API key
- Configurable per key via admin interface
- Global instance limit: 1000 requests/minute

## 🔧 Error Handling

```python
def robust_tts_request(text, api_key, max_retries=3):
    """Make TTS request with retry logic"""
    import time
    
    for attempt in range(max_retries):
        try:
            response = requests.post(
                'http://localhost:8080/v1/tts',
                json={
                    'text': text, 
                    'voice': 'naija_female',
                    'format': 'mp3'
                },
                headers={'x-api-key': api_key},
                timeout=30
            )
            
            if response.status_code == 200:
                return response.content if 'audio' in response.headers.get('content-type', '') else response.json()
            elif response.status_code == 401:
                raise ValueError("Invalid API key")
            elif response.status_code == 429:
                print(f"Rate limited on attempt {attempt + 1}")
            else:
                print(f"Attempt {attempt + 1} failed: {response.status_code}")
            
        except requests.exceptions.RequestException as e:
            print(f"Request error on attempt {attempt + 1}: {e}")
        
        if attempt < max_retries - 1:
            time.sleep(2 ** attempt)  # Exponential backoff
    
    return None
```

## 📊 Monitoring & Analytics

### Usage Tracking

The API automatically tracks:
- Character count per request
- Response time (ms)
- Cache hit/miss ratio
- Rate limit consumption

### Health Monitoring

```bash
# Check API health
curl http://localhost:8080/health

# Expected response
{
  "status": "ok",
  "engine": "coqui"
}
```

## 📱 Mobile Integration Examples

### React Native with Expo

```javascript
import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, Alert } from 'react-native';
import { Audio } from 'expo-av';

const TTSScreen = () => {
  const [text, setText] = useState('');
  const [sound, setSound] = useState();
  const [apiKey] = useState('YOUR_API_KEY'); // Store securely

  const generateAndPlaySpeech = async () => {
    try {
      const response = await fetch('http://localhost:8080/v1/tts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey
        },
        body: JSON.stringify({
          text: text,
          voice: 'naija_female',
          format: 'mp3'
        })
      });

      if (response.ok) {
        const contentType = response.headers.get('content-type');
        
        if (contentType.includes('application/json')) {
          const result = await response.json();
          // Play from S3 URL
          const { sound } = await Audio.Sound.createAsync({ uri: result.url });
          setSound(sound);
          await sound.playAsync();
        } else {
          // Handle binary audio response
          const audioBlob = await response.blob();
          const audioUri = URL.createObjectURL(audioBlob);
          const { sound } = await Audio.Sound.createAsync({ uri: audioUri });
          setSound(sound);
          await sound.playAsync();
        }
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to generate speech');
    }
  };

  return (
    <View style={{ padding: 20 }}>
      <TextInput
        value={text}
        onChangeText={setText}
        placeholder="Enter text to speak..."
        multiline
        style={{ borderWidth: 1, padding: 10, marginBottom: 20 }}
      />
      <TouchableOpacity onPress={generateAndPlaySpeech}>
        <Text>Generate Speech</Text>
      </TouchableOpacity>
    </View>
  );
};
```

## 📚 Documentation & Support

### Additional Resources

- **Deployment Guide:** `DEPLOYMENT_REPORT.md`
- **Setup Scripts:** `scripts/setup-env.ps1`, `scripts/setup-aws.ps1`
- **Test Suite:** `tests/test_tts_api.py`, `tests/test-endpoints.ps1`
- **API Schema:** Available at `/docs` endpoint when running

### Configuration

- **Environment:** Configure via `config/.env`
- **Admin Token:** Stored securely in `secrets/ADMIN_TOKEN.txt`
- **Supabase:** Required for API key management
- **AWS S3:** Optional for audio caching

### Performance

- **TTS Generation:** < 3s for 200 characters
- **Cache Response:** < 100ms for cached audio
- **Concurrent Users:** Supports multiple simultaneous requests

## 🎆 Ready to Use!

The ODIADEV TTS API is production-ready with:

✅ **Nigerian English voices** (naija_female, naija_male)  
✅ **Multiple audio formats** (MP3, WAV, OGG)  
✅ **S3 caching** for performance  
✅ **Rate limiting** and usage tracking  
✅ **Docker deployment** ready  
✅ **Comprehensive testing** suite  

### Quick Start Commands

```bash
# Local setup
.\scripts\setup-env.ps1
docker build -t odiadev/tts:local -f server/Dockerfile .
docker compose -f infra/docker-compose.yml up -d

# Test the API
.\tests\test-endpoints.ps1

# Deploy to production
.\scripts\setup-aws.ps1
# Follow deployment guide
```

**Local API:** http://localhost:8080  
**Production API:** https://[YOUR_DOMAIN] (after deployment)

For support, deployment assistance, or custom voice training, refer to the deployment documentation and test results.

