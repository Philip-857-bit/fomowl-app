# PowerShell script to remove white bottom indicator lines from all screens

$files = @(
    "lib/screens/onboarding/fingerprint_verification_screen.dart",
    "lib/screens/onboarding/congratulations_screen.dart",
    "lib/screens/onboarding/import_wallet_screen.dart",
    "lib/screens/onboarding/welcome_screen.dart",
    "lib/screens/onboarding/create_passcode_screen.dart",
    "lib/screens/wallet/wallets_screen.dart",
    "lib/screens/onboarding/import_secret_phrase_screen.dart",
    "lib/screens/onboarding/import_private_key_screen.dart",
    "lib/screens/onboarding/face_id_verification_screen.dart",
    "lib/screens/onboarding/face_capture_screen.dart",
    "lib/screens/onboarding/confirm_passcode_screen.dart",
    "lib/screens/onboarding/verify_phrase_screen.dart"
)

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        
        # Remove the bottom indicator line pattern
        $pattern = '(\s+const SizedBox\(height: \d+\),\s+)?// Bottom indicator line\s+Center\(\s+child: Container\(\s+width: 193,\s+height: 3,\s+decoration: BoxDecoration\(\s+color: Colors\.white,\s+borderRadius: BorderRadius\.circular\(2\),\s+\),\s+\),\s+\),\s+const SizedBox\(height: \d+\),'
        
        $newContent = $content -replace $pattern, ''
        
        Set-Content $fullPath -Value $newContent -NoNewline
        Write-Host "Processed: $file"
    }
}

Write-Host "Done! Removed white lines from all screens."
