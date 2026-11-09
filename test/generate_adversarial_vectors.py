import hmac
import hashlib
import json

def canonical_string(method, path, timestamp, body):
    clean_method = method.strip().upper()
    clean_path = path.split('?')[0]
    if not clean_path.startswith('/'):
        clean_path = '/' + clean_path
    if body is None or body == '':
        body_hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    else:
        body_hash = hashlib.sha256(body.encode('utf-8')).hexdigest().lower()
    return f"{clean_method}\n{clean_path}\n{timestamp.strip()}\n{body_hash}"

def sign(key, canonical):
    return hmac.new(key.encode('utf-8'), canonical.encode('utf-8'), hashlib.sha256).hexdigest().lower()

tests = [
    # Diverse keys
    {"name": "empty_key", "key": "", "method": "GET", "path": "/tokens", "ts": "1710000000", "body": None},
    {"name": "short_key", "key": "k", "method": "GET", "path": "/tokens", "ts": "1710000000", "body": None},
    {"name": "standard_key", "key": "test_secret_key_12345", "method": "GET", "path": "/tokens", "ts": "1710000000", "body": None},
    {"name": "long_key_over_64", "key": "a" * 128, "method": "GET", "path": "/tokens", "ts": "1710000000", "body": None},
    {"name": "unicode_key", "key": "密匙_🔑_secret", "method": "GET", "path": "/tokens", "ts": "1710000000", "body": None},
    {"name": "special_char_key", "key": "!@#$%^&*()_+-=[]{}|;:,.<>?", "method": "GET", "path": "/tokens", "ts": "1710000000", "body": None},
    # Body variations
    {"name": "utf8_chinese", "key": "test_secret_key_12345", "method": "POST", "path": "/transactions", "ts": "1710000100", "body": '{"name":"中文测试"}'},
    {"name": "utf8_emoji", "key": "test_secret_key_12345", "method": "POST", "path": "/transactions", "ts": "1710000100", "body": '{"icon":"🦉🚀⚡💰🔥"}'},
    {"name": "utf8_currency", "key": "test_secret_key_12345", "method": "POST", "path": "/transactions", "ts": "1710000100", "body": '{"symbols":"€£¥₹₽₩"}'},
    {"name": "json_whitespace", "key": "test_secret_key_12345", "method": "POST", "path": "/transactions", "ts": "1710000100", "body": '{\n  "key": "value"\n}'},
    {"name": "empty_string_body", "key": "test_secret_key_12345", "method": "POST", "path": "/transactions", "ts": "1710000100", "body": ""},
    {"name": "whitespace_only_body", "key": "test_secret_key_12345", "method": "POST", "path": "/transactions", "ts": "1710000100", "body": "   "},
    # Method variations
    {"name": "method_lowercase", "key": "test_secret_key_12345", "method": "get", "path": "/tokens", "ts": "1710000000", "body": None},
    {"name": "method_mixed", "key": "test_secret_key_12345", "method": "PoSt", "path": "/transactions", "ts": "1710000100", "body": ""},
    {"name": "method_put_spaces", "key": "test_secret_key_12345", "method": "  put  ", "path": "/transactions", "ts": "1710000150", "body": None},
    # Path variations
    {"name": "path_no_slash", "key": "test_secret_key_12345", "method": "GET", "path": "tokens", "ts": "1710000000", "body": None},
    {"name": "path_encoded_query", "key": "test_secret_key_12345", "method": "GET", "path": "/transactions?user=0x1%202&foo=%2Fbar", "ts": "1710000050", "body": None},
    {"name": "path_multiple_query", "key": "test_secret_key_12345", "method": "GET", "path": "/bridges?a=1&b=2&c=3&d=4", "ts": "1710000000", "body": None},
    {"name": "path_empty_query", "key": "test_secret_key_12345", "method": "GET", "path": "/tokens?", "ts": "1710000000", "body": None},
    {"name": "path_root", "key": "test_secret_key_12345", "method": "GET", "path": "/", "ts": "1710000000", "body": None},
    {"name": "path_empty", "key": "test_secret_key_12345", "method": "GET", "path": "", "ts": "1710000000", "body": None},
    {"name": "path_trailing_slash", "key": "test_secret_key_12345", "method": "GET", "path": "/tokens/", "ts": "1710000000", "body": None},
    # Timestamp variations
    {"name": "ts_ms", "key": "test_secret_key_12345", "method": "GET", "path": "/tokens", "ts": "1710000000000", "body": None},
    {"name": "ts_spaces", "key": "test_secret_key_12345", "method": "GET", "path": "/tokens", "ts": " 1710000000 ", "body": None},
]

out = []
for t in tests:
    canon = canonical_string(t["method"], t["path"], t["ts"], t["body"])
    sig = sign(t["key"], canon)
    t_copy = dict(t)
    t_copy["canonical"] = canon
    t_copy["signature"] = sig
    out.append(t_copy)

with open("fomowl_wallet/test/adversarial_vectors.json", "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)

print(f"Generated {len(out)} adversarial test vectors successfully.")
