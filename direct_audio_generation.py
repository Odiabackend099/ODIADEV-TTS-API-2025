"""
ODIADEV TTS Direct Audio Generation
==================================

This script directly uses OpenAI TTS API to generate all ODIADEV 
company audio content and saves to the target directory.
"""

import os
import base64
import time
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
config_path = os.path.join(os.path.dirname(__file__), 'config', '.env')
load_dotenv(config_path)

# Configuration
TARGET_DIRECTORY = r"C:\Users\OD~IA\Music\ODIA-TTS-TEST-AUDIO"

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

def generate_tts_direct(text, voice="alloy"):
    """Generate TTS using OpenAI API directly"""
    try:
        # Get OpenAI API key
        openai_key = os.getenv('OPENAI_API_KEY')
        if not openai_key or openai_key.startswith('#'):
            raise Exception("OpenAI API key not configured")
        
        # Import OpenAI client
        from openai import OpenAI
        client = OpenAI(api_key=openai_key)
        
        print(f"   🔊 Using OpenAI TTS-1 model with {voice} voice")
        
        # Generate TTS
        response = client.audio.speech.create(
            model="tts-1",
            voice=voice,
            input=text,
            response_format="mp3"
        )
        
        # Get audio data
        audio_data = response.content
        
        return {
            "success": True,
            "audio_data": audio_data,
            "size_bytes": len(audio_data),
            "text": text,
            "voice": voice,
            "provider": "openai-direct"
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def generate_audio_file(text, filename, voice="alloy"):
    """Generate and save TTS audio file"""
    try:
        print(f"🎙️ Generating: {filename}")
        print(f"   Text: {text[:60]}{'...' if len(text) > 60 else ''}")
        
        # Generate TTS
        result = generate_tts_direct(text, voice)
        
        if result['success']:
            # Save audio file
            file_path = os.path.join(TARGET_DIRECTORY, f"{filename}.mp3")
            
            with open(file_path, 'wb') as f:
                f.write(result['audio_data'])
            
            file_size = result['size_bytes']
            print(f"✅ Saved: {filename}.mp3 ({file_size:,} bytes)")
            
            return {
                'success': True,
                'filename': f"{filename}.mp3",
                'file_path': file_path,
                'size_bytes': file_size,
                'text': text,
                'voice': voice,
                'provider': 'openai-direct'
            }
        else:
            error = result.get('error', 'Unknown error')
            print(f"❌ Failed: {error}")
            return {'success': False, 'error': error}
            
    except Exception as e:
        print(f"❌ Exception: {e}")
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
            f.write("ODIADEV Company Audio - Production Quality (OpenAI TTS)\\n")
            f.write(f"Generated: {datetime.now().isoformat()}\\n")
            f.write(f"Location: {TARGET_DIRECTORY}\\n")
            f.write("=" * 70 + "\\n\\n")
            
            successful_files = [r for r in results if r['success']]
            total_size = sum(r['size_bytes'] for r in successful_files)
            
            f.write(f"Total Files: {len(successful_files)}\\n")
            f.write(f"Total Size: {total_size:,} bytes ({total_size/1024:.1f} KB) ({total_size/(1024*1024):.2f} MB)\\n")
            f.write(f"Provider: OpenAI TTS-1 (Production API)\\n")
            f.write(f"Quality: Production Grade\\n\\n")
            
            f.write("Audio Files (Playback Order):\\n")
            f.write("-" * 50 + "\\n")
            
            for i, result in enumerate(successful_files, 1):
                f.write(f"{i:2d}. {result['filename']} ({result['size_bytes']:,} bytes)\\n")
                f.write(f"    Voice: {result['voice']}\\n")
                f.write(f"    Text: {result['text'][:80]}{'...' if len(result['text']) > 80 else ''}\\n\\n")
            
            f.write("\\n" + "=" * 70 + "\\n")
            f.write("USAGE INSTRUCTIONS:\\n")
            f.write("1. Files are high-quality MP3 format from OpenAI TTS-1\\n")
            f.write("2. Play files 01-20 in sequence for complete presentation\\n")
            f.write("3. Files 21-25 are voice variants of key messages\\n")
            f.write("4. Use individual segments for specific marketing needs\\n")
            f.write("5. Professional broadcast quality suitable for all media\\n")
            f.write("\\nODIADEV TTS - Empowering Nigeria through Artificial Intelligence\\n")
        
        print(f"✅ Playlist created: {os.path.basename(playlist_file)}")
        return playlist_file
        
    except Exception as e:
        print(f"❌ Failed to create playlist: {e}")
        return None

def main():
    """Main audio generation process"""
    print("🎙️ ODIADEV TTS Direct Audio Generation")
    print("=" * 60)
    print("🚀 Using OpenAI TTS API for Production-Grade Audio")
    print(f"📁 Target Directory: {TARGET_DIRECTORY}")
    print(f"⏰ Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Check OpenAI API key
    openai_key = os.getenv('OPENAI_API_KEY')
    if not openai_key or openai_key.startswith('#'):
        print("❌ OpenAI API key not configured!")
        print("   Please check config/.env file")
        return False
    
    print(f"✅ OpenAI API Key: {openai_key[:20]}...{openai_key[-10:]}")
    
    # Step 1: Ensure target directory exists
    if not ensure_target_directory():
        print("❌ Cannot proceed without target directory")
        return False
    
    # Step 2: Get all audio segments to generate
    all_segments = get_odiadev_company_segments()
    
    print(f"🎯 Generating {len(all_segments)} production-quality audio files...")
    print("   Each file will be generated using OpenAI TTS-1 model")
    print()
    
    # Step 3: Generate all audio files
    results = []
    successful = 0
    failed = 0
    total_size = 0
    
    start_time = time.time()
    
    for i, segment in enumerate(all_segments, 1):
        print(f"[{i:2d}/{len(all_segments)}]", end=" ")
        
        result = generate_audio_file(
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
        
        # Small delay to avoid rate limiting
        time.sleep(0.5)
        print()
    
    generation_time = time.time() - start_time
    
    # Step 4: Create playlist file
    playlist_file = create_playlist_file(results)
    
    # Step 5: Final summary
    print("=" * 60)
    print("🎉 AUDIO GENERATION COMPLETE!")
    print("=" * 60)
    print(f"Total Segments: {len(all_segments)}")
    print(f"✅ Successful: {successful}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Success Rate: {successful/len(all_segments)*100:.1f}%")
    print(f"⏱️ Generation Time: {generation_time:.1f} seconds")
    
    if successful > 0:
        print(f"📏 Total Audio: {total_size:,} bytes ({total_size/1024:.1f} KB) ({total_size/(1024*1024):.2f} MB)")
        print(f"📊 Average Size: {total_size/successful:,.0f} bytes per file")
    
    print(f"\\n📁 Files Location: {TARGET_DIRECTORY}")
    
    if playlist_file:
        print(f"📋 Playlist: {os.path.basename(playlist_file)}")
    
    if successful == len(all_segments):
        print("\\n🎉 ALL AUDIO FILES GENERATED SUCCESSFULLY!")
        print("\\n🎵 Your ODIADEV company audio is ready!")
        print("   ✨ Professional-grade quality from OpenAI TTS")
        print("   🎯 Perfect for marketing, presentations, and demos")
        print("   🇳🇬 Optimized for Nigerian business context")
    elif successful > 0:
        print(f"\\n✅ {successful} files generated successfully")
        print("   Some files may need retry for complete set")
    else:
        print("\\n❌ No files were generated successfully")
        print("   Check API key and internet connection")
    
    return successful > 0

if __name__ == "__main__":
    print("🎙️ ODIADEV TTS - Direct OpenAI Audio Generation")
    print("🇳🇬 Making Voice AI Affordable for Nigeria!")
    print()
    
    success = main()
    
    if success:
        print("\\n" + "=" * 60)
        print("🎊 MISSION ACCOMPLISHED!")
        print("🎙️ Your ODIADEV TTS company audio is ready for the world!")
        print("🚀 Go forth and revolutionize Nigerian voice AI!")
        print("=" * 60)
    else:
        print("\\n⚠️ Generation encountered issues. Please check the logs above.")
    
    print("\\nPress Enter to exit...")
    input()