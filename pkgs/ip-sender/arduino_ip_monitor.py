#!/usr/bin/env python3

import serial
import socket
import time
import subprocess
import platform
import sys
import os

# Force line-buffered output for better debugging in Nix environments
# Note: Python 3 doesn't support unbuffered text I/O, use line buffering instead
sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 1)  # 1 = line buffered
sys.stderr = os.fdopen(sys.stderr.fileno(), 'w', 1)  # 1 = line buffered

# Try to import netifaces, fall back to basic methods if not available
try:
    import netifaces
    HAS_NETIFACES = True
    print("netifaces library found - using advanced IPv6 detection")
    sys.stdout.flush()
except ImportError:
    HAS_NETIFACES = False
    print("netifaces not found - using basic IPv6 detection")
    print("Install with: pip install netifaces")
    sys.stdout.flush()

def print_flush(msg):
    """Print with immediate flush for better debugging"""
    print(msg)
    sys.stdout.flush()

def get_local_ipv4():
    """Get the local IPv4 address of the PC"""
    print_flush("Detecting IPv4 address...")
    try:
        # Connect to a remote server to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            addr = s.getsockname()[0]
            print_flush(f"Found IPv4: {addr}")
            return addr
    except Exception as e:
        print_flush(f"IPv4 detection failed: {e}")
        return "127.0.0.1"

def get_local_ipv6():
    """Get the local IPv6 address of the PC"""
    print_flush("Detecting IPv6 address...")
    
    if HAS_NETIFACES:
        try:
            # Get all network interfaces
            interfaces = netifaces.interfaces()
            print_flush(f"Found interfaces: {interfaces}")
            
            for interface in interfaces:
                # Skip loopback interface
                if interface == 'lo' or 'loopback' in interface.lower():
                    continue
                    
                addrs = netifaces.ifaddresses(interface)
                
                # Check for IPv6 addresses
                if netifaces.AF_INET6 in addrs:
                    for addr_info in addrs[netifaces.AF_INET6]:
                        addr = addr_info['addr']
                        print_flush(f"Found IPv6 on {interface}: {addr}")
                        # Skip link-local addresses (they start with fe80)
                        if not addr.startswith('fe80') and not addr.startswith('::1'):
                            # Remove scope identifier if present
                            if '%' in addr:
                                addr = addr.split('%')[0]
                            print_flush(f"Using IPv6: {addr}")
                            return addr
            
            print_flush("No global IPv6 addresses found")
        except Exception as e:
            print_flush(f"Error with netifaces: {e}")
    
    # Fallback methods
    try:
        print_flush("Trying fallback IPv6 detection...")
        # Method 1: Try connecting to IPv6 address
        with socket.socket(socket.AF_INET6, socket.SOCK_DGRAM) as s:
            s.connect(("2001:4860:4860::8888", 80))  # Google's IPv6 DNS
            addr = s.getsockname()[0]
            if not addr.startswith('fe80') and addr != '::1':
                print_flush(f"Found IPv6 via socket: {addr}")
                return addr
    except Exception as e:
        print_flush(f"Socket method failed: {e}")
    
    try:
        # Method 2: Use getaddrinfo
        hostname = socket.getfqdn()
        print_flush(f"Trying hostname: {hostname}")
        addr_info = socket.getaddrinfo(hostname, None, socket.AF_INET6)
        if addr_info:
            addr = addr_info[0][4][0]
            if not addr.startswith('fe80') and addr != '::1':
                print_flush(f"Found IPv6 via getaddrinfo: {addr}")
                return addr
    except Exception as e:
        print_flush(f"getaddrinfo method failed: {e}")
    
    print_flush("Using localhost IPv6")
    return "::1"  # localhost IPv6

def get_primary_ipv4():
    """Alternative method to get IPv4 address"""
    hostname = socket.gethostname()
    try:
        return socket.gethostbyname(hostname)
    except:
        return get_local_ipv4()

def find_arduino_port():
    """Find the Arduino/nRF52840 serial port"""
    print_flush("Searching for Arduino/nRF52840...")
    
    try:
        import serial.tools.list_ports
        
        ports = serial.tools.list_ports.comports()
        print_flush(f"Available ports: {[p.device for p in ports]}")
        
        for port in ports:
            print_flush(f"Checking port: {port.device} - {port.description}")
            # Look for Adafruit or nRF52840 in the description
            if any(keyword in port.description.lower() for keyword in ['adafruit', 'nrf52840', 'bluefruit']):
                print_flush(f"Found Arduino at: {port.device}")
                return port.device
        
        # If not found, return the first available port
        if ports:
            print_flush(f"Arduino not found, using first available port: {ports[0].device}")
            return ports[0].device
        
        print_flush("No serial ports found!")
        return None
        
    except Exception as e:
        print_flush(f"Error finding ports: {e}")
        return None

def main():
    print_flush("=== PC IP Address Sender for nRF52840 ===")
    print_flush("Starting up...")
    print_flush(f"Python version: {sys.version}")
    print_flush(f"Platform: {platform.platform()}")
    
    # Test basic functionality first
    print_flush("\n--- Basic Test ---")
    print_flush("Testing basic output...")
    
    # Test IP detection first
    print_flush("\n--- Testing IP Detection ---")
    try:
        ipv4 = get_local_ipv4()
        ipv6 = get_local_ipv6()
        print_flush(f"Detected IPv4: {ipv4}")
        print_flush(f"Detected IPv6: {ipv6}")
    except Exception as e:
        print_flush(f"ERROR in IP detection: {e}")
        return
    
    # Find and connect to Arduino
    print_flush("\n--- Connecting to Arduino ---")
    try:
        port = find_arduino_port()
        if not port:
            print_flush("ERROR: No serial ports found!")
            print_flush("Make sure your Arduino is connected via USB")
            return
    except Exception as e:
        print_flush(f"ERROR finding Arduino: {e}")
        return
    
    try:
        # Connect to Arduino
        print_flush(f"Connecting to Arduino on {port}...")
        ser = serial.Serial(port, 115200, timeout=1)
        time.sleep(2)  # Wait for Arduino to initialize
        
        print_flush(f"✓ Connected to Arduino on {port}")
        print_flush("✓ Monitoring IPv4 and IPv6 address changes...")
        print_flush("✓ Press Ctrl+C to stop")
        print_flush("-" * 50)
        
        last_ipv4 = ""
        last_ipv6 = ""
        loop_count = 0
        
        while True:
            loop_count += 1
            print_flush(f"Loop {loop_count}: Checking for IP changes...")
            
            # Get current IPs
            current_ipv4 = get_local_ipv4()
            current_ipv6 = get_local_ipv6()
            
            # Send IPv4 if it changed
            if current_ipv4 != last_ipv4:
                message = f"IPV4:{current_ipv4}\n"
                ser.write(message.encode())
                print_flush(f"→ Sent IPv4: {current_ipv4}")
                last_ipv4 = current_ipv4
            
            # Send IPv6 if it changed
            if current_ipv6 != last_ipv6:
                message = f"IPV6:{current_ipv6}\n"
                ser.write(message.encode())
                print_flush(f"→ Sent IPv6: {current_ipv6}")
                last_ipv6 = current_ipv6
            
            # Check for responses from Arduino
            if ser.in_waiting > 0:
                response = ser.readline().decode().strip()
                if response:
                    print_flush(f"← Arduino: {response}")
            
            print_flush(f"Waiting 5 seconds... (loop {loop_count} complete)")
            time.sleep(5)  # Check every 5 seconds
            
    except serial.SerialException as e:
        print_flush(f"ERROR: Serial communication failed: {e}")
        print_flush("Make sure the Arduino is connected and the correct port is selected.")
    except KeyboardInterrupt:
        print_flush("\n--- Stopping ---")
        print_flush("User interrupted with Ctrl+C")
    except Exception as e:
        print_flush(f"ERROR: Unexpected error: {e}")
        import traceback
        print_flush(f"Traceback: {traceback.format_exc()}")
    finally:
        if 'ser' in locals():
            ser.close()
            print_flush("Serial connection closed")

if __name__ == "__main__":
    main()
