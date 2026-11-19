// Always restore previous windows and tabs on startup
user_pref("browser.startup.page", 3);

// Always automatically restore session after unclean shutdown / reboot
// without showing the "Sorry. We're having trouble getting your pages back" screen
user_pref("browser.sessionstore.resume_from_crash", true);
user_pref("browser.sessionstore.max_resumed_crashes", -1);
