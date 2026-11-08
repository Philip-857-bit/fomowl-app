1. **Fix UnlockScreen**:
   - Revert clearing of `_passcode` variable in `dispose` since strings are immutable and this is security theater.
   - Add comment for why `ScreenCaptureGuard` is used.

2. **Fix LoginProfileScreen**:
   - Revert clearing `_passwordController.text = ''` in `dispose` to avoid security theater and avoid triggering `ChangeNotifier` listeners during unmount.
   - Add comment for why `ScreenCaptureGuard` is used.

3. **Fix RegisterProfileScreen**:
   - Revert clearing `_passwordController.text = ''` and `_xSecretController.text = ''` in `dispose`.
   - Add comment for why `ScreenCaptureGuard` is used.

4. **Verify**:
   - Check `git status` to ensure only the 3 modified files are being tracked.
   - Check file lengths to ensure only the necessary logic is added (<50 lines).

5. **Request Code Review**.
