import os
from datetime import datetime

TARGET_DIRECTORY = r"C:\Users\OD~IA\Music\ODIA-TTS-TEST-AUDIO"

def check_generated_files():
    """Check what audio files have been generated"""
    print(f"📁 Checking files in: {TARGET_DIRECTORY}")
    print("=" * 60)
    
    if not os.path.exists(TARGET_DIRECTORY):
        print("❌ Target directory does not exist")
        return
    
    # Get all MP3 files
    mp3_files = [f for f in os.listdir(TARGET_DIRECTORY) if f.endswith('.mp3')]
    mp3_files.sort()
    
    if not mp3_files:
        print("📂 No MP3 files found yet")
        return
    
    total_size = 0
    print(f"🎵 Found {len(mp3_files)} audio files:")
    print("-" * 60)
    
    for i, filename in enumerate(mp3_files, 1):
        file_path = os.path.join(TARGET_DIRECTORY, filename)
        file_size = os.path.getsize(file_path)
        total_size += file_size
        
        # Get creation time
        creation_time = datetime.fromtimestamp(os.path.getctime(file_path))
        
        print(f"{i:2d}. {filename}")
        print(f"    Size: {file_size:,} bytes ({file_size/1024:.1f} KB)")
        print(f"    Created: {creation_time.strftime('%H:%M:%S')}")
        print()
    
    print("-" * 60)
    print(f"📊 Total Files: {len(mp3_files)}")
    print(f"📏 Total Size: {total_size:,} bytes ({total_size/1024:.1f} KB) ({total_size/(1024*1024):.2f} MB)")
    print(f"📊 Average Size: {total_size/len(mp3_files):,.0f} bytes per file")
    
    # Check if generation is complete (expecting 25 files)
    if len(mp3_files) >= 25:
        print("\n🎉 GENERATION COMPLETE! All 25 files created.")
    else:
        print(f"\n⏳ Generation in progress: {len(mp3_files)}/25 files completed")

if __name__ == "__main__":
    print("🎙️ ODIADEV TTS - File Status Checker")
    check_generated_files()
    input("\nPress Enter to exit...")