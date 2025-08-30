"""
ODIADEV TTS Audio Regeneration - Simplified Version
==================================================

This script generates all ODIADEV company audio content using the 
production TTS server running on port 5003.
"""

import os
import base64
import time
import requests
import json
from datetime import datetime

# Configuration
TARGET_DIRECTORY = r"C:\Users\OD~IA\Music\ODIA-TTS-TEST-AUDIO"
PRODUCTION_API_URL = "http://127.0.0.1:5003"

def ensure_target_directory():
    """Ensure the target directory exists"""
    try:
        if not os.path.exists(TARGET_DIRECTORY):
            os.makedirs(TARGET_DIRECTORY, exist_ok=True)
            print(f"✅ Created target directory: {TARGET_DIRECTORY}")
        else:
            print(f"✅ Target directory exists: {TARGET_DIRECTORY}")
        return True
    except Exception as e:
        print(f"❌ Failed to create target directory: {e}")
        return False

def test_server_connection():
    """Test if the production server is running"""
    try:
        response = requests.get(f"{PRODUCTION_API_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Production TTS server is running")
            print(f"   Service: {data.get('service', 'Unknown')}")
            print(f"   OpenAI Configured: {data.get('openai_configured', False)}")
            return True
        else:
            print(f"❌ Server health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Server not accessible: {e}")
        return False

def generate_tts_file(text, filename, voice="alloy"):
    """Generate TTS audio file using production API"""
    try:
        print(f"🎙️ Generating: {filename}")
        print(f"   Text: {text[:60]}{'...' if len(text) > 60 else ''}")
        
        # Make request to production TTS API
        response = requests.post(
            f"{PRODUCTION_API_URL}/tts",
            json={"text": text, "voice": voice},
            timeout=60
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                tts_data = data.get('data', {})
                audio_base64 = tts_data.get('audio_base64', '')
                
                if audio_base64:
                    # Decode and save audio file
                    audio_bytes = base64.b64decode(audio_base64)
                    file_path = os.path.join(TARGET_DIRECTORY, f"{filename}.mp3")
                    
                    with open(file_path, 'wb') as f:
                        f.write(audio_bytes)
                    
                    file_size = len(audio_bytes)
                    print(f"✅ Saved: {filename}.mp3 ({file_size:,} bytes)")
                    
                    return {
                        'success': True,
                        'filename': f"{filename}.mp3",
                        'file_path': file_path,
                        'size_bytes': file_size,
                        'text': text,
                        'voice': voice,
                        'provider': tts_data.get('provider', 'openai')
                    }
                else:
                    print(f"❌ No audio data received for {filename}")
                    return {'success': False, 'error': 'No audio data'}
            else:
                error = data.get('error', 'Unknown error')
                print(f"❌ TTS generation failed for {filename}: {error}")
                return {'success': False, 'error': error}
        else:
            print(f"❌ API request failed for {filename}: HTTP {response.status_code}")
            return {'success': False, 'error': f'HTTP {response.status_code}'}
            
    except Exception as e:
        print(f"❌ Exception generating {filename}: {e}")
        return {'success': False, 'error': str(e)}

def get_odiadev_company_segments():
    """Get all ODIADEV company speech segments"""
    return [
        {
            "filename": "01_welcome_intro",
            "text": "Welcome to ODIADEV - The Future of Voice AI in Nigeria.",
            "voice": "alloy"
        },
        {
            "filename": "02_company_mission",
            "text": "ODIADEV is pioneering the next generation of artificial intelligence solutions specifically designed for Nigeria and Africa.",
            "voice": "alloy"
        },
        {
            "filename": "03_product_intro", 
            "text": "Our flagship product, ODIADEV TTS, is set to revolutionize how Nigerians interact with technology through voice.",
            "voice": "alloy"
        },
        {
            "filename": "04_market_problem",
            "text": "For too long, voice AI has been expensive and inaccessible to everyday Nigerians.",
            "voice": "alloy"
        },
        {
            "filename": "05_cost_barrier",
            "text": "International solutions cost thousands of dollars, putting them out of reach for small businesses and developers.",
            "voice": "alloy"
        },
        {
            "filename": "06_solution_intro",
            "text": "ODIADEV changes that completely.",
            "voice": "alloy"
        },
        {
            "filename": "07_affordable_pricing",
            "text": "With ODIADEV TTS, we're making professional-grade text-to-speech technology available at a fraction of the cost.",
            "voice": "alloy"
        },
        {
            "filename": "08_pricing_details",
            "text": "Starting at just 8,000 Naira for our Starter plan, up to 75,000 Naira for Enterprise.",
            "voice": "alloy"
        },
        {
            "filename": "09_democratization",
            "text": "We're democratizing voice AI for everyone.",
            "voice": "alloy"
        },
        {
            "filename": "10_differentiation",
            "text": "What makes us different? We understand Nigeria.",
            "voice": "alloy"
        },
        {
            "filename": "11_local_optimization",
            "text": "Our system is optimized for Nigerian networks, supports local languages and accents.",
            "voice": "alloy"
        },
        {
            "filename": "12_network_resilience",
            "text": "We work seamlessly even with slower internet connections.",
            "voice": "alloy"
        },
        {
            "filename": "13_nationwide_coverage",
            "text": "Whether you're in Lagos, Abuja, Port Harcourt, or remote areas, ODIADEV TTS delivers reliable voice generation.",
            "voice": "alloy"
        },
        {
            "filename": "14_vision_statement",
            "text": "Imagine a Nigeria where every small business can afford an AI voice assistant.",
            "voice": "alloy"
        },
        {
            "filename": "15_use_cases",
            "text": "Where educational apps can speak in local languages, where customer service is available 24/7 at minimal cost.",
            "voice": "alloy"
        },
        {
            "filename": "16_building_future",
            "text": "That's the Nigeria we're building at ODIADEV.",
            "voice": "alloy"
        },
        {
            "filename": "17_economic_impact",
            "text": "ODIADEV TTS isn't just about technology - it's about economic empowerment.",
            "voice": "alloy"
        },
        {
            "filename": "18_job_creation",
            "text": "We're creating jobs, supporting local innovation, and ensuring Nigeria leads AI development in Africa.",
            "voice": "alloy"
        },
        {
            "filename": "19_call_to_action",
            "text": "Join the voice AI revolution. Choose ODIADEV TTS.",
            "voice": "alloy"
        },
        {
            "filename": "20_final_message",
            "text": "Affordable, reliable, and proudly Nigerian. ODIADEV - Empowering Nigeria through Artificial Intelligence.",
            "voice": "alloy"
        },
        # Voice variants for key messages
        {
            "filename": "21_welcome_nova",
            "text": "Welcome to ODIADEV - The Future of Voice AI in Nigeria.",
            "voice": "nova"
        },
        {
            "filename": "22_affordable_echo",
            "text": "Starting at just 8,000 Naira, we're making voice AI affordable for every Nigerian business.",
            "voice": "echo"
        },
        {
            "filename": "23_revolution_onyx",
            "text": "Join the voice AI revolution. Choose ODIADEV TTS - Affordable, reliable, and proudly Nigerian.",
            "voice": "onyx"
        },
        {
            "filename": "24_empowerment_shimmer",
            "text": "ODIADEV - Empowering Nigeria through Artificial Intelligence.",
            "voice": "shimmer"
        },
        {
            "filename": "25_complete_pitch_fable",
            "text": "ODIADEV TTS revolutionizes voice AI for Nigeria. Starting at 8,000 Naira, we make professional voice technology accessible to every business. Join us in building the future of African AI.",
            "voice": "fable"
        }
    ]

def create_playlist_file(results):
    """Create a playlist file with all generated audio"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    playlist_file = os.path.join(TARGET_DIRECTORY, f"ODIADEV_Company_Playlist_{timestamp}.txt")
    
    try:
        with open(playlist_file, 'w', encoding='utf-8') as f:
            f.write("ODIADEV Company Audio - Complete Playlist (Real OpenAI TTS)\\n")
            f.write(f"Generated: {datetime.now().isoformat()}\\n")
            f.write(f"Location: {TARGET_DIRECTORY}\\n")
            f.write("=" * 70 + "\\n\\n")
            
            successful_files = [r for r in results if r['success']]
            total_size = sum(r['size_bytes'] for r in successful_files)
            
            f.write(f"Total Files: {len(successful_files)}\\n")
            f.write(f"Total Size: {total_size:,} bytes ({total_size/1024:.1f} KB) ({total_size/(1024*1024):.2f} MB)\\n")
            f.write(f"Provider: OpenAI TTS (Real API)\\n")
            f.write(f"Quality: Production Grade\\n\\n")
            
            f.write("Audio Files:\\n")
            f.write("-" * 50 + "\\n")
            
            for i, result in enumerate(successful_files, 1):
                f.write(f"{i:2d}. {result['filename']} ({result['size_bytes']:,} bytes)\\n")
                f.write(f"    Voice: {result['voice']}\\n")
                f.write(f"    Text: {result['text'][:80]}{'...' if len(result['text']) > 80 else ''}\\n\\n")
            
            f.write("\\n" + "=" * 70 + "\\n")
            f.write("USAGE INSTRUCTIONS:\\n")
            f.write("1. Files are in MP3 format, ready for immediate use\\n")
            f.write("2. Play in sequence for complete company presentation\\n")
            f.write("3. Use individual segments for specific marketing needs\\n")
            f.write("4. Voice variants (files 21-25) provide different tones\\n")
            f.write("5. All audio generated using OpenAI's production TTS API\\n")
        
        print(f"✅ Playlist created: {os.path.basename(playlist_file)}")
        return playlist_file
        
    except Exception as e:
        print(f"❌ Failed to create playlist: {e}")
        return None

def main():
    """Main audio regeneration process"""
    print("🎙️ ODIADEV TTS Audio Regeneration - Real OpenAI API")
    print("=" * 60)
    print(f"Target Directory: {TARGET_DIRECTORY}")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Step 1: Ensure target directory exists
    if not ensure_target_directory():
        print("❌ Cannot proceed without target directory")
        return False
    
    # Step 2: Test server connection
    if not test_server_connection():
        print("❌ Production TTS server is not running")
        print("   Please start the server with: py production_tts_app.py")
        return False
    
    # Step 3: Get all audio segments to generate
    all_segments = get_odiadev_company_segments()
    
    print(f"🎯 Generating {len(all_segments)} high-quality audio files...")
    print("   Using real OpenAI TTS API for production-grade audio")
    print()
    
    # Step 4: Generate all audio files
    results = []
    successful = 0
    failed = 0
    total_size = 0
    
    for i, segment in enumerate(all_segments, 1):
        print(f"[{i:2d}/{len(all_segments)}]", end=" ")
        
        result = generate_tts_file(
            text=segment['text'],
            filename=segment['filename'],
            voice=segment['voice']
        )
        
        results.append(result)
        
        if result['success']:
            successful += 1
            total_size += result['size_bytes']
        else:
            failed += 1
        
        # Small delay between requests to avoid rate limiting
        time.sleep(1)
        print()
    
    # Step 5: Create playlist file
    playlist_file = create_playlist_file(results)
    
    # Step 6: Summary report
    print("=" * 60)
    print("📊 AUDIO REGENERATION COMPLETE")
    print("=" * 60)
    print(f"Total Segments: {len(all_segments)}")
    print(f"Successful: {successful}")
    print(f"Failed: {failed}")
    print(f"Success Rate: {successful/len(all_segments)*100:.1f}%")
    
    if successful > 0:
        print(f"Total Audio: {total_size:,} bytes ({total_size/1024:.1f} KB) ({total_size/(1024*1024):.2f} MB)")
        print(f"Average Size: {total_size/successful:,.0f} bytes per file")
    
    print(f"\\nFiles Location: {TARGET_DIRECTORY}")
    
    if playlist_file:
        print(f"Playlist: {os.path.basename(playlist_file)}")
    
    if successful == len(all_segments):
        print("\\n🎉 ALL AUDIO FILES GENERATED SUCCESSFULLY!")
        print("   Your ODIADEV company audio is ready for professional use!")
        print("   Real OpenAI TTS provides production-grade quality!")
    elif successful > 0:
        print(f"\\n✅ {successful} files generated successfully")
        print("   Some files may need retry for complete set")
    else:
        print("\\n❌ No files were generated successfully")
        print("   Check API key and server configuration")
    
    return successful > 0

if __name__ == "__main__":
    success = main()
    if success:
        print("\\n🇳🇬 ODIADEV TTS - Making Voice AI Affordable for Nigeria! 🎙️")
        print("\\n🎵 Your professional-grade company audio is now ready!")
    else:
        print("\\n⚠️ Audio regeneration encountered issues. Please check the logs above.")
    
    print("\\nPress Enter to exit...")
    input()