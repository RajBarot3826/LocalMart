import ftplib
import urllib.request
import ssl
import time

FTP_HOST = "ftpupload.net"
FTP_USER = "if0_42237423"
FTP_PASS = "pufSSVzpzAK"
FTP_DIR = "/htdocs/api"
LOCAL_FILE = "patch_backend.php"
REMOTE_FILE = "patch_backend.php"
TRIGGER_URL = "https://localmart.free.nf/api/patch_backend.php"

def upload_and_trigger():
    print(f"Connecting to FTP host: {FTP_HOST}...")
    session = None
    max_retries = 3
    for attempt in range(1, max_retries + 1):
        try:
            session = ftplib.FTP(FTP_HOST, FTP_USER, FTP_PASS, timeout=30)
            break
        except ftplib.error_perm as e:
            print(f"FTP permission/login error (attempt {attempt}/{max_retries}): {e}")
            if attempt < max_retries:
                print("Retrying in 5 seconds...")
                time.sleep(5)
            else:
                print("Could not log in to FTP. InfinityFree has strict rate limits. Please try again in a few minutes.")
                return False
        except Exception as e:
            print(f"FTP connection error (attempt {attempt}/{max_retries}): {e}")
            if attempt < max_retries:
                print("Retrying in 5 seconds...")
                time.sleep(5)
            else:
                return False

    try:
        print(f"Changing directory to: {FTP_DIR}...")
        session.cwd(FTP_DIR)
        
        print(f"Uploading {LOCAL_FILE} as {REMOTE_FILE}...")
        with open(LOCAL_FILE, "rb") as f:
            session.storbinary(f"STOR {REMOTE_FILE}", f)
            
        print("Upload completed successfully!")
        session.quit()
        session = None
    except Exception as e:
        print(f"Failed to upload file: {e}")
        if session:
            try:
                session.quit()
            except:
                pass
        return False

    # Wait a second for the file system to synchronize
    time.sleep(2)

    print(f"Triggering script execution at: {TRIGGER_URL}...")
    try:
        # Create a permissive SSL context to bypass potential SSL verification issues
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        
        # Add User-Agent header to avoid basic crawler blocking
        req = urllib.request.Request(
            TRIGGER_URL, 
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        )
        
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            html_content = response.read().decode('utf-8', errors='ignore')
            print("\n--- Server Response ---")
            # Strip HTML tags or just print the text parts for readability
            import re
            text_response = re.sub('<[^<]+?>', '', html_content)
            # Normalize whitespace
            text_response = '\n'.join([line.strip() for line in text_response.splitlines() if line.strip()])
            print(text_response)
            print("-----------------------")
            
            if "Backend Patch Applied" in text_response or "OK" in text_response:
                print("\nDeployment and patch execution succeeded!")
                return True
            else:
                print("\nPatch output doesn't confirm success. Please check details above.")
                return False
    except Exception as e:
        print(f"Error triggering script: {e}")
        print("You can manually open the URL in your browser to execute it: " + TRIGGER_URL)
        return False

if __name__ == "__main__":
    upload_and_trigger()
