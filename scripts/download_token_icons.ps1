# PowerShell script to download common token icons
# Run this from the project root: .\scripts\download_token_icons.ps1

$tokensDir = "assets\images\tokens"

# Create directory if it doesn't exist
if (-not (Test-Path $tokensDir)) {
    New-Item -ItemType Directory -Path $tokensDir -Force | Out-Null
}

# Token icons to download from Trust Wallet
$tokens = @{
    "eth" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png"
    "btc" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/bitcoin/info/logo.png"
    "usdc" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png"
    "usdt" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xdAC17F958D2ee523a2206206994597C13D831ec7/logo.png"
    "bnb" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/binance/info/logo.png"
    "matic" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/polygon/info/logo.png"
    "dai" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo.png"
    "link" = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x514910771AF9Ca656af840dff83E8264EcF986CA/logo.png"
}

Write-Host "Downloading token icons..." -ForegroundColor Green

foreach ($token in $tokens.GetEnumerator()) {
    $filename = "$tokensDir\$($token.Key).png"
    
    if (Test-Path $filename) {
        Write-Host "  Already exists: $($token.Key).png" -ForegroundColor Yellow
    }
    else {
        try {
            Write-Host "  Downloading $($token.Key).png..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $token.Value -OutFile $filename -ErrorAction Stop
            Write-Host "  Downloaded: $($token.Key).png" -ForegroundColor Green
        }
        catch {
            Write-Host "  Failed: $($token.Key).png" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Done! Token icons saved to $tokensDir" -ForegroundColor Green
Write-Host "Note: You still need to add fowl.png manually from your Figma design" -ForegroundColor Yellow
