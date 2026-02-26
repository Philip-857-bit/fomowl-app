# Token Icons

This folder contains token logo images for the wallet.

## File Naming Convention
- Use lowercase token symbol as filename
- Format: `{symbol}.png`
- Examples: `eth.png`, `usdc.png`, `fowl.png`

## Recommended Specifications
- **Format**: PNG with transparency
- **Size**: 200x200px or 256x256px
- **Background**: Transparent
- **Quality**: High resolution for crisp display

## Where to Get Token Icons

### 1. Trust Wallet Assets (Recommended)
- Repository: https://github.com/trustwallet/assets
- Path: `blockchains/ethereum/assets/{contractAddress}/logo.png`
- Most comprehensive collection (4000+ tokens)

### 2. CoinGecko
- Website: https://www.coingecko.com
- Search for token and download logo from token page

### 3. Official Token Websites
- Always prefer official sources for brand accuracy

## Current Icons Needed

Priority tokens to add:
- [ ] `fowl.png` - FOMOwl token (custom, from Figma)
- [ ] `eth.png` - Ethereum
- [ ] `usdc.png` - USD Coin
- [ ] `btc.png` - Bitcoin
- [ ] `bnb.png` - Binance Coin
- [ ] `usdt.png` - Tether

## Fallback Behavior

The app uses a 3-tier fallback system:
1. **Local Asset**: Checks this folder first
2. **Network (Trust Wallet)**: Falls back to Trust Wallet CDN if contract address available
3. **Placeholder**: Shows first letter of symbol with colored background

## Example Downloads

### Ethereum (ETH)
```
https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png
```

### USDC
```
https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png
```

### Bitcoin (BTC)
```
https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/bitcoin/info/logo.png
```

## Adding New Icons

1. Download the icon (200x200px PNG recommended)
2. Rename to lowercase symbol (e.g., `eth.png`)
3. Place in this folder
4. The app will automatically use it

No code changes needed - the TokenIcon widget handles everything!
