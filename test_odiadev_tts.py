import requests
import json
import base64
import os
from datetime import datetime

def load_odiadev_script():
    """Load the ODIADEV company script"""
    try:
        with open('odiadev_company_speech.txt', 'r', encoding='utf-8') as f:
            return f.read().strip()
    except FileNotFoundError:
        return """Welcome to ODIADEV - The Future of Voice AI in Nigeria. 
        ODIADEV is pioneering affordable voice AI solutions for Nigeria. 
        Our TTS technology makes professional voice generation accessible 
        to every Nigerian business at just 8,000 Naira and up. 
        Join the voice AI revolution with ODIADEV TTS - 
        Affordable, reliable, and proudly Nigerian."""

def test_tts_with_odiadev_script():
    """Test TTS functionality with the ODIADEV company script"""
    
    # Load the company script
    full_script = load_odiadev_script()
    
    # For TTS, we'll use shorter segments to ensure better quality
    # Split into sentences for better voice pacing
    sentences = [s.strip() + '.' for s in full_script.split('.') if s.strip()]
    
    # Test with first few sentences (approximately 1 minute of speech)
    test_segments = [
        "Welcome to ODIADEV - The Future of Voice AI in Nigeria",
        "ODIADEV is pioneering the next generation of artificial intelligence solutions specifically designed for Nigeria and Africa",
        "Our flagship product, ODIADEV TTS, is set to revolutionize how Nigerians interact with technology through voice",
        "We're making professional-grade text-to-speech technology available at a fraction of the cost",
        "Starting at just 8,000 Naira for our Starter plan, we're democratizing voice AI for everyone",
        "What makes us different? We understand Nigeria and optimize for Nigerian networks",
        "ODIADEV TTS delivers reliable voice generation even in remote areas with limited connectivity",
        "Choose ODIADEV TTS - Affordable, reliable, and proudly Nigerian"
    ]
    
    print("🎤 ODIADEV TTS Testing Suite")
    print("=" * 50)
    print(f"Total script length: {len(full_script)} characters")
    print(f"Testing {len(test_segments)} voice segments...")
    print("")
    
    results = []
    total_size = 0
    
    # Test with debug app first (port 5001)
    base_url = "http://localhost:5001"
    
    for i, segment in enumerate(test_segments, 1):
        print(f"Testing segment {i}/{len(test_segments)}:")
        print(f"Text: {segment[:60]}{'...' if len(segment) > 60 else ''}")
        
        try:
            # Test data
            data = {
                "text": segment,
                "voice": "alloy"
            }
            
            # Make TTS request
            response = requests.post(f"{base_url}/test-tts", json=data, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                if result.get('success'):
                    audio_data = result.get('data', {}).get('audio_base64', '')
                    audio_size = len(base64.b64decode(audio_data.encode())) if audio_data else 0
                    total_size += audio_size
                    
                    print(f"✓ Success - {audio_size} bytes generated")
                    print(f"  Provider: {result.get('data', {}).get('provider', 'unknown')}")
                    print(f"  Mock: {result.get('data', {}).get('mock', False)}")
                    
                    results.append({
                        'segment': i,
                        'text': segment,
                        'success': True,
                        'size_bytes': audio_size,
                        'provider': result.get('data', {}).get('provider', 'unknown')
                    })
                else:
                    print(f"✗ Failed - {result.get('error', 'Unknown error')}")
                    results.append({
                        'segment': i,
                        'text': segment,
                        'success': False,
                        'error': result.get('error', 'Unknown error')
                    })
            else:
                print(f"✗ HTTP Error - Status {response.status_code}")
                results.append({
                    'segment': i,
                    'text': segment,
                    'success': False,
                    'error': f'HTTP {response.status_code}'
                })
                
        except Exception as e:
            print(f"✗ Exception - {str(e)}")
            results.append({
                'segment': i,
                'text': segment,
                'success': False,
                'error': str(e)
            })
        
        print("")
    
    # Summary
    print("=" * 50)
    print("🎯 ODIADEV TTS Test Results")
    print("=" * 50)
    
    successful = sum(1 for r in results if r['success'])
    total_tests = len(results)
    success_rate = (successful / total_tests * 100) if total_tests > 0 else 0
    
    print(f"Tests completed: {total_tests}")
    print(f"Successful: {successful}")
    print(f"Failed: {total_tests - successful}")
    print(f"Success rate: {success_rate:.1f}%")
    print(f"Total audio generated: {total_size} bytes ({total_size/1024:.1f} KB)")
    
    if successful > 0:
        avg_size = total_size / successful
        print(f"Average segment size: {avg_size:.0f} bytes")
    
    # Save results to file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_file = f"tts_test_report_{timestamp}.txt"
    
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("ODIADEV TTS Test Report\\n")
        f.write(f"Generated: {datetime.now().isoformat()}\\n")
        f.write("=" * 50 + "\\n\\n")
        
        f.write("Test Summary:\\n")
        f.write(f"Total tests: {total_tests}\\n")
        f.write(f"Successful: {successful}\\n")
        f.write(f"Success rate: {success_rate:.1f}%\\n")
        f.write(f"Total audio: {total_size} bytes\\n\\n")
        
        f.write("Individual Results:\\n")
        for r in results:
            f.write(f"Segment {r['segment']}: {'SUCCESS' if r['success'] else 'FAILED'}\\n")
            f.write(f"  Text: {r['text'][:100]}{'...' if len(r['text']) > 100 else ''}\\n")
            if r['success']:
                f.write(f"  Size: {r.get('size_bytes', 0)} bytes\\n")
                f.write(f"  Provider: {r.get('provider', 'unknown')}\\n")
            else:
                f.write(f"  Error: {r.get('error', 'Unknown')}\\n")
            f.write("\\n")
        
        f.write("Full Company Script:\\n")
        f.write("-" * 30 + "\\n")
        f.write(full_script)
    
    print(f"\\nDetailed report saved to: {report_file}")
    
    if success_rate >= 80:
        print("\\n🎉 EXCELLENT! Your ODIADEV TTS system is working great!")
        print("   Ready for generating company voice content.")
    elif success_rate >= 50:
        print("\\n✅ GOOD! Most TTS requests succeeded.")
        print("   Some fine-tuning may be needed for production.")
    else:
        print("\\n⚠️ NEEDS ATTENTION! Low success rate detected.")
        print("   Check configuration and network connectivity.")
    
    return results

if __name__ == "__main__":
    test_tts_with_odiadev_script()