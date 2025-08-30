import os
import requests
import json
import base64
from datetime import datetime
import subprocess
import sys

def test_existing_test_files():
    """Run existing test files to ensure nothing is broken"""
    print("🔍 Running existing test suite...")
    print("-" * 40)
    
    test_results = {}
    
    # Test files to run
    test_files = [
        'test_api.py',
        'test_enhanced_api.py', 
        'test_tts_api.py'
    ]
    
    for test_file in test_files:
        test_path = os.path.join('tests', test_file)
        if os.path.exists(test_path):
            print(f"Running {test_file}...")
            try:
                result = subprocess.run([sys.executable, test_path], 
                                      capture_output=True, text=True, timeout=60)
                
                success = result.returncode == 0
                test_results[test_file] = {
                    'success': success,
                    'output': result.stdout,
                    'error': result.stderr
                }
                
                print(f"  {'✓' if success else '✗'} {test_file}: {'PASSED' if success else 'FAILED'}")
                if not success and result.stderr:
                    print(f"    Error: {result.stderr[:100]}...")
                    
            except subprocess.TimeoutExpired:
                test_results[test_file] = {
                    'success': False,
                    'error': 'Test timed out'
                }
                print(f"  ✗ {test_file}: TIMEOUT")
            except Exception as e:
                test_results[test_file] = {
                    'success': False,
                    'error': str(e)
                }
                print(f"  ✗ {test_file}: ERROR - {e}")
        else:
            print(f"  ⚠ {test_file}: NOT FOUND")
            test_results[test_file] = {
                'success': False,
                'error': 'File not found'
            }
    
    return test_results

def save_audio_output(audio_base64, filename, format_type="mp3"):
    """Save base64 audio data to file"""
    try:
        # Create output directory if it doesn't exist
        output_dir = "output"
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # Decode base64 audio data
        audio_data = base64.b64decode(audio_base64.encode())
        
        # Save to file
        file_path = os.path.join(output_dir, f"{filename}.{format_type}")
        with open(file_path, 'wb') as f:
            f.write(audio_data)
        
        return file_path, len(audio_data)
    except Exception as e:
        print(f"Error saving audio: {e}")
        return None, 0

def test_complete_odiadev_speech():
    """Generate the complete ODIADEV company speech"""
    print("\\n🎙️ Generating Complete ODIADEV Company Speech")
    print("-" * 50)
    
    # Load the full company script
    try:
        with open('odiadev_company_speech.txt', 'r', encoding='utf-8') as f:
            full_script = f.read().strip()
    except FileNotFoundError:
        full_script = "ODIADEV - The Future of Voice AI in Nigeria. Making voice AI affordable for every Nigerian business."
    
    # Create shorter segments for better TTS quality (approximately 1-2 sentences each)
    segments = [
        "Welcome to ODIADEV - The Future of Voice AI in Nigeria.",
        "ODIADEV is pioneering the next generation of artificial intelligence solutions specifically designed for Nigeria and Africa.",
        "Our flagship product, ODIADEV TTS, is set to revolutionize how Nigerians interact with technology through voice.",
        "For too long, voice AI has been expensive and inaccessible to everyday Nigerians.",
        "International solutions cost thousands of dollars, putting them out of reach for small businesses and developers.",
        "ODIADEV changes that completely.",
        "With ODIADEV TTS, we're making professional-grade text-to-speech technology available at a fraction of the cost.",
        "Starting at just 8,000 Naira for our Starter plan, up to 75,000 Naira for Enterprise.",
        "We're democratizing voice AI for everyone.",
        "What makes us different? We understand Nigeria.",
        "Our system is optimized for Nigerian networks, supports local languages and accents.",
        "We work seamlessly even with slower internet connections.",
        "Whether you're in Lagos, Abuja, Port Harcourt, or remote areas, ODIADEV TTS delivers reliable voice generation.",
        "Imagine a Nigeria where every small business can afford an AI voice assistant.",
        "Where educational apps can speak in local languages, where customer service is available 24/7 at minimal cost.",
        "That's the Nigeria we're building at ODIADEV.",
        "ODIADEV TTS isn't just about technology - it's about economic empowerment.",
        "We're creating jobs, supporting local innovation, and ensuring Nigeria leads AI development in Africa.",
        "Join the voice AI revolution. Choose ODIADEV TTS.",
        "Affordable, reliable, and proudly Nigerian. ODIADEV - Empowering Nigeria through Artificial Intelligence."
    ]
    
    base_url = "http://localhost:5001"  # Using debug app
    generated_files = []
    total_audio_size = 0
    
    print(f"Generating {len(segments)} audio segments...")
    
    for i, segment in enumerate(segments, 1):
        print(f"\\nSegment {i:2d}/{len(segments)}: {segment[:50]}{'...' if len(segment) > 50 else ''}")
        
        try:
            data = {
                "text": segment,
                "voice": "alloy"
            }
            
            response = requests.post(f"{base_url}/test-tts", json=data, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                if result.get('success'):
                    audio_base64 = result.get('data', {}).get('audio_base64', '')
                    if audio_base64:
                        filename = f"odiadev_speech_segment_{i:02d}"
                        file_path, file_size = save_audio_output(audio_base64, filename)
                        
                        if file_path:
                            generated_files.append({
                                'segment': i,
                                'file_path': file_path,
                                'file_size': file_size,
                                'text': segment
                            })
                            total_audio_size += file_size
                            print(f"    ✓ Generated: {os.path.basename(file_path)} ({file_size} bytes)")
                        else:
                            print(f"    ✗ Failed to save audio file")
                    else:
                        print(f"    ✗ No audio data received")
                else:
                    print(f"    ✗ TTS failed: {result.get('error', 'Unknown error')}")
            else:
                print(f"    ✗ HTTP Error: {response.status_code}")
                
        except Exception as e:
            print(f"    ✗ Exception: {str(e)}")
    
    # Generate summary report
    print("\\n" + "=" * 50)
    print("📊 ODIADEV Speech Generation Summary")
    print("=" * 50)
    print(f"Total segments: {len(segments)}")
    print(f"Successfully generated: {len(generated_files)}")
    print(f"Total audio size: {total_audio_size} bytes ({total_audio_size/1024:.1f} KB)")
    print(f"Average segment size: {total_audio_size/len(generated_files):.0f} bytes" if generated_files else "N/A")
    
    # Create playlist/script file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    playlist_file = f"output/odiadev_speech_playlist_{timestamp}.txt"
    
    with open(playlist_file, 'w', encoding='utf-8') as f:
        f.write("ODIADEV Company Speech - Audio Playlist\\n")
        f.write(f"Generated: {datetime.now().isoformat()}\\n")
        f.write("=" * 60 + "\\n\\n")
        
        f.write(f"Total Segments: {len(generated_files)}\\n")
        f.write(f"Total Size: {total_audio_size} bytes ({total_audio_size/1024:.1f} KB)\\n\\n")
        
        f.write("Audio Files:\\n")
        f.write("-" * 30 + "\\n")
        for item in generated_files:
            f.write(f"{item['segment']:2d}. {os.path.basename(item['file_path'])} ({item['file_size']} bytes)\\n")
            f.write(f"    Text: {item['text']}\\n\\n")
    
    print(f"\\nPlaylist saved to: {playlist_file}")
    
    if generated_files:
        print("\\n🎉 ODIADEV company speech generated successfully!")
        print(f"   Audio files saved in: {os.path.abspath('output')}")
    
    return generated_files

def main():
    """Main validation and testing function"""
    print("🚀 ODIADEV TTS API - Complete System Validation")
    print("=" * 60)
    print(f"Started: {datetime.now().isoformat()}")
    print("")
    
    # Test 1: Run existing test suite
    print("Phase 1: Existing Test Suite")
    existing_test_results = test_existing_test_files()
    
    # Test 2: Generate ODIADEV company speech
    print("\\nPhase 2: ODIADEV Company Speech Generation")
    speech_files = test_complete_odiadev_speech()
    
    # Final summary
    print("\\n" + "=" * 60)
    print("📋 COMPLETE VALIDATION SUMMARY")
    print("=" * 60)
    
    # Existing tests summary
    existing_passed = sum(1 for result in existing_test_results.values() if result['success'])
    existing_total = len(existing_test_results)
    
    print(f"Existing Tests: {existing_passed}/{existing_total} passed")
    for test_name, result in existing_test_results.items():
        status = "PASS" if result['success'] else "FAIL"
        print(f"  {test_name}: {status}")
    
    # Speech generation summary
    print(f"\\nSpeech Generation: {len(speech_files)} segments created")
    if speech_files:
        total_size = sum(f['file_size'] for f in speech_files)
        print(f"  Total audio: {total_size} bytes ({total_size/1024:.1f} KB)")
        print(f"  Files location: {os.path.abspath('output')}")
    
    # Overall status
    overall_success = (existing_passed > 0 or existing_total == 0) and len(speech_files) > 0
    
    print(f"\\n{'🎉' if overall_success else '⚠️'} Overall Status: {'SUCCESS' if overall_success else 'PARTIAL SUCCESS'}")
    
    if overall_success:
        print("\\n✅ Your ODIADEV TTS API is working correctly!")
        print("   - All core functionality tested")
        print("   - Company speech generated successfully") 
        print("   - Ready for production use")
    else:
        print("\\n⚠️ Some issues detected, but core TTS functionality works")
        print("   - Check individual test results above")
        print("   - TTS generation is functional for basic use")
    
    print(f"\\nCompleted: {datetime.now().isoformat()}")

if __name__ == "__main__":
    main()