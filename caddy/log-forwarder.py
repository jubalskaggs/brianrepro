#!/usr/bin/env python3
"""
Enhanced log forwarder that reads Caddy JSON logs and sends them to Graylog via GELF TCP
Features: retry logic, batching, metrics, log rotation, and improved error handling
"""

import json
import socket
import time
import sys
import os
import threading
import subprocess
from datetime import datetime
from collections import deque
from typing import List, Dict, Any

GRAYLOG_HOST = os.getenv('GRAYLOG_HOST', 'graylog')
GRAYLOG_PORT = int(os.getenv('GRAYLOG_PORT', '12201'))
LOG_FILE = '/var/log/caddy/access.log'
BATCH_SIZE = int(os.getenv('BATCH_SIZE', '10'))
BATCH_TIMEOUT = float(os.getenv('BATCH_TIMEOUT', '5.0'))
MAX_RETRIES = int(os.getenv('MAX_RETRIES', '3'))
RETRY_BASE_DELAY = float(os.getenv('RETRY_BASE_DELAY', '1.0'))
LOG_ROTATION_SIZE = int(os.getenv('LOG_ROTATION_SIZE', '500000'))  # 500KB
LOG_ROTATION_INTERVAL = int(os.getenv('LOG_ROTATION_INTERVAL', '300'))  # 5 minutes

# Metrics tracking
metrics = {
    'forwarded': 0,
    'failed': 0,
    'batches_sent': 0,
    'retries': 0,
    'rotations': 0,
    'start_time': time.time()
}
metrics_lock = threading.Lock()

def create_gelf_message(log_entry):
    """Convert Caddy log entry to GELF format"""
    # Extract request and response information
    request = log_entry.get('request', {})
    response = log_entry.get('response', {})
    resp_headers = log_entry.get('resp_headers', {})
    
    method = request.get('method', 'UNKNOWN')
    uri = request.get('uri', '/')
    status = log_entry.get('status', 0)
    
    # Extract real client IP from X-Forwarded-For header if available
    headers = request.get('headers', {})
    x_forwarded_for = headers.get('X-Forwarded-For', [''])[0] if headers.get('X-Forwarded-For') else ''
    real_ip = headers.get('X-Real-IP', [''])[0] if headers.get('X-Real-IP') else ''
    
    # Use the most reliable IP source
    client_ip = x_forwarded_for or real_ip or request.get('remote_ip', '')
    
    gelf = {
        "version": "1.1",
        "host": "caddy",
        "short_message": f"{method} {uri} -> {status}",
        "timestamp": log_entry.get('ts', time.time()),
        "level": 6,  # INFO level
        "facility": "caddy",
        "_service": "caddy",
        "_method": method,
        "_uri": uri,
        "_status": status,
        "_duration": log_entry.get('duration', ''),
        "_client_ip": client_ip,
        "_remote_ip": request.get('remote_ip', ''),
        "_x_forwarded_for": x_forwarded_for,
        "_x_real_ip": real_ip,
        "_user_agent": headers.get('User-Agent', [''])[0] if headers.get('User-Agent') else '',
        "_host": request.get('host', ''),
        "_proto": request.get('proto', ''),
        "_size": log_entry.get('size', 0),
        "_bytes_read": log_entry.get('bytes_read', 0),
    }
    
    # Add any additional fields
    for key, value in log_entry.items():
        if key not in ['ts', 'request', 'response', 'resp_headers', 'duration', 'status', 'size', 'bytes_read']:
            gelf[f"_{key}"] = str(value)
    
    return json.dumps(gelf) + '\n'

def send_to_graylog_with_retry(messages: List[str]) -> bool:
    """Send GELF messages to Graylog via TCP with exponential backoff retry"""
    for attempt in range(MAX_RETRIES + 1):
        try:
            # Send each message individually to avoid JSON parsing issues
            for message in messages:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(10)
                sock.connect((GRAYLOG_HOST, GRAYLOG_PORT))
                sock.sendall(message.encode('utf-8'))
                sock.close()  # Close connection after each message
            
            # Update metrics on success
            with metrics_lock:
                metrics['forwarded'] += len(messages)
                metrics['batches_sent'] += 1
                if attempt > 0:
                    metrics['retries'] += attempt
            
            return True
            
        except Exception as e:
            if attempt < MAX_RETRIES:
                delay = RETRY_BASE_DELAY * (2 ** attempt)  # Exponential backoff
                print(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s...", file=sys.stderr)
                time.sleep(delay)
            else:
                print(f"All {MAX_RETRIES + 1} attempts failed. Last error: {e}", file=sys.stderr)
                with metrics_lock:
                    metrics['failed'] += len(messages)
                return False
    
    return False

def rotate_log_file():
    """Rotate the log file to keep it small"""
    try:
        if os.path.exists(LOG_FILE):
            file_size = os.path.getsize(LOG_FILE)
            if file_size > LOG_ROTATION_SIZE:
                print(f"Log file size ({file_size} bytes) exceeds limit ({LOG_ROTATION_SIZE} bytes), rotating...")
                
                # Truncate the log file to keep only the last 100KB
                with open(LOG_FILE, 'r') as f:
                    lines = f.readlines()
                
                # Keep only the last 1000 lines (approximately 100KB)
                if len(lines) > 1000:
                    lines = lines[-1000:]
                
                with open(LOG_FILE, 'w') as f:
                    f.writelines(lines)
                
                with metrics_lock:
                    metrics['rotations'] += 1
                
                print(f"Log file rotated, kept {len(lines)} lines")
                return True
    except Exception as e:
        print(f"Error rotating log file: {e}", file=sys.stderr)
    return False

def print_metrics():
    """Print current metrics to stdout"""
    with metrics_lock:
        uptime = time.time() - metrics['start_time']
        print(f"Metrics - Uptime: {uptime:.1f}s, Forwarded: {metrics['forwarded']}, "
              f"Failed: {metrics['failed']}, Batches: {metrics['batches_sent']}, "
              f"Retries: {metrics['retries']}, Rotations: {metrics['rotations']}")

def follow_log_file():
    """Follow the log file and forward entries to Graylog with batching"""
    print(f"Starting enhanced log forwarder: {LOG_FILE} -> {GRAYLOG_HOST}:{GRAYLOG_PORT}")
    print(f"Batch size: {BATCH_SIZE}, Batch timeout: {BATCH_TIMEOUT}s, Max retries: {MAX_RETRIES}")
    print(f"Log rotation: {LOG_ROTATION_SIZE} bytes, every {LOG_ROTATION_INTERVAL}s")
    
    # Wait for log file to exist
    while not os.path.exists(LOG_FILE):
        print(f"Waiting for log file: {LOG_FILE}")
        time.sleep(1)
    
    # Batching variables
    message_batch = []
    last_batch_time = time.time()
    last_rotation_check = time.time()
    
    # Open log file and follow it
    with open(LOG_FILE, 'r') as f:
        # Go to end of file
        f.seek(0, 2)
        
        while True:
            line = f.readline()
            if not line:
                # Check if we should flush the batch due to timeout
                if message_batch and (time.time() - last_batch_time) >= BATCH_TIMEOUT:
                    print(f"Batch timeout reached, sending {len(message_batch)} messages")
                    if send_to_graylog_with_retry(message_batch):
                        print(f"Successfully sent batch of {len(message_batch)} messages")
                    else:
                        print(f"Failed to send batch of {len(message_batch)} messages")
                    message_batch.clear()
                    last_batch_time = time.time()
                
                # Check if we should rotate the log file
                current_time = time.time()
                if (current_time - last_rotation_check) >= LOG_ROTATION_INTERVAL:
                    rotate_log_file()
                    last_rotation_check = current_time
                
                time.sleep(0.1)
                continue
            
            try:
                # Parse JSON log entry
                log_entry = json.loads(line.strip())
                
                # Only process HTTP access logs, skip internal Caddy logs
                if 'request' in log_entry and ('response' in log_entry or 'resp_headers' in log_entry):
                    # Convert to GELF and add to batch
                    gelf_message = create_gelf_message(log_entry)
                    message_batch.append(gelf_message)
                    
                    # Check if batch is full or timeout reached
                    current_time = time.time()
                    if (len(message_batch) >= BATCH_SIZE or 
                        (message_batch and (current_time - last_batch_time) >= BATCH_TIMEOUT)):
                        
                        print(f"Sending batch of {len(message_batch)} messages")
                        if send_to_graylog_with_retry(message_batch):
                            print(f"Successfully sent batch of {len(message_batch)} messages")
                        else:
                            print(f"Failed to send batch of {len(message_batch)} messages")
                        
                        message_batch.clear()
                        last_batch_time = current_time
                
            except json.JSONDecodeError:
                print(f"Invalid JSON in log: {line.strip()}", file=sys.stderr)
            except Exception as e:
                print(f"Error processing log entry: {e}", file=sys.stderr)

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    print("\nShutdown signal received, printing final metrics...")
    print_metrics()
    sys.exit(0)

if __name__ == "__main__":
    import signal
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start metrics reporting thread
    def metrics_reporter():
        while True:
            time.sleep(60)  # Report every minute
            print_metrics()
    
    metrics_thread = threading.Thread(target=metrics_reporter, daemon=True)
    metrics_thread.start()
    
    follow_log_file()
