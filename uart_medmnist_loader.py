import serial
import time
import argparse
import numpy as np
from medmnist import BloodMNIST

# --- Protocol Constants ---
CMD_LOAD  = b'L'  # 0x4C
CMD_START = b'S'  # 0x53
EXPECTED_BYTES = 28 * 28 * 3  # 2352 bytes

def run_npu_inference(serial_port, baud_rate, flat_bytes, true_label):
    """
    Executes the UART protocol to load the image and trigger the NPU.
    """
    print(f"[*] Opening serial port {serial_port} at {baud_rate} baud...")
    
    try:
        # Open the serial port with a timeout
        with serial.Serial(serial_port, baud_rate, timeout=2.0) as ser:
            time.sleep(1) # Allow port to stabilize

            ser.reset_input_buffer()
            
            # 1. Send Load Command
            print("[*] Sending LOAD command ('L')...")
            ser.write(CMD_LOAD)
            
            # 2. Transmit Pixel Data
            print(f"[*] Transmitting {len(flat_bytes)} bytes of image data...")
            # Writing in chunks can help prevent serial buffer overflows on some OS
            chunk_size = 256
            for i in range(0, len(flat_bytes), chunk_size):
                ser.write(flat_bytes[i:i+chunk_size])
                
            # 3. Send Start Command
            print("[*] Sending START command ('S')...")
            ser.write(CMD_START)
            
            # 4. Wait for Classification Result
            print("[*] Waiting for NPU classification...")
            start_time = time.time()
            
            result = ser.read(1)
            
            end_time = time.time()
            
            if result:
                try:
                    # Decode the ASCII byte back to a string/integer
                    class_idx = result.decode('ascii')
                    print("\n========================================")
                    print(f"   [TRUE LABEL]      : {true_label}")
                    print(f"   [NPU PREDICTION]  : {class_idx}")
                    
                    match_status = "YES" if str(true_label) == class_idx else "NO"
                    print(f"   [MATCH?]          : {match_status}")
                    
                    print(f"   [TIMING] Inference Latency: {(end_time - start_time) * 1000:.2f} ms")
                    print("========================================\n")
                except UnicodeDecodeError:
                    print(f"\n[ERROR] Received invalid ASCII byte: {result.hex()}")
            else:
                print("\n[ERROR] NPU timeout. No data received.")
                
    except serial.SerialException as e:
        print(f"[ERROR] Serial communication failed: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Tang Nano 20k NPU UART Loader for BloodMNIST")
    parser.add_argument("index", type=int, help="Index of the BloodMNIST image to load and test")
    parser.add_argument("--split", type=str, default="test", choices=["train", "val", "test"], help="Dataset split to use (default: test)")
    parser.add_argument("--port", default="/dev/ttyUSB1", help="Serial port (default: /dev/ttyUSB1)")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate (default: 115200)")
    parser.add_argument("--download", action="store_true", help="Download the MedMNIST dataset if not present")
    
    args = parser.parse_args()
    
    try:
        print(f"[*] Loading BloodMNIST '{args.split}' dataset...")
        # Load the dataset directly using the medmnist library
        dataset = BloodMNIST(split=args.split, download=args.download, as_rgb=True)
        
        # Validate index
        if args.index < 0 or args.index >= len(dataset):
            raise ValueError(f"Index {args.index} out of bounds for dataset of size {len(dataset)}.")
            
        # Extract the image and the label
        img = dataset.imgs[args.index]
        true_label = dataset.labels[args.index][0]
        
        if img.shape != (28, 28, 3):
            raise ValueError(f"Image must be exactly 28x28 RGB. Got shape: {img.shape}")
            
        # Flatten the array to a 1D sequence of R, G, B bytes
        image_bytes = img.flatten().tobytes()
        
        if len(image_bytes) != EXPECTED_BYTES:
            raise ValueError(f"Expected {EXPECTED_BYTES} bytes, got {len(image_bytes)}.")
            
        print(f"[*] Selected Image Index {args.index} | True Label: {true_label}")
        run_npu_inference(args.port, args.baud, image_bytes, true_label)
        
    except Exception as e:
        print(f"Fatal Error: {e}")