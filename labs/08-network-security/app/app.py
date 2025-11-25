from flask import Flask, jsonify
import socket
import os
import sys

app = Flask(__name__)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'hostname': socket.gethostname(),
        'ip': socket.gethostbyname(socket.gethostname())
    })

@app.route('/network-info')
def network_info():
    """Return network information about this container"""
    try:
        hostname = socket.gethostname()
        ip_address = socket.gethostbyname(hostname)
        
        return jsonify({
            'hostname': hostname,
            'ip_address': ip_address,
            'network': os.environ.get('NETWORK_NAME', 'unknown'),
            'service': os.environ.get('SERVICE_NAME', 'api')
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/ping/<target>')
def ping_target(target):
    """Try to resolve and ping a target hostname"""
    try:
        # Try to resolve the hostname
        ip = socket.gethostbyname(target)
        return jsonify({
            'target': target,
            'resolved_ip': ip,
            'reachable': True,
            'message': f'Successfully resolved {target} to {ip}'
        })
    except socket.gaierror:
        return jsonify({
            'target': target,
            'resolved_ip': None,
            'reachable': False,
            'message': f'Cannot resolve hostname: {target}'
        }), 404
    except Exception as e:
        return jsonify({
            'target': target,
            'error': str(e),
            'reachable': False
        }), 500

@app.route('/connect-test/<target>/<int:port>')
def connect_test(target, port):
    """Test if we can connect to a target host and port"""
    import socket as sock
    
    try:
        # Create socket and set timeout
        s = sock.socket(sock.AF_INET, sock.SOCK_STREAM)
        s.settimeout(2)
        
        # Try to resolve hostname first
        try:
            target_ip = sock.gethostbyname(target)
        except sock.gaierror:
            return jsonify({
                'target': target,
                'port': port,
                'reachable': False,
                'message': f'Cannot resolve hostname: {target}'
            }), 404
        
        # Try to connect
        result = s.connect_ex((target_ip, port))
        s.close()
        
        if result == 0:
            return jsonify({
                'target': target,
                'ip': target_ip,
                'port': port,
                'reachable': True,
                'message': f'Successfully connected to {target}:{port}'
            })
        else:
            return jsonify({
                'target': target,
                'ip': target_ip,
                'port': port,
                'reachable': False,
                'message': f'Cannot connect to {target}:{port} (connection refused or filtered)'
            }), 503
            
    except Exception as e:
        return jsonify({
            'target': target,
            'port': port,
            'error': str(e),
            'reachable': False
        }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"Starting API server on port {port}", file=sys.stderr)
    print(f"Hostname: {socket.gethostname()}", file=sys.stderr)
    print(f"IP: {socket.gethostbyname(socket.gethostname())}", file=sys.stderr)
    app.run(host='0.0.0.0', port=port, debug=False)