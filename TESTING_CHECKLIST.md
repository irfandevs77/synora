# Testing Checklist - Notifications & Real-Time Updates

## Pre-Testing Setup:
- [ ] Pull all code changes
- [ ] Run `flutter pub get`
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Restart app
- [ ] Login with test account

---

## Test 1: Chat Message Notifications ✅

**Setup:**
- [ ] Login on Device A with User A
- [ ] Login on Device B with User B (or emulator)
- [ ] Both users should have internet connection

**Steps:**
1. [ ] Device A: Open chat with User B
2. [ ] Device A: Send a text message (e.g., "Hello World")
3. [ ] Device B: Wait 2-3 seconds
4. [ ] Device B: Check if notification appears on screen
5. [ ] Device B: Check if message appears in chat (without refresh)
6. [ ] Device B: Tap notification
7. [ ] Device B: Should navigate to chat or show snackbar

**Expected Results:**
- ✅ Notification appears on Device B within 3 seconds
- ✅ Message visible in chat on Device B without refresh
- ✅ Message text matches what User A sent
- ✅ Sender name appears in notification

**Debug if failing:**
```bash
# Check Cloud Function logs
firebase functions:log

# Check if notification_queue document was created
# Firebase Console → Firestore → notification_queue
```

---

## Test 2: Chat Media Notifications ✅

**Steps:**
1. [ ] Device A: Open chat
2. [ ] Device A: Send an image/photo
3. [ ] Device B: Wait 2-3 seconds
4. [ ] Device B: Check if notification says "sent a photo"
5. [ ] Device B: Verify image appears in chat

**Expected Results:**
- ✅ Notification shows "sent a photo"
- ✅ Photo loads in chat without refresh
- ✅ No crashes or errors

---

## Test 3: Friend Request Notifications ✅

**Steps:**
1. [ ] Device A: Go to Search screen
2. [ ] Device A: Search for User B
3. [ ] Device A: Click Add Friend button
4. [ ] Device A: Button shows "Requested"
5. [ ] Device B: Wait 2-3 seconds
6. [ ] Device B: Check for friend request notification
7. [ ] Device B: Go to user profile (search for User A)
8. [ ] Device B: Check if button says "Accept Request"

**Expected Results:**
- ✅ Device A button changes to "Requested" immediately
- ✅ Device B receives notification within 3 seconds
- ✅ Device B sees "Accept Request" button without refresh
- ✅ Button state matches across devices

**Debug if failing:**
```bash
# Check friend status in Firestore
# Firebase Console → Firestore → freinds collection
# Look for document: userA_userB (sorted alphabetically)
```

---

## Test 4: Friend Request Acceptance ✅

**Steps:**
1. [ ] (Continue from Test 3)
2. [ ] Device B: Click "Accept Request" button
3. [ ] Device B: Verify button changes to "Remove Friend"
4. [ ] Device B: Check if friends count increased
5. [ ] Device A: Wait 2-3 seconds (without refreshing)
6. [ ] Device A: Verify button changed to "Remove Friend"
7. [ ] Device A: Check friends count increased

**Expected Results:**
- ✅ Button changes immediately on both devices
- ✅ Friends count incremented
- ✅ No manual refresh needed
- ✅ In-app notification appears about acceptance

---

## Test 5: Message Display Without Refresh ✅

**Steps:**
1. [ ] Device A: Open chat with User B
2. [ ] Device A: Verify old messages load from history
3. [ ] Device A: Scroll to top of chat
4. [ ] Device A: Verify oldest messages show correctly
5. [ ] Device A: Scroll to bottom
6. [ ] Device B: Send message
7. [ ] Device A: Verify new message appears without scrolling
8. [ ] Device A: Verify message is in correct order

**Expected Results:**
- ✅ All messages visible in correct chronological order
- ✅ New messages appear as they arrive
- ✅ No manual refresh required
- ✅ Scroll position maintained appropriately

---

## Test 6: Multiple Messages Real-Time ✅

**Steps:**
1. [ ] Device A & B: Open same chat
2. [ ] Device A: Send 5 messages quickly
3. [ ] Device B: Verify all 5 messages appear in order
4. [ ] Device B: Verify no messages are missing
5. [ ] Device A: Close chat and reopen
6. [ ] Device A: Verify all messages still there

**Expected Results:**
- ✅ All messages received in correct order
- ✅ No message duplication
- ✅ No messages lost

---

## Test 7: Notification Permissions ✅

**Steps:**
1. [ ] Uninstall app
2. [ ] Reinstall app
3. [ ] Open app for first time (fresh install)
4. [ ] Wait for permission dialog
5. [ ] Check if "Notifications" permission is asked
6. [ ] Grant permission
7. [ ] Send test message
8. [ ] Verify notification appears

**Expected Results:**
- ✅ Permission dialog appears
- ✅ Dialog clearly asks for notification permission
- ✅ After granting, notifications work
- ✅ After denying, notifications still sent to Firestore (in-app)

---

## Test 8: App Background Notification ✅

**Steps:**
1. [ ] Device A: Open chat with User B
2. [ ] Device A: Send message
3. [ ] Device B: Minimize app (go to home screen)
4. [ ] Device A: Send another message
5. [ ] Device B: Check if system notification appears (notification bar)
6. [ ] Device B: Tap notification
7. [ ] Device B: Should open app and navigate to chat

**Expected Results:**
- ✅ Notification appears in system notification bar
- ✅ Notification title and body are correct
- ✅ Tapping notification opens app
- ✅ App navigates to correct chat (if implemented)

---

## Test 9: Notification While App is Killed ✅

**Steps:**
1. [ ] Device B: Close app completely (force stop from Settings)
2. [ ] Device A: Send message
3. [ ] Device B: Wait 5-10 seconds
4. [ ] Device B: Check notification bar
5. [ ] Device B: Reopen app
6. [ ] Device B: Verify message is in Firestore

**Expected Results:**
- ✅ Notification appears in system bar (even with app killed)
- ✅ Message is saved in Firestore
- ✅ When app reopens, message loads correctly

---

## Performance Tests:

**Test 10: Network Latency Test** 🌐
- [ ] Simulate slow network (3G)
- [ ] Send message
- [ ] Verify notification still arrives
- [ ] Measure time to notification (should be < 5 seconds)

**Test 11: Multiple Concurrent Messages** 💬
- [ ] Send 10+ messages in rapid succession
- [ ] Verify all notifications received
- [ ] Check for any duplicates
- [ ] Monitor memory usage

**Test 12: Long Chat History** 📜
- [ ] Load chat with 100+ messages
- [ ] Verify app doesn't lag
- [ ] Scroll performance should be smooth
- [ ] New messages should still appear in real-time

---

## Failure Recovery Tests:

**Test 13: Notification Retry** 🔄
- [ ] Stop Cloud Functions
- [ ] Send message
- [ ] Check notification_queue has pending status
- [ ] Restart Cloud Functions
- [ ] Verify notification is retried and sent

**Test 14: Network Interruption** 📡
- [ ] Disable internet on Device B
- [ ] Device A sends message
- [ ] Re-enable internet on Device B
- [ ] Verify message and notification arrive

---

## Home Feed & Saved Account Tests:

**Test 15: Home Feed Preview**
- [ ] Sign in and open the Home tab
- [ ] Confirm unseen friend demo posts appear before recommendations
- [ ] Tap a Reel preview and verify it is recorded as watched
- [ ] Like, save, share, and comment on posts; verify each interaction updates the demo ranking
- [ ] Mark a post as not interested and verify it disappears after refresh
- [ ] Sign out and use another account; verify its feed behavior is separate

**Test 16: Saved Account Switching**
- [ ] Deploy the updated Cloud Functions before testing
- [ ] Sign in to Account A, then add Account B with its password once
- [ ] Open Profile → Switch account and select Account A
- [ ] Verify switching succeeds without entering Account A's password
- [ ] Force an expired/revoked saved session and verify the app asks for one fresh sign-in
- [ ] Log out and verify saved sessions are removed

---

## Final Checklist:

| Test | Status | Notes |
|------|--------|-------|
| Chat Notifications | ☐ | |
| Media Notifications | ☐ | |
| Friend Requests | ☐ | |
| Real-Time Updates | ☐ | |
| Permission Handling | ☐ | |
| Background Notifications | ☐ | |
| App-Closed Notifications | ☐ | |
| Performance | ☐ | |
| Home Feed Ranking | ☐ | |
| Saved Account Switching | ☐ | |

---

## Common Issues & Solutions:

| Problem | Solution |
|---------|----------|
| No notifications appear | Check Cloud Functions deployed |
| Notifications delayed | Check Firebase latency, network speed |
| Messages don't update | Restart app, check Firestore rules |
| Button doesn't update | Check stream listener errors |
| Crash on notification | Check notification_queue schema |
| FCM token null | Ensure user is logged in before opening chat |

---

## Documentation Links:

- [Firebase Cloud Messaging Docs](https://firebase.flutter.dev/docs/messaging/overview/)
- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [GetX State Management](https://github.com/jonataslaw/getx)
- [Firestore Real-Time Updates](https://firebase.google.com/docs/firestore/query-data/listen)

---

## Notes for Development:

⚠️ **Important:** 
- Always check `firebase functions:log` when debugging notifications
- Check `notification_queue` collection in Firestore to see all notification requests
- Use Firestore Rules to ensure proper access control

📱 **Testing Tips:**
- Use two physical devices for best real-time testing
- Emulators might have latency issues
- Test on both Android and iOS if possible

🐛 **Debug Mode:**
- Check browser console / Xcode console for errors
- Look for `debugPrint` statements in code
- Check Firebase Console → Cloud Functions → Logs

Happy Testing! 🎉
